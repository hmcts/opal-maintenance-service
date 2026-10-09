package uk.gov.hmcts.opal.repository;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.jdbc.Sql;
import tools.jackson.databind.json.JsonMapper;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.common.exception.OpalApiException;
import uk.gov.hmcts.opal.entity.CountryEntity;
import uk.gov.hmcts.opal.entity.MaintenanceApplicationEntity;
import uk.gov.hmcts.opal.entity.MajorCreditorEntity;
import uk.gov.hmcts.opal.exception.DraftCasefileError;
import uk.gov.hmcts.opal.generated.model.DraftCasefileAddRequest;
import uk.gov.hmcts.opal.validator.DraftCasefileValidator;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.catchThrowableOfType;

@TestPropertySource(properties = {
    "spring.flyway.locations=classpath:db/migration/ddl",
    "opal.redis.enabled=false",
    "management.health.redis.enabled=false",
    "spring.jpa.open-in-view=false"
})
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@Sql(scripts = {"/db/major-creditor-controller-fixtures.sql", "/db/maintenance-application-controller-fixtures.sql",
    "/db/results-controller-fixtures.sql"})
@Sql(scripts = {"/db/major-creditor-controller-cleanup.sql", "/db/maintenance-application-controller-cleanup.sql",
    "/db/results-controller-cleanup.sql"}, executionPhase = Sql.ExecutionPhase.AFTER_TEST_METHOD)
@Sql(statements = "DELETE FROM countries WHERE country_id IN (5000000201, 5000000202)",
    executionPhase = Sql.ExecutionPhase.AFTER_TEST_METHOD)
class DraftCasefileReferenceRepositoryIntegrationTest extends BaseIntegrationTest {

    @Autowired
    private CountryRepository countries;
    @Autowired
    private MaintenanceApplicationRepository applications;
    @Autowired
    private MajorCreditorRepository creditors;
    @Autowired
    private ResultRepository results;
    @Autowired
    private DraftCasefileValidator validator;
    @Autowired
    private JdbcTemplate jdbc;

    @Test
    void scopesIdenticalCreditorCodesToOwningBusinessUnit() {
        assertThat(creditors.findByBusinessUnitIdAndMajorCreditorCode((short) 31001, "T001"))
            .get().extracting(MajorCreditorEntity::getMajorCreditorId).isEqualTo(5000000001L);
        assertThat(creditors.findByBusinessUnitIdAndMajorCreditorCode((short) 31002, "T001"))
            .get().extracting(MajorCreditorEntity::getMajorCreditorId).isEqualTo(5000000006L);
        assertThat(creditors.findByBusinessUnitIdAndMajorCreditorCode((short) 31003, "T001")).isEmpty();
        assertThat(creditors.findByBusinessUnitIdAndMajorCreditorCode((short) 31001, "NONE")).isEmpty();
        assertThat(creditors.findByBusinessUnitIdAndMajorCreditorCode((short) 31001, "T003"))
            .get().extracting(MajorCreditorEntity::getActive).isEqualTo(false);
    }

    @Test
    void resolvesApplicationsByCodeWithoutFilteringAwayInactiveRows() {
        assertThat(applications.findByApplicationCode("APP00001"))
            .get().extracting(MaintenanceApplicationEntity::getApplicationId).isEqualTo((short) 32001);
        assertThat(applications.findByApplicationCode("APP00002"))
            .get().extracting(MaintenanceApplicationEntity::getActive).isEqualTo(false);
        assertThat(applications.findByApplicationCode("MISSING")).isEmpty();
    }

    @ParameterizedTest
    @CsvSource({"OTAT01,true", "OTAT02,false"})
    void loadsExistingRequiresCreditorFlagFromPostgres(String resultId, boolean requiresCreditor) {
        assertThat(results.findById(resultId)).get()
            .satisfies(result -> assertThat(result.getRequiresCreditor()).isEqualTo(requiresCreditor));
    }

    @Test
    void returnsAllCountryMatchesAndRejectsAmbiguityBeforePublication() {
        country(5000000201L, true, "2999-01-01", null);
        country(5000000202L, false, "1990-01-01", "1991-01-01");
        assertThat(countries.findByCjsCode((short) 31004)).extracting(CountryEntity::getActive)
            .containsExactlyInAnyOrder(true, false);
        OpalApiException failure = catchThrowableOfType(OpalApiException.class, () -> validator.validate(request()));
        assertThat(failure).isNotNull();
        assertThat(failure.getError()).isEqualTo(DraftCasefileError.INVALID_REQUEST);
        assertThat(failure.getDetail()).isEqualTo("Country CJS code must identify exactly one Country");
        assertThat(countries.findByCjsCode((short) 31005)).isEmpty();
    }

    @ParameterizedTest
    @CsvSource({"2999-01-01,2999-12-31", "1990-01-01,1991-01-01"})
    void acceptsActiveReferencesWithoutAddingEffectiveDateRules(String from, String to) {
        country(5000000201L, true, from, to);
        // APP00001 is active with a future start date; Result and Country dates are not extra rules.
        assertThatCode(() -> validator.validate(request())).doesNotThrowAnyException();
    }

    private void country(long id, boolean active, String from, String to) {
        jdbc.update("""
            INSERT INTO countries (country_id, cjs_code, country_name, active, date_used_from, date_used_to)
            VALUES (?, 31004, 'Synthetic Reference Country', ?, CAST(? AS date), CAST(? AS date))
            """, id, active, from, to);
    }

    private static DraftCasefileAddRequest request() {
        return JsonMapper.builder().build().readValue("""
            {"business_unit_id":31001,"casefile_type":"REMO In","casefile":{
              "respondent_account":{"business_unit_id":31001,"casefile_type":"REMO In",
                "application_code":"APP00001","central_authority_code":"T001",
                "respondent":{"party_details":{"organisation":false,"individual_details":{"surname":"Synthetic"},
                  "address":{"address_line_1":"Synthetic address","cjs_code":31004}}},
                "order_details":{"date_ordered":"2026-08-01","date_arrears_last_updated":"2026-08-02",
                  "interest_flag":false,"indexation":"None","payment_arrangement":"Court","payment_period":"Monthly",
                  "order_terms":[{"result_id":"OTAT02","result_responses":[
                    {"parameter_name":"Arbitrary","response":"not a number or date"}]}]}},
              "applicant":{"party_details":{"organisation":false,"individual_details":{"surname":"Synthetic"},
                "address":{"address_line_1":"Synthetic address","cjs_code":31004}},
                "bank_account_details":{"bank_account_type":"None or not applicable"}}}}
            """, DraftCasefileAddRequest.class);
    }
}
