package uk.gov.hmcts.opal.assertions;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import io.restassured.builder.ResponseBuilder;
import io.restassured.response.Response;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.function.Executable;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.ValueSource;
import uk.gov.hmcts.opal.config.JacksonCompatibilityConfiguration;
import uk.gov.hmcts.opal.data.DraftCasefileRequestFactory;
import uk.gov.hmcts.opal.generated.model.CasefileSnapshot;
import uk.gov.hmcts.opal.generated.model.CasefileTimelineEntry;
import uk.gov.hmcts.opal.generated.model.CasefileType;
import uk.gov.hmcts.opal.generated.model.DraftCasefileGetResponse;
import uk.gov.hmcts.opal.mapper.DraftCasefileMapper;
import tools.jackson.databind.json.JsonMapper;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.function.Consumer;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class DraftCasefilePublicationAssertionsTest {
    private static final ObjectMapper JSON = new JacksonCompatibilityConfiguration().objectMapper();
    private static final String MARKER = "E2E-550e8400e29b41d4";
    private static final String CREATED = "2026-10-23T10:00:00Z";
    private static final String APPROVED = "2026-10-23T11:00:00Z";
    private static final String TERMINAL = "2026-10-23T11:00:01Z";
    private static final String APPROVAL_ETAG = "\"2\"";
    private static final String TERMINAL_ETAG = "\"3\"";
    private static final String FAILURE = "Publication failed; contact support";
    private static final String[] ACCOUNTS = {"respondent_account", "applicant_account",
        "minor_creditor_accounts/0", "minor_creditor_accounts/1"};

    @Test
    void acceptsCompletePublishedAndFailedDtoResponses() throws Exception {
        ObjectNode published = published();
        assertTrue(DraftCasefilePublicationAssertions.published(response(published), approved(), APPROVAL_ETAG)
            .equals(published));
        ObjectNode failed = failed();
        assertTrue(DraftCasefilePublicationAssertions.failed(response(failed), approved(), APPROVAL_ETAG)
            .equals(failed));
    }

    @ParameterizedTest
    @ValueSource(booleans = {false, true})
    void acceptsZeroMinorsAndSequenceMappingIndependentOfArrayOrder(boolean hasMinors) throws Exception {
        ObjectNode before = approved(hasMinors);
        ObjectNode after = published(before);
        ArrayNode minors = (ArrayNode) after.at("/casefile_snapshot/minor_creditor_accounts");
        if (hasMinors) {
            minors.add(minors.remove(0));
        }
        assertDoesNotThrow(() -> DraftCasefilePublicationAssertions.published(response(after), before, APPROVAL_ETAG));
        ObjectNode failed = terminal(before, false);
        assertDoesNotThrow(() -> DraftCasefilePublicationAssertions.failed(response(failed), before, APPROVAL_ETAG));
    }

    @ParameterizedTest
    @ValueSource(longs = {1, 9007199254740993L, Long.MAX_VALUE})
    void preservesExactPositiveLongIdentitiesAcrossSeparateSequenceDomains(long id) throws Exception {
        ObjectNode body = published();
        account(body, "respondent_account").put("account_id", id);
        account(body, "applicant_account").put("account_id", id);
        assertDoesNotThrow(() -> DraftCasefilePublicationAssertions.published(response(body),
            approved(), APPROVAL_ETAG));
    }

    @ParameterizedTest
    @ValueSource(strings = {"\"2\"", "\"1\"", "W/\"3\"", "3", "\"-1\"", "\"9223372036854775808\"", ""})
    void rejectsUnadvancedOrMalformedTerminalEtags(String etag) throws Exception {
        assertSafe(() -> DraftCasefilePublicationAssertions.published(response(published(), etag),
            approved(), APPROVAL_ETAG));
        assertSafe(() -> DraftCasefilePublicationAssertions.failed(response(failed(), etag),
            approved(), APPROVAL_ETAG));
    }

    @ParameterizedTest
    @ValueSource(strings = {"W/\"2\"", "2", "\"-1\"", "\"9223372036854775808\"", "", "\"3\""})
    void rejectsInvalidOrUnadvancedApprovalEtags(String etag) throws Exception {
        assertSafe(() -> DraftCasefilePublicationAssertions.published(response(published()), approved(), etag));
        assertSafe(() -> DraftCasefilePublicationAssertions.failed(response(failed()), approved(), etag));
    }

    @Test
    void acceptsNonnegativeEtagBoundariesAndStableExactHeader() throws Exception {
        assertDoesNotThrow(() -> DraftCasefilePublicationAssertions.published(response(published(), "\"1\""),
            approved(), "\"0\""));
        assertDoesNotThrow(() -> DraftCasefilePublicationAssertions.published(
            response(published(), "\"9223372036854775807\""), approved(), "\"9223372036854775806\""));
        ObjectNode body = published();
        assertTrue(DraftCasefilePublicationAssertions.stable(response(body), body, TERMINAL_ETAG).equals(body));
        assertSafe(() -> DraftCasefilePublicationAssertions.stable(response(body, "\"03\""), body, TERMINAL_ETAG));
    }

    @ParameterizedTest
    @ValueSource(strings = {"draft_casefile_id", "business_unit_id", "created_date", "submitted_by",
        "submitted_by_name", "casefile_type", "validated_date", "validated_by", "validated_by_name", "casefile",
        "timeline_data"})
    void rejectsChangedOrMissingImmutableFields(String field) throws Exception {
        rejectBoth(body -> body.put(field, MARKER));
        rejectBoth(body -> body.remove(field));
    }

    @Test
    void preservesOptionalFieldsAndUnknownMetadataByExactPresenceAndValue() throws Exception {
        ObjectNode before = approved().putNull("additional_null");
        before.putObject("additional_metadata").put("retained", true);
        ObjectNode body = published(before);
        assertDoesNotThrow(() -> DraftCasefilePublicationAssertions.published(response(body), before, APPROVAL_ETAG));
        body.remove("additional_null");
        assertSafe(() -> DraftCasefilePublicationAssertions.published(response(body), before, APPROVAL_ETAG));
        body.putNull("additional_null");
        ((ObjectNode) body.path("additional_metadata")).put("retained", false);
        assertSafe(() -> DraftCasefilePublicationAssertions.published(response(body), before, APPROVAL_ETAG));
        rejectBoth(node -> node.putNull("additional_null"));
        for (boolean absent : new boolean[] {false, true}) {
            ObjectNode optional = approved();
            if (absent) {
                optional.remove("status_message");
            }
            assertDoesNotThrow(() -> DraftCasefilePublicationAssertions.published(response(published(optional)),
                optional, APPROVAL_ETAG));
        }
    }

    @ParameterizedTest
    @ValueSource(strings = {"casefile_status", "casefile_status_name"})
    void rejectsMissingWrongOrNullLifecycleLabels(String field) throws Exception {
        rejectBoth(node -> node.remove(field));
        rejectBoth(node -> node.put(field, MARKER));
        rejectBoth(node -> node.putNull(field));
    }

    @ParameterizedTest
    @ValueSource(strings = {"invalid", "2026-10-23", "2026-10-23T11:00:01", "2026-10-23T12:00:01+01:00",
        "2026-10-23T10:59:59Z", "2026-02-30T11:00:01Z"})
    void rejectsMalformedNonUtcOrPrematureLifecycleDates(String date) throws Exception {
        rejectBoth(node -> node.put("casefile_status_date", date));
    }

    @ParameterizedTest
    @ValueSource(strings = {"invalid", "2026-10-23", "2026-10-23T10:00:00", "2026-10-23T11:00:00+01:00"})
    void rejectsMalformedOrNonUtcCreationEvenWhenPreservedExactly(String created) throws Exception {
        ObjectNode before = approved().put("created_date", created);
        assertSafe(() -> DraftCasefilePublicationAssertions.published(response(published(before)),
            before, APPROVAL_ETAG));
        assertSafe(() -> DraftCasefilePublicationAssertions.failed(response(terminal(before, false)),
            before, APPROVAL_ETAG));
    }

    @Test
    void rejectsApprovalPredatingCreationEvenWhenTerminalDateIsLater() throws Exception {
        String earlier = "2026-10-23T09:59:59.999999Z";
        ObjectNode before = approved().put("casefile_status_date", earlier).put("validated_date", earlier);
        ((ObjectNode) before.at("/timeline_data/1")).put("status_date", earlier);
        assertSafe(() -> DraftCasefilePublicationAssertions.published(response(published(before)),
            before, APPROVAL_ETAG));
        assertSafe(() -> DraftCasefilePublicationAssertions.failed(response(terminal(before, false)),
            before, APPROVAL_ETAG));
    }

    @Test
    void acceptsCreationAndApprovalAtTheSameUtcInstant() throws Exception {
        ObjectNode before = approved().put("created_date", APPROVED);
        ((ObjectNode) before.at("/timeline_data/0")).put("status_date", APPROVED);
        assertDoesNotThrow(() -> DraftCasefilePublicationAssertions.published(response(published(before)),
            before, APPROVAL_ETAG));
        assertDoesNotThrow(() -> DraftCasefilePublicationAssertions.failed(response(terminal(before, false)),
            before, APPROVAL_ETAG));
    }

    @Test
    void acceptsEqualApprovalInstantAndUtcZeroOffset() throws Exception {
        ObjectNode body = published().put("casefile_status_date", "2026-10-23T11:00:00+00:00");
        assertDoesNotThrow(() -> DraftCasefilePublicationAssertions.published(response(body),
            approved(), APPROVAL_ETAG));
    }

    @ParameterizedTest
    @ValueSource(strings = {"respondent_account", "applicant_account", "minor_creditor_accounts/0",
        "minor_creditor_accounts/1"})
    void rejectsChangedMissingOrNullDisplayNames(String path) throws Exception {
        String field = path.startsWith("respondent") ? "respondent_name"
            : path.startsWith("applicant") ? "applicant_name" : "name";
        rejectBoth(node -> account(node, path).put(field, MARKER));
        rejectBoth(node -> account(node, path).remove(field));
        rejectBoth(node -> account(node, path).putNull(field));
        ObjectNode before = approved();
        account(before, path).put(field, MARKER);
        ObjectNode body = published(before);
        assertSafe(() -> DraftCasefilePublicationAssertions.published(response(body), before, APPROVAL_ETAG));
    }

    @ParameterizedTest
    @ValueSource(ints = {0, 7, 99})
    void rejectsNonpositiveDuplicateOrUnknownMinorSequences(int sequence) throws Exception {
        rejectBoth(node -> account(node, "minor_creditor_accounts/1").put("creditor_sequence", sequence));
    }

    @Test
    void rejectsMissingWrongTypedOrIncompleteMinorCollections() throws Exception {
        rejectBoth(node -> account(node, "minor_creditor_accounts/0").remove("creditor_sequence"));
        rejectBoth(node -> account(node, "minor_creditor_accounts/0").put("creditor_sequence", "7"));
        rejectBoth(node -> ((ArrayNode) node.at("/casefile_snapshot/minor_creditor_accounts")).remove(1));
        rejectBoth(node -> ((ObjectNode) node.path("casefile_snapshot")).putNull("minor_creditor_accounts"));
    }

    @ParameterizedTest
    @ValueSource(strings = {"0", "-1", "9223372036854775808", "1.0", "9007199254740993.0", "null", "\"1\""})
    void rejectsNonpositiveOverflowAndImpreciseAccountIds(String raw) throws Exception {
        for (String path : ACCOUNTS) {
            ObjectNode body = published();
            account(body, path).set("account_id", JSON.readTree(raw));
            assertSafe(() -> DraftCasefilePublicationAssertions.published(response(body), approved(), APPROVAL_ETAG));
        }
    }

    @ParameterizedTest
    @ValueSource(strings = {"44000001A", "44000001s", "44000001", "440000001S", "abcdefghS", " 44000001S",
        "44000001S ", "", " ", "00000000B", "12345678A", "99999999A"})
    void rejectsAccountNumberFormatAndInvalidCheckLetters(String number) throws Exception {
        for (String path : ACCOUNTS) {
            ObjectNode body = published();
            account(body, path).put("account_number", number);
            assertSafe(() -> DraftCasefilePublicationAssertions.published(response(body), approved(), APPROVAL_ETAG));
        }
    }

    @ParameterizedTest
    @CsvSource({"00000000A", "12345678H", "99999999P"})
    void acceptsIndependentKnownChecksumVectors(String number) throws Exception {
        ObjectNode body = published();
        account(body, "respondent_account").put("account_number", number);
        assertDoesNotThrow(() -> DraftCasefilePublicationAssertions.published(response(body),
            approved(), APPROVAL_ETAG));
    }

    @Test
    void rejectsDuplicateCreditorIdsAndNumbersWithoutConflatingRespondentSequence() throws Exception {
        rejectPublished(body -> account(body, "minor_creditor_accounts/0").put("account_id", 101));
        rejectPublished(body -> account(body, "minor_creditor_accounts/1").put("account_id", 102));
        rejectPublished(body -> account(body, "minor_creditor_accounts/0").put("account_number", "44000002O"));
        rejectPublished(body -> account(body, "minor_creditor_accounts/1").put("account_number", "44000003K"));
    }

    @Test
    void rejectsRespondentAccountNumbersDuplicatedAcrossAllAccountTypes() throws Exception {
        for (String path : new String[] {"applicant_account", "minor_creditor_accounts/0",
            "minor_creditor_accounts/1"}) {
            rejectPublished(body -> account(body, path).put("account_number", "44000001S"));
        }
    }

    @Test
    void requiresExplicitNullFailedIdentitiesAndPositivePublishedIdentities() throws Exception {
        for (String path : ACCOUNTS) {
            for (String field : new String[] {"account_id", "account_number"}) {
                ObjectNode failed = failed();
                account(failed, path).remove(field);
                assertSafe(() -> DraftCasefilePublicationAssertions.failed(response(failed),
                    approved(), APPROVAL_ETAG));
                ObjectNode invented = failed();
                account(invented, path).put(field, MARKER);
                assertSafe(() -> DraftCasefilePublicationAssertions.failed(response(invented),
                    approved(), APPROVAL_ETAG));
                rejectPublished(body -> account(body, path).putNull(field));
                rejectPublished(body -> account(body, path).remove(field));
            }
        }
    }

    @ParameterizedTest
    @ValueSource(strings = {"", " ", "not-an-amount", "Synthetic Applicant", "stack exception",
        "Publication failed E2E-550e8400e29b41d4"})
    void rejectsBlankOrUnsafeFailureMessages(String message) throws Exception {
        ObjectNode body = failed().put("status_message", message);
        assertSafe(() -> DraftCasefilePublicationAssertions.failed(response(body), approved(), APPROVAL_ETAG));
    }

    @Test
    void rejectsMissingNullFailureMessageAndPopulatedSuccessfulMessage() throws Exception {
        ObjectNode body = failed();
        body.remove("status_message");
        assertSafe(() -> DraftCasefilePublicationAssertions.failed(response(body), approved(), APPROVAL_ETAG));
        body.putNull("status_message");
        assertSafe(() -> DraftCasefilePublicationAssertions.failed(response(body), approved(), APPROVAL_ETAG));
        rejectPublished(node -> node.put("status_message", FAILURE));
    }

    @ParameterizedTest
    @ValueSource(strings = {"account_id", "account_number"})
    void forbidsTopLevelIdentityFieldsEvenWhenNull(String field) throws Exception {
        rejectBoth(node -> node.putNull(field));
    }

    @ParameterizedTest
    @ValueSource(strings = {"validated_date", "validated_by", "validated_by_name", "casefile_status",
        "casefile_status_name", "casefile_status_date", "timeline_data", "status_message"})
    void forbidsSnapshotLifecycleCopies(String field) throws Exception {
        rejectBoth(node -> ((ObjectNode) node.path("casefile_snapshot")).putNull(field));
        rejectBoth(node -> account(node, "respondent_account").putNull(field));
    }

    @Test
    void retainsExactHistoryAndInputIncludingNullPresence() throws Exception {
        rejectBoth(node -> ((ObjectNode) node.at("/timeline_data/1")).putNull("reason_text"));
        rejectBoth(node -> ((ArrayNode) node.path("timeline_data")).addObject().put("status", "Published"));
        rejectBoth(node -> ((ObjectNode) node.at("/casefile/respondent_account")).put("remo_reference", "changed"));
        rejectBoth(node -> ((ObjectNode) node.at("/casefile/applicant")).putNull("optional"));
    }

    @Test
    void stableRequiresExactBodyPresenceValuesAndEtag() throws Exception {
        for (ObjectNode terminal : new ObjectNode[] {published(), failed()}) {
            assertDoesNotThrow(() -> DraftCasefilePublicationAssertions.stable(response(terminal),
                terminal, TERMINAL_ETAG));
            ObjectNode changedDate = terminal.deepCopy().put("casefile_status_date", APPROVED);
            assertSafe(() -> DraftCasefilePublicationAssertions.stable(response(changedDate), terminal, TERMINAL_ETAG));
            ObjectNode changed = terminal.deepCopy();
            changed.remove("status_message");
            Response missing = response(changed);
            assertSafe(() -> DraftCasefilePublicationAssertions.stable(missing, terminal, TERMINAL_ETAG));
            assertSafe(() -> DraftCasefilePublicationAssertions.stable(response(terminal, "\"4\""),
                terminal, TERMINAL_ETAG));
        }
    }

    @Test
    void stableRejectsNonterminalBaselinesAndMalformedEtags() throws Exception {
        assertSafe(() -> DraftCasefilePublicationAssertions.stable(response(approved()), approved(), TERMINAL_ETAG));
        assertSafe(() -> DraftCasefilePublicationAssertions.stable(response(published()), published(), "3"));
    }

    @Test
    void rejectsWrongHttpMediaTypeAndMalformedJsonWithoutPrivateDiagnostics() throws Exception {
        for (Response invalid : new Response[] {
            new ResponseBuilder().clone(response(published())).setStatusCode(201).build(),
            new ResponseBuilder().clone(response(published())).setContentType("text/plain").build(),
            new ResponseBuilder().clone(response(published())).setContentType("application/json-invalid").build(),
            new ResponseBuilder().clone(response(published())).setBody("{\"private\":\"" + MARKER).build(),
            new ResponseBuilder().clone(response(published())).setBody(published() + " " + MARKER).build()
        }) {
            assertSafe(() -> DraftCasefilePublicationAssertions.published(invalid, approved(), APPROVAL_ETAG));
            assertSafe(() -> DraftCasefilePublicationAssertions.stable(invalid, published(), TERMINAL_ETAG));
        }
    }

    @Test
    void acceptsLegalOrganisationsAndRetainsTheirExactNamesThroughTerminalAndStableRetrieval() throws Exception {
        ObjectNode before = approved();
        ObjectNode respondent = (ObjectNode) before.at("/casefile/respondent_account/respondent/party_details");
        respondent.put("organisation", true).remove("individual_details");
        respondent.putObject("organisation_details").put("organisation_name", "Synthetic Respondent Organisation");
        ObjectNode applicant = (ObjectNode) before.at("/casefile/applicant/party_details");
        applicant.put("organisation", true).remove("individual_details");
        applicant.putObject("organisation_details").put("organisation_name", "Synthetic Applicant Authority")
            .put("foreign_authority_reference", "SYNTHETIC44");
        // Literal expectations preserve organisation case and do not borrow the snapshot mapper's output.
        account(before, "respondent_account").put("respondent_name", "Synthetic Respondent Organisation");
        account(before, "applicant_account").put("applicant_name", "Synthetic Applicant Authority");
        JsonNode published = DraftCasefilePublicationAssertions.published(response(published(before)),
            before, APPROVAL_ETAG);
        JsonNode failed = DraftCasefilePublicationAssertions.failed(response(terminal(before, false)),
            before, APPROVAL_ETAG);
        for (JsonNode terminal : new JsonNode[] {published, failed}) {
            assertTrue("Synthetic Respondent Organisation".equals(
                terminal.at("/casefile_snapshot/respondent_account/respondent_name").textValue()));
            assertTrue("Synthetic Applicant Authority".equals(
                terminal.at("/casefile_snapshot/applicant_account/applicant_name").textValue()));
            assertDoesNotThrow(() -> DraftCasefilePublicationAssertions.stable(response(terminal),
                terminal, TERMINAL_ETAG));
        }
    }

    @Test
    void acceptsAbsentOptionalSourceForenames() throws Exception {
        ObjectNode before = approved();
        ((ObjectNode) before.at("/casefile/respondent_account/respondent/party_details/individual_details"))
            .remove("forenames");
        account(before, "respondent_account").put("respondent_name", "RESPONDENT");
        assertDoesNotThrow(() -> DraftCasefilePublicationAssertions.published(response(published(before)),
            before, APPROVAL_ETAG));
    }

    @Test
    void rejectsIncompleteOrWrongApprovalBaselines() throws Exception {
        for (String field : new String[] {"casefile_status", "casefile_status_name", "casefile_snapshot",
            "casefile_status_date", "validated_date", "validated_by", "validated_by_name"}) {
            ObjectNode before = approved();
            before.remove(field);
            assertSafe(() -> DraftCasefilePublicationAssertions.published(response(published()),
                before, APPROVAL_ETAG));
        }
        ObjectNode before = approved().put("casefile_status", "SUBMITTED");
        assertSafe(() -> DraftCasefilePublicationAssertions.failed(response(failed()), before, APPROVAL_ETAG));
    }

    private void rejectBoth(Consumer<ObjectNode> mutation) throws Exception {
        rejectPublished(mutation);
        ObjectNode body = failed();
        mutation.accept(body);
        assertSafe(() -> DraftCasefilePublicationAssertions.failed(response(body), approved(), APPROVAL_ETAG));
    }

    private void rejectPublished(Consumer<ObjectNode> mutation) throws Exception {
        ObjectNode body = published();
        mutation.accept(body);
        assertSafe(() -> DraftCasefilePublicationAssertions.published(response(body), approved(), APPROVAL_ETAG));
    }

    private void assertSafe(Executable assertion) {
        AssertionError failure = assertThrows(AssertionError.class, assertion);
        assertNull(failure.getCause());
        for (String privateValue : new String[] {MARKER, "Synthetic", "not-an-amount", "44000001S"}) {
            assertFalse(failure.toString().contains(privateValue));
        }
    }

    private ObjectNode approved() throws Exception {
        return approved(true);
    }

    private ObjectNode approved(boolean minors) throws Exception {
        DraftCasefileRequestFactory factory = new DraftCasefileRequestFactory();
        String request = minors ? factory.withMinorCreditors(MARKER) : factory.valid(MARKER);
        JsonNode casefile = JSON.readTree(request).path("casefile");
        String snapshot = new DraftCasefileMapper(JSON).toSnapshotJson(
            JsonMapper.builder().build().readTree(casefile.toString()));
        DraftCasefileGetResponse dto = new DraftCasefileGetResponse().draftCasefileId(123L)
            .businessUnitId((short) 44).createdDate(OffsetDateTime.parse(CREATED))
            .submittedBy("L044JG").submittedByName("Synthetic Inputter")
            .validatedDate(OffsetDateTime.parse(APPROVED)).validatedBy("L044CK").validatedByName("Synthetic Checker")
            .casefileType(CasefileType.REMO_IN)
            .casefileStatus(DraftCasefileGetResponse.CasefileStatusEnum.PUBLISHING_PENDING)
            .casefileStatusName("Publishing pending").casefileStatusDate(OffsetDateTime.parse(APPROVED))
            .casefileSnapshot(JSON.readValue(snapshot, CasefileSnapshot.class)).statusMessage(null)
            .timelineData(List.of(new CasefileTimelineEntry().username("Synthetic Inputter")
                    .status(CasefileTimelineEntry.StatusEnum.SUBMITTED).statusDate(OffsetDateTime.parse(CREATED)),
                new CasefileTimelineEntry().username("Synthetic Checker")
                    .status(CasefileTimelineEntry.StatusEnum.APPROVED)
                    .statusDate(OffsetDateTime.parse(APPROVED))));
        ObjectNode root = (ObjectNode) JSON.readTree(JSON.writeValueAsString(dto));
        // Preserve the original arbitrary JSON payload across the Jackson 2/3 boundary.
        root.set("casefile", casefile);
        return root;
    }

    private ObjectNode published() throws Exception {
        return published(approved());
    }

    private ObjectNode published(ObjectNode approved) throws Exception {
        ObjectNode body = terminal(approved, true);
        identity(account(body, "respondent_account"), 101, "44000001S");
        identity(account(body, "applicant_account"), 101, "44000002O");
        if (!body.at("/casefile_snapshot/minor_creditor_accounts").isEmpty()) {
            identity(account(body, "minor_creditor_accounts/0"), 102, "44000003K");
            identity(account(body, "minor_creditor_accounts/1"), 103, "44000004G");
        }
        return (ObjectNode) JSON.readTree(body.toString());
    }

    private ObjectNode failed() throws Exception {
        return terminal(approved(), false);
    }

    private ObjectNode terminal(ObjectNode before, boolean published) {
        ObjectNode body = before.deepCopy().put("casefile_status", published ? "PUBLISHED" : "PUBLISHING_FAILED")
            .put("casefile_status_name", published ? "Published" : "Publishing failed")
            .put("casefile_status_date", TERMINAL);
        if (!published) {
            body.put("status_message", FAILURE);
        }
        return body;
    }

    private ObjectNode account(ObjectNode body, String path) {
        return (ObjectNode) body.at("/casefile_snapshot/" + path);
    }

    private void identity(ObjectNode node, long id, String number) {
        node.put("account_id", id).put("account_number", number);
    }

    private Response response(JsonNode body) {
        return response(body, TERMINAL_ETAG);
    }

    private Response response(JsonNode body, String etag) {
        return new ResponseBuilder().setStatusCode(200).setContentType("application/json")
            .setHeader("ETag", etag).setBody(body.toString()).build();
    }
}
