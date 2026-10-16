package uk.gov.hmcts.opal.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.List;

public record TestingSupportDraftCasefileMatches(
    @JsonProperty("count") int count,
    @JsonProperty("draft_casefile_ids") List<Long> draftCasefileIds
) {
    public TestingSupportDraftCasefileMatches {
        draftCasefileIds = List.copyOf(draftCasefileIds);
    }
}
