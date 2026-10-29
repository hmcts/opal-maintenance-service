package uk.gov.hmcts.opal.assertions;

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

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

class DraftCasefileResubmissionAssertionsTest {
    private static final ObjectMapper JSON = new ObjectMapper();
    private static final String MARKER = "E2E-550e8400e29b41d4";
    private static final String CREATED = "2026-10-23T10:00:00Z";
    private static final String REJECTED = "2026-10-23T11:00:00Z";
    private static final String RESUBMITTED = "2026-10-23T12:00:00Z";
    private static final String ACTOR = "L044OTHER";
    private static final String NAME = "Synthetic Resubmitter";
    private static final String REASON = "Synthetic correction required";
    private static final String OPERATION = "550e8400-e29b-41d4-a716-446655440000";

    @ParameterizedTest
    @ValueSource(strings = {"L044JG", ACTOR})
    void acceptsSameAndDifferentAuthenticatedSubmitters(String actor) throws Exception {
        ObjectNode after = resubmitted().put("submitted_by", actor);
        JsonNode actual = DraftCasefileResubmissionAssertions.resubmitted(response(after), rejected(),
            replacement().toString(), actor, NAME);
        assertEquals(after, actual);
    }

    @ParameterizedTest
    @ValueSource(strings = {"respondent", "applicant", "minor"})
    void acceptsIndependentPartyCorrectionAndRetainsOtherMinor(String party) throws Exception {
        ObjectNode request = original();
        correct(request, party);
        ObjectNode after = resubmitted(request);
        assertEquals(rejected().at("/casefile/minor_creditors/1"), after.at("/casefile/minor_creditors/1"));
        assertEquals(after, DraftCasefileResubmissionAssertions.resubmitted(response(after), rejected(),
            request.toString(), ACTOR, NAME));
    }

    @Test
    void acceptsOrganisationAndSurnameOnlyDisplayNames() throws Exception {
        ObjectNode request = replacement();
        ObjectNode party = (ObjectNode) request.at("/casefile/applicant/party_details");
        party.remove("individual_details");
        party.put("organisation", true).putObject("organisation_details")
            .put("organisation_name", "Synthetic Corrected Organisation");
        ((ObjectNode) request.at("/casefile/minor_creditors/0/party_details/individual_details"))
            .put("surname", "i corrected").remove("forenames");
        ObjectNode after = resubmitted(request);
        ((ObjectNode) after.at("/casefile_snapshot/applicant_account"))
            .put("applicant_name", "Synthetic Corrected Organisation");
        ((ObjectNode) after.at("/casefile_snapshot/minor_creditor_accounts/0"))
            .put("name", "I CORRECTED");
        assertDoesNotThrow(() -> DraftCasefileResubmissionAssertions.resubmitted(response(after), rejected(),
            request.toString(), ACTOR, NAME));
    }

    @ParameterizedTest
    @ValueSource(strings = {"draft_casefile_id", "business_unit_id", "created_date", "casefile_type",
        "validated_date", "validated_by", "validated_by_name", "status_message", "stable_metadata"})
    void rejectsChangedAndMissingStableMetadata(String field) throws Exception {
        rejectMutation(node -> node.put(field, MARKER));
        rejectMutation(node -> node.remove(field));
    }

    @ParameterizedTest
    @ValueSource(strings = {"draft_casefile_id", "business_unit_id", "created_date", "casefile_type",
        "status_message"})
    void requiresStableFieldsEvenWhenMissingInBothBodies(String field) throws Exception {
        ObjectNode before = rejected();
        ObjectNode after = resubmitted();
        before.remove(field);
        after.remove(field);
        assertSafe(() -> DraftCasefileResubmissionAssertions.resubmitted(response(after), before,
            replacement().toString(), ACTOR, NAME));
    }

    @Test
    void preservesAbsentAndPopulatedOptionalValidation() throws Exception {
        for (boolean absent : new boolean[] {true, false}) {
            ObjectNode before = rejected();
            ObjectNode after = resubmitted();
            for (String field : new String[] {"validated_date", "validated_by", "validated_by_name"}) {
                if (absent) {
                    before.remove(field);
                    after.remove(field);
                } else {
                    String value = "validated_date".equals(field) ? CREATED : "Synthetic Previous Validator";
                    before.put(field, value);
                    after.put(field, value);
                }
            }
            assertDoesNotThrow(() -> DraftCasefileResubmissionAssertions.resubmitted(response(after), before,
                replacement().toString(), ACTOR, NAME));
            ObjectNode added = after.deepCopy().put("validated_by", ACTOR);
            assertSafe(() -> DraftCasefileResubmissionAssertions.resubmitted(response(added), before,
                replacement().toString(), ACTOR, NAME));
        }
    }

    @Test
    void rejectsAddedStableMetadataAndStaleActors() throws Exception {
        rejectMutation(node -> node.put("unexpected_metadata", "value"));
        rejectMutation(node -> node.put("submitted_by", "L044JG"));
        rejectMutation(node -> node.put("submitted_by_name", "Synthetic Inputter"));
        for (String actor : new String[] {"", " "}) {
            assertSafe(() -> DraftCasefileResubmissionAssertions.resubmitted(response(resubmitted()), rejected(),
                replacement().toString(), actor, NAME));
            assertSafe(() -> DraftCasefileResubmissionAssertions.resubmitted(response(resubmitted()), rejected(),
                replacement().toString(), ACTOR, actor));
        }
    }

    @ParameterizedTest
    @ValueSource(strings = {"casefile_status", "casefile_status_name"})
    void rejectsMissingAndWrongLifecycleLabels(String field) throws Exception {
        rejectMutation(node -> node.remove(field));
        rejectMutation(node -> node.put(field, "Rejected"));
        ObjectNode before = rejected().put(field, "Submitted");
        assertSafe(() -> DraftCasefileResubmissionAssertions.resubmitted(response(resubmitted()), before,
            replacement().toString(), ACTOR, NAME));
        before.remove(field);
        assertSafe(() -> DraftCasefileResubmissionAssertions.resubmitted(response(resubmitted()), before,
            replacement().toString(), ACTOR, NAME));
    }

    @Test
    void requiresCompleteRejectedBaselineAndHistoryActors() throws Exception {
        for (String field : new String[] {"submitted_by", "submitted_by_name"}) {
            ObjectNode before = rejected();
            before.remove(field);
            assertSafe(() -> DraftCasefileResubmissionAssertions.resubmitted(response(resubmitted()), before,
                replacement().toString(), ACTOR, NAME));
        }
        for (int index : new int[] {0, 1}) {
            ObjectNode before = rejected();
            ((ObjectNode) before.at("/timeline_data/" + index)).remove("username");
            ObjectNode after = resubmitted();
            ((ObjectNode) after.at("/timeline_data/" + index)).remove("username");
            assertSafe(() -> DraftCasefileResubmissionAssertions.resubmitted(response(after), before,
                replacement().toString(), ACTOR, NAME));
        }
    }

    @Test
    void rejectsStaleOrPartialCasefileAndMismatchedOwner() throws Exception {
        rejectMutation(node -> node.set("casefile", rejectedCasefile()));
        rejectMutation(node -> ((ObjectNode) node.at("/casefile/applicant/party_details/individual_details"))
            .put("surname", "Applicant"));
        rejectMutation(node -> ((ObjectNode) node.path("casefile")).remove("minor_creditors"));
        ObjectNode request = replacement().put("business_unit_id", 45);
        assertSafe(() -> DraftCasefileResubmissionAssertions.resubmitted(response(resubmitted()), rejected(),
            request.toString(), ACTOR, NAME));
        ObjectNode nestedOwner = replacement();
        ((ObjectNode) nestedOwner.at("/casefile/respondent_account")).put("business_unit_id", 45);
        assertSafe(() -> DraftCasefileResubmissionAssertions.resubmitted(response(resubmitted(nestedOwner)), rejected(),
            nestedOwner.toString(), ACTOR, NAME));
    }

    @ParameterizedTest
    @ValueSource(strings = {"business_unit_id", "casefile"})
    void requiresCompleteReplacementRequest(String field) throws Exception {
        ObjectNode request = replacement();
        request.remove(field);
        assertSafe(() -> DraftCasefileResubmissionAssertions.resubmitted(response(resubmitted()), rejected(),
            request.toString(), ACTOR, NAME));
        final String extra = replacement().put("submitted_by", ACTOR).toString();
        assertSafe(() -> DraftCasefileResubmissionAssertions.resubmitted(response(resubmitted()), rejected(),
            extra, ACTOR, NAME));
    }

    @ParameterizedTest
    @ValueSource(strings = {"respondent_account/respondent_name", "applicant_account/applicant_name",
        "minor_creditor_accounts/0/name", "minor_creditor_accounts/1/name"})
    void rejectsIncorrectOrMissingSnapshotNames(String path) throws Exception {
        int split = path.lastIndexOf('/');
        String parent = "/casefile_snapshot/" + path.substring(0, split);
        String field = path.substring(split + 1);
        rejectMutation(node -> ((ObjectNode) node.at(parent)).put(field, "STALE, Synthetic"));
        rejectMutation(node -> ((ObjectNode) node.at(parent)).remove(field));
    }

    @ParameterizedTest
    @ValueSource(strings = {"respondent_account", "applicant_account", "minor_creditor_accounts/0",
        "minor_creditor_accounts/1"})
    void requiresExplicitNullAccountIdentities(String path) throws Exception {
        for (String field : new String[] {"account_id", "account_number"}) {
            rejectMutation(node -> ((ObjectNode) node.at("/casefile_snapshot/" + path)).put(field, 99));
            rejectMutation(node -> ((ObjectNode) node.at("/casefile_snapshot/" + path)).remove(field));
        }
    }

    @Test
    void rejectsWrongDuplicateAndMissingMinorSequences() throws Exception {
        for (int sequence : new int[] {0, 7, 99}) {
            rejectMutation(node -> ((ObjectNode) node.at("/casefile_snapshot/minor_creditor_accounts/1"))
                .put("creditor_sequence", sequence));
        }
        rejectMutation(node -> ((ArrayNode) node.at("/casefile_snapshot/minor_creditor_accounts")).remove(1));
        rejectMutation(node -> ((ObjectNode) node.at("/casefile_snapshot/minor_creditor_accounts/0"))
            .put("creditor_sequence", "7"));
    }

    @Test
    void rejectsLostChangedOrExtraHistory() throws Exception {
        rejectMutation(node -> ((ArrayNode) node.path("timeline_data")).remove(0));
        rejectMutation(node -> ((ObjectNode) node.at("/timeline_data/0")).put("username", NAME));
        rejectMutation(node -> ((ObjectNode) node.at("/timeline_data/1")).put("reason_text", "Changed reason"));
        rejectMutation(node -> ((ArrayNode) node.path("timeline_data")).addObject().put("status", "Resubmitted"));
        rejectMutation(node -> ((ArrayNode) node.path("timeline_data")).remove(2));
        rejectMutation(node -> ((ObjectNode) node.at("/timeline_data/2")).put("status", "Submitted"));
        rejectMutation(node -> ((ObjectNode) node.at("/timeline_data/2")).put("username", "Synthetic Inputter"));
        rejectMutation(node -> ((ObjectNode) node.at("/timeline_data/2")).put("reason_text", REASON));
        rejectMutation(node -> ((ObjectNode) node.at("/timeline_data/2")).putNull("reason_text"));
    }

    @Test
    void rejectsWrongOrMissingDatesAndAcceptsEqualInstants() throws Exception {
        rejectMutation(node -> node.put("casefile_status_date", MARKER));
        rejectMutation(node -> node.remove("casefile_status_date"));
        rejectMutation(node -> ((ObjectNode) node.at("/timeline_data/2")).put("status_date", REJECTED));
        ObjectNode after = resubmitted().put("casefile_status_date", "2026-10-22T10:00:00Z");
        ((ObjectNode) after.at("/timeline_data/2")).put("status_date", "2026-10-22T10:00:00Z");
        assertSafe(() -> assertResubmitted(after));
        ObjectNode equivalent = resubmitted();
        ((ObjectNode) equivalent.at("/timeline_data/2")).put("status_date", "2026-10-23T13:00:00+01:00");
        assertDoesNotThrow(() -> assertResubmitted(equivalent));
    }

    @ParameterizedTest
    @ValueSource(strings = {"W/\"3\"", "3", "\"-1\"", "\"9223372036854775808\"", ""})
    void rejectsInvalidEtags(String etag) throws Exception {
        Response invalid = new ResponseBuilder().clone(response(resubmitted())).setHeader("ETag", etag).build();
        assertSafe(() -> DraftCasefileResubmissionAssertions.resubmitted(invalid, rejected(),
            replacement().toString(), ACTOR, NAME));
    }

    @Test
    void rejectsWrongHttpAndMediaType() throws Exception {
        for (Response invalid : new Response[] {
            new ResponseBuilder().clone(response(resubmitted())).setStatusCode(201).build(),
            new ResponseBuilder().clone(response(resubmitted())).setContentType("text/plain").build(),
            new ResponseBuilder().clone(response(resubmitted())).setContentType("application/json-invalid").build()
        }) {
            assertSafe(() -> DraftCasefileResubmissionAssertions.resubmitted(invalid, rejected(),
                replacement().toString(), ACTOR, NAME));
        }
    }

    @ParameterizedTest
    @ValueSource(strings = {"", "{", "null", "[]", "{} {}", "{} E2E-550e8400e29b41d4"})
    void rejectsMalformedOrTrailingResponseAndRequestSafely(String raw) throws Exception {
        Response invalid = new ResponseBuilder().clone(response(resubmitted())).setBody(raw).build();
        assertSafe(() -> DraftCasefileResubmissionAssertions.resubmitted(invalid, rejected(),
            replacement().toString(), ACTOR, NAME));
        assertSafe(() -> DraftCasefileResubmissionAssertions.resubmitted(response(resubmitted()), rejected(),
            raw, ACTOR, NAME));
    }

    @Test
    void acceptsExactSupportedInvalidReferenceProblem() {
        assertDoesNotThrow(() -> DraftCasefileResubmissionAssertions.invalidContent(problem(problemBody()), MARKER));
    }

    @ParameterizedTest
    @ValueSource(strings = {"23e626552a324ac3ab9bc02588fd4fec", "synthetic-correlation-42"})
    void acceptsCorrelatedStringOperationIds(String operation) {
        ObjectNode body = problemBody().put("operation_id", operation)
            .put("instance", "https://hmcts.gov.uk/problems/instance/" + operation);
        assertDoesNotThrow(() -> DraftCasefileResubmissionAssertions.invalidContent(problem(body), MARKER));
    }

    @ParameterizedTest
    @ValueSource(strings = {"null", "23", "\"\"", "\"  \"", "[]", "{}"})
    void rejectsBlankAndNonStringOperationIds(String raw) throws Exception {
        ObjectNode body = problemBody();
        body.set("operation_id", JSON.readTree(raw));
        assertSafe(() -> DraftCasefileResubmissionAssertions.invalidContent(problem(body), MARKER));
    }

    @ParameterizedTest
    @ValueSource(strings = {"status", "type", "title", "detail", "retriable", "operation_id", "instance"})
    void rejectsMissingWrongTypedAndUnsafeProblemFields(String field) {
        ObjectNode missing = problemBody();
        missing.remove(field);
        assertSafe(() -> DraftCasefileResubmissionAssertions.invalidContent(problem(missing), MARKER));
        assertSafe(() -> DraftCasefileResubmissionAssertions.invalidContent(
            problem(problemBody().put(field, MARKER)), MARKER));
    }

    @Test
    void rejectsUncorrelatedRetriableNestedAndExtraProblems() {
        for (ObjectNode body : new ObjectNode[] {problemBody().put("retriable", true),
            problemBody().put("status", 400.0), problemBody().put("status", 403),
            problemBody().put("operation_id", "650e8400-e29b-41d4-a716-446655440000"),
            problemBody().put("reason", "stack exception " + MARKER)}) {
            assertSafe(() -> DraftCasefileResubmissionAssertions.invalidContent(problem(body), MARKER));
        }
        ObjectNode nested = problemBody();
        nested.putObject("casefile").put("private", MARKER);
        assertSafe(() -> DraftCasefileResubmissionAssertions.invalidContent(problem(nested), MARKER));
        for (String header : new String[] {"ETag", "Location"}) {
            Response invalid = new ResponseBuilder().clone(problem(problemBody())).setHeader(header, "value").build();
            assertSafe(() -> DraftCasefileResubmissionAssertions.invalidContent(invalid, MARKER));
        }
    }

    @ParameterizedTest
    @ValueSource(strings = {"", "{", "null", "[]", "{} {}", "{} E2E-550e8400e29b41d4"})
    void rejectsMalformedTrailingAndWrongHttpProblems(String raw) {
        Response invalid = new ResponseBuilder().clone(problem(problemBody())).setBody(raw).build();
        assertSafe(() -> DraftCasefileResubmissionAssertions.invalidContent(invalid, MARKER));
        Response status = new ResponseBuilder().clone(problem(problemBody())).setStatusCode(403).build();
        assertSafe(() -> DraftCasefileResubmissionAssertions.invalidContent(status, MARKER));
        Response media = new ResponseBuilder().clone(problem(problemBody())).setContentType("application/json").build();
        assertSafe(() -> DraftCasefileResubmissionAssertions.invalidContent(media, MARKER));
    }

    private void rejectMutation(Consumer<ObjectNode> mutation) throws Exception {
        ObjectNode body = resubmitted();
        mutation.accept(body);
        assertSafe(() -> assertResubmitted(body));
    }

    private JsonNode assertResubmitted(ObjectNode body) throws Exception {
        return DraftCasefileResubmissionAssertions.resubmitted(response(body), rejected(),
            replacement().toString(), ACTOR, NAME);
    }

    private void assertSafe(Executable assertion) {
        AssertionError failure = assertThrows(AssertionError.class, assertion);
        for (String privateValue : new String[] {MARKER, NAME, ACTOR, REASON, "Synthetic Inputter", "L044JG"}) {
            assertFalse(failure.toString().contains(privateValue));
        }
        assertNull(failure.getCause());
    }

    private ObjectNode original() throws Exception {
        ObjectNode root = (ObjectNode) JSON.readTree(new DraftCasefileRequestFactory().withMinorCreditors(MARKER));
        root.remove("casefile_type");
        return root;
    }

    private ObjectNode replacement() throws Exception {
        ObjectNode request = original();
        for (String party : new String[] {"respondent", "applicant", "minor"}) {
            correct(request, party);
        }
        return request;
    }

    private void correct(ObjectNode request, String party) {
        String path = switch (party) {
            case "respondent" -> "/casefile/respondent_account/respondent/party_details/individual_details";
            case "applicant" -> "/casefile/applicant/party_details/individual_details";
            default -> "/casefile/minor_creditors/0/party_details/individual_details";
        };
        ((ObjectNode) request.at(path)).put("surname", "Corrected " + party);
    }

    private JsonNode rejectedCasefile() {
        try {
            return original().path("casefile");
        } catch (Exception exception) {
            throw new AssertionError("Synthetic fixture must be valid");
        }
    }

    private ObjectNode rejected() throws Exception {
        ObjectNode root = JSON.createObjectNode().put("draft_casefile_id", 123).put("business_unit_id", 44)
            .put("created_date", CREATED).put("submitted_by", "L044JG").put("submitted_by_name", "Synthetic Inputter")
            .put("casefile_type", "REMO In").put("casefile_status", "REJECTED").put("casefile_status_name", "Rejected")
            .put("casefile_status_date", REJECTED).put("status_message", REASON)
            .putNull("validated_date").putNull("validated_by").putNull("validated_by_name");
        root.putObject("stable_metadata").put("retained", true);
        root.set("casefile", original().path("casefile"));
        root.set("casefile_snapshot", snapshot(false, false, false));
        ArrayNode history = root.putArray("timeline_data");
        history.addObject().put("status", "Submitted").put("status_date", CREATED)
            .put("username", "Synthetic Inputter");
        history.addObject().put("status", "Rejected").put("status_date", REJECTED)
            .put("username", "Synthetic Checker").put("reason_text", REASON);
        return root;
    }

    private ObjectNode resubmitted() throws Exception {
        return resubmitted(replacement());
    }

    private ObjectNode resubmitted(ObjectNode request) throws Exception {
        ObjectNode root = rejected().put("submitted_by", ACTOR).put("submitted_by_name", NAME)
            .put("casefile_status", "RESUBMITTED").put("casefile_status_name", "Resubmitted")
            .put("casefile_status_date", RESUBMITTED);
        root.set("casefile", request.path("casefile").deepCopy());
        root.set("casefile_snapshot", snapshot(
            request.at("/casefile/respondent_account/respondent/party_details/individual_details/surname")
                .asText().startsWith("Corrected"),
            request.at("/casefile/applicant/party_details/individual_details/surname").asText().startsWith("Corrected"),
            request.at("/casefile/minor_creditors/0/party_details/individual_details/surname")
                .asText().startsWith("Corrected")));
        ((ArrayNode) root.path("timeline_data")).addObject().put("status", "Resubmitted")
            .put("status_date", RESUBMITTED).put("username", NAME);
        return root;
    }

    private ObjectNode snapshot(boolean respondent, boolean applicant, boolean minor) {
        ObjectNode snapshot = JSON.createObjectNode();
        account(snapshot.putObject("respondent_account"), "respondent_name",
            respondent ? "CORRECTED RESPONDENT, Synthetic" : "RESPONDENT, Synthetic");
        account(snapshot.putObject("applicant_account"), "applicant_name",
            applicant ? "CORRECTED APPLICANT, Synthetic" : "APPLICANT, Synthetic");
        ArrayNode minors = snapshot.putArray("minor_creditor_accounts");
        account(minors.addObject().put("creditor_sequence", 7), "name",
            minor ? "CORRECTED MINOR, Synthetic" : "MINORSEVEN, Synthetic");
        account(minors.addObject().put("creditor_sequence", 23), "name", "MINORTWENTYTHREE, Synthetic");
        return snapshot;
    }

    private void account(ObjectNode node, String field, String value) {
        node.putNull("account_id").putNull("account_number").put(field, value);
    }

    private Response response(JsonNode body) {
        return new ResponseBuilder().setStatusCode(200).setContentType("application/json")
            .setHeader("ETag", "\"3\"").setBody(body.toString()).build();
    }

    private ObjectNode problemBody() {
        return JSON.createObjectNode().put("status", 400).put("type", "https://hmcts.gov.uk/problems/opal-api-error")
            .put("title", "Bad Request").put("detail", "An error occurred while processing your request")
            .put("retriable", false).put("operation_id", OPERATION)
            .put("instance", "https://hmcts.gov.uk/problems/instance/" + OPERATION);
    }

    private Response problem(JsonNode body) {
        return new ResponseBuilder().setStatusCode(400).setContentType("application/problem+json")
            .setBody(body.toString()).build();
    }
}
