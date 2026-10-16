package uk.gov.hmcts.opal.mapper;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;

import java.time.LocalDateTime;
import java.time.ZoneOffset;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class TestingSupportDraftCasefileMapperTest {

    private final ObjectMapper json = new ObjectMapper().findAndRegisterModules();
    private final TestingSupportDraftCasefileMapper mapper = new TestingSupportDraftCasefileMapper(json);

    @Test
    void mapsOnlyTechnicalMetadataOnTheWire() throws Exception {
        DraftCasefileEntity entity = entity();
        var metadata = mapper.toMetadata(entity);
        JsonNode wire = json.valueToTree(metadata);

        assertThat(wire.properties().stream().map(java.util.Map.Entry::getKey)).containsExactlyInAnyOrder(
            "draft_casefile_id", "business_unit_id", "submitted_by", "created_date", "casefile_status",
            "casefile_status_date", "version_number", "snapshot_present", "timeline_entry_count",
            "timeline_statuses");
        assertThat(wire.get("submitted_by").asText()).isEqualTo("L044JG");
        assertThat(metadata.createdDate()).isEqualTo(entity.getCreatedDate().atOffset(ZoneOffset.UTC));
        assertThat(metadata.casefileStatusDate()).isEqualTo(entity.getCasefileStatusDate().atOffset(ZoneOffset.UTC));
        assertThat(metadata.snapshotPresent()).isTrue();
        assertThat(metadata.timelineEntryCount()).isEqualTo(2);
        assertThat(metadata.timelineStatuses()).containsExactly("Submitted", "Validated");
        assertThat(wire.toString()).doesNotContain("Synthetic Name", "private-content", "account_comment");
    }

    @Test
    void readsMarkerSeparatelyAndTreatsMissingMarkerAsNull() {
        assertThat(mapper.marker(entity())).isEqualTo("PO10287-550e8400-e29b-41d4-a716-446655440000");
        assertThat(mapper.marker(entity().toBuilder().casefile("{}").build())).isNull();
    }

    @Test
    void wrapsMalformedPersistedJsonWithoutPayload() {
        assertThatThrownBy(() -> mapper.toMetadata(entity().toBuilder().timelineData("private-content{").build()))
            .isInstanceOf(IllegalStateException.class)
            .hasMessageContaining("123")
            .hasMessageNotContaining("private-content");
    }

    private static DraftCasefileEntity entity() {
        LocalDateTime created = LocalDateTime.of(2026, 10, 16, 10, 11);
        return DraftCasefileEntity.builder()
            .draftCasefileId(123L).businessUnitId((short) 44).submittedBy("L044JG")
            .submittedByName("Synthetic Name").createdDate(created).casefileStatus(DraftCasefileStatus.SUBMITTED)
            .casefileStatusDate(created).versionNumber(0L)
            .casefile("{\"respondent_account\":{\"account_comment\":\"PO10287-550e8400-e29b-41d4-a716-446655440000\"}}")
            .casefileSnapshot("{\"name\":\"private-content\"}")
            .timelineData("[{\"status\":\"Submitted\",\"name\":\"Synthetic Name\"},{\"status\":\"Validated\"}]")
            .build();
    }
}
