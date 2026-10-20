package uk.gov.hmcts.opal.steps;

import static com.github.tomakehurst.wiremock.client.WireMock.get;
import static com.github.tomakehurst.wiremock.client.WireMock.okJson;
import static com.github.tomakehurst.wiremock.client.WireMock.urlEqualTo;
import static com.github.tomakehurst.wiremock.core.WireMockConfiguration.options;
import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;

import com.github.tomakehurst.wiremock.WireMockServer;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.restassured.builder.ResponseBuilder;
import net.thucydides.core.steps.BaseStepListener;
import net.thucydides.core.steps.StepEventBus;
import net.thucydides.model.steps.ExecutedStepDescription;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import java.io.File;
import java.io.IOException;

class RmUserStateStepDefTest {
    private static final ObjectMapper MAPPER = new ObjectMapper();

    @Test
    void localResponseIsAbsentFromSerenityOutcome() {
        String marker = "SYNTHETIC_PRIVATE_STATE_MARKER";
        WireMockServer server = new WireMockServer(options().dynamicPort());
        server.start();
        StepEventBus bus = StepEventBus.getEventBus();
        BaseStepListener listener = new BaseStepListener(new File("build/serenity-private-test"));
        bus.registerListener(listener);
        try {
            server.stubFor(get(urlEqualTo("/v2/users/0/state"))
                .willReturn(okJson("{\"private\":\"" + marker + "\"}")));
            bus.testStarted("Synthetic User State report privacy boundary");
            bus.stepStarted(ExecutedStepDescription.withTitle("Request synthetic User State"));
            var response = RmUserStateStepDef.requestFrom("http://localhost:" + server.port(), null);
            assertEquals(200, response.statusCode());
            bus.stepFinished();
            var outcome = listener.getCurrentTestOutcome();
            assertFalse(outcome.getFlattenedTestSteps().stream().anyMatch(step -> step.getRestQuery() != null));
            assertFalse(outcome.getTestSteps().stream().anyMatch(step -> step.getAllStepsText().contains(marker)));
        } finally {
            bus.testFinished();
            bus.dropListener(listener);
            server.stop();
        }
    }

    @Test
    void acceptsGrantedAndDeniedAssignments() {
        assertDoesNotThrow(() -> RmUserStateStepDef.assertAssignmentResponse(
            fixture(101, 44, 21), 101, (short) 44, true));
        assertDoesNotThrow(() -> RmUserStateStepDef.assertAssignmentResponse(
            fixture(102, 44, 22), 102, (short) 44, false));
    }

    @Test
    void rejectsWrongUserAndMissingOrEmptyDomain() throws IOException {
        rejects(fixture(101, 44, 21), 102, 44, true);
        ObjectNode root = root(101, 44, 21);
        root.remove("domains");
        rejects(root.toString(), 101, 44, true);
        root = root(101, 44, 21);
        root.with("domains").set("maintenance", MAPPER.createObjectNode());
        rejects(root.toString(), 101, 44, true);
    }

    @Test
    void rejectsMissingExpectedBuAndDuplicateAssignments() throws IOException {
        rejects(fixture(101, 45, 21), 101, 44, true);
        ObjectNode root = root(101, 44, 21);
        ArrayNode assignments = (ArrayNode) root.path("domains").path("maintenance").path("business_unit_users");
        assignments.add(assignments.get(0).deepCopy());
        rejects(root.toString(), 101, 44, true);
    }

    @Test
    void rejectsMissingNullAndNonArrayPermissions() throws IOException {
        for (int type = 0; type < 3; type++) {
            ObjectNode root = root(101, 44, 21);
            ObjectNode assignment = (ObjectNode) root.path("domains").path("maintenance")
                .path("business_unit_users").get(0);
            if (type == 0) {
                assignment.remove("permissions");
            } else if (type == 1) {
                assignment.putNull("permissions");
            } else {
                assignment.putObject("permissions");
            }
            rejects(root.toString(), 101, 44, true);
        }
    }

    @Test
    void rejectsPermissionOnlyUnderFinesOrDifferentMaintenanceBu() throws IOException {
        ObjectNode fines = root(101, 44, 22);
        fines.with("domains").set("fines", MAPPER.createObjectNode().set("business_unit_users",
            MAPPER.createArrayNode().add(assignment(99, 21, "fines"))));
        rejects(fines.toString(), 101, 44, true);
        ObjectNode anotherBu = root(101, 44, 22);
        ((ArrayNode) anotherBu.path("domains").path("maintenance").path("business_unit_users"))
            .add(assignment(45, 21, "other"));
        rejects(anotherBu.toString(), 101, 44, true);
    }

    @Test
    void rejectsDeniedAssignmentWithPermission21OrNoOtherPermission() throws IOException {
        rejects(fixture(102, 44, 21), 102, 44, false);
        ObjectNode empty = root(102, 44, 22);
        ((ObjectNode) empty.path("domains").path("maintenance").path("business_unit_users").get(0))
            .set("permissions", MAPPER.createArrayNode());
        rejects(empty.toString(), 102, 44, false);
    }

    @Test
    void acceptsMinimalProblemAndRejectsDisclosureKeysAtAnyDepth() {
        var step = new RmUserStateStepDef();
        String problem = """
            {"type":"about:blank","title":"Unauthorized","detail":"Authentication required","status":401}
            """;
        step.latestResponse(response(401, MediaType.APPLICATION_PROBLEM_JSON_VALUE, problem));
        assertDoesNotThrow(step::assertUnauthorizedUserState);
        for (String key : new String[]{"domains", "business_unit_users", "permissions", "user_id", "username",
            "name", "cache_name", "stack", "stacktrace", "stack_frames", "exception", "exception_details"}) {
            String disclosed = problem.replace("\"status\":401",
                "\"nested\":[{\"" + key + "\":\"marker\"}],\"status\":401");
            step.latestResponse(response(401, MediaType.APPLICATION_PROBLEM_JSON_VALUE, disclosed));
            assertThrows(AssertionError.class, step::assertUnauthorizedUserState);
        }
        step.latestResponse(response(200, MediaType.APPLICATION_JSON_VALUE, fixture(101, 44, 21)));
        assertThrows(AssertionError.class, step::assertUnauthorizedUserState);
    }

    private static void rejects(String body, long userId, int buId, boolean granted) {
        assertThrows(AssertionError.class,
            () -> RmUserStateStepDef.assertAssignmentResponse(body, userId, (short) buId, granted));
    }

    private static String fixture(long userId, int buId, int permissionId) {
        return root(userId, buId, permissionId).toString();
    }

    private static ObjectNode root(long userId, int buId, int permissionId) {
        ObjectNode root = MAPPER.createObjectNode();
        root.put("user_id", userId);
        root.putObject("domains").putObject("maintenance").putArray("business_unit_users")
            .add(assignment(buId, permissionId, "synthetic-assignment-" + userId));
        return root;
    }

    private static ObjectNode assignment(int buId, int permissionId, String id) {
        ObjectNode node = MAPPER.createObjectNode();
        node.put("business_unit_user_id", id);
        node.put("business_unit_id", buId);
        ObjectNode permission = node.putArray("permissions").addObject();
        permission.put("permission_id", permissionId);
        permission.put("permission_name", permissionId == 21
            ? "Create and Manage Draft Casefiles" : "Check and validate draft Casefiles");
        return node;
    }

    private static io.restassured.response.Response response(int status, String contentType, String body) {
        return new ResponseBuilder().setStatusCode(status).setContentType(contentType).setBody(body).build();
    }
}
