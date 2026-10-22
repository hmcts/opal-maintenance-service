package uk.gov.hmcts.opal.service.messaging;

import com.fasterxml.jackson.annotation.JsonProperty;

public record DraftCasefileQueueMessage(
    @JsonProperty("draft_casefile_id") Long draftCasefileId,
    @JsonProperty("checker_user_id") Long checkerUserId,
    @JsonProperty("originating_ip_address") String originatingIpAddress,
    @JsonProperty("approval_timestamp") String approvalTimestamp
) { }
