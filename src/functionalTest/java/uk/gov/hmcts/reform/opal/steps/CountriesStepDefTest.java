package uk.gov.hmcts.reform.opal.steps;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import static org.junit.jupiter.api.Assertions.assertThrows;

class CountriesStepDefTest {

    @Test
    void rejectsFractionalCount() {
        assertInvalidCountryResponse("""
            {"count": 0.5, "refData": []}
            """);
    }

    @Test
    void rejectsFractionalCountryId() {
        assertInvalidCountryResponse("""
            {"count": 1, "refData": [{"country_id": 1.5, "active": true}]}
            """);
    }

    @ParameterizedTest
    @ValueSource(longs = {0, -1})
    void rejectsNonPositiveCountryId(long countryId) {
        assertInvalidCountryResponse("""
            {"count": 1, "refData": [{"country_id": %d, "active": true}]}
            """.formatted(countryId));
    }

    private void assertInvalidCountryResponse(String body) {
        assertThrows(AssertionError.class, () -> CountriesStepDef.readCountries(body));
    }
}
