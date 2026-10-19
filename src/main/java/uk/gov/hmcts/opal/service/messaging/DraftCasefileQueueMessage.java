package uk.gov.hmcts.opal.service.messaging;

import com.fasterxml.jackson.annotation.JsonProperty;

public record DraftCasefileQueueMessage(@JsonProperty("draft_casefile_id") Long draftCasefileId) {
}
