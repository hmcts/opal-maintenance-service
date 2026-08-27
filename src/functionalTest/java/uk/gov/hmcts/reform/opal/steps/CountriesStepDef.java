package uk.gov.hmcts.reform.opal.steps;

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

    private Map<Long, Boolean> readCountries(Response response) throws IOException {
        assertEquals(200, response.statusCode(), "Country request did not succeed");
        JsonNode root = OBJECT_MAPPER.readTree(response.asString());
        assertTrue(root.path("count").canConvertToInt(), "Country response count is missing or invalid");
        assertTrue(root.path("refData").isArray(), "Country response refData is missing or invalid");
        assertEquals(root.path("count").asInt(), root.path("refData").size());

        Map<Long, Boolean> countries = new LinkedHashMap<>();
        for (JsonNode item : root.path("refData")) {
            assertTrue(item.path("country_id").canConvertToLong(), "Country identifier is missing or invalid");
            assertTrue(item.path("active").isBoolean(), "Country active state is missing or invalid");
            long countryId = item.path("country_id").asLong();
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
