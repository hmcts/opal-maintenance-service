package uk.gov.hmcts.opal.assertions;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import io.restassured.builder.ResponseBuilder;
import io.restassured.response.Response;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertThrows;

class DraftCasefileAssertionsTest {

    private static final String MARKER = "PO10287-550e8400-e29b-41d4-a716-446655440000";
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
    private static final String METADATA_BODY = """
        {"draft_casefile_id":123,"business_unit_id":44,"submitted_by":"L044JG",
         "created_date":"2026-10-16T10:00:00Z","casefile_status":"SUBMITTED",
         "casefile_status_date":"2026-10-16T10:00:00Z","version_number":0,
         "snapshot_present":true,"timeline_entry_count":1,"timeline_statuses":["Submitted"]}
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
    void acceptsTechnicalMetadataAndRejectsPayloadLeakage() throws Exception {
        DraftCasefileAssertions.assertTechnicalMetadata(metadata(METADATA_BODY), created());
        assertThrows(AssertionError.class, () -> DraftCasefileAssertions.assertTechnicalMetadata(
            metadata(METADATA_BODY.replace("}", ",\"casefile\":{}}")), created()));
        assertThrows(AssertionError.class, () -> DraftCasefileAssertions.assertTechnicalMetadata(
            metadata(METADATA_BODY.replace("}", ",\"marker\":\"" + MARKER + "\"}")), created()));
        assertThrows(AssertionError.class, () -> DraftCasefileAssertions.assertTechnicalMetadata(
            metadata(METADATA_BODY.replace("10:00:00Z", "10:00:01Z")), created()));
        assertThrows(AssertionError.class, () -> DraftCasefileAssertions.assertTechnicalMetadata(
            metadata(METADATA_BODY.replace("\"version_number\":0", "\"version_number\":1")), created()));
        assertThrows(AssertionError.class, () -> DraftCasefileAssertions.assertTechnicalMetadata(
            metadata(METADATA_BODY.replace("\"timeline_statuses\":[\"Submitted\"]",
                "\"timeline_statuses\":[\"Created\"]")), created()));
    }

    @Test
    void requiresSafeCorrelatedPermissionReferenceAndFailureProblems() throws Exception {
        assertSafeProblem(403, DraftCasefileAssertions::assertPermissionProblem);
        assertSafeProblem(400, DraftCasefileAssertions::assertReferenceProblem);
        assertSafeProblem(500, DraftCasefileAssertions::assertFailureProblem);
    }

    @Test
    void acceptsZeroMatchesAndSuccessfulCleanup() throws Exception {
        DraftCasefileAssertions.assertNoMarkerMatches(response(200, "application/json",
            "{\"count\":0,\"draft_casefile_ids\":[]}", null, null));
        assertThrows(AssertionError.class, () -> DraftCasefileAssertions.assertNoMarkerMatches(
            response(200, "application/json", "{\"count\":1,\"draft_casefile_ids\":[123]}", null, null)));
        DraftCasefileAssertions.assertCleanup(response(204, null, "", null, null));
        assertThrows(AssertionError.class, () -> DraftCasefileAssertions.assertCleanup(
            response(500, "application/problem+json", "{}", null, null)));
    }

    private void assertSafeProblem(int status, ProblemCheck check) throws Exception {
        String detail = switch (status) {
            case 403 -> "You do not have permission to access this resource";
            case 400 -> "An error occurred while processing your request";
            default -> "An unexpected error occurred while processing your request";
        };
        assertSafeProblem(status, check, detail);
    }

    private void assertSafeProblem(int status, ProblemCheck check, String detail) throws Exception {
        String type = switch (status) {
            case 403 -> "forbidden";
            case 400 -> "opal-api-error";
            default -> "internal-server-error";
        };
        String title = switch (status) {
            case 403 -> "Forbidden";
            case 400 -> "Bad Request";
            default -> "Internal Server Error";
        };
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

    private Response metadata(String body) {
        return response(200, "application/json", body, null, null);
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
