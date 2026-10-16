package uk.gov.hmcts.opal.dto;

import uk.gov.hmcts.opal.generated.model.DraftCasefileAddResponse;

public record DraftCasefileSubmission(DraftCasefileAddResponse response, long version) {
}
