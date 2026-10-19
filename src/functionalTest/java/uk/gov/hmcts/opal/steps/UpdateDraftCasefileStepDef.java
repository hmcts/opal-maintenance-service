package uk.gov.hmcts.opal.steps;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.cucumber.java.en.Given;
import io.cucumber.java.en.Then;
import io.cucumber.java.en.When;
import io.restassured.response.Response;

import java.io.IOException;

import static org.assertj.core.api.Assertions.assertThat;

public class UpdateDraftCasefileStepDef extends BaseStepDef {
    private static final ObjectMapper JSON = new ObjectMapper();
    private String path;
    private String originalEtag;
    private String target;
    private JsonNode original;
    private String request;
    private Response response;

    @Given("an approved synthetic submitted draft is available for {string}")
    public void submittedDraft(String decision) throws IOException {
        target = decision;
        loadFixture("RM_CHECKER_DRAFT_ID_" + decision, "RM_DRAFT_CASEFILE_CHECKER_USER");
    }

    @Given("an approved synthetic draft was submitted by the checker")
    public void selfCheckFixture() throws IOException {
        target = "REJECTED";
        loadFixture("RM_CHECKER_SELF_DRAFT_ID", "RM_DRAFT_CASEFILE_CHECKER_USER");
    }

    private void loadFixture(String idVariable, String userVariable) throws IOException {
        String id = requiredEnvironment(idVariable);
        if (!id.matches("[1-9][0-9]*")) {
            throw new IllegalStateException(idVariable + " must be a positive synthetic draft identifier");
        }
        path = "/draft-casefiles/" + id;
        new BearerTokenStepDef().useTestUser(requiredEnvironment(userVariable));
        Response read = getWithBearer(path, BearerTokenStepDef.getToken());
        assertThat(read.statusCode()).isEqualTo(200);
        originalEtag = read.header("ETag");
        original = JSON.readTree(read.asString());
        assertThat(original.path("casefile_status").asText()).isIn("SUBMITTED", "RESUBMITTED");
        var body = JSON.createObjectNode().put("casefile_status", target);
        body.set("business_unit_id", original.get("business_unit_id"));
        if (!target.equals("PUBLISHING_PENDING")) {
            body.put("status_message", "Synthetic functional checker reason");
        }
        request = body.toString();
    }

    @When("the checker records the decision with the current ETag")
    public void decide() {
        response = patchWithBearer(path, BearerTokenStepDef.getToken(), request, originalEtag);
    }

    @Then("the draft records {string} with preserved content and a new ETag")
    public void confirmsDecision(String timelineStatus) throws IOException {
        assertThat(response.statusCode()).isEqualTo(200);
        assertThat(response.header("ETag")).matches("\"[0-9]+\"").isNotEqualTo(originalEtag);
        JsonNode saved = JSON.readTree(response.asString());
        assertThat(saved.path("casefile_status").asText()).isEqualTo(target);
        for (String field : new String[]{"casefile", "casefile_snapshot", "created_date", "submitted_by"}) {
            assertThat(saved.get(field)).as(field).isEqualTo(original.get(field));
        }
        JsonNode history = saved.get("timeline_data");
        int previous = original.get("timeline_data").size();
        assertThat(history.size()).isEqualTo(previous + 1);
        for (int index = 0; index < previous; index++) {
            assertThat(history.get(index)).isEqualTo(original.get("timeline_data").get(index));
        }
        assertThat(history.get(previous).path("status").asText()).isEqualTo(timelineStatus);
        Response repeated = patchWithBearer(path, BearerTokenStepDef.getToken(), request, originalEtag);
        assertThat(repeated.statusCode()).isEqualTo(409);
        Response retrieved = getWithBearer(path, BearerTokenStepDef.getToken());
        assertThat(retrieved.statusCode()).isEqualTo(200);
        assertThat(retrieved.header("ETag")).isEqualTo(response.header("ETag"));
        assertThat(JSON.readTree(retrieved.asString())).isEqualTo(saved);
    }

    @Then("the self-check is forbidden without changing the draft")
    public void confirmsSelfCheckDenied() throws IOException {
        assertThat(response.statusCode()).isEqualTo(403);
        Response retrieved = getWithBearer(path, BearerTokenStepDef.getToken());
        assertThat(retrieved.statusCode()).isEqualTo(200);
        assertThat(retrieved.header("ETag")).isEqualTo(originalEtag);
        assertThat(JSON.readTree(retrieved.asString())).isEqualTo(original);
    }

    private static String requiredEnvironment(String name) {
        String value = System.getenv(name);
        if (value == null || value.isBlank()) {
            throw new IllegalStateException("Required synthetic fixture input is missing: " + name);
        }
        return value;
    }
}
