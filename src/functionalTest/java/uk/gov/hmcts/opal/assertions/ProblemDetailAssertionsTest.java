package uk.gov.hmcts.opal.assertions;

import io.restassured.builder.ResponseBuilder;
import io.restassured.response.Response;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.http.MediaType;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static uk.gov.hmcts.opal.assertions.ProblemDetailAssertions.assertProblemDetail;

class ProblemDetailAssertionsTest {

    @Test
    void rejectsNonIntegerStatus() {
        Response response = response(
            MediaType.APPLICATION_PROBLEM_JSON_VALUE,
            """
                {
                  "type": "https://hmcts.gov.uk/problems/type-mismatch",
                  "title": "Not Acceptable",
                  "detail": "Invalid parameter value format",
                  "status": "406",
                  "retriable": false
                }
                """
        );

        assertThrows(AssertionError.class, () -> assertProblemDetail(
            response,
            406,
            "https://hmcts.gov.uk/problems/type-mismatch",
            "Not Acceptable",
            "Invalid parameter value format"
        ));
    }

    @ParameterizedTest
    @ValueSource(strings = {"123", "true"})
    void rejectsNonTextualDynamicField(String invalidValue) {
        Response response = response(
            MediaType.APPLICATION_PROBLEM_JSON_VALUE,
            """
                {
                  "type": "https://hmcts.gov.uk/problems/type-mismatch",
                  "title": "Not Acceptable",
                  "detail": "Invalid parameter value format",
                  "status": 406,
                  "retriable": false,
                  "instance": %s
                }
                """.formatted(invalidValue)
        );

        assertThrows(AssertionError.class, () -> assertProblemDetail(
            response,
            406,
            "https://hmcts.gov.uk/problems/type-mismatch",
            "Not Acceptable",
            "Invalid parameter value format",
            "instance"
        ));
    }

    @Test
    void rejectsMissingContentTypeWithObservedValue() {
        Response response = new ResponseBuilder()
            .setStatusCode(406)
            .setBody("{}")
            .build();

        AssertionError error = assertThrows(AssertionError.class, () -> assertProblemDetail(
            response,
            406,
            "https://hmcts.gov.uk/problems/type-mismatch",
            "Not Acceptable",
            "Invalid parameter value format"
        ));

        assertTrue(error.getMessage().contains("Expected application/problem+json but received null"));
    }

    private Response response(String contentType, String body) {
        return new ResponseBuilder()
            .setStatusCode(406)
            .setContentType(contentType)
            .setBody(body)
            .build();
    }
}
