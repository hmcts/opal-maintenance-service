package uk.gov.hmcts.opal.dto;

import uk.gov.hmcts.opal.entity.DraftCasefileStatus;

import java.time.LocalDateTime;
import java.util.List;

public record DraftCasefileFilter(Short businessUnitId, String submittedBy, String notSubmittedBy,
                                 List<DraftCasefileStatus> statuses, LocalDateTime fromInclusive,
                                 LocalDateTime toExclusive) {
    public DraftCasefileFilter {
        statuses = List.copyOf(statuses);
    }
}
