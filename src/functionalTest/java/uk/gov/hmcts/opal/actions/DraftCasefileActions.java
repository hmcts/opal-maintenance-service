package uk.gov.hmcts.opal.actions;

import io.restassured.response.Response;
import java.util.Map;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import uk.gov.hmcts.opal.steps.BaseStepDef;

public final class DraftCasefileActions extends BaseStepDef {

    public Response replace(String token, long id, String body, String etag) {
        return authenticatedRequestWithoutReporting(token).header(HttpHeaders.IF_MATCH, etag).body(body)
            .when().put(testServiceUrl() + "/draft-casefiles/" + id);
    }



    public Response userState(String token) {
        return authenticatedRequestWithoutReporting(token).when().get(userServiceUrl() + "/v2/users/0/state");
    }

    public Response list(String token, Map<String, String> filters) {
        return authenticatedRequestWithoutReporting(token).queryParams(filters).when()
            .get(testServiceUrl() + "/draft-casefiles");
    }

    public Response get(String token, long id) {
        return authenticatedRequestWithoutReporting(token).when().get(testServiceUrl() + "/draft-casefiles/" + id);
    }

    public Response decide(String token, long id, String body, String etag) {
        return authenticatedRequestWithoutReporting(token).header(HttpHeaders.IF_MATCH, etag).body(body)
            .when().patch(testServiceUrl() + "/draft-casefiles/" + id);
    }

    public Response create(String token, String requestBody) {
        return authenticatedRequestWithoutReporting(token).body(requestBody).when()
            .post(testServiceUrl() + "/draft-casefiles");
    }

    public Response delete(String token, long draftCasefileId, String marker) {
        return authenticatedRequestWithoutReporting(token).accept(MediaType.APPLICATION_PROBLEM_JSON_VALUE)
            .header("Test-Run-Reference", marker).when()
            .delete(testServiceUrl() + "/testing-support/draft-casefiles/" + draftCasefileId);
    }
}
