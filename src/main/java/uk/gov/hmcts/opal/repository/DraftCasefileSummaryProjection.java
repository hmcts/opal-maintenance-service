package uk.gov.hmcts.opal.repository;

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

    String getCasefileStatus();

    LocalDateTime getCasefileStatusDate();
}
