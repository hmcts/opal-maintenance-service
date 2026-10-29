package uk.gov.hmcts.opal.steps;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import io.cucumber.java.Scenario;
import io.restassured.builder.ResponseBuilder;
import io.restassured.response.Response;
import java.time.Duration;
import java.util.Map;
import java.util.concurrent.atomic.AtomicReference;
import java.util.function.Consumer;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.mockito.InOrder;
import uk.gov.hmcts.opal.actions.DraftCasefileActions;
import uk.gov.hmcts.opal.actions.DraftCasefilePoller;
import uk.gov.hmcts.opal.data.DraftCasefileRequestFactory;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoMoreInteractions;
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
        preparePublication(false, terminal -> { });
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

    @ParameterizedTest
    @ValueSource(ints = {400, 403, 409, 500, 502, 503, 504})
    void non201CreateRetainsRecoveryMarker(int status) throws Exception {
        when(actions.create(eq("owner-token"), anyString()))
            .thenReturn(response(status, "private response owner-token"));
        steps.resetScenario();
        assertThatThrownBy(steps::submitComplete).isInstanceOf(AssertionError.class)
            .hasMessage("Scenario Draft Casefile creation requires HTTP 201").hasNoCause();
        ArgumentCaptor<String> request = ArgumentCaptor.forClass(String.class);
        verify(actions, times(1)).create(eq("owner-token"), request.capture());
        final String marker = JSON.readTree(request.getValue())
            .at("/casefile/respondent_account/remo_reference").textValue();
        when(scenario.isFailed()).thenReturn(true);
        steps.deleteCreatedDraft(scenario);
        ArgumentCaptor<String> evidence = ArgumentCaptor.forClass(String.class);
        verify(scenario).attach(evidence.capture(), eq("text/plain"), eq("PO-10618 cleanup failure"));
        assertThat(evidence.getValue()).contains("unknown", marker, "operator follow-up")
            .doesNotContain("private", "owner-token");
        verify(actions, never()).delete(anyString(), anyLong(), anyString());
        steps.deleteCreatedDraft(scenario);
        verify(scenario, times(1)).attach(anyString(), anyString(), anyString());
        verify(actions, times(1)).create(anyString(), anyString());
    }

    @Test
    void standardSeededCheckerIsUsedWithoutAnOverride() {
        GetDraftCasefileStepDef noChecker = steps(Map.of());
        AtomicReference<ObjectNode> submitted = new AtomicReference<>();
        when(actions.create(eq("owner-token"), anyString())).thenAnswer(invocation -> {
            ObjectNode full = completeSubmitted(JSON.readTree(invocation.getArgument(1, String.class)));
            submitted.set(full);
            ObjectNode post = full.deepCopy();
            post.remove("casefile");
            return response(201, post.toString());
        });
        noChecker.resetScenario();
        noChecker.submitComplete();
        when(actions.get("owner-token", 123L)).thenReturn(response(200, submitted.get().toString(), "\"9\""));
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

    @Test
    void publishedJourneyRetainsApprovalAndUsesOwnerForPollingAndCleanup() throws Exception {
        preparePublication(false, terminal -> { });

        steps.approve();
        steps.retrievePublished();
        steps.assertPublished();
        steps.deleteCreatedDraft(scenario);

        verifyPublicationCalls();
    }

    @Test
    void failedJourneyRetainsApprovalWithoutGeneratedAccountIdentities() throws Exception {
        preparePublication(true, terminal -> { });

        steps.approve();
        steps.retrieveFailed();
        steps.assertFailed();
        steps.deleteCreatedDraft(scenario);

        verifyPublicationCalls();
    }

    @ParameterizedTest
    @CsvSource({"false,0", "false,1", "true,0", "true,1"})
    void approvalRejectsLostMinors(boolean failed, int retained) {
        preparePublication(failed, submitted -> {
            for (String path : new String[] {
                "/casefile/minor_creditors", "/casefile_snapshot/minor_creditor_accounts"
            }) {
                ArrayNode minors = (ArrayNode) submitted.at(path);
                while (minors.size() > retained) {
                    minors.remove(minors.size() - 1);
                }
            }
        }, terminal -> { });

        assertThatThrownBy(steps::approve).isInstanceOf(AssertionError.class)
            .hasMessageContaining("casefile must match the request");
        verify(actions, never()).decide(anyString(), anyLong(), anyString(), anyString());
        when(scenario.isFailed()).thenReturn(true);
        steps.deleteCreatedDraft(scenario);
        verify(actions).delete(eq("owner-token"), eq(123L), anyString());
    }

    @Test
    void publishedJourneyRejectsFailedTerminalAndStillCleansUp() throws Exception {
        preparePublication(true, terminal -> { });
        steps.approve();

        assertThatThrownBy(steps::retrievePublished).isInstanceOf(AssertionError.class)
            .hasMessage("Draft Casefile reached an unexpected lifecycle state: expected PUBLISHED"
                + " but was PUBLISHING_FAILED");
        when(scenario.isFailed()).thenReturn(true);
        steps.deleteCreatedDraft(scenario);

        verifyPublicationCalls();
    }

    @Test
    void publishedThenRejectsChangedApprovalBaselineAndStillCleansUp() throws Exception {
        preparePublication(false, terminal -> terminal.put("validated_date", "2026-10-24T11:00:00Z"));
        steps.approve();
        steps.retrievePublished();

        assertThatThrownBy(steps::assertPublished).isInstanceOf(AssertionError.class)
            .hasMessageContaining("validated_date must be retained");
        when(scenario.isFailed()).thenReturn(true);
        steps.deleteCreatedDraft(scenario);

        verifyPublicationCalls();
    }

    private void preparePublication(boolean failed, Consumer<ObjectNode> changeTerminal) {
        preparePublication(failed, submitted -> { }, changeTerminal);
    }

    private void preparePublication(boolean failed, Consumer<ObjectNode> changeSubmitted,
                                    Consumer<ObjectNode> changeTerminal) {
        AtomicReference<ObjectNode> submitted = new AtomicReference<>();
        when(actions.create(eq("owner-token"), anyString())).thenAnswer(invocation -> {
            ObjectNode full = completeSubmitted(JSON.readTree(invocation.getArgument(1, String.class)));
            submitted.set(full);
            ObjectNode post = full.deepCopy();
            post.remove("casefile");
            return response(201, post.toString());
        });
        steps.resetScenario();
        if (failed) {
            steps.submitUnpublishable();
        } else {
            steps.submitComplete();
        }
        changeSubmitted.accept(submitted.get());
        ObjectNode approved = approval(submitted.get());
        ObjectNode terminal = approved.deepCopy().put("casefile_status", failed ? "PUBLISHING_FAILED" : "PUBLISHED")
            .put("casefile_status_date", "2026-10-23T11:01:00Z");
        if (failed) {
            terminal.put("status_message", "Synthetic publication unsuccessful");
        } else {
            identity((ObjectNode) terminal.at("/casefile_snapshot/respondent_account"), 101, "R101");
            identity((ObjectNode) terminal.at("/casefile_snapshot/applicant_account"), 101, "C101");
            int index = 0;
            for (JsonNode minor : terminal.at("/casefile_snapshot/minor_creditor_accounts")) {
                identity((ObjectNode) minor, 102L + index, "C" + (102 + index));
                index++;
            }
        }
        changeTerminal.accept(terminal);
        when(actions.get("owner-token", 123L))
            .thenReturn(response(200, submitted.get().toString(), "\"9\""),
                response(200, approved.toString(), "\"10\""), response(200, terminal.toString(), "\"11\""));
        when(actions.decide(eq("checker-token"), eq(123L), anyString(), eq("\"9\"")))
            .thenReturn(response(200, approved.toString(), "\"10\""));
        when(actions.delete(eq("owner-token"), eq(123L), anyString())).thenReturn(response(204, ""));
    }

    private void verifyPublicationCalls() throws Exception {
        InOrder order = inOrder(actions);
        ArgumentCaptor<String> source = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<String> decision = ArgumentCaptor.forClass(String.class);
        order.verify(actions).create(eq("owner-token"), source.capture());
        String marker = JSON.readTree(source.getValue()).at("/casefile/respondent_account/remo_reference").asText();
        order.verify(actions).get("owner-token", 123L);
        order.verify(actions).decide(eq("checker-token"), eq(123L), decision.capture(), eq("\"9\""));
        order.verify(actions, times(2)).get("owner-token", 123L);
        order.verify(actions).delete("owner-token", 123L, marker);
        assertThat(JSON.readTree(decision.getValue())).isEqualTo(JSON.createObjectNode()
            .put("casefile_status", "PUBLISHING_PENDING").put("business_unit_id", 44));
        verifyNoMoreInteractions(actions);
    }

    private ObjectNode completeSubmitted(JsonNode request) {
        ObjectNode root = created();
        root.set("casefile", request.path("casefile"));
        ObjectNode snapshot = root.putObject("casefile_snapshot");
        account(snapshot.putObject("respondent_account"), "respondent_name", "RESPONDENT, Synthetic");
        account(snapshot.putObject("applicant_account"), "applicant_name", "APPLICANT, Synthetic");
        ArrayNode minors = snapshot.putArray("minor_creditor_accounts");
        account(minors.addObject().put("creditor_sequence", 7), "name", "MINORSEVEN, Synthetic");
        account(minors.addObject().put("creditor_sequence", 23), "name", "MINORTWENTYTHREE, Synthetic");
        root.putArray("timeline_data").addObject().put("status", "Submitted")
            .put("status_date", "2026-10-23T10:00:00Z").put("username", "Synthetic Inputter");
        return root;
    }

    private ObjectNode approval(ObjectNode submitted) {
        ObjectNode approved = submitted.deepCopy().put("casefile_status", "PUBLISHING_PENDING")
            .put("validated_by", "checker").put("validated_by_name", "Synthetic Checker")
            .put("validated_date", "2026-10-23T11:00:00Z").put("casefile_status_date", "2026-10-23T11:00:00Z");
        ((ArrayNode) approved.path("timeline_data")).addObject().put("status", "Approved")
            .put("status_date", "2026-10-23T11:00:00Z").put("username", "Synthetic Checker");
        return approved;
    }

    private void account(ObjectNode node, String field, String name) {
        node.putNull("account_id").putNull("account_number").put(field, name);
    }

    private void identity(ObjectNode node, long id, String number) {
        node.put("account_id", id).put("account_number", number);
    }

    private GetDraftCasefileStepDef steps(Map<String, String> config) {
        long[] elapsed = {0};
        DraftCasefilePoller poller = new DraftCasefilePoller(Duration.ofSeconds(60), Duration.ofMillis(500),
            () -> elapsed[0], millis -> elapsed[0] += Duration.ofMillis(millis).toNanos());
        return new GetDraftCasefileStepDef(actions, new DraftCasefileRequestFactory(), poller,
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
