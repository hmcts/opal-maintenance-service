package uk.gov.hmcts.opal.steps;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.cucumber.java.en.Then;
import io.cucumber.java.en.When;
import io.restassured.response.Response;

import java.io.IOException;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static uk.gov.hmcts.opal.assertions.ProblemDetailAssertions.assertProblemDetail;

public class CountriesStepDef extends BaseStepDef {

    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();

    private Response allCountriesResponse;
    private Response activeCountriesResponse;
    private Response inactiveCountriesResponse;
    private Response latestResponse;

    @When("I request all Countries")
    public void requestAllCountries() {
        allCountriesResponse = getWithBearer("/countries", BearerTokenStepDef.getToken());
        latestResponse = allCountriesResponse;
    }

    @When("I request active Countries")
    public void requestActiveCountries() {
        activeCountriesResponse = getWithBearer("/countries?active=true", BearerTokenStepDef.getToken());
        latestResponse = activeCountriesResponse;
    }

    @When("I request inactive Countries")
    public void requestInactiveCountries() {
        inactiveCountriesResponse = getWithBearer("/countries?active=false", BearerTokenStepDef.getToken());
        latestResponse = inactiveCountriesResponse;
    }

    @Then("the Country active filter partitions the available Countries")
    public void assertCountryFilterPartition() throws IOException {
        final Map<Long, Boolean> allCountries = readCountries(required(allCountriesResponse, "all"));
        final Map<Long, Boolean> activeCountries = readCountries(required(activeCountriesResponse, "active"));
        final Map<Long, Boolean> inactiveCountries = readCountries(required(inactiveCountriesResponse, "inactive"));

        assertFalse(activeCountries.isEmpty(), "Expected at least one active Country");
        assertFalse(inactiveCountries.isEmpty(), "Expected at least one inactive Country");
        assertTrue(activeCountries.values().stream().allMatch(Boolean::booleanValue));
        assertTrue(inactiveCountries.values().stream().noneMatch(Boolean::booleanValue));

        Set<Long> activeIds = activeCountries.keySet();
        Set<Long> inactiveIds = inactiveCountries.keySet();
        assertTrue(disjoint(activeIds, inactiveIds), "Active and inactive Country sets overlap");

        Set<Long> filteredIds = new HashSet<>(activeIds);
        filteredIds.addAll(inactiveIds);
        assertEquals(allCountries.keySet(), filteredIds, "Filtered Countries do not partition all Countries");
    }

    @When("I request Countries with a malformed active filter")
    public void requestCountriesWithMalformedActiveFilter() {
        latestResponse = getWithBearer(
            "/countries?active=not-a-boolean",
            BearerTokenStepDef.getToken()
        );
    }

    @Then("the Country validation Problem Details response is returned")
    public void assertCountryValidationProblemDetails() throws IOException {
        assertProblemDetail(
            latestResponse(),
            406,
            "https://hmcts.gov.uk/problems/type-mismatch",
            "Not Acceptable",
            "Invalid parameter value format",
            "instance",
            "operation_id",
            "reason"
        );
    }

    @When("I request active Countries without authentication")
    public void requestActiveCountriesWithoutAuthentication() {
        latestResponse = getWithoutBearer("/countries?active=true");
    }

    @Then("the Country unauthorized Problem Details response is returned")
    public void assertCountryUnauthorizedProblemDetails() throws IOException {
        assertProblemDetail(
            latestResponse(),
            401,
            "https://hmcts.gov.uk/problems/unauthorized",
            "Unauthorized",
            "You are not authorized to access this resource",
            "instance",
            "operation_id"
        );
    }

    private Map<Long, Boolean> readCountries(Response response) throws IOException {
        assertEquals(200, response.statusCode(), "Country request did not succeed");
        return readCountries(response.asString());
    }

    static Map<Long, Boolean> readCountries(String responseBody) throws IOException {
        JsonNode root = OBJECT_MAPPER.readTree(responseBody);
        JsonNode count = root.path("count");
        assertTrue(
            count.isIntegralNumber() && count.canConvertToInt() && count.intValue() >= 0,
            "Country response count is missing or invalid"
        );
        assertTrue(root.path("refData").isArray(), "Country response refData is missing or invalid");
        assertEquals(count.intValue(), root.path("refData").size());

        Map<Long, Boolean> countries = new LinkedHashMap<>();
        for (JsonNode item : root.path("refData")) {
            JsonNode countryIdNode = item.path("country_id");
            assertTrue(
                countryIdNode.isIntegralNumber()
                    && countryIdNode.canConvertToLong()
                    && countryIdNode.longValue() > 0,
                "Country identifier is missing or invalid"
            );
            assertTrue(item.path("active").isBoolean(), "Country active state is missing or invalid");
            long countryId = countryIdNode.longValue();
            Boolean previous = countries.put(countryId, item.path("active").asBoolean());
            assertNull(previous, "Duplicate Country identifier returned: " + countryId);
        }
        return countries;
    }

    private Response required(Response response, String responseName) {
        if (response == null) {
            throw new IllegalStateException("No " + responseName + " Country response is available");
        }
        return response;
    }

    private boolean disjoint(Set<Long> first, Set<Long> second) {
        return first.stream().noneMatch(second::contains);
    }

    Response latestResponse() {
        return required(latestResponse, "latest");
    }
}
