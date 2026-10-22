package uk.gov.hmcts.opal.service.messaging;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.springframework.test.context.jdbc.Sql;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionTemplate;
import tools.jackson.databind.json.JsonMapper;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.exception.DraftCasefilePublicationException;
import uk.gov.hmcts.opal.logging.integration.service.LoggingService;
import uk.gov.hmcts.opal.mapper.DraftCasefilePublicationMapper;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.repository.extensions.DraftCasefilePublicationRepository;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.context.jdbc.Sql.ExecutionPhase.AFTER_TEST_METHOD;

@ExtendWith(OutputCaptureExtension.class)
@TestPropertySource(properties = {"opal.redis.enabled=false", "management.health.redis.enabled=false",
    "spring.jpa.open-in-view=false"})
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@Sql("/draft-casefile/publication-fixtures.sql")
@Sql(scripts = "/draft-casefile/publication-cleanup.sql", executionPhase = AFTER_TEST_METHOD)
class DraftCasefileQueueProcessingIntegrationTest extends BaseIntegrationTest {
    @Autowired
    private DraftCasefileQueueProcessingService processing;
    @Autowired
    private JdbcTemplate jdbc;
    @Autowired
    private DraftCasefileQueueConsumerService consumer;
    @Autowired
    private PlatformTransactionManager transactionManager;
    @MockitoSpyBean
    private DraftCasefilePublicationRepository publication;
    @MockitoSpyBean
    private DraftCasefilePublicationMapper mapper;
    @MockitoSpyBean
    private DraftCasefileRepository drafts;
    @MockitoBean
    private LoggingService logging;
    private final DraftCasefileQueueMessage message = new DraftCasefileQueueMessage(1062901L, 123L, "192.0.2.1",
        "2024-01-02T00:00:00Z");

    @BeforeEach
    void setUp() {
        when(logging.personalDataAccessLogAsync(any())).thenReturn(true);
    }

    @Test
    void delayedRolledBackApprovalCannotPublishLaterApproval() {
        // The old delivery survives rollback; a later approval reuses the same row version.
        jdbc.update("UPDATE draft_casefiles SET validated_date=TIMESTAMP '2024-01-03'"
            + " WHERE draft_casefile_id=1062901");
        assertThatThrownBy(() -> processing.processPendingDraft(message))
            .isInstanceOf(IllegalArgumentException.class);
        assertThat(status()).isEqualTo("PUBLISHING_PENDING");
        verifyNoInteractions(publication, logging);
        when(logging.personalDataAccessLogAsync(any())).thenAnswer(invocation -> {
            uk.gov.hmcts.opal.logging.integration.dto.PersonalDataProcessingLogDetails details =
                invocation.getArgument(0);
            assertThat(details.getCreatedBy().getIdentifier()).isEqualTo("456");
            return true;
        });
        assertThat(processing.processPendingDraft(new DraftCasefileQueueMessage(1062901L, 456L,
            "192.0.2.2", "2024-01-03T00:00:00Z")))
            .isEqualTo(DraftCasefileQueueProcessingService.Outcome.PUBLISHED);
        verify(logging, times(3)).personalDataAccessLogAsync(any());
    }

    @Test
    void publishesRealGraphAndAuditsOnlyAfterCommit() {
        final var before = jdbc.queryForMap("SELECT * FROM draft_casefiles WHERE draft_casefile_id=1062901");
        when(logging.personalDataAccessLogAsync(any())).thenAnswer(invocation -> {
            var observer = new TransactionTemplate(transactionManager);
            observer.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
            String committedStatus = observer.execute(transaction -> status());
            assertThat(committedStatus).isEqualTo("PUBLISHED");
            return true;
        });
        assertThat(processing.processPendingDraft(message))
            .isEqualTo(DraftCasefileQueueProcessingService.Outcome.PUBLISHED);
        var after = jdbc.queryForMap("SELECT * FROM draft_casefiles WHERE draft_casefile_id=1062901");
        for (String field : new String[]{"casefile", "timeline_data", "submitted_by",
            "validated_by", "validated_date"}) {
            assertThat(after.get(field)).as(field).isEqualTo(before.get(field));
        }
        assertThat(after.get("version_number")).isEqualTo(2L);
        var snapshot = JsonMapper.builder().build().readTree(after.get("casefile_snapshot").toString());
        assertThat(snapshot.at("/respondent_account/account_id").longValue()).isEqualTo(after.get("account_id"));
        assertThat(snapshot.at("/minor_creditor_accounts/0/account_id").longValue()).isPositive();
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM creditor_accounts WHERE business_unit_id=32055",
            Long.class)).isEqualTo(2L);
        assertThat(jdbc.queryForObject(
            "SELECT casefile_status::text FROM draft_casefiles WHERE draft_casefile_id=1062902",
            String.class)).isEqualTo("PUBLISHING_PENDING");
        verify(logging, times(3)).personalDataAccessLogAsync(any());
        assertThat(processing.processPendingDraft(message))
            .isEqualTo(DraftCasefileQueueProcessingService.Outcome.NO_OP);
        verify(logging, times(3)).personalDataAccessLogAsync(any());
    }

    @Test
    void rollsBackRealProcedureWhenOutputMappingFails() {
        doThrow(new IllegalStateException("Synthetic mapping failure"))
            .when(mapper).mergePublishedAccounts(any(), any(), any());
        assertThatThrownBy(() -> processing.processPendingDraft(message))
            .isInstanceOf(DraftCasefilePublicationException.class);
        assertRolledBack();
    }

    @Test
    void rollsBackRealProcedureWhenCompletionFlushFails() {
        doThrow(new IllegalStateException("Synthetic flush failure")).when(drafts).flush();
        assertThatThrownBy(() -> processing.processPendingDraft(message))
            .isInstanceOf(DraftCasefilePublicationException.class);
        assertRolledBack();
    }

    @Test
    void handlesLegacyVersionOnSuccessfulPublication() {
        jdbc.update("UPDATE draft_casefiles SET version_number=NULL WHERE draft_casefile_id=1062901");
        processing.processPendingDraft(message);
        assertThat(status()).isEqualTo("PUBLISHED");
        assertThat(jdbc.queryForObject("SELECT version_number FROM draft_casefiles WHERE draft_casefile_id=1062901",
            Long.class)).isEqualTo(1L);
    }

    @Test
    void legacyPendingMessageCannotPublishWithoutAuditContext() {
        assertThatThrownBy(() -> processing.processPendingDraft(
            new DraftCasefileQueueMessage(1062901L, null, null, null)))
            .isInstanceOf(IllegalArgumentException.class);
        assertRolledBack();
    }

    @ParameterizedTest
    @CsvSource(delimiter = '|', value = {
        "{notes}|{\"note_text\":\"\"}",
        "{applicant,bank_account_details}|{\"bank_account_type\":\"UK\",\"uk_bank_details\":{}}",
        "{respondent_account,application_code}|\"UNKNOWN\""
    })
    void validatesPersistedNoteBankAndReferenceDataBeforeProcedure(String path, String replacement) {
        jdbc.update("UPDATE draft_casefiles SET casefile=jsonb_set(casefile::jsonb,?::text[],?::jsonb)::json "
            + "WHERE draft_casefile_id=1062901", path, replacement);
        assertThatThrownBy(() -> processing.processPendingDraft(message))
            .isInstanceOf(DraftCasefilePublicationException.class);
        verify(publication, never()).publish(any());
        assertRolledBack();
    }

    @Test
    void completionConstraintFailureDoesNotExposeSavedData(CapturedOutput output) {
        jdbc.execute("ALTER TABLE draft_casefiles ADD CONSTRAINT publication_test_failure "
            + "CHECK (casefile_status <> 'PUBLISHED')");
        try {
            consumer.consume("{\"draft_casefile_id\":1062901,\"checker_user_id\":123,"
                + "\"originating_ip_address\":\"192.0.2.1\",\"approval_timestamp\":\"2024-01-02T00:00:00Z\"}");
            assertThat(status()).isEqualTo("PUBLISHING_FAILED");
            assertThat(output.getAll()).doesNotContain("Synthetic Respondent", "Synthetic Applicant",
                "Synthetic saved submitter", "Synthetic saved approver", "192.0.2.1");
        } finally {
            jdbc.execute("ALTER TABLE draft_casefiles DROP CONSTRAINT publication_test_failure");
        }
    }

    private void assertRolledBack() {
        assertThat(status()).isEqualTo("PUBLISHING_PENDING");
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM respondent_accounts WHERE business_unit_id=32055",
            Long.class)).isZero();
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM account_number_index WHERE business_unit_id=32055",
            Long.class)).isZero();
        verifyNoInteractions(logging);
    }

    private String status() {
        return jdbc.queryForObject("SELECT casefile_status::text FROM draft_casefiles WHERE draft_casefile_id=1062901",
            String.class);
    }
}
