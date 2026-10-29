package uk.gov.hmcts.opal.assertions;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import io.restassured.builder.ResponseBuilder;
import io.restassured.response.Response;
import java.util.function.Consumer;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.function.Executable;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import uk.gov.hmcts.opal.data.DraftCasefileRequestFactory;

class DraftCasefileDecisionAssertionsTest {
    private static final ObjectMapper JSON = new ObjectMapper();
    private static final String MARKER = "E2E-550e8400e29b41d4";
    private static final String CREATED = "2026-10-23T10:00:00Z";
    private static final String DECIDED = "2026-10-23T11:00:00Z";
    private static final String CHECKER = "L044CK";
    private static final String NAME = "Synthetic Checker";
    private static final String REASON = "Synthetic decision reason";

    @ParameterizedTest
    @ValueSource(strings = {"PUBLISHING_PENDING", "REJECTED", "DELETED"})
    void acceptsCompleteDecisionAndPreservesSubmittedBody(String target) throws Exception {
        assertDoesNotThrow(() -> decide(decision(target), target));
    }

    @Test
    void approvalRequiresAuthenticatedActorEvenWhenNamesDiffer() throws Exception {
        rejectMutation("PUBLISHING_PENDING", node -> node.put("validated_by", "L044OTHER"));
        rejectMutation("PUBLISHING_PENDING", node -> node.put("validated_by_name", "Other Checker"));
        ObjectNode before = submitted().put("submitted_by_name", NAME);
        ObjectNode after = decision("PUBLISHING_PENDING");
        after.put("submitted_by_name", NAME);
        assertDoesNotThrow(() -> DraftCasefileDecisionAssertions.decided(response(after, "\"2\""), before,
            "PUBLISHING_PENDING", null, CHECKER, NAME));
    }

    @ParameterizedTest
    @ValueSource(strings = {"PUBLISHING_PENDING", "REJECTED", "DELETED"})
    void rejectsChangedImmutableFieldsContentSnapshotAndHistory(String target) throws Exception {
        for (String field : new String[] {"draft_casefile_id", "business_unit_id", "created_date", "submitted_by",
            "submitted_by_name", "casefile_type"}) {
            rejectMutation(target, node -> node.put(field, "private-mutation"));
        }
        rejectMutation(target, node -> ((ObjectNode) node.path("casefile")).put("private", MARKER));
        rejectMutation(target, node -> ((ObjectNode) node.path("casefile_snapshot")).put("private", MARKER));
        rejectMutation(target, node -> ((ObjectNode) node.at("/timeline_data/0")).put("username", "changed"));
        rejectMutation(target, node -> ((ArrayNode) node.path("timeline_data")).addObject().put("status", "extra"));
    }

    @ParameterizedTest
    @ValueSource(strings = {"REJECTED", "DELETED"})
    void rejectsChangedValidationAndMissingOrWrongReasonActorAndEvent(String target) throws Exception {
        for (String field : new String[] {"validated_by", "validated_by_name", "validated_date"}) {
            rejectMutation(target, node -> node.put(field, "changed"));
        }
        rejectMutation(target, node -> node.remove("status_message"));
        rejectMutation(target, node -> node.put("status_message", "wrong reason"));
        rejectMutation(target, node -> ((ObjectNode) node.at("/timeline_data/1")).remove("reason_text"));
        rejectMutation(target, node -> ((ObjectNode) node.at("/timeline_data/1")).put("reason_text", "wrong reason"));
        rejectMutation(target, node -> ((ObjectNode) node.at("/timeline_data/1")).put("username", "Other Checker"));
        rejectMutation(target, node -> ((ArrayNode) node.path("timeline_data")).remove(1));
    }

    @ParameterizedTest
    @ValueSource(strings = {"REJECTED", "DELETED"})
    void synchronousDecisionsRetainExistingValidationMetadata(String target) throws Exception {
        ObjectNode before = submitted().put("validated_by", "L044PREVIOUS")
            .put("validated_by_name", "Synthetic Previous Checker").put("validated_date", CREATED);
        ObjectNode after = decision(target);
        for (String field : new String[] {"validated_by", "validated_by_name", "validated_date"}) {
            after.set(field, before.path(field));
        }
        assertDoesNotThrow(() -> DraftCasefileDecisionAssertions.decided(response(after, "\"2\""), before,
            target, REASON, CHECKER, NAME));
        after.put("validated_by", CHECKER);
        assertSafe(() -> DraftCasefileDecisionAssertions.decided(response(after, "\"2\""), before,
            target, REASON, CHECKER, NAME));
    }

    @Test
    void approvalClearsStatusMessageAndHasNoEventReason() throws Exception {
        rejectMutation("PUBLISHING_PENDING", node -> node.put("status_message", REASON));
        rejectMutation("PUBLISHING_PENDING",
            node -> ((ObjectNode) node.at("/timeline_data/1")).put("reason_text", REASON));
    }

    @ParameterizedTest
    @ValueSource(strings = {"PUBLISHING_PENDING", "REJECTED", "DELETED"})
    void rejectsWrongStatusDatesAndEtags(String target) throws Exception {
        rejectMutation(target, node -> node.put("casefile_status", "SUBMITTED"));
        rejectMutation(target, node -> node.put("casefile_status_date", MARKER));
        rejectMutation(target, node -> node.put("casefile_status_date", "2026-10-22T10:00:00Z"));
        rejectMutation(target,
            node -> ((ObjectNode) node.at("/timeline_data/1")).put("status_date", CREATED));
        for (String etag : new String[] {"W/\"2\"", "2", "\"-1\"", "\"9223372036854775808\"", ""}) {
            assertThrows(AssertionError.class, () -> DraftCasefileDecisionAssertions.decided(
                response(decision(target), etag), submitted(), target, reason(target), CHECKER, NAME));
        }
        Response wrongStatus = new ResponseBuilder().setStatusCode(201).setContentType("application/json")
            .setHeader("ETag", "\"2\"").setBody(decision(target).toString()).build();
        assertThrows(AssertionError.class, () -> DraftCasefileDecisionAssertions.decided(
            wrongStatus, submitted(), target, reason(target), CHECKER, NAME));
    }

    @Test
    void comparesDatesAsInstants() throws Exception {
        ObjectNode after = decision("REJECTED");
        ((ObjectNode) after.at("/timeline_data/1")).put("status_date", "2026-10-23T12:00:00+01:00");
        assertDoesNotThrow(() -> decide(after, "REJECTED"));
    }

    @Test
    void unchangedRequiresEntireBodyAndSameEtag() throws Exception {
        ObjectNode before = submitted();
        assertDoesNotThrow(() -> DraftCasefileDecisionAssertions.unchanged(response(before, "\"2\""), before, "\"2\""));
        ObjectNode mutated = before.deepCopy();
        mutated.putObject("unrelated").put("private", MARKER);
        assertThrows(AssertionError.class,
            () -> DraftCasefileDecisionAssertions.unchanged(response(mutated, "\"2\""), before, "\"2\""));
        assertThrows(AssertionError.class,
            () -> DraftCasefileDecisionAssertions.unchanged(response(before, "\"3\""), before, "\"2\""));
    }

    @Test
    void acceptsPendingOrFastTerminalApprovalReadback() throws Exception {
        ObjectNode approved = decision("PUBLISHING_PENDING");
        assertDoesNotThrow(() -> DraftCasefileDecisionAssertions.approvalPersisted(
            response(approved, "\"2\""), approved, "\"2\""));
        for (String target : new String[] {"PUBLISHED", "PUBLISHING_FAILED"}) {
            assertDoesNotThrow(() -> DraftCasefileDecisionAssertions.approvalPersisted(
                response(terminal(target), "\"3\""), approved, "\"2\""));
        }
    }

    @Test
    void readbackRejectsUnexpectedStateWrongVersionAndTerminalMutation() throws Exception {
        ObjectNode approved = decision("PUBLISHING_PENDING");
        for (String target : new String[] {"SUBMITTED", "REJECTED", "DELETED", "RESUBMITTED"}) {
            ObjectNode wrong = approved.deepCopy().put("casefile_status", target);
            assertThrows(AssertionError.class, () -> DraftCasefileDecisionAssertions.approvalPersisted(
                response(wrong, "\"3\""), approved, "\"2\""));
        }
        for (String etag : new String[] {"\"1\"", "\"2\"", "W/\"3\""}) {
            assertThrows(AssertionError.class, () -> DraftCasefileDecisionAssertions.approvalPersisted(
                response(terminal("PUBLISHED"), etag), approved, "\"2\""));
        }
        ObjectNode mutated = approved.deepCopy().put("validated_by", "wrong");
        assertThrows(AssertionError.class, () -> DraftCasefileDecisionAssertions.approvalPersisted(
            response(mutated, "\"2\""), approved, "\"2\""));
        ObjectNode terminal = terminal("PUBLISHED").put("validated_date", CREATED);
        assertThrows(AssertionError.class, () -> DraftCasefileDecisionAssertions.approvalPersisted(
            response(terminal, "\"3\""), approved, "\"2\""));
        ObjectNode noAccount = terminal("PUBLISHED");
        ((ObjectNode) noAccount.at("/casefile_snapshot/applicant_account")).remove("account_id");
        assertThrows(AssertionError.class, () -> DraftCasefileDecisionAssertions.approvalPersisted(
            response(noAccount, "\"3\""), approved, "\"2\""));
    }

    @ParameterizedTest
    @ValueSource(strings = {"forbidden", "optimistic-locking", "resource-conflict"})
    void acceptsOnlyExactSafeProblemCategory(String kind) {
        int status = "forbidden".equals(kind) ? 403 : 409;
        assertDoesNotThrow(() -> DraftCasefileDecisionAssertions.safeProblem(
            problem(kind, null), status, kind, MARKER));
        String other = "resource-conflict".equals(kind) ? "optimistic-locking" : "resource-conflict";
        assertThrows(AssertionError.class,
            () -> DraftCasefileDecisionAssertions.safeProblem(problem(other, null), status, kind, MARKER));
    }

    @ParameterizedTest
    @ValueSource(strings = {"forbidden", "optimistic-locking", "resource-conflict"})
    void rejectsMissingWrongTypedUncorrelatedAndUnsafeProblemFields(String kind) throws Exception {
        int status = "forbidden".equals(kind) ? 403 : 409;
        ObjectNode original = (ObjectNode) JSON.readTree(problem(kind, null).asString());
        for (String field : new String[] {"type", "title", "detail", "status", "retriable",
            "operation_id", "instance"}) {
            ObjectNode missing = original.deepCopy();
            missing.remove(field);
            assertSafeProblem(missing, status, kind);
            assertSafeProblem(original.deepCopy().put(field, MARKER), status, kind);
        }
        for (String operation : new String[] {"", " ", "\t"}) {
            ObjectNode blank = original.deepCopy().put("operation_id", operation)
                .put("instance", "https://hmcts.gov.uk/problems/instance/" + operation);
            assertSafeProblem(blank, status, kind);
        }
        assertSafeProblem(original.deepCopy().putNull("operation_id"), status, kind);
        assertSafeProblem(original.deepCopy().put("operation_id", 123), status, kind);
        assertSafeProblem(original.deepCopy().put("operation_id", true), status, kind);
        assertSafeProblem(original.deepCopy().put("retriable", true), status, kind);
        assertSafeProblem(original.deepCopy().put("status", status == 403 ? 409 : 403), status, kind);
        assertSafeProblem(original.deepCopy().put("status", (double) status), status, kind);
        assertSafeProblem(original.deepCopy().put("operation_id", "33e626552a324ac3ab9bc02588fd4fec"),
            status, kind);
        Response wrongType = new ResponseBuilder().clone(problem(kind, null))
            .setContentType("application/json").build();
        assertSafe(() -> DraftCasefileDecisionAssertions.safeProblem(wrongType, status, kind, MARKER));
    }

    private void assertSafeProblem(JsonNode body, int status, String kind) {
        Response response = new ResponseBuilder().setStatusCode(status).setContentType("application/problem+json")
            .setBody(body.toString()).build();
        assertSafe(() -> DraftCasefileDecisionAssertions.safeProblem(response, status, kind, MARKER));
    }

    @Test
    void rejectsExtraNestedPrivateDiagnosticFieldsAndSuccessHeaders() {
        for (String kind : new String[] {"forbidden", "optimistic-locking", "resource-conflict"}) {
            int status = "forbidden".equals(kind) ? 403 : 409;
            for (String extra : new String[] {"\"private\":\"" + MARKER + "\"", "\"nested\":{}",
                "\"exception\":\"diagnostic\""}) {
                assertSafe(() -> DraftCasefileDecisionAssertions.safeProblem(
                    problem(kind, extra), status, kind, MARKER));
            }
            for (String header : new String[] {"ETag", "Location"}) {
                Response invalid = new ResponseBuilder().clone(problem(kind, null))
                    .setHeader(header, "private").build();
                assertSafe(() -> DraftCasefileDecisionAssertions.safeProblem(invalid, status, kind, MARKER));
            }
        }
    }

    @ParameterizedTest
    @ValueSource(strings = {"", "{", "null", "[]", "{} {}", "{} E2E-550e8400e29b41d4"})
    void rejectsMalformedAndTrailingProblemWithoutPrivateDiagnostics(String body) {
        Response invalid = new ResponseBuilder().setStatusCode(409).setContentType("application/problem+json")
            .setBody(body).build();
        assertSafe(() -> DraftCasefileDecisionAssertions.safeProblem(invalid, 409, "resource-conflict", MARKER));
    }

    @Test
    void rejectsTrailingDecisionAndProblemPayloadsSafely() throws Exception {
        Response invalid = new ResponseBuilder().clone(response(decision("REJECTED"), "\"2\""))
            .setBody(decision("REJECTED") + " {\"private\":\"" + MARKER + "\"}").build();
        assertSafe(() -> DraftCasefileDecisionAssertions.decided(
            invalid, submitted(), "REJECTED", REASON, CHECKER, NAME));
        Response problem = new ResponseBuilder().clone(problem("optimistic-locking", null))
            .setBody(problem("optimistic-locking", null).asString() + " " + MARKER).build();
        assertSafe(() -> DraftCasefileDecisionAssertions.safeProblem(problem, 409, "optimistic-locking", MARKER));
    }

    private void assertSafe(Executable assertion) {
        AssertionError failure = assertThrows(AssertionError.class, assertion);
        assertFalse(failure.toString().contains(MARKER));
        assertFalse(failure.toString().contains(REASON));
        assertNull(failure.getCause());
    }

    private void rejectMutation(String target, Consumer<ObjectNode> mutation) throws Exception {
        ObjectNode body = decision(target);
        mutation.accept(body);
        assertSafe(() -> decide(body, target));
    }

    private JsonNode decide(ObjectNode body, String target) throws Exception {
        return DraftCasefileDecisionAssertions.decided(response(body, "\"2\""), submitted(), target,
            reason(target), CHECKER, NAME);
    }

    private String reason(String target) {
        return "PUBLISHING_PENDING".equals(target) ? null : REASON;
    }

    private ObjectNode submitted() throws Exception {
        ObjectNode root = JSON.createObjectNode().put("draft_casefile_id", 123).put("business_unit_id", 44)
            .put("created_date", CREATED).put("submitted_by", "L044JG").put("submitted_by_name", "Synthetic Inputter")
            .put("casefile_type", "REMO In").put("casefile_status", "SUBMITTED").put("casefile_status_date", CREATED);
        root.set("casefile", JSON.readTree(new DraftCasefileRequestFactory().withMinorCreditors(MARKER))
            .path("casefile"));
        ObjectNode snapshot = root.putObject("casefile_snapshot");
        account(snapshot.putObject("respondent_account"), "respondent_name", "RESPONDENT, Synthetic");
        account(snapshot.putObject("applicant_account"), "applicant_name", "APPLICANT, Synthetic");
        ArrayNode minors = snapshot.putArray("minor_creditor_accounts");
        account(minors.addObject().put("creditor_sequence", 7), "name", "MINORSEVEN, Synthetic");
        account(minors.addObject().put("creditor_sequence", 23), "name", "MINORTWENTYTHREE, Synthetic");
        root.putArray("timeline_data").addObject().put("status", "Submitted")
            .put("status_date", CREATED).put("username", "Synthetic Inputter");
        return root;
    }

    private ObjectNode decision(String target) throws Exception {
        ObjectNode root = submitted().put("casefile_status", target).put("casefile_status_date", DECIDED);
        String status = switch (target) {
            case "PUBLISHING_PENDING" -> "Approved";
            case "REJECTED" -> "Rejected";
            default -> "Deleted";
        };
        ObjectNode event = ((ArrayNode) root.path("timeline_data")).addObject().put("status", status)
            .put("status_date", DECIDED).put("username", NAME);
        if ("PUBLISHING_PENDING".equals(target)) {
            root.put("validated_date", DECIDED).put("validated_by", CHECKER).put("validated_by_name", NAME);
        } else {
            root.put("status_message", REASON);
            event.put("reason_text", REASON);
        }
        return root;
    }

    private ObjectNode terminal(String target) throws Exception {
        ObjectNode root = decision("PUBLISHING_PENDING").put("casefile_status", target);
        if ("PUBLISHING_FAILED".equals(target)) {
            root.put("status_message", "Publication unsuccessful");
        } else {
            identity((ObjectNode) root.at("/casefile_snapshot/respondent_account"), 101, "R101");
            identity((ObjectNode) root.at("/casefile_snapshot/applicant_account"), 101, "C101");
            identity((ObjectNode) root.at("/casefile_snapshot/minor_creditor_accounts/0"), 102, "C102");
            identity((ObjectNode) root.at("/casefile_snapshot/minor_creditor_accounts/1"), 103, "C103");
        }
        return root;
    }

    private void account(ObjectNode node, String key, String name) {
        node.putNull("account_id").putNull("account_number").put(key, name);
    }

    private void identity(ObjectNode node, long id, String number) {
        node.put("account_id", id).put("account_number", number);
    }

    private Response response(JsonNode body, String etag) {
        return new ResponseBuilder().setStatusCode(200).setContentType("application/json")
            .setHeader("ETag", etag).setBody(body.toString()).build();
    }

    private Response problem(String kind, String extra) {
        int status = "forbidden".equals(kind) ? 403 : 409;
        String detail = switch (kind) {
            case "forbidden" -> "You do not have permission to access this resource";
            case "optimistic-locking" -> "Conflict updating record. Please try again.";
            default -> "A conflict occurred with the requested resource";
        };
        ObjectNode root = JSON.createObjectNode().put("type", "https://hmcts.gov.uk/problems/" + kind)
            .put("title", status == 403 ? "Forbidden" : "Conflict").put("detail", detail).put("status", status)
            .put("retriable", false).put("operation_id", "23e626552a324ac3ab9bc02588fd4fec")
            .put("instance", "https://hmcts.gov.uk/problems/instance/23e626552a324ac3ab9bc02588fd4fec");
        String raw = root.toString();
        if (extra != null) {
            raw = raw.substring(0, raw.length() - 1) + "," + extra + "}";
        }
        return new ResponseBuilder().setStatusCode(status).setContentType("application/problem+json")
            .setBody(raw).build();
    }
}
