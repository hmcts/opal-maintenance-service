package uk.gov.hmcts.opal.entity;

import lombok.Getter;
import lombok.RequiredArgsConstructor;

@Getter
@RequiredArgsConstructor
public enum DraftCasefileStatus {
    SUBMITTED("Submitted"),
    DELETED("Deleted"),
    REJECTED("Rejected"),
    PUBLISHING_PENDING("Publishing pending"),
    PUBLISHED("Published"),
    PUBLISHING_FAILED("Publishing failed"),
    RESUBMITTED("Resubmitted");

    private final String displayName;
}
