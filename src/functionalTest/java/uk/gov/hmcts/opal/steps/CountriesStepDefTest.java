package uk.gov.hmcts.opal.steps;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;

import io.restassured.builder.ResponseBuilder;
import io.restassured.response.Response;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.http.MediaType;

class CountriesStepDefTest {

    @Test
    void acceptsCurrentCountryValidationProblemDetails() {
        CountriesStepDef stepDef = new CountriesStepDef();
        stepDef.latestResponse(validationResponse(""));

        assertDoesNotThrow(stepDef::assertCountryValidationProblemDetails);
    }

    @Test
    void rejectsCountryValidationProblemDetailsThatExposeUnsafeReason() {
        CountriesStepDef stepDef = new CountriesStepDef();
        stepDef.latestResponse(validationResponse(", \"reason\": \"not-a-boolean\""));

        assertThrows(AssertionError.class, stepDef::assertCountryValidationProblemDetails);
    }

    @Test
    void acceptsActiveCountriesInDisplayOrder() {
        assertDoesNotThrow(() -> CountriesStepDef.assertActiveCountryResponse("""
            {
              "count": 4,
              "refData": [
                {"country_id": 102, "international_code": "GBR", "country_name": "United Kingdom", "active": true},
                {"country_id": 101, "international_code": "FRA", "country_name": "France", "active": true},
                {"country_id": 201, "international_code": "ZZ1", "country_name": "Zealand", "active": true},
                {"country_id": 202, "international_code": "ZZ2", "country_name": "Zealand", "active": true}
              ]
            }
            """));
    }

    @Test
    void rejectsInactiveCountry() {
        assertInvalidCountryResponse("""
            {
              "count": 2,
              "refData": [
                {"country_id": 102, "international_code": "GBR", "country_name": "United Kingdom", "active": true},
                {"country_id": 101, "international_code": "FRA", "country_name": "France", "active": false}
              ]
            }
            """);
    }

    @Test
    void rejectsResponseWithoutAnotherActiveCountry() {
        assertInvalidCountryResponse("""
            {
              "count": 1,
              "refData": [
                {"country_id": 102, "international_code": "GBR", "country_name": "United Kingdom", "active": true}
              ]
            }
            """);
    }

    @Test
    void rejectsUnitedKingdomAfterAnotherCountry() {
        assertInvalidCountryResponse("""
            {
              "count": 2,
              "refData": [
                {"country_id": 101, "international_code": "FRA", "country_name": "France", "active": true},
                {"country_id": 102, "international_code": "GBR", "country_name": "United Kingdom", "active": true}
              ]
            }
            """);
    }

    @Test
    void rejectsCountriesOutsideAlphabeticalOrder() {
        assertInvalidCountryResponse("""
            {
              "count": 3,
              "refData": [
                {"country_id": 102, "international_code": "GBR", "country_name": "United Kingdom", "active": true},
                {"country_id": 103, "international_code": "DEU", "country_name": "Germany", "active": true},
                {"country_id": 101, "international_code": "FRA", "country_name": "France", "active": true}
              ]
            }
            """);
    }

    @Test
    void rejectsDuplicateNamesOutsideCountryIdOrder() {
        assertInvalidCountryResponse("""
            {
              "count": 3,
              "refData": [
                {"country_id": 102, "international_code": "GBR", "country_name": "United Kingdom", "active": true},
                {"country_id": 202, "international_code": "ZZ2", "country_name": "Zealand", "active": true},
                {"country_id": 201, "international_code": "ZZ1", "country_name": "Zealand", "active": true}
              ]
            }
            """);
    }

    @ParameterizedTest
    @ValueSource(strings = {"selected", "defaulted"})
    void rejectsUnitedKingdomSelectionMetadata(String fieldName) {
        assertInvalidCountryResponse("""
            {
              "count": 2,
              "refData": [
                {
                  "country_id": 102,
                  "international_code": "GBR",
                  "country_name": "United Kingdom",
                  "active": true,
                  "%s": true
                },
                {"country_id": 101, "international_code": "FRA", "country_name": "France", "active": true}
              ]
            }
            """.formatted(fieldName));
    }

    private void assertInvalidCountryResponse(String body) {
        assertThrows(AssertionError.class, () -> CountriesStepDef.assertActiveCountryResponse(body));
    }

    private Response validationResponse(String additionalField) {
        return new ResponseBuilder()
            .setStatusCode(400)
            .setContentType(MediaType.APPLICATION_PROBLEM_JSON_VALUE)
            .setBody("""
                {
                  "type": "https://hmcts.gov.uk/problems/type-mismatch",
                  "title": "Bad Request",
                  "status": 400,
                  "detail": "Parameter 'active' must be of type Boolean",
                  "instance": "/countries",
                  "operation_id": "test-operation-id",
                  "retriable": false%s
                }
                """.formatted(additionalField))
            .build();
    }
}
