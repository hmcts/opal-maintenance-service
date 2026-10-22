package uk.gov.hmcts.opal.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.jdbc.Sql;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.exception.DraftCasefilePublicationException.Attempt;

import java.time.LocalDateTime;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.context.jdbc.Sql.ExecutionPhase.AFTER_TEST_METHOD;

@TestPropertySource(properties = {"spring.flyway.locations=classpath:db/migration/ddl", "opal.redis.enabled=false",
    "management.health.redis.enabled=false", "spring.jpa.open-in-view=false"})
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@Sql("/draft-casefile/reference-fixtures.sql")
@Sql(scripts = "/draft-casefile/reference-cleanup.sql", executionPhase = AFTER_TEST_METHOD)
class DraftCasefilePublicationFailureIntegrationTest extends BaseIntegrationTest {
    @Autowired
    private DraftCasefilePublicationFailureService failures;
    @Autowired
    private JdbcTemplate jdbc;
    private final LocalDateTime approved = LocalDateTime.of(2026, 10, 21, 12, 0);

    @BeforeEach
    void insertDraft() {
        jdbc.update("""
            INSERT INTO draft_casefiles(draft_casefile_id,business_unit_id,created_date,submitted_by,submitted_by_name,
              validated_date,validated_by,validated_by_name,casefile,casefile_snapshot,casefile_type,casefile_status,
              casefile_status_date,timeline_data,version_number)
            VALUES(1062901,1,?,'SUBMITTER','Synthetic submitter',?,'CHECKER','Synthetic checker','{}','{}','REMO In',
              'PUBLISHING_PENDING',?,'[]',1)
            """, approved.minusDays(1), approved, approved);
    }

    @Test
    void commitsFailureWithoutChangingRetainedData() {
        final var before = jdbc.queryForMap("SELECT * FROM draft_casefiles WHERE draft_casefile_id=1062901");
        assertThat(failures.markFailed(attempt(1L), "Publication failed; contact support")).isTrue();
        var after = jdbc.queryForMap("SELECT * FROM draft_casefiles WHERE draft_casefile_id=1062901");
        assertThat(after.get("casefile_status").toString()).isEqualTo("PUBLISHING_FAILED");
        assertThat(after.get("version_number")).isEqualTo(2L);
        for (String field : new String[]{"casefile_status", "casefile_status_date",
            "status_message", "version_number"}) {
            before.remove(field);
            after.remove(field);
        }
        assertThat(after).isEqualTo(before);
    }

    @Test
    void handlesNullVersionUnderLock() {
        jdbc.update("UPDATE draft_casefiles SET version_number=NULL WHERE draft_casefile_id=1062901");
        assertThat(failures.markFailed(attempt(null), "Publication failed; contact support")).isTrue();
        assertThat(jdbc.queryForObject("SELECT version_number FROM draft_casefiles WHERE draft_casefile_id=1062901",
            Long.class)).isEqualTo(1L);
    }

    @Test
    void refusesChangedApprovalWithoutMutation() {
        jdbc.update("UPDATE draft_casefiles SET validated_by='OTHER' WHERE draft_casefile_id=1062901");
        assertThatThrownBy(() -> failures.markFailed(attempt(1L), "Publication failed; contact support"))
            .isInstanceOf(IllegalStateException.class);
        assertThat(jdbc.queryForObject(
            "SELECT casefile_status::text FROM draft_casefiles WHERE draft_casefile_id=1062901",
            String.class)).isEqualTo("PUBLISHING_PENDING");
    }

    @Test
    void preservesAlreadyPublishedOutcome() {
        jdbc.update("""
            UPDATE draft_casefiles SET casefile_status='PUBLISHED',account_id=101,account_number='R101',
              casefile_snapshot='{"respondent_account":{"account_id":101,"account_number":"R101"},
                "applicant_account":{"account_id":102,"account_number":"A102"},"minor_creditor_accounts":[]}'
            WHERE draft_casefile_id=1062901
            """);
        assertThat(failures.markFailed(attempt(1L), "Publication failed; contact support")).isFalse();
    }

    private Attempt attempt(Long version) {
        return new Attempt(1062901L, version, "CHECKER", approved);
    }
}
