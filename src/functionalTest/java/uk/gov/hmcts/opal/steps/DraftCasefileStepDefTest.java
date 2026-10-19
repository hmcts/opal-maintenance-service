package uk.gov.hmcts.opal.steps;

import io.cucumber.java.Scenario;
import io.restassured.builder.ResponseBuilder;
import io.restassured.response.Response;
import org.junit.jupiter.api.Test;
import org.mockito.MockedStatic;
import uk.gov.hmcts.opal.actions.DraftCasefileActions;
import uk.gov.hmcts.opal.data.DraftCasefileRequestFactory;
import uk.gov.hmcts.opal.data.DraftCasefileScenarioState;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.mockStatic;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class DraftCasefileStepDefTest {

    private final DraftCasefileActions actions = mock(DraftCasefileActions.class);
    private final DraftCasefileScenarioState state = new DraftCasefileScenarioState();
    private final DraftCasefileStepDef steps = new DraftCasefileStepDef(
        actions, new DraftCasefileRequestFactory(), state);
    private final Scenario scenario = mock(Scenario.class);

    @Test
    void successfulCreateRetainsResponseIdAndOriginalTokenForCleanup() {
        steps.resetScenario();
        steps.prepareValid();
        Response created = response(201, "{\"draft_casefile_id\":123}");
        when(actions.create(eq("creator-token"), anyString(), eq(null))).thenReturn(created);
        when(actions.delete("creator-token", 123L)).thenReturn(response(204, ""));
        when(actions.findByMarker(eq("creator-token"), anyString())).thenReturn(response(200,
            "{\"count\":0,\"draft_casefile_ids\":[]}"));

        try (MockedStatic<BearerTokenStepDef> bearer = mockStatic(BearerTokenStepDef.class)) {
            bearer.when(BearerTokenStepDef::getToken).thenReturn("creator-token", "later-token");
            steps.submit();
        }

        assertThat(state.createdResponse()).isSameAs(created);
        assertThat(state.createdId()).isEqualTo(123L);
        assertThat(state.cleanupToken()).isEqualTo("creator-token");
        steps.deleteCreatedDraft(scenario);
        verify(actions).delete("creator-token", 123L);
        verify(actions).findByMarker("creator-token", state.marker());
        assertThat(state.createdId()).isNull();
        assertThat(state.createdResponse()).isNull();
        assertThat(state.cleanupToken()).isNull();
    }

    @Test
    void rejectedCreateDoesNotCaptureOrDeleteAnything() {
        steps.resetScenario();
        steps.prepareValid();
        Response rejected = response(403, "{}");
        when(actions.create(eq("denied-token"), anyString(), eq(null))).thenReturn(rejected);

        try (MockedStatic<BearerTokenStepDef> bearer = mockStatic(BearerTokenStepDef.class)) {
            bearer.when(BearerTokenStepDef::getToken).thenReturn("denied-token");
            steps.submit();
        }

        assertThat(state.latestResponse()).isSameAs(rejected);
        assertThat(state.createdResponse()).isNull();
        assertThat(state.createdId()).isNull();
        assertThat(state.cleanupToken()).isNull();
        steps.deleteCreatedDraft(scenario);
        verify(actions, never()).delete(anyString(), anyLong());
    }

    @Test
    void failedCleanupFailsAnOtherwisePassingScenarioWithoutSensitiveAttachment() {
        prepareCreatedState();
        when(actions.delete("creator-token", 123L)).thenReturn(response(500, "sensitive response body"));

        assertThatThrownBy(() -> steps.deleteCreatedDraft(scenario))
            .isInstanceOf(AssertionError.class)
            .hasMessage("Draft cleanup failed for ID 123 with status 500");
        verify(scenario, never()).attach(anyString(), anyString(), anyString());
        assertThat(state.createdId()).isNull();
    }

    @Test
    void cleanupRequestErrorFailsAnOtherwisePassingScenarioWithoutAttachment() {
        prepareCreatedState();
        when(actions.delete("creator-token", 123L)).thenThrow(new IllegalStateException("sensitive cause"));

        assertThatThrownBy(() -> steps.deleteCreatedDraft(scenario))
            .isInstanceOf(AssertionError.class)
            .hasMessage("Draft cleanup failed for ID 123 with a request error");
        verify(scenario, never()).attach(anyString(), anyString(), anyString());
        assertThat(state.createdId()).isNull();
    }

    @Test
    void cleanupVerificationFailsWhenTheMarkerStillExists() {
        prepareCreatedState();
        when(actions.delete("creator-token", 123L)).thenReturn(response(204, ""));
        when(actions.findByMarker(eq("creator-token"), anyString())).thenReturn(response(200,
            "{\"count\":1,\"draft_casefile_ids\":[123]}"));

        assertThatThrownBy(() -> steps.deleteCreatedDraft(scenario))
            .isInstanceOf(AssertionError.class)
            .hasMessage("Draft cleanup verification failed for ID 123");
        assertThat(state.createdId()).isNull();
    }

    @Test
    void failedCleanupAttachesEvidenceButPreservesPrimaryFailure() {
        prepareCreatedState();
        when(scenario.isFailed()).thenReturn(true);
        when(actions.delete("creator-token", 123L)).thenReturn(response(500, "sensitive response body"));

        steps.deleteCreatedDraft(scenario);

        verify(scenario).attach("Draft cleanup failed for ID 123 with status 500", "text/plain",
            "PO-10287 cleanup failure");
        assertThat(state.createdId()).isNull();
    }

    @Test
    void cleanupRequestErrorDoesNotReplaceAnExistingFailure() {
        prepareCreatedState();
        when(scenario.isFailed()).thenReturn(true);
        when(actions.delete("creator-token", 123L)).thenThrow(new IllegalStateException("sensitive cause"));

        steps.deleteCreatedDraft(scenario);

        verify(scenario).attach("Draft cleanup failed for ID 123 with a request error", "text/plain",
            "PO-10287 cleanup failure");
        assertThat(state.createdId()).isNull();
    }

    private void prepareCreatedState() {
        steps.resetScenario();
        state.createdId(123L);
        state.cleanupToken("creator-token");
    }

    private Response response(int status, String body) {
        return new ResponseBuilder().setStatusCode(status).setContentType("application/json").setBody(body).build();
    }
}
