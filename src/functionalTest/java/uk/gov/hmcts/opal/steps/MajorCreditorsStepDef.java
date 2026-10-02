package uk.gov.hmcts.opal.steps;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static uk.gov.hmcts.opal.assertions.ProblemDetailAssertions.assertProblemDetail;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.cucumber.java.en.Given;
import io.cucumber.java.en.Then;
import io.cucumber.java.en.When;
import io.restassured.response.Response;

import java.io.IOException;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

public class MajorCreditorsStepDef extends BaseStepDef {
    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();
    private Response latestResponse;

    @Given("the Major Creditor selection and comparison records are available")
    public void requireSeededComparators() throws IOException {
        Response response = getWithBearer("/major-creditors?business_unit_id=44", BearerTokenStepDef.getToken());
        assertEquals(200, response.statusCode(), "Major Creditor prerequisite request did not succeed");
        assertSeedPrerequisites(response.asString());
    }

    static void assertSeedPrerequisites(String body) throws IOException {
        JsonNode creditors = OBJECT_MAPPER.readTree(body).path("refData");
        assertTrue(creditors.isArray(), "Expected creditor reference data array");
        Set<String> found = new HashSet<>();
        for (JsonNode creditor : creditors) {
            String code = creditor.path("major_creditor_code").asText();
            if (Set.of("T901", "T902", "T903").contains(code)) {
                assertTrue(found.add(code), "Duplicate seed comparator");
                assertEquals(44, creditor.path("business_unit_id").intValue());
                assertTrue(creditor.path("active").isBoolean());
                assertTrue(creditor.path("central_authority").isBoolean());
                assertEquals(!"T902".equals(code), creditor.path("active").booleanValue());
                assertEquals("T903".equals(code), creditor.path("central_authority").booleanValue());
            }
        }
        assertEquals(Set.of("T901", "T902", "T903"), found,
            "Missing selection/comparison seed; apply approved DEV V1_15 before this scenario");
    }

    @When("I request active non-Central Authority Major Creditors")
    public void requestActiveMajorCreditors() {
        latestResponse = getWithBearer(
            "/major-creditors?business_unit_id=44&active=true&central_authority=false",
            BearerTokenStepDef.getToken()
        );
    }

    @Then("the Major Creditors required for creditor selection are returned")
    public void assertActiveMajorCreditors() throws IOException {
        Response response = latestResponse();
        assertEquals(200, response.statusCode(), "Major Creditor request did not succeed");
        assertTrue(response.contentType() != null && response.contentType().startsWith("application/json"),
            "Expected application/json but received " + response.contentType());
        assertActiveResponse(response.asString());
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

    static void assertActiveResponse(String body) throws IOException {
        JsonNode root = OBJECT_MAPPER.readTree(body);
        JsonNode count = root.path("count");
        JsonNode creditors = root.path("refData");
        assertTrue(count.isIntegralNumber() && count.canConvertToInt(), "Invalid creditor count");
        assertTrue(creditors.isArray(), "Expected creditor reference data array");
        assertEquals(count.intValue(), creditors.size(), "Creditor count must match reference data");
        assertFalse(creditors.isEmpty(), "DEV Major Creditor seed is missing; apply V1_15 before this scenario");
        Set<Long> ids = new HashSet<>();
        Set<String> codes = new HashSet<>();
        for (JsonNode creditor : creditors) {
            assertPositiveIdentifier(creditor, "major_creditor_id");
            assertTrue(ids.add(creditor.path("major_creditor_id").longValue()), "Duplicate creditor identifier");
            JsonNode unit = creditor.path("business_unit_id");
            assertTrue(unit.isIntegralNumber() && unit.canConvertToInt(), "Invalid business unit identifier");
            assertEquals(44, unit.intValue(), "Creditor belongs to a different business unit");
            assertTrue(creditor.path("active").isBoolean() && creditor.path("active").booleanValue(),
                "Creditor must be active");
            assertTrue(creditor.path("central_authority").isBoolean()
                && !creditor.path("central_authority").booleanValue(), "Creditor must not be a Central Authority");
            for (String field : List.of("major_creditor_code", "name", "address_line_1")) {
                JsonNode value = creditor.path(field);
                assertTrue(value.isTextual() && !value.textValue().isBlank(), "Expected textual creditor " + field);
            }
            String code = creditor.path("major_creditor_code").textValue();
            assertTrue(codes.add(code), "Duplicate creditor code");
            assertFalse("T902".equals(code) || "T903".equals(code), "Seeded comparison creditor must be excluded");
            if ("T901".equals(code)) {
                assertSeedDetails(creditor);
            }
        }
        assertTrue(codes.contains("T901"), "DEV Major Creditor T901 is missing; apply V1_15 before this scenario");
    }

    private static void assertSeedDetails(JsonNode creditor) {
        assertText(creditor, "name", "Functional Test Major Creditor");
        assertText(creditor, "address_line_1", "1 Synthetic Test Street");
        assertText(creditor, "address_line_2", "Synthetic Test Town");
        assertText(creditor, "address_line_3", "Synthetic Test District");
        assertText(creditor, "address_line_4", "Synthetic Test Region");
        assertText(creditor, "address_line_5", "Synthetic Test Province");
        assertText(creditor, "postcode", "ZZ1 1ZZ");
        assertText(creditor, "contact_name", "Synthetic Test Contact");
        assertText(creditor, "contact_email", "creditor@example.invalid");
        assertText(creditor, "country_name", "Czech Republic");
        assertPositiveIdentifier(creditor, "country_id");
    }

    private static void assertPositiveIdentifier(JsonNode creditor, String field) {
        JsonNode value = creditor.path(field);
        assertTrue(value.isIntegralNumber() && value.canConvertToLong() && value.longValue() > 0,
            "Expected positive creditor " + field);
    }

    private static void assertText(JsonNode creditor, String field, String expected) {
        JsonNode value = creditor.path(field);
        assertTrue(value.isTextual(), "Expected textual creditor " + field);
        assertEquals(expected, value.textValue(), "Unexpected creditor " + field);
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
