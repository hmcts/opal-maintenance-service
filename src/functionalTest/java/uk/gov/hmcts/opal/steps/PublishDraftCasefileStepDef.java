package uk.gov.hmcts.opal.steps;

import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.cucumber.java.After;
import io.cucumber.java.Before;
import io.cucumber.java.Scenario;
import io.cucumber.java.en.Given;
import io.cucumber.java.en.Then;
import io.cucumber.java.en.When;
import io.restassured.response.Response;
import java.io.IOException;
import java.util.HashSet;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.function.Supplier;
import uk.gov.hmcts.opal.actions.DraftCasefileActions;
import uk.gov.hmcts.opal.actions.DraftCasefilePoller;
import uk.gov.hmcts.opal.assertions.DraftCasefileDecisionAssertions;
import uk.gov.hmcts.opal.assertions.DraftCasefilePublicationAssertions;
import uk.gov.hmcts.opal.assertions.DraftCasefileRetrievalAssertions;
import uk.gov.hmcts.opal.data.DraftCasefileRequestFactory;

import static org.junit.jupiter.api.Assertions.assertTrue;

public class PublishDraftCasefileStepDef {
    private static final ObjectMapper JSON = new ObjectMapper()
        .enable(DeserializationFeature.FAIL_ON_TRAILING_TOKENS);
    private static final String INPUTTER = "opal-test@dev.platform.hmcts.net";
    private static final String CHECKER = "opal-test-10@dev.platform.hmcts.net";
    private final DraftCasefileActions actions;
    private final DraftCasefileRequestFactory requests;
    private final DraftCasefilePoller poller;
    private final Function<String, String> config;
    private final Function<String, String> tokens;
    private String creatorToken;
    private String checkerToken;
    private String marker;
    private Long id;
    private boolean createAttempted;
    private boolean unknownCreate;
    private boolean failureFixture;
    private boolean pollingAttempted;
    private JsonNode approval;
    private String approvalEtag;
    private Response terminalResponse;
    private JsonNode terminal;
    private String terminalEtag;

    public PublishDraftCasefileStepDef() {
        this(new DraftCasefileActions(), new DraftCasefileRequestFactory(), new DraftCasefilePoller(),
            System::getenv, user -> {
                new BearerTokenStepDef().useTestUser(user);
                return BearerTokenStepDef.getToken();
            });
    }

    PublishDraftCasefileStepDef(DraftCasefileActions actions, DraftCasefileRequestFactory requests,
                              DraftCasefilePoller poller, Function<String, String> config,
                              Function<String, String> tokens) {
        this.actions = actions;
        this.requests = requests;
        this.poller = poller;
        this.config = config;
        this.tokens = tokens;
    }

    @Before("@PO10621")
    public void resetScenario() {
        clear();
        marker = "E2E-" + UUID.randomUUID().toString().replace("-", "").substring(0, 16);
    }

    @Given("a new publication casefile with {string} is independently approved")
    public void approvedCasefile(String minors) {
        require(Set.of("none", "two").contains(minors), "Publication minor creditor fixture must be supported");
        prepare(minors, false);
    }

    @Given("a new unpublishable publication casefile is independently approved")
    public void approvedUnpublishableCasefile() {
        prepare("two", true);
    }

    private void prepare(String minors, boolean unpublishable) {
        require(marker != null && !createAttempted && creatorToken == null,
            "Each publication scenario requires one fresh casefile");
        safe(() -> {
            String inputterUser = configured("RM_DRAFT_CASEFILE_INPUTTER_USER", INPUTTER);
            String checkerUser = configured("RM_DRAFT_CASEFILE_CHECKER_USER", CHECKER);
            require(!inputterUser.equalsIgnoreCase(checkerUser),
                "Publication requires different configured inputter and checker users");
            // Capture the ThreadLocal value immediately, before obtaining the independent checker's token.
            creatorToken = token(inputterUser);
            Actor creator = actor(creatorToken, 21);
            checkerToken = token(checkerUser);
            Actor checker = actor(checkerToken, 22);
            require(!creator.id.equals(checker.id), "Publication requires independent Business Unit identities");
            failureFixture = unpublishable;
            String request = unpublishable ? requests.unpublishable(marker)
                : "two".equals(minors) ? requests.withMinorCreditors(marker) : requests.valid(marker);
            createAttempted = true;
            unknownCreate = true;
            Response created = call(() -> actions.create(creatorToken, request));
            require(created.statusCode() == 201, "Publication setup creation requires HTTP 201");
            JsonNode post = parse(created.asString());
            JsonNode createdId = post.path("draft_casefile_id");
            require(createdId.isIntegralNumber() && createdId.canConvertToLong() && createdId.longValue() > 0,
                "Created publication casefile requires a positive Long ID");
            // Keep this ID even if later metadata or assertions fail; never search for an unknown create.
            id = createdId.longValue();
            unknownCreate = false;
            require(jsonType(created) && version(created.header("ETag")) == 0,
                "Publication creation requires application/json and initial version zero");
            require(creator.id.equals(post.path("submitted_by").textValue())
                && creator.name.equals(post.path("submitted_by_name").textValue()),
                "POST submitter must match the resolved creator Business Unit identity");
            Response submitted = call(() -> actions.get(creatorToken, id));
            DraftCasefileRetrievalAssertions.submitted(submitted, request, post);
            require(version(submitted.header("ETag")) == 0
                && "Submitted".equals(parse(submitted.asString()).path("casefile_status_name").textValue()),
                "Publication submission baseline requires initial version and Submitted label");
            JsonNode before = parse(submitted.asString());
            String decision = JSON.createObjectNode().put("business_unit_id", 44)
                .put("casefile_status", "PUBLISHING_PENDING").toString();
            Response decided = call(() -> actions.decide(checkerToken, id, decision, submitted.header("ETag")));
            JsonNode approved = DraftCasefileDecisionAssertions.decided(decided, before, "PUBLISHING_PENDING", null,
                checker.id, checker.name);
            require(jsonType(decided) && version(decided.header("ETag")) > version(submitted.header("ETag")),
                "Approval requires application/json and an advanced strong ETag");
            require("Publishing pending".equals(approved.path("casefile_status_name").textValue())
                && !approved.path("validated_by").equals(approved.path("submitted_by")),
                "Approval requires the pending label and an independent validation identity");
            approval = approved;
            approvalEtag = decided.header("ETag");
        });
    }

    @When("the publication consumer publishes the owned casefile")
    public void consumerPublishes() {
        observe(false);
    }

    @When("the publication consumer records terminal failure for the owned casefile")
    public void consumerRecordsFailure() {
        observe(true);
    }

    private void observe(boolean failure) {
        require(approval != null && id != null && failureFixture == failure && !pollingAttempted,
            "Publication polling requires the matching approved owned casefile and must not replay");
        pollingAttempted = true;
        safe(() -> terminalResponse = poller.await(() -> call(() -> actions.get(creatorToken, id)),
            failure ? "PUBLISHING_FAILED" : "PUBLISHED"));
    }

    @Then("all publication identities and approval history are available on a stable read")
    public void assertPublished() {
        verifyTerminal(false);
    }

    @Then("failed publication preserves its approval snapshot and history on a stable read")
    public void assertFailed() {
        verifyTerminal(true);
    }

    private void verifyTerminal(boolean failure) {
        require(terminalResponse != null && failureFixture == failure, "A matching terminal publication is required");
        safe(() -> {
            terminal = failure ? DraftCasefilePublicationAssertions.failed(terminalResponse, approval, approvalEtag)
                : DraftCasefilePublicationAssertions.published(terminalResponse, approval, approvalEtag);
            terminalEtag = terminalResponse.header("ETag");
            DraftCasefilePublicationAssertions.stable(call(() -> actions.get(creatorToken, id)),
                terminal, terminalEtag);
        });
    }

    private Actor actor(String bearer, int permissionRequired) {
        Response response = call(() -> actions.userState(bearer));
        require(response.statusCode() == 200 && jsonType(response), "User state requires HTTP 200 application/json");
        JsonNode state = parse(response.asString());
        require(state.path("name").isTextual() && !state.path("name").textValue().isBlank(),
            "User state requires a nonblank actor name");
        require(state.path("domains").isObject(), "User state requires a domains object");
        JsonNode maintenance = state.at("/domains/maintenance");
        JsonNode units = maintenance.path("business_unit_users");
        require(maintenance.isObject() && units.isArray(), "User state requires maintenance Business Unit users");
        Actor actor = new Actor();
        actor.name = state.path("name").textValue();
        int matches = 0;
        boolean authorised = false;
        for (JsonNode unit : units) {
            require(unit.isObject() && unit.path("business_unit_id").isIntegralNumber()
                && unit.path("business_unit_id").canConvertToInt() && unit.path("business_unit_id").intValue() > 0
                && unit.path("business_unit_user_id").isTextual()
                && !unit.path("business_unit_user_id").textValue().isBlank() && unit.path("permissions").isArray(),
                "User state Business Unit identity or permission shape is invalid");
            Set<Integer> permissions = new HashSet<>();
            for (JsonNode permission : unit.path("permissions")) {
                JsonNode permissionId = permission.path("permission_id");
                require(permission.isObject() && permissionId.isIntegralNumber() && permissionId.canConvertToInt()
                    && permissionId.intValue() > 0, "User state permission shape is invalid");
                require(permissions.add(permissionId.intValue()), "User state permissions are ambiguous");
            }
            if (unit.path("business_unit_id").intValue() == 44) {
                matches++;
                actor.id = unit.path("business_unit_user_id").textValue();
                authorised = permissions.contains(permissionRequired);
            }
        }
        require(matches == 1, "User state requires exactly one owning Business Unit identity");
        require(authorised, "Actor requires its owning Business Unit role permission");
        return actor;
    }

    @After("@PO10621")
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
                scenario.attach(evidence, "text/plain", "PO-10621 cleanup failure");
            } catch (RuntimeException | AssertionError exception) {
                throw new AssertionError(evidence + "; cleanup evidence attachment failed");
            }
        } finally {
            clear();
        }
    }

    private String cleanupEvidence() {
        if (id == null) {
            return unknownCreate ? "Publication cleanup has no captured ID for marker " + marker
                + "; create must not replay; manual recovery required" : null;
        }
        String evidence = "Publication cleanup failed for ID " + id + " with marker " + marker;
        try {
            Response response = actions.delete(creatorToken, id, marker);
            if (response != null && response.statusCode() == 204) {
                return null;
            }
            return evidence + (response == null ? "; request error: no response" : "; status " + response.statusCode());
        } catch (RuntimeException exception) {
            return evidence + "; request error";
        }
    }

    private void clear() {
        creatorToken = null;
        checkerToken = null;
        marker = null;
        id = null;
        createAttempted = false;
        unknownCreate = false;
        failureFixture = false;
        pollingAttempted = false;
        approval = null;
        approvalEtag = null;
        terminalResponse = null;
        terminal = null;
        terminalEtag = null;
    }

    private String configured(String variable, String fallback) {
        String value = config.apply(variable);
        return value == null || value.isBlank() ? fallback : value;
    }

    private String token(String user) {
        String value = tokens.apply(user);
        require(value != null && !value.isBlank(), "Publication actor requires a bearer token");
        return value;
    }

    private static Response call(Supplier<Response> request) {
        try {
            Response response = request.get();
            require(response != null, "Publication request returned no response");
            return response;
        } catch (RuntimeException exception) {
            throw new AssertionError("Publication request failed");
        }
    }

    private static void safe(CheckedAction action) {
        try {
            action.run();
        } catch (IOException | RuntimeException exception) {
            throw new AssertionError("Publication setup or observation failed");
        }
    }

    private static JsonNode parse(String body) {
        try {
            JsonNode parsed = JSON.readTree(body);
            require(parsed != null && parsed.isObject(), "Publication evidence requires a JSON object");
            return parsed;
        } catch (IOException | RuntimeException exception) {
            throw new AssertionError("Publication evidence requires valid JSON");
        }
    }

    private static boolean jsonType(Response response) {
        return response.contentType() != null
            && "application/json".equalsIgnoreCase(response.contentType().split(";", 2)[0].trim());
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

    @FunctionalInterface
    private interface CheckedAction {
        void run() throws IOException;
    }

    // No generated toString: actual user details remain scenario-local and never enter evidence.
    private static final class Actor {
        private String id;
        private String name;
    }
}
