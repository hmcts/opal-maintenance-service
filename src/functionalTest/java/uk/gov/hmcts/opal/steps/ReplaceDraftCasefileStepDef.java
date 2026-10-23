package uk.gov.hmcts.opal.steps;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import io.cucumber.java.en.Given;
import io.cucumber.java.en.When;
import io.cucumber.java.en.Then;
import io.restassured.response.Response;

import java.io.IOException;

import static org.assertj.core.api.Assertions.assertThat;

public class ReplaceDraftCasefileStepDef extends BaseStepDef {

    private static final ObjectMapper JSON = new ObjectMapper();
    private String path;
    private String originalEtag;
    private String newEtag;
    private JsonNode original;
    private JsonNode committed;
    private ObjectNode replacement;
    private Response response;

    @Given("an approved synthetic rejected draft is available for replacement")
    public void rejectedFixture() throws IOException {
        loadFixture();
        assertThat(original.path("casefile_status").asText()).isEqualTo("REJECTED");
    }

    @Given("an approved synthetic draft is available for unauthenticated replacement")
    public void unauthenticatedFixture() throws IOException {
        loadFixture();
    }

    private void loadFixture() throws IOException {
        String id = requiredEnvironment("RM_REJECTED_DRAFT_CASEFILE_ID");
        if (!id.matches("[1-9][0-9]*")) {
            throw new IllegalStateException("RM_REJECTED_DRAFT_CASEFILE_ID must be a positive draft identifier");
        }
        path = "/draft-casefiles/" + id;
        new BearerTokenStepDef().useTestUser(requiredEnvironment("RM_DRAFT_CASEFILE_FUNCTIONAL_USER"));
        Response retrieved = getWithBearer(path, BearerTokenStepDef.getToken());
        assertThat(retrieved.statusCode()).isEqualTo(200);
        originalEtag = retrieved.header("ETag");
        assertThat(originalEtag).matches("\"[0-9]+\"");
        original = JSON.readTree(retrieved.asString());
        replacement = JSON.createObjectNode();
        replacement.set("business_unit_id", original.get("business_unit_id"));
        replacement.set("casefile", original.get("casefile").deepCopy());
        ((ObjectNode) replacement.at("/casefile/respondent_account"))
            .put("account_comment", "Synthetic functional correction");
    }

    @When("I replace the draft using its current ETag")
    public void replace() {
        response = putWithBearer(path, BearerTokenStepDef.getToken(), replacement.toString(), originalEtag);
    }

    @Then("the corrected draft is resubmitted with preserved history and a new ETag")
    public void confirmsResubmission() throws IOException {
        assertThat(response.statusCode()).isEqualTo(200);
        newEtag = response.header("ETag");
        assertThat(newEtag).matches("\"[0-9]+\"").isNotEqualTo(originalEtag);
        JsonNode body = JSON.readTree(response.asString());
        assertThat(body.path("casefile_status").asText()).isEqualTo("RESUBMITTED");
        assertThat(body.get("casefile")).isEqualTo(replacement.get("casefile"));
        assertThat(body.get("created_date")).isEqualTo(original.get("created_date"));
        JsonNode timeline = body.get("timeline_data");
        assertThat(timeline.size()).isEqualTo(original.get("timeline_data").size() + 1);
        for (int index = 0; index < original.get("timeline_data").size(); index++) {
            assertThat(timeline.get(index)).isEqualTo(original.get("timeline_data").get(index));
        }
        assertThat(timeline.get(timeline.size() - 1).path("status").asText()).isEqualTo("Resubmitted");
        Response read = getWithBearer(path, BearerTokenStepDef.getToken());
        assertThat(read.statusCode()).isEqualTo(200);
        assertThat(read.header("ETag")).isEqualTo(newEtag);
        committed = JSON.readTree(read.asString());
        assertThat(committed).isEqualTo(body);
    }

    @Then("reusing the original ETag is rejected without changing the draft")
    public void rejectsOldVersion() throws IOException {
        Response stale = putWithBearer(path, BearerTokenStepDef.getToken(), replacement.toString(), originalEtag);
        assertThat(stale.statusCode()).isEqualTo(409);
        Response read = getWithBearer(path, BearerTokenStepDef.getToken());
        assertThat(read.statusCode()).isEqualTo(200);
        assertThat(read.header("ETag")).isEqualTo(newEtag);
        assertThat(JSON.readTree(read.asString())).isEqualTo(committed);
    }

    @When("I replace the draft without authentication")
    public void replaceUnauthenticated() {
        response = putWithoutBearer(path, replacement.toString(), originalEtag);
    }

    @Then("the replacement is unauthorized")
    public void rejectsUnauthenticated() {
        assertThat(response.statusCode()).isEqualTo(401);
    }

    private static String requiredEnvironment(String name) {
        String value = System.getenv(name);
        if (value == null || value.isBlank()) {
            throw new IllegalStateException("Required synthetic fixture input is missing: " + name);
        }
        return value;
    }
}
