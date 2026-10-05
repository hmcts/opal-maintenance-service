package uk.gov.hmcts.opal.mapper;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.springframework.data.projection.SpelAwareProxyProjectionFactory;
import tools.jackson.databind.json.JsonMapper;
import uk.gov.hmcts.opal.config.JacksonCompatibilityConfiguration;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.repository.DraftCasefileSummaryProjection;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DraftCasefileSummaryMapperTest {
    private static final String SNAPSHOT = """
        {"respondent_account":{"account_id":101,"account_number":"R101","respondent_name":"Synthetic R"},
         "applicant_account":{"account_id":201,"account_number":"A201","applicant_name":"Synthetic A"},
         "minor_creditor_accounts":[
          {"creditor_sequence":7,"account_id":301,"account_number":"M301","name":"Synthetic M1"},
          {"creditor_sequence":2,"account_id":302,"account_number":"M302","name":"Synthetic M2"}]}
        """;
    private final com.fasterxml.jackson.databind.ObjectMapper compatible =
        new JacksonCompatibilityConfiguration().objectMapper();
    private final DraftCasefileSummaryMapper mapper = new DraftCasefileSummaryMapperImpl(
        new DraftCasefileJsonMapper(JsonMapper.builder().build(), compatible));

    @Test
    void preservesPublishedLinksSequencesAndDistinctApprovalDate() throws Exception {
        var summary = mapper.toSummary(projection(values()));
        var wire = compatible.readTree(compatible.writeValueAsString(summary));
        assertThat(wire.get("casefile_snapshot")).isEqualTo(compatible.readTree(SNAPSHOT));
        assertThat(wire.get("created_date").asText()).isEqualTo("2026-10-01T12:00:00.123456Z");
        assertThat(wire.get("validated_date").asText()).isEqualTo("2026-10-02T12:00:00Z");
        assertThat(wire.get("casefile_status_date").asText()).isEqualTo("2026-10-03T12:00:00Z");
        assertThat(wire.get("casefile_status_name").asText()).isEqualTo("Published");
        assertThat(wire.has("casefile")).isFalse();
        assertThat(wire.has("timeline_data")).isFalse();
        assertThat(wire.has("version_number")).isFalse();
    }

    @Test
    void preservesNullApprovalAndPrepublicationLinks() throws Exception {
        var values = values();
        values.put("validatedDate", null);
        values.put("casefileSnapshot", """
            {"respondent_account":{"account_id":null,"account_number":null,"respondent_name":"Synthetic R"},
             "applicant_account":{"account_id":null,"account_number":null,"applicant_name":"Synthetic A"},
             "minor_creditor_accounts":[]}
            """);
        var summary = mapper.toSummary(projection(values));
        assertThat(summary.getValidatedDate().isPresent()).isTrue();
        assertThat(summary.getValidatedDate().get()).isNull();
        var wire = compatible.readTree(compatible.writeValueAsString(summary));
        assertThat(wire.get("casefile_snapshot")).isEqualTo(compatible.readTree((String) values.get("casefileSnapshot")));
    }

    @ParameterizedTest
    @EnumSource(DraftCasefileStatus.class)
    void mapsEveryLifecycleCodeAndLabel(DraftCasefileStatus status) {
        var values = values();
        values.put("casefileStatus", status.name());
        var summary = mapper.toSummary(projection(values));
        assertThat(summary.getCasefileStatus().getValue()).isEqualTo(status.name());
        assertThat(summary.getCasefileStatusName()).isEqualTo(status.getDisplayName());
    }

    @Test
    void unreadableSnapshotHasSafeErrorWithoutParserCause() {
        var values = values();
        values.put("casefileSnapshot", "\"SYNTHETIC_PRIVATE_VALUE\"");
        assertThatThrownBy(() -> mapper.toSummary(projection(values)))
            .isInstanceOf(IllegalStateException.class)
            .hasMessage("Unable to read stored Draft Casefile data").hasNoCause();
    }

    private static DraftCasefileSummaryProjection projection(Map<String, Object> values) {
        return new SpelAwareProxyProjectionFactory().createProjection(DraftCasefileSummaryProjection.class, values);
    }

    private static Map<String, Object> values() {
        Map<String, Object> values = new HashMap<>();
        values.put("draftCasefileId", 123L);
        values.put("businessUnitId", (short) 44);
        values.put("createdDate", LocalDateTime.parse("2026-10-01T12:00:00.123456"));
        values.put("submittedBy", "BUU-1");
        values.put("submittedByName", "Synthetic Submitter");
        values.put("validatedDate", LocalDateTime.parse("2026-10-02T12:00:00"));
        values.put("casefileSnapshot", SNAPSHOT);
        values.put("casefileType", "REMO In");
        values.put("casefileStatus", "PUBLISHED");
        values.put("casefileStatusDate", LocalDateTime.parse("2026-10-03T12:00:00"));
        return values;
    }
}
