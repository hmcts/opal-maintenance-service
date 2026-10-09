package uk.gov.hmcts.opal.mapper;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.ValueSource;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;
import tools.jackson.databind.node.ObjectNode;
import uk.gov.hmcts.opal.authorisation.MaintenanceUser;
import uk.gov.hmcts.opal.config.JacksonCompatibilityConfiguration;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.generated.model.DraftCasefileAddRequest;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class DraftCasefileMapperTest {

    private static final JsonMapper JSON = JsonMapper.builder().build();
    private static final Instant SUBMITTED = Instant.parse("2026-10-01T12:00:00.123456Z");
    private static final MaintenanceUser USER = new MaintenanceUser(99L, "synthetic-bu-user", "Synthetic User", null);
    private final DraftCasefileMapper mapper = new DraftCasefileMapper(
        new JacksonCompatibilityConfiguration().objectMapper());

    @ParameterizedTest
    @CsvSource(value = {"NULL|SYNTHETIC", "Example|SYNTHETIC, Example", "'   '|SYNTHETIC"},
        nullValues = "NULL", delimiter = '|')
    void derivesIndividualNames(String forenames, String expected) {
        DraftCasefileAddRequest request = request();
        if (forenames != null) {
            ((ObjectNode) request.getCasefile().at("/respondent_account/respondent/party_details/individual_details"))
                .put("forenames", forenames);
        }
        JsonNode snapshot = JSON.readTree(mapper.toEntity(request, USER, SUBMITTED).getCasefileSnapshot());
        assertThat(snapshot.at("/respondent_account/respondent_name").asString()).isEqualTo(expected);
    }

    @Test
    void preservesOrganisationNameAndExplicitNullAccountFields() {
        DraftCasefileAddRequest request = request();
        ObjectNode party = (ObjectNode) request.getCasefile().at("/applicant/party_details");
        party.remove("individual_details");
        party.put("organisation", true).putObject("organisation_details")
            .put("organisation_name", "Synthetic Organisation");
        JsonNode snapshot = JSON.readTree(mapper.toEntity(request, USER, SUBMITTED).getCasefileSnapshot());
        assertThat(snapshot.at("/applicant_account/applicant_name").asString()).isEqualTo("Synthetic Organisation");
        assertNullAccounts(snapshot.get("respondent_account"));
        assertNullAccounts(snapshot.get("applicant_account"));
    }

    @ParameterizedTest
    @ValueSource(booleans = {true, false})
    void createsEmptyMinorSnapshotForAbsentOrEmptyMinorCreditors(boolean present) {
        DraftCasefileAddRequest request = request();
        if (present) {
            ((ObjectNode) request.getCasefile()).putArray("minor_creditors");
        }
        JsonNode snapshot = JSON.readTree(mapper.toEntity(request, USER, SUBMITTED).getCasefileSnapshot());
        assertThat(snapshot.get("minor_creditor_accounts").isArray()).isTrue();
        assertThat(snapshot.get("minor_creditor_accounts").size()).isZero();
    }

    @Test
    void preservesMinorCreditorIdentifiersAndArrayOrder() {
        DraftCasefileAddRequest request = request();
        ObjectNode first = (ObjectNode) request.getCasefile().get("applicant").deepCopy();
        ObjectNode second = first.deepCopy();
        first.put("creditor_sequence", Integer.MAX_VALUE);
        second.put("creditor_sequence", 3);
        ((ObjectNode) request.getCasefile()).putArray("minor_creditors").add(first).add(second);
        DraftCasefileEntity entity = mapper.toEntity(request, USER, SUBMITTED);
        JsonNode minors = JSON.readTree(entity.getCasefileSnapshot()).get("minor_creditor_accounts");
        assertThat(minors.size()).isEqualTo(2);
        assertThat(minors.get(0).get("creditor_sequence").intValue()).isEqualTo(Integer.MAX_VALUE);
        assertThat(minors.get(1).get("creditor_sequence").intValue()).isEqualTo(3);
        for (JsonNode minor : minors) {
            assertNullAccounts(minor);
            assertThat(minor.get("name").asString()).isEqualTo("SYNTHETIC");
        }
        assertThat(JSON.readTree(entity.getCasefile())).isEqualTo(request.getCasefile());
    }

    @Test
    void preservesSubmittedValuesAndAbsenceWithoutRebuildingPayload() {
        DraftCasefileAddRequest request = request();
        JsonNode original = request.getCasefile().deepCopy();
        DraftCasefileEntity entity = mapper.toEntity(request, USER, SUBMITTED);
        assertThat(JSON.readTree(entity.getCasefile())).isEqualTo(original);
        assertThat(request.getCasefile()).isEqualTo(original);
        assertThat(JSON.readTree(entity.getCasefile()).at("/respondent_account/restrict_personal_information")
            .isMissingNode()).isTrue();
        assertThat(entity.getDraftCasefileId()).isNull();
        assertThat(entity.getBusinessUnitId()).isEqualTo((short) 31001);
        assertThat(entity.getCasefileType()).isEqualTo("REMO In");
        assertThat(entity.getCasefileStatus()).isEqualTo(DraftCasefileStatus.SUBMITTED);
        assertThat(entity.getCreatedDate()).isEqualTo(LocalDateTime.ofInstant(SUBMITTED, ZoneOffset.UTC));
        assertThat(entity.getCasefileStatusDate()).isEqualTo(entity.getCreatedDate());
        assertThat(entity.getSubmittedBy()).isEqualTo(USER.businessUnitUserId());
        assertThat(entity.getSubmittedByName()).isEqualTo(USER.displayName());
        assertThat(entity.getValidatedDate()).isNull();
        assertThat(entity.getValidatedBy()).isNull();
        assertThat(entity.getValidatedByName()).isNull();
        assertThat(entity.getStatusMessage()).isNull();
        assertThat(entity.getAccountId()).isNull();
        assertThat(entity.getAccountNumber()).isNull();
        assertThat(entity.getVersionNumber()).isNull();
        JsonNode timeline = JSON.readTree(entity.getTimelineData());
        assertThat(timeline.size()).isEqualTo(1);
        assertThat(timeline.get(0).size()).isEqualTo(3);
        assertThat(timeline.get(0).get("username").asString()).isEqualTo(USER.displayName());
        assertThat(timeline.get(0).get("status").asString()).isEqualTo("Submitted");
        assertThat(Instant.parse(timeline.get(0).get("status_date").asString())).isEqualTo(SUBMITTED);
        assertThat(timeline.get(0).has("reason_text")).isFalse();
    }

    @Test
    void treatsMetadataSerializationFailureAsServerFailure() throws Exception {
        ObjectMapper broken = mock(ObjectMapper.class);
        when(broken.writeValueAsString(any())).thenThrow(mock(JsonProcessingException.class));
        assertThatThrownBy(() -> new DraftCasefileMapper(broken).toEntity(request(), USER, SUBMITTED))
            .isInstanceOf(IllegalStateException.class).hasCauseInstanceOf(JsonProcessingException.class);
    }

    private static void assertNullAccounts(JsonNode account) {
        assertThat(account.has("account_id")).isTrue();
        assertThat(account.get("account_id").isNull()).isTrue();
        assertThat(account.has("account_number")).isTrue();
        assertThat(account.get("account_number").isNull()).isTrue();
    }

    private static DraftCasefileAddRequest request() {
        return JSON.readValue("""
            {"business_unit_id":31001,"casefile_type":"REMO In","casefile":{
              "respondent_account":{"business_unit_id":31001,"casefile_type":"REMO In","application_code":"SYNTH",
                "central_authority_code":"SYN",
                "respondent":{"party_details":{"organisation":false,"individual_details":{"surname":"Synthetic"}}},
                "order_details":{"order_terms":[{"result_id":"SYNTH","major_creditor_code":"SYN",
                  "result_responses":[{"parameter_name":"Arbitrary","response":"0001.00"},
                    {"parameter_name":"Other","response":"not a date"}]}]}},
              "applicant":{"party_details":{"organisation":false,"individual_details":{"surname":"Synthetic"}}}}}
            """, DraftCasefileAddRequest.class);
    }
}
