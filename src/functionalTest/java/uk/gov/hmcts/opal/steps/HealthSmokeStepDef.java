package uk.gov.hmcts.opal.steps;

import io.cucumber.java.en.Then;
import io.cucumber.java.en.When;
import io.restassured.response.Response;

import static org.junit.jupiter.api.Assertions.assertEquals;

public class HealthSmokeStepDef extends BaseStepDef {

    private Response response;

    @When("I request the Maintenance service health status")
    public void requestHealth() {
        response = getWithoutBearer("/health");
    }

    @Then("the Maintenance service reports as up")
    public void reportsAsUp() {
        assertEquals(200, response.statusCode());
        assertEquals("UP", response.jsonPath().getString("status"));
    }
}
