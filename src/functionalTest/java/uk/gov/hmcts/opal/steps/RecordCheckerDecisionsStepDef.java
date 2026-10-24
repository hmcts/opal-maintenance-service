package uk.gov.hmcts.opal.steps;

import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import io.cucumber.java.After;
import io.cucumber.java.Before;
import io.cucumber.java.Scenario;
import io.cucumber.java.en.Given;
import io.cucumber.java.en.Then;
import io.cucumber.java.en.When;
import io.restassured.response.Response;
import java.io.IOException;
import java.time.OffsetDateTime;
import java.time.format.DateTimeParseException;
import java.util.HashSet;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.function.Supplier;
import uk.gov.hmcts.opal.actions.DraftCasefileActions;
import uk.gov.hmcts.opal.assertions.DraftCasefileDecisionAssertions;
import uk.gov.hmcts.opal.assertions.DraftCasefileRetrievalAssertions;
import uk.gov.hmcts.opal.assertions.PublicationEvidenceAssertions;
import uk.gov.hmcts.opal.data.DraftCasefileRequestFactory;

import static org.junit.jupiter.api.Assertions.assertTrue;

public class RecordCheckerDecisionsStepDef {
    private static final ObjectMapper JSON = new ObjectMapper()
        .enable(DeserializationFeature.FAIL_ON_TRAILING_TOKENS);
    private static final String INPUTTER = "opal-test@dev.platform.hmcts.net";
    private static final String CHECKER = "opal-test-10@dev.platform.hmcts.net";
    private static final String DENIED = "opal-test-2@dev.platform.hmcts.net";
    private static final String REASON = "Synthetic checker decision reason";
    private static final String CORRECTED = "SyntheticCorrected";
    private final DraftCasefileActions actions;
    private final DraftCasefileRequestFactory requests;
    private final Function<String, String> config;
    private final Function<String, String> tokens;
    private OwnedDraft owned;
    private Actor checker;
    private Actor separateActor;

    public RecordCheckerDecisionsStepDef() {
        this(new DraftCasefileActions(), new DraftCasefileRequestFactory(), System::getenv, user -> {
            new BearerTokenStepDef().useTestUser(user);
            return BearerTokenStepDef.getToken();
        });
    }

    RecordCheckerDecisionsStepDef(DraftCasefileActions actions, DraftCasefileRequestFactory requests,
                                 Function<String, String> config, Function<String, String> tokens) {
        this.actions = actions;
        this.requests = requests;
        this.config = config;
        this.tokens = tokens;
    }

    @Before("@PO10617")
    public void resetScenario() {
        clear();
    }

    @Given("an owned complete {word} Draft Casefile is ready for checking")
    public void readyForChecking(String source) {
        require(Set.of("SUBMITTED", "RESUBMITTED").contains(source), "Unsupported checker source lifecycle");
        resolveChecker(false);
        submit(configuredUser("RM_DRAFT_CASEFILE_INPUTTER_USER", INPUTTER), false);
        if ("RESUBMITTED".equals(source)) {
            rejectForSetup();
            resubmit();
        }
        require(source.equals(owned.baseline.path("casefile_status").textValue()), "Checker source lifecycle differs");
    }

    @Given("an owned submission by a user with both create and check permissions")
    public void ownSubmission() {
        resolveChecker(true);
        submit(checker.user, true);
    }

    @Given("an owned RESUBMITTED Draft Casefile with its obsolete original version")
    public void obsoleteVersion() {
        readyForChecking("RESUBMITTED");
        require(version(owned.originalEtag) == 0 && version(owned.etag) == 2,
            "Stale scenario requires original zero and current resubmitted version two");
    }

    @Given("an owned REJECTED Draft Casefile with a current version")
    public void rejectedVersion() {
        readyForChecking("SUBMITTED");
        rejectForSetup();
        require("REJECTED".equals(owned.baseline.path("casefile_status").textValue()) && version(owned.etag) == 1,
            "Lifecycle scenario requires a current rejected version one");
    }

    @When("the independent checker records {word} with the current version")
    public void recordDecision(String decision) {
        requireOwned();
        owned.target = switch (decision) {
            case "Approve" -> "PUBLISHING_PENDING";
            case "Reject" -> "REJECTED";
            case "Delete" -> "DELETED";
            default -> throw new AssertionError("Unsupported checker decision");
        };
        independent();
        testDecision(checker, owned.etag);
    }

    @When("that same checker attempts approval")
    public void selfApproval() {
        requireOwned();
        require(checker.id.equals(owned.created.path("submitted_by").textValue()),
            "Self-check requires the actual submitting Business Unit user");
        approve(checker, owned.etag);
    }

    @When("a caller without owning Business Unit permission attempts approval")
    public void deniedApproval() {
        requireOwned();
        separateActor = actor(configuredUser("RM_DRAFT_CASEFILE_DENIED_USER", DENIED), false, true);
        approve(separateActor, owned.etag);
    }

    @When("the independent checker approves using that obsolete version")
    public void staleApproval() {
        requireOwned();
        require("RESUBMITTED".equals(owned.baseline.path("casefile_status").textValue())
            && version(owned.originalEtag) == 0 && version(owned.etag) == 2,
            "Obsolete approval requires an eligible resubmitted current draft");
        independent();
        approve(checker, owned.originalEtag);
    }

    @When("the independent checker attempts approval of that rejected draft")
    public void rejectedApproval() {
        requireOwned();
        require("REJECTED".equals(owned.baseline.path("casefile_status").textValue()) && version(owned.etag) == 1,
            "Rejected approval requires the current rejected version");
        independent();
        approve(checker, owned.etag);
    }

    private void approve(Actor actor, String etag) {
        owned.target = "PUBLISHING_PENDING";
        testDecision(actor, etag);
    }

    private void testDecision(Actor actor, String etag) {
        require(!owned.observationAttempted && !owned.testedAttempted,
            "A scenario may attempt its tested decision only once");
        owned.observationAttempted = true;
        owned.registration = PublicationEvidenceAssertions.registered(mutation(() ->
            actions.registerPublicationEvidence(owned.ownerToken, owned.id, owned.marker)));
        Response registeredRead = call(() -> actions.get(owned.ownerToken, owned.id));
        DraftCasefileDecisionAssertions.unchanged(registeredRead, owned.baseline, owned.etag);
        // Registration follows all setup. The synchronous publisher completes journal outcomes before PATCH returns.
        owned.testedAttempted = true;
        owned.testedResponse = mutation(() -> actions.decide(actor.token, owned.id,
            decisionBody(owned.target), etag));
    }

    @Then("the decision is persisted with server-owned history and the expected producer evidence")
    public void assertDecision() {
        requireTested();
        JsonNode decided = DraftCasefileDecisionAssertions.decided(owned.testedResponse, owned.baseline,
            owned.target, "PUBLISHING_PENDING".equals(owned.target) ? null : REASON, checker.id, checker.name);
        require(version(owned.testedResponse.header("ETag")) > version(owned.etag),
            "Decision must numerically advance the version");
        Response persisted = call(() -> actions.get(owned.ownerToken, owned.id));
        if ("PUBLISHING_PENDING".equals(owned.target)) {
            DraftCasefileDecisionAssertions.approvalPersisted(persisted, decided, owned.testedResponse.header("ETag"));
            PublicationEvidenceAssertions.acknowledged(evidence(), owned.registration);
        } else {
            DraftCasefileDecisionAssertions.unchanged(persisted, decided, owned.testedResponse.header("ETag"));
            PublicationEvidenceAssertions.noSend(evidence(), owned.registration);
        }
    }

    @Then("a safe forbidden response preserves the draft and complete zero producer evidence")
    public void assertForbidden() {
        unchangedProblem(403, "forbidden");
    }

    @Then("a safe version conflict preserves the draft and complete zero producer evidence")
    public void assertVersionConflict() {
        unchangedProblem(409, "optimistic-locking");
    }

    @Then("a safe lifecycle conflict preserves the draft and complete zero producer evidence")
    public void assertLifecycleConflict() {
        unchangedProblem(409, "resource-conflict");
    }

    private void unchangedProblem(int status, String kind) {
        requireTested();
        DraftCasefileDecisionAssertions.safeProblem(owned.testedResponse, status, kind, owned.marker);
        DraftCasefileDecisionAssertions.unchanged(call(() -> actions.get(owned.ownerToken, owned.id)),
            owned.baseline, owned.etag);
        PublicationEvidenceAssertions.noSend(evidence(), owned.registration);
    }

    private Response evidence() {
        return call(() -> actions.publicationEvidence(owned.ownerToken, owned.id, owned.marker));
    }

    private void resolveChecker(boolean createPermission) {
        checker = actor(configuredUser("RM_DRAFT_CASEFILE_CHECKER_USER", CHECKER), createPermission, false);
    }

    private Actor actor(String user, boolean createPermission, boolean denied) {
        Actor actor = new Actor();
        actor.user = user;
        actor.token = token(user);
        Response response = call(() -> actions.userState(actor.token));
        require(response.statusCode() == 200 && jsonType(response), "User state requires HTTP 200 application/json");
        JsonNode state = parse(response.asString());
        require(state.path("name").isTextual() && !state.path("name").textValue().isBlank(),
            "User state requires a nonblank actor name");
        actor.name = state.path("name").textValue();
        JsonNode domains = state.path("domains");
        require(domains.isObject(), "User state requires a domains object");
        if (denied && !domains.has("maintenance")) {
            return actor;
        }
        JsonNode maintenance = domains.path("maintenance");
        JsonNode units = maintenance.path("business_unit_users");
        require(maintenance.isObject() && units.isArray(),
            "User state requires the maintenance Business Unit users array");
        int matches = 0;
        boolean check = false;
        boolean create = false;
        for (JsonNode unit : units) {
            require(unit.isObject() && unit.path("business_unit_id").isIntegralNumber()
                && unit.path("business_unit_id").canConvertToInt() && unit.path("business_unit_id").intValue() > 0
                && unit.path("business_unit_user_id").isTextual()
                && !unit.path("business_unit_user_id").textValue().isBlank() && unit.path("permissions").isArray(),
                "User state Business Unit identity or permission shape is invalid");
            Set<Integer> permissions = new HashSet<>();
            for (JsonNode permission : unit.path("permissions")) {
                JsonNode id = permission.path("permission_id");
                require(permission.isObject() && id.isIntegralNumber() && id.canConvertToInt() && id.intValue() > 0,
                    "User state permission shape is invalid");
                require(permissions.add(id.intValue()), "User state permissions are ambiguous");
            }
            if (unit.path("business_unit_id").intValue() == 44) {
                matches++;
                actor.id = unit.path("business_unit_user_id").textValue();
                check = permissions.contains(22);
                create = permissions.contains(21);
            }
        }
        require(matches <= 1, "User state has ambiguous owning Business Unit users");
        if (denied) {
            require(!check, "Denied actor must lack owning Business Unit permission 22");
        } else {
            require(matches == 1 && check && (!createPermission || create),
                "Checker requires the owning Business Unit permissions");
        }
        return actor;
    }

    private void submit(String owner, boolean self) {
        require(owned == null, "Each scenario owns one newly created draft");
        owned = new OwnedDraft();
        owned.marker = "E2E-" + UUID.randomUUID().toString().replace("-", "").substring(0, 16);
        owned.ownerUser = owner;
        owned.ownerToken = self ? checker.token : token(owner);
        owned.originalRequest = requests.withMinorCreditors(owned.marker);
        owned.unknownCreate = true;
        Response response = mutation(() -> actions.create(owned.ownerToken, owned.originalRequest));
        require(response.statusCode() == 201, "Owned draft creation requires HTTP 201");
        JsonNode created = parse(response.asString());
        JsonNode id = created.path("draft_casefile_id");
        require(id.isIntegralNumber() && id.canConvertToLong() && id.longValue() > 0,
            "Created draft requires a positive Long ID");
        // Capture ownership before validating any remaining POST metadata, headers, or authoritative content.
        owned.id = id.longValue();
        owned.unknownCreate = false;
        owned.created = created;
        require(jsonType(response) && version(response.header("ETag")) == 0,
            "Owned creation requires application/json and initial version zero");
        owned.originalEtag = response.header("ETag");
        Response original = call(() -> actions.get(owned.ownerToken, owned.id));
        try {
            DraftCasefileRetrievalAssertions.submitted(original, owned.originalRequest, owned.created);
        } catch (IOException exception) {
            throw new AssertionError("Original submitted baseline requires valid JSON");
        }
        require(version(original.header("ETag")) == 0, "Original submitted version must be zero");
        owned.baseline = read(original);
        owned.etag = original.header("ETag");
        minors(owned.baseline);
        if (self) {
            require(checker.id.equals(created.path("submitted_by").textValue()),
                "Self submission must match the actual checker Business Unit user");
        } else {
            independent();
        }
    }

    private void independent() {
        require(checker != null && !checker.id.equals(owned.created.path("submitted_by").textValue()),
            "Independent checker must differ from the actual POST submitter");
    }

    private void rejectForSetup() {
        Response rejection = mutation(() -> actions.decide(
            checker.token, owned.id, decisionBody("REJECTED"), owned.etag));
        JsonNode rejected = DraftCasefileDecisionAssertions.decided(rejection, owned.baseline, "REJECTED", REASON,
            checker.id, checker.name);
        require(version(rejection.header("ETag")) == 1, "Setup rejection must produce version one");
        Response persisted = call(() -> actions.get(owned.ownerToken, owned.id));
        DraftCasefileDecisionAssertions.unchanged(persisted, rejected, rejection.header("ETag"));
        owned.baseline = read(persisted);
        owned.etag = persisted.header("ETag");
    }

    private void resubmit() {
        ObjectNode correction = parse(owned.originalRequest).deepCopy();
        ((ObjectNode) correction.at("/casefile/respondent_account/respondent/party_details/individual_details"))
            .put("forenames", CORRECTED);
        ObjectNode put = JSON.createObjectNode().put("business_unit_id", 44);
        put.set("casefile", correction.path("casefile"));
        owned.correctedRequest = put.toString();
        Response replaced = mutation(() -> actions.replace(
            owned.ownerToken, owned.id, owned.correctedRequest, owned.etag));
        JsonNode replacement = read(replaced);
        require(version(replaced.header("ETag")) == 2, "Resubmission must produce version two");
        corrected(replacement);
        Response persisted = call(() -> actions.get(owned.ownerToken, owned.id));
        DraftCasefileDecisionAssertions.unchanged(persisted, replacement, replaced.header("ETag"));
        corrected(read(persisted));
        owned.baseline = read(persisted);
        owned.etag = persisted.header("ETag");
    }

    private void corrected(JsonNode body) {
        require("RESUBMITTED".equals(body.path("casefile_status").textValue()),
            "Corrected lifecycle must be RESUBMITTED");
        JsonNode correction = parse(owned.correctedRequest);
        require(body.path("casefile").equals(correction.path("casefile"))
            && owned.marker.equals(body.at("/casefile/respondent_account/remo_reference").textValue()),
            "Resubmission must retain the full corrected request and marker");
        ObjectNode expectedSnapshot = owned.baseline.path("casefile_snapshot").deepCopy();
        ((ObjectNode) expectedSnapshot.path("respondent_account")).put("respondent_name", "RESPONDENT, " + CORRECTED);
        require(body.path("casefile_snapshot").equals(expectedSnapshot), "Corrected snapshot differs");
        Set<String> changed = Set.of("casefile_status", "casefile_status_date", "casefile", "casefile_snapshot",
            "timeline_data");
        ObjectNode before = owned.baseline.deepCopy();
        ObjectNode after = body.deepCopy();
        before.remove(changed);
        after.remove(changed);
        require(after.equals(before), "Resubmission must retain all other draft metadata");
        JsonNode prior = owned.baseline.path("timeline_data");
        JsonNode timeline = body.path("timeline_data");
        require(prior.isArray() && timeline.isArray() && timeline.size() == prior.size() + 1,
            "Resubmission must append one history event");
        for (int index = 0; index < prior.size(); index++) {
            require(timeline.get(index).equals(prior.get(index)), "Resubmission must retain the exact history prefix");
        }
        JsonNode event = timeline.get(timeline.size() - 1);
        require(event.isObject() && "Resubmitted".equals(event.path("status").textValue())
            && owned.created.path("submitted_by_name").equals(event.path("username"))
            && !event.hasNonNull("reason_text"), "Resubmission history actor or status differs");
        OffsetDateTime statusDate = date(body.path("casefile_status_date"));
        require(statusDate.toInstant().equals(date(event.path("status_date")).toInstant())
            && !statusDate.toInstant().isBefore(date(owned.baseline.path("casefile_status_date")).toInstant()),
            "Resubmission history timestamp differs");
        minors(body);
    }

    private static void minors(JsonNode body) {
        for (String path : new String[] {"/casefile/minor_creditors", "/casefile_snapshot/minor_creditor_accounts"}) {
            JsonNode minors = body.at(path);
            require(minors.isArray() && minors.size() == 2, "Both synthetic minor creditors must be retained");
            Set<Integer> sequences = new HashSet<>();
            for (JsonNode minor : minors) {
                require(minor.path("creditor_sequence").isIntegralNumber()
                    && minor.path("creditor_sequence").canConvertToInt(), "Minor creditor sequence must be numeric");
                require(sequences.add(minor.path("creditor_sequence").intValue()),
                    "Minor creditor sequence is repeated");
            }
            require(sequences.equals(Set.of(7, 23)), "Minor creditors seven and twenty-three must be retained");
        }
    }

    private String decisionBody(String target) {
        ObjectNode body = JSON.createObjectNode().put("business_unit_id", 44).put("casefile_status", target);
        if (!"PUBLISHING_PENDING".equals(target)) {
            body.put("status_message", REASON);
        }
        return body.toString();
    }

    @After("@PO10617")
    public void deleteCreatedDraft(Scenario scenario) {
        try {
            String evidence = cleanupEvidence();
            if (evidence == null) {
                return;
            }
            if (!scenario.isFailed()) {
                throw new AssertionError(evidence);
            }
            try {
                scenario.attach(evidence, "text/plain", "PO-10617 cleanup failure");
            } catch (RuntimeException exception) {
                throw new AssertionError(evidence + "; cleanup evidence attachment failed");
            }
        } finally {
            clear();
        }
    }

    private String cleanupEvidence() {
        if (owned == null) {
            return null;
        }
        if (owned.id == null) {
            return owned.unknownCreate ? "Draft cleanup has unknown owned create ID with marker " + owned.marker
                + "; operator follow-up required" : null;
        }
        String identity = "Draft cleanup failed for ID " + owned.id + " with marker " + owned.marker;
        try {
            Response response = actions.delete(owned.ownerToken, owned.id, owned.marker);
            return response != null && response.statusCode() == 204 ? null : identity
                + (response == null ? " with no response" : " with status " + response.statusCode());
        } catch (RuntimeException exception) {
            return identity + " with a request error";
        }
    }

    private void clear() {
        owned = null;
        checker = null;
        separateActor = null;
    }

    private void requireOwned() {
        require(owned != null && owned.id != null && owned.baseline != null && checker != null,
            "An owned complete checker baseline is required");
    }

    private void requireTested() {
        requireOwned();
        require(owned.testedAttempted && owned.testedResponse != null && owned.registration != null,
            "A completed tested decision and registered producer evidence are required");
    }

    private String configuredUser(String variable, String defaultUser) {
        String value = config.apply(variable);
        return value == null || value.isBlank() ? defaultUser : value;
    }

    private String token(String user) {
        try {
            String value = tokens.apply(user);
            require(value != null && !value.isBlank(), "Functional access token must be nonblank");
            return value;
        } catch (RuntimeException exception) {
            throw new AssertionError("Functional access token resolution failed");
        }
    }

    private static Response mutation(Supplier<Response> action) {
        return request(action, "Draft mutation result is ambiguous; do not replay; cleanup may require follow-up");
    }

    private static Response call(Supplier<Response> action) {
        return request(action, "Draft Casefile evidence request failed");
    }

    private static Response request(Supplier<Response> action, String failure) {
        try {
            Response response = action.get();
            require(response != null, failure);
            return response;
        } catch (RuntimeException exception) {
            throw new AssertionError(failure);
        }
    }

    private static boolean jsonType(Response response) {
        return response.contentType() != null
            && "application/json".equalsIgnoreCase(response.contentType().split(";", 2)[0].trim());
    }

    private static JsonNode parse(String body) {
        try {
            JsonNode parsed = JSON.readTree(body);
            require(parsed != null && parsed.isObject(), "Evidence requires a JSON object");
            return parsed;
        } catch (IOException | RuntimeException exception) {
            throw new AssertionError("Evidence requires valid JSON");
        }
    }

    private static JsonNode read(Response response) {
        try {
            return DraftCasefileRetrievalAssertions.read(response);
        } catch (IOException exception) {
            throw new AssertionError("Draft retrieval requires valid JSON");
        }
    }

    private static long version(String etag) {
        require(etag != null && etag.matches("\"[0-9]+\""), "ETag must be a strong quoted decimal version");
        try {
            return Long.parseLong(etag.substring(1, etag.length() - 1));
        } catch (NumberFormatException exception) {
            throw new AssertionError("ETag must fit a nonnegative Long");
        }
    }

    private static OffsetDateTime date(JsonNode value) {
        require(value.isTextual(), "Draft date must be an offset date-time");
        try {
            return OffsetDateTime.parse(value.textValue());
        } catch (DateTimeParseException exception) {
            throw new AssertionError("Draft date must be an offset date-time");
        }
    }

    private static void require(boolean condition, String message) {
        assertTrue(condition, message);
    }

    // Deliberately no generated toString: these scenario-local holders contain credentials and actual actor data.
    private static final class OwnedDraft {
        private Long id;
        private String marker;
        private String ownerUser;
        private String ownerToken;
        private boolean unknownCreate;
        private String originalRequest;
        private String correctedRequest;
        private JsonNode created;
        private String originalEtag;
        private JsonNode baseline;
        private String etag;
        private JsonNode registration;
        private boolean observationAttempted;
        private String target;
        private boolean testedAttempted;
        private Response testedResponse;
    }

    private static final class Actor {
        private String user;
        private String token;
        private String id;
        private String name;
    }
}
