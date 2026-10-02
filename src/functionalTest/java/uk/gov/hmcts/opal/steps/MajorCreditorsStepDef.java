package uk.gov.hmcts.opal.steps;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static uk.gov.hmcts.opal.assertions.ProblemDetailAssertions.assertProblemDetail;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.cucumber.java.After;
import io.cucumber.java.en.Given;
import io.cucumber.java.en.Then;
import io.cucumber.java.en.When;
import io.restassured.response.Response;
import uk.gov.hmcts.opal.fixtures.MajorCreditorsFixture;
import uk.gov.hmcts.opal.fixtures.MajorCreditorsFixture.ExpectedCreditor;

import java.io.IOException;
import java.sql.SQLException;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;

public class MajorCreditorsStepDef extends BaseStepDef {
    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();
    private MajorCreditorsFixture fixture;
    private Response latestResponse;

    @Given("isolated Major Creditor reference data is available")
    public void prepareMajorCreditors() throws SQLException {
        fixture = MajorCreditorsFixture.create(System.getenv());
    }

    @When("I request active non-Central Authority Major Creditors")
    public void requestActiveMajorCreditors() {
        latestResponse = getWithBearer(
            "/major-creditors?business_unit_id=" + requiredFixture().businessUnitId()
                + "&active=true&central_authority=false",
            BearerTokenStepDef.getToken()
        );
    }

    @Then("the Major Creditors required for creditor selection are returned")
    public void assertActiveMajorCreditors() throws IOException {
        Response response = latestResponse();
        assertEquals(200, response.statusCode(), "Major Creditor request did not succeed");
        assertTrue(response.contentType() != null && response.contentType().startsWith("application/json"),
            "Expected application/json but received " + response.contentType());
        assertActiveResponse(response.asString(), requiredFixture().expectedCreditors());
    }

    @When("I request Major Creditors with a malformed active filter")
    public void requestMalformedFilter() {
        latestResponse = getWithBearer(
            "/major-creditors?business_unit_id=31010&active=not-a-boolean&central_authority=false",
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
            "/major-creditors?business_unit_id=31010&active=true&central_authority=false"
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

    @After("@PO10297Active")
    public void removeOwnedMajorCreditors() throws SQLException {
        if (fixture != null) {
            fixture.close();
            fixture = null;
        }
    }

    static void assertActiveResponse(String body, List<ExpectedCreditor> expected) throws IOException {
        JsonNode root = OBJECT_MAPPER.readTree(body);
        JsonNode count = root.path("count");
        assertTrue(count.isIntegralNumber() && count.canConvertToInt() && count.intValue() >= 0,
            "Major Creditor response count is missing or invalid");
        JsonNode refData = root.path("refData");
        assertTrue(refData.isArray(), "Major Creditor response refData is missing or invalid");
        assertEquals(count.intValue(), refData.size(), "Count must equal the returned array size");
        assertEquals(expected.size(), count.intValue(), "Expected exactly the qualifying fixture creditors");
        Map<Long, ExpectedCreditor> expectedById = expected.stream()
            .collect(Collectors.toMap(ExpectedCreditor::id, Function.identity()));
        Set<Long> actualIds = new HashSet<>();
        for (JsonNode item : refData) {
            JsonNode id = item.path("major_creditor_id");
            assertTrue(id.isIntegralNumber() && id.canConvertToLong(), "Missing or invalid Major Creditor identifier");
            assertTrue(actualIds.add(id.longValue()), "Duplicate Major Creditor identifier: " + id.longValue());
            ExpectedCreditor creditor = expectedById.get(id.longValue());
            assertTrue(creditor != null, "Unexpected Major Creditor identifier: " + id.longValue());
            assertNumericField(item, "business_unit_id", (long) creditor.businessUnitId());
            assertTextField(item, "major_creditor_code", creditor.code());
            assertTextField(item, "name", creditor.name());
            assertTextField(item, "address_line_1", creditor.addressLine1());
            assertTextField(item, "contact_name", creditor.contactName());
            assertTextField(item, "contact_email", creditor.contactEmail());
            assertNumericField(item, "country_id", creditor.countryId());
            assertTextField(item, "country_name", creditor.countryName());
            assertTrue(item.path("active").isBoolean() && item.path("active").booleanValue(),
                "Expected an active Major Creditor");
            assertTrue(item.path("central_authority").isBoolean() && !item.path("central_authority").booleanValue(),
                "Central Authority must be false");
        }
        assertEquals(expectedById.keySet(), actualIds, "Returned Major Creditor identifiers do not match the fixture");
    }

    private static void assertTextField(JsonNode item, String field, String expected) {
        JsonNode value = item.path(field);
        if (expected == null) {
            assertTrue(value.isNull(), "Expected null " + field);
        } else {
            assertTrue(value.isTextual(), "Missing or invalid " + field);
            assertEquals(expected, value.textValue(), "Unexpected " + field);
        }
    }

    private static void assertNumericField(JsonNode item, String field, Long expected) {
        JsonNode value = item.path(field);
        if (expected == null) {
            assertTrue(value.isNull(), "Expected null " + field);
        } else {
            assertTrue(value.isIntegralNumber() && value.canConvertToLong(), "Missing or invalid " + field);
            assertEquals(expected.longValue(), value.longValue(), "Unexpected " + field);
        }
    }

    private static JsonNode assertNoReferenceData(Response response) throws IOException {
        JsonNode problem = OBJECT_MAPPER.readTree(response.asString());
        for (String field : List.of("count", "refData", "stackTrace")) {
            assertFalse(problem.has(field), "Problem response must not expose " + field);
        }
        return problem;
    }

    private MajorCreditorsFixture requiredFixture() {
        if (fixture == null) {
            throw new IllegalStateException(
                "No Major Creditor fixture is available; run the isolated-data Given first");
        }
        return fixture;
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
