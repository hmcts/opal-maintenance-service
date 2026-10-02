package uk.gov.hmcts.opal.steps;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;

import io.restassured.builder.ResponseBuilder;
import io.restassured.response.Response;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import java.util.List;

class MajorCreditorsStepDefTest {
    @Test
    void acceptsEmptySeededSelection() {
        assertDoesNotThrow(() -> MajorCreditorsStepDef.assertEmptyResponse(
            "{\"count\":0,\"refData\":[]}"));
    }

    @ParameterizedTest
    @ValueSource(strings = {
        "{}", "{\"count\":\"0\",\"refData\":[]}",
        "{\"count\":0.0,\"refData\":[]}", "{\"count\":0,\"refData\":{}}",
        "{\"count\":1,\"refData\":[]}", "{\"count\":0,\"refData\":[{}]}",
        "{\"count\":1,\"refData\":[{}]}"
    })
    void rejectsNonemptyOrMalformedEmptySelection(String body) {
        assertThrows(AssertionError.class, () -> MajorCreditorsStepDef.assertEmptyResponse(body));
    }

    @Test
    void requiresRequestStateBeforeThenAssertions() {
        MajorCreditorsStepDef steps = new MajorCreditorsStepDef();
        assertThrows(IllegalStateException.class, steps::assertEmptyMajorCreditors);
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

}
