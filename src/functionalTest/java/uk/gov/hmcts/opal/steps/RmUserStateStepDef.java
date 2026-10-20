package uk.gov.hmcts.opal.steps;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.cucumber.java.en.Given;
import io.cucumber.java.en.Then;
import io.cucumber.java.en.When;
import io.restassured.response.Response;
import io.restassured.specification.RequestSpecification;
import net.serenitybdd.rest.SerenityRest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;

import java.io.IOException;
import java.util.Iterator;
import java.util.Set;

public class RmUserStateStepDef extends BaseStepDef {
    private static final ObjectMapper MAPPER = new ObjectMapper();
    private static final String PATH = "/v2/users/0/state";
    private static final int DRAFT_CASEFILE_PERMISSION = 21;
    private static final Set<String> DISCLOSURE_KEYS = Set.of("domains", "businessunitusers", "permissions",
        "userid", "username", "name", "cachename", "stack", "stacktrace", "trace", "exception",
        "exceptionname", "exceptionmessage", "exceptionclass", "exceptiontype", "cause");

    private RmUserStateTestUsers.TestUser selected;
    private short expectedBuId;
    private Response latestResponse;

    @Given("I select the {string} RM User State assignment")
    public void selectAssignment(String outcome) {
        if (!"granted".equals(outcome) && !"denied".equals(outcome)) {
            throw new IllegalArgumentException("Assignment outcome must be granted or denied");
        }
        RmUserStateTestUsers users = RmUserStateTestUsers.fromEnvironment(System.getenv());
        selected = "granted".equals(outcome) ? users.granted() : users.denied();
        expectedBuId = users.businessUnitId();
        latestResponse = null;
        new BearerTokenStepDef().useTestUser(selected.email());
    }

    @When("I request my RM User State")
    public void requestUserState() {
        if (selected == null) {
            throw new IllegalStateException("Select an RM User State assignment before requesting authenticated state");
        }
        latestResponse = requestFrom(userServiceUrl(), BearerTokenStepDef.getToken());
    }

    @When("I request RM User State without authentication")
    public void requestUserStateWithoutAuthentication() {
        latestResponse = requestFrom(userServiceUrl(), null);
    }

    static Response requestFrom(String serviceUrl, String token) {
        RequestSpecification request = userStateRequest();
        if (token != null) {
            request.header(HttpHeaders.AUTHORIZATION, "Bearer " + token);
        }
        return request.when().get(serviceUrl + PATH);
    }

    private static RequestSpecification userStateRequest() {
        return SerenityRest.givenWithNoReporting()
            .config(requestConfig())
            .accept(MediaType.APPLICATION_JSON_VALUE)
            .contentType(MediaType.APPLICATION_JSON_VALUE);
    }

    @Then("my Maintenance Business Unit includes the Draft Casefile permission")
    public void assertGrantedAssignment() throws IOException {
        assertAuthenticatedResponse(true);
    }

    @Then("my Maintenance Business Unit does not grant the Draft Casefile permission")
    public void assertDeniedAssignment() throws IOException {
        assertAuthenticatedResponse(false);
    }

    private void assertAuthenticatedResponse(boolean granted) throws IOException {
        if (selected == null) {
            throw new IllegalStateException("No RM User State assignment selected");
        }
        Response response = latestResponse();
        assertEquals(200, response.statusCode(), "User State request did not succeed");
        assertTrue(isMediaType(response, MediaType.APPLICATION_JSON_VALUE), "Expected User State JSON response");
        assertAssignmentResponse(response.asString(), selected.userId(), expectedBuId, granted);
    }

    static void assertAssignmentResponse(String body, long userId, short buId, boolean granted) throws IOException {
        JsonNode root = MAPPER.readTree(body);
        assertTrue(root != null && root.isObject(), "Expected User State object");
        JsonNode actualUserId = root.path("user_id");
        assertTrue(actualUserId.isIntegralNumber() && actualUserId.canConvertToLong(), "Invalid User State user ID");
        assertTrue(actualUserId.longValue() == userId, "Unexpected User State user ID");
        JsonNode maintenance = root.path("domains").path("maintenance");
        assertTrue(maintenance.isObject(), "Maintenance domain is missing");
        JsonNode assignments = maintenance.path("business_unit_users");
        assertTrue(assignments.isArray() && !assignments.isEmpty(), "Maintenance assignments are missing");
        JsonNode matched = null;
        int matches = 0;
        for (JsonNode assignment : assignments) {
            assertTrue(assignment.isObject(), "Invalid Maintenance assignment");
            JsonNode assignmentBu = assignment.path("business_unit_id");
            assertTrue(assignmentBu.isIntegralNumber() && assignmentBu.canConvertToInt(),
                "Invalid Maintenance Business Unit ID");
            JsonNode permissions = assignment.path("permissions");
            assertTrue(permissions.isArray(), "Maintenance permissions are missing or invalid");
            for (JsonNode permission : permissions) {
                JsonNode permissionId = permission.path("permission_id");
                assertTrue(permissionId.isIntegralNumber() && permissionId.canConvertToInt(),
                    "Invalid Maintenance permission ID");
                if (!granted) {
                    assertFalse(permissionId.intValue() == DRAFT_CASEFILE_PERMISSION,
                        "Draft Casefile permission unexpectedly present in Maintenance");
                }
            }
            if (assignmentBu.intValue() == buId) {
                matched = assignment;
                matches++;
            }
        }
        assertEquals(1, matches, "Expected exactly one Maintenance assignment for the selected Business Unit");
        JsonNode assignmentId = matched.path("business_unit_user_id");
        assertTrue(assignmentId.isTextual() && !assignmentId.asText().isBlank(), "Assignment ID is missing");
        JsonNode permissions = matched.path("permissions");
        if (granted) {
            boolean found = false;
            for (JsonNode permission : permissions) {
                found |= permission.path("permission_id").intValue() == DRAFT_CASEFILE_PERMISSION;
            }
            assertTrue(found, "Draft Casefile permission missing from selected Maintenance assignment");
        } else {
            assertFalse(permissions.isEmpty(), "Denied assignment must retain other Maintenance permissions");
        }
    }

    @Then("my Business Unit assignments and permissions are not disclosed")
    public void assertUnauthorizedUserState() throws IOException {
        Response response = latestResponse();
        assertEquals(401, response.statusCode(), "Expected unauthorized User State response");
        assertTrue(isMediaType(response, MediaType.APPLICATION_PROBLEM_JSON_VALUE), "Expected Problem JSON response");
        JsonNode problem = MAPPER.readTree(response.asString());
        assertTrue(problem != null && problem.isObject(), "Expected Problem JSON object");
        JsonNode status = problem.path("status");
        assertTrue(status.isIntegralNumber() && status.canConvertToInt() && status.intValue() == 401,
            "Invalid Problem status");
        for (String key : new String[]{"type", "title", "detail"}) {
            JsonNode value = problem.path(key);
            assertTrue(value.isTextual() && !value.asText().isBlank(), "Invalid Problem " + key);
        }
        assertNoDisclosureKeys(problem);
    }

    private static void assertNoDisclosureKeys(JsonNode node) {
        if (node.isObject()) {
            Iterator<String> names = node.fieldNames();
            while (names.hasNext()) {
                String name = names.next();
                String canonicalName = name.toLowerCase(java.util.Locale.ROOT).replaceAll("[^a-z0-9]", "");
                assertFalse(DISCLOSURE_KEYS.contains(canonicalName)
                    || canonicalName.startsWith("stack") || canonicalName.startsWith("exception"),
                    "Problem response exposes forbidden key: " + name);
                assertNoDisclosureKeys(node.get(name));
            }
        } else if (node.isArray()) {
            for (JsonNode item : node) {
                assertNoDisclosureKeys(item);
            }
        }
    }

    private static boolean isMediaType(Response response, String mediaType) {
        return response.contentType() != null && response.contentType().split(";", 2)[0].trim()
            .equalsIgnoreCase(mediaType);
    }

    Response latestResponse() {
        if (latestResponse == null) {
            throw new IllegalStateException("No RM User State response is available");
        }
        return latestResponse;
    }

    void latestResponse(Response response) {
        latestResponse = response;
    }
}
