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
import java.util.HashSet;
import java.util.Set;

public class MaintenanceApplicationsStepDef extends BaseStepDef {

    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();
    private static final String CREATE_CASEFILE_GROUP = "Create Casefile";
    private static final String REPRESENTATIVE_CODE = "AP00001";
    private static final String REPRESENTATIVE_TITLE = "Application to Appeal";
    static final String ACTIVE_REQUEST_PATH =
        "/maintenance-applications?application_group=Create Casefile&active=true";
    static final String INACTIVE_REQUEST_PATH =
        "/maintenance-applications?application_group=Create Casefile&active=false";
    static final String MALFORMED_REQUEST_PATH =
        "/maintenance-applications?application_group=Create Casefile&active=not-a-boolean";

    private Response latestResponse;

    @When("I request active Maintenance Applications for Create Casefile")
    public void requestActiveMaintenanceApplications() {
        latestResponse = getWithBearer(
            ACTIVE_REQUEST_PATH,
            BearerTokenStepDef.getToken()
        );
    }

    @Then("active Maintenance Applications are returned for Order Details")
    public void assertActiveMaintenanceApplications() throws IOException {
        Response response = latestResponse();
        assertSuccessfulJson(response);
        assertActiveMaintenanceApplicationsResponse(response.asString());
    }

    @When("I request inactive Maintenance Applications for Create Casefile")
    public void requestInactiveMaintenanceApplications() {
        latestResponse = getWithBearer(
            INACTIVE_REQUEST_PATH,
            BearerTokenStepDef.getToken()
        );
    }

    @Then("an empty Maintenance Applications response is returned")
    public void assertEmptyMaintenanceApplications() throws IOException {
        Response response = latestResponse();
        assertSuccessfulJson(response);
        assertEmptyMaintenanceApplicationsResponse(response.asString());
    }

    @When("I request Maintenance Applications with a malformed active filter")
    public void requestMaintenanceApplicationsWithMalformedActiveFilter() {
        latestResponse = getWithBearer(
            MALFORMED_REQUEST_PATH,
            BearerTokenStepDef.getToken()
        );
    }

    @Then("the Maintenance Applications validation Problem Details response is returned")
    public void assertMaintenanceApplicationValidationProblemDetails() throws IOException {
        Response response = latestResponse();
        assertProblemDetail(
            response,
            400,
            "https://hmcts.gov.uk/problems/type-mismatch",
            "Bad Request",
            "Parameter 'active' must be of type Boolean",
            "instance",
            "operation_id"
        );

        JsonNode problem = OBJECT_MAPPER.readTree(response.asString());
        assertFalse(problem.has("reason"), "Validation response must not expose the rejected value");
        assertFalse(response.asString().contains("not-a-boolean"), "Validation response echoed the rejected value");
    }

    @When("I request Maintenance Applications without authentication")
    public void requestMaintenanceApplicationsWithoutAuthentication() {
        latestResponse = getWithoutBearer(
            ACTIVE_REQUEST_PATH
        );
    }

    @Then("the Maintenance Applications unauthorized Problem Details response is returned")
    public void assertMaintenanceApplicationUnauthorizedProblemDetails() throws IOException {
        Response response = latestResponse();
        assertProblemDetail(
            response,
            401,
            "https://hmcts.gov.uk/problems/unauthorized",
            "Unauthorized",
            "You are not authorized to access this resource",
            "instance",
            "operation_id"
        );

        JsonNode problem = OBJECT_MAPPER.readTree(response.asString());
        assertFalse(problem.has("count"), "Unauthorized response must not expose an application count");
        assertFalse(problem.has("refData"), "Unauthorized response must not expose application reference data");
    }

    static void assertActiveMaintenanceApplicationsResponse(String responseBody) throws IOException {
        JsonNode root = OBJECT_MAPPER.readTree(responseBody);
        JsonNode count = root.path("count");
        JsonNode refData = root.path("refData");
        assertValidCountAndArray(count, refData);
        assertTrue(refData.size() > 0, "Expected active Create Casefile Maintenance Applications");

        Set<Long> applicationIds = new HashSet<>();
        Set<String> applicationCodes = new HashSet<>();
        boolean representativeFound = false;

        for (JsonNode item : refData) {
            JsonNode applicationId = item.path("application_id");
            assertTrue(
                applicationId.isIntegralNumber() && applicationId.canConvertToLong()
                    && applicationId.longValue() > 0,
                "Maintenance Application identifier is missing or invalid"
            );
            assertTrue(
                applicationIds.add(applicationId.longValue()),
                "Duplicate Maintenance Application identifier: " + applicationId.longValue()
            );

            String code = requiredText(item, "application_code");
            final String title = requiredText(item, "application_title");
            assertTrue(applicationCodes.add(code), "Duplicate Maintenance Application code: " + code);
            assertEquals(CREATE_CASEFILE_GROUP, requiredText(item, "application_group"));
            assertTrue(item.path("active").isBoolean(), "Maintenance Application active state is invalid");
            assertTrue(item.path("active").asBoolean(), "Inactive Maintenance Application was returned");

            if (REPRESENTATIVE_CODE.equals(code) && REPRESENTATIVE_TITLE.equals(title)) {
                representativeFound = true;
            }
        }

        assertTrue(representativeFound, "Representative approved Maintenance Application is missing");
    }

    static void assertEmptyMaintenanceApplicationsResponse(String responseBody) throws IOException {
        JsonNode root = OBJECT_MAPPER.readTree(responseBody);
        JsonNode count = root.path("count");
        JsonNode refData = root.path("refData");
        assertValidCountAndArray(count, refData);
        assertEquals(0, count.intValue(), "Expected zero inactive Create Casefile applications");
        assertTrue(refData.isEmpty(), "Expected an empty Maintenance Applications array");
    }

    private static void assertSuccessfulJson(Response response) {
        assertEquals(200, response.statusCode(), "Maintenance Applications request did not succeed");
        assertTrue(
            response.contentType() != null && response.contentType().startsWith("application/json"),
            "Expected application/json but received " + response.contentType()
        );
    }

    private static void assertValidCountAndArray(JsonNode count, JsonNode refData) {
        assertTrue(
            count.isIntegralNumber() && count.canConvertToInt() && count.intValue() >= 0,
            "Maintenance Applications response count is missing or invalid"
        );
        assertTrue(refData.isArray(), "Maintenance Applications response refData is missing or invalid");
        assertEquals(count.intValue(), refData.size(), "Response count does not match refData size");
    }

    private static String requiredText(JsonNode item, String fieldName) {
        JsonNode field = item.path(fieldName);
        assertTrue(field.isTextual() && !field.asText().isBlank(), fieldName + " is missing or blank");
        return field.asText();
    }

    private Response required(Response response) {
        if (response == null) {
            throw new IllegalStateException("No latest Maintenance Applications response is available");
        }
        return response;
    }

    Response latestResponse() {
        return required(latestResponse);
    }

    void latestResponse(Response response) {
        latestResponse = response;
    }
}
