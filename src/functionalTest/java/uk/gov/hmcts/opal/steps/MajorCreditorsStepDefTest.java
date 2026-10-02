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
import uk.gov.hmcts.opal.fixtures.MajorCreditorsFixture.ExpectedCreditor;

import java.io.IOException;
import java.util.List;

class MajorCreditorsStepDefTest {
    private static final ObjectMapper MAPPER = new ObjectMapper();
    private static final List<ExpectedCreditor> EXPECTED = List.of(
        new ExpectedCreditor(101L, (short) 31010, "F001", "Synthetic Creditor Alpha",
            "Synthetic address Alpha", "Synthetic Contact Alpha", "alpha@example.invalid",
            9000101L, "Synthetic Functional Country"),
        new ExpectedCreditor(102L, (short) 31010, "F002", "Synthetic Creditor Beta",
            "Synthetic address Beta", null, null, null, null)
    );

    @Test
    void acceptsExpectedCreditorsWithNullableBetaDetails() {
        assertDoesNotThrow(() -> MajorCreditorsStepDef.assertActiveResponse(validBody().toString(), EXPECTED));
    }

    @Test
    void acceptsEitherDisplayOrder() throws IOException {
        ObjectNode body = validBody();
        body.withArray("refData").add(body.withArray("refData").remove(0));
        assertDoesNotThrow(() -> MajorCreditorsStepDef.assertActiveResponse(body.toString(), EXPECTED));
    }

    @Test
    void rejectsAnEmptySuccessfulResponseWhenCreditorsAreExpected() {
        assertInvalid("{\"count\":0,\"refData\":[]}");
    }

    @Test
    void rejectsMissingCreditor() throws IOException {
        ObjectNode body = validBody();
        body.withArray("refData").remove(1);
        body.put("count", 1);
        assertInvalid(body.toString());
    }

    @Test
    void rejectsUnexpectedExtraCreditor() throws IOException {
        ObjectNode body = validBody();
        ObjectNode extra = body.withArray("refData").get(0).deepCopy();
        extra.put("major_creditor_id", 103);
        body.withArray("refData").add(extra);
        body.put("count", 3);
        assertInvalid(body.toString());
    }

    @ParameterizedTest
    @ValueSource(longs = {101, 103})
    void rejectsDuplicateOrUnexpectedId(long id) throws IOException {
        ObjectNode body = validBody();
        ((ObjectNode) body.withArray("refData").get(1)).put("major_creditor_id", id);
        assertInvalid(body.toString());
    }

    @ParameterizedTest
    @ValueSource(strings = {"-1", "1", "3", "2.0", "\"2\"", "null", "2147483648"})
    void rejectsInvalidOrMismatchedCount(String count) throws IOException {
        ObjectNode body = validBody();
        body.set("count", MAPPER.readTree(count));
        assertInvalid(body.toString());
    }

    @ParameterizedTest
    @ValueSource(strings = {"active", "central_authority"})
    void rejectsIncorrectFilterFlags(String field) throws IOException {
        ObjectNode body = validBody();
        ((ObjectNode) body.withArray("refData").get(0)).put(field, field.equals("central_authority"));
        assertInvalid(body.toString());
    }

    @ParameterizedTest
    @ValueSource(strings = {"active", "central_authority"})
    void rejectsStringFilterFlags(String field) throws IOException {
        ObjectNode body = validBody();
        ((ObjectNode) body.withArray("refData").get(0)).put(field, field.equals("active") ? "true" : "false");
        assertInvalid(body.toString());
    }

    @Test
    void rejectsWrongOwningUnit() throws IOException {
        ObjectNode body = validBody();
        ((ObjectNode) body.withArray("refData").get(0)).put("business_unit_id", 31011);
        assertInvalid(body.toString());
    }

    @ParameterizedTest
    @ValueSource(strings = {"major_creditor_code", "name", "address_line_1", "contact_name", "contact_email",
        "country_id", "country_name"})
    void rejectsChangedBusinessDetails(String field) throws IOException {
        ObjectNode body = validBody();
        ((ObjectNode) body.withArray("refData").get(0)).put(field, "changed");
        assertInvalid(body.toString());
    }

    @Test
    void rejectsInvalidReferenceDataShape() {
        assertInvalid("{\"count\":2,\"refData\":{}}");
    }

    @Test
    void requiresRequestStateBeforeThenAssertions() {
        MajorCreditorsStepDef steps = new MajorCreditorsStepDef();
        assertThrows(IllegalStateException.class, steps::assertActiveMajorCreditors);
        assertThrows(IllegalStateException.class, steps::assertValidationResponse);
        assertThrows(IllegalStateException.class, steps::assertUnauthorizedResponse);
    }

    @Test
    void requiresFixtureBeforeSuccessRequest() {
        assertThrows(IllegalStateException.class, new MajorCreditorsStepDef()::requestActiveMajorCreditors);
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

    private void assertInvalid(String body) {
        assertThrows(AssertionError.class, () -> MajorCreditorsStepDef.assertActiveResponse(body, EXPECTED));
    }

    private ObjectNode validBody() throws IOException {
        return (ObjectNode) MAPPER.readTree("""
            {"count":2,"refData":[
              {"major_creditor_id":101,"business_unit_id":31010,"major_creditor_code":"F001",
               "name":"Synthetic Creditor Alpha","address_line_1":"Synthetic address Alpha",
               "contact_name":"Synthetic Contact Alpha","contact_email":"alpha@example.invalid",
               "country_id":9000101,"country_name":"Synthetic Functional Country",
               "active":true,"central_authority":false},
              {"major_creditor_id":102,"business_unit_id":31010,"major_creditor_code":"F002",
               "name":"Synthetic Creditor Beta","address_line_1":"Synthetic address Beta",
               "contact_name":null,"contact_email":null,"country_id":null,"country_name":null,
               "active":true,"central_authority":false}
            ]}
            """);
    }
}
