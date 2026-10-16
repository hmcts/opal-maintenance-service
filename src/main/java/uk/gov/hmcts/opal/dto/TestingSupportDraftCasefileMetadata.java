package uk.gov.hmcts.opal.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;

import java.time.OffsetDateTime;
import java.util.List;

public record TestingSupportDraftCasefileMetadata(
    @JsonProperty("draft_casefile_id") Long draftCasefileId,
    @JsonProperty("business_unit_id") Short businessUnitId,
    @JsonProperty("submitted_by") String submittedBy,
    @JsonProperty("created_date") OffsetDateTime createdDate,
    @JsonProperty("casefile_status") DraftCasefileStatus casefileStatus,
    @JsonProperty("casefile_status_date") OffsetDateTime casefileStatusDate,
    @JsonProperty("version_number") Long versionNumber,
    @JsonProperty("snapshot_present") boolean snapshotPresent,
    @JsonProperty("timeline_entry_count") int timelineEntryCount,
    @JsonProperty("timeline_statuses") List<String> timelineStatuses
) {
    public TestingSupportDraftCasefileMetadata {
        timelineStatuses = List.copyOf(timelineStatuses);
    }
}
