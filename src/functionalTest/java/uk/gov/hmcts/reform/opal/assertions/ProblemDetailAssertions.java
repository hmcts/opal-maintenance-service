package uk.gov.hmcts.reform.opal.assertions;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.restassured.response.Response;
import org.springframework.http.MediaType;

import java.io.IOException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

public final class ProblemDetailAssertions {

    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();

    private ProblemDetailAssertions() {
    }

    public static void assertProblemDetail(
        Response response,
        int status,
        String type,
        String title,
        String detail,
        String... requiredDynamicFields
    ) throws IOException {
        assertEquals(status, response.statusCode());
        String contentType = response.contentType();
        assertTrue(
            contentType != null && contentType.startsWith(MediaType.APPLICATION_PROBLEM_JSON_VALUE),
            "Expected application/problem+json but received " + contentType
        );

        JsonNode problem = OBJECT_MAPPER.readTree(response.asString());
        assertEquals(type, problem.path("type").asText());
        assertEquals(title, problem.path("title").asText());
        assertEquals(detail, problem.path("detail").asText());
        assertTrue(problem.path("status").isInt(), "Problem status field is missing or invalid");
        assertEquals(status, problem.path("status").asInt());
        assertTrue(problem.path("retriable").isBoolean(), "Problem retriable field is missing");
        assertFalse(problem.path("retriable").asBoolean(), "Problem must not be retriable");

        for (String field : requiredDynamicFields) {
            assertTrue(problem.path(field).isTextual(), "Problem field is missing or not textual: " + field);
            assertFalse(problem.path(field).asText().isBlank(), "Problem field is blank: " + field);
        }
    }
}
