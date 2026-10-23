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
import java.util.UUID;
import java.util.function.Function;
import java.util.function.Supplier;
import uk.gov.hmcts.opal.actions.DraftCasefileActions;
import uk.gov.hmcts.opal.actions.DraftCasefilePoller;
import uk.gov.hmcts.opal.assertions.DraftCasefileRetrievalAssertions;
import uk.gov.hmcts.opal.data.DraftCasefileRequestFactory;

import static org.junit.jupiter.api.Assertions.assertTrue;

public class GetDraftCasefileStepDef {
    private static final ObjectMapper JSON = new ObjectMapper()
        .enable(DeserializationFeature.FAIL_ON_TRAILING_TOKENS);
    private static final String DEFAULT_INPUTTER = "opal-test@dev.platform.hmcts.net";
    private final DraftCasefileActions actions;
    private final DraftCasefileRequestFactory requests;
    private final DraftCasefilePoller poller;
    private final Function<String, String> config;
    private final Function<String, String> tokens;
    private String marker;
    private String request;
    private Long capturedId;
    private String ownerToken;
    private String ownerUser;
    private boolean unknownOwnedCreate;
    private JsonNode created;
    private JsonNode approved;
    private Response latestResponse;

    public GetDraftCasefileStepDef() {
        this(new DraftCasefileActions(), new DraftCasefileRequestFactory(), new DraftCasefilePoller(),
            System::getenv, user -> {
                new BearerTokenStepDef().useTestUser(user);
                return BearerTokenStepDef.getToken();
            });
    }

    GetDraftCasefileStepDef(DraftCasefileActions actions, DraftCasefileRequestFactory requests,
                           DraftCasefilePoller poller, Function<String, String> config,
                           Function<String, String> tokens) {
        this.actions = actions;
        this.requests = requests;
        this.poller = poller;
        this.config = config;
        this.tokens = tokens;
    }

    @Before("@PO10618")
    public void resetScenario() {
        clear();
        marker = "E2E-" + UUID.randomUUID().toString().replace("-", "").substring(0, 16);
    }

    @Given("a new scenario-owned complete Draft Casefile is submitted")
    public void submitComplete() {
        submit(requests.withMinorCreditors(marker));
    }

    @Given("a new scenario-owned unpublishable Draft Casefile is submitted")
    public void submitUnpublishable() {
        submit(requests.unpublishable(marker));
    }

    private void submit(String body) {
        request = body;
        ownerUser = config.apply("RM_DRAFT_CASEFILE_INPUTTER_USER");
        if (ownerUser == null || ownerUser.isBlank()) {
            ownerUser = DEFAULT_INPUTTER;
        }
        ownerToken = token(ownerUser);
        // An interrupted create may already have committed. Never replay an ambiguous mutation.
        unknownOwnedCreate = true;
        latestResponse = call(() -> actions.create(ownerToken, request));
        if (latestResponse.statusCode() != 201) {
            unknownOwnedCreate = false;
            throw new AssertionError("Scenario Draft Casefile creation requires HTTP 201");
        }
        JsonNode parsed = parse(latestResponse);
        JsonNode id = parsed.path("draft_casefile_id");
        assertTrue(id.isIntegralNumber() && id.canConvertToLong() && id.longValue() > 0,
            "Created Draft Casefile requires a positive Long ID");
        capturedId = id.longValue();
        unknownOwnedCreate = false;
        created = parsed;
        assertTrue("SUBMITTED".equals(created.path("casefile_status").textValue()),
            "Created Draft Casefile must be SUBMITTED");
        assertTrue(created.path("business_unit_id").isIntegralNumber()
            && created.path("business_unit_id").intValue() == 44, "Created Business Unit must be 44");
        for (String field : new String[] {"created_date", "submitted_by", "submitted_by_name", "casefile_type",
            "casefile_status_date", "casefile_snapshot", "timeline_data"}) {
            assertTrue(created.hasNonNull(field), "Created baseline metadata must be present");
        }
        assertTrue(latestResponse.contentType() != null
            && latestResponse.contentType().startsWith("application/json"), "Creation requires application/json");
        assertTrue("\"0\"".equals(latestResponse.header("ETag")), "Creation requires initial ETag");
    }

    @Given("a different authorised checker approves the scenario Draft Casefile")
    public void approve() {
        String checker = configuredUser("RM_DRAFT_CASEFILE_CHECKER_USER", "opal-test-10@dev.platform.hmcts.net");
        assertTrue(!checker.equalsIgnoreCase(ownerUser), "Checker must differ from the inputter");
        Response beforeResponse = call(() -> actions.get(ownerToken, capturedId));
        JsonNode before = read(beforeResponse);
        String etag = beforeResponse.header("ETag");
        String checkerToken = token(checker);
        String decision = JSON.createObjectNode().put("casefile_status", "PUBLISHING_PENDING")
            .set("business_unit_id", before.path("business_unit_id")).toString();
        latestResponse = call(() -> actions.decide(checkerToken, capturedId, decision, etag));
        approved = read(latestResponse);
        assertTrue(!etag.equals(latestResponse.header("ETag")), "Approval must change the ETag");
        check(() -> DraftCasefileRetrievalAssertions.approved(latestResponse, before));
        assertTrue(!approved.path("validated_by").equals(approved.path("submitted_by")),
            "Checker identity must differ from the submitter");
    }

    @When("the owning user retrieves the scenario Draft Casefile")
    public void retrieveOwner() {
        latestResponse = call(() -> actions.get(ownerToken, capturedId));
    }

    @When("the owner retrieves the scenario Draft Casefile after successful publication")
    public void retrievePublished() {
        latestResponse = poller.await(() -> actions.get(ownerToken, capturedId), "PUBLISHED");
    }

    @When("the owner retrieves the scenario Draft Casefile after failed publication")
    public void retrieveFailed() {
        latestResponse = poller.await(() -> actions.get(ownerToken, capturedId), "PUBLISHING_FAILED");
    }

    @When("a user without either owning Business Unit permission retrieves the scenario Draft Casefile")
    public void retrieveDenied() {
        String reader = configuredUser("RM_DRAFT_CASEFILE_DENIED_USER", "opal-test-2@dev.platform.hmcts.net");
        assertTrue(!reader.equalsIgnoreCase(ownerUser), "Denied reader must differ from the inputter");
        String readerToken = token(reader);
        latestResponse = call(() -> actions.get(readerToken, capturedId));
    }

    @Given("the owner removes the scenario Draft Casefile")
    public void removeOwned() {
        Response removed = call(() -> actions.delete(ownerToken, capturedId, marker));
        assertTrue(removed.statusCode() == 204, "Owned Draft Casefile removal requires HTTP 204");
    }

    @Then("the complete submitted Draft Casefile is returned")
    public void assertSubmitted() {
        check(() -> DraftCasefileRetrievalAssertions.submitted(latestResponse, request, created));
    }

    @Then("all published account identities and the approval history are returned")
    public void assertPublished() {
        check(() -> DraftCasefileRetrievalAssertions.published(latestResponse, approved));
    }

    @Then("the failed publication retains validation and approval history without account identities")
    public void assertFailed() {
        check(() -> DraftCasefileRetrievalAssertions.failed(latestResponse, approved));
    }

    @Then("a safe missing Draft Casefile response is returned")
    public void assertMissing() {
        check(() -> DraftCasefileRetrievalAssertions.safeProblem(latestResponse, 404, marker));
    }

    @Then("a safe forbidden Draft Casefile response is returned")
    public void assertForbidden() {
        check(() -> DraftCasefileRetrievalAssertions.safeProblem(latestResponse, 403, marker));
    }

    @After("@PO10618")
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
                scenario.attach(evidence, "text/plain", "PO-10618 cleanup failure");
            } catch (RuntimeException exception) {
                throw new AssertionError(evidence + "; cleanup evidence attachment failed");
            }
        } finally {
            clear();
        }
    }

    private String cleanupEvidence() {
        if (capturedId == null) {
            return unknownOwnedCreate ? "Draft cleanup has unknown owned create ID with marker " + marker
                + "; operator follow-up required" : null;
        }
        String identity = "Draft cleanup failed for ID " + capturedId + " with marker " + marker;
        try {
            Response response = actions.delete(ownerToken, capturedId, marker);
            return response.statusCode() == 204 ? null : identity + " with status " + response.statusCode();
        } catch (RuntimeException exception) {
            return identity + " with a request error";
        }
    }

    private String configuredUser(String variable, String defaultUser) {
        String value = config.apply(variable);
        return value == null || value.isBlank() ? defaultUser : value;
    }

    private String token(String user) {
        try {
            String value = tokens.apply(user);
            assertTrue(value != null && !value.isBlank(), "Functional access token must be nonblank");
            return value;
        } catch (RuntimeException exception) {
            throw new AssertionError("Functional access token resolution failed");
        }
    }

    private static Response call(Supplier<Response> action) {
        try {
            Response response = action.get();
            assertTrue(response != null, "Draft Casefile request returned no response");
            return response;
        } catch (RuntimeException exception) {
            throw new AssertionError("Draft Casefile request failed");
        }
    }

    private static JsonNode parse(Response response) {
        try {
            JsonNode value = JSON.readTree(response.asString());
            assertTrue(value != null && value.isObject(), "Draft Casefile requires a JSON object");
            return value;
        } catch (IOException | RuntimeException exception) {
            throw new AssertionError("Draft Casefile requires valid JSON");
        }
    }

    private static JsonNode read(Response response) {
        try {
            return DraftCasefileRetrievalAssertions.read(response);
        } catch (IOException exception) {
            throw new AssertionError("Draft Casefile retrieval requires valid JSON");
        }
    }

    private static void check(JsonCheck assertion) {
        try {
            assertion.run();
        } catch (IOException exception) {
            throw new AssertionError("Draft Casefile assertions require valid JSON");
        }
    }

    @FunctionalInterface
    private interface JsonCheck {
        void run() throws IOException;
    }

    private void clear() {
        marker = null;
        request = null;
        capturedId = null;
        ownerToken = null;
        ownerUser = null;
        unknownOwnedCreate = false;
        created = null;
        approved = null;
        latestResponse = null;
    }
}
