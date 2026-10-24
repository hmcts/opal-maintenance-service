package uk.gov.hmcts.opal.actions;

import io.restassured.response.Response;
import java.util.Map;
import uk.gov.hmcts.opal.steps.BaseStepDef;

public final class DraftCasefileActions extends BaseStepDef {

    public Response replace(String token, long id, String body, String etag) {
        return putWithBearer("/draft-casefiles/" + id, token, body, etag);
    }

    public Response registerPublicationEvidence(String token, long id, String marker) {
        return postWithBearerAndRunReference(
            "/testing-support/draft-casefiles/" + id + "/publication-evidence", token, marker);
    }

    public Response publicationEvidence(String token, long id, String marker) {
        return getWithBearerAndRunReference(
            "/testing-support/draft-casefiles/" + id + "/publication-evidence", token, marker);
    }

    public Response userState(String token) {
        return getWithBearer(userServiceUrl(), "/v2/users/0/state", token);
    }

    public Response list(String token, Map<String, String> filters) {
        return getWithBearer("/draft-casefiles", token, filters);
    }

    public Response get(String token, long id) {
        return getWithBearer("/draft-casefiles/" + id, token);
    }

    public Response decide(String token, long id, String body, String etag) {
        return patchWithBearer("/draft-casefiles/" + id, token, body, etag);
    }

    public Response create(String token, String requestBody) {
        return postWithBearer("/draft-casefiles", token, requestBody);
    }

    public Response delete(String token, long draftCasefileId, String marker) {
        return deleteWithBearer("/testing-support/draft-casefiles/" + draftCasefileId, token, marker);
    }
}
