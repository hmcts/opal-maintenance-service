package uk.gov.hmcts.opal.repository;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.stubbing.Answer;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.dao.QueryTimeoutException;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.springframework.test.context.jdbc.Sql;
import org.springframework.test.web.servlet.MockMvc;
import tools.jackson.databind.json.JsonMapper;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.authorisation.MaintenanceUser;
import uk.gov.hmcts.opal.authorisation.MaintenanceUserService;
import uk.gov.hmcts.opal.common.exception.OpalApiException;
import uk.gov.hmcts.opal.exception.DraftCasefilePublicationException.Attempt;
import uk.gov.hmcts.opal.logging.integration.service.LoggingService;
import uk.gov.hmcts.opal.repository.extensions.DraftCasefilePublicationRepository;
import uk.gov.hmcts.opal.service.DraftCasefileCleanupService;
import uk.gov.hmcts.opal.service.DraftCasefilePublicationFailureService;
import uk.gov.hmcts.opal.service.messaging.DraftCasefileQueueConsumerService;
import uk.gov.hmcts.opal.service.messaging.DraftCasefileQueueMessage;
import uk.gov.hmcts.opal.service.messaging.DraftCasefileQueueProcessingService;
import uk.gov.hmcts.opal.support.DraftCasefileHttpFixture;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.awaitility.Awaitility.await;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.mockingDetails;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.test.context.jdbc.Sql.ExecutionPhase.AFTER_TEST_METHOD;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static uk.gov.hmcts.opal.authorisation.MaintenancePermission.CREATE_MANAGE_DRAFT_CASEFILES;

/** Verifies native graph deletion and real publication transactions against disposable PostgreSQL. */
@AutoConfigureMockMvc
@TestPropertySource(properties = {"opal.redis.enabled=false", "management.health.redis.enabled=false",
    "spring.jpa.open-in-view=false", "opal.testing-support-endpoints.enabled=true"})
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@Sql({"/draft-casefile/publication-fixtures.sql", "/draft-casefile/published-cleanup-fixtures.sql"})
@Sql(scripts = "/draft-casefile/published-cleanup-cleanup.sql", executionPhase = AFTER_TEST_METHOD)
class DraftCasefilePublishedCleanupIntegrationTest extends BaseIntegrationTest {
    private static final long ID = 1062901L;
    private static final String RUN = "E2E-0123456789abcdef";
    private static final List<String> GRAPH_TABLES = List.of("respondent_accounts", "creditor_accounts", "parties",
        "aliases", "third_party_contact", "debtor_detail", "notes", "order_terms", "respondent_account_parties",
        "account_number_index");
    @Autowired
    private JdbcTemplate jdbc;
    @Autowired
    private DraftCasefileCleanupService cleanup;
    @Autowired
    private DraftCasefileQueueConsumerService consumer;
    @Autowired
    private DraftCasefileQueueProcessingService processing;
    @Autowired
    private DraftCasefilePublicationFailureService failures;
    @Autowired
    private MockMvc mvc;
    @MockitoSpyBean
    private DraftCasefileRepository drafts;
    @MockitoSpyBean
    private DraftCasefileCleanupRepository graphs;
    @MockitoSpyBean
    private DraftCasefilePublicationRepository publication;
    @MockitoBean
    private MaintenanceUserService users;
    @MockitoBean
    private LoggingService logging;

    @BeforeEach
    void setUp() {
        when(users.requireAuthorisedUser((short) 32055, CREATE_MANAGE_DRAFT_CASEFILES))
            .thenReturn(new MaintenanceUser(123L, "P55_SUBMIT", "Synthetic saved submitter", "192.0.2.1"));
        when(logging.personalDataAccessLogAsync(any())).thenReturn(true);
    }

    @Test
    void removesCompleteGraphWhileRetainingAnotherCaseAndReferenceRows() throws Exception {
        publish(1062902L);
        var sibling = graphRows();
        publish(ID);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM creditor_accounts WHERE business_unit_id=32055",
            Long.class)).isEqualTo(6);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM third_party_contact", Long.class))
            .isEqualTo(sibling.get("third_party_contact").size() + 2);
        mvc.perform(delete("/testing-support/draft-casefiles/{id}", ID)
            .with(authentication(DraftCasefileHttpFixture.token((short) 32055)))
            .header("Test-Run-Reference", RUN)).andExpect(status().isNoContent());
        assertThat(graphRows()).isEqualTo(sibling);
        assertThat(drafts.findById(1062902L)).isPresent();
        assertAbsent();
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM major_creditors WHERE business_unit_id=32055",
            Long.class)).isEqualTo(3);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM countries WHERE country_id=-1065501",
            Long.class)).isEqualTo(1);
        cleanup.cleanup(ID, RUN);
        consumer.consume(payload(ID));
        assertThat(graphRows()).isEqualTo(sibling);
    }

    @Test
    void pendingCleanupWinsAgainstDeliveryRedeliveryAndSeparateFailure() throws Exception {
        final var before = graphRows();
        var locked = new CountDownLatch(1);
        var release = new CountDownLatch(1);
        Answer<?> delegate = mockingDetails(drafts).getMockCreationSettings().getDefaultAnswer();
        doAnswer(invocation -> {
            final Object result = delegate.answer(invocation);
            locked.countDown();
            awaitRelease(release);
            return result;
        }).when(drafts).flush();
        try (var workers = Executors.newFixedThreadPool(3)) {
            var deletion = workers.submit(() -> cleanup.cleanup(ID, RUN));
            assertThat(locked.await(15, TimeUnit.SECONDS)).isTrue();
            final var delivery = workers.submit(() -> consumer.consume(payload(ID)));
            final var failure = workers.submit(() -> failures.markFailed(attempt(), "Synthetic failure"));
            try {
                awaitDraftLocks(2);
            } finally {
                release.countDown();
            }
            deletion.get(20, TimeUnit.SECONDS);
            delivery.get(20, TimeUnit.SECONDS);
            assertThat(failure.get(20, TimeUnit.SECONDS)).isFalse();
            consumer.consume(payload(ID));
        } finally {
            release.countDown();
        }
        assertAbsent();
        assertThat(graphRows()).isEqualTo(before);
        verifyNoInteractions(publication, logging);
    }

    @ParameterizedTest
    @ValueSource(booleans = {false, true})
    void cleanupWaitsForRealPublicationCommitOrRollback(boolean rollback) throws Exception {
        final var before = graphRows();
        var locked = new CountDownLatch(1);
        var release = new CountDownLatch(1);
        doAnswer(invocation -> {
            final Object result = invocation.callRealMethod();
            locked.countDown();
            awaitRelease(release);
            if (rollback) {
                throw new QueryTimeoutException("Synthetic failure after real graph allocation");
            }
            return result;
        }).when(publication).publish(ID);
        try (var workers = Executors.newFixedThreadPool(2)) {
            final var delivery = workers.submit(() -> consumer.consume(payload(ID)));
            assertThat(locked.await(15, TimeUnit.SECONDS)).isTrue();
            verifyNoInteractions(logging);
            var deletion = workers.submit(() -> cleanup.cleanup(ID, RUN));
            try {
                awaitDraftLocks(1);
            } finally {
                release.countDown();
            }
            if (rollback) {
                assertThatThrownBy(() -> delivery.get(20, TimeUnit.SECONDS))
                    .hasCauseInstanceOf(IllegalStateException.class);
            } else {
                delivery.get(20, TimeUnit.SECONDS);
            }
            deletion.get(20, TimeUnit.SECONDS);
        } finally {
            release.countDown();
        }
        assertAbsent();
        consumer.consume(payload(ID));
        assertThat(failures.markFailed(attempt(), "Synthetic failure")).isFalse();
        assertThat(graphRows()).isEqualTo(before);
        verify(publication).publish(ID);
        if (rollback) {
            verifyNoInteractions(logging);
        } else {
            verify(logging, times(4)).personalDataAccessLogAsync(any());
        }
    }

    @Test
    void graphDeletionFailureRollsBackDraftAndEveryGraphRow() {
        publish(ID);
        final var before = graphRows();
        var draft = drafts.findById(ID).orElseThrow();
        doAnswer(invocation -> {
            invocation.callRealMethod();
            throw new DataAccessResourceFailureException("Synthetic failure after graph removal");
        }).when(graphs).deleteGraph(any());
        assertThatThrownBy(() -> cleanup.cleanup(ID, RUN)).isInstanceOf(DataAccessResourceFailureException.class);
        assertThat(graphRows()).isEqualTo(before);
        assertThat(drafts.findById(ID).orElseThrow()).usingRecursiveComparison().isEqualTo(draft);
    }

    @ParameterizedTest
    @ValueSource(booleans = {false, true})
    void removesLegacyPendingOrPublishedDraftWithNullVersion(boolean published) {
        final var before = graphRows();
        if (published) {
            publish(ID);
        }
        jdbc.update("UPDATE draft_casefiles SET version_number=NULL WHERE draft_casefile_id=?", ID);
        cleanup.cleanup(ID, RUN);
        assertAbsent();
        consumer.consume(payload(ID));
        assertThat(failures.markFailed(attempt(), "Synthetic failure")).isFalse();
        assertThat(graphRows()).isEqualTo(before);
        if (!published) {
            verifyNoInteractions(publication, logging);
        }
    }

    @ParameterizedTest
    @ValueSource(strings = {"party", "creditor", "contact", "debtor", "marker", "snapshot",
        "respondent-version", "creditor-version", "money", "reservation", "missing-term"})
    void refusesSharedOrInconsistentGraphsWithoutDeletingAnything(String variant) {
        publish(ID);
        publish(1062902L);
        var accountsBefore = jdbc.queryForList("SELECT * FROM respondent_accounts WHERE business_unit_id=32055");
        var associationsBefore = jdbc.queryForList("SELECT * FROM respondent_account_parties");
        var termsBefore = jdbc.queryForList("SELECT * FROM order_terms");
        try {
            // Native SQL deliberately constructs graph-integrity violations at the repository boundary.
            switch (variant) {
                case "party" -> jdbc.update("""
                    UPDATE respondent_account_parties SET associated_account_id=(
                        SELECT associated_account_id FROM respondent_account_parties
                        WHERE respondent_account_id=(SELECT account_id FROM draft_casefiles
                            WHERE draft_casefile_id=1062901)
                            AND association_type='Respondent')
                    WHERE respondent_account_id=(SELECT account_id FROM draft_casefiles WHERE draft_casefile_id=1062902)
                        AND association_type='Respondent'
                    """);
                case "creditor" -> jdbc.update("""
                    UPDATE order_terms SET creditor_account_id=(SELECT MIN(creditor_account_id) FROM order_terms
                        WHERE respondent_account_id=(SELECT account_id FROM draft_casefiles
                            WHERE draft_casefile_id=1062901))
                    WHERE respondent_account_id=(SELECT account_id FROM draft_casefiles WHERE draft_casefile_id=1062902)
                    """);
                case "contact" -> jdbc.update("""
                    UPDATE respondent_accounts SET third_party_contact_id=(SELECT third_party_contact_id
                        FROM respondent_accounts WHERE respondent_account_id=(
                            SELECT account_id FROM draft_casefiles WHERE draft_casefile_id=1062901))
                    WHERE respondent_account_id=(SELECT account_id FROM draft_casefiles WHERE draft_casefile_id=1062902)
                    """);
                case "debtor" -> jdbc.update("""
                    UPDATE respondent_accounts SET debtor_detail_id=(SELECT debtor_detail_id FROM respondent_accounts
                        WHERE respondent_account_id=(SELECT account_id FROM draft_casefiles
                            WHERE draft_casefile_id=1062901))
                    WHERE respondent_account_id=(SELECT account_id FROM draft_casefiles WHERE draft_casefile_id=1062902)
                    """);
                case "marker" -> jdbc.update("""
                    UPDATE respondent_accounts SET remo_reference='E2E-fedcba9876543210'
                    WHERE respondent_account_id=(SELECT account_id FROM draft_casefiles WHERE draft_casefile_id=1062901)
                    """);
                case "snapshot" -> jdbc.update("""
                    UPDATE draft_casefiles SET casefile_snapshot=JSONB_SET(casefile_snapshot::jsonb,
                        '{applicant_account,account_number}', '"incorrect"')::json WHERE draft_casefile_id=1062901
                    """);
                case "respondent-version" -> jdbc.update("""
                    UPDATE respondent_accounts SET version_number=2 WHERE respondent_account_id=(
                        SELECT account_id FROM draft_casefiles WHERE draft_casefile_id=1062901)
                    """);
                case "creditor-version" -> jdbc.update("""
                    UPDATE creditor_accounts SET version_number=1 WHERE creditor_account_id=(
                        SELECT MIN(creditor_account_id) FROM order_terms WHERE respondent_account_id=(
                            SELECT account_id FROM draft_casefiles WHERE draft_casefile_id=1062901))
                    """);
                case "money" -> jdbc.update("""
                    UPDATE respondent_accounts SET account_balance=1.00 WHERE respondent_account_id=(
                        SELECT account_id FROM draft_casefiles WHERE draft_casefile_id=1062901)
                    """);
                case "reservation" -> jdbc.update("""
                    UPDATE account_number_index SET associated_record_type='creditor_accounts'
                    WHERE business_unit_id=32055 AND account_number=(
                        SELECT account_number FROM draft_casefiles WHERE draft_casefile_id=1062901)
                    """);
                case "missing-term" -> jdbc.update("""
                    DELETE FROM order_terms WHERE order_terms_id=(SELECT MAX(order_terms_id) FROM order_terms
                        WHERE respondent_account_id=(SELECT account_id FROM draft_casefiles
                            WHERE draft_casefile_id=1062901))
                    """);
                default -> throw new IllegalArgumentException(variant);
            }
            final var before = graphRows();
            assertThatThrownBy(() -> cleanup.cleanup(ID, RUN)).isInstanceOf(OpalApiException.class);
            assertThat(graphRows()).isEqualTo(before);
            assertThat(drafts.findById(ID)).isPresent();
        } finally {
            for (var row : accountsBefore) {
                jdbc.update("""
                    UPDATE respondent_accounts SET third_party_contact_id=?,debtor_detail_id=?,remo_reference=?
                    WHERE respondent_account_id=?
                    """, row.get("third_party_contact_id"), row.get("debtor_detail_id"),
                    row.get("remo_reference"), row.get("respondent_account_id"));
            }
            for (var row : associationsBefore) {
                jdbc.update("""
                    UPDATE respondent_account_parties SET associated_account_id=? WHERE respondent_account_party_id=?
                    """, row.get("associated_account_id"), row.get("respondent_account_party_id"));
            }
            for (var row : termsBefore) {
                jdbc.update("UPDATE order_terms SET creditor_account_id=? WHERE order_terms_id=?",
                    row.get("creditor_account_id"), row.get("order_terms_id"));
            }
        }
    }

    private Map<String, List<String>> graphRows() {
        Map<String, List<String>> rows = new HashMap<>();
        for (String table : GRAPH_TABLES) {
            rows.put(table, jdbc.queryForList("SELECT ROW_TO_JSON(t)::text FROM " + table + " t ORDER BY 1",
                String.class));
        }
        return rows;
    }

    private void assertAbsent() {
        assertThat(drafts.findById(ID)).isEmpty();
    }

    private void awaitDraftLocks(int count) {
        await().atMost(Duration.ofSeconds(10)).untilAsserted(() -> assertThat(jdbc.queryForObject("""
            SELECT COUNT(*) FROM pg_stat_activity WHERE wait_event_type='Lock'
                AND query LIKE '%draft_casefiles%' AND pid<>pg_backend_pid()
            """, Long.class)).isGreaterThanOrEqualTo(count));
    }

    private static void awaitRelease(CountDownLatch release) throws InterruptedException {
        assertThat(release.await(20, TimeUnit.SECONDS)).isTrue();
    }

    private static Attempt attempt() {
        return new Attempt(ID, 1L, "P55_APPROVE", LocalDateTime.of(2024, 1, 2, 0, 0));
    }

    private void publish(long id) {
        assertThat(processing.processPendingDraft(new DraftCasefileQueueMessage(id, 123L,
            "192.0.2.1", "2024-01-02T00:00:00Z"))).isEqualTo(DraftCasefileQueueProcessingService.Outcome.PUBLISHED);
    }

    private static String payload(long id) {
        return JsonMapper.builder().build().writeValueAsString(new DraftCasefileQueueMessage(id, 123L,
            "192.0.2.1", "2024-01-02T00:00:00Z"));
    }
}
