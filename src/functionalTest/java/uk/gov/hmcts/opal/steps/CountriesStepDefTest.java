package uk.gov.hmcts.opal.steps;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

class CountriesStepDefTest {

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
}
