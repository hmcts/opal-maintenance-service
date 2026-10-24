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
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.function.Supplier;
import uk.gov.hmcts.opal.actions.DraftCasefileActions;
import uk.gov.hmcts.opal.assertions.DraftCasefileDecisionAssertions;
import uk.gov.hmcts.opal.assertions.DraftCasefileResubmissionAssertions;
import uk.gov.hmcts.opal.assertions.DraftCasefileRetrievalAssertions;
import uk.gov.hmcts.opal.assertions.PublicationEvidenceAssertions;
import uk.gov.hmcts.opal.data.DraftCasefileRequestFactory;

import static org.junit.jupiter.api.Assertions.assertTrue;

public class ResubmitRejectedCasefileStepDef {
    private static final ObjectMapper JSON = new ObjectMapper()
        .enable(DeserializationFeature.FAIL_ON_TRAILING_TOKENS);
    private static final String INPUTTER = "opal-test@dev.platform.hmcts.net";
    private static final String CHECKER = "opal-test-10@dev.platform.hmcts.net";
    private static final String DENIED = "opal-test-2@dev.platform.hmcts.net";
    private static final String REASON = "Synthetic resubmission setup rejection";
    private final DraftCasefileActions actions;
    private final DraftCasefileRequestFactory requests;
    private final Function<String, String> config;
    private final Function<String, String> tokens;
    private OwnedDraft owned;
    private Actor creator;
    private Actor checker;
    private Actor denied;

    public ResubmitRejectedCasefileStepDef() {
        this(new DraftCasefileActions(), new DraftCasefileRequestFactory(), System::getenv, user -> {
            new BearerTokenStepDef().useTestUser(user);
            return BearerTokenStepDef.getToken();
        });
    }

    ResubmitRejectedCasefileStepDef(DraftCasefileActions actions, DraftCasefileRequestFactory requests,
                                  Function<String, String> config, Function<String, String> tokens) {
        this.actions = actions;
        this.requests = requests;
        this.config = config;
        this.tokens = tokens;
    }

    @Before("@PO10622")
    public void resetScenario() {
        clear();
    }

    @Given("an owned rejected casefile with complete original content")
    public void rejectedCasefile() {
        require(owned == null, "Each scenario owns one fresh draft");
        creator = actor(configured("RM_DRAFT_CASEFILE_INPUTTER_USER", INPUTTER), false, false);
        checker = actor(configured("RM_DRAFT_CASEFILE_CHECKER_USER", CHECKER), true, false);
        require(!creator.id.equals(checker.id), "Setup checker must have an independent Business Unit identity");
        owned = new OwnedDraft();
        owned.marker = "E2E-" + UUID.randomUUID().toString().replace("-", "").substring(0, 16);
        owned.owner = creator;
        owned.originalRequest = requests.withMinorCreditors(owned.marker);
        owned.unknownCreate = true;
        Response created = mutation(() -> actions.create(creator.token, owned.originalRequest));
        require(created.statusCode() == 201, "Owned draft creation requires HTTP 201");
        JsonNode post = parse(created.asString());
        JsonNode id = post.path("draft_casefile_id");
        require(id.isIntegralNumber() && id.canConvertToLong() && id.longValue() > 0,
            "Created draft requires a positive Long ID");
        // Capture cleanup identity before checking any other POST metadata or headers.
        owned.id = id.longValue();
        owned.unknownCreate = false;
        require(jsonType(created) && version(created.header("ETag")) == 0,
            "Owned creation requires application/json and initial version zero");
        require(creator.id.equals(post.path("submitted_by").textValue())
            && creator.name.equals(post.path("submitted_by_name").textValue()),
            "POST submitter must match the resolved creator Business Unit identity");
        Response submitted = call(() -> actions.get(creator.token, owned.id));
        try {
            DraftCasefileRetrievalAssertions.submitted(submitted, owned.originalRequest, post);
        } catch (IOException exception) {
            throw new AssertionError("Original submitted baseline requires valid JSON");
        }
        require(version(submitted.header("ETag")) == 0
            && "Submitted".equals(read(submitted).path("casefile_status_name").textValue()),
            "Original baseline requires initial version and Submitted label");
        JsonNode before = read(submitted);
        Response rejection = mutation(() -> actions.decide(checker.token, owned.id, decisionBody(),
            submitted.header("ETag")));
        JsonNode rejected = DraftCasefileDecisionAssertions.decided(rejection, before, "REJECTED", REASON,
            checker.id, checker.name);
        require(version(rejection.header("ETag")) == 1
            && "Rejected".equals(rejected.path("casefile_status_name").textValue()),
            "Setup rejection requires version one and Rejected label");
        Response persisted = call(() -> actions.get(creator.token, owned.id));
        DraftCasefileDecisionAssertions.unchanged(persisted, rejected, rejection.header("ETag"));
        owned.baseline = read(persisted);
        owned.etag = persisted.header("ETag");
    }

    @When("the original inputter resubmits its complete correction")
    public void originalCorrection() {
        replace(creator, false, false);
    }

    @When("another authorised inputter resubmits its complete correction")
    public void anotherCorrection() {
        replace(checker, false, false);
    }

    @When("the original inputter attempts a correction with an unknown application")
    public void invalidCorrection() {
        replace(creator, true, false);
    }

    @When("a caller without create permission attempts the complete correction")
    public void deniedCorrection() {
        requireOwned();
        denied = actor(configured("RM_DRAFT_CASEFILE_DENIED_USER", DENIED), false, true);
        replace(denied, false, false);
    }

    @When("the original inputter attempts the complete correction in a different Business Unit")
    public void differentUnitCorrection() {
        replace(creator, false, true);
    }

    private void replace(Actor actor, boolean invalid, boolean differentUnit) {
        requireOwned();
        require(!owned.observationAttempted && !owned.putAttempted, "Tested PUT and registration must not replay");
        owned.observationAttempted = true;
        Response registration = mutation(() -> actions.registerPublicationEvidence(creator.token, owned.id,
            owned.marker));
        require(registration.statusCode() == 201,
            "Publication registration requires HTTP 201; actual HTTP status " + registration.statusCode());
        try {
            owned.registration = PublicationEvidenceAssertions.registered(registration);
        } catch (AssertionError exception) {
            throw new AssertionError("Publication registration contract failed; actual HTTP status "
                + registration.statusCode());
        }
        DraftCasefileDecisionAssertions.unchanged(call(() -> actions.get(creator.token, owned.id)),
            owned.baseline, owned.etag);
        owned.correctedRequest = correction(invalid, differentUnit);
        owned.intended = actor;
        owned.putAttempted = true;
        owned.ambiguous = true;
        owned.response = mutation(() -> actions.replace(actor.token, owned.id, owned.correctedRequest, owned.etag));
        if (owned.response.statusCode() == 200) {
            // Only known eligible inputters can gain cleanup and journal authority on confirmed success.
            if (actor == creator || actor == checker) {
                owned.owner = actor;
            }
            owned.ambiguous = false;
        } else if (Set.of(400, 403, 409).contains(owned.response.statusCode())) {
            owned.ambiguous = false;
        }
    }

    private String correction(boolean invalid, boolean differentUnit) {
        ObjectNode full = parse(owned.originalRequest).deepCopy();
        ((ObjectNode) full.at("/casefile/respondent_account/respondent/party_details/individual_details"))
            .put("forenames", "CorrectedRespondent");
        ((ObjectNode) full.at("/casefile/applicant/party_details/individual_details"))
            .put("forenames", "CorrectedApplicant");
        for (JsonNode minor : full.at("/casefile/minor_creditors")) {
            if (minor.path("creditor_sequence").intValue() == 7) {
                ((ObjectNode) minor.at("/party_details/individual_details")).put("forenames", "CorrectedMinorSeven");
            }
        }
        if (invalid) {
            ((ObjectNode) full.at("/casefile/respondent_account")).put("application_code", "ZZ99999");
        }
        ObjectNode put = JSON.createObjectNode().put("business_unit_id", differentUnit ? 45 : 44);
        put.set("casefile", full.path("casefile"));
        return put.toString();
    }

    @Then("the corrected casefile is persisted with the authenticated latest submitter and no publication")
    public void assertResubmitted() {
        requireTested();
        JsonNode after = DraftCasefileResubmissionAssertions.resubmitted(owned.response, owned.baseline,
            owned.correctedRequest, owned.intended.id, owned.intended.name);
        require(version(owned.response.header("ETag")) > version(owned.etag),
            "Resubmission must numerically advance the strong ETag");
        DraftCasefileDecisionAssertions.unchanged(call(() -> actions.get(owned.owner.token, owned.id)),
            after, owned.response.header("ETag"));
        noPublication();
        owned.resubmitted = after;
        owned.resubmittedEtag = owned.response.header("ETag");
    }

    @Then("a safe validation problem preserves the complete rejected casefile and no publication")
    public void assertInvalid() {
        unchanged();
        DraftCasefileResubmissionAssertions.invalidContent(owned.response, owned.marker);
    }

    @Then("a safe denied problem preserves the complete rejected casefile and no publication")
    public void assertDenied() {
        unchanged();
        DraftCasefileDecisionAssertions.safeProblem(owned.response, 403, "forbidden", owned.marker);
    }

    @Then("a safe ownership conflict preserves the complete rejected casefile and no publication")
    public void assertConflict() {
        unchanged();
        DraftCasefileDecisionAssertions.safeProblem(owned.response, 409, "resource-conflict", owned.marker);
    }

    private void unchanged() {
        requireTested();
        DraftCasefileDecisionAssertions.unchanged(call(() -> actions.get(owned.owner.token, owned.id)),
            owned.baseline, owned.etag);
        noPublication();
    }

    private void noPublication() {
        PublicationEvidenceAssertions.noSend(call(() -> actions.publicationEvidence(owned.owner.token, owned.id,
            owned.marker)), owned.registration);
    }

    @Then("the latest submitter cannot check its own resubmitted work")
    public void selfCheckDenied() {
        requireTested();
        require(owned.owner == checker && owned.resubmitted != null && !owned.selfCheckAttempted,
            "Self-check requires the confirmed independent resubmitter and must not replay");
        owned.selfCheckAttempted = true;
        Response response = mutation(() -> actions.decide(checker.token, owned.id, decisionBody(),
            owned.resubmittedEtag));
        DraftCasefileDecisionAssertions.unchanged(call(() -> actions.get(checker.token, owned.id)),
            owned.resubmitted, owned.resubmittedEtag);
        noPublication();
        DraftCasefileDecisionAssertions.safeProblem(response, 403, "forbidden", owned.marker);
    }

    private static String decisionBody() {
        return JSON.createObjectNode().put("business_unit_id", 44).put("casefile_status", "REJECTED")
            .put("status_message", REASON).toString();
    }

    private Actor actor(String user, boolean checkRequired, boolean deniedActor) {
        Actor actor = new Actor();
        actor.token = token(user);
        Response response = call(() -> actions.userState(actor.token));
        require(response.statusCode() == 200 && jsonType(response), "User state requires HTTP 200 application/json");
        JsonNode state = parse(response.asString());
        require(state.path("name").isTextual() && !state.path("name").textValue().isBlank(),
            "User state requires a nonblank actor name");
        actor.name = state.path("name").textValue();
        JsonNode domains = state.path("domains");
        require(domains.isObject(), "User state requires a domains object");
        if (deniedActor && !domains.has("maintenance")) {
            return actor;
        }
        JsonNode maintenance = domains.path("maintenance");
        JsonNode units = maintenance.path("business_unit_users");
        require(maintenance.isObject() && units.isArray(), "User state requires maintenance Business Unit users");
        int matches = 0;
        boolean create = false;
        boolean check = false;
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
                create = permissions.contains(21);
                check = permissions.contains(22);
            }
        }
        require(matches <= 1, "User state has ambiguous owning Business Unit users");
        if (deniedActor) {
            require(!create, "Denied caller must lack owning Business Unit permission 21");
        } else {
            require(matches == 1 && create && (!checkRequired || check),
                "Actor requires the owning Business Unit create and applicable check permissions");
        }
        return actor;
    }

    @After("@PO10622")
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
                scenario.attach(evidence, "text/plain", "PO-10622 cleanup failure");
            } catch (RuntimeException | AssertionError exception) {
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
        List<Actor> candidates = new ArrayList<>();
        candidates.add(owned.owner);
        if (owned.ambiguous && owned.intended != null && owned.intended != creator && owned.intended == checker) {
            candidates.add(owned.intended);
            prioritizeRecognizedOwner(candidates);
        }
        StringBuilder evidence = new StringBuilder("Draft cleanup failed for ID ").append(owned.id)
            .append(" with marker ").append(owned.marker);
        for (Actor candidate : candidates) {
            try {
                Response response = actions.delete(candidate.token, owned.id, owned.marker);
                if (response != null && response.statusCode() == 204) {
                    return null;
                }
                evidence.append(response == null ? "; no response" : "; status " + response.statusCode());
            } catch (RuntimeException exception) {
                evidence.append("; request error");
            }
        }
        return evidence.toString();
    }

    private void prioritizeRecognizedOwner(List<Actor> candidates) {
        // An old read cannot rule out a later commit: both known candidates always survive an ambiguous handover.
        try {
            Response response = actions.get(creator.token, owned.id);
            if (response == null || response.statusCode() != 200) {
                return;
            }
            JsonNode body = read(response);
            require(body.path("draft_casefile_id").isIntegralNumber()
                && body.path("draft_casefile_id").longValue() == owned.id
                && owned.marker.equals(body.at("/casefile/respondent_account/remo_reference").textValue()),
                "Recovery read must identify the owned draft and marker");
            if (checker.id.equals(body.path("submitted_by").textValue())) {
                DraftCasefileResubmissionAssertions.resubmitted(response, owned.baseline, owned.correctedRequest,
                    checker.id, checker.name);
                require(version(response.header("ETag")) > version(owned.etag),
                    "Recovery resubmission must advance the version");
                candidates.clear();
                candidates.add(checker);
                candidates.add(creator);
            } else if (creator.id.equals(body.path("submitted_by").textValue())) {
                DraftCasefileDecisionAssertions.unchanged(response, owned.baseline, owned.etag);
            }
        } catch (RuntimeException | AssertionError exception) {
            // Unrecognized or unavailable readback never authorizes another identity or a replay.
        }
    }

    private void clear() {
        owned = null;
        creator = null;
        checker = null;
        denied = null;
    }

    private void requireOwned() {
        require(owned != null && owned.id != null && owned.baseline != null && creator != null && checker != null,
            "An owned complete rejected baseline is required");
    }

    private void requireTested() {
        requireOwned();
        require(owned.putAttempted && owned.response != null && owned.registration != null,
            "A completed PUT and registered observation are required");
    }

    private String configured(String variable, String fallback) {
        String value = config.apply(variable);
        return value == null || value.isBlank() ? fallback : value;
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

    private static void require(boolean condition, String message) {
        assertTrue(condition, message);
    }

    // No generated toString: holders contain scenario-local credentials and actual actor data.
    private static final class OwnedDraft {
        private Long id;
        private String marker;
        private boolean unknownCreate;
        private Actor owner;
        private Actor intended;
        private String originalRequest;
        private String correctedRequest;
        private JsonNode baseline;
        private String etag;
        private JsonNode registration;
        private boolean observationAttempted;
        private boolean putAttempted;
        private boolean ambiguous;
        private Response response;
        private JsonNode resubmitted;
        private String resubmittedEtag;
        private boolean selfCheckAttempted;
    }

    private static final class Actor {
        private String token;
        private String id;
        private String name;
    }
}
