package uk.gov.hmcts.opal.repository;

import uk.gov.hmcts.opal.entity.DraftCasefileStatus;

import java.time.LocalDateTime;

public interface DraftCasefileSummaryProjection {
    Long getDraftCasefileId();

    Short getBusinessUnitId();

    LocalDateTime getCreatedDate();

    String getSubmittedBy();

    String getSubmittedByName();

    LocalDateTime getValidatedDate();

    String getCasefileSnapshot();

    String getCasefileType();

    DraftCasefileStatus getCasefileStatus();

    LocalDateTime getCasefileStatusDate();
}
