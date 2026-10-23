package uk.gov.hmcts.opal.assertions;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import io.restassured.builder.ResponseBuilder;
import io.restassured.response.Response;
import org.junit.jupiter.api.Test;
import uk.gov.hmcts.opal.data.DraftCasefileRequestFactory;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;

class DraftCasefileRetrievalAssertionsTest {
    private static final ObjectMapper JSON = new ObjectMapper();
    private static final String MARKER = "E2E-550e8400e29b41d4";
    private static final String DATE = "2026-10-23T10:00:00Z";
    private final DraftCasefileRequestFactory factory = new DraftCasefileRequestFactory();

    @Test
    void submittedMatchesCompleteRequestAndPost() throws Exception {
        ObjectNode submitted = submitted();
        assertDoesNotThrow(() -> DraftCasefileRetrievalAssertions.submitted(response(submitted),
            factory.withMinorCreditors(MARKER), created(submitted)));
    }

    @Test
    void wrongRequestFailsWithoutPayloadDiagnostics() throws Exception {
        ObjectNode submitted = submitted();
        assertThrows(AssertionError.class, () -> DraftCasefileRetrievalAssertions.submitted(response(submitted),
            factory.withMinorCreditors("E2E-0000000000000000"), created(submitted)));
    }

    @Test
    void approvedAppendsExactlyOneCorrelatedEvent() throws Exception {
        assertDoesNotThrow(() -> DraftCasefileRetrievalAssertions.approved(response(approved()), submitted()));
    }

    @Test
    void publishedAcceptsReorderedMinorsAndSeparateIdentityDomains() throws Exception {
        ObjectNode published = published();
        ArrayNode minors = (ArrayNode) published.at("/casefile_snapshot/minor_creditor_accounts");
        JsonNode first = minors.remove(0);
        minors.add(first);
        assertDoesNotThrow(() -> DraftCasefileRetrievalAssertions.published(response(published), approved()));
    }

    @Test
    void failedRetainsApprovalAndExplicitNullIdentities() throws Exception {
        assertDoesNotThrow(() -> DraftCasefileRetrievalAssertions.failed(response(failed()), approved()));
    }

    @Test
    void missingApplicantAndMissingCreditorFail() throws Exception {
        ObjectNode noApplicant = published();
        ((ObjectNode) noApplicant.path("casefile_snapshot")).remove("applicant_account");
        rejectsPublished(noApplicant);
        ObjectNode noCreditor = published();
        ((ArrayNode) noCreditor.at("/casefile_snapshot/minor_creditor_accounts")).remove(1);
        rejectsPublished(noCreditor);
    }

    @Test
    void duplicateSequenceAndCreditorIdentityFail() throws Exception {
        ObjectNode duplicate = published();
        ((ObjectNode) duplicate.at("/casefile_snapshot/minor_creditor_accounts/1")).put("creditor_sequence", 7);
        rejectsPublished(duplicate);
        duplicate = published();
        ((ObjectNode) duplicate.at("/casefile_snapshot/minor_creditor_accounts/1")).put("account_id", 102);
        rejectsPublished(duplicate);
        duplicate = published();
        ((ObjectNode) duplicate.at("/casefile_snapshot/minor_creditor_accounts/1")).put("account_number", "C102");
        rejectsPublished(duplicate);
    }

    @Test
    void missingNullIdentityFailsForSubmittedAndFailed() throws Exception {
        ObjectNode submitted = submitted();
        ((ObjectNode) submitted.at("/casefile_snapshot/applicant_account")).remove("account_id");
        assertThrows(AssertionError.class, () -> DraftCasefileRetrievalAssertions.submitted(response(submitted),
            factory.withMinorCreditors(MARKER), created(submitted)));
        ObjectNode failed = failed();
        ((ObjectNode) failed.at("/casefile_snapshot/minor_creditor_accounts/0")).remove("account_number");
        assertThrows(AssertionError.class, () -> DraftCasefileRetrievalAssertions.failed(response(failed), approved()));
    }

    @Test
    void publicationEventAndChangedValidationDateFail() throws Exception {
        ObjectNode extraEvent = published();
        ((ArrayNode) extraEvent.path("timeline_data")).addObject().put("status", "Published");
        rejectsPublished(extraEvent);
        ObjectNode changed = published();
        changed.put("validated_date", "2026-10-24T11:00:00Z");
        rejectsPublished(changed);
    }

    @Test
    void readRejectsWeakOverflowAndMissingEtags() throws Exception {
        for (String etag : new String[] {"W/\"1\"", "1", "\"-1\"", "\"9223372036854775808\"", ""}) {
            Response response = new ResponseBuilder().setStatusCode(200).setContentType("application/json")
                .setHeader("ETag", etag).setBody(submitted().toString()).build();
            assertThrows(AssertionError.class, () -> DraftCasefileRetrievalAssertions.read(response));
        }
        assertDoesNotThrow(() -> DraftCasefileRetrievalAssertions.read(response(submitted())));
    }

    @Test
    void safeMissingAndDeniedProblemsAreAccepted() throws Exception {
        assertDoesNotThrow(() -> DraftCasefileRetrievalAssertions.safeProblem(problem(404, null), 404, MARKER));
        assertDoesNotThrow(() -> DraftCasefileRetrievalAssertions.safeProblem(problem(403, null), 403, MARKER));
    }

    @Test
    void problemMarkerPayloadAndNestedIdentitiesFailSafely() throws Exception {
        for (String leak : new String[] {"\"extra\":\"" + MARKER + "\"",
            "\"nested\":{\"casefile\":{}}", "\"nested\":{\"account_id\":123}",
            "\"extra\":\"MinorTwentyThree\"", "\"stack_trace\":\"secret\""}) {
            assertThrows(AssertionError.class,
                () -> DraftCasefileRetrievalAssertions.safeProblem(problem(404, leak), 404, MARKER));
        }
    }

    @Test
    void identitiesCannotBeInventedAtTheSnapshotRoot() throws Exception {
        ObjectNode value = published();
        ((ObjectNode) value.path("casefile_snapshot")).put("account_id", 999);
        rejectsPublished(value);
    }

    @Test
    void missingProblemRequiresTheActualSafeReason() throws Exception {
        ObjectNode body = (ObjectNode) JSON.readTree(problem(404, null).asString());
        body.remove("reason");
        Response missingReason = new ResponseBuilder().setStatusCode(404)
            .setContentType("application/problem+json").setBody(body.toString()).build();
        assertThrows(AssertionError.class,
            () -> DraftCasefileRetrievalAssertions.safeProblem(missingReason, 404, MARKER));
    }

    @Test
    void invalidDateAndJsonDiagnosticsDoNotExposePrivateValues() throws Exception {
        ObjectNode value = approved().put("validated_date", MARKER);
        AssertionError dateFailure = assertThrows(AssertionError.class,
            () -> DraftCasefileRetrievalAssertions.approved(response(value), submitted()));
        org.junit.jupiter.api.Assertions.assertFalse(dateFailure.toString().contains(MARKER));
        org.junit.jupiter.api.Assertions.assertNull(dateFailure.getCause());
        Response invalid = new ResponseBuilder().setStatusCode(200).setContentType("application/json")
            .setHeader("ETag", "\"1\"").setBody("{\"private\":\"" + MARKER).build();
        AssertionError jsonFailure = assertThrows(AssertionError.class,
            () -> DraftCasefileRetrievalAssertions.read(invalid));
        org.junit.jupiter.api.Assertions.assertFalse(jsonFailure.toString().contains(MARKER));
        org.junit.jupiter.api.Assertions.assertNull(jsonFailure.getCause());
    }

    private JsonNode created(ObjectNode submitted) {
        ObjectNode created = submitted.deepCopy();
        created.remove("casefile");
        return created;
    }

    private void rejectsPublished(ObjectNode value) {
        assertThrows(AssertionError.class,
            () -> DraftCasefileRetrievalAssertions.published(response(value), approved()));
    }

    private ObjectNode submitted() throws Exception {
        ObjectNode root = JSON.createObjectNode();
        root.put("draft_casefile_id", 123).put("business_unit_id", 44).put("created_date", DATE)
            .put("submitted_by", "L044JG").put("submitted_by_name", "Synthetic Inputter")
            .put("casefile_type", "REMO In").put("casefile_status", "SUBMITTED").put("casefile_status_date", DATE);
        root.set("casefile", JSON.readTree(factory.withMinorCreditors(MARKER)).path("casefile"));
        ObjectNode snapshot = root.putObject("casefile_snapshot");
        account(snapshot.putObject("respondent_account"), "respondent_name", "RESPONDENT, Synthetic");
        account(snapshot.putObject("applicant_account"), "applicant_name", "APPLICANT, Synthetic");
        ArrayNode minors = snapshot.putArray("minor_creditor_accounts");
        account(minors.addObject().put("creditor_sequence", 7), "name", "MINORSEVEN, Synthetic");
        account(minors.addObject().put("creditor_sequence", 23), "name", "MINORTWENTYTHREE, Synthetic");
        root.putArray("timeline_data").addObject().put("status", "Submitted")
            .put("status_date", DATE).put("username", "Synthetic Inputter");
        return root;
    }

    private ObjectNode approved() throws Exception {
        ObjectNode root = submitted();
        root.put("casefile_status", "PUBLISHING_PENDING").put("casefile_status_date", "2026-10-23T11:00:00Z")
            .put("validated_date", "2026-10-23T11:00:00Z").put("validated_by", "L044CK")
            .put("validated_by_name", "Synthetic Checker");
        ((ArrayNode) root.path("timeline_data")).addObject().put("status", "Approved")
            .put("status_date", "2026-10-23T11:00:00Z").put("username", "Synthetic Checker");
        return root;
    }

    private ObjectNode published() throws Exception {
        ObjectNode root = approved();
        root.put("casefile_status", "PUBLISHED");
        identity((ObjectNode) root.at("/casefile_snapshot/respondent_account"), 101, "R101");
        identity((ObjectNode) root.at("/casefile_snapshot/applicant_account"), 101, "C101");
        identity((ObjectNode) root.at("/casefile_snapshot/minor_creditor_accounts/0"), 102, "C102");
        identity((ObjectNode) root.at("/casefile_snapshot/minor_creditor_accounts/1"), 103, "C103");
        return root;
    }

    private ObjectNode failed() throws Exception {
        return approved().put("casefile_status", "PUBLISHING_FAILED").put("status_message", "Publication unsuccessful");
    }

    private void account(ObjectNode node, String field, String name) {
        node.putNull("account_id").putNull("account_number").put(field, name);
    }

    private void identity(ObjectNode node, long id, String number) {
        node.put("account_id", id).put("account_number", number);
    }

    private Response response(JsonNode root) {
        return new ResponseBuilder().setStatusCode(200).setContentType("application/json")
            .setHeader("ETag", "\"2\"").setBody(root.toString()).build();
    }

    private Response problem(int status, String extra) {
        String type = status == 403 ? "forbidden" : "entity-not-found";
        String title = status == 403 ? "Forbidden" : "Entity Not Found";
        String detail = status == 403 ? "You do not have permission to access this resource"
            : "The requested entity could not be found";
        ObjectNode body = JSON.createObjectNode().put("type", "https://hmcts.gov.uk/problems/" + type)
            .put("title", title).put("detail", detail).put("status", status).put("retriable", false)
            .put("operation_id", "550e8400-e29b-41d4-a716-446655440000")
            .put("instance", "https://hmcts.gov.uk/problems/instance/550e8400-e29b-41d4-a716-446655440000");
        if (status == 404) {
            body.put("reason", "Draft Casefile not found");
        }
        String raw = body.toString();
        if (extra != null) {
            raw = raw.substring(0, raw.length() - 1) + "," + extra + "}";
        }
        return new ResponseBuilder().setStatusCode(status).setContentType("application/problem+json")
            .setBody(raw).build();
    }
}
