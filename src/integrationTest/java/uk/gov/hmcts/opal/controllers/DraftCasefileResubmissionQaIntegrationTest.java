package uk.gov.hmcts.opal.controllers;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.context.jdbc.Sql;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;
import tools.jackson.databind.node.ArrayNode;
import tools.jackson.databind.node.ObjectNode;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.common.spring.security.OpalJwtAuthenticationToken;
import uk.gov.hmcts.opal.common.user.authorisation.model.BusinessUnitUser;
import uk.gov.hmcts.opal.common.user.authorisation.model.Domain;
import uk.gov.hmcts.opal.common.user.authorisation.model.DomainBusinessUnitUsers;
import uk.gov.hmcts.opal.common.user.authorisation.model.Permission;
import uk.gov.hmcts.opal.common.user.authorisation.model.UserStateV2;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.logging.integration.service.LoggingService;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.service.messaging.DraftCasefileQueuePublisherImpl;
import uk.gov.hmcts.opal.support.DraftCasefileHttpFixture;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.test.context.jdbc.Sql.ExecutionPhase.AFTER_TEST_METHOD;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
@TestPropertySource(properties = {"spring.flyway.locations=classpath:db/migration/ddl", "opal.redis.enabled=false",
    "management.health.redis.enabled=false", "spring.jpa.open-in-view=false",
    "opal.testing-support-endpoints.enabled=true"})
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@Sql({"/draft-casefile/reference-fixtures.sql", "/draft-casefile/cleanup-scope-fixtures.sql"})
@Sql(scripts = "/draft-casefile/cleanup-scope-cleanup.sql", executionPhase = AFTER_TEST_METHOD)
class DraftCasefileResubmissionQaIntegrationTest extends BaseIntegrationTest {

    private static final JsonMapper JSON = JsonMapper.builder().build();
    private static final String DRAFT_PATH = "/draft-casefiles/{id}";
    private static final String REASON = "Synthetic resubmission correction required";
    private static final Permission CREATE = new Permission(21L, "Create and Manage Draft Casefiles");
    private static final Permission CHECK = new Permission(22L, "Check and validate draft Casefiles");
    private static final Actor CREATOR = new Actor(123L, "BUU-CREATOR", "Synthetic Original Inputter");
    private static final Actor HANDOVER = new Actor(124L, "BUU-HANDOVER", "Synthetic Handover Inputter");
    private static final Actor CHECKER = new Actor(125L, "BUU-CHECKER", "Synthetic Independent Checker");

    @Autowired
    private MockMvc mvc;
    @Autowired
    private DraftCasefileRepository drafts;
    @MockitoBean
    private DraftCasefileQueuePublisherImpl delegate;
    @MockitoBean
    private LoggingService logging;

    @BeforeEach
    void setUp() {
        when(logging.personalDataAccessLogAsync(any())).thenReturn(true);
    }

    @ParameterizedTest
    @ValueSource(booleans = {false, true})
    void correctedCasefileCommitsForOriginalOrDifferentInputter(boolean handover) throws Exception {
        OwnedDraft draft = rejectedDraft();
        Actor inputter = handover ? HANDOVER : CREATOR;
        assertSuccessfulReplacement(draft, inputter);
        cleanup(draft, inputter);
    }

    @Test
    void latestInputterWithBothPermissionsCannotRejectAfterHandover() throws Exception {
        OwnedDraft draft = rejectedDraft();
        assertSuccessfulReplacement(draft, HANDOVER);
        State before = state(draft);
        // The identical authenticated identity has both 21 and 22 for BU1 on PUT and PATCH.
        final String operation = assertProblem(reject(draft, token(HANDOVER), before.etag()), 403, "forbidden", draft);
        assertUnchanged(draft, before);

        verifyNoInteractions(delegate);
        cleanup(draft, HANDOVER);
        assertCanonicalOperationId(operation);
    }

    @Test
    void obsoleteVersionConflictsWhileCurrentDraftIsStillEligibleAndRejected() throws Exception {
        OwnedDraft draft = rejectedDraft();
        String obsolete = state(draft).etag();
        assertThat(obsolete).isEqualTo("\"1\"");
        replace(draft, token(CREATOR), obsolete, correction(draft)).andExpect(status().isOk());
        reject(draft, token(CHECKER), state(draft).etag()).andExpect(status().isOk());
        State current = state(draft);
        assertThat(current.body().path("casefile_status").asString()).isEqualTo("REJECTED");
        assertThat(current.entity().getVersionNumber()).isEqualTo(3L);
        assertThat(current.etag()).isEqualTo("\"3\"");
        assertRejectedReplacement(draft, token(CREATOR), obsolete, correction(draft), 409, "optimistic-locking");
    }

    @ParameterizedTest
    @ValueSource(strings = {"SUBMITTED", "RESUBMITTED"})
    void replacementRequiresRejectedLifecycle(String source) throws Exception {
        OwnedDraft draft = submit();
        if (source.equals("RESUBMITTED")) {
            reject(draft, token(CHECKER), state(draft).etag()).andExpect(status().isOk());
            replace(draft, token(CREATOR), state(draft).etag(), correction(draft)).andExpect(status().isOk());
        }
        State before = state(draft);
        assertThat(before.body().path("casefile_status").asString()).isEqualTo(source);
        assertRejectedReplacement(draft, token(CREATOR), before.etag(), correction(draft), 409, "resource-conflict");
    }

    @ParameterizedTest
    @CsvSource({"application,400,opal-api-error", "none,403,forbidden", "foreign,403,forbidden",
        "supplied-business-unit,409,resource-conflict"})
    void invalidOrUnauthorisedCorrectionPreservesEntireDraft(String failure, int expectedStatus, String type)
        throws Exception {
        OwnedDraft draft = rejectedDraft();
        ObjectNode corrected = correction(draft);
        OpalJwtAuthenticationToken caller = token(CREATOR);
        switch (failure) {
            case "application" -> ((ObjectNode) corrected.at("/casefile/respondent_account"))
                .put("application_code", "ZZ99999");
            case "none" -> caller = token(CREATOR, (short) 1, Set.of());
            case "foreign" -> caller = token(HANDOVER, (short) 2, Set.of(CREATE));
            case "supplied-business-unit" -> corrected.put("business_unit_id", 2);
            default -> throw new IllegalArgumentException("Unknown test example");
        }
        assertRejectedReplacement(draft, caller, state(draft).etag(), corrected, expectedStatus, type);
    }

    private void assertSuccessfulReplacement(OwnedDraft draft, Actor inputter) throws Exception {
        State before = state(draft);
        assertThat(before.body().path("casefile_status").asString()).isEqualTo("REJECTED");
        ObjectNode corrected = correction(draft);
        assertThat(corrected.at("/casefile/minor_creditors/1"))
            .isEqualTo(before.body().at("/casefile/minor_creditors/1"));
        for (String path : List.of("/casefile/respondent_account/respondent", "/casefile/applicant",
            "/casefile/minor_creditors/0")) {
            assertThat(corrected.at(path)).isNotEqualTo(before.body().at(path));
        }
        assertThat(before.body().path("status_message").asString()).isEqualTo(REASON);
        clearInvocations(delegate);
        final Instant earliest = Instant.now();
        MockHttpServletResponse response = replace(draft, token(inputter), before.etag(), corrected)
            .andExpect(status().isOk()).andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
            .andReturn().getResponse();
        final Instant latest = Instant.now();
        JsonNode result = JSON.readTree(response.getContentAsString());
        State after = state(draft);
        assertThat(after.body()).isEqualTo(result);
        assertThat(after.etag()).isEqualTo(strongEtag(response)).isNotEqualTo(before.etag());
        assertThat(after.entity().getVersionNumber()).isEqualTo(before.entity().getVersionNumber() + 1);
        assertThat(result.path("casefile_status").asString()).isEqualTo("RESUBMITTED");
        assertThat(result.path("casefile_status_name").asString()).isEqualTo("Resubmitted");
        assertThat(result.has("version_number")).isFalse();
        assertThat(after.entity().getCasefileStatus().name()).isEqualTo("RESUBMITTED");
        assertThat(result.path("submitted_by").asString()).isEqualTo(inputter.businessUnitUserId());
        assertThat(result.path("submitted_by_name").asString()).isEqualTo(inputter.name());
        assertThat(after.entity().getSubmittedBy()).isEqualTo(inputter.businessUnitUserId());
        assertThat(after.entity().getSubmittedByName()).isEqualTo(inputter.name());
        assertThat(result.get("casefile")).isEqualTo(corrected.get("casefile"));
        assertThat(JSON.readTree(after.entity().getCasefile())).isEqualTo(corrected.get("casefile"));
        for (String field : List.of("draft_casefile_id", "business_unit_id", "created_date", "casefile_type",
            "status_message", "validated_by", "validated_by_name", "validated_date", "account_id", "account_number")) {
            assertThat(result.has(field)).as(field + " presence").isEqualTo(before.body().has(field));
            assertThat(result.get(field)).as(field).isEqualTo(before.body().get(field));
        }
        // Only these server-maintained replacement columns may differ; all other persisted columns are compared.
        assertThat(after.entity()).usingRecursiveComparison().ignoringFields("versionNumber", "casefileStatus",
            "casefileStatusDate", "submittedBy", "submittedByName", "casefile", "casefileSnapshot", "timelineData")
            .isEqualTo(before.entity());
        OffsetDateTime changedAt = utcTimestamp(result.path("casefile_status_date"));
        assertThat(changedAt.toInstant()).isBetween(earliest, latest);
        assertThat(after.entity().getCasefileStatusDate()).isEqualTo(changedAt.toLocalDateTime());
        assertHistory(before.body(), result, inputter, changedAt);
        assertThat(JSON.readTree(after.entity().getTimelineData())).isEqualTo(result.get("timeline_data"));
        assertSnapshot(result.get("casefile_snapshot"));
        assertThat(JSON.readTree(after.entity().getCasefileSnapshot())).isEqualTo(result.get("casefile_snapshot"));

        verifyNoInteractions(delegate);

    }

    private void assertSnapshot(JsonNode snapshot) {
        ObjectNode expected = JSON.createObjectNode();
        expected.set("respondent_account", account("respondent_name", "CORRECTED RESPONDENT, Synthetic"));
        expected.set("applicant_account", account("applicant_name", "CORRECTED APPLICANT, Synthetic"));
        ArrayNode minors = expected.putArray("minor_creditor_accounts");
        minors.add(account("name", "CORRECTED MINOR SEVEN, Synthetic").put("creditor_sequence", 7));
        minors.add(account("name", "MINOR TWENTY THREE, Synthetic").put("creditor_sequence", 23));
        assertThat(snapshot).isEqualTo(expected);
    }

    private ObjectNode account(String nameField, String name) {
        return JSON.createObjectNode().putNull("account_id").putNull("account_number").put(nameField, name);
    }

    private void assertHistory(JsonNode before, JsonNode after, Actor inputter, OffsetDateTime changedAt) {
        JsonNode prior = before.path("timeline_data");
        JsonNode current = after.path("timeline_data");
        assertThat(prior.size()).isGreaterThanOrEqualTo(2);
        assertThat(prior.get(0).path("status").asString()).isEqualTo("Submitted");
        assertThat(prior.get(prior.size() - 1).path("status").asString()).isEqualTo("Rejected");
        assertThat(prior.get(prior.size() - 1).get("reason_text")).isEqualTo(before.get("status_message"));
        assertThat(current.size()).isEqualTo(prior.size() + 1);
        for (int index = 0; index < prior.size(); index++) {
            assertThat(current.get(index)).isEqualTo(prior.get(index));
            assertThat(changedAt.toInstant()).isAfterOrEqualTo(utcTimestamp(prior.get(index).get("status_date"))
                .toInstant());
        }
        JsonNode added = current.get(prior.size());
        assertThat(added.propertyNames()).containsExactlyInAnyOrder("status", "username", "status_date");
        assertThat(added.path("status").asString()).isEqualTo("Resubmitted");
        assertThat(added.path("username").asString()).isEqualTo(inputter.name());
        assertThat(utcTimestamp(added.get("status_date"))).isEqualTo(changedAt);
    }

    private void assertRejectedReplacement(OwnedDraft draft, OpalJwtAuthenticationToken caller, String etag,
                                           ObjectNode corrected, int expectedStatus, String type) throws Exception {
        State before = state(draft);
        clearInvocations(delegate);
        final String operation = assertProblem(replace(draft, caller, etag, corrected), expectedStatus, type, draft);
        assertUnchanged(draft, before);

        verifyNoInteractions(delegate);
        cleanup(draft, draft.creator());
        assertCanonicalOperationId(operation);
    }

    private String assertProblem(ResultActions result, int expectedStatus, String type, OwnedDraft draft)
        throws Exception {
        MockHttpServletResponse response = result.andExpect(status().is(expectedStatus))
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
            .andExpect(header().doesNotExist("ETag")).andExpect(header().doesNotExist("Location"))
            .andReturn().getResponse();
        JsonNode problem = JSON.readTree(response.getContentAsString());
        assertThat(problem.propertyNames()).containsExactlyInAnyOrder("type", "title", "status", "detail",
            "retriable", "operation_id", "instance");
        assertThat(problem.path("status").intValue()).isEqualTo(expectedStatus);
        assertThat(problem.path("type").asString()).isEqualTo("https://hmcts.gov.uk/problems/" + type);
        assertThat(problem.path("title").asString()).isEqualTo(switch (expectedStatus) {
            case 400 -> "Bad Request";
            case 403 -> "Forbidden";
            default -> "Conflict";
        });
        assertThat(problem.path("detail").asString()).isEqualTo(switch (type) {
            case "opal-api-error" -> "An error occurred while processing your request";
            case "forbidden" -> "You do not have permission to access this resource";
            case "optimistic-locking" -> "Conflict updating record. Please try again.";
            default -> "A conflict occurred with the requested resource";
        });
        assertThat(problem.path("retriable").isBoolean()).isTrue();
        assertThat(problem.path("retriable").booleanValue()).isFalse();
        String operation = problem.path("operation_id").asString();
        assertThat(operation).isNotBlank();
        assertThat(problem.path("instance").asString())
            .isEqualTo("https://hmcts.gov.uk/problems/instance/" + operation);
        for (JsonNode value : problem) {
            assertThat(value.isValueNode()).isTrue();
        }
        assertThat(response.getContentAsString()).doesNotContain(draft.marker(), REASON, "Synthetic", "BUU-",
            "ZZ99999", "stackTrace", "resourceType", "resourceId", "Exception", "amqp://");
        return operation;
    }

    private void assertCanonicalOperationId(String operation) {
        assertThat(UUID.fromString(operation).toString()).isEqualTo(operation);
    }

    private OwnedDraft rejectedDraft() throws Exception {
        OwnedDraft draft = submit();
        reject(draft, token(CHECKER), state(draft).etag()).andExpect(status().isOk());
        return draft;
    }

    private OwnedDraft submit() throws Exception {
        String marker = "E2E-" + UUID.randomUUID().toString().replace("-", "").substring(0, 16);
        MockHttpServletResponse created = mvc.perform(post("/draft-casefiles").with(authentication(token(CREATOR)))
            .header("X-User-IP", "192.0.2.1").contentType(MediaType.APPLICATION_JSON)
            .content(request(marker).toString())).andExpect(status().isCreated()).andReturn().getResponse();
        long id = JSON.readTree(created.getContentAsString()).path("draft_casefile_id").longValue();
        assertThat(id).isPositive();
        return new OwnedDraft(id, marker, CREATOR);
    }

    private ObjectNode request(String marker) throws Exception {
        ObjectNode request = (ObjectNode) JSON.readTree(DraftCasefileHttpFixture.requestBody());
        ObjectNode casefile = (ObjectNode) request.get("casefile");
        ((ObjectNode) casefile.get("respondent_account")).put("remo_reference", marker);
        person(casefile, "/respondent_account/respondent", "Respondent");
        person(casefile, "/applicant", "Applicant");
        ArrayNode minors = casefile.putArray("minor_creditors");
        ArrayNode terms = (ArrayNode) casefile.at("/respondent_account/order_details/order_terms");
        for (int index = 0; index < 2; index++) {
            int sequence = index == 0 ? 7 : 23;
            ObjectNode minor = ((ObjectNode) casefile.get("applicant")).deepCopy();
            minor.put("creditor_sequence", sequence);
            person(minor, "", index == 0 ? "Minor Seven" : "Minor Twenty Three");
            minors.add(minor);
            ObjectNode term = ((ObjectNode) terms.get(0)).deepCopy();
            term.put("creditor_type", "Minor Creditor").put("minor_creditor_sequence", sequence);
            ((ObjectNode) term.at("/result_responses/0")).put("response", index == 0 ? "25.00" : "35.00");
            terms.add(term);
        }
        return request;
    }

    private ObjectNode correction(OwnedDraft draft) throws Exception {
        ObjectNode corrected = request(draft.marker());
        corrected.remove("casefile_type");
        ObjectNode casefile = (ObjectNode) corrected.get("casefile");
        person(casefile, "/respondent_account/respondent", "Corrected Respondent");
        person(casefile, "/applicant", "Corrected Applicant");
        person(casefile, "/minor_creditors/0", "Corrected Minor Seven");
        return corrected;
    }

    private void person(ObjectNode root, String path, String surname) {
        ((ObjectNode) root.at(path + "/party_details/individual_details"))
            .put("forenames", "Synthetic").put("surname", surname);
    }

    private ResultActions replace(OwnedDraft draft, OpalJwtAuthenticationToken caller, String etag, ObjectNode body)
        throws Exception {
        return mvc.perform(put(DRAFT_PATH, draft.id()).with(authentication(caller)).header("If-Match", etag)
            .header("X-User-IP", "192.0.2.1").contentType(MediaType.APPLICATION_JSON).content(body.toString()));
    }

    private ResultActions reject(OwnedDraft draft, OpalJwtAuthenticationToken caller, String etag) throws Exception {
        ObjectNode body = JSON.createObjectNode().put("business_unit_id", 1).put("casefile_status", "REJECTED")
            .put("status_message", REASON);
        return mvc.perform(patch(DRAFT_PATH, draft.id()).with(authentication(caller)).header("If-Match", etag)
            .header("X-User-IP", "192.0.2.1").contentType(MediaType.APPLICATION_JSON).content(body.toString()));
    }

    private State state(OwnedDraft draft) throws Exception {
        MockHttpServletResponse response = mvc.perform(get(DRAFT_PATH, draft.id())
            .with(authentication(token(draft.creator()))).header("X-User-IP", "192.0.2.1"))
            .andExpect(status().isOk()).andReturn().getResponse();
        // No test transaction or open-in-view context: repository reads observe committed, detached entities.
        DraftCasefileEntity entity = drafts.findById(draft.id()).orElseThrow();
        String etag = strongEtag(response);
        assertThat(etag).isEqualTo("\"" + entity.getVersionNumber() + "\"");
        return new State(JSON.readTree(response.getContentAsString()), etag, entity);
    }




    private void assertUnchanged(OwnedDraft draft, State before) throws Exception {
        State after = state(draft);
        assertThat(after.entity()).usingRecursiveComparison().isEqualTo(before.entity());
        assertThat(after.body()).isEqualTo(before.body());
        assertThat(after.etag()).isEqualTo(before.etag());
    }

    private void cleanup(OwnedDraft draft, Actor owner) throws Exception {
        mvc.perform(delete("/testing-support/draft-casefiles/{id}", draft.id()).with(authentication(token(owner)))
            .header("Test-Run-Reference", draft.marker())).andExpect(status().isNoContent());
        assertThat(drafts.findById(draft.id())).isEmpty();

    }

    private String strongEtag(MockHttpServletResponse response) {
        String etag = response.getHeader("ETag");
        assertThat(etag).matches("\"[0-9]+\"");
        return etag;
    }

    private OffsetDateTime utcTimestamp(JsonNode value) {
        OffsetDateTime timestamp = OffsetDateTime.parse(value.asString());
        assertThat(timestamp.getOffset()).isEqualTo(ZoneOffset.UTC);
        return timestamp;
    }

    private OpalJwtAuthenticationToken token(Actor actor) {
        return token(actor, (short) 1, Set.of(CREATE, CHECK));
    }

    private OpalJwtAuthenticationToken token(Actor actor, short businessUnitId, Set<Permission> permissions) {
        UserStateV2 user = UserStateV2.builder().userId(actor.userId()).name(actor.name())
            .domains(Map.of(Domain.MAINTENANCE, new DomainBusinessUnitUsers(List.of(
                new BusinessUnitUser(actor.businessUnitUserId(), businessUnitId, permissions))))).build();
        Jwt jwt = Jwt.withTokenValue("synthetic-test-token").header("alg", "none").claim("sub", "synthetic-user")
            .issuedAt(Instant.EPOCH).expiresAt(Instant.EPOCH.plusSeconds(60)).build();
        return new OpalJwtAuthenticationToken(user, Domain.MAINTENANCE, jwt, List.of(), null);
    }

    private record Actor(long userId, String businessUnitUserId, String name) { }

    private record OwnedDraft(long id, String marker, Actor creator) { }

    private record State(JsonNode body, String etag, DraftCasefileEntity entity) { }
}
