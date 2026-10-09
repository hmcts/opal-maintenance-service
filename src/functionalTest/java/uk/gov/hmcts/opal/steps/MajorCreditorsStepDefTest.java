package uk.gov.hmcts.opal.steps;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import io.restassured.builder.ResponseBuilder;
import io.restassured.response.Response;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import java.io.IOException;
import java.util.List;

class MajorCreditorsStepDefTest {
    private static final ObjectMapper MAPPER = new ObjectMapper();

    @Test
    void acceptsSeededCreditor() {
        assertDoesNotThrow(() -> MajorCreditorsStepDef.assertActiveResponse(validBody().toString()));
    }

    @Test
    void acceptsExtraQualifyingCreditorInEitherOrder() throws IOException {
        ObjectNode body = validBody();
        ObjectNode extra = body.withArray("refData").get(0).deepCopy();
        extra.put("major_creditor_id", 102).put("major_creditor_code", "X001").put("name", "Another Creditor");
        body.withArray("refData").add(extra);
        body.put("count", 2);
        assertDoesNotThrow(() -> MajorCreditorsStepDef.assertActiveResponse(body.toString()));
        body.withArray("refData").add(body.withArray("refData").remove(0));
        assertDoesNotThrow(() -> MajorCreditorsStepDef.assertActiveResponse(body.toString()));
    }

    @ParameterizedTest
    @ValueSource(strings = {
        "{}", "{\"count\":0,\"refData\":[]}", "{\"count\":1,\"refData\":{}}",
        "{\"count\":1,\"refData\":[{}]}", "{\"count\":1,\"refData\":null}"
    })
    void rejectsEmptyOrMalformedSelection(String body) {
        assertThrows(AssertionError.class, () -> MajorCreditorsStepDef.assertActiveResponse(body));
    }

    @ParameterizedTest
    @ValueSource(strings = {"-1", "0", "2", "1.0", "\"1\"", "null", "2147483648"})
    void rejectsInvalidOrMismatchedCount(String count) throws IOException {
        ObjectNode body = validBody();
        body.set("count", MAPPER.readTree(count));
        assertInvalid(body);
    }

    @ParameterizedTest
    @ValueSource(strings = {"T902", "T903", "X001"})
    void rejectsComparatorsOrMissingSeed(String code) throws IOException {
        ObjectNode body = validBody();
        ((ObjectNode) body.withArray("refData").get(0)).put("major_creditor_code", code);
        assertInvalid(body);
    }

    @ParameterizedTest
    @ValueSource(strings = {"0", "-1", "1.5", "\"101\"", "null", "9223372036854775808"})
    void rejectsInvalidIdentifier(String id) throws IOException {
        ObjectNode body = validBody();
        ((ObjectNode) body.withArray("refData").get(0)).set("major_creditor_id", MAPPER.readTree(id));
        assertInvalid(body);
    }

    @Test
    void rejectsDuplicateIdentifier() throws IOException {
        ObjectNode body = validBody();
        ObjectNode extra = body.withArray("refData").get(0).deepCopy();
        extra.put("major_creditor_code", "X001");
        body.withArray("refData").add(extra);
        body.put("count", 2);
        assertInvalid(body);
    }

    @ParameterizedTest
    @ValueSource(strings = {"business_unit_id", "active", "central_authority"})
    void rejectsIncorrectSelection(String field) throws IOException {
        ObjectNode body = validBody();
        ObjectNode item = (ObjectNode) body.withArray("refData").get(0);
        if (field.equals("business_unit_id")) {
            item.put(field, 45);
        } else {
            item.put(field, field.equals("central_authority"));
        }
        assertInvalid(body);
    }

    @ParameterizedTest
    @ValueSource(strings = {"major_creditor_code", "name", "address_line_1", "address_line_2", "address_line_3",
        "address_line_4", "address_line_5", "postcode",
        "contact_name", "contact_email", "country_name"})
    void rejectsChangedSeedDetails(String field) throws IOException {
        ObjectNode body = validBody();
        ((ObjectNode) body.withArray("refData").get(0)).put(field, "changed");
        assertInvalid(body);
    }

    @ParameterizedTest
    @ValueSource(strings = {"0", "-1", "\"1\"", "null"})
    void rejectsInvalidSeedCountry(String id) throws IOException {
        ObjectNode body = validBody();
        ((ObjectNode) body.withArray("refData").get(0)).set("country_id", MAPPER.readTree(id));
        assertInvalid(body);
    }

    @Test
    void acceptsAvailableSelectionAndComparators() throws IOException {
        assertDoesNotThrow(() -> MajorCreditorsStepDef.assertSeedPrerequisites(prerequisites().toString()));
    }

    @ParameterizedTest
    @ValueSource(ints = {0, 1, 2})
    void rejectsMissingComparisonData(int index) throws IOException {
        ObjectNode body = prerequisites();
        body.withArray("refData").remove(index);
        assertThrows(AssertionError.class, () -> MajorCreditorsStepDef.assertSeedPrerequisites(body.toString()));
    }

    @ParameterizedTest
    @ValueSource(strings = {"active", "central_authority"})
    void rejectsIncorrectComparisonFlags(String field) throws IOException {
        ObjectNode body = prerequisites();
        ObjectNode comparator = (ObjectNode) body.withArray("refData").get(1);
        comparator.put(field, !comparator.path(field).booleanValue());
        assertThrows(AssertionError.class, () -> MajorCreditorsStepDef.assertSeedPrerequisites(body.toString()));
    }

    private ObjectNode prerequisites() throws IOException {
        ObjectNode body = validBody();
        ObjectNode inactive = body.withArray("refData").get(0).deepCopy();
        inactive.put("major_creditor_code", "T902").put("active", false);
        ObjectNode authority = body.withArray("refData").get(0).deepCopy();
        authority.put("major_creditor_code", "T903").put("central_authority", true);
        body.withArray("refData").add(inactive).add(authority);
        body.put("count", 3);
        return body;
    }

    @Test
    void requiresRequestStateBeforeThenAssertions() {
        MajorCreditorsStepDef steps = new MajorCreditorsStepDef();
        assertThrows(IllegalStateException.class, steps::assertActiveMajorCreditors);
        assertThrows(IllegalStateException.class, steps::assertValidationResponse);
        assertThrows(IllegalStateException.class, steps::assertUnauthorizedResponse);
    }

    @Test
    void acceptsCorrelatedValidationResponse() {
        MajorCreditorsStepDef steps = new MajorCreditorsStepDef();
        steps.latestResponse(problemResponse(400, ""));
        assertDoesNotThrow(steps::assertValidationResponse);
    }

    @Test
    void acceptsCorrelatedUnauthorizedResponse() {
        MajorCreditorsStepDef steps = new MajorCreditorsStepDef();
        steps.latestResponse(problemResponse(401, ""));
        assertDoesNotThrow(steps::assertUnauthorizedResponse);
    }

    @ParameterizedTest
    @ValueSource(strings = {"count", "refData", "stackTrace"})
    void rejectsDisclosedErrorProperties(String field) {
        for (int status : List.of(400, 401)) {
            MajorCreditorsStepDef steps = new MajorCreditorsStepDef();
            steps.latestResponse(problemResponse(status, ", \"" + field + "\": null"));
            assertThrows(AssertionError.class,
                status == 400 ? steps::assertValidationResponse : steps::assertUnauthorizedResponse);
        }
    }

    @ParameterizedTest
    @ValueSource(strings = {", \"reason\": null", ", \"extra\": \"not-a-boolean\""})
    void rejectsValidationDetailsThatExposeRejectedValue(String property) {
        MajorCreditorsStepDef steps = new MajorCreditorsStepDef();
        steps.latestResponse(problemResponse(400, property));
        assertThrows(AssertionError.class, steps::assertValidationResponse);
    }

    @Test
    void rejectsBlankCorrelation() {
        for (int status : List.of(400, 401)) {
            MajorCreditorsStepDef steps = new MajorCreditorsStepDef();
            Response problem = problemResponse(status, "");
            steps.latestResponse(new ResponseBuilder().clone(problem)
                .setBody(problem.asString().replace("test-operation-id", "")).build());
            assertThrows(AssertionError.class,
                status == 400 ? steps::assertValidationResponse : steps::assertUnauthorizedResponse);
        }
    }

    private Response problemResponse(int status, String additional) {
        String type = status == 400 ? "type-mismatch" : "unauthorized";
        String title = status == 400 ? "Bad Request" : "Unauthorized";
        String detail = status == 400 ? "Parameter 'active' must be of type Boolean"
            : "You are not authorized to access this resource";
        return new ResponseBuilder().setStatusCode(status).setContentType("application/problem+json")
            .setBody("""
                {"type":"https://hmcts.gov.uk/problems/%s","title":"%s","status":%s,"detail":"%s",
                 "instance":"/major-creditors","operation_id":"test-operation-id","retriable":false%s}
                """.formatted(type, title, status, detail, additional)).build();
    }

    private void assertInvalid(ObjectNode body) {
        assertThrows(AssertionError.class, () -> MajorCreditorsStepDef.assertActiveResponse(body.toString()));
    }

    private ObjectNode validBody() throws IOException {
        return (ObjectNode) MAPPER.readTree("""
            {"count":1,"refData":[
              {"major_creditor_id":101,"business_unit_id":44,"major_creditor_code":"T901",
               "name":"Functional Test Major Creditor","address_line_1":"1 Synthetic Test Street",
               "address_line_2":"Synthetic Test Town",
               "address_line_3":"Synthetic Test District","address_line_4":"Synthetic Test Region",
               "address_line_5":"Synthetic Test Province","postcode":"ZZ1 1ZZ",
               "contact_name":"Synthetic Test Contact","contact_email":"creditor@example.invalid",
               "country_id":7,"country_name":"Czech Republic","active":true,"central_authority":false}
            ]}
            """);
    }
}
