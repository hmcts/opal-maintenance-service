package uk.gov.hmcts.opal.steps;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.cucumber.java.After;
import io.cucumber.java.en.Given;
import io.cucumber.java.en.Then;
import io.cucumber.java.en.When;
import io.restassured.response.Response;

import java.io.IOException;
import java.sql.SQLException;
import java.util.HashSet;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static uk.gov.hmcts.opal.assertions.ProblemDetailAssertions.assertProblemDetail;

public class CentralAuthoritiesStepDef extends BaseStepDef {

    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();
    private Response latestResponse;
    private CentralAuthorityFixtures fixtures;

    @Given("this scenario owns active and excluded Central Authority records")
    public void createOwnedAuthorities() throws SQLException {
        fixtures = CentralAuthorityFixtures.create();
    }

    @After
    public void closeOwnedAuthorities() throws SQLException {
        if (fixtures != null) {
            // Cucumber records hook failures separately, retaining an earlier scenario failure too.
            fixtures.close();
        }
    }

    @When("I request active Central Authorities for this scenario's business unit")
    public void requestActiveAuthorities() {
        latestResponse = getWithBearer("/major-creditors?business_unit_id=" + fixtures.businessUnitId()
            + "&active=true&central_authority=true", BearerTokenStepDef.getToken());
    }

    @Then("the Central Authority details are available for casefile selection")
    public void assertCasefileAuthorities() throws IOException {
        assertEquals(200, latestResponse.statusCode(), "Central Authority request did not succeed");
        assertTrue(latestResponse.contentType() != null
            && latestResponse.contentType().startsWith("application/json"), "Expected application/json");
        assertAuthorities(latestResponse.asString(), fixtures.businessUnitId());
    }

    @When("I request Central Authorities with a malformed authority filter")
    public void requestMalformedAuthorityFilter() {
        latestResponse = getWithBearer(
            "/major-creditors?business_unit_id=1&active=true&central_authority=not-a-boolean",
            BearerTokenStepDef.getToken());
    }

    @Then("a correlated Central Authority validation rejection is returned")
    public void assertValidationRejection() throws IOException {
        assertProblemDetail(latestResponse, 400, "https://hmcts.gov.uk/problems/type-mismatch", "Bad Request",
            "Parameter 'central_authority' must be of type Boolean", "instance", "operation_id");
        assertFalse(latestResponse.asString().contains("not-a-boolean"), "Rejected literal must not be exposed");
        assertNoDataOrDiagnostics();
    }

    @When("I request Central Authorities without authentication")
    public void requestUnauthenticatedAuthorities() {
        latestResponse = getWithoutBearer("/major-creditors?business_unit_id=1&active=true&central_authority=true");
    }

    @Then("authentication is required without exposing Central Authority data")
    public void assertAuthenticationRequired() throws IOException {
        assertProblemDetail(latestResponse, 401, "https://hmcts.gov.uk/problems/unauthorized", "Unauthorized",
            "You are not authorized to access this resource", "instance", "operation_id");
        assertNoDataOrDiagnostics();
    }

    private void assertNoDataOrDiagnostics() throws IOException {
        JsonNode problem = OBJECT_MAPPER.readTree(latestResponse.asString());
        for (String field : Set.of("count", "refData", "stackTrace", "exception")) {
            assertFalse(problem.has(field), "Problem Details must not expose " + field);
        }
    }

    static void assertAuthorities(String body, short businessUnitId) throws IOException {
        JsonNode root = OBJECT_MAPPER.readTree(body);
        JsonNode count = root.path("count");
        JsonNode authorities = root.path("refData");
        assertTrue(count.isIntegralNumber() && count.canConvertToInt(), "Invalid authority count");
        assertTrue(authorities.isArray(), "Expected authority reference data array");
        assertEquals(count.intValue(), authorities.size(), "Authority count must match reference data");
        assertEquals(2, authorities.size(), "Expected both owned active Central Authorities");

        Set<Long> ids = new HashSet<>();
        Set<String> codes = new HashSet<>();
        for (JsonNode authority : authorities) {
            JsonNode id = authority.path("major_creditor_id");
            assertTrue(id.isIntegralNumber() && id.canConvertToLong() && id.longValue() > 0,
                "Expected positive authority identifier");
            assertTrue(ids.add(id.longValue()), "Duplicate authority identifier");
            JsonNode unit = authority.path("business_unit_id");
            assertTrue(unit.isIntegralNumber() && unit.canConvertToInt(), "Invalid business unit identifier");
            assertEquals((int) businessUnitId, unit.intValue(), "Authority belongs to a different business unit");
            for (String flag : Set.of("active", "central_authority")) {
                assertTrue(authority.path(flag).isBoolean() && authority.path(flag).booleanValue(),
                    "Authority must have " + flag + " enabled");
            }
            JsonNode code = authority.path("major_creditor_code");
            assertTrue(code.isTextual(), "Authority code must be textual");
            assertTrue(codes.add(code.textValue()), "Duplicate authority code");
            assertTrue(Set.of("A001", "A002").contains(code.textValue()), "Excluded creditor returned");
            boolean first = "A001".equals(code.textValue());
            assertText(authority, "name", first ? "Synthetic Authority One" : "Synthetic Authority Two");
            assertText(authority, "address_line_1", first ? "Synthetic address one" : "Synthetic address two");
            assertText(authority, "address_line_2", first ? "Synthetic line two" : null);
            assertText(authority, "postcode", first ? "ZZ1 1ZZ" : null);
            assertText(authority, "contact_name", first ? "Synthetic Contact" : null);
            assertText(authority, "contact_email", first ? "contact@example.invalid" : null);
        }
        assertEquals(Set.of("A001", "A002"), codes, "Expected both authority codes");
    }

    private static void assertText(JsonNode authority, String field, String expected) {
        JsonNode value = authority.path(field);
        if (expected == null) {
            assertTrue(value.isNull(), "Expected nullable authority field: " + field);
        } else {
            assertTrue(value.isTextual(), "Expected textual authority field: " + field);
            assertEquals(expected, value.textValue(), "Unexpected authority " + field);
        }
    }
}
