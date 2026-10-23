package uk.gov.hmcts.opal.controllers;

import jakarta.jms.DeliveryMode;
import org.apache.qpid.jms.JmsConnectionFactory;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.Timeout;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jms.JmsException;
import org.springframework.jms.core.JmsTemplate;
import org.springframework.mock.web.MockHttpServletResponse;
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
import uk.gov.hmcts.opal.common.user.authorisation.model.Permission;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.logging.integration.service.LoggingService;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.service.messaging.DraftCasefileQueueMessage;
import uk.gov.hmcts.opal.service.messaging.DraftCasefileQueueMessageValidator;
import uk.gov.hmcts.opal.service.messaging.DraftCasefileQueuePublisherImpl;
import uk.gov.hmcts.opal.support.DraftCasefileHttpFixture;

import java.net.InetAddress;
import java.net.ServerSocket;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicBoolean;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.test.context.jdbc.Sql.ExecutionPhase.AFTER_TEST_METHOD;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
@TestPropertySource(properties = {"spring.flyway.locations=classpath:db/migration/ddl", "opal.redis.enabled=false",
    "management.health.redis.enabled=false", "opal.testing-support-endpoints.enabled=true"})
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@Sql({"/draft-casefile/reference-fixtures.sql", "/draft-casefile/cleanup-scope-fixtures.sql"})
@Sql(scripts = "/draft-casefile/cleanup-scope-cleanup.sql", executionPhase = AFTER_TEST_METHOD)
class DraftCasefileCheckerQaIntegrationTest extends BaseIntegrationTest {

    private static final JsonMapper JSON = JsonMapper.builder().build();
    private static final String DRAFT_PATH = "/draft-casefiles/{id}";
    private static final String EVIDENCE_PATH = "/testing-support/draft-casefiles/{id}/publication-evidence";
    private static final String REASON = "Synthetic checker correction required";
    private static final String ACTOR_NAME = "Synthetic Submitter";
    private static final Permission CREATE = new Permission(21L, "Create and Manage Draft Casefiles");
    private static final Permission CHECK = new Permission(22L, "Check and validate draft Casefiles");

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
    @CsvSource({"SUBMITTED,PUBLISHING_PENDING,Approved", "SUBMITTED,REJECTED,Rejected", "SUBMITTED,DELETED,Deleted",
        "RESUBMITTED,PUBLISHING_PENDING,Approved", "RESUBMITTED,REJECTED,Rejected", "RESUBMITTED,DELETED,Deleted"})
    void checkerDecisionCommitsAndPreservesOwnedCasefile(String source, String target, String event) throws Exception {
        OwnedDraft draft = submit(owner());
        if (source.equals("RESUBMITTED")) {
            resubmit(draft);
        }
        State before = state(draft);
        assertThat(before.body().path("casefile_status").asString()).isEqualTo(source);
        final JsonNode registered = register(draft, before);
        final Instant earliest = Instant.now();
        MockHttpServletResponse response = decision(draft, checker(), before.etag(), target)
            .andExpect(status().isOk()).andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
            .andReturn().getResponse();
        final Instant latest = Instant.now();
        JsonNode result = JSON.readTree(response.getContentAsString());
        State after = state(draft);
        assertThat(after.body()).isEqualTo(result);
        assertThat(after.etag()).isEqualTo(response.getHeader("ETag"));
        assertThat(after.entity().getVersionNumber()).isGreaterThan(before.entity().getVersionNumber());
        assertThat(after.body().path("casefile_status").asString()).isEqualTo(target);
        assertThat(after.entity().getCasefileStatus().name()).isEqualTo(target);
        assertThat(after.entity()).usingRecursiveComparison().ignoringFields("versionNumber", "casefileStatus",
            "casefileStatusDate", "statusMessage", "timelineData", "validatedBy", "validatedByName", "validatedDate")
            .isEqualTo(before.entity());
        for (String field : new String[]{"draft_casefile_id", "business_unit_id", "created_date", "submitted_by",
            "submitted_by_name", "casefile_type", "casefile", "casefile_snapshot", "account_id", "account_number"}) {
            assertThat(result.get(field)).as(field).isEqualTo(before.body().get(field));
        }
        OffsetDateTime decidedAt = utcTimestamp(result.path("casefile_status_date"));
        assertThat(decidedAt.toInstant()).isBetween(earliest, latest);
        assertThat(after.entity().getCasefileStatusDate()).isEqualTo(decidedAt.toLocalDateTime());
        assertHistory(before.body(), result, event, decidedAt, target.equals("PUBLISHING_PENDING"));
        if (target.equals("PUBLISHING_PENDING")) {
            assertThat(after.entity().getValidatedBy()).isEqualTo("BUU-CHECKER");
            assertThat(after.entity().getValidatedByName()).isEqualTo(ACTOR_NAME);
            assertThat(after.entity().getValidatedDate()).isEqualTo(decidedAt.toLocalDateTime());
            assertThat(result.path("validated_by").asString()).isEqualTo("BUU-CHECKER");
            assertThat(result.path("validated_by_name").asString()).isEqualTo(ACTOR_NAME);
            assertThat(utcTimestamp(result.path("validated_date"))).isEqualTo(decidedAt);
            assertThat(after.entity().getStatusMessage()).isNull();
            assertThat(result.path("status_message").isNull()).isTrue();
            assertEvidence(draft, registered, 1, 1, 0, true);
            verify(delegate, times(1)).publish(argThat(message -> message.draftCasefileId().equals(draft.id())));
        } else {
            assertThat(after.entity().getStatusMessage()).isEqualTo(REASON);
            assertThat(result.path("status_message").asString()).isEqualTo(REASON);
            assertThat(after.entity().getValidatedBy()).isEqualTo(before.entity().getValidatedBy());
            assertThat(after.entity().getValidatedByName()).isEqualTo(before.entity().getValidatedByName());
            assertThat(after.entity().getValidatedDate()).isEqualTo(before.entity().getValidatedDate());
            for (String field : new String[]{"validated_by", "validated_by_name", "validated_date"}) {
                assertThat(result.get(field)).as(field).isEqualTo(before.body().get(field));
            }
            assertEvidence(draft, registered, 0, 0, 0, true);
            verifyNoInteractions(delegate);
        }
    }

    @Test
    void creatorWithCheckerPermissionCannotCheckOwnDraft() throws Exception {
        OpalJwtAuthenticationToken creator = DraftCasefileHttpFixture.token((short) 1, 123L, "BUU-1",
            Set.of(CREATE, CHECK));
        OwnedDraft draft = submit(creator);
        assertDeniedDecision(draft, creator, state(draft).etag(), 403, "forbidden");
    }

    @Test
    void checkerWithOnlyForeignBusinessUnitPermissionCannotCheck() throws Exception {
        OwnedDraft draft = submit(owner());
        OpalJwtAuthenticationToken foreignChecker = DraftCasefileHttpFixture.token((short) 2, 124L, "BUU-FOREIGN",
            Set.of(CHECK));
        assertDeniedDecision(draft, foreignChecker, state(draft).etag(), 403, "forbidden");
    }

    @Test
    void originalVersionIsStaleAfterRejectedDraftIsResubmitted() throws Exception {
        OwnedDraft draft = submit(owner());
        resubmit(draft);
        assertThat(state(draft).body().path("casefile_status").asString()).isEqualTo("RESUBMITTED");
        assertDeniedDecision(draft, checker(), draft.createdEtag(), 409, "optimistic-locking");
    }

    @Test
    void rejectedDraftCannotBeApprovedWithCurrentVersion() throws Exception {
        OwnedDraft draft = submit(owner());
        decision(draft, checker(), draft.createdEtag(), "REJECTED").andExpect(status().isOk());
        State rejected = state(draft);
        assertThat(rejected.body().path("casefile_status").asString()).isEqualTo("REJECTED");
        assertDeniedDecision(draft, checker(), rejected.etag(), 409, "resource-conflict");
    }

    @Test
    @Timeout(20)
    void actualTransportFailureRollsBackApprovalAndRecordsUncertainty() throws Exception {
        OwnedDraft draft = submit(owner());
        State before = state(draft);
        final JsonNode registered = register(draft, before);
        clearInvocations(logging);
        AtomicBoolean transportFailed = new AtomicBoolean();
        // Retain the bound socket throughout PATCH: TCP connects but no AMQP peer completes the handshake.
        try (ServerSocket unavailable = new ServerSocket(0, 1, InetAddress.getByName("127.0.0.1"))) {
            JmsConnectionFactory factory = new JmsConnectionFactory("amqp://127.0.0.1:"
                + unavailable.getLocalPort() + "?jms.connectTimeout=500&jms.requestTimeout=500&jms.sendTimeout=500");
            JmsTemplate template = new JmsTemplate(factory);
            template.setDeliveryMode(DeliveryMode.PERSISTENT);
            template.setExplicitQosEnabled(true);
            DraftCasefileQueuePublisherImpl realPublisher = new DraftCasefileQueuePublisherImpl(template, JSON,
                "test-po10617", new DraftCasefileQueueMessageValidator());
            doAnswer(invocation -> {
                DraftCasefileQueueMessage original = invocation.getArgument(0);
                assertThat(original.checkerUserId()).isEqualTo(124L);
                assertThat(original.originatingIpAddress()).isEqualTo("192.0.2.1");
                Instant.parse(original.approvalTimestamp());
                try {
                    realPublisher.publish(original);
                } catch (JmsException exception) {
                    transportFailed.set(true);
                    throw exception;
                }
                return null;
            }).when(delegate).publish(argThat(message -> message.draftCasefileId().equals(draft.id())));
            assertProblem(decision(draft, checker(), before.etag(), "PUBLISHING_PENDING"), 503,
                "messaging-unavailable", draft);
        }
        assertThat(transportFailed).as("real JMS transport failure occurred").isTrue();
        assertThat(drafts.findById(draft.id()).orElseThrow()).usingRecursiveComparison().isEqualTo(before.entity());
        // Check before ordinary GET can emit its legitimate consultation log.
        verifyNoInteractions(logging);
        assertUnchanged(draft, before);
        assertEvidence(draft, registered, 1, 0, 1, false);
        verify(delegate, times(1)).publish(argThat(message -> message.draftCasefileId().equals(draft.id())));
        // Uncertainty records a failed acknowledgement; it does not establish non-delivery.
    }

    private OwnedDraft submit(OpalJwtAuthenticationToken creator) throws Exception {
        String marker = "E2E-" + UUID.randomUUID().toString().replace("-", "").substring(0, 16);
        MockHttpServletResponse created = mvc.perform(post("/draft-casefiles").with(authentication(creator))
            .header("X-User-IP", "192.0.2.1").contentType(MediaType.APPLICATION_JSON)
            .content(request(marker).toString())).andExpect(status().isCreated()).andReturn().getResponse();
        return new OwnedDraft(JSON.readTree(created.getContentAsString()).path("draft_casefile_id").longValue(),
            marker, strongEtag(created));
    }

    private ObjectNode request(String marker) throws Exception {
        ObjectNode request = (ObjectNode) JSON.readTree(DraftCasefileHttpFixture.requestBody());
        ObjectNode casefile = (ObjectNode) request.get("casefile");
        ((ObjectNode) casefile.get("respondent_account")).put("remo_reference", marker);
        ArrayNode minors = casefile.putArray("minor_creditors");
        ArrayNode terms = (ArrayNode) casefile.at("/respondent_account/order_details/order_terms");
        for (int index = 0; index < 2; index++) {
            int sequence = index == 0 ? 7 : 23;
            ObjectNode minor = ((ObjectNode) casefile.get("applicant")).deepCopy();
            minor.put("creditor_sequence", sequence);
            ((ObjectNode) minor.at("/party_details/individual_details")).put("surname", "Synthetic Minor " + sequence);
            minors.add(minor);
            ObjectNode term = ((ObjectNode) terms.get(0)).deepCopy();
            term.put("creditor_type", "Minor Creditor").put("minor_creditor_sequence", sequence);
            ((ObjectNode) term.at("/result_responses/0")).put("response", index == 0 ? "25.00" : "35.00");
            terms.add(term);
        }
        return request;
    }

    private void resubmit(OwnedDraft draft) throws Exception {
        decision(draft, checker(), draft.createdEtag(), "REJECTED").andExpect(status().isOk());
        State rejected = state(draft);
        ObjectNode corrected = request(draft.marker());
        corrected.remove("casefile_type");
        ((ObjectNode) corrected.at("/casefile/applicant/party_details/individual_details"))
            .put("surname", "Synthetic Corrected Applicant");
        MockHttpServletResponse replaced = mvc.perform(put(DRAFT_PATH, draft.id()).with(authentication(owner()))
            .header("If-Match", rejected.etag()).header("X-User-IP", "192.0.2.1")
            .contentType(MediaType.APPLICATION_JSON).content(corrected.toString()))
            .andExpect(status().isOk()).andReturn().getResponse();
        State resubmitted = state(draft);
        assertThat(resubmitted.body()).isEqualTo(JSON.readTree(replaced.getContentAsString()));
        assertThat(resubmitted.body().path("casefile_status").asString()).isEqualTo("RESUBMITTED");
        assertThat(resubmitted.body().get("casefile")).isEqualTo(corrected.get("casefile"));
        assertThat(resubmitted.entity().getVersionNumber()).isGreaterThan(rejected.entity().getVersionNumber());
        assertThat(resubmitted.etag()).isEqualTo(strongEtag(replaced)).isNotEqualTo(draft.createdEtag());
    }

    private State state(OwnedDraft draft) throws Exception {
        MockHttpServletResponse response = mvc.perform(get(DRAFT_PATH, draft.id()).with(authentication(owner()))
            .header("X-User-IP", "192.0.2.1")).andExpect(status().isOk()).andReturn().getResponse();
        DraftCasefileEntity entity = drafts.findById(draft.id()).orElseThrow();
        String etag = strongEtag(response);
        assertThat(etag).isEqualTo("\"" + entity.getVersionNumber() + "\"");
        return new State(JSON.readTree(response.getContentAsString()), entity, etag);
    }

    private JsonNode register(OwnedDraft draft, State before) throws Exception {
        JsonNode registered = JSON.readTree(mvc.perform(post(EVIDENCE_PATH, draft.id()).with(authentication(owner()))
            .header("Test-Run-Reference", draft.marker())).andExpect(status().isCreated())
            .andReturn().getResponse().getContentAsString());
        assertThat(registered.propertyNames()).containsExactlyInAnyOrder("observation_id", "registered_at",
            "send_attempt_count", "acknowledged_send_count", "uncertain_send_count", "unfinished_send_count",
            "evidence_complete");
        UUID.fromString(registered.path("observation_id").asString());
        utcTimestamp(registered.path("registered_at"));
        assertCounts(registered, 0, 0, 0, true);
        assertUnchanged(draft, before);
        return registered;
    }

    private void assertEvidence(OwnedDraft draft, JsonNode registered, int attempts, int acknowledged, int uncertain,
                                boolean complete) throws Exception {
        JsonNode current = JSON.readTree(mvc.perform(get(EVIDENCE_PATH, draft.id()).with(authentication(owner()))
            .header("Test-Run-Reference", draft.marker())).andExpect(status().isOk())
            .andReturn().getResponse().getContentAsString());
        assertThat(current.propertyNames()).containsExactlyInAnyOrderElementsOf(registered.propertyNames());
        assertThat(current.get("observation_id")).isEqualTo(registered.get("observation_id"));
        assertThat(current.get("registered_at")).isEqualTo(registered.get("registered_at"));
        assertCounts(current, attempts, acknowledged, uncertain, complete);
    }

    private void assertCounts(JsonNode observation, int attempts, int acknowledged, int uncertain, boolean complete) {
        assertThat(observation.path("send_attempt_count").intValue()).isEqualTo(attempts);
        assertThat(observation.path("acknowledged_send_count").intValue()).isEqualTo(acknowledged);
        assertThat(observation.path("uncertain_send_count").intValue()).isEqualTo(uncertain);
        assertThat(observation.path("unfinished_send_count").intValue()).isZero();
        assertThat(observation.path("evidence_complete").booleanValue()).isEqualTo(complete);
    }

    private void assertDeniedDecision(OwnedDraft draft, OpalJwtAuthenticationToken caller, String etag,
                                      int expectedStatus, String type) throws Exception {
        State before = state(draft);
        final JsonNode registered = register(draft, before);
        clearInvocations(logging);
        assertProblem(decision(draft, caller, etag, "PUBLISHING_PENDING"), expectedStatus, type, draft);
        verifyNoInteractions(logging, delegate);
        assertUnchanged(draft, before);
        assertEvidence(draft, registered, 0, 0, 0, true);
        verifyNoInteractions(delegate);
    }

    private void assertProblem(ResultActions result, int expectedStatus, String type, OwnedDraft draft)
        throws Exception {
        MockHttpServletResponse response = result.andExpect(status().is(expectedStatus))
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
            .andExpect(header().doesNotExist("ETag")).andExpect(header().doesNotExist("Location"))
            .andReturn().getResponse();
        JsonNode problem = JSON.readTree(response.getContentAsString());
        assertThat(problem.path("status").intValue()).isEqualTo(expectedStatus);
        assertThat(problem.path("type").asString()).isEqualTo("https://hmcts.gov.uk/problems/" + type);
        assertThat(problem.path("title").asString()).isNotBlank();
        assertThat(problem.path("detail").asString()).isNotBlank();
        String operation = problem.path("operation_id").asString();
        assertThat(operation).isNotBlank();
        assertThat(problem.path("instance").asString())
            .isEqualTo("https://hmcts.gov.uk/problems/instance/" + operation);
        assertThat(response.getContentAsString()).doesNotContain(draft.marker(), REASON, "Synthetic address",
            "Synthetic Minor", "BUU-", "amqp://", "JmsException", "stackTrace", "resourceType", "resourceId");
    }

    private void assertUnchanged(OwnedDraft draft, State before) throws Exception {
        State after = state(draft);
        assertThat(after.entity()).usingRecursiveComparison().isEqualTo(before.entity());
        assertThat(after.body()).isEqualTo(before.body());
        assertThat(after.etag()).isEqualTo(before.etag());
    }

    private void assertHistory(JsonNode before, JsonNode after, String event, OffsetDateTime decidedAt,
                               boolean approved) {
        JsonNode previous = before.path("timeline_data");
        JsonNode current = after.path("timeline_data");
        assertThat(current.size()).isEqualTo(previous.size() + 1);
        for (int index = 0; index < previous.size(); index++) {
            assertThat(current.get(index)).isEqualTo(previous.get(index));
        }
        JsonNode added = current.get(previous.size());
        assertThat(added.path("status").asString()).isEqualTo(event);
        assertThat(added.path("username").asString()).isEqualTo(ACTOR_NAME);
        assertThat(utcTimestamp(added.path("status_date"))).isEqualTo(decidedAt);
        if (approved) {
            assertThat(added.hasNonNull("reason_text")).isFalse();
        } else {
            assertThat(added.path("reason_text").asString()).isEqualTo(REASON);
        }
    }

    private ResultActions decision(OwnedDraft draft, OpalJwtAuthenticationToken caller, String etag, String target)
        throws Exception {
        ObjectNode body = JSON.createObjectNode().put("business_unit_id", 1).put("casefile_status", target);
        if (!target.equals("PUBLISHING_PENDING")) {
            body.put("status_message", REASON);
        }
        return mvc.perform(patch(DRAFT_PATH, draft.id()).with(authentication(caller)).header("If-Match", etag)
            .header("X-User-IP", "192.0.2.1").contentType(MediaType.APPLICATION_JSON).content(body.toString()));
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

    private OpalJwtAuthenticationToken owner() {
        return DraftCasefileHttpFixture.token((short) 1);
    }

    private OpalJwtAuthenticationToken checker() {
        return DraftCasefileHttpFixture.token((short) 1, 124L, "BUU-CHECKER", Set.of(CHECK));
    }

    private record OwnedDraft(long id, String marker, String createdEtag) { }

    private record State(JsonNode body, DraftCasefileEntity entity, String etag) { }
}
