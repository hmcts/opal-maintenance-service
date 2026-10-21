package uk.gov.hmcts.opal.assertions;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertThrows;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import io.restassured.builder.ResponseBuilder;
import io.restassured.response.Response;
import org.junit.jupiter.api.Test;

class DraftCasefileAssertionsTest {

    private static final String MARKER = "E2E-550e8400e29b41d4";
    private static final String CREATED_BODY = """
        {"draft_casefile_id":123,"business_unit_id":44,"created_date":"2026-10-16T10:00:00Z",
         "submitted_by":"L044JG","submitted_by_name":"Synthetic Test User",
         "casefile_snapshot":{"respondent_account":{"account_id":null,"account_number":null,
             "respondent_name":"RESPONDENT, Synthetic"},
           "applicant_account":{"account_id":null,"account_number":null,
             "applicant_name":"APPLICANT, Synthetic"},"minor_creditor_accounts":[]},
         "casefile_type":"REMO In","casefile_status":"SUBMITTED",
         "casefile_status_date":"2026-10-16T10:00:00Z",
         "timeline_data":[{"username":"Synthetic Test User","status":"Submitted",
           "status_date":"2026-10-16T10:00:00Z"}]}
        """;

    @Test
    void acceptsCreatedResponseAndRejectsMissingEtagOrUnexpectedLocation() throws Exception {
        Response created = created();
        assertThat(DraftCasefileAssertions.assertCreated(created)).isEqualTo(123L);
        assertThrows(AssertionError.class, () -> DraftCasefileAssertions.assertCreated(
            response(201, "application/json", CREATED_BODY, null, null)));
        assertThrows(AssertionError.class, () -> DraftCasefileAssertions.assertCreated(
            response(201, "application/json", CREATED_BODY, "\"0\"", "/draft-casefiles/123")));
        assertThrows(AssertionError.class, () -> DraftCasefileAssertions.assertCreated(
            response(201, "application/json", "{\"draft_casefile_id\":123}", "\"0\"", null)));
        assertThrows(AssertionError.class, () -> DraftCasefileAssertions.assertCreated(
            response(201, "application/json", CREATED_BODY.replace("SUBMITTED", "DRAFT"), "\"0\"", null)));
        ObjectNode withoutSnapshot = (ObjectNode) new ObjectMapper().readTree(CREATED_BODY);
        withoutSnapshot.putNull("casefile_snapshot");
        assertThrows(AssertionError.class, () -> DraftCasefileAssertions.assertCreated(
            response(201, "application/json", withoutSnapshot.toString(), "\"0\"", null)));
        assertThrows(AssertionError.class, () -> DraftCasefileAssertions.assertCreated(
            response(201, "application/json", CREATED_BODY.replace("\"status\":\"Submitted\"",
                "\"status\":\"Created\""), "\"0\"", null)));
    }

    @Test
    void requiresSafeCorrelatedPermissionAndReferenceProblems() throws Exception {
        assertSafeProblem(403, DraftCasefileAssertions::assertPermissionProblem);
        assertSafeProblem(400, DraftCasefileAssertions::assertReferenceProblem);
    }

    @Test
    void acceptsSuccessfulCleanupAndRejectsFailure() {
        DraftCasefileAssertions.assertCleanup(response(204, null, "", null, null));
        assertThrows(AssertionError.class, () -> DraftCasefileAssertions.assertCleanup(
            response(500, "application/problem+json", "{}", null, null)));
    }

    private void assertSafeProblem(int status, ProblemCheck check) throws Exception {
        String detail = status == 403 ? "You do not have permission to access this resource"
            : "An error occurred while processing your request";
        String type = status == 403 ? "forbidden" : "opal-api-error";
        String title = status == 403 ? "Forbidden" : "Bad Request";
        String safe = """
            {"type":"https://hmcts.gov.uk/problems/%s","title":"%s","detail":"%s","status":%d,
             "retriable":false,"operation_id":"op-123",
             "instance":"https://hmcts.gov.uk/problems/instance/op-123"}
            """.formatted(type, title, detail, status);
        check.verify(response(status, "application/problem+json", safe, null, null), MARKER);
        assertThrows(AssertionError.class, () -> check.verify(
            response(status, "application/problem+json", safe.replace("op-123", MARKER), null, null), MARKER));
        assertThrows(AssertionError.class, () -> check.verify(
            response(status, "application/json", safe, null, null), MARKER));
        assertThrows(AssertionError.class, () -> check.verify(
            response(status, "application/problem+json", safe.replace("false", "true"), null, null), MARKER));
        assertThrows(AssertionError.class, () -> check.verify(
            response(status, "application/problem+json", safe.replace(",\"operation_id\":\"op-123\"", ""),
                null, null), MARKER));
        assertThrows(AssertionError.class, () -> check.verify(
            response(status, "application/problem+json", safe.replace(detail, "Synthetic address"),
                null, null), MARKER));
        assertThrows(AssertionError.class, () -> check.verify(
            response(status, "application/problem+json", safe.replace(detail, "A different public error"),
                null, null), MARKER));
        assertThrows(AssertionError.class, () -> check.verify(
            response(status, "application/problem+json", safe.replace("instance/op-123", "instance/other"),
                null, null), MARKER));
    }

    private Response created() {
        return response(201, "application/json", CREATED_BODY, "\"0\"", null);
    }

    private Response response(int status, String contentType, String body, String etag, String location) {
        ResponseBuilder builder = new ResponseBuilder().setStatusCode(status).setBody(body);
        if (contentType != null) {
            builder.setContentType(contentType);
        }
        if (etag != null) {
            builder.setHeader("ETag", etag);
        }
        if (location != null) {
            builder.setHeader("Location", location);
        }
        return builder.build();
    }

    @FunctionalInterface
    private interface ProblemCheck {
        void verify(Response response, String marker) throws Exception;
    }
}
