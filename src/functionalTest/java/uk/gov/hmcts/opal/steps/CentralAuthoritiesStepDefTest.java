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

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mockStatic;

class CentralAuthoritiesStepDefTest {

    private static final short BUSINESS_UNIT_ID = 44;
    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();
    private static final String RESPONSE = """
        {"count":1,"refData":[
          {"major_creditor_id":101,"business_unit_id":44,"major_creditor_code":"0001",
           "name":"Urad pro mezinarodnepravni ochranu deti",
           "address_line_1":"Silingrovo nam 3/4","address_line_2":"Brno",
           "postcode":"602 00","active":true,"central_authority":true}
        ]}
        """;

    @Test
    void acceptsSeededAuthority() {
        assertDoesNotThrow(() -> CentralAuthoritiesStepDef.assertAuthorities(RESPONSE, BUSINESS_UNIT_ID));
    }

    @ParameterizedTest
    @ValueSource(booleans = {false, true})
    void acceptsExtraAuthorityInEitherOrder(boolean reversed) throws IOException {
        ObjectNode response = responseWithExtraAuthority();
        ArrayNode items = (ArrayNode) response.path("refData");
        if (reversed) {
            items.add(items.remove(0));
        }
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

    @Test
    void rejectsMissingSeededAuthority() {
        assertInvalid(RESPONSE.replace("\"0001\"", "\"0002\""));
    }

    @Test
    void rejectsDuplicateCode() throws IOException {
        ObjectNode response = responseWithExtraAuthority();
        item(response, 1).put("major_creditor_code", "0001");
        assertInvalid(response.toString());
    }

    @ParameterizedTest
    @ValueSource(strings = {"active", "central_authority"})
    void rejectsFalseFilterFlag(String field) throws IOException {
        ObjectNode response = response();
        item(response, 0).put(field, false);
        assertInvalid(response.toString());
    }

    @Test
    void rejectsWrongBusinessUnit() throws IOException {
        ObjectNode response = response();
        item(response, 0).put("business_unit_id", 1);
        assertInvalid(response.toString());
    }

    @Test
    void rejectsDuplicateIdentifier() throws IOException {
        ObjectNode response = responseWithExtraAuthority();
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
    @ValueSource(strings = {"name", "address_line_1", "address_line_2", "postcode"})
    void rejectsAlteredCasefileDetails(String field) throws IOException {
        ObjectNode response = response();
        item(response, 0).put(field, "Altered value");
        assertInvalid(response.toString());
    }

    @Test
    void rejectsMissingAddress() throws IOException {
        ObjectNode response = response();
        item(response, 0).remove("address_line_1");
        assertInvalid(response.toString());
    }

    @Test
    void requestsSeededBusinessUnit() {
        try (MockedStatic<BaseStepDef> http = mockStatic(BaseStepDef.class);
             MockedStatic<BearerTokenStepDef> token = mockStatic(BearerTokenStepDef.class)) {
            token.when(BearerTokenStepDef::getToken).thenReturn("synthetic-test-token");
            new CentralAuthoritiesStepDef().requestActiveAuthorities();
            http.verify(() -> BaseStepDef.getWithBearer(
                "/major-creditors?business_unit_id=44&active=true&central_authority=true", "synthetic-test-token"));
        }
    }

    @ParameterizedTest
    @ValueSource(booleans = {false, true})
    void requestsSeededErrorJourneys(boolean authenticated) {
        try (MockedStatic<BaseStepDef> http = mockStatic(BaseStepDef.class);
             MockedStatic<BearerTokenStepDef> token = mockStatic(BearerTokenStepDef.class)) {
            token.when(BearerTokenStepDef::getToken).thenReturn("synthetic-test-token");
            CentralAuthoritiesStepDef steps = new CentralAuthoritiesStepDef();
            if (authenticated) {
                steps.requestMalformedAuthorityFilter();
                http.verify(() -> BaseStepDef.getWithBearer(
                    "/major-creditors?business_unit_id=44&active=true&central_authority=not-a-boolean",
                    "synthetic-test-token"));
            } else {
                steps.requestUnauthenticatedAuthorities();
                http.verify(() -> BaseStepDef.getWithoutBearer(
                    "/major-creditors?business_unit_id=44&active=true&central_authority=true"));
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

    private static ObjectNode responseWithExtraAuthority() throws IOException {
        ObjectNode response = response();
        ObjectNode extra = OBJECT_MAPPER.createObjectNode();
        extra.put("major_creditor_id", 102).put("business_unit_id", BUSINESS_UNIT_ID)
            .put("major_creditor_code", "0002").put("active", true).put("central_authority", true);
        ((ArrayNode) response.path("refData")).add(extra);
        response.put("count", 2);
        return response;
    }

    private static ObjectNode item(ObjectNode response, int index) {
        return (ObjectNode) response.path("refData").get(index);
    }

    private static void assertInvalid(String body) {
        assertThrows(AssertionError.class, () -> CentralAuthoritiesStepDef.assertAuthorities(body, BUSINESS_UNIT_ID));
    }
}
