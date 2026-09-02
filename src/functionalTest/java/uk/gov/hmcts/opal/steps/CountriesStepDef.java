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
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

public class CountriesStepDef extends BaseStepDef {

    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();
    private static final Comparator<Country> DISPLAY_ORDER = Comparator.comparing(Country::countryName)
        .thenComparingLong(Country::countryId);

    private Response latestResponse;

    @When("I request active Countries")
    public void requestActiveCountries() {
        latestResponse = getWithBearer("/countries?active=true", BearerTokenStepDef.getToken());
    }

    @Then("active Countries are returned in display order for casefile address selection")
    public void assertActiveCountriesInDisplayOrder() throws IOException {
        Response response = latestResponse();
        assertEquals(200, response.statusCode(), "Country request did not succeed");
        assertTrue(
            response.contentType() != null && response.contentType().startsWith("application/json"),
            "Expected application/json but received " + response.contentType()
        );
        assertActiveCountryResponse(response.asString());
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

    @When("I request Countries without authentication")
    public void requestCountriesWithoutAuthentication() {
        latestResponse = getWithoutBearer("/countries");
    }

    @Then("the Country unauthorized Problem Details response is returned")
    public void assertCountryUnauthorizedProblemDetails() throws IOException {
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
        assertFalse(problem.has("count"), "Unauthorized response must not expose a Country count");
        assertFalse(problem.has("refData"), "Unauthorized response must not expose Country reference data");
    }

    static void assertActiveCountryResponse(String responseBody) throws IOException {
        JsonNode root = OBJECT_MAPPER.readTree(responseBody);
        JsonNode count = root.path("count");
        assertTrue(
            count.isIntegralNumber() && count.canConvertToInt() && count.intValue() >= 0,
            "Country response count is missing or invalid"
        );
        assertTrue(root.path("refData").isArray(), "Country response refData is missing or invalid");
        assertEquals(count.intValue(), root.path("refData").size());
        assertTrue(
            root.path("refData").size() > 1,
            "Expected the United Kingdom and at least one other active Country"
        );

        List<Country> countries = new ArrayList<>();
        Set<Long> countryIds = new HashSet<>();
        for (JsonNode item : root.path("refData")) {
            JsonNode countryIdNode = item.path("country_id");
            assertTrue(
                countryIdNode.isIntegralNumber()
                    && countryIdNode.canConvertToLong()
                    && countryIdNode.longValue() > 0,
                "Country identifier is missing or invalid"
            );
            assertTrue(
                item.path("country_name").isTextual() && !item.path("country_name").asText().isBlank(),
                "Country name is missing or invalid"
            );
            assertTrue(item.path("active").isBoolean(), "Country active state is missing or invalid");
            assertTrue(item.path("active").asBoolean(), "Inactive Country returned by the active filter");

            long countryId = countryIdNode.longValue();
            assertTrue(countryIds.add(countryId), "Duplicate Country identifier returned: " + countryId);
            String internationalCode = item.path("international_code").isTextual()
                ? item.path("international_code").asText()
                : null;
            countries.add(new Country(countryId, internationalCode, item.path("country_name").asText()));
        }

        Country unitedKingdom = countries.getFirst();
        assertEquals("GBR", unitedKingdom.internationalCode(), "United Kingdom must be returned first");
        assertEquals("United Kingdom", unitedKingdom.countryName(), "Canonical United Kingdom record is missing");

        JsonNode unitedKingdomNode = root.path("refData").get(0);
        assertFalse(unitedKingdomNode.has("selected"), "United Kingdom must not be marked as selected");
        assertFalse(unitedKingdomNode.has("defaulted"), "United Kingdom must not be marked as defaulted");

        List<Country> remainingCountries = countries.subList(1, countries.size());
        List<Country> expectedOrder = new ArrayList<>(remainingCountries);
        expectedOrder.sort(DISPLAY_ORDER);
        assertEquals(
            expectedOrder,
            remainingCountries,
            "Countries after United Kingdom must be ordered by country_name and then country_id"
        );
    }

    private Response required(Response response, String responseName) {
        if (response == null) {
            throw new IllegalStateException("No " + responseName + " Country response is available");
        }
        return response;
    }

    Response latestResponse() {
        return required(latestResponse, "latest");
    }

    private record Country(long countryId, String internationalCode, String countryName) {
    }
}
