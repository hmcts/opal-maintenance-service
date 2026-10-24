package uk.gov.hmcts.opal.steps;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import io.cucumber.java.After;
import io.cucumber.java.Before;
import io.cucumber.java.Scenario;
import io.restassured.builder.ResponseBuilder;
import io.restassured.response.Response;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.ArgumentCaptor;
import org.mockito.InOrder;
import uk.gov.hmcts.opal.actions.DraftCasefileActions;
import uk.gov.hmcts.opal.data.DraftCasefileRequestFactory;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class RecordCheckerDecisionsStepDefTest {
    private static final ObjectMapper JSON = new ObjectMapper();
    private static final String DATE = "2026-10-23T10:00:00Z";
    private static final String REASON = "Synthetic checker decision reason";
    private static final String CORRECTED = "SyntheticCorrected";
    private final DraftCasefileActions actions = mock(DraftCasefileActions.class);
    private final Scenario scenario = mock(Scenario.class);
    private final List<String> resolvedUsers = new ArrayList<>();
    private final RecordCheckerDecisionsStepDef steps = steps(Map.of());
    private ObjectNode current;
    private ObjectNode originalRequest;
    private ObjectNode registration;
    private int version;
    private int registeredVersion = -1;
    private int testedCalls;
    private String problem;
    private Consumer<ObjectNode> createChange = node -> { };
    private Consumer<ObjectNode> replaceChange = node -> { };
    private Consumer<ObjectNode> decisionChange = node -> { };
    private Consumer<ObjectNode> evidenceChange = node -> { };

    @BeforeEach
    void boundary() {
        when(actions.userState(anyString())).thenAnswer(call -> {
            String token = call.getArgument(0);
            return response(200, user("checker-token".equals(token) ? "checker-id" : "denied-id",
                "checker-token".equals(token) ? 44 : 99, 21, 22), null);
        });
        when(actions.create(anyString(), anyString())).thenAnswer(call -> {
            originalRequest = (ObjectNode) JSON.readTree(call.getArgument(1, String.class));
            current = submitted(originalRequest, "checker-token".equals(call.getArgument(0)));
            createChange.accept(current);
            ObjectNode post = current.deepCopy();
            post.remove("casefile");
            version = 0;
            return response(201, post, "\"0\"");
        });
        when(actions.get(anyString(), eq(123L))).thenAnswer(call -> response(200, current, etag()));
        when(actions.decide(anyString(), eq(123L), anyString(), anyString())).thenAnswer(call -> {
            if (registeredVersion >= 0) {
                testedCalls++;
                if (problem != null) {
                    return problem(problem);
                }
            }
            JsonNode body = JSON.readTree(call.getArgument(2, String.class));
            String status = body.path("casefile_status").textValue();
            current = decision(current, status, body.path("status_message").textValue());
            decisionChange.accept(current);
            version++;
            return response(200, current, etag());
        });
        when(actions.replace(anyString(), eq(123L), anyString(), anyString())).thenAnswer(call -> {
            JsonNode request = JSON.readTree(call.getArgument(2, String.class));
            current.set("casefile", request.path("casefile"));
            current.put("casefile_status", "RESUBMITTED").put("casefile_status_date", DATE);
            ((ObjectNode) current.at("/casefile_snapshot/respondent_account"))
                .put("respondent_name", "RESPONDENT, " + CORRECTED);
            event(current, "Resubmitted", "Synthetic Inputter", null);
            replaceChange.accept(current);
            version++;
            return response(200, current, etag());
        });
        when(actions.registerPublicationEvidence(anyString(), eq(123L), anyString())).thenAnswer(call -> {
            registeredVersion = version;
            registration = evidence(0);
            return response(201, registration, null);
        });
        when(actions.publicationEvidence(anyString(), eq(123L), anyString())).thenAnswer(call -> {
            ObjectNode observed = evidence("PUBLISHING_PENDING".equals(current.path("casefile_status").asText())
                || "PUBLISHED".equals(current.path("casefile_status").asText())
                || "PUBLISHING_FAILED".equals(current.path("casefile_status").asText()) ? 1 : 0);
            evidenceChange.accept(observed);
            return response(200, observed, null);
        });
        when(actions.delete(anyString(), eq(123L), anyString())).thenReturn(response(204, null, null));
        steps.resetScenario();
    }

    @ParameterizedTest
    @CsvSource({"SUBMITTED, Approve", "SUBMITTED, Reject", "SUBMITTED, Delete",
        "RESUBMITTED, Approve", "RESUBMITTED, Reject", "RESUBMITTED, Delete"})
    void sixIndependentDecisionsUseCurrentOwnedBaseline(String source, String decision) throws Exception {
        steps.readyForChecking(source);
        int expectedVersion = "SUBMITTED".equals(source) ? 0 : 2;
        assertThat(version).isEqualTo(expectedVersion);
        final ObjectNode before = current.deepCopy();
        steps.recordDecision(decision);
        steps.assertDecision();
        steps.deleteCreatedDraft(scenario);
        assertThat(testedCalls).isEqualTo(1);
        ArgumentCaptor<String> body = ArgumentCaptor.forClass(String.class);
        InOrder order = inOrder(actions);
        order.verify(actions).registerPublicationEvidence(eq("owner-token"), eq(123L), anyString());
        order.verify(actions).get("owner-token", 123L);
        order.verify(actions).decide(eq("checker-token"), eq(123L), body.capture(),
            eq("\"" + expectedVersion + "\""));
        order.verify(actions).get("owner-token", 123L);
        order.verify(actions).publicationEvidence(eq("owner-token"), eq(123L), anyString());
        order.verify(actions).delete(eq("owner-token"), eq(123L), anyString());
        ObjectNode expected = JSON.createObjectNode().put("business_unit_id", 44)
            .put("casefile_status", target(decision));
        if (!"Approve".equals(decision)) {
            expected.put("status_message", REASON);
        }
        assertThat(JSON.readTree(body.getValue())).isEqualTo(expected);
        assertThat(current.path("casefile")).isEqualTo(before.path("casefile"));
        assertThat(current.at("/casefile/minor_creditors").size()).isEqualTo(2);
        if ("RESUBMITTED".equals(source)) {
            ArgumentCaptor<String> replacement = ArgumentCaptor.forClass(String.class);
            verify(actions).replace(eq("owner-token"), eq(123L), replacement.capture(), eq("\"1\""));
            JsonNode put = JSON.readTree(replacement.getValue());
            assertThat(put.size()).isEqualTo(2);
            assertThat(put.path("business_unit_id").intValue()).isEqualTo(44);
            assertThat(put.path("casefile")).isEqualTo(before.path("casefile"));
            assertThat(originalRequest
                .at("/casefile/respondent_account/respondent/party_details/individual_details/forenames")
                .asText()).isEqualTo("Synthetic");
            assertThat(put.at("/casefile/respondent_account/respondent/party_details/individual_details/forenames")
                .asText()).isEqualTo(CORRECTED);
        }
    }

    @Test
    void selfApprovalUsesActualCreatorWithBothPermissions() {
        steps.ownSubmission();
        problem = "forbidden";
        steps.selfApproval();
        steps.assertForbidden();
        steps.deleteCreatedDraft(scenario);
        verify(actions).create(eq("checker-token"), anyString());
        verify(actions).decide(eq("checker-token"), eq(123L), anyString(), eq("\"0\""));
        verify(actions).delete(eq("checker-token"), eq(123L), anyString());
    }

    @Test
    void noBusinessUnitApprovalUsesDeniedActorAndOriginalOwnerForEvidenceAndCleanup() {
        steps.readyForChecking("SUBMITTED");
        problem = "forbidden";
        steps.deniedApproval();
        steps.assertForbidden();
        steps.deleteCreatedDraft(scenario);
        verify(actions).userState("denied-token");
        verify(actions).decide(eq("denied-token"), eq(123L), anyString(), eq("\"0\""));
        verify(actions).publicationEvidence(eq("owner-token"), eq(123L), anyString());
        verify(actions).delete(eq("owner-token"), eq(123L), anyString());
    }

    @Test
    void staleApprovalUsesOriginalZeroWhileCurrentDraftIsEligibleResubmittedTwo() {
        steps.obsoleteVersion();
        assertThat(current.path("casefile_status").asText()).isEqualTo("RESUBMITTED");
        assertThat(version).isEqualTo(2);
        problem = "optimistic-locking";
        steps.staleApproval();
        steps.assertVersionConflict();
        ArgumentCaptor<String> decisions = ArgumentCaptor.forClass(String.class);
        verify(actions, times(2)).decide(eq("checker-token"), eq(123L), decisions.capture(), eq("\"0\""));
        assertThat(decisions.getAllValues().get(0)).contains("REJECTED");
        assertThat(decisions.getAllValues().get(1)).contains("PUBLISHING_PENDING");
        assertThat(registeredVersion).isEqualTo(2);
    }

    @Test
    void lifecycleConflictUsesCurrentRejectedVersionOne() {
        steps.rejectedVersion();
        assertThat(version).isEqualTo(1);
        problem = "resource-conflict";
        steps.rejectedApproval();
        steps.assertLifecycleConflict();
        verify(actions).decide(eq("checker-token"), eq(123L), anyString(), eq("\"1\""));
    }

    @Test
    void hooksAreScopedOnlyToTicket() throws Exception {
        assertThat(RecordCheckerDecisionsStepDef.class.getMethod("resetScenario")
            .getAnnotation(Before.class).value()).isEqualTo("@PO10617");
        assertThat(RecordCheckerDecisionsStepDef.class.getMethod("deleteCreatedDraft", Scenario.class)
            .getAnnotation(After.class).value()).isEqualTo("@PO10617");
    }

    @Test
    void eachCreateHasNewMarkerRetainedThroughRegistrationAndCleanup() throws Exception {
        steps.readyForChecking("SUBMITTED");
        steps.recordDecision("Reject");
        steps.assertDecision();
        steps.deleteCreatedDraft(scenario);
        RecordCheckerDecisionsStepDef other = steps(Map.of());
        other.resetScenario();
        other.readyForChecking("SUBMITTED");
        ArgumentCaptor<String> requests = ArgumentCaptor.forClass(String.class);
        verify(actions, times(2)).create(eq("owner-token"), requests.capture());
        String first = JSON.readTree(requests.getAllValues().get(0)).at("/casefile/respondent_account/remo_reference")
            .asText();
        String second = JSON.readTree(requests.getAllValues().get(1)).at("/casefile/respondent_account/remo_reference")
            .asText();
        assertThat(first).matches("E2E-[0-9a-f]{16}").isNotEqualTo(second);
        verify(actions).registerPublicationEvidence("owner-token", 123L, first);
        verify(actions).publicationEvidence("owner-token", 123L, first);
        verify(actions).delete("owner-token", 123L, first);
    }

    @Test
    void consistentCreateAndGetMinorLossFailsBeforeAnySetupDecision() {
        createChange = body -> {
            ((ArrayNode) body.at("/casefile/minor_creditors")).remove(1);
            ((ArrayNode) body.at("/casefile_snapshot/minor_creditor_accounts")).remove(1);
        };
        assertThatThrownBy(() -> steps.readyForChecking("RESUBMITTED")).isInstanceOf(AssertionError.class);
        verify(actions, never()).decide(anyString(), anyLong(), anyString(), anyString());
        steps.deleteCreatedDraft(scenario);
        verify(actions).delete(eq("owner-token"), eq(123L), anyString());
    }

    @ParameterizedTest
    @ValueSource(strings = {"casefile", "snapshot", "history", "identity", "status"})
    void correctedReadbackRejectsLossOrMutation(String field) {
        replaceChange = body -> {
            switch (field) {
                case "casefile" -> body.set("casefile", originalRequest.path("casefile"));
                case "snapshot" -> ((ObjectNode) body.at("/casefile_snapshot/respondent_account"))
                    .put("respondent_name", "RESPONDENT, Synthetic");
                case "history" -> ((ArrayNode) body.path("timeline_data")).remove(1);
                case "identity" -> body.put("submitted_by", "other");
                default -> body.put("casefile_status", "SUBMITTED");
            }
        };
        assertThatThrownBy(() -> steps.readyForChecking("RESUBMITTED")).isInstanceOf(AssertionError.class);
        verify(actions, never()).registerPublicationEvidence(anyString(), anyLong(), anyString());
    }

    @Test
    void setupRejectionRequiresAuthenticatedCheckerHistory() {
        decisionChange = body -> ((ObjectNode) body.at("/timeline_data/1")).put("username", "Wrong Actor");
        assertThatThrownBy(steps::rejectedVersion).isInstanceOf(AssertionError.class);
        verify(actions, never()).registerPublicationEvidence(anyString(), anyLong(), anyString());
    }

    @Test
    void registrationMustNotChangeFullDraftOrEtag() {
        steps.readyForChecking("SUBMITTED");
        when(actions.registerPublicationEvidence(anyString(), anyLong(), anyString())).thenAnswer(call -> {
            current.put("unexpected", "changed");
            return response(201, evidence(0), null);
        });
        assertThatThrownBy(() -> steps.recordDecision("Approve")).isInstanceOf(AssertionError.class);
        verify(actions, never()).decide(anyString(), anyLong(), anyString(), anyString());
    }

    @Test
    void invalidRegistrationPreventsTestedPatch() {
        steps.readyForChecking("SUBMITTED");
        ObjectNode incomplete = evidence(0).put("evidence_complete", false);
        when(actions.registerPublicationEvidence(anyString(), anyLong(), anyString()))
            .thenReturn(response(201, incomplete, null));
        assertThatThrownBy(() -> steps.recordDecision("Approve")).isInstanceOf(AssertionError.class);
        verify(actions, never()).decide(anyString(), anyLong(), anyString(), anyString());
    }

    @ParameterizedTest
    @ValueSource(strings = {"identity", "timestamp", "extraSend", "uncertain", "unfinished", "incomplete"})
    void journalCannotBeDowngradedToAnySuccessfulRead(String change) {
        steps.readyForChecking("SUBMITTED");
        steps.recordDecision("Approve");
        evidenceChange = body -> {
            switch (change) {
                case "identity" -> body.put("observation_id", "650e8400-e29b-41d4-a716-446655440000");
                case "timestamp" -> body.put("registered_at", "2026-10-24T10:00:00Z");
                case "extraSend" -> body.put("send_attempt_count", 2).put("acknowledged_send_count", 2);
                case "uncertain" -> body.put("uncertain_send_count", 1).put("send_attempt_count", 2)
                    .put("evidence_complete", false);
                case "unfinished" -> body.put("unfinished_send_count", 1).put("send_attempt_count", 2)
                    .put("evidence_complete", false);
                default -> body.put("evidence_complete", false);
            }
        };
        assertThatThrownBy(steps::assertDecision).isInstanceOf(AssertionError.class);
    }

    @ParameterizedTest
    @ValueSource(strings = {"forbidden", "optimistic-locking", "resource-conflict"})
    void negativeChecksCompareEntireBeforeAndAfter(String kind) {
        if ("optimistic-locking".equals(kind)) {
            steps.obsoleteVersion();
        } else if ("resource-conflict".equals(kind)) {
            steps.rejectedVersion();
        } else {
            steps.readyForChecking("SUBMITTED");
        }
        problem = kind;
        if ("optimistic-locking".equals(kind)) {
            steps.staleApproval();
        } else if ("resource-conflict".equals(kind)) {
            steps.rejectedApproval();
        } else {
            steps.deniedApproval();
        }
        current.put("unrelated", "changed");
        assertThatThrownBy(() -> assertNegative(kind)).isInstanceOf(AssertionError.class);
    }

    @ParameterizedTest
    @ValueSource(strings = {"PUBLISHED", "PUBLISHING_FAILED"})
    void validFastPublicationNeedsNoConsumerStopOrPolling(String terminal) {
        steps.readyForChecking("SUBMITTED");
        steps.recordDecision("Approve");
        terminal(terminal);
        steps.assertDecision();
        verify(actions, times(3)).get("owner-token", 123L);
    }

    @Test
    void successVersionMustNumericallyAdvance() {
        steps.readyForChecking("SUBMITTED");
        when(actions.decide(anyString(), anyLong(), anyString(), anyString())).thenAnswer(call ->
            response(200, decision(current, "REJECTED", REASON), "\"0\""));
        steps.recordDecision("Reject");
        assertThatThrownBy(steps::assertDecision).isInstanceOf(AssertionError.class);
    }

    @Test
    void ambiguousPatchIsNeverReplayedOrReportedAsZero() {
        steps.readyForChecking("SUBMITTED");
        when(actions.decide(anyString(), anyLong(), anyString(), anyString()))
            .thenThrow(new IllegalStateException("private owner-token"));
        assertThatThrownBy(() -> steps.recordDecision("Approve")).isInstanceOf(AssertionError.class)
            .hasMessageContaining("ambiguous").hasMessageNotContaining("private").hasNoCause();
        verify(actions, times(1)).decide(anyString(), anyLong(), anyString(), anyString());
        assertThatThrownBy(steps::assertForbidden).isInstanceOf(AssertionError.class);
        verify(actions, never()).publicationEvidence(anyString(), anyLong(), anyString());
    }

    @Test
    void ambiguousPutIsNeverReplayedOrFollowedByRegistration() {
        when(actions.replace(anyString(), anyLong(), anyString(), anyString()))
            .thenThrow(new IllegalStateException("private owner-token"));
        assertThatThrownBy(() -> steps.readyForChecking("RESUBMITTED")).isInstanceOf(AssertionError.class)
            .hasMessageContaining("ambiguous").hasNoCause();
        verify(actions, times(1)).replace(anyString(), anyLong(), anyString(), anyString());
        verify(actions, never()).registerPublicationEvidence(anyString(), anyLong(), anyString());
    }

    @Test
    void idIsCapturedBeforeMalformedCreatedMetadataFails() {
        doReturn(response(201, JSON.createObjectNode().put("draft_casefile_id", 123), "\"0\""))
            .when(actions).create(anyString(), anyString());
        assertThatThrownBy(() -> steps.readyForChecking("SUBMITTED")).isInstanceOf(AssertionError.class);
        steps.deleteCreatedDraft(scenario);
        verify(actions).delete(eq("owner-token"), eq(123L), anyString());
    }

    @ParameterizedTest
    @ValueSource(strings = {"malformed", "transport", "invalidId"})
    void unknownCreateRetainsSafeMarkerAndNeverReplays(String failure) {
        if ("transport".equals(failure)) {
            doThrow(new IllegalStateException("private owner-token")).when(actions).create(anyString(), anyString());
        } else {
            String body = "malformed".equals(failure) ? "private" : "{\"draft_casefile_id\":-1}";
            doReturn(new ResponseBuilder().setStatusCode(201).setContentType("application/json").setBody(body).build())
                .when(actions).create(anyString(), anyString());
        }
        assertThatThrownBy(() -> steps.readyForChecking("SUBMITTED")).isInstanceOf(AssertionError.class).hasNoCause();
        when(scenario.isFailed()).thenReturn(true);
        steps.deleteCreatedDraft(scenario);
        ArgumentCaptor<String> ledger = ArgumentCaptor.forClass(String.class);
        verify(scenario).attach(ledger.capture(), eq("text/plain"), eq("PO-10617 cleanup failure"));
        assertThat(ledger.getValue()).contains("unknown", "E2E-").doesNotContain("private", "owner-token");
        verify(actions, times(1)).create(anyString(), anyString());
        verify(actions, never()).delete(anyString(), anyLong(), anyString());
    }

    @Test
    void cleanupConflictFailsOtherwiseGreenAndClearsCredentials() {
        steps.readyForChecking("SUBMITTED");
        when(actions.delete(anyString(), anyLong(), anyString())).thenReturn(response(409, null, null));
        assertThatThrownBy(() -> steps.deleteCreatedDraft(scenario)).isInstanceOf(AssertionError.class)
            .hasMessageContaining("123").hasMessageContaining("409").hasMessageContaining("E2E-");
        steps.deleteCreatedDraft(scenario);
        verify(actions, times(1)).delete(anyString(), anyLong(), anyString());
        assertThatThrownBy(() -> steps.recordDecision("Approve")).isInstanceOf(AssertionError.class);
    }

    @Test
    void cleanupExceptionPreservesPrimaryFailureWithSafeLedger() {
        steps.readyForChecking("SUBMITTED");
        when(scenario.isFailed()).thenReturn(true);
        when(actions.delete(anyString(), anyLong(), anyString()))
            .thenThrow(new IllegalStateException("private owner-token"));
        steps.deleteCreatedDraft(scenario);
        ArgumentCaptor<String> ledger = ArgumentCaptor.forClass(String.class);
        verify(scenario).attach(ledger.capture(), eq("text/plain"), eq("PO-10617 cleanup failure"));
        assertThat(ledger.getValue()).contains("123", "E2E-", "request error").doesNotContain("private", "owner-token");
    }

    @Test
    void attachmentFailureStillClearsStateAndSurfacesSafeCleanupIdentity() {
        steps.readyForChecking("SUBMITTED");
        when(scenario.isFailed()).thenReturn(true);
        when(actions.delete(anyString(), anyLong(), anyString())).thenReturn(response(409, null, null));
        doThrow(new IllegalStateException("private owner-token")).when(scenario)
            .attach(anyString(), eq("text/plain"), anyString());
        assertThatThrownBy(() -> steps.deleteCreatedDraft(scenario)).isInstanceOf(AssertionError.class)
            .hasMessageContaining("attachment failed").hasMessageContaining("123").hasMessageNotContaining("private")
            .hasNoCause();
        steps.deleteCreatedDraft(scenario);
        verify(actions, times(1)).delete(anyString(), anyLong(), anyString());
    }

    @Test
    void defaultsAndOverridesResolveCorrectUsers() {
        steps.readyForChecking("SUBMITTED");
        steps.deniedApproval();
        assertThat(resolvedUsers).contains("opal-test@dev.platform.hmcts.net",
            "opal-test-10@dev.platform.hmcts.net", "opal-test-2@dev.platform.hmcts.net");
        RecordCheckerDecisionsStepDef custom = steps(Map.of("RM_DRAFT_CASEFILE_INPUTTER_USER", "owner-override",
            "RM_DRAFT_CASEFILE_CHECKER_USER", "checker-override", "RM_DRAFT_CASEFILE_DENIED_USER", "denied-override"));
        custom.resetScenario();
        custom.readyForChecking("SUBMITTED");
        custom.deniedApproval();
        assertThat(resolvedUsers).contains("owner-override", "checker-override", "denied-override");
    }

    @ParameterizedTest
    @ValueSource(strings = {"shape", "name", "duplicate", "missingPermission", "id", "wrongUnit", "badPermission"})
    void invalidCheckerStateStopsBeforeCreateWithoutLeakingUserData(String invalid) {
        ObjectNode state = user("checker-id", 44, 22);
        ArrayNode units = (ArrayNode) state.at("/domains/maintenance/business_unit_users");
        switch (invalid) {
            case "shape" -> state.put("domains", "private");
            case "name" -> state.put("name", "");
            case "duplicate" -> units.add(units.get(0).deepCopy());
            case "missingPermission" -> ((ObjectNode) units.get(0)).putArray("permissions");
            case "id" -> ((ObjectNode) units.get(0)).put("business_unit_user_id", 123);
            case "wrongUnit" -> ((ObjectNode) units.get(0)).put("business_unit_id", "44");
            default -> ((ObjectNode) units.get(0).path("permissions").get(0)).put("permission_id", "22");
        }
        when(actions.userState("checker-token")).thenReturn(response(200, state, null));
        assertThatThrownBy(() -> steps.readyForChecking("SUBMITTED")).isInstanceOf(AssertionError.class)
            .hasMessageNotContaining("private").hasMessageNotContaining("checker-id");
        verify(actions, never()).create(anyString(), anyString());
    }

    @Test
    void selfCheckerRequiresCreateAsWellAsCheck() {
        when(actions.userState("checker-token")).thenReturn(response(200, user("checker-id", 44, 22), null));
        assertThatThrownBy(steps::ownSubmission).isInstanceOf(AssertionError.class);
        verify(actions, never()).create(anyString(), anyString());
    }

    @Test
    void selfSubmissionMustMatchActualBusinessUnitUserId() {
        createChange = body -> body.put("submitted_by", "different-id");
        assertThatThrownBy(steps::ownSubmission).isInstanceOf(AssertionError.class);
        verify(actions, never()).registerPublicationEvidence(anyString(), anyLong(), anyString());
    }

    @Test
    void independentCheckerCannotMatchActualPostSubmitterEvenWithDifferentConfiguredUsers() {
        createChange = body -> body.put("submitted_by", "checker-id");
        assertThatThrownBy(() -> steps.readyForChecking("SUBMITTED")).isInstanceOf(AssertionError.class);
        verify(actions, never()).decide(anyString(), anyLong(), anyString(), anyString());
    }

    @Test
    void equalDisplayNamesDoNotPreventIndependentActors() {
        when(actions.userState("checker-token")).thenReturn(response(200, user("checker-id", 44, 22)
            .put("name", "Synthetic Inputter"), null));
        steps.readyForChecking("SUBMITTED");
    }

    @Test
    void deniedActorWithOwningCheckPermissionIsRejectedBeforeApproval() {
        steps.readyForChecking("SUBMITTED");
        when(actions.userState("denied-token")).thenReturn(response(200, user("denied-id", 44, 22), null));
        assertThatThrownBy(steps::deniedApproval).isInstanceOf(AssertionError.class);
        verify(actions, never()).registerPublicationEvidence(anyString(), anyLong(), anyString());
    }

    @Test
    void actorTransportErrorsAreSanitized() {
        when(actions.userState(anyString())).thenThrow(new IllegalStateException("private checker-token"));
        assertThatThrownBy(() -> steps.readyForChecking("SUBMITTED")).isInstanceOf(AssertionError.class)
            .hasMessageNotContaining("private").hasNoCause();
    }

    @Test
    void tokenErrorsAreSanitized() {
        RecordCheckerDecisionsStepDef invalid = new RecordCheckerDecisionsStepDef(actions,
            new DraftCasefileRequestFactory(), name -> null, user -> {
                throw new IllegalStateException("private token");
            });
        invalid.resetScenario();
        assertThatThrownBy(() -> invalid.readyForChecking("SUBMITTED")).isInstanceOf(AssertionError.class)
            .hasMessageNotContaining("private").hasNoCause();
    }

    @Test
    void ambiguousRegistrationCannotBeReplayedOrReachTestedPatch() {
        steps.readyForChecking("SUBMITTED");
        when(actions.registerPublicationEvidence(anyString(), anyLong(), anyString()))
            .thenThrow(new IllegalStateException("private owner-token"));
        assertThatThrownBy(() -> steps.recordDecision("Approve")).isInstanceOf(AssertionError.class)
            .hasMessageContaining("ambiguous").hasNoCause();
        assertThatThrownBy(() -> steps.recordDecision("Approve")).isInstanceOf(AssertionError.class);
        verify(actions, times(1)).registerPublicationEvidence(anyString(), anyLong(), anyString());
        verify(actions, never()).decide(anyString(), anyLong(), anyString(), anyString());
        verify(actions, never()).publicationEvidence(anyString(), anyLong(), anyString());
    }

    @Test
    void negativeResponseCannotHideVersionMutation() {
        steps.readyForChecking("SUBMITTED");
        problem = "forbidden";
        steps.deniedApproval();
        version++;
        assertThatThrownBy(steps::assertForbidden).isInstanceOf(AssertionError.class);
    }

    @Test
    void negativeResponseStillRequiresCompleteZeroJournal() {
        steps.readyForChecking("SUBMITTED");
        problem = "forbidden";
        steps.deniedApproval();
        evidenceChange = body -> body.put("send_attempt_count", 1).put("acknowledged_send_count", 1);
        assertThatThrownBy(steps::assertForbidden).isInstanceOf(AssertionError.class);
    }

    @Test
    void setupRejectionReadbackMustRetainEntireDecision() {
        when(actions.get(anyString(), eq(123L))).thenAnswer(call -> {
            ObjectNode body = current.deepCopy();
            if (version == 1) {
                body.put("unexpected", "changed");
            }
            return response(200, body, etag());
        });
        assertThatThrownBy(() -> steps.readyForChecking("RESUBMITTED")).isInstanceOf(AssertionError.class);
        verify(actions, never()).replace(anyString(), anyLong(), anyString(), anyString());
    }

    @Test
    void deniedUserWithNoMaintenanceDomainCompletesProtectedJourney() {
        steps.readyForChecking("SUBMITTED");
        final ObjectNode before = current.deepCopy();
        ObjectNode deniedState = JSON.createObjectNode().put("name", "Synthetic Denied Caller");
        deniedState.putObject("domains");
        when(actions.userState("denied-token")).thenReturn(response(200, deniedState, null));
        problem = "forbidden";

        steps.deniedApproval();
        steps.assertForbidden();
        steps.deleteCreatedDraft(scenario);

        assertThat(current).isEqualTo(before);
        assertThat(version).isZero();
        assertThat(testedCalls).isEqualTo(1);
        InOrder order = inOrder(actions);
        order.verify(actions).userState("denied-token");
        order.verify(actions).registerPublicationEvidence(eq("owner-token"), eq(123L), anyString());
        order.verify(actions).get("owner-token", 123L);
        order.verify(actions).decide(eq("denied-token"), eq(123L), anyString(), eq("\"0\""));
        order.verify(actions).get("owner-token", 123L);
        order.verify(actions).publicationEvidence(eq("owner-token"), eq(123L), anyString());
        order.verify(actions).delete(eq("owner-token"), eq(123L), anyString());
    }

    @ParameterizedTest
    @ValueSource(strings = {"missingDomains", "nullDomains", "arrayDomains", "textDomains", "nullMaintenance",
        "arrayMaintenance", "textMaintenance", "missingUnits", "nullUnits", "objectUnits", "badPermissions",
        "duplicateUnit"})
    void deniedUserCannotTreatMalformedStateAsMissingPermission(String invalid) {
        steps.readyForChecking("SUBMITTED");
        ObjectNode state = user("denied-id", 44, 21);
        ObjectNode domains = (ObjectNode) state.path("domains");
        ObjectNode maintenance = (ObjectNode) domains.path("maintenance");
        ObjectNode unit = (ObjectNode) maintenance.path("business_unit_users").get(0);
        switch (invalid) {
            case "missingDomains" -> state.remove("domains");
            case "nullDomains" -> state.putNull("domains");
            case "arrayDomains" -> state.putArray("domains");
            case "textDomains" -> state.put("domains", "private");
            case "nullMaintenance" -> domains.putNull("maintenance");
            case "arrayMaintenance" -> domains.putArray("maintenance");
            case "textMaintenance" -> domains.put("maintenance", "private");
            case "missingUnits" -> maintenance.remove("business_unit_users");
            case "nullUnits" -> maintenance.putNull("business_unit_users");
            case "objectUnits" -> maintenance.putObject("business_unit_users");
            case "badPermissions" -> unit.put("permissions", "private");
            default -> ((ArrayNode) maintenance.path("business_unit_users")).add(unit.deepCopy());
        }
        when(actions.userState("denied-token")).thenReturn(response(200, state, null));

        assertThatThrownBy(steps::deniedApproval).isInstanceOf(AssertionError.class)
            .hasMessageNotContaining("private").hasMessageNotContaining("denied-id");
        verify(actions, never()).registerPublicationEvidence(anyString(), anyLong(), anyString());
        verify(actions, never()).decide(anyString(), anyLong(), anyString(), anyString());
    }

    @Test
    void independentCheckerStillRequiresMaintenanceDomain() {
        ObjectNode state = JSON.createObjectNode().put("name", "Synthetic Checker");
        state.putObject("domains");
        when(actions.userState("checker-token")).thenReturn(response(200, state, null));
        assertThatThrownBy(() -> steps.readyForChecking("SUBMITTED")).isInstanceOf(AssertionError.class);
        verify(actions, never()).create(anyString(), anyString());
    }

    private void assertNegative(String kind) {
        switch (kind) {
            case "forbidden" -> steps.assertForbidden();
            case "optimistic-locking" -> steps.assertVersionConflict();
            default -> steps.assertLifecycleConflict();
        }
    }

    private RecordCheckerDecisionsStepDef steps(Map<String, String> config) {
        return new RecordCheckerDecisionsStepDef(actions, new DraftCasefileRequestFactory(), config::get, user -> {
            resolvedUsers.add(user);
            return user.contains("checker") || user.contains("test-10") ? "checker-token"
                : user.contains("denied") || user.contains("test-2") ? "denied-token" : "owner-token";
        });
    }

    private ObjectNode submitted(JsonNode request, boolean self) {
        ObjectNode body = JSON.createObjectNode().put("draft_casefile_id", 123).put("business_unit_id", 44)
            .put("casefile_type", "REMO In").put("casefile_status", "SUBMITTED").put("created_date", DATE)
            .put("casefile_status_date", DATE).put("submitted_by", self ? "checker-id" : "owner-id")
            .put("submitted_by_name", self ? "Synthetic Checker" : "Synthetic Inputter");
        body.set("casefile", request.path("casefile").deepCopy());
        ObjectNode snapshot = body.putObject("casefile_snapshot");
        account(snapshot.putObject("respondent_account"), "respondent_name", "RESPONDENT, Synthetic");
        account(snapshot.putObject("applicant_account"), "applicant_name", "APPLICANT, Synthetic");
        ArrayNode minors = snapshot.putArray("minor_creditor_accounts");
        account(minors.addObject().put("creditor_sequence", 7), "name", "MINORSEVEN, Synthetic");
        account(minors.addObject().put("creditor_sequence", 23), "name", "MINORTWENTYTHREE, Synthetic");
        body.putArray("timeline_data");
        event(body, "Submitted", body.path("submitted_by_name").asText(), null);
        return body;
    }

    private ObjectNode decision(ObjectNode before, String target, String reason) {
        ObjectNode after = before.deepCopy().put("casefile_status", target).put("casefile_status_date", DATE);
        if ("PUBLISHING_PENDING".equals(target)) {
            after.put("validated_by", "checker-id").put("validated_by_name", "Synthetic Checker")
                .put("validated_date", DATE).putNull("status_message");
        } else {
            after.put("status_message", reason);
        }
        event(after, "PUBLISHING_PENDING".equals(target) ? "Approved" : "REJECTED".equals(target)
            ? "Rejected" : "Deleted", "Synthetic Checker", reason);
        return after;
    }

    private void terminal(String target) {
        current.put("casefile_status", target).put("casefile_status_date", DATE);
        version++;
        if ("PUBLISHING_FAILED".equals(target)) {
            current.put("status_message", "Synthetic publication unsuccessful");
        } else {
            identity((ObjectNode) current.at("/casefile_snapshot/respondent_account"), 101, "R101");
            identity((ObjectNode) current.at("/casefile_snapshot/applicant_account"), 101, "C101");
            identity((ObjectNode) current.at("/casefile_snapshot/minor_creditor_accounts/0"), 102, "C102");
            identity((ObjectNode) current.at("/casefile_snapshot/minor_creditor_accounts/1"), 103, "C103");
        }
    }

    private void event(ObjectNode body, String status, String name, String reason) {
        ObjectNode event = ((ArrayNode) body.path("timeline_data")).addObject().put("status", status)
            .put("status_date", DATE).put("username", name);
        if (reason != null) {
            event.put("reason_text", reason);
        }
    }

    private void account(ObjectNode node, String field, String name) {
        node.putNull("account_id").putNull("account_number").put(field, name);
    }

    private void identity(ObjectNode node, long id, String number) {
        node.put("account_id", id).put("account_number", number);
    }

    private ObjectNode user(String id, int unit, int... permissions) {
        ObjectNode state = JSON.createObjectNode().put("name", "Synthetic Checker");
        ObjectNode entry = state.putObject("domains").putObject("maintenance").putArray("business_unit_users")
            .addObject().put("business_unit_id", unit).put("business_unit_user_id", id);
        ArrayNode entries = entry.putArray("permissions");
        for (int permission : permissions) {
            entries.addObject().put("permission_id", permission);
        }
        return state;
    }

    private ObjectNode evidence(int count) {
        return JSON.createObjectNode().put("observation_id", "550e8400-e29b-41d4-a716-446655440000")
            .put("registered_at", DATE).put("send_attempt_count", count).put("acknowledged_send_count", count)
            .put("uncertain_send_count", 0).put("unfinished_send_count", 0).put("evidence_complete", true);
    }

    private Response problem(String kind) {
        int status = "forbidden".equals(kind) ? 403 : 409;
        String operation = "550e8400-e29b-41d4-a716-446655440000";
        ObjectNode body = JSON.createObjectNode().put("type", "https://hmcts.gov.uk/problems/" + kind)
            .put("title", status == 403 ? "Forbidden" : "Conflict")
            .put("detail", status == 403 ? "You do not have permission to access this resource"
                : "optimistic-locking".equals(kind) ? "Conflict updating record. Please try again."
                    : "A conflict occurred with the requested resource")
            .put("status", status).put("retriable", false).put("operation_id", operation)
            .put("instance", "https://hmcts.gov.uk/problems/instance/" + operation);
        return new ResponseBuilder().setStatusCode(status).setContentType("application/problem+json")
            .setBody(body.toString()).build();
    }

    private String etag() {
        return "\"" + version + "\"";
    }

    private String target(String decision) {
        return "Approve".equals(decision) ? "PUBLISHING_PENDING" : "Reject".equals(decision) ? "REJECTED" : "DELETED";
    }

    private Response response(int status, JsonNode body, String etag) {
        ResponseBuilder builder = new ResponseBuilder().setStatusCode(status).setContentType("application/json")
            .setBody(body == null ? "" : body.toString());
        if (etag != null) {
            builder.setHeader("ETag", etag);
        }
        return builder.build();
    }
}
