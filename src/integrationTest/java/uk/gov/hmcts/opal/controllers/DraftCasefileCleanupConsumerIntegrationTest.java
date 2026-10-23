package uk.gov.hmcts.opal.controllers;

import org.junit.jupiter.api.BeforeEach;
import org.mockito.stubbing.Answer;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.dao.QueryTimeoutException;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jms.UncategorizedJmsException;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.springframework.test.context.jdbc.Sql;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import tools.jackson.databind.json.JsonMapper;
import tools.jackson.databind.node.ObjectNode;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.common.exception.OpalApiException;
import uk.gov.hmcts.opal.common.user.authorisation.model.Permission;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.exception.DraftCasefilePublicationException.Attempt;
import uk.gov.hmcts.opal.logging.integration.service.LoggingService;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.repository.PublicationEvidenceRepository;
import uk.gov.hmcts.opal.repository.extensions.DraftCasefilePublicationRepository;
import uk.gov.hmcts.opal.service.DraftCasefileCleanupService;
import uk.gov.hmcts.opal.service.DraftCasefilePublicationFailureService;
import uk.gov.hmcts.opal.service.messaging.DraftCasefileQueueConsumerService;
import uk.gov.hmcts.opal.service.messaging.DraftCasefileQueueMessage;
import uk.gov.hmcts.opal.service.messaging.DraftCasefileQueuePublisherImpl;
import uk.gov.hmcts.opal.support.DraftCasefileHttpFixture;

import java.time.Duration;
import java.util.Set;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.awaitility.Awaitility.await;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.mockingDetails;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.test.context.jdbc.Sql.ExecutionPhase.AFTER_TEST_METHOD;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Real Java transactions and PostgreSQL locks; publication failures are injected at the repository boundary. */
@AutoConfigureMockMvc
@TestPropertySource(properties = {"spring.flyway.locations=classpath:db/migration/ddl", "opal.redis.enabled=false",
    "management.health.redis.enabled=false", "opal.testing-support-endpoints.enabled=true"})
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@Sql({"/draft-casefile/reference-fixtures.sql", "/draft-casefile/cleanup-scope-fixtures.sql"})
@Sql(scripts = "/draft-casefile/cleanup-scope-cleanup.sql", executionPhase = AFTER_TEST_METHOD)
class DraftCasefileCleanupConsumerIntegrationTest extends BaseIntegrationTest {
    private static final String RUN = "E2E-0123456789abcdef";
    private static final JsonMapper JSON = JsonMapper.builder().build();
    @Autowired
    private MockMvc mvc;
    @Autowired
    private JdbcTemplate jdbc;
    @Autowired
    private DraftCasefileCleanupService cleanup;
    @Autowired
    private DraftCasefileQueueConsumerService consumer;
    @Autowired
    private DraftCasefilePublicationFailureService failures;
    @Autowired
    private PublicationEvidenceRepository evidence;
    @MockitoSpyBean
    private DraftCasefileRepository drafts;
    @MockitoSpyBean
    private DraftCasefilePublicationRepository publication;
    @MockitoBean
    private DraftCasefileQueuePublisherImpl publisher;
    @MockitoBean
    private LoggingService logging;

    private Answer<?> repositoryDelegate;

    @BeforeEach
    void setUp() {
        when(logging.personalDataAccessLogAsync(any())).thenReturn(true);
        repositoryDelegate = mockingDetails(drafts).getMockCreationSettings().getDefaultAnswer();
    }

    @ParameterizedTest
    @ValueSource(booleans = {false, true})
    void delayedConsumerAndFailureWaitForCleanupCommitOrRollback(boolean rollback) throws Exception {
        long id = submit();
        var locked = new CountDownLatch(1);
        var release = new CountDownLatch(1);
        doAnswer(invocation -> {
            repositoryDelegate.answer(invocation);
            locked.countDown();
            awaitRelease(release);
            if (rollback) {
                throw new IllegalStateException("Synthetic cleanup rollback");
            }
            return null;
        }).when(drafts).flush();
        try (var workers = Executors.newFixedThreadPool(3)) {
            var deletion = workers.submit(() -> cleanup(id));
            if (!locked.await(15, TimeUnit.SECONDS)) {
                deletion.get(1, TimeUnit.SECONDS);
                throw new AssertionError("Cleanup did not reach transaction flush");
            }
            var delivery = workers.submit(() -> consumer.consume(payload(id)));
            final var failure = workers.submit(() ->
                failures.markFailed(new Attempt(id, 0L, null, null), "Synthetic failure"));
            try {
                awaitBlockedDraftLocks(2);
            } finally {
                release.countDown();
            }
            if (rollback) {
                assertThatThrownBy(() -> deletion.get(15, TimeUnit.SECONDS))
                    .hasCauseInstanceOf(IllegalStateException.class);
                assertThat(drafts.findById(id).orElseThrow().getCasefileStatus())
                    .isEqualTo(DraftCasefileStatus.SUBMITTED);
                assertThat(evidence.findObservation(id)).isPresent();
            } else {
                deletion.get(15, TimeUnit.SECONDS);
                assertThat(drafts.findById(id)).isEmpty();
                assertThat(evidence.findObservation(id)).isEmpty();
            }
            delivery.get(15, TimeUnit.SECONDS);
            assertThat(failure.get(15, TimeUnit.SECONDS)).isFalse();
            consumer.consume(payload(id));
            verifyNoInteractions(publication, logging);
        } finally {
            release.countDown();
        }
    }

    @ParameterizedTest
    @ValueSource(booleans = {false, true})
    void lateAcceptedDeliveryAfterApprovalFailureCannotPublishOrRecreateCleanedDraft(boolean transportFailure)
        throws Exception {
        long id = submit();
        var accepted = new AtomicReference<DraftCasefileQueueMessage>();
        doAnswer(invocation -> {
            accepted.set(invocation.getArgument(0));
            if (transportFailure) {
                throw new UncategorizedJmsException("Synthetic uncertain send");
            }
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void beforeCommit(boolean readOnly) {
                    throw new IllegalStateException("Synthetic approval rollback");
                }
            });
            return null;
        }).when(publisher).publish(any());
        approve(id, transportFailure ? 503 : 500);
        assertThat(accepted.get()).isNotNull();
        assertThat(drafts.findById(id).orElseThrow().getCasefileStatus()).isEqualTo(DraftCasefileStatus.SUBMITTED);
        var counts = evidence.counts(evidence.findObservation(id).orElseThrow().observationId());
        assertThat(counts.sendAttemptCount()).isEqualTo(1);
        assertThat(counts.acknowledgedSendCount()).isEqualTo(transportFailure ? 0 : 1);
        assertThat(counts.uncertainSendCount()).isEqualTo(transportFailure ? 1 : 0);
        consumer.consume(JSON.writeValueAsString(accepted.get()));
        cleanup(id);
        consumer.consume(JSON.writeValueAsString(accepted.get()));
        assertThat(failures.markFailed(new Attempt(id, 1L, "BUU-CHECKER", null), "Synthetic failure")).isFalse();
        assertThat(drafts.findById(id)).isEmpty();
        assertThat(evidence.findObservation(id)).isEmpty();
        verifyNoInteractions(publication, logging);
    }

    @Test
    void processingRollbackReleasesLockButPendingCleanupStillRefusesUntilFailureRecorded() throws Exception {
        long id = submit();
        var accepted = new AtomicReference<DraftCasefileQueueMessage>();
        doAnswer(invocation -> {
            accepted.set(invocation.getArgument(0));
            return null;
        }).when(publisher).publish(any());
        approve(id, 200);
        clearInvocations(logging);
        var pending = drafts.findById(id).orElseThrow();
        var attempt = new Attempt(id, pending.getVersionNumber(), pending.getValidatedBy(), pending.getValidatedDate());
        var locked = new CountDownLatch(1);
        var release = new CountDownLatch(1);
        doAnswer(invocation -> {
            locked.countDown();
            awaitRelease(release);
            throw new QueryTimeoutException("Synthetic publication boundary timeout");
        }).when(publication).publish(id);
        try (var workers = Executors.newFixedThreadPool(2)) {
            var delivery = workers.submit(() -> consumer.consume(JSON.writeValueAsString(accepted.get())));
            if (!locked.await(15, TimeUnit.SECONDS)) {
                delivery.get(1, TimeUnit.SECONDS);
                throw new AssertionError("Processing did not reach the controlled publication boundary");
            }
            var deletion = workers.submit(() -> cleanup(id));
            try {
                awaitBlockedDraftLocks(1);
            } finally {
                release.countDown();
            }
            assertThatThrownBy(() -> delivery.get(15, TimeUnit.SECONDS))
                .hasCauseInstanceOf(IllegalStateException.class);
            assertThatThrownBy(() -> deletion.get(15, TimeUnit.SECONDS)).hasCauseInstanceOf(OpalApiException.class);
            assertThat(drafts.findById(id).orElseThrow().getCasefileStatus())
                .isEqualTo(DraftCasefileStatus.PUBLISHING_PENDING);
            assertThat(evidence.findObservation(id)).isPresent();
            assertThat(failures.markFailed(attempt, "Synthetic terminal failure")).isTrue();
            cleanup(id);
            consumer.consume(JSON.writeValueAsString(accepted.get()));
            assertThat(failures.markFailed(attempt, "Synthetic terminal failure")).isFalse();
            assertThat(drafts.findById(id)).isEmpty();
            assertThat(evidence.findObservation(id)).isEmpty();
            verify(publication).publish(id);
            verifyNoInteractions(logging);
        } finally {
            release.countDown();
        }
    }

    @Test
    void cleanupWaitsForSeparatelyCommittedFailureThenDeletesOnlyUnlinkedDraft() throws Exception {
        long id = submit();
        approve(id, 200);
        clearInvocations(logging);
        var pending = drafts.findById(id).orElseThrow();
        var attempt = new Attempt(id, pending.getVersionNumber(), pending.getValidatedBy(), pending.getValidatedDate());
        var locked = new CountDownLatch(1);
        var release = new CountDownLatch(1);
        doAnswer(invocation -> {
            repositoryDelegate.answer(invocation);
            if (Thread.currentThread().getName().equals("failure-writer")) {
                locked.countDown();
                awaitRelease(release);
            }
            return null;
        }).when(drafts).flush();
        try (var workers = Executors.newFixedThreadPool(2)) {
            var failure = workers.submit(() -> {
                Thread.currentThread().setName("failure-writer");
                return failures.markFailed(attempt, "Synthetic terminal failure");
            });
            if (!locked.await(15, TimeUnit.SECONDS)) {
                failure.get(1, TimeUnit.SECONDS);
                throw new AssertionError("Failure recording did not reach transaction flush");
            }
            var deletion = workers.submit(() -> cleanup(id));
            try {
                awaitBlockedDraftLocks(1);
            } finally {
                release.countDown();
            }
            assertThat(failure.get(15, TimeUnit.SECONDS)).isTrue();
            deletion.get(15, TimeUnit.SECONDS);
            consumer.consume(payload(id));
            assertThat(failures.markFailed(attempt, "Synthetic terminal failure")).isFalse();
            assertThat(drafts.findById(id)).isEmpty();
            assertThat(evidence.findObservation(id)).isEmpty();
            verify(publication, never()).publish(any());
            verifyNoInteractions(logging);
        } finally {
            release.countDown();
        }
    }

    private void awaitBlockedDraftLocks(int count) {
        // Native SQL is limited to observing the PostgreSQL lock behavior under test.
        await().atMost(Duration.ofSeconds(10)).untilAsserted(() -> assertThat(jdbc.queryForObject("""
            SELECT COUNT(*) FROM pg_stat_activity WHERE wait_event_type='Lock'
              AND query LIKE '%draft_casefiles%' AND pid<>pg_backend_pid()
            """, Long.class)).isGreaterThanOrEqualTo(count));
    }

    private void awaitRelease(CountDownLatch release) throws InterruptedException {
        assertThat(release.await(20, TimeUnit.SECONDS)).isTrue();
    }

    private void cleanup(long id) {
        SecurityContextHolder.getContext().setAuthentication(DraftCasefileHttpFixture.token((short) 1));
        try {
            cleanup.cleanup(id, RUN);
        } finally {
            SecurityContextHolder.clearContext();
        }
    }

    private String payload(long id) {
        return JSON.createObjectNode().put("draft_casefile_id", id).toString();
    }

    private long submit() throws Exception {
        ObjectNode request = (ObjectNode) JSON.readTree(DraftCasefileHttpFixture.requestBody());
        ((ObjectNode) request.at("/casefile/respondent_account")).put("remo_reference", RUN);
        long id = JSON.readTree(mvc.perform(post("/draft-casefiles")
            .with(authentication(DraftCasefileHttpFixture.token((short) 1)))
            .contentType(MediaType.APPLICATION_JSON).content(request.toString()))
            .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString())
            .get("draft_casefile_id").longValue();
        mvc.perform(post("/testing-support/draft-casefiles/{id}/publication-evidence", id)
            .with(authentication(DraftCasefileHttpFixture.token((short) 1)))
            .header("Test-Run-Reference", RUN)).andExpect(status().isCreated());
        clearInvocations(logging);
        return id;
    }

    private void approve(long id, int expectedStatus) throws Exception {
        var checker = DraftCasefileHttpFixture.token((short) 1, 124L, "BUU-CHECKER",
            Set.of(new Permission(22L, "Check and validate draft Casefiles")));
        mvc.perform(patch("/draft-casefiles/{id}", id).header("If-Match", "\"0\"")
            .header("X-User-IP", "192.0.2.1")
            .contentType(MediaType.APPLICATION_JSON)
            .content("{\"business_unit_id\":1,\"casefile_status\":\"PUBLISHING_PENDING\"}")
            .with(authentication(checker))).andExpect(status().is(expectedStatus));
    }
}
