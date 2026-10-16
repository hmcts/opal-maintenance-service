package uk.gov.hmcts.opal.assertions;

import io.restassured.builder.ResponseBuilder;
import io.restassured.response.Response;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertThrows;

class DraftCasefileAssertionsTest {

    private static final String MARKER = "PO10287-550e8400-e29b-41d4-a716-446655440000";

    @Test
    void acceptsCreatedResponseAndRejectsMissingEtagOrUnexpectedLocation() throws Exception {
        Response created = response(201, "application/json", "{\"draft_casefile_id\":123}", "\"0\"", null);
        assertThat(DraftCasefileAssertions.assertCreated(created)).isEqualTo(123L);
        assertThrows(AssertionError.class, () -> DraftCasefileAssertions.assertCreated(
            response(201, "application/json", "{\"draft_casefile_id\":123}", null, null)));
        assertThrows(AssertionError.class, () -> DraftCasefileAssertions.assertCreated(
            response(201, "application/json", "{\"draft_casefile_id\":123}", "\"0\"", "/draft-casefiles/123")));
    }

    @Test
    void acceptsTechnicalMetadataAndRejectsPayloadLeakage() throws Exception {
        String metadata = """
            {"draft_casefile_id":123,"business_unit_id":44,"submitted_by":"L044JG",
             "created_date":"2026-10-16T10:00:00Z","casefile_status":"SUBMITTED",
             "casefile_status_date":"2026-10-16T10:00:00Z","version_number":0,
             "snapshot_present":true,"timeline_entry_count":1,"timeline_statuses":["Submitted"]}
            """;
        DraftCasefileAssertions.assertTechnicalMetadata(response(200, "application/json", metadata, null, null), 123);
        assertThrows(AssertionError.class, () -> DraftCasefileAssertions.assertTechnicalMetadata(
            response(200, "application/json", metadata.replace("}", ",\"casefile\":{}}"), null, null), 123));
        assertThrows(AssertionError.class, () -> DraftCasefileAssertions.assertTechnicalMetadata(
            response(200, "application/json", metadata.replace("}", ",\"marker\":\"" + MARKER + "\"}"),
                null, null), 123));
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
        String safe = """
            {"type":"about:blank","title":"Error","detail":"Request failed","status":%d,
             "retriable":false,"operation_id":"op-123"}
            """.formatted(status);
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
            response(status, "application/problem+json", safe.replace("Request failed", "Synthetic address"),
                null, null), MARKER));
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
