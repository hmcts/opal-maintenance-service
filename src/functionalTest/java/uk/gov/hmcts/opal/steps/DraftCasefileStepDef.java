package uk.gov.hmcts.opal.steps;

import io.cucumber.java.After;
import io.cucumber.java.Before;
import io.cucumber.java.Scenario;
import io.cucumber.java.en.Given;
import io.cucumber.java.en.Then;
import io.cucumber.java.en.When;
import io.restassured.response.Response;
import uk.gov.hmcts.opal.actions.DraftCasefileActions;
import uk.gov.hmcts.opal.data.DraftCasefileRequestFactory;
import uk.gov.hmcts.opal.data.DraftCasefileScenarioState;
import uk.gov.hmcts.opal.data.InvalidDraftReference;

import java.io.IOException;

import static uk.gov.hmcts.opal.assertions.DraftCasefileAssertions.assertCreated;
import static uk.gov.hmcts.opal.assertions.DraftCasefileAssertions.assertFailureProblem;
import static uk.gov.hmcts.opal.assertions.DraftCasefileAssertions.assertNoMarkerMatches;
import static uk.gov.hmcts.opal.assertions.DraftCasefileAssertions.assertPermissionProblem;
import static uk.gov.hmcts.opal.assertions.DraftCasefileAssertions.assertReferenceProblem;
import static uk.gov.hmcts.opal.assertions.DraftCasefileAssertions.assertTechnicalMetadata;

public class DraftCasefileStepDef {

    private final DraftCasefileActions actions;
    private final DraftCasefileRequestFactory requests;
    private final DraftCasefileScenarioState state;
    private String requestBody;

    public DraftCasefileStepDef() {
        this(new DraftCasefileActions(), new DraftCasefileRequestFactory(), new DraftCasefileScenarioState());
    }

    DraftCasefileStepDef(DraftCasefileActions actions, DraftCasefileRequestFactory requests,
                         DraftCasefileScenarioState state) {
        this.actions = actions;
        this.requests = requests;
        this.state = state;
    }

    @Before("@PO10287")
    public void resetScenario() {
        state.reset();
        requestBody = null;
    }

    @Given("I prepare a valid uniquely marked Draft Casefile")
    public void prepareValid() {
        requestBody = requests.valid(state.marker());
    }

    @Given("^I prepare a uniquely marked Draft Casefile with an "
        + "(unknown application|inactive country|historical country)$")
    public void prepareInvalidReference(String reference) {
        requestBody = requests.withInvalidReference(state.marker(), InvalidDraftReference.fromFeatureValue(reference));
    }

    @When("I submit the Draft Casefile")
    public void submit() {
        submitWithFailureMode(null);
    }

    @When("I submit the Draft Casefile with a post-save testing failure")
    public void submitWithPostSaveFailure() {
        submitWithFailureMode("after-save");
    }

    private void submitWithFailureMode(String failureMode) {
        String token = BearerTokenStepDef.getToken();
        Response response = actions.create(token, requestBody, failureMode);
        state.latestResponse(response);
        if (response.statusCode() == 201) {
            state.createdId(response.jsonPath().getLong("draft_casefile_id"));
            state.createdResponse(response);
            state.cleanupToken(token);
        }
    }

    @Then("the submitted Draft Casefile response is returned")
    public void assertSubmitted() throws IOException {
        assertCreated(state.latestResponse());
    }

    @Then("the stored Draft Casefile technical outcome is observable")
    public void assertStoredTechnicalOutcome() throws IOException {
        Response metadata = actions.inspect(BearerTokenStepDef.getToken(), state.createdId());
        assertTechnicalMetadata(metadata, state.createdResponse());
    }

    @Then("the Draft Casefile permission failure is returned")
    public void assertPermissionFailure() throws IOException {
        assertPermissionProblem(state.latestResponse(), state.marker());
    }

    @Then("^the invalid (unknown application|inactive country|historical country) Draft Casefile response is returned$")
    public void assertInvalidReference(String reference) throws IOException {
        String detail = switch (InvalidDraftReference.fromFeatureValue(reference)) {
            case UNKNOWN_APPLICATION -> "Application must identify an active Maintenance Application";
            case INACTIVE_COUNTRY, HISTORICAL_COUNTRY -> "Country must be active";
        };
        assertReferenceProblem(state.latestResponse(), state.marker(), detail);
    }

    @Then("the correlated Draft Casefile server failure is returned")
    public void assertCorrelatedServerFailure() throws IOException {
        assertFailureProblem(state.latestResponse(), state.marker());
    }

    @Then("no Draft Casefile exists for the scenario marker")
    public void assertNoDraftForMarker() throws IOException {
        Response lookup = actions.findByMarker(BearerTokenStepDef.getToken(), state.marker());
        assertNoMarkerMatches(lookup);
    }

    @After("@PO10287")
    public void deleteCreatedDraft(Scenario scenario) {
        try {
            if (state.createdId() == null) {
                return;
            }
            String evidence = cleanupEvidence();
            if (evidence == null) {
                return;
            }
            if (!scenario.isFailed()) {
                throw new AssertionError(evidence);
            }
            try {
                scenario.attach(evidence, "text/plain", "PO-10287 cleanup failure");
            } catch (RuntimeException attachmentFailure) {
                return;
            }
        } finally {
            state.clearAfterCleanup();
            requestBody = null;
        }
    }

    private String cleanupEvidence() {
        Response cleanup;
        try {
            cleanup = actions.delete(state.cleanupToken(), state.createdId());
        } catch (RuntimeException exception) {
            return "Draft cleanup failed for ID " + state.createdId() + " with a request error";
        }
        if (cleanup.statusCode() != 204) {
            return "Draft cleanup failed for ID " + state.createdId()
                + " with status " + cleanup.statusCode();
        }
        try {
            Response lookup = actions.findByMarker(state.cleanupToken(), state.marker());
            assertNoMarkerMatches(lookup);
            return null;
        } catch (IOException | RuntimeException | AssertionError exception) {
            return "Draft cleanup verification failed for ID " + state.createdId();
        }
    }
}
