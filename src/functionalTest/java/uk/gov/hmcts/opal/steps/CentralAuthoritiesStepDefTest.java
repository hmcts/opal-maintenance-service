package uk.gov.hmcts.opal.steps;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import io.restassured.builder.ResponseBuilder;
import io.restassured.response.Response;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.mockito.MockedStatic;
import org.junit.jupiter.params.provider.ValueSource;

import java.io.IOException;
import java.sql.SQLException;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.mockStatic;
import static org.mockito.Mockito.verify;

class CentralAuthoritiesStepDefTest {

    private static final short BUSINESS_UNIT_ID = 30000;
    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();
    private static final String RESPONSE = """
        {"count":2,"refData":[
          {"major_creditor_id":101,"business_unit_id":30000,"major_creditor_code":"A001",
           "name":"Synthetic Authority One","address_line_1":"Synthetic address one",
           "address_line_2":"Synthetic line two","postcode":"ZZ1 1ZZ",
           "contact_name":"Synthetic Contact","contact_email":"contact@example.invalid",
           "active":true,"central_authority":true},
          {"major_creditor_id":102,"business_unit_id":30000,"major_creditor_code":"A002",
           "name":"Synthetic Authority Two","address_line_1":"Synthetic address two",
           "address_line_2":null,"postcode":null,"contact_name":null,"contact_email":null,
           "active":true,"central_authority":true}
        ]}
        """;

    @Test
    void acceptsAuthoritiesWithNullableContact() {
        assertDoesNotThrow(() -> CentralAuthoritiesStepDef.assertAuthorities(RESPONSE, BUSINESS_UNIT_ID));
    }

    @Test
    void acceptsReversedOrder() throws IOException {
        ObjectNode response = response();
        ArrayNode items = (ArrayNode) response.path("refData");
        items.add(items.remove(0));
        assertDoesNotThrow(() -> CentralAuthoritiesStepDef.assertAuthorities(response.toString(), BUSINESS_UNIT_ID));
    }

    @Test
    void rejectsEmptyAuthoritySelection() {
        assertInvalid("{\"count\":0,\"refData\":[]}");
    }

    @Test
    void rejectsInconsistentCount() {
        assertInvalid("{\"count\":2,\"refData\":[]}");
    }

    @ParameterizedTest
    @ValueSource(ints = {0, 1})
    void rejectsMissingAuthority(int index) throws IOException {
        ObjectNode response = response();
        ((ArrayNode) response.path("refData")).remove(index);
        response.put("count", 1);
        assertInvalid(response.toString());
    }

    @ParameterizedTest
    @ValueSource(strings = {"I001", "M001", "A001"})
    void rejectsExcludedOrDuplicateCode(String code) throws IOException {
        ObjectNode response = response();
        item(response, 1).put("major_creditor_code", code);
        assertInvalid(response.toString());
    }

    @ParameterizedTest
    @CsvSource({"0,active", "1,active", "0,central_authority", "1,central_authority"})
    void rejectsFalseFilterFlag(int index, String field) throws IOException {
        ObjectNode response = response();
        item(response, index).put(field, false);
        assertInvalid(response.toString());
    }

    @ParameterizedTest
    @ValueSource(ints = {0, 1})
    void rejectsWrongBusinessUnit(int index) throws IOException {
        ObjectNode response = response();
        item(response, index).put("business_unit_id", 1);
        assertInvalid(response.toString());
    }

    @Test
    void rejectsDuplicateIdentifier() throws IOException {
        ObjectNode response = response();
        item(response, 1).put("major_creditor_id", 101);
        assertInvalid(response.toString());
    }

    @ParameterizedTest
    @ValueSource(longs = {0, -1})
    void rejectsNonPositiveIdentifier(long id) throws IOException {
        ObjectNode response = response();
        item(response, 0).put("major_creditor_id", id);
        assertInvalid(response.toString());
    }

    @ParameterizedTest
    @CsvSource({"0,name", "1,name", "0,address_line_1", "1,address_line_1", "0,address_line_2",
        "0,postcode", "0,contact_name", "0,contact_email", "1,address_line_2", "1,postcode",
        "1,contact_name", "1,contact_email"})
    void rejectsAlteredCasefileDetails(int index, String field) throws IOException {
        ObjectNode response = response();
        item(response, index).put(field, "Altered synthetic value");
        assertInvalid(response.toString());
    }

    @ParameterizedTest
    @ValueSource(ints = {0, 1})
    void rejectsMissingAddress(int index) throws IOException {
        ObjectNode response = response();
        item(response, index).remove("address_line_1");
        assertInvalid(response.toString());
    }

    @Test
    void propagatesCleanupFailureAfterScenarioFailure() throws SQLException {
        CentralAuthorityFixtures fixtures = mock(CentralAuthorityFixtures.class);
        SQLException cleanupFailure = new SQLException("Synthetic cleanup failure");
        doThrow(cleanupFailure).when(fixtures).close();
        try (MockedStatic<CentralAuthorityFixtures> factory = mockStatic(CentralAuthorityFixtures.class)) {
            factory.when(CentralAuthorityFixtures::create).thenReturn(fixtures);
            CentralAuthoritiesStepDef steps = new CentralAuthoritiesStepDef();
            steps.createOwnedAuthorities();
            assertThrows(AssertionError.class, () ->
                CentralAuthoritiesStepDef.assertAuthorities("{\"count\":0,\"refData\":[]}", BUSINESS_UNIT_ID));
            assertSame(cleanupFailure, assertThrows(SQLException.class, steps::closeOwnedAuthorities));
            verify(fixtures).close();
        }
    }

    @ParameterizedTest
    @ValueSource(booleans = {false, true})
    void errorJourneysDoNotCreateFixtures(boolean authenticated) {
        try (MockedStatic<CentralAuthorityFixtures> factory = mockStatic(CentralAuthorityFixtures.class);
             MockedStatic<BaseStepDef> http = mockStatic(BaseStepDef.class);
             MockedStatic<BearerTokenStepDef> token = mockStatic(BearerTokenStepDef.class)) {
            token.when(BearerTokenStepDef::getToken).thenReturn("synthetic-test-token");
            CentralAuthoritiesStepDef steps = new CentralAuthoritiesStepDef();
            if (authenticated) {
                steps.requestMalformedAuthorityFilter();
            } else {
                steps.requestUnauthenticatedAuthorities();
            }
            assertDoesNotThrow(steps::closeOwnedAuthorities);
            factory.verifyNoInteractions();
            if (authenticated) {
                http.verify(() -> BaseStepDef.getWithBearer(
                    "/major-creditors?business_unit_id=1&active=true&central_authority=not-a-boolean",
                    "synthetic-test-token"));
            } else {
                http.verify(() -> BaseStepDef.getWithoutBearer(
                    "/major-creditors?business_unit_id=1&active=true&central_authority=true"));
            }
        }
    }

    @ParameterizedTest
    @ValueSource(booleans = {false, true})
    void acceptsCorrelatedProblemDetails(boolean validation) {
        assertDoesNotThrow(() -> assertProblemResponse(validation, ""));
    }

    @ParameterizedTest
    @CsvSource({"true,count", "true,refData", "true,stackTrace", "true,exception",
        "false,count", "false,refData", "false,stackTrace", "false,exception"})
    void rejectsProblemDataOrDiagnostics(boolean validation, String field) {
        assertThrows(AssertionError.class, () -> assertProblemResponse(validation, ",\"" + field + "\":null"));
    }

    @Test
    void rejectsEchoedFilterLiteral() {
        assertThrows(AssertionError.class, () -> assertProblemResponse(true, ",\"reason\":\"not-a-boolean\""));
    }

    private static void assertProblemResponse(boolean validation, String extra) throws IOException {
        int status = validation ? 400 : 401;
        Response response = new ResponseBuilder().setStatusCode(status)
            .setContentType("application/problem+json").setBody("""
                {"type":"https://hmcts.gov.uk/problems/%s","title":"%s","status":%d,
                 "detail":"%s","instance":"/major-creditors","operation_id":"synthetic-operation",
                 "retriable":false%s}
                """.formatted(validation ? "type-mismatch" : "unauthorized",
                    validation ? "Bad Request" : "Unauthorized", status,
                    validation ? "Parameter 'central_authority' must be of type Boolean"
                        : "You are not authorized to access this resource", extra)).build();
        try (MockedStatic<BaseStepDef> http = mockStatic(BaseStepDef.class);
             MockedStatic<BearerTokenStepDef> token = mockStatic(BearerTokenStepDef.class)) {
            token.when(BearerTokenStepDef::getToken).thenReturn("synthetic-test-token");
            http.when(() -> BaseStepDef.getWithBearer(anyString(), anyString())).thenReturn(response);
            http.when(() -> BaseStepDef.getWithoutBearer(anyString())).thenReturn(response);
            CentralAuthoritiesStepDef steps = new CentralAuthoritiesStepDef();
            if (validation) {
                steps.requestMalformedAuthorityFilter();
                steps.assertValidationRejection();
            } else {
                steps.requestUnauthenticatedAuthorities();
                steps.assertAuthenticationRequired();
            }
        }
    }

    private static ObjectNode response() throws IOException {
        return (ObjectNode) OBJECT_MAPPER.readTree(RESPONSE);
    }

    private static ObjectNode item(ObjectNode response, int index) {
        return (ObjectNode) response.path("refData").get(index);
    }

    private static void assertInvalid(String body) {
        assertThrows(AssertionError.class, () -> CentralAuthoritiesStepDef.assertAuthorities(body, BUSINESS_UNIT_ID));
    }
}
