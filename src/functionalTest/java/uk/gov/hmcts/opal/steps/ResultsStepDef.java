package uk.gov.hmcts.opal.steps;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static uk.gov.hmcts.opal.assertions.ProblemDetailAssertions.assertProblemDetail;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.cucumber.datatable.DataTable;
import io.cucumber.java.en.Given;
import io.cucumber.java.en.Then;
import io.cucumber.java.en.When;
import io.restassured.response.Response;
import java.io.IOException;
import java.math.BigDecimal;
import java.net.URI;
import java.net.URISyntaxException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class ResultsStepDef extends BaseStepDef {

    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();
    private static final String MATCHING_TARGET = "TEST_URL";
    static final String ACTIVE_REQUEST_PATH = "/results?order_term=true&active=true";
    static final String INACTIVE_REQUEST_PATH = "/results?order_term=true&active=false";
    static final String MALFORMED_REQUEST_PATH = "/results?order_term=not-a-boolean&active=true";

    private Response latestResponse;
    private String selectedId;

    @Given("I have selected the Result with identifier {string}")
    public void selectResult(String resultId) {
        assertTrue("MLUMP".equals(resultId) || "ZZZZZZ".equals(resultId),
            "Use the seeded or documented absent Result identifier");
        selectedId = resultId;
    }

    @When("I request the selected Result details")
    public void requestSelectedResult() {
        latestResponse = getWithBearer(resultsTarget(), resultPath(), BearerTokenStepDef.getToken());
    }

    @When("I request the selected Result details without authentication")
    public void requestSelectedResultWithoutAuthentication() {
        latestResponse = getWithoutBearer(resultsTarget(), resultPath());
    }

    @Then("the selected Result identity and parameter metadata are returned")
    public void resultDetailsAreReturned() throws IOException {
        assertSelectedResultResponse(latestResponse(), "MLUMP", "Lump sum order");
    }

    @Then("the metadata describes the expected amount input")
    public void amountMetadataIsAvailable() throws IOException {
        assertAmountMetadata(latestResponse());
    }

    @Then("a correlated Result not-found response is returned without Result data")
    public void missingResultIsCorrelated() throws IOException {
        assertMissingResultResponse(latestResponse());
    }

    @Then("Result details require authentication without exposing Result data")
    public void resultAuthenticationIsRequired() throws IOException {
        assertUnauthorizedResultResponse(latestResponse());
    }

    @When("I request active Results available as Order Terms")
    public void requestActiveResults() {
        latestResponse = getWithBearer(resultsTarget(), ACTIVE_REQUEST_PATH, BearerTokenStepDef.getToken());
    }

    @When("I request inactive Results available as Order Terms")
    public void requestEmptyResults() {
        latestResponse = getWithBearer(resultsTarget(), INACTIVE_REQUEST_PATH, BearerTokenStepDef.getToken());
    }

    @When("I request Order Term Results with a malformed order_term filter")
    public void requestMalformedResults() {
        latestResponse = getWithBearer(resultsTarget(), MALFORMED_REQUEST_PATH, BearerTokenStepDef.getToken());
    }

    @When("I request active Order Term Results without authentication")
    public void requestUnauthenticatedResults() {
        latestResponse = getWithoutBearer(resultsTarget(), ACTIVE_REQUEST_PATH);
    }

    protected String environmentSetting(String setting) {
        return System.getenv(setting);
    }

    String resultsTarget() {
        String configuredTarget = environmentSetting(MATCHING_TARGET);
        return validatedTarget(MATCHING_TARGET,
            configuredTarget == null ? "http://localhost:4551" : configuredTarget);
    }

    static String validatedTarget(String setting, String value) {
        if (value == null || value.isBlank()) {
            throw new IllegalStateException(setting);
        }
        try {
            URI uri = new URI(value);
            if (!("http".equalsIgnoreCase(uri.getScheme()) || "https".equalsIgnoreCase(uri.getScheme()))
                || uri.getHost() == null || uri.getRawUserInfo() != null || uri.getRawQuery() != null
                || uri.getRawFragment() != null || uri.getPort() > 65535 || uri.getPort() == 0) {
                throw new IllegalStateException(setting);
            }
        } catch (URISyntaxException exception) {
            throw new IllegalStateException(setting);
        }
        return value.endsWith("/") ? value.substring(0, value.length() - 1) : value;
    }

    @Then("the returned Order Term Results are")
    public void assertReturnedResults(DataTable expected) throws IOException {
        Response response = latestResponse();
        assertSuccessfulJson(response);
        assertExpectedResults(response.asString(), expected);
    }

    @Then("an empty Order Term Results response is returned")
    public void assertReturnedResultsEmpty() throws IOException {
        Response response = latestResponse();
        assertSuccessfulJson(response);
        assertEmptyResults(response.asString());
    }

    @Then("the Order Term Results validation Problem Details response is returned")
    public void assertValidationProblemDetails() throws IOException {
        Response response = latestResponse();
        assertProblemDetail(response, 400, "https://hmcts.gov.uk/problems/type-mismatch", "Bad Request",
                            "Parameter 'order_term' must be of type Boolean", "instance", "operation_id");
        JsonNode problem = OBJECT_MAPPER.readTree(response.asString());
        assertFalse(problem.has("reason"));
        assertFalse(response.asString().contains("not-a-boolean"));
        assertFalse(problem.has("refData"));
        assertFalse(problem.has("stackTrace"));
        assertFalse(problem.has("stack_trace"));
    }

    @Then("the Order Term Results unauthorized Problem Details response is returned")
    public void assertUnauthorizedProblemDetails() throws IOException {
        Response response = latestResponse();
        assertProblemDetail(response, 401, "https://hmcts.gov.uk/problems/unauthorized", "Unauthorized",
                            "You are not authorized to access this resource", "instance", "operation_id");
        JsonNode problem = OBJECT_MAPPER.readTree(response.asString());
        assertFalse(problem.has("count"));
        assertFalse(problem.has("refData"));
        assertFalse(problem.has("stackTrace"));
        assertFalse(problem.has("stack_trace"));
    }

    private static void assertSuccessfulJson(Response response) {
        assertEquals(200, response.statusCode());
        assertTrue(response.contentType() != null && response.contentType().startsWith("application/json"));
    }

    static void assertExpectedResults(String body, DataTable expectedTable) throws IOException {
        JsonNode root = OBJECT_MAPPER.readTree(body);
        JsonNode count = root.path("count");
        JsonNode data = root.path("refData");
        assertTrue(count.isIntegralNumber() && count.canConvertToInt());
        assertTrue(data.isArray());
        assertEquals(data.size(), count.intValue());

        Map<String, String> actual = new HashMap<>();
        for (JsonNode item : data) {
            assertTrue(item.path("result_id").isTextual());
            assertTrue(item.path("result_title").isTextual());
            String id = item.path("result_id").asText();
            String title = item.path("result_title").asText();
            assertFalse(id.isBlank());
            assertFalse(title.isBlank());
            assertFalse(actual.containsKey(id), "Duplicate Result identifier");
            actual.put(id, title);
        }

        List<Map<String, String>> rows = expectedTable.asMaps(String.class, String.class);
        Map<String, String> expected = new HashMap<>();
        for (Map<String, String> row : rows) {
            assertFalse(expected.containsKey(row.get("result_id")), "Duplicate expected Result identifier");
            expected.put(row.get("result_id"), row.get("result_title"));
        }
        assertFalse(expected.isEmpty());
        assertEquals(expected, actual, "Results must match the seeded Order Term definitions");
        for (int index = 0; index < rows.size(); index++) {
            assertEquals(rows.get(index).get("result_id"), data.get(index).path("result_id").textValue(),
                "Result display order differs from the seeded definitions");
        }
    }

    static void assertEmptyResults(String body) throws IOException {
        JsonNode root = OBJECT_MAPPER.readTree(body);
        assertTrue(root.path("count").isIntegralNumber() && root.path("count").canConvertToInt());
        assertEquals(0, root.path("count").intValue());
        assertTrue(root.path("refData").isArray());
        assertTrue(root.path("refData").isEmpty());
    }

    Response latestResponse() {
        if (latestResponse == null) {
            throw new IllegalStateException("No Results response is available");
        }
        return latestResponse;
    }

    void latestResponse(Response response) {
        latestResponse = response;
    }

    static void assertSelectedResultResponse(Response response, String id, String title) throws IOException {
        assertEquals(200, response.statusCode(), "Result detail request did not succeed");
        assertTrue(response.contentType() != null && response.contentType().startsWith("application/json"));
        JsonNode body = OBJECT_MAPPER.readTree(response.asString());
        assertTrue(body.isObject(), "Expected one Result object");
        assertTrue(body.path("result_id").isTextual());
        assertEquals(id, body.path("result_id").textValue());
        assertTrue(body.path("result_title").isTextual());
        assertEquals(title, body.path("result_title").textValue());
        assertTrue(body.path("result_parameters").isTextual(), "Expected JSON-encoded parameter metadata");
        JsonNode parameters = OBJECT_MAPPER.readTree(body.path("result_parameters").textValue());
        assertTrue(parameters != null && parameters.isArray() && !parameters.isEmpty());
        for (JsonNode parameter : parameters) {
            assertTrue(parameter.isObject(), "Expected parameter objects");
        }
    }

    static void assertAmountMetadata(Response response) throws IOException {
        JsonNode outer = OBJECT_MAPPER.readTree(response.asString());
        assertTrue(outer.path("result_parameters").isTextual(), "Expected encoded metadata");
        JsonNode parameters = OBJECT_MAPPER.readTree(outer.path("result_parameters").textValue());
        assertTrue(parameters != null && parameters.isArray(), "Expected parameter array");
        List<JsonNode> amounts = new ArrayList<>();
        for (JsonNode parameter : parameters) {
            if ("Amount".equals(parameter.path("name").textValue())) {
                amounts.add(parameter);
            }
        }
        assertEquals(1, amounts.size(), "Expected one configured Amount parameter");
        JsonNode amount = amounts.get(0);
        assertEquals("Amount of order", amount.path("prompt").textValue());
        assertEquals("decimal-2dp", amount.path("type").textValue());
        assertTrue(amount.path("mandatory").isBoolean() && amount.path("mandatory").booleanValue());
        assertTrue(amount.path("min").isNumber());
        assertEquals(0, amount.path("min").decimalValue().compareTo(BigDecimal.ZERO));
        assertTrue(amount.path("max").isNumber());
        assertEquals(0, amount.path("max").decimalValue().compareTo(new BigDecimal("9999999999.99")));
    }

    static void assertMissingResultResponse(Response response) throws IOException {
        assertProblemDetail(response, 404, "https://hmcts.gov.uk/problems/entity-not-found",
            "Entity Not Found", "The requested entity could not be found", "instance", "operation_id");
        JsonNode problem = assertNoResultData(response);
        assertEquals("Result not found", problem.path("reason").textValue());
    }

    static void assertUnauthorizedResultResponse(Response response) throws IOException {
        assertProblemDetail(response, 401, "https://hmcts.gov.uk/problems/unauthorized",
            "Unauthorized", "You are not authorized to access this resource", "instance", "operation_id");
        assertNoResultData(response);
    }

    private static JsonNode assertNoResultData(Response response) throws IOException {
        JsonNode problem = OBJECT_MAPPER.readTree(response.asString());
        for (String field : new String[] {"result_id", "result_title", "result_parameters", "refData"}) {
            assertFalse(problem.has(field), "Problem response exposes Result data: " + field);
        }
        assertFalse(problem.has("stackTrace"), "Problem response exposes a stack trace");
        assertFalse(problem.has("exception"), "Problem response exposes an exception");
        return problem;
    }

    private String resultPath() {
        assertNotNull(selectedId, "Select a Result before requesting its details");
        return "/results/" + selectedId;
    }

}
