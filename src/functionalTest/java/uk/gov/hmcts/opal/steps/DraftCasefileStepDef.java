package uk.gov.hmcts.opal.steps;

import static uk.gov.hmcts.opal.assertions.DraftCasefileAssertions.assertCreated;
import static uk.gov.hmcts.opal.assertions.DraftCasefileAssertions.assertFailureProblem;
import static uk.gov.hmcts.opal.assertions.DraftCasefileAssertions.assertPermissionProblem;
import static uk.gov.hmcts.opal.assertions.DraftCasefileAssertions.assertReferenceProblem;

import io.cucumber.java.After;
import io.cucumber.java.Before;
import io.cucumber.java.Scenario;
import io.cucumber.java.en.Given;
import io.cucumber.java.en.Then;
import io.cucumber.java.en.When;
import io.restassured.response.Response;
import java.io.IOException;
import uk.gov.hmcts.opal.actions.DraftCasefileActions;
import uk.gov.hmcts.opal.data.DraftCasefileRequestFactory;
import uk.gov.hmcts.opal.data.DraftCasefileScenarioState;
import uk.gov.hmcts.opal.data.InvalidDraftReference;

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
            state.cleanupToken(token);
        }
    }

    @Then("the submitted Draft Casefile response is returned")
    public void assertSubmitted() throws IOException {
        assertCreated(state.latestResponse());
    }

    @Then("the Draft Casefile permission failure is returned")
    public void assertPermissionFailure() throws IOException {
        assertPermissionProblem(state.latestResponse(), state.marker());
    }

    @Then("^the invalid (unknown application|inactive country|historical country) Draft Casefile response is returned$")
    public void assertInvalidReference(String ignoredReference) throws IOException {
        assertReferenceProblem(state.latestResponse(), state.marker());
    }

    @Then("the correlated Draft Casefile server failure is returned")
    public void assertCorrelatedServerFailure() throws IOException {
        assertFailureProblem(state.latestResponse(), state.marker());
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
            cleanup = actions.delete(state.cleanupToken(), state.createdId(), state.marker());
        } catch (RuntimeException exception) {
            return "Draft cleanup failed for ID " + state.createdId() + " with marker "
                + state.marker() + " with a request error";
        }
        if (cleanup.statusCode() != 204) {
            return "Draft cleanup failed for ID " + state.createdId() + " with marker " + state.marker()
                + " with status " + cleanup.statusCode();
        }
        return null;
    }
}
