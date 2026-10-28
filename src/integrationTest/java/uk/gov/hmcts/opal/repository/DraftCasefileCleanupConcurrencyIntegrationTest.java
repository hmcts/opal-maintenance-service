package uk.gov.hmcts.opal.repository;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.springframework.test.context.jdbc.Sql;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.authorisation.MaintenanceUser;
import uk.gov.hmcts.opal.authorisation.MaintenanceUserService;
import uk.gov.hmcts.opal.common.exception.OpalApiException;
import uk.gov.hmcts.opal.logging.integration.service.LoggingService;
import uk.gov.hmcts.opal.service.DraftCasefileCleanupService;
import uk.gov.hmcts.opal.service.messaging.DraftCasefileQueueMessage;
import uk.gov.hmcts.opal.service.messaging.DraftCasefileQueueProcessingService;
import uk.gov.hmcts.opal.support.DraftCasefileHttpFixture;

import java.sql.SQLException;
import java.time.Duration;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.awaitility.Awaitility.await;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.test.context.jdbc.Sql.ExecutionPhase.AFTER_TEST_METHOD;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static uk.gov.hmcts.opal.authorisation.MaintenancePermission.CREATE_MANAGE_DRAFT_CASEFILES;

/** Application-owned cleanup SQL against unchanged production helpers in independent Spring transactions. */
@AutoConfigureMockMvc
@TestPropertySource(properties = {"opal.redis.enabled=false", "management.health.redis.enabled=false",
    "spring.jpa.open-in-view=false", "opal.testing-support-endpoints.enabled=true"})
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@Sql({"/draft-casefile/publication-fixtures.sql", "/draft-casefile/published-cleanup-fixtures.sql"})
@Sql(scripts = "/draft-casefile/published-cleanup-cleanup.sql", executionPhase = AFTER_TEST_METHOD)
class DraftCasefileCleanupConcurrencyIntegrationTest extends BaseIntegrationTest {
    private static final long ID = 1062901L;
    private static final long SIBLING = 1062902L;
    private static final String RUN = "E2E-0123456789abcdef";
    @Autowired
    private JdbcTemplate jdbc;
    @Autowired
    private PlatformTransactionManager transactionManager;
    @Autowired
    private DraftCasefileCleanupService cleanup;
    @Autowired
    private DraftCasefileQueueProcessingService processing;
    @Autowired
    private DraftCasefileRepository drafts;
    @Autowired
    private MockMvc mvc;
    @MockitoSpyBean
    private DraftCasefileCleanupRepository graphs;
    @MockitoBean
    private MaintenanceUserService users;
    @MockitoBean
    private LoggingService logging;

    @BeforeEach
    void setUp() {
        when(users.requireAuthorisedUser((short) 32055, CREATE_MANAGE_DRAFT_CASEFILES))
            .thenReturn(new MaintenanceUser(123L, "P55_SUBMIT", "Synthetic saved submitter", "192.0.2.1"));
        when(logging.personalDataAccessLogAsync(any())).thenReturn(true);
        publish(ID);
        publish(SIBLING);
    }

    @AfterEach
    void removeCoordination() {
        jdbc.execute("DROP TRIGGER IF EXISTS cleanup_writer_gate ON notes");
        jdbc.execute("DROP TRIGGER IF EXISTS cleanup_writer_gate ON respondent_account_parties");
        jdbc.execute("DROP FUNCTION IF EXISTS cleanup_writer_gate()");
        // Also remove the deliberately dangling regression row when running against the unsafe implementation.
        jdbc.update("DELETE FROM notes WHERE note_text='Synthetic concurrent cleanup note'");
    }

    @ParameterizedTest
    @ValueSource(strings = {"Note", "Applicant", "Respondent"})
    void writerFirstPreservesIntegrityAndReturnsSafeRetry(String kind) throws Exception {
        Targets targets = targets(kind);
        installInsertGate(kind);
        var writerPid = new AtomicInteger();
        try (var workers = Executors.newFixedThreadPool(2)) {
            var writerStarted = new CountDownLatch(1);
            var releaseGate = new CountDownLatch(1);
            var gate = workers.submit(() -> transaction().executeWithoutResult(status -> {
                jdbc.execute("SELECT pg_advisory_xact_lock(10626, 2)");
                writerStarted.countDown();
                awaitRelease(releaseGate);
            }));
            assertThat(writerStarted.await(15, TimeUnit.SECONDS)).isTrue();
            var writer = workers.submit(() -> write(kind, targets, writerPid));
            org.springframework.test.web.servlet.MvcResult response;
            try {
                awaitLock(writerPid, "advisory");
                response = mvc.perform(delete("/testing-support/draft-casefiles/{id}", ID)
                    .with(authentication(DraftCasefileHttpFixture.token((short) 32055)))
                    .header("Test-Run-Reference", RUN)).andReturn();
            } finally {
                releaseGate.countDown();
            }
            gate.get(15, TimeUnit.SECONDS);
            writer.get(15, TimeUnit.SECONDS);
            assertNoDanglingReferences();
            assertThat(response.getResponse().getStatus()).isEqualTo(503);
            assertThat(response.getResolvedException()).isInstanceOf(DataAccessResourceFailureException.class)
                .hasRootCauseInstanceOf(SQLException.class);
            assertThat(((SQLException) rootCause(response.getResolvedException())).getSQLState()).isEqualTo("55P03");
            assertThat(response.getResponse().getContentAsString())
                .contains("Opal database is currently unavailable")
                .doesNotContain("LOCK TABLE", "respondent_accounts", "55P03");
            assertThat(drafts.findById(ID)).isPresent();
            if (kind.equals("Note")) {
                cleanup.cleanup(ID, RUN);
                assertThat(drafts.findById(ID)).isEmpty();
            } else {
                // A second respondent now shares the owned polymorphic target. Retry must refuse deletion.
                assertThatThrownBy(() -> cleanup.cleanup(ID, RUN)).isInstanceOf(OpalApiException.class);
                assertThat(drafts.findById(ID)).isPresent();
            }
            assertNoDanglingReferences();
            assertSiblingPresent(targets);
            assertLocksReleased();
        }
    }

    @ParameterizedTest
    @CsvSource({"Note,false", "Applicant,false", "Respondent,false",
        "Note,true", "Applicant,true", "Respondent,true"})
    void cleanupFirstOrdersTargetValidationAfterCommitOrRollback(String kind, boolean rollback) throws Exception {
        Targets targets = targets(kind);
        var locked = new CountDownLatch(1);
        var release = new CountDownLatch(1);
        doAnswer(invocation -> {
            Object graph = invocation.callRealMethod();
            locked.countDown();
            awaitRelease(release);
            return graph;
        }).when(graphs).lockGraph(any(), any());
        if (rollback) {
            doAnswer(invocation -> {
                invocation.callRealMethod();
                throw new DataAccessResourceFailureException("Synthetic rollback after deleting graph");
            }).when(graphs).deleteGraph(any());
        }
        var writerPid = new AtomicInteger();
        try (var workers = Executors.newFixedThreadPool(2)) {
            var deletion = workers.submit(() -> cleanup.cleanup(ID, RUN));
            assertThat(locked.await(15, TimeUnit.SECONDS)).isTrue();
            var writer = workers.submit(() -> write(kind, targets, writerPid));
            try {
                awaitLock(writerPid, "relation");
            } finally {
                release.countDown();
            }
            if (rollback) {
                assertThatThrownBy(() -> deletion.get(15, TimeUnit.SECONDS))
                    .hasCauseInstanceOf(DataAccessResourceFailureException.class);
                writer.get(15, TimeUnit.SECONDS);
                assertThat(drafts.findById(ID)).isPresent();
            } else {
                deletion.get(15, TimeUnit.SECONDS);
                assertThatThrownBy(() -> writer.get(15, TimeUnit.SECONDS))
                    .hasRootCauseInstanceOf(SQLException.class)
                    .rootCause().hasMessageContaining(kind.equals("Note")
                        ? "respondent_account target does not exist" : "validate " + kind + " target failed");
                assertThat(drafts.findById(ID)).isEmpty();
            }
            assertNoDanglingReferences();
            assertSiblingPresent(targets);
            assertLocksReleased();
        } finally {
            release.countDown();
        }
    }

    private void installInsertGate(String kind) {
        // Test-only trigger pauses the REAL helper after its validation, before the INSERT becomes visible.
        // It neither replaces the procedure nor validates/locks its target on the helper's behalf.
        jdbc.execute("""
            CREATE FUNCTION cleanup_writer_gate() RETURNS trigger LANGUAGE plpgsql AS $$
            BEGIN
                PERFORM pg_advisory_xact_lock(10626, 2);
                RETURN NEW;
            END $$
            """);
        String table = kind.equals("Note") ? "notes" : "respondent_account_parties";
        jdbc.execute("CREATE TRIGGER cleanup_writer_gate BEFORE INSERT ON " + table
            + " FOR EACH ROW EXECUTE FUNCTION cleanup_writer_gate()");
    }

    private void write(String kind, Targets targets, AtomicInteger pid) {
        transaction().executeWithoutResult(status -> {
            jdbc.execute("SET LOCAL statement_timeout='15s'");
            pid.set(jdbc.queryForObject("SELECT pg_backend_pid()", Integer.class));
            if (kind.equals("Note")) {
                jdbc.update("CALL p_insert_notes(?, 'P55_SUBMIT', 'Synthetic writer', "
                    + "'{\"note_text\":\"Synthetic concurrent cleanup note\"}'::json)", targets.respondent());
            } else {
                jdbc.update("CALL p_insert_respondent_account_parties(?, ?, ?::t_association_type_enum)",
                    targets.sibling(), targets.target(), kind);
            }
        });
    }

    private Targets targets(String kind) {
        long respondent = drafts.findById(ID).orElseThrow().getAccountId();
        long sibling = drafts.findById(SIBLING).orElseThrow().getAccountId();
        long target = kind.equals("Note") ? respondent : jdbc.queryForObject("""
            SELECT associated_account_id FROM respondent_account_parties
            WHERE respondent_account_id=? AND association_type::text=?
            """, Long.class, respondent, kind);
        return new Targets(respondent, sibling, target);
    }

    private void awaitLock(AtomicInteger pid, String lockType) {
        await().atMost(Duration.ofSeconds(10)).untilAsserted(() -> assertThat(jdbc.queryForObject("""
            SELECT COUNT(*) FROM pg_locks WHERE pid=? AND locktype=? AND NOT granted
              AND (locktype='advisory' OR (mode='AccessShareLock' AND relation IN
                  ('respondent_accounts'::regclass, 'creditor_accounts'::regclass, 'parties'::regclass)))
            """, Long.class, pid.get(), lockType)).isPositive());
    }

    private void assertNoDanglingReferences() {
        assertThat(jdbc.queryForObject("""
            SELECT COUNT(*) FROM notes n WHERE n.associated_record_type='respondent_accounts'
              AND NOT EXISTS (SELECT 1 FROM respondent_accounts r
                  WHERE r.respondent_account_id::text=n.associated_record_id)
            """, Long.class)).as("dangling notes").isZero();
        assertThat(jdbc.queryForObject("""
            SELECT COUNT(*) FROM respondent_account_parties a WHERE
              (a.association_type='Respondent' AND NOT EXISTS
                  (SELECT 1 FROM parties p WHERE p.party_id=a.associated_account_id))
              OR (a.association_type='Applicant' AND NOT EXISTS
                  (SELECT 1 FROM creditor_accounts c WHERE c.creditor_account_id=a.associated_account_id))
            """, Long.class)).as("dangling polymorphic associations").isZero();
    }

    private void assertSiblingPresent(Targets targets) {
        assertThat(drafts.findById(SIBLING).orElseThrow().getAccountId()).isEqualTo(targets.sibling());
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM respondent_accounts WHERE respondent_account_id=?",
            Long.class, targets.sibling())).isEqualTo(1);
    }

    private void assertLocksReleased() {
        transaction().executeWithoutResult(status -> jdbc.execute("""
            LOCK TABLE respondent_accounts, creditor_accounts, parties IN ACCESS EXCLUSIVE MODE NOWAIT
            """));
    }

    private TransactionTemplate transaction() {
        return new TransactionTemplate(transactionManager);
    }

    private static void awaitRelease(CountDownLatch release) {
        try {
            assertThat(release.await(20, TimeUnit.SECONDS)).isTrue();
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException(exception);
        }
    }

    private static Throwable rootCause(Throwable failure) {
        Throwable result = failure;
        while (result.getCause() != null) {
            result = result.getCause();
        }
        return result;
    }

    private void publish(long id) {
        assertThat(processing.processPendingDraft(new DraftCasefileQueueMessage(id, 123L,
            "192.0.2.1", "2024-01-02T00:00:00Z"))).isEqualTo(DraftCasefileQueueProcessingService.Outcome.PUBLISHED);
    }

    private record Targets(long respondent, long sibling, long target) { }
}
