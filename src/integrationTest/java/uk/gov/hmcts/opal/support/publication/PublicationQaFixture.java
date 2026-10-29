package uk.gov.hmcts.opal.support.publication;

import org.mockito.ArgumentCaptor;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionTemplate;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.node.ArrayNode;
import tools.jackson.databind.node.ObjectNode;
import uk.gov.hmcts.opal.common.user.authorisation.model.Permission;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.entity.MajorCreditorEntity;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.repository.MajorCreditorRepository;
import uk.gov.hmcts.opal.service.messaging.DraftCasefileQueueMessage;
import uk.gov.hmcts.opal.service.messaging.DraftCasefileQueuePublisherImpl;
import uk.gov.hmcts.opal.support.DraftCasefileHttpFixture;
import uk.gov.hmcts.opal.validator.OpenApiSchemaValidator;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import java.util.function.Supplier;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

/** Fresh HTTP approvals shared by backend and broker QA, with ownership-checked disposable-database cleanup. */
public final class PublicationQaFixture {
    private static final String MAJOR_CODE = "Q106";
    private static final Permission CHECK = new Permission(22L, "Check and validate draft Casefiles");
    private final MockMvc mvc;
    private final ObjectMapper json;
    private final DraftCasefileRepository drafts;
    private final MajorCreditorRepository majorCreditors;
    private final PlatformTransactionManager transactions;
    private final PublicationQaGraph graph;
    private final DraftCasefileQueuePublisherImpl delegate;
    private final OpenApiSchemaValidator schemas;
    private OwnedDraft captured;
    private Long majorId;

    public PublicationQaFixture(MockMvc mvc, ObjectMapper json, DraftCasefileRepository drafts,
                                MajorCreditorRepository majorCreditors, PlatformTransactionManager transactions,
                                PublicationQaGraph graph, DraftCasefileQueuePublisherImpl delegate,
                                OpenApiSchemaValidator schemas) {
        this.mvc = mvc;
        this.json = json;
        this.drafts = drafts;
        this.majorCreditors = majorCreditors;
        this.transactions = transactions;
        this.graph = graph;
        this.delegate = delegate;
        this.schemas = schemas;
    }

    public OwnedDraft approve(boolean withMinors) {
        assertTrue(captured == null && majorId == null, "Fixture must clean its previous owned case first");
        String marker = "E2E-" + UUID.randomUUID().toString().replace("-", "").substring(0, 16);
        PublicationQaGraph.Snapshot before = graph.snapshot();
        String stage = "reference setup";
        try {
            assertTrue(majorCreditors.findByBusinessUnitIdAndMajorCreditorCode((short) 1, MAJOR_CODE).isEmpty(),
                "Case-owned Major Creditor code must be unused");
            majorId = independently(() -> majorCreditors.saveAndFlush(MajorCreditorEntity.builder()
                .businessUnitId((short) 1).majorCreditorCode(MAJOR_CODE).name("Synthetic QA Major")
                .addressLine1("Synthetic major address").active(true).centralAuthority(false).build())
                .getMajorCreditorId());
            stage = "rich request construction";
            ObjectNode request = request(marker, withMinors);
            stage = "rich request schema validation";
            schemas.validate("Casefile", bytes(request.get("casefile").toString()));
            stage = "HTTP create";
            MockHttpServletResponse created = mvc.perform(post("/draft-casefiles")
                .with(authentication(DraftCasefileHttpFixture.token((short) 1)))
                .header("X-User-IP", "192.0.2.1").contentType(MediaType.APPLICATION_JSON)
                .content(request.toString())).andReturn().getResponse();
            JsonNode submitted = json.readTree(created.getContentAsString());
            long id = submitted.path("draft_casefile_id").longValue();
            // Capture ownership before any remaining create-response assertions.
            if (id > 0) {
                captured = new OwnedDraft(id, marker, null, null, null, before);
            }
            assertTrue(id > 0, "Create must return a positive draft identity");
            assertEquals(201, created.getStatus(), "Fresh QA draft must be created through HTTP");
            schemas.validate("DraftCasefileAddResponse", bytes(submitted.toString()));
            final String initialEtag = strongEtag(created);
            DraftCasefileEntity original = committed(id);
            assertEquals(DraftCasefileStatus.SUBMITTED, original.getCasefileStatus());
            assertTrue(Objects.equals(json.readTree(original.getCasefile()), request.get("casefile")),
                "Created input must match the rich request");
            stage = "independent HTTP approval";
            MockHttpServletResponse approval = mvc.perform(patch("/draft-casefiles/{id}", id)
                .with(authentication(DraftCasefileHttpFixture.token((short) 1, 124L, "BUU-CHECKER", Set.of(CHECK))))
                .header("If-Match", initialEtag).header("X-User-IP", "192.0.2.1")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.createObjectNode().put("business_unit_id", 1)
                    .put("casefile_status", "PUBLISHING_PENDING").toString())).andReturn().getResponse();
            assertEquals(200, approval.getStatus(), "Independent checker must approve the owned draft");
            JsonNode approved = json.readTree(approval.getContentAsString());
            schemas.validate("DraftCasefileGetResponse", bytes(approved.toString()));
            final String etag = strongEtag(approval);
            DraftCasefileEntity pending = committed(id);
            assertEquals(DraftCasefileStatus.PUBLISHING_PENDING, pending.getCasefileStatus());
            assertEquals("Publishing pending", approved.path("casefile_status_name").asString());
            assertTrue(pending.getVersionNumber() > original.getVersionNumber(), "Approval must advance version");
            assertEquals("\"" + pending.getVersionNumber() + "\"", etag);
            assertTrue(!etag.equals(initialEtag), "Approval ETag must advance");
            assertTrue(Objects.equals(original.getCasefile(), pending.getCasefile())
                && Objects.equals(original.getCasefileSnapshot(), pending.getCasefileSnapshot())
                && Objects.equals(original.getCreatedDate(), pending.getCreatedDate())
                && Objects.equals(original.getSubmittedBy(), pending.getSubmittedBy())
                && Objects.equals(original.getSubmittedByName(), pending.getSubmittedByName()),
                "Approval must preserve submitted data and metadata");
            assertEquals("BUU-1", pending.getSubmittedBy());
            assertEquals("BUU-CHECKER", pending.getValidatedBy());
            assertTrue(!pending.getSubmittedBy().equals(pending.getValidatedBy()), "Checker must be independent");
            assertEquals("Synthetic Submitter", pending.getValidatedByName());
            assertTrue(pending.getValidatedDate() != null
                && pending.getValidatedDate().equals(pending.getCasefileStatusDate()),
                "Approval timestamps must match");
            assertTrue(Objects.equals(json.readTree(pending.getCasefile()), approved.get("casefile"))
                && Objects.equals(json.readTree(pending.getCasefileSnapshot()), approved.get("casefile_snapshot"))
                && Objects.equals(json.readTree(pending.getTimelineData()), approved.get("timeline_data")),
                "Approved response must describe committed input, snapshot and timeline");
            assertMetadata(approved, pending);
            assertHistory(original, pending, approved);
            stage = "captured approval message";
            ArgumentCaptor<DraftCasefileQueueMessage> sent = ArgumentCaptor.forClass(DraftCasefileQueueMessage.class);
            verify(delegate, times(1)).publish(sent.capture());
            DraftCasefileQueueMessage message = sent.getValue();
            assertEquals(id, message.draftCasefileId());
            assertEquals(124L, message.checkerUserId());
            assertEquals("192.0.2.1", message.originatingIpAddress());
            assertEquals(pending.getValidatedDate().toInstant(ZoneOffset.UTC).toString(), message.approvalTimestamp());
            Instant.parse(message.approvalTimestamp());
            captured = new OwnedDraft(id, marker, json.writeValueAsString(message), approved, etag, before);
            graph.assertUnchanged(before);
            return captured;
        } catch (Exception failure) {
            throw new AssertionError("Publication QA fixture failed during " + stage
                + " (" + failure.getClass().getSimpleName() + ")");
        }
    }

    public DraftCasefileEntity committed(long id) {
        return independently(() -> drafts.findById(id).orElseThrow(
            () -> new IllegalStateException("Owned draft is missing")).toBuilder().build());
    }

    public void cleanup(OwnedDraft owned) {
        assertTrue(captured != null && captured.id() == owned.id()
            && Objects.equals(captured.marker(), owned.marker()), "Cleanup must target this fixture's owned draft");
        graph.removeOwned(owned.graphBefore(), owned.id(), owned.marker());
        assertTrue(drafts.findById(owned.id()).isEmpty(), "Owned draft cleanup must be committed");
        graph.assertUnchanged(owned.graphBefore());
        captured = null;
        cleanupMajor();
    }

    /** Called by the owning test's after hook even when approval fails after a positive create identity. */
    public void cleanupCaptured() {
        if (captured != null) {
            cleanup(captured);
        } else {
            cleanupMajor();
        }
    }

    public String assertHttpState(long id, DraftCasefileEntity expected, String label) {
        try {
            MockHttpServletResponse response = mvc.perform(get("/draft-casefiles/{id}", id)
                .with(authentication(DraftCasefileHttpFixture.token((short) 1)))
                .header("X-User-IP", "192.0.2.1")).andReturn().getResponse();
            assertEquals(200, response.getStatus(), "Committed owned draft must be readable");
            JsonNode body = json.readTree(response.getContentAsString());
            schemas.validate("DraftCasefileGetResponse", bytes(body.toString()));
            assertEquals(expected.getCasefileStatus().name(), body.path("casefile_status").asString());
            assertEquals(label, body.path("casefile_status_name").asString());
            assertMetadata(body, expected);
            assertTrue(Objects.equals(json.readTree(expected.getCasefile()), body.get("casefile"))
                && Objects.equals(json.readTree(expected.getCasefileSnapshot()), body.get("casefile_snapshot"))
                && Objects.equals(json.readTree(expected.getTimelineData()), body.get("timeline_data")),
                "HTTP state must preserve committed casefile, snapshot and timeline");
            String etag = strongEtag(response);
            assertEquals("\"" + expected.getVersionNumber() + "\"", etag);
            return etag;
        } catch (Exception failure) {
            throw new AssertionError("Owned publication state could not be read safely");
        }
    }

    public void assertSameDraft(DraftCasefileEntity expected, DraftCasefileEntity actual) {
        // Entity strings contain synthetic personal data: compare without rendering either row on failure.
        assertTrue(Objects.equals(expected.getDraftCasefileId(), actual.getDraftCasefileId())
            && Objects.equals(expected.getBusinessUnitId(), actual.getBusinessUnitId())
            && Objects.equals(expected.getCreatedDate(), actual.getCreatedDate())
            && Objects.equals(expected.getSubmittedBy(), actual.getSubmittedBy())
            && Objects.equals(expected.getSubmittedByName(), actual.getSubmittedByName())
            && Objects.equals(expected.getValidatedDate(), actual.getValidatedDate())
            && Objects.equals(expected.getValidatedBy(), actual.getValidatedBy())
            && Objects.equals(expected.getValidatedByName(), actual.getValidatedByName())
            && Objects.equals(expected.getCasefile(), actual.getCasefile())
            && Objects.equals(expected.getCasefileSnapshot(), actual.getCasefileSnapshot())
            && Objects.equals(expected.getCasefileType(), actual.getCasefileType())
            && expected.getCasefileStatus() == actual.getCasefileStatus()
            && Objects.equals(expected.getCasefileStatusDate(), actual.getCasefileStatusDate())
            && Objects.equals(expected.getStatusMessage(), actual.getStatusMessage())
            && Objects.equals(expected.getTimelineData(), actual.getTimelineData())
            && Objects.equals(expected.getAccountNumber(), actual.getAccountNumber())
            && Objects.equals(expected.getAccountId(), actual.getAccountId())
            && Objects.equals(expected.getVersionNumber(), actual.getVersionNumber()),
            "Owned draft changed unexpectedly");
    }

    private void cleanupMajor() {
        if (majorId != null) {
            Long id = majorId;
            independently(() -> {
                MajorCreditorEntity row = majorCreditors.findById(id).orElseThrow();
                assertTrue(MAJOR_CODE.equals(row.getMajorCreditorCode()) && row.getBusinessUnitId() == 1,
                    "Major Creditor cleanup ownership differs");
                majorCreditors.delete(row);
                majorCreditors.flush();
                return null;
            });
            assertTrue(majorCreditors.findById(id).isEmpty(), "Case-owned Major Creditor cleanup must be committed");
            majorId = null;
        }
    }

    private void assertMetadata(JsonNode body, DraftCasefileEntity expected) {
        assertTrue(body.path("draft_casefile_id").longValue() == expected.getDraftCasefileId()
            && body.path("business_unit_id").intValue() == expected.getBusinessUnitId()
            && Objects.equals(body.path("submitted_by").asString(), expected.getSubmittedBy())
            && Objects.equals(body.path("submitted_by_name").asString(), expected.getSubmittedByName())
            && Objects.equals(body.path("validated_by").asString(), expected.getValidatedBy())
            && Objects.equals(body.path("validated_by_name").asString(), expected.getValidatedByName())
            && Objects.equals(body.path("casefile_type").asString(), expected.getCasefileType())
            && Objects.equals(body.path("casefile_status").asString(), expected.getCasefileStatus().name())
            && timestampEquals(body.path("created_date"), expected.getCreatedDate())
            && timestampEquals(body.path("validated_date"), expected.getValidatedDate())
            && timestampEquals(body.path("casefile_status_date"), expected.getCasefileStatusDate())
            && (expected.getStatusMessage() == null ? body.path("status_message").isNull()
                : expected.getStatusMessage().equals(body.path("status_message").asString())),
            "HTTP response metadata must match the independently committed draft");
    }

    private boolean timestampEquals(JsonNode value, LocalDateTime expected) {
        return expected == null ? value.isNull()
            : value.isString() && expected.toInstant(ZoneOffset.UTC).equals(Instant.parse(value.asString()));
    }

    private void assertHistory(DraftCasefileEntity original, DraftCasefileEntity pending, JsonNode approved) {
        JsonNode submitted = json.readTree(original.getTimelineData());
        final JsonNode history = approved.path("timeline_data");
        assertEquals(1, submitted.size(), "Fresh creation has one submission event");
        assertEquals("Submitted", submitted.get(0).path("status").asString());
        assertEquals(original.getSubmittedByName(), submitted.get(0).path("username").asString());
        assertTrue(timestampEquals(submitted.get(0).path("status_date"), original.getCasefileStatusDate()),
            "Submission history must preserve the original status timestamp");
        assertEquals(2, history.size(), "Fresh independent approval appends one event");
        assertTrue(submitted.get(0).equals(history.get(0)), "Approval preserves submission history exactly");
        JsonNode entry = history.get(1);
        assertEquals("Approved", entry.path("status").asString());
        assertEquals(pending.getValidatedByName(), entry.path("username").asString());
        assertEquals(pending.getValidatedDate().toInstant(ZoneOffset.UTC),
            Instant.parse(entry.path("status_date").asString()));
        assertTrue(!entry.hasNonNull("reason_text"), "Approval must not invent a reason");
    }

    private ObjectNode request(String marker, boolean withMinors) throws Exception {
        ObjectNode request = (ObjectNode) json.readTree(DraftCasefileHttpFixture.requestBody());
        ObjectNode casefile = (ObjectNode) request.get("casefile");
        ObjectNode account = (ObjectNode) casefile.get("respondent_account");
        account.put("remo_reference", marker).put("originator_name", "Synthetic Court")
            .put("central_authority_reference", "Synthetic CA reference").put("account_comment", "Synthetic comment");
        account.putObject("notes").put("note_text", "Synthetic publication case note");
        ObjectNode respondent = (ObjectNode) account.get("respondent");
        enrichParty((ObjectNode) respondent.get("party_details"), "Respondent");
        ObjectNode debtor = respondent.putObject("debtor_details").put("employer_name", "Synthetic employer")
            .put("employee_reference", "Synthetic employee").put("employer_email_address", "employer@example.com")
            .put("employer_telephone_number", "02000000001");
        debtor.set("employer_address", address("Synthetic employer address"));
        respondent.set("third_party_details", thirdParty("Respondent contact"));
        ObjectNode applicant = (ObjectNode) casefile.get("applicant");
        enrichParty((ObjectNode) applicant.get("party_details"), "Applicant");
        applicant.set("third_party_details", thirdParty("Applicant contact"));
        ArrayNode terms = (ArrayNode) account.at("/order_details/order_terms");
        ObjectNode base = ((ObjectNode) terms.get(0)).deepCopy();
        ((ArrayNode) base.get("result_responses")).addObject().put("parameter_name", "Arrears").put("response", "5.00");
        terms.set(0, base);
        ArrayNode minors = casefile.putArray("minor_creditors");
        if (withMinors) {
            for (int sequence : new int[]{7, 23}) {
                ObjectNode minor = applicant.deepCopy();
                minor.remove("third_party_details");
                minor.put("creditor_sequence", sequence);
                ((ObjectNode) minor.at("/party_details/individual_details"))
                    .put("surname", "Synthetic Minor " + sequence);
                minors.add(minor);
                ObjectNode term = base.deepCopy().put("creditor_type", "Minor Creditor")
                    .put("minor_creditor_sequence", sequence);
                ((ObjectNode) term.at("/result_responses/0")).put("response", sequence == 7 ? "25.00" : "35.00");
                terms.add(term);
            }
        }
        for (String amount : new String[]{"12.00", "18.00"}) {
            ObjectNode term = base.deepCopy().put("creditor_type", "Major Creditor")
                .put("major_creditor_code", MAJOR_CODE);
            ((ObjectNode) term.at("/result_responses/0")).put("response", amount);
            terms.add(term);
        }
        return request;
    }

    private void enrichParty(ObjectNode party, String role) {
        ((ObjectNode) party.get("individual_details")).put("forenames", "Synthetic " + role)
            .put("surname", "QA " + role).put("date_of_birth", "1990-01-02");
        party.putArray("aliases").addObject().put("sequence_number", 1)
            .put("forenames", "Synthetic alias").put("surname", role);
        party.putObject("contact_details").put("primary_email_address", "qa@example.com")
            .put("main_telephone_number", "02000000002");
    }

    private ObjectNode address(String firstLine) {
        return json.createObjectNode().put("address_line_1", firstLine).put("address_line_2", "Synthetic district")
            .put("postcode", "ZZ1 1ZZ").put("cjs_code", 1);
    }

    private ObjectNode thirdParty(String role) {
        ObjectNode contact = json.createObjectNode().put("name", "Synthetic " + role)
            .put("relationship", "Synthetic representative").put("reference", "Synthetic contact reference");
        contact.set("address", address("Synthetic contact address"));
        return contact;
    }

    private String strongEtag(MockHttpServletResponse response) {
        String etag = response.getHeader("ETag");
        assertTrue(etag != null && etag.matches("\"[0-9]+\""), "Response must carry a strong numeric ETag");
        return etag;
    }

    private byte[] bytes(String value) {
        return value.getBytes(StandardCharsets.UTF_8);
    }

    private <T> T independently(Supplier<T> action) {
        TransactionTemplate transaction = new TransactionTemplate(transactions);
        transaction.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
        return transaction.execute(status -> action.get());
    }

    public record OwnedDraft(long id, String marker, String payload, JsonNode approved, String etag,
                             PublicationQaGraph.Snapshot graphBefore) {
        @Override
        public String toString() {
            return "Owned publication QA draft";
        }
    }
}
