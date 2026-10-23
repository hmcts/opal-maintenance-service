package uk.gov.hmcts.opal.dto;

import uk.gov.hmcts.opal.generated.model.TestingSupportPublicationEvidence;

public record RegisteredPublicationEvidence(TestingSupportPublicationEvidence evidence, boolean created) {
}
