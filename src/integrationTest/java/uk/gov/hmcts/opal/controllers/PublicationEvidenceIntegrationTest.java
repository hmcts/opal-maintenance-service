package uk.gov.hmcts.opal.controllers;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.http.MediaType;
import org.springframework.jms.UncategorizedJmsException;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.springframework.test.context.jdbc.Sql;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.common.spring.security.OpalJwtAuthenticationToken;
import uk.gov.hmcts.opal.common.user.authorisation.model.Permission;
import uk.gov.hmcts.opal.dto.PublicationObservation;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.logging.integration.service.LoggingService;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.repository.PublicationEvidenceRepository;
import uk.gov.hmcts.opal.service.messaging.DraftCasefileQueuePublisherImpl;
import uk.gov.hmcts.opal.service.messaging.PublicationEvidenceWriter;
import uk.gov.hmcts.opal.support.DraftCasefileHttpFixture;

import java.util.Set;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mockingDetails;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.test.context.jdbc.Sql.ExecutionPhase.AFTER_TEST_METHOD;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
@TestPropertySource(properties = {"spring.flyway.locations=classpath:db/migration/ddl", "opal.redis.enabled=false",
    "management.health.redis.enabled=false", "opal.testing-support-endpoints.enabled=true"})
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@Sql({"/draft-casefile/reference-fixtures.sql", "/draft-casefile/cleanup-scope-fixtures.sql"})
@Sql(scripts = "/draft-casefile/cleanup-scope-cleanup.sql", executionPhase = AFTER_TEST_METHOD)
class PublicationEvidenceIntegrationTest extends BaseIntegrationTest {

    private static final String RUN = "E2E-0123456789abcdef";
    private static final String OTHER_RUN = "E2E-fedcba9876543210";
    private static final String PATH = "/testing-support/draft-casefiles/{id}/publication-evidence";
    @Autowired
    private MockMvc mvc;
    @Autowired
    private ObjectMapper json;
    @MockitoSpyBean
    private DraftCasefileRepository drafts;
    @Autowired
    private PublicationEvidenceRepository evidence;
    @MockitoSpyBean
    private PublicationEvidenceWriter writer;
    @MockitoBean
    private DraftCasefileQueuePublisherImpl delegate;
    @MockitoBean
    private LoggingService logging;

    @BeforeEach
    void setUp() {
        when(logging.personalDataAccessLogAsync(any())).thenReturn(true);
    }

    @Test
    void approvalPublishesOnceAndRepeatedReadsAndRegistrationPreserveCounts() throws Exception {
        long id = submit();
        final JsonNode registered = body(register(id).andExpect(status().isCreated()));
        assertZero(id);
        decision(id, "PUBLISHING_PENDING", "\"0\"").andExpect(status().isOk());
        for (int repeat = 0; repeat < 2; repeat++) {
            read(id).andExpect(status().isOk()).andExpect(jsonPath("$.send_attempt_count").value(1))
                .andExpect(jsonPath("$.acknowledged_send_count").value(1))
                .andExpect(jsonPath("$.uncertain_send_count").value(0))
                .andExpect(jsonPath("$.unfinished_send_count").value(0))
                .andExpect(jsonPath("$.evidence_complete").value(true));
        }
        JsonNode repeated = body(register(id).andExpect(status().isOk()));
        assertThat(repeated.get("observation_id")).isEqualTo(registered.get("observation_id"));
        assertThat(repeated.get("registered_at")).isEqualTo(registered.get("registered_at"));
        assertThat(repeated.get("acknowledged_send_count").longValue()).isEqualTo(1L);
        decision(id, "PUBLISHING_PENDING", "\"0\"").andExpect(status().isConflict());
        verify(delegate, times(1)).publish(argThat(message -> message.draftCasefileId().equals(id)));
        assertThat(repeated.fieldNames()).toIterable().containsExactlyInAnyOrder("observation_id", "registered_at",
            "send_attempt_count", "acknowledged_send_count", "uncertain_send_count", "unfinished_send_count",
            "evidence_complete");
    }

    @Test
    void committedSendEvidenceSurvivesOuterCommitFailureWithoutAutomaticReplay() throws Exception {
        long id = submit();
        register(id).andExpect(status().isCreated());
        final DraftCasefileEntity before = drafts.findById(id).orElseThrow();
        clearInvocations(logging);
        doAnswer(invocation -> {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void beforeCommit(boolean readOnly) {
                    throw new IllegalStateException("Synthetic commit failure");
                }
            });
            return null;
        }).when(delegate).publish(argThat(message -> message.draftCasefileId().equals(id)));
        decision(id, "PUBLISHING_PENDING", "\"0\"").andExpect(status().isInternalServerError());
        assertThat(drafts.findById(id).orElseThrow()).usingRecursiveComparison().isEqualTo(before);
        read(id).andExpect(status().isOk()).andExpect(jsonPath("$.acknowledged_send_count").value(1))
            .andExpect(jsonPath("$.send_attempt_count").value(1));
        register(id).andExpect(status().isOk()).andExpect(jsonPath("$.acknowledged_send_count").value(1));
        verify(delegate, times(1)).publish(argThat(message -> message.draftCasefileId().equals(id)));
        verifyNoInteractions(logging);
    }

    @Test
    void sendFailureIsUncertainAndDraftRollsBack() throws Exception {
        long id = submit();
        register(id).andExpect(status().isCreated());
        final DraftCasefileEntity before = drafts.findById(id).orElseThrow();
        doThrow(new UncategorizedJmsException("Synthetic transport uncertainty"))
            .when(delegate).publish(argThat(message -> message.draftCasefileId().equals(id)));
        decision(id, "PUBLISHING_PENDING", "\"0\"").andExpect(status().isServiceUnavailable());
        assertThat(drafts.findById(id).orElseThrow()).usingRecursiveComparison().isEqualTo(before);
        read(id).andExpect(status().isOk()).andExpect(jsonPath("$.send_attempt_count").value(1))
            .andExpect(jsonPath("$.acknowledged_send_count").value(0))
            .andExpect(jsonPath("$.uncertain_send_count").value(1))
            .andExpect(jsonPath("$.evidence_complete").value(false));
        verify(delegate, times(1)).publish(argThat(message -> message.draftCasefileId().equals(id)));
    }

    @Test
    void outcomeWriteFailureRetainsStartedWithoutFailingApproval() throws Exception {
        long id = submit();
        register(id).andExpect(status().isCreated());
        doThrow(new DataAccessResourceFailureException("Synthetic completion failure")).when(writer).acknowledge(any());
        decision(id, "PUBLISHING_PENDING", "\"0\"").andExpect(status().isOk());
        read(id).andExpect(status().isOk()).andExpect(jsonPath("$.send_attempt_count").value(1))
            .andExpect(jsonPath("$.unfinished_send_count").value(1))
            .andExpect(jsonPath("$.acknowledged_send_count").value(0))
            .andExpect(jsonPath("$.evidence_complete").value(false));
        verify(delegate, times(1)).publish(argThat(message -> message.draftCasefileId().equals(id)));
    }

    @Test
    void beginFailurePreventsSendAndRollsBackApproval() throws Exception {
        long id = submit();
        register(id).andExpect(status().isCreated());
        final DraftCasefileEntity before = drafts.findById(id).orElseThrow();
        doThrow(new DataAccessResourceFailureException("Synthetic begin failure")).when(writer).begin(id);
        decision(id, "PUBLISHING_PENDING", "\"0\"").andExpect(status().isServiceUnavailable());
        assertThat(drafts.findById(id).orElseThrow()).usingRecursiveComparison().isEqualTo(before);
        assertZero(id);
        verifyNoInteractions(delegate);
    }

    @ParameterizedTest
    @EnumSource(value = DraftCasefileStatus.class, names = {"SUBMITTED", "REJECTED", "RESUBMITTED"})
    void firstRegistrationSupportsUnlinkedLifecycle(DraftCasefileStatus lifecycle) throws Exception {
        long id = submit();
        drafts.saveAndFlush(drafts.findById(id).orElseThrow().toBuilder().casefileStatus(lifecycle).build());
        register(id).andExpect(status().isCreated());
        register(id).andExpect(status().isOk());
        assertZero(id);
        verifyNoInteractions(delegate);
    }

    @ParameterizedTest
    @EnumSource(value = DraftCasefileStatus.class,
        names = {"PUBLISHING_PENDING", "PUBLISHED", "PUBLISHING_FAILED", "DELETED"})
    void firstRegistrationRejectsIneligibleLifecycle(DraftCasefileStatus lifecycle) throws Exception {
        long id = submit();
        drafts.saveAndFlush(drafts.findById(id).orElseThrow().toBuilder().casefileStatus(lifecycle).build());
        register(id).andExpect(status().isConflict());
        assertThat(evidence.findObservation(id)).isEmpty();
    }

    @ParameterizedTest
    @ValueSource(strings = {"row-number", "snapshot-number", "missing-account", "scalar", "missing-minors"})
    void firstRegistrationRejectsLinkedOrInconsistentSnapshot(String variant) throws Exception {
        long id = submit();
        DraftCasefileEntity draft = drafts.findById(id).orElseThrow();
        var updated = draft.toBuilder();
        ObjectNode snapshot = (ObjectNode) json.readTree(draft.getCasefileSnapshot());
        switch (variant) {
            case "row-number" -> updated.accountNumber("SYNTHETIC");
            case "snapshot-number" -> ((ObjectNode) snapshot.get("respondent_account"))
                .put("account_number", "SYNTHETIC");
            case "missing-account" -> snapshot.remove("applicant_account");
            case "missing-minors" -> snapshot.remove("minor_creditor_accounts");
            default -> { }
        }
        updated.casefileSnapshot(variant.equals("scalar") ? "null" : json.writeValueAsString(snapshot));
        drafts.saveAndFlush(updated.build());
        register(id).andExpect(status().isConflict());
        assertThat(evidence.findObservation(id)).isEmpty();
        verifyNoInteractions(delegate);
    }

    @Test
    void unregisteredAndMissingDraftHaveDistinctOutcomes() throws Exception {
        long id = submit();
        read(id).andExpect(status().isConflict());
        register(Long.MAX_VALUE).andExpect(status().isNotFound());
        read(Long.MAX_VALUE).andExpect(status().isNotFound());
        PublicationObservation orphan = evidence.register(Long.MAX_VALUE, RUN);
        try {
            read(Long.MAX_VALUE).andExpect(status().isNotFound());
            register(Long.MAX_VALUE).andExpect(status().isNotFound());
            mvc.perform(delete("/testing-support/draft-casefiles/{id}", Long.MAX_VALUE)
                .with(authentication(owner())).header("Test-Run-Reference", RUN)).andExpect(status().isNoContent());
            assertThat(evidence.findObservation(Long.MAX_VALUE)).contains(orphan);
        } finally {
            evidence.deleteObservation(Long.MAX_VALUE, RUN);
        }
    }

    @ParameterizedTest
    @ValueSource(strings = {"no-permission", "checker", "wrong-user", "wrong-buu", "wrong-bu", "wrong-marker"})
    void readAndRegistrationEnforceScope(String variant) throws Exception {
        long id = submit();
        register(id).andExpect(status().isCreated());
        Set<Permission> permissions = switch (variant) {
            case "no-permission" -> Set.of();
            case "checker" -> Set.of(new Permission(22L, "Check and validate draft Casefiles"));
            default -> Set.of(new Permission(21L, "Create and Manage Draft Casefiles"));
        };
        var caller = DraftCasefileHttpFixture.token((short) (variant.equals("wrong-bu") ? 2 : 1),
            variant.equals("wrong-user") ? 124L : 123L,
            variant.equals("wrong-user") || variant.equals("wrong-buu") ? "BUU-OTHER" : "BUU-1", permissions);
        for (var request : new MockHttpServletRequestBuilder[]{post(PATH, id), get(PATH, id)}) {
            mvc.perform(request.with(authentication(caller)).header("Test-Run-Reference",
                variant.equals("wrong-marker") ? OTHER_RUN : RUN)).andExpect(status().isForbidden());
        }
        assertZero(id);
        verifyNoInteractions(delegate);
    }

    @ParameterizedTest
    @ValueSource(strings = {"MISSING", "", "E2E-0123456789ABCDEF", "E2E-0123456789abcde", "E2E-0123456789abcdef0"})
    void validatesHeaderOnBothOperations(String marker) throws Exception {
        long id = submit();
        for (var request : new MockHttpServletRequestBuilder[]{post(PATH, id), get(PATH, id)}) {
            if (!marker.equals("MISSING")) {
                request.header("Test-Run-Reference", marker);
            }
            mvc.perform(request.with(authentication(owner()))).andExpect(status().isBadRequest());
        }
        assertThat(evidence.findObservation(id)).isEmpty();
    }

    @ParameterizedTest
    @ValueSource(strings = {"0", "-1", "not-a-number", "9223372036854775808"})
    void validatesIdentifiersOnBothOperations(String id) throws Exception {
        for (var request : new MockHttpServletRequestBuilder[]{post(PATH, id), get(PATH, id)}) {
            mvc.perform(request.with(authentication(owner())).header("Test-Run-Reference", RUN))
                .andExpect(status().isBadRequest());
        }
    }

    @ParameterizedTest
    @ValueSource(booleans = {false, true})
    void inputterHandoverRetainsEvidenceScopeAndCurrentOwnerCanCleanOldJournal(boolean changedMarker)
        throws Exception {
        long id = submit();
        register(id).andExpect(status().isCreated());
        final PublicationObservation observation = evidence.findObservation(id).orElseThrow();
        UUID attempt = writer.begin(id).orElseThrow();
        writer.acknowledge(attempt);
        decision(id, "REJECTED", "\"0\"").andExpect(status().isOk());
        var newOwner = DraftCasefileHttpFixture.token((short) 1, 125L, "BUU-NEW",
            Set.of(new Permission(21L, "Create and Manage Draft Casefiles")));
        String marker = changedMarker ? OTHER_RUN : RUN;
        ObjectNode replacement = request(marker);
        replacement.remove("casefile_type");
        mvc.perform(put("/draft-casefiles/{id}", id).with(authentication(newOwner)).header("If-Match", "\"1\"")
            .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsBytes(replacement)))
            .andExpect(status().isOk());
        for (var request : new MockHttpServletRequestBuilder[]{post(PATH, id), get(PATH, id),
            delete("/testing-support/draft-casefiles/{id}", id)}) {
            mvc.perform(request.with(authentication(owner())).header("Test-Run-Reference", RUN))
                .andExpect(status().isForbidden());
        }
        for (var request : new MockHttpServletRequestBuilder[]{post(PATH, id), get(PATH, id)}) {
            mvc.perform(request.with(authentication(newOwner)).header("Test-Run-Reference", marker))
                .andExpect(changedMarker ? status().isForbidden() : status().isOk());
        }
        assertThat(evidence.findObservation(id)).contains(observation);
        mvc.perform(delete("/testing-support/draft-casefiles/{id}", id).with(authentication(newOwner))
            .header("Test-Run-Reference", marker)).andExpect(status().isNoContent());
        assertThat(drafts.findById(id)).isEmpty();
        assertThat(evidence.findObservation(id)).isEmpty();
        assertThat(evidence.counts(observation.observationId()).sendAttemptCount()).isZero();
        verifyNoInteractions(delegate);
    }

    @Test
    void cleanupFailureRollsBackDraftObservationAndAttemptsTogether() throws Exception {
        long id = submit();
        register(id).andExpect(status().isCreated());
        UUID attempt = writer.begin(id).orElseThrow();
        writer.acknowledge(attempt);
        final PublicationObservation observation = evidence.findObservation(id).orElseThrow();
        final DraftCasefileEntity before = drafts.findById(id).orElseThrow();
        var repositoryDelegate = mockingDetails(drafts).getMockCreationSettings().getDefaultAnswer();
        doAnswer(invocation -> {
            repositoryDelegate.answer(invocation);
            throw new DataAccessResourceFailureException("Synthetic post-delete failure");
        }).when(drafts).flush();
        mvc.perform(delete("/testing-support/draft-casefiles/{id}", id).with(authentication(owner()))
            .header("Test-Run-Reference", RUN)).andExpect(status().isServiceUnavailable());
        assertThat(drafts.findById(id).orElseThrow()).usingRecursiveComparison().isEqualTo(before);
        assertThat(evidence.findObservation(id)).contains(observation);
        assertThat(evidence.counts(observation.observationId()).acknowledgedSendCount()).isEqualTo(1L);
    }

    @ParameterizedTest
    @ValueSource(strings = {"REJECTED", "DELETED", "stale", "permission"})
    void nonApprovalAndDeniedDecisionsDoNotSend(String outcome) throws Exception {
        long id = submit();
        register(id).andExpect(status().isCreated());
        if (outcome.equals("permission")) {
            mvc.perform(patch("/draft-casefiles/{id}", id).with(authentication(owner())).header("If-Match", "\"0\"")
                .contentType(MediaType.APPLICATION_JSON).content(decisionBody("PUBLISHING_PENDING")))
                .andExpect(status().isForbidden());
        } else if (outcome.equals("stale")) {
            decision(id, "PUBLISHING_PENDING", "\"9\"").andExpect(status().isConflict());
        } else {
            decision(id, outcome, "\"0\"").andExpect(status().isOk());
        }
        assertZero(id);
        verifyNoInteractions(delegate);
    }

    @Test
    void operationalEndpointsRemainPublicWhenObservationIsEnabled() throws Exception {
        mvc.perform(get("/")).andExpect(status().isOk());
        mvc.perform(get("/health")).andExpect(status().isOk()).andExpect(jsonPath("$.status").value("UP"));
        mvc.perform(get("/prometheus")).andExpect(status().isOk());
    }

    @Test
    void runtimeDocumentationExposesAuthenticatedConditionalOperations() throws Exception {
        JsonNode paths = body(mvc.perform(get("/v3/api-docs")).andExpect(status().isOk())).get("paths");
        JsonNode path = paths.get("/testing-support/draft-casefiles/{draft_casefile_id}/publication-evidence");
        for (String method : new String[]{"post", "get"}) {
            assertThat(path.path(method).path("security").isEmpty()).isFalse();
            assertThat(path.path(method).path("responses").has("409")).isTrue();
        }
        assertThat(path.at("/post/responses/201").isObject()).isTrue();
    }

    private long submit() throws Exception {
        return body(mvc.perform(post("/draft-casefiles").with(authentication(owner()))
            .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsBytes(request(RUN))))
            .andExpect(status().isCreated())).get("draft_casefile_id").longValue();
    }

    private ObjectNode request(String marker) throws Exception {
        ObjectNode request = (ObjectNode) json.readTree(DraftCasefileHttpFixture.requestBody());
        ((ObjectNode) request.at("/casefile/respondent_account")).put("remo_reference", marker);
        return request;
    }

    private ResultActions register(long id) throws Exception {
        return mvc.perform(post(PATH, id).with(authentication(owner())).header("Test-Run-Reference", RUN));
    }

    private ResultActions read(long id) throws Exception {
        return mvc.perform(get(PATH, id).with(authentication(owner())).header("Test-Run-Reference", RUN));
    }

    private void assertZero(long id) throws Exception {
        read(id).andExpect(status().isOk()).andExpect(jsonPath("$.send_attempt_count").value(0))
            .andExpect(jsonPath("$.acknowledged_send_count").value(0));
    }

    private ResultActions decision(long id, String state, String version) throws Exception {
        var checker = DraftCasefileHttpFixture.token((short) 1, 124L, "BUU-CHECKER",
            Set.of(new Permission(22L, "Check and validate draft Casefiles")));
        return mvc.perform(patch("/draft-casefiles/{id}", id).with(authentication(checker)).header("If-Match", version)
            .contentType(MediaType.APPLICATION_JSON).content(decisionBody(state)));
    }

    private String decisionBody(String state) throws Exception {
        ObjectNode body = json.createObjectNode().put("business_unit_id", 1).put("casefile_status", state);
        if (state.equals("REJECTED") || state.equals("DELETED")) {
            body.put("status_message", "Synthetic rejection");
        }
        return json.writeValueAsString(body);
    }

    private OpalJwtAuthenticationToken owner() {
        return DraftCasefileHttpFixture.token((short) 1);
    }

    private JsonNode body(ResultActions result) throws Exception {
        return json.readTree(result.andReturn().getResponse().getContentAsString());
    }
}
