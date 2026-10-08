package uk.gov.hmcts.opal.mapper;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.boot.autoconfigure.AutoConfigurations;
import org.springframework.boot.jackson.autoconfigure.JacksonAutoConfiguration;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import tools.jackson.databind.json.JsonMapper;
import uk.gov.hmcts.opal.config.JacksonCompatibilityConfiguration;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.generated.model.CasefileTimelineEntry;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DraftCasefileGetMapperTest {

    private static final JsonMapper JSON = JsonMapper.builder().build();
    private static final ObjectMapper COMPATIBLE = new JacksonCompatibilityConfiguration().objectMapper();
    private final DraftCasefileGetMapper mapper = new DraftCasefileGetMapperImpl(
        new DraftCasefileJsonMapper(JSON, COMPATIBLE), new DraftCasefileValueMapper());

    @Test
    void returnsTheCompleteStoredPayloadAndPublishedSummary() throws Exception {
        var row = publishedRow();
        var response = mapper.toResponse(row);
        assertThat(response.getCasefile()).isEqualTo(JSON.readTree(row.getCasefile()));
        assertThat(COMPATIBLE.readTree(COMPATIBLE.writeValueAsString(response.getCasefileSnapshot())))
            .isEqualTo(COMPATIBLE.readTree(row.getCasefileSnapshot()));
        assertStoredTimeline(response.getTimelineData(), row.getTimelineData());
        assertThat(COMPATIBLE.readTree(COMPATIBLE.writeValueAsString(response.getTimelineData())))
            .isEqualTo(COMPATIBLE.readTree(row.getTimelineData()));
        assertThat(response.getDraftCasefileId()).isEqualTo(row.getDraftCasefileId());
        assertThat(response.getBusinessUnitId()).isEqualTo(row.getBusinessUnitId());
        assertThat(response.getSubmittedBy()).isEqualTo(row.getSubmittedBy());
        assertThat(response.getSubmittedByName()).isEqualTo(row.getSubmittedByName());
        assertThat(response.getCasefileType().getValue()).isEqualTo(row.getCasefileType());
        assertThat(response.getValidatedByName().get()).isEqualTo(row.getValidatedByName());
        assertThat(response.getStatusMessage().get()).isEqualTo(row.getStatusMessage());
        assertThat(response.getCreatedDate().toInstant()).isEqualTo(Instant.parse("2026-10-01T12:00:00Z"));
        assertThat(response.getCasefileStatusDate().toInstant()).isEqualTo(Instant.parse("2026-10-03T12:00:00Z"));
        assertThat(response.getCasefileStatusDate().getOffset()).isEqualTo(ZoneOffset.UTC);
        assertThat(response.getCasefileStatus().getValue()).isEqualTo("PUBLISHED");
        assertThat(response.getCasefileStatusName()).isEqualTo("Published");
        assertThat(response.getCreatedDate().getOffset()).isEqualTo(ZoneOffset.UTC);
        assertThat(response.getValidatedDate().get().toInstant()).isEqualTo(Instant.parse("2026-10-02T12:00:00Z"));
        assertThat(response.getValidatedBy().get()).isEqualTo("BUU-2");
    }

    @ParameterizedTest
    @ValueSource(strings = {"casefile", "snapshot", "timeline"})
    void doesNotExposeParserDetailsForUnreadableStoredMetadata(String field) {
        var builder = publishedRow().toBuilder();
        String unreadable = "Synthetic private value: broken JSON";
        switch (field) {
            case "casefile" -> builder.casefile(unreadable);
            case "snapshot" -> builder.casefileSnapshot(unreadable);
            case "timeline" -> builder.timelineData(unreadable);
            default -> throw new IllegalArgumentException("Unexpected field");
        }
        var row = builder.build();
        assertThatThrownBy(() -> mapper.toResponse(row))
            .isInstanceOf(IllegalStateException.class)
            .hasMessage("Unable to read stored Draft Casefile data").hasNoCause();
    }

    @Test
    void preservesSubmittedNullMetadataAndEmptyMinorCreditorAccounts() throws Exception {
        var row = publishedRow().toBuilder()
            .validatedDate(null).validatedBy(null).validatedByName(null).statusMessage(null)
            .casefileStatus(DraftCasefileStatus.SUBMITTED)
            .casefileSnapshot("""
                {"respondent_account":{"account_id":null,"account_number":null,"respondent_name":"Synthetic R"},
                 "applicant_account":{"account_id":null,"account_number":null,"applicant_name":"Synthetic A"},
                 "minor_creditor_accounts":[]}
                """)
            .timelineData("""
                [{"username":"Synthetic Submitter","status":"Submitted","status_date":"2026-10-01T12:00:00Z"}]
                """).build();
        var response = mapper.toResponse(row);
        assertThat(response.getValidatedDate().isPresent()).isTrue();
        assertThat(response.getValidatedDate().get()).isNull();
        assertThat(response.getValidatedBy().isPresent()).isTrue();
        assertThat(response.getValidatedBy().get()).isNull();
        assertThat(response.getValidatedByName().isPresent()).isTrue();
        assertThat(response.getValidatedByName().get()).isNull();
        assertThat(response.getStatusMessage().isPresent()).isTrue();
        assertThat(response.getStatusMessage().get()).isNull();
        assertThat(response.getCasefileSnapshot().getMinorCreditorAccounts()).isEmpty();
        assertThat(COMPATIBLE.readTree(COMPATIBLE.writeValueAsString(response.getCasefileSnapshot())))
            .isEqualTo(COMPATIBLE.readTree(row.getCasefileSnapshot()));
        assertStoredTimeline(response.getTimelineData(), row.getTimelineData());
        assertThat(COMPATIBLE.readTree(COMPATIBLE.writeValueAsString(response.getTimelineData())))
            .isEqualTo(COMPATIBLE.readTree(row.getTimelineData()));
        assertThat(response.getCasefileStatus().getValue()).isEqualTo("SUBMITTED");
        assertThat(response.getCasefileStatusName()).isEqualTo("Submitted");
    }

    @ParameterizedTest
    @CsvSource({"SUBMITTED, Submitted", "DELETED, Deleted", "REJECTED, Rejected",
        "PUBLISHING_PENDING, Publishing pending", "PUBLISHED, Published",
        "PUBLISHING_FAILED, Publishing failed", "RESUBMITTED, Resubmitted"})
    void returnsEveryLifecycleCodeAndDisplayLabel(DraftCasefileStatus status, String label) {
        var row = publishedRow().toBuilder().casefileStatus(status).build();
        var response = mapper.toResponse(row);
        assertThat(response.getCasefileStatus().getValue()).isEqualTo(status.name());
        assertThat(response.getCasefileStatusName()).isEqualTo(label);
    }

    @Test
    void httpSerializationOmitsAbsentReasonAndPreservesSuppliedReason() {
        new ApplicationContextRunner()
            .withConfiguration(AutoConfigurations.of(JacksonAutoConfiguration.class))
            .run(context -> {
                var json = context.getBean(JsonMapper.class);
                var timeline = mapper.toResponse(publishedRow()).getTimelineData();
                var serialized = json.readTree(json.writeValueAsString(timeline));
                assertThat(serialized.get(0).has("reason_text")).isFalse();
                assertThat(serialized.get(1).get("reason_text").asString())
                    .isEqualTo("Synthetic rejection reason");
                assertThat(serialized.get(2).has("reason_text")).isFalse();
                assertThat(serialized.get(3).has("reason_text")).isFalse();
            });
    }

    private static void assertStoredTimeline(List<CasefileTimelineEntry> timeline, String stored) {
        var expected = JSON.readTree(stored);
        assertThat(timeline).hasSize(expected.size());
        for (int index = 0; index < timeline.size(); index++) {
            var event = timeline.get(index);
            var original = expected.get(index);
            assertThat(event.getUsername()).isEqualTo(original.get("username").asString());
            assertThat(event.getStatus().getValue()).isEqualTo(original.get("status").asString());
            assertThat(event.getStatusDate().toInstant())
                .isEqualTo(Instant.parse(original.get("status_date").asString()));
            assertThat(event.getStatusDate().getOffset()).isEqualTo(ZoneOffset.UTC);
            assertThat(event.getReasonText()).isEqualTo(original.path("reason_text").asString(null));
        }
    }

    private static DraftCasefileEntity publishedRow() {
        return DraftCasefileEntity.builder().draftCasefileId(123L).businessUnitId((short) 1)
            .createdDate(LocalDateTime.parse("2026-10-01T12:00:00"))
            .submittedBy("BUU-1").submittedByName("Synthetic Submitter")
            .validatedDate(LocalDateTime.parse("2026-10-02T12:00:00"))
            .validatedBy("BUU-2").validatedByName("Synthetic Checker")
            .casefileType("REMO In").casefileStatus(DraftCasefileStatus.PUBLISHED)
            .casefileStatusDate(LocalDateTime.parse("2026-10-03T12:00:00"))
            .statusMessage("Synthetic lifecycle message").versionNumber(4L)
            .casefile("""
                {"respondent_account":{"respondent":{"party_details":{"organisation":false,
                  "individual_details":{"surname":"Synthetic Respondent"}}}},
                 "applicant":{"party_details":{"organisation":false,
                  "individual_details":{"surname":"Synthetic Applicant"}}},
                 "minor_creditors":[{"creditor_sequence":7},{"creditor_sequence":2}],
                 "future_payload_field":{"nested":["kept",null,12.5]}}
                """)
            .casefileSnapshot("""
                {"respondent_account":{"account_id":101,"account_number":"R101","respondent_name":"Synthetic R"},
                 "applicant_account":{"account_id":201,"account_number":"A201","applicant_name":"Synthetic A"},
                 "minor_creditor_accounts":[
                  {"creditor_sequence":7,"account_id":301,"account_number":"M301","name":"Synthetic M1"},
                  {"creditor_sequence":2,"account_id":302,"account_number":"M302","name":"Synthetic M2"}]}
                """)
            .timelineData("""
                [{"username":"Synthetic Submitter","status":"Submitted","status_date":"2026-10-01T12:00:00Z"},
                 {"username":"Synthetic Checker","status":"Rejected","status_date":"2026-10-01T13:00:00Z",
                  "reason_text":"Synthetic rejection reason"},
                 {"username":"Synthetic Submitter","status":"Resubmitted","status_date":"2026-10-01T14:00:00Z"},
                 {"username":"Synthetic Checker","status":"Approved","status_date":"2026-10-02T12:00:00Z"}]
                """).build();
    }
}
