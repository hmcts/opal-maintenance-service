package uk.gov.hmcts.opal.service.messaging;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.springframework.test.context.jdbc.Sql;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.exception.DraftCasefilePublicationException.Attempt;
import uk.gov.hmcts.opal.logging.integration.service.LoggingService;
import uk.gov.hmcts.opal.repository.extensions.DraftCasefilePublicationRepository;
import uk.gov.hmcts.opal.service.DraftCasefilePublicationFailureService;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

import static org.assertj.core.api.Assertions.assertThat;
import static org.awaitility.Awaitility.await;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.context.jdbc.Sql.ExecutionPhase.AFTER_TEST_METHOD;

@TestPropertySource(properties = {"opal.redis.enabled=false", "management.health.redis.enabled=false",
    "spring.jpa.open-in-view=false"})
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@Sql("/draft-casefile/publication-fixtures.sql")
@Sql(scripts = "/draft-casefile/publication-cleanup.sql", executionPhase = AFTER_TEST_METHOD)
class DraftCasefilePublicationConcurrencyIntegrationTest extends BaseIntegrationTest {
    @Autowired
    private DraftCasefileQueueProcessingService processing;
    @Autowired
    private DraftCasefilePublicationFailureService failures;
    @Autowired
    private JdbcTemplate jdbc;
    @Autowired
    private PlatformTransactionManager transactionManager;
    @MockitoSpyBean
    private DraftCasefilePublicationRepository publication;
    @MockitoBean
    private LoggingService logging;
    private final DraftCasefileQueueMessage message = new DraftCasefileQueueMessage(1062901L, 123L, "192.0.2.1",
        "2024-01-02T00:00:00Z");

    @Test
    void concurrentDeliveriesCreateOneGraph() throws Exception {
        var locked = new CountDownLatch(1);
        var release = new CountDownLatch(1);
        var first = new AtomicBoolean(true);
        when(logging.personalDataAccessLogAsync(any())).thenReturn(true);
        doAnswer(invocation -> {
            if (first.compareAndSet(true, false)) {
                locked.countDown();
                assertThat(release.await(15, TimeUnit.SECONDS)).isTrue();
            }
            return invocation.callRealMethod();
        }).when(publication).publish(1062901L);
        try (var workers = Executors.newFixedThreadPool(2)) {
            var winner = workers.submit(() -> processing.processPendingDraft(message));
            assertThat(locked.await(15, TimeUnit.SECONDS)).isTrue();
            var duplicate = workers.submit(() -> processing.processPendingDraft(message));
            try {
                awaitBlockedDraftLock();
            } finally {
                release.countDown();
            }
            assertThat(winner.get(20, TimeUnit.SECONDS))
                .isEqualTo(DraftCasefileQueueProcessingService.Outcome.PUBLISHED);
            assertThat(duplicate.get(20, TimeUnit.SECONDS))
                .isEqualTo(DraftCasefileQueueProcessingService.Outcome.NO_OP);
        } finally {
            release.countDown();
        }
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM respondent_accounts WHERE business_unit_id=32055",
            Long.class)).isEqualTo(1L);
        verify(publication).publish(1062901L);
        verify(logging, times(3)).personalDataAccessLogAsync(any());
    }

    @Test
    void consumerWaitsForApprovalCommit() throws Exception {
        approvalRace(false);
        assertThat(status()).isEqualTo("PUBLISHED");
    }

    @Test
    void approvalRollbackMakesQueuedMessageNoOp() throws Exception {
        approvalRace(true);
        assertThat(status()).isEqualTo("SUBMITTED");
        verifyNoInteractions(publication, logging);
    }

    @Test
    void terminalFailureCannotOverwriteWinningPublication() {
        var attempt = new Attempt(1062901L, 1L, "P55_APPROVE", LocalDateTime.of(2024, 1, 2, 0, 0));
        processing.processPendingDraft(message);
        assertThat(failures.markFailed(attempt, "Publication failed; contact support")).isFalse();
        assertThat(status()).isEqualTo("PUBLISHED");
        assertThat(processing.processPendingDraft(new DraftCasefileQueueMessage(1062901L, null, null, null)))
            .isEqualTo(DraftCasefileQueueProcessingService.Outcome.NO_OP);
        verify(publication).publish(1062901L);
    }

    private void approvalRace(boolean rollback) throws Exception {
        jdbc.update("UPDATE draft_casefiles SET casefile_status='SUBMITTED' WHERE draft_casefile_id=1062901");
        var locked = new CountDownLatch(1);
        var release = new CountDownLatch(1);
        when(logging.personalDataAccessLogAsync(any())).thenReturn(true);
        try (var workers = Executors.newFixedThreadPool(2)) {
            var approval = workers.submit(() -> new TransactionTemplate(transactionManager).executeWithoutResult(tx -> {
                jdbc.update("UPDATE draft_casefiles SET casefile_status='PUBLISHING_PENDING'"
                    + " WHERE draft_casefile_id=1062901");
                locked.countDown();
                try {
                    assertThat(release.await(15, TimeUnit.SECONDS)).isTrue();
                } catch (InterruptedException interrupted) {
                    Thread.currentThread().interrupt();
                    throw new IllegalStateException("Synthetic approval interrupted");
                }
                if (rollback) {
                    tx.setRollbackOnly();
                }
            }));
            assertThat(locked.await(15, TimeUnit.SECONDS)).isTrue();
            var consumer = workers.submit(() -> processing.processPendingDraft(message));
            try {
                awaitBlockedDraftLock();
            } finally {
                release.countDown();
            }
            approval.get(20, TimeUnit.SECONDS);
            assertThat(consumer.get(20, TimeUnit.SECONDS)).isEqualTo(rollback
                ? DraftCasefileQueueProcessingService.Outcome.NO_OP
                : DraftCasefileQueueProcessingService.Outcome.PUBLISHED);
        } finally {
            release.countDown();
        }
    }

    private void awaitBlockedDraftLock() {
        await().atMost(Duration.ofSeconds(10)).untilAsserted(() -> assertThat(jdbc.queryForObject("""
            SELECT COUNT(*) FROM pg_stat_activity WHERE wait_event_type='Lock'
              AND query LIKE '%draft_casefiles%' AND pid<>pg_backend_pid()
            """, Long.class)).isPositive());
    }

    private String status() {
        return jdbc.queryForObject("SELECT casefile_status::text FROM draft_casefiles WHERE draft_casefile_id=1062901",
            String.class);
    }
}
