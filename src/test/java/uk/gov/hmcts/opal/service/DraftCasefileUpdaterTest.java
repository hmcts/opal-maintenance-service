package uk.gov.hmcts.opal.service;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;
import tools.jackson.databind.node.ObjectNode;
import uk.gov.hmcts.opal.authorisation.MaintenanceUser;
import uk.gov.hmcts.opal.config.JacksonCompatibilityConfiguration;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.generated.model.DraftCasefileAddRequest;
import uk.gov.hmcts.opal.generated.model.DraftCasefileReplaceRequest;
import uk.gov.hmcts.opal.mapper.DraftCasefileJsonMapper;
import uk.gov.hmcts.opal.mapper.DraftCasefileMapper;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DraftCasefileUpdaterTest {

    private static final JsonMapper JSON = JsonMapper.builder().build();
    private static final Instant SUBMITTED = Instant.parse("2026-10-01T12:00:00.123456Z");
    private static final MaintenanceUser USER = new MaintenanceUser(99L, "synthetic-bu-user", "Synthetic User", null);
    private final DraftCasefileMapper mapper = new DraftCasefileMapper(
        new JacksonCompatibilityConfiguration().objectMapper());
    private final DraftCasefileUpdater updater = new DraftCasefileUpdater(mapper,
        new DraftCasefileJsonMapper(JSON, new JacksonCompatibilityConfiguration().objectMapper()));

    @ParameterizedTest
    @ValueSource(booleans = {true, false})
    void resubmitsWithRegeneratedSnapshotAndPreservedHistory(boolean creditorsPresent) {
        final Instant timestamp = Instant.parse("2026-10-09T10:00:00.123456Z");
        final MaintenanceUser resubmitter = new MaintenanceUser(123L, "BUU-2", "Synthetic Resubmitter", null);
        final DraftCasefileEntity existing = rejected();
        ObjectNode corrected = (ObjectNode) request().getCasefile().deepCopy();
        ObjectNode party = (ObjectNode) corrected.at("/applicant/party_details");
        party.remove("individual_details");
        party.put("organisation", true).putObject("organisation_details")
            .put("organisation_name", "Synthetic Organisation");
        if (creditorsPresent) {
            ObjectNode first = JSON.createObjectNode().put("creditor_sequence", 3);
            first.set("party_details", party.deepCopy());
            ObjectNode second = first.deepCopy().put("creditor_sequence", 1);
            corrected.putArray("minor_creditors").add(first).add(second);
        }
        DraftCasefileReplaceRequest replacement = new DraftCasefileReplaceRequest()
            .businessUnitId((short) 31001).casefile(corrected);
        DraftCasefileEntity updated = updater.applyResubmission(existing, replacement, resubmitter, timestamp);
        assertThat(updated).usingRecursiveComparison().ignoringFields("casefile", "casefileSnapshot",
            "casefileStatus", "casefileStatusDate", "submittedBy", "submittedByName", "timelineData")
            .isEqualTo(existing);
        assertThat(updated.getSubmittedBy()).isEqualTo("BUU-2");
        assertThat(updated.getSubmittedByName()).isEqualTo("Synthetic Resubmitter");
        assertThat(updated.getCasefileStatus()).isEqualTo(DraftCasefileStatus.RESUBMITTED);
        assertThat(updated.getCasefileStatusDate()).isEqualTo(LocalDateTime.ofInstant(timestamp, ZoneOffset.UTC));
        assertThat(JSON.readTree(updated.getCasefile())).isEqualTo(corrected);
        JsonNode snapshot = JSON.readTree(updated.getCasefileSnapshot());
        assertThat(snapshot.at("/applicant_account/applicant_name").asString()).isEqualTo("Synthetic Organisation");
        assertNullAccounts(snapshot.get("respondent_account"));
        assertNullAccounts(snapshot.get("applicant_account"));
        JsonNode minors = snapshot.get("minor_creditor_accounts");
        assertThat(minors.size()).isEqualTo(creditorsPresent ? 2 : 0);
        if (creditorsPresent) {
            assertThat(minors.get(0).get("creditor_sequence").intValue()).isEqualTo(3);
            assertThat(minors.get(1).get("creditor_sequence").intValue()).isEqualTo(1);
            for (JsonNode minor : minors) {
                assertNullAccounts(minor);
                assertThat(minor.get("name").asString()).isEqualTo("Synthetic Organisation");
            }
        }
        JsonNode timeline = JSON.readTree(updated.getTimelineData());
        JsonNode history = JSON.readTree(existing.getTimelineData());
        assertThat(timeline.size()).isEqualTo(3);
        assertThat(timeline.get(0)).isEqualTo(history.get(0));
        assertThat(timeline.get(1)).isEqualTo(history.get(1));
        assertThat(timeline.get(2).get("status").asString()).isEqualTo("Resubmitted");
        assertThat(timeline.get(2).get("username").asString()).isEqualTo(resubmitter.displayName());
        assertThat(Instant.parse(timeline.get(2).get("status_date").asString())).isEqualTo(timestamp);
        assertThat(timeline.get(2).has("reason_text")).isFalse();
        assertThat(existing.getCasefileStatus()).isEqualTo(DraftCasefileStatus.REJECTED);
        assertThat(JSON.readTree(existing.getTimelineData()).size()).isEqualTo(2);
        assertThat(existing.getSubmittedBy()).isEqualTo(USER.businessUnitUserId());
    }

    @Test
    void rejectsCorruptHistoryWithoutDisclosingStoredValues() {
        DraftCasefileEntity existing = rejected().toBuilder().timelineData("SYNTHETIC_PRIVATE_DATA").build();
        assertThatThrownBy(() -> updater.applyResubmission(existing,
            new DraftCasefileReplaceRequest().businessUnitId((short) 31001).casefile(request().getCasefile()),
            USER, SUBMITTED)).isInstanceOf(IllegalStateException.class)
            .hasMessage("Unable to read stored Draft Casefile data").hasNoCause();
    }

    private DraftCasefileEntity rejected() {
        return mapper.toEntity(request(), USER, SUBMITTED).toBuilder().draftCasefileId(88L)
            .casefileStatus(DraftCasefileStatus.REJECTED).versionNumber(4L)
            .validatedDate(LocalDateTime.ofInstant(SUBMITTED, ZoneOffset.UTC)).validatedBy("BUU-3")
            .validatedByName("Synthetic Validator").statusMessage("Synthetic reason")
            .accountId(90L).accountNumber("SYNTHETIC-90")
            .casefileSnapshot("{\"minor_creditor_accounts\":[{\"creditor_sequence\":99,\"name\":\"Old name\"}]}")
            .timelineData("""
                [{"username":"Synthetic User","status":"Submitted","status_date":"2026-10-01T12:00:00.123456Z"},
                 {"username":"Synthetic Validator","status":"Rejected","status_date":"2026-10-02T12:00:00Z",
                  "reason_text":"Synthetic reason"}]
                """).build();
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
