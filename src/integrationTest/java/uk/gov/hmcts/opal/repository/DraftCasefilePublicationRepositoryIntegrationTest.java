package uk.gov.hmcts.opal.repository;

import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.jdbc.Sql;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.test.context.transaction.TestTransaction;
import tools.jackson.databind.json.JsonMapper;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.repository.extensions.DraftCasefilePublicationRepository;

import static org.assertj.core.api.Assertions.assertThat;

@TestPropertySource(properties = {
    "opal.redis.enabled=false", "management.health.redis.enabled=false", "spring.jpa.open-in-view=false"
})
@Transactional
@Sql("/draft-casefile/publication-fixtures.sql")
class DraftCasefilePublicationRepositoryIntegrationTest extends BaseIntegrationTest {

    @Autowired
    private DraftCasefilePublicationRepository publication;
    @Autowired
    private DraftCasefileRepository drafts;
    @Autowired
    private JdbcTemplate jdbc;
    @Autowired
    private EntityManager entityManager;

    @Test
    void returnsAllThreeOutputsFromRealProvider() {
        var result = publication.publish(1062901L);
        var accounts = JsonMapper.builder().build().readTree(result.publishedAccountsJson());
        assertThat(result.respondentAccountId()).isPositive();
        assertThat(accounts.get("respondent_account").get("account_id").longValue())
            .isEqualTo(result.respondentAccountId());
        assertThat(accounts.get("respondent_account").get("account_number").asString())
            .isEqualTo(result.accountNumber());
        assertThat(accounts.get("applicant_account").get("account_id").longValue()).isPositive();
        assertThat(accounts.get("minor_creditor_accounts").get(0).get("creditor_sequence").intValue()).isEqualTo(7);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM respondent_accounts WHERE business_unit_id=32055",
            Long.class)).isEqualTo(1L);
    }

    @Test
    void rollsBackGraphAndReservationsWithJpaTransaction() {
        publication.publish(1062901L);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM account_number_index WHERE business_unit_id=32055",
            Long.class)).isEqualTo(3L);
        TestTransaction.flagForRollback();
        TestTransaction.end();
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM respondent_accounts WHERE business_unit_id=32055",
            Long.class)).isZero();
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM account_number_index WHERE business_unit_id=32055",
            Long.class)).isZero();
    }

    @Test
    void preservesBigintIdentities() {
        jdbc.execute("ALTER SEQUENCE respondent_account_id_seq RESTART WITH 9007199254740993");
        var result = publication.publish(1062901L);
        assertThat(result.respondentAccountId()).isEqualTo(9007199254740993L);
        assertThat(JsonMapper.builder().build().readTree(result.publishedAccountsJson())
            .get("respondent_account").get("account_id").longValue()).isEqualTo(9007199254740993L);
    }

    @Test
    void leavesExistingVersionUnchangedBeforeMutation() {
        var draft = drafts.findForPublicationById(1062901L).orElseThrow();
        publication.initialiseLegacyVersion(draft);
        assertThat(draft.getVersionNumber()).isEqualTo(1L);
    }

    @Test
    void updatesManagedLegacyDraftWithoutInsertingAnotherRow() {
        jdbc.update("UPDATE draft_casefiles SET version_number=NULL WHERE draft_casefile_id=1062902");
        var draft = drafts.findForPublicationById(1062902L).orElseThrow();
        publication.initialiseLegacyVersion(draft);
        ReflectionTestUtils.setField(draft, "casefileStatus", DraftCasefileStatus.PUBLISHING_FAILED);
        entityManager.flush();
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM draft_casefiles WHERE business_unit_id=32055",
            Long.class)).isEqualTo(2L);
        assertThat(draft.getVersionNumber()).isNotNull();
    }
}
