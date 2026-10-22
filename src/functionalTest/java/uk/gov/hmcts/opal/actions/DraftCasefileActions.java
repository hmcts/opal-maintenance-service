package uk.gov.hmcts.opal.actions;

import io.restassured.response.Response;
import uk.gov.hmcts.opal.steps.BaseStepDef;

public final class DraftCasefileActions extends BaseStepDef {

    public Response create(String token, String requestBody) {
        return postWithBearer("/draft-casefiles", token, requestBody);
    }

    public Response delete(String token, long draftCasefileId, String marker) {
        return deleteWithBearer("/testing-support/draft-casefiles/" + draftCasefileId, token, marker);
    }
}
