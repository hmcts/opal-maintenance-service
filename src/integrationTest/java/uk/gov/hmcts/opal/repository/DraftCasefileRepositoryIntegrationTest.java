package uk.gov.hmcts.opal.repository;

import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.TestPropertySource;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.authorisation.MaintenanceUser;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.generated.model.CasefileType;
import uk.gov.hmcts.opal.generated.model.DraftCasefileAddRequest;
import uk.gov.hmcts.opal.generated.model.DraftCasefileAddResponse;
import uk.gov.hmcts.opal.mapper.DraftCasefileMapper;

import java.time.Instant;
import java.time.ZoneOffset;
import java.util.concurrent.atomic.AtomicReference;

import static org.assertj.core.api.Assertions.assertThat;

@TestPropertySource(properties = {
    "spring.flyway.locations=classpath:db/migration/ddl",
    "opal.redis.enabled=false",
    "management.health.redis.enabled=false",
    "spring.jpa.open-in-view=false"
})
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
class DraftCasefileRepositoryIntegrationTest extends BaseIntegrationTest {

    private static final JsonMapper JSON = JsonMapper.builder().build();
    private static final Instant SUBMITTED = Instant.parse("2026-10-01T12:00:00.123456Z");
    @Autowired
    private DraftCasefileRepository repository;
    @Autowired
    private DraftCasefileMapper mapper;
    @Autowired
    private EntityManager entityManager;
    @Autowired
    private JdbcTemplate jdbc;
    @Autowired
    private PlatformTransactionManager transactionManager;
    @Autowired
    private com.fasterxml.jackson.databind.ObjectMapper compatibilityMapper;

    @ParameterizedTest
    @ValueSource(strings = {"REMO In", "REMO Out", "REMO Out (CMS)"})
    void savesAndReloadsAllCaseTypesAndUnchangedJsonWithOneSubmissionInstant(String type) {
        new TransactionTemplate(transactionManager).executeWithoutResult(transaction -> {
            insertBusinessUnit();
            DraftCasefileAddRequest request = request(type);
            DraftCasefileEntity mapped = mapper.toEntity(request, user(), SUBMITTED);
            DraftCasefileEntity saved = repository.saveAndFlush(mapped);
            assertThat(saved.getDraftCasefileId()).isPositive();
            DraftCasefileAddResponse response = mapper.toResponse(saved);
            assertThat(response.getDraftCasefileId()).isEqualTo(saved.getDraftCasefileId());
            assertThat(response.getCreatedDate()).isEqualTo(SUBMITTED.atOffset(ZoneOffset.UTC));
            assertThat(response.getCasefileStatusDate()).isEqualTo(response.getCreatedDate());
            assertThat(response.getCasefileType()).isEqualTo(CasefileType.fromValue(type));
            assertResponseWire(response);
            entityManager.clear();
            DraftCasefileEntity reloaded = repository.findById(saved.getDraftCasefileId()).orElseThrow();
            assertThat(reloaded.getBusinessUnitId()).isEqualTo((short) 31011);
            assertThat(reloaded.getCasefileType()).isEqualTo(type);
            assertThat(reloaded.getCasefileStatus()).isEqualTo(DraftCasefileStatus.SUBMITTED);
            assertThat(JSON.readTree(reloaded.getCasefile())).isEqualTo(request.getCasefile());
            assertThat(JSON.readTree(reloaded.getCasefileSnapshot()))
                .isEqualTo(JSON.readTree(mapped.getCasefileSnapshot()));
            assertThat(JSON.readTree(reloaded.getTimelineData())).isEqualTo(JSON.readTree(mapped.getTimelineData()));
            assertThat(reloaded.getCreatedDate().toInstant(ZoneOffset.UTC)).isEqualTo(SUBMITTED);
            assertThat(reloaded.getCasefileStatusDate()).isEqualTo(reloaded.getCreatedDate());
            assertThat(Instant.parse(JSON.readTree(reloaded.getTimelineData()).get(0).get("status_date").asString()))
                .isEqualTo(reloaded.getCreatedDate().toInstant(ZoneOffset.UTC));
            transaction.setRollbackOnly();
        });
    }

    @Test
    void jpaAndJdbcShareOneTransactionAndBothRollback() {
        AtomicReference<Long> id = new AtomicReference<>();
        new TransactionTemplate(transactionManager).executeWithoutResult(transaction -> {
            insertBusinessUnit();
            DraftCasefileEntity saved = repository.saveAndFlush(mapper.toEntity(request("REMO In"), user(), SUBMITTED));
            id.set(saved.getDraftCasefileId());
            assertThat(jdbc.queryForObject("SELECT count(*) FROM draft_casefiles WHERE draft_casefile_id = ?",
                Integer.class, id.get())).isEqualTo(1);
            transaction.setRollbackOnly();
        });
        assertThat(repository.findById(id.get())).isEmpty();
        assertThat(jdbc.queryForObject("SELECT count(*) FROM business_units WHERE business_unit_id = 31011",
            Integer.class)).isZero();
    }

    @ParameterizedTest
    @EnumSource(DraftCasefileStatus.class)
    void persistsEveryDatabaseLifecycleStatus(DraftCasefileStatus status) {
        new TransactionTemplate(transactionManager).executeWithoutResult(transaction -> {
            insertBusinessUnit();
            DraftCasefileEntity entity = mapper.toEntity(request("REMO In"), user(), SUBMITTED).toBuilder()
                .casefileStatus(status).build();
            Long id = repository.saveAndFlush(entity).getDraftCasefileId();
            entityManager.clear();
            assertThat(repository.findById(id).orElseThrow().getCasefileStatus()).isEqualTo(status);
            transaction.setRollbackOnly();
        });
    }

    @Test
    void observesPostgresMicrosecondRoundingWithoutNormalizingTheSubmissionInTheMapper() {
        Instant nanoseconds = Instant.parse("2026-10-01T12:00:00.123456789Z");
        new TransactionTemplate(transactionManager).executeWithoutResult(transaction -> {
            insertBusinessUnit();
            Long id = repository.saveAndFlush(mapper.toEntity(request("REMO In"), user(), nanoseconds))
                .getDraftCasefileId();
            entityManager.clear();
            DraftCasefileEntity reloaded = repository.findById(id).orElseThrow();
            assertThat(reloaded.getCreatedDate().toInstant(ZoneOffset.UTC))
                .isEqualTo(Instant.parse("2026-10-01T12:00:00.123457Z"));
            assertThat(reloaded.getCasefileStatusDate()).isEqualTo(reloaded.getCreatedDate());
            assertThat(Instant.parse(JSON.readTree(reloaded.getTimelineData()).get(0).get("status_date").asString()))
                .isEqualTo(nanoseconds);
            transaction.setRollbackOnly();
        });
    }

    private void assertResponseWire(DraftCasefileAddResponse response) {
        JsonNode wire;
        try {
            wire = JSON.readTree(compatibilityMapper.writeValueAsString(response));
        } catch (com.fasterxml.jackson.core.JsonProcessingException exception) {
            throw new AssertionError(exception);
        }
        assertThat(wire.propertyNames()).containsExactlyInAnyOrder("draft_casefile_id", "business_unit_id",
            "created_date", "submitted_by", "submitted_by_name", "casefile_snapshot", "casefile_type",
            "casefile_status", "casefile_status_date", "timeline_data");
        assertThat(wire.get("casefile_status").asString()).isEqualTo("SUBMITTED");
        assertThat(wire.get("submitted_by").asString()).isEqualTo(user().businessUnitUserId());
        assertThat(wire.get("submitted_by_name").asString()).isEqualTo(user().displayName());
        assertThat(wire.at("/casefile_snapshot/respondent_account/account_id").isNull()).isTrue();
        assertThat(wire.at("/casefile_snapshot/respondent_account/account_number").isNull()).isTrue();
        assertThat(wire.at("/casefile_snapshot/applicant_account/account_id").isNull()).isTrue();
        assertThat(wire.at("/casefile_snapshot/applicant_account/account_number").isNull()).isTrue();
        assertThat(wire.get("timeline_data").size()).isEqualTo(1);
        assertThat(wire.at("/timeline_data/0/status_date")).isEqualTo(wire.get("created_date"));
        assertThat(wire.at("/timeline_data/0/status").asString()).isEqualTo("Submitted");
        assertThat(wire.at("/timeline_data/0").has("reason_text")).isFalse();
    }

    private void insertBusinessUnit() {
        jdbc.update("""
            INSERT INTO business_units
                (business_unit_id, business_unit_code, business_unit_name, business_unit_type, welsh_language)
            VALUES (31011, 'ZD11', 'Synthetic Draft Unit', 'Area', false)
            """);
    }

    private static MaintenanceUser user() {
        return new MaintenanceUser(99L, "synthetic-bu-user", "Synthetic User", null);
    }

    private static DraftCasefileAddRequest request(String type) {
        return new DraftCasefileAddRequest().businessUnitId((short) 31011).casefileType(CasefileType.fromValue(type))
            .casefile(JSON.readTree("""
                {"respondent_account":{"business_unit_id":31011,"application_code":"SYNTH",
                  "respondent":{"party_details":{"organisation":false,"individual_details":{"surname":"Synthetic"}}},
                  "order_details":{"order_terms":[{"result_id":"SYNTH","result_responses":[
                    {"parameter_name":"Amount","response":"0001.00"},
                    {"parameter_name":"Other","response":"not a date"}]}]}},
                  "applicant":{"party_details":{"organisation":true,
                    "organisation_details":{"organisation_name":"Synthetic Organisation"}}}}
                """));
    }
}
