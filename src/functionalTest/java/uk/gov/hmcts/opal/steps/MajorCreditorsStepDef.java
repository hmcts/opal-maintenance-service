package uk.gov.hmcts.opal.steps;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static uk.gov.hmcts.opal.assertions.ProblemDetailAssertions.assertProblemDetail;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.cucumber.java.en.Then;
import io.cucumber.java.en.When;
import io.restassured.response.Response;

import java.io.IOException;
import java.util.List;

public class MajorCreditorsStepDef extends BaseStepDef {
    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();
    private Response latestResponse;

    @When("I request active non-Central Authority Major Creditors")
    public void requestActiveMajorCreditors() {
        latestResponse = getWithBearer(
            "/major-creditors?business_unit_id=44&active=true&central_authority=false",
            BearerTokenStepDef.getToken()
        );
    }

    @Then("no non-Central Authority Major Creditors are returned for the seeded business unit")
    public void assertEmptyMajorCreditors() throws IOException {
        Response response = latestResponse();
        assertEquals(200, response.statusCode(), "Major Creditor request did not succeed");
        assertTrue(response.contentType() != null && response.contentType().startsWith("application/json"),
            "Expected application/json but received " + response.contentType());
        assertEmptyResponse(response.asString());
    }

    @When("I request Major Creditors with a malformed active filter")
    public void requestMalformedFilter() {
        latestResponse = getWithBearer(
            "/major-creditors?business_unit_id=44&active=not-a-boolean&central_authority=false",
            BearerTokenStepDef.getToken()
        );
    }

    @Then("the Major Creditor validation response is correlated")
    public void assertValidationResponse() throws IOException {
        Response response = latestResponse();
        assertProblemDetail(response, 400,
            "https://hmcts.gov.uk/problems/type-mismatch", "Bad Request",
            "Parameter 'active' must be of type Boolean", "instance", "operation_id");
        JsonNode problem = assertNoReferenceData(response);
        assertFalse(problem.has("reason"), "Validation response must not expose a reason");
        assertFalse(response.asString().contains("not-a-boolean"), "Validation response exposes the rejected value");
    }

    @When("I request Major Creditors without authentication")
    public void requestWithoutAuthentication() {
        latestResponse = getWithoutBearer(
            "/major-creditors?business_unit_id=44&active=true&central_authority=false"
        );
    }

    @Then("Major Creditor reference data is not disclosed")
    public void assertUnauthorizedResponse() throws IOException {
        Response response = latestResponse();
        assertProblemDetail(response, 401,
            "https://hmcts.gov.uk/problems/unauthorized", "Unauthorized",
            "You are not authorized to access this resource", "instance", "operation_id");
        assertNoReferenceData(response);
    }

    static void assertEmptyResponse(String body) throws IOException {
        JsonNode root = OBJECT_MAPPER.readTree(body);
        JsonNode count = root.path("count");
        JsonNode refData = root.path("refData");
        assertTrue(count.isIntegralNumber() && count.canConvertToInt(), "Invalid creditor count");
        assertTrue(refData.isArray(), "Expected creditor reference data array");
        assertEquals(0, count.intValue(), "Expected no seeded non-Central Authority creditors");
        assertEquals(0, refData.size(), "Expected an empty creditor reference data array");
    }

    private static JsonNode assertNoReferenceData(Response response) throws IOException {
        JsonNode problem = OBJECT_MAPPER.readTree(response.asString());
        for (String field : List.of("count", "refData", "stackTrace")) {
            assertFalse(problem.has(field), "Problem response must not expose " + field);
        }
        return problem;
    }

    Response latestResponse() {
        if (latestResponse == null) {
            throw new IllegalStateException("No Major Creditor response is available; run the request When first");
        }
        return latestResponse;
    }

    void latestResponse(Response response) {
        latestResponse = response;
    }
}
