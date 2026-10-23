package uk.gov.hmcts.opal.steps;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import io.cucumber.java.Scenario;
import io.restassured.builder.ResponseBuilder;
import io.restassured.response.Response;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import uk.gov.hmcts.opal.actions.DraftCasefileActions;
import uk.gov.hmcts.opal.actions.DraftCasefilePoller;
import uk.gov.hmcts.opal.data.DraftCasefileRequestFactory;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class GetDraftCasefileStepDefTest {
    private static final ObjectMapper JSON = new ObjectMapper();
    private final DraftCasefileActions actions = mock(DraftCasefileActions.class);
    private final Scenario scenario = mock(Scenario.class);
    private final GetDraftCasefileStepDef steps = steps(Map.of(
        "RM_DRAFT_CASEFILE_CHECKER_USER", "checker", "RM_DRAFT_CASEFILE_DENIED_USER", "denied"));

    @Test
    void freshScenariosCreateDistinctOwnedMarkers() throws Exception {
        when(actions.create(eq("owner-token"), anyString())).thenReturn(response(201, created().toString()));
        steps.resetScenario();
        steps.submitComplete();
        GetDraftCasefileStepDef other = steps(Map.of());
        other.resetScenario();
        other.submitComplete();
        ArgumentCaptor<String> bodies = ArgumentCaptor.forClass(String.class);
        verify(actions, times(2)).create(eq("owner-token"), bodies.capture());
        JsonNode first = JSON.readTree(bodies.getAllValues().get(0));
        JsonNode second = JSON.readTree(bodies.getAllValues().get(1));
        assertThat(first.at("/casefile/respondent_account/remo_reference").asText()).startsWith("E2E-");
        assertThat(first.at("/casefile/respondent_account/remo_reference"))
            .isNotEqualTo(second.at("/casefile/respondent_account/remo_reference"));
        assertThat(first.at("/casefile/minor_creditors").size()).isEqualTo(2);
    }

    @Test
    void failedSetupStillDeletesCapturedIdWithOriginalOwner() {
        when(actions.create(eq("owner-token"), anyString()))
            .thenReturn(response(201, "{\"draft_casefile_id\":123}"));
        when(actions.delete(eq("owner-token"), eq(123L), anyString())).thenReturn(response(204, ""));
        steps.resetScenario();
        assertThatThrownBy(steps::submitComplete).isInstanceOf(AssertionError.class);
        when(scenario.isFailed()).thenReturn(true);
        steps.deleteCreatedDraft(scenario);
        verify(actions).delete(eq("owner-token"), eq(123L), anyString());
    }

    @Test
    void deniedReadUsesReaderTokenButCleanupUsesOwner() {
        prepare();
        when(actions.get("denied-token", 123L)).thenReturn(response(403, "{}"));
        steps.retrieveDenied();
        steps.deleteCreatedDraft(scenario);
        verify(actions).get("denied-token", 123L);
        verify(actions).delete(eq("owner-token"), eq(123L), anyString());
    }

    @Test
    void approvalUsesFreshEtagAndOnlyOneMutation() {
        prepare();
        when(actions.get("owner-token", 123L)).thenReturn(response(200, created().toString(), "\"9\""));
        when(actions.decide(eq("checker-token"), eq(123L), anyString(), eq("\"9\"")))
            .thenReturn(response(200, "{}", "\"10\""));
        assertThatThrownBy(steps::approve).isInstanceOf(AssertionError.class);
        ArgumentCaptor<String> body = ArgumentCaptor.forClass(String.class);
        verify(actions).decide(eq("checker-token"), eq(123L), body.capture(), eq("\"9\""));
        assertThat(body.getValue()).contains("PUBLISHING_PENDING", "44");
    }

    @Test
    void successfulCleanupIsIdempotentInMemory() {
        prepare();
        steps.deleteCreatedDraft(scenario);
        steps.deleteCreatedDraft(scenario);
        verify(actions).delete(eq("owner-token"), eq(123L), anyString());
    }

    @Test
    void cleanupConflictFailsPassingScenarioWithSafeRetainedIdentity() {
        prepare();
        when(actions.delete(eq("owner-token"), eq(123L), anyString()))
            .thenReturn(response(409, "private body"));
        assertThatThrownBy(() -> steps.deleteCreatedDraft(scenario)).isInstanceOf(AssertionError.class)
            .hasMessageContaining("123").hasMessageContaining("409").hasMessageContaining("E2E-")
            .hasMessageNotContaining("private").hasMessageNotContaining("owner-token");
    }

    @Test
    void cleanupTransportErrorIsSanitized() {
        prepare();
        when(actions.delete(eq("owner-token"), eq(123L), anyString()))
            .thenThrow(new IllegalStateException("private body owner-token"));
        assertThatThrownBy(() -> steps.deleteCreatedDraft(scenario)).isInstanceOf(AssertionError.class)
            .hasMessageContaining("request error").hasMessageNotContaining("private").hasNoCause();
    }

    @Test
    void primaryFailureSurvivesCleanupConflictWithSafeAttachment() {
        prepare();
        when(scenario.isFailed()).thenReturn(true);
        when(actions.delete(eq("owner-token"), eq(123L), anyString())).thenReturn(response(409, "private body"));
        steps.deleteCreatedDraft(scenario);
        ArgumentCaptor<String> evidence = ArgumentCaptor.forClass(String.class);
        verify(scenario).attach(evidence.capture(), eq("text/plain"), eq("PO-10618 cleanup failure"));
        assertThat(evidence.getValue()).contains("123", "409", "E2E-").doesNotContain("private", "owner-token");
    }

    @Test
    void unknownCreatedIdReportsLimitationWithoutGuessingOrPayload() {
        when(actions.create(eq("owner-token"), anyString())).thenReturn(response(201, "private invalid JSON"));
        steps.resetScenario();
        assertThatThrownBy(steps::submitComplete).isInstanceOf(AssertionError.class).hasNoCause();
        when(scenario.isFailed()).thenReturn(true);
        steps.deleteCreatedDraft(scenario);
        ArgumentCaptor<String> evidence = ArgumentCaptor.forClass(String.class);
        verify(scenario).attach(evidence.capture(), eq("text/plain"), eq("PO-10618 cleanup failure"));
        assertThat(evidence.getValue()).contains("unknown", "E2E-").doesNotContain("private");
        verify(actions, never()).delete(anyString(), anyLong(), anyString());
    }

    @Test
    void standardSeededCheckerIsUsedWithoutAnOverride() {
        GetDraftCasefileStepDef noChecker = steps(Map.of());
        when(actions.create(eq("owner-token"), anyString())).thenReturn(response(201, created().toString()));
        noChecker.resetScenario();
        noChecker.submitComplete();
        when(actions.get("owner-token", 123L)).thenReturn(response(200, created().toString(), "\"9\""));
        assertThatThrownBy(noChecker::approve).isInstanceOf(AssertionError.class);
        verify(actions).decide(eq("checker-token"), eq(123L), anyString(), eq("\"9\""));
    }

    @Test
    void removedDraftIsReadUsingSameOwnedIdAndCleanupRepeatsDelete() {
        prepare();
        when(actions.get("owner-token", 123L)).thenReturn(response(404, "{}"));
        steps.removeOwned();
        steps.retrieveOwner();
        steps.deleteCreatedDraft(scenario);
        verify(actions, times(2)).delete(eq("owner-token"), eq(123L), anyString());
        verify(actions).get("owner-token", 123L);
    }

    @Test
    void unpublishableScenarioUsesTheRealNonnumericAmountFixture() throws Exception {
        when(actions.create(eq("owner-token"), anyString())).thenReturn(response(201, created().toString()));
        steps.resetScenario();
        steps.submitUnpublishable();
        ArgumentCaptor<String> body = ArgumentCaptor.forClass(String.class);
        verify(actions).create(eq("owner-token"), body.capture());
        assertThat(JSON.readTree(body.getValue())
            .at("/casefile/respondent_account/order_details/order_terms/0/result_responses/0/response").asText())
            .isEqualTo("not-an-amount");
    }

    @Test
    void standardSeededDeniedReaderIsUsedWithoutAnOverride() {
        GetDraftCasefileStepDef defaults = steps(Map.of());
        when(actions.create(eq("owner-token"), anyString())).thenReturn(response(201, created().toString()));
        when(actions.get("denied-token", 123L)).thenReturn(response(403, "{}"));
        defaults.resetScenario();
        defaults.submitComplete();
        defaults.retrieveDenied();
        verify(actions).get("denied-token", 123L);
    }

    @Test
    void checkerCannotBeTheInputter() {
        GetDraftCasefileStepDef sameUser = steps(Map.of(
            "RM_DRAFT_CASEFILE_CHECKER_USER", "opal-test@dev.platform.hmcts.net"));
        when(actions.create(eq("owner-token"), anyString())).thenReturn(response(201, created().toString()));
        sameUser.resetScenario();
        sameUser.submitComplete();
        assertThatThrownBy(sameUser::approve).isInstanceOf(AssertionError.class)
            .hasMessageContaining("Checker must differ");
        verify(actions, never()).decide(anyString(), anyLong(), anyString(), anyString());
    }

    private GetDraftCasefileStepDef steps(Map<String, String> config) {
        return new GetDraftCasefileStepDef(actions, new DraftCasefileRequestFactory(), new DraftCasefilePoller(),
            config::get, user -> "checker".equals(user)
                || "opal-test-10@dev.platform.hmcts.net".equals(user) ? "checker-token"
                : "denied".equals(user) || "opal-test-2@dev.platform.hmcts.net".equals(user)
                    ? "denied-token" : "owner-token");
    }

    private void prepare() {
        when(actions.create(eq("owner-token"), anyString())).thenReturn(response(201, created().toString()));
        when(actions.delete(eq("owner-token"), eq(123L), anyString())).thenReturn(response(204, ""));
        steps.resetScenario();
        steps.submitComplete();
    }

    private ObjectNode created() {
        ObjectNode root = JSON.createObjectNode().put("draft_casefile_id", 123).put("business_unit_id", 44)
            .put("casefile_type", "REMO In").put("casefile_status", "SUBMITTED")
            .put("created_date", "2026-10-23T10:00:00Z").put("casefile_status_date", "2026-10-23T10:00:00Z")
            .put("submitted_by", "inputter").put("submitted_by_name", "Synthetic Inputter");
        root.putObject("casefile_snapshot");
        root.putArray("timeline_data");
        return root;
    }

    private Response response(int status, String body) {
        return response(status, body, "\"0\"");
    }

    private Response response(int status, String body, String etag) {
        return new ResponseBuilder().setStatusCode(status).setContentType("application/json")
            .setHeader("ETag", etag).setBody(body).build();
    }
}
