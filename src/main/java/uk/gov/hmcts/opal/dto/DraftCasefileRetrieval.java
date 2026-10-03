package uk.gov.hmcts.opal.dto;

import uk.gov.hmcts.opal.generated.model.DraftCasefileGetResponse;

public record DraftCasefileRetrieval(DraftCasefileGetResponse response, long version) { }
