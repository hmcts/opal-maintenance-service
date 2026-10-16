package uk.gov.hmcts.opal.actions;

import io.restassured.response.Response;
import uk.gov.hmcts.opal.steps.BaseStepDef;

public final class DraftCasefileActions extends BaseStepDef {

    public Response create(String token, String requestBody, String failureMode) {
        return postWithBearer("/draft-casefiles", token, requestBody, failureMode);
    }

    public Response inspect(String token, long draftCasefileId) {
        return getWithBearer("/testing-support/draft-casefiles/" + draftCasefileId, token);
    }

    public Response findByMarker(String token, String marker) {
        return getWithBearer("/testing-support/draft-casefiles/markers/" + marker, token);
    }

    public Response delete(String token, long draftCasefileId) {
        return deleteWithBearer("/testing-support/draft-casefiles/" + draftCasefileId, token);
    }
}
