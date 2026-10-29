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
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class ResubmitRejectedCasefileStepDefTest {
    private static final ObjectMapper JSON = new ObjectMapper();
    private static final String DATE = "2026-10-23T10:00:00Z";
    private static final String REASON = "Synthetic resubmission setup rejection";
    private final DraftCasefileActions actions = mock(DraftCasefileActions.class);
    private final Scenario scenario = mock(Scenario.class);
    private final List<String> users = new ArrayList<>();
    private final ResubmitRejectedCasefileStepDef steps = steps(Map.of());
    private ObjectNode current;
    private ObjectNode original;
    private int version;
    private String problem;
    private Consumer<ObjectNode> createChange = node -> { };
    private Consumer<ObjectNode> replaceChange = node -> { };

    @BeforeEach
    void boundary() {
        when(actions.userState(anyString())).thenAnswer(call -> {
            String token = call.getArgument(0);
            ObjectNode state = "checker-token".equals(token) ? user("checker-id", 21, 22)
                : "owner-token".equals(token) ? user("owner-id", 21) : user("denied-id");
            if ("denied-token".equals(token)) {
                state.putObject("domains");
            }
            return response(200, state, null);
        });
        when(actions.create(anyString(), anyString())).thenAnswer(call -> {
            original = (ObjectNode) JSON.readTree(call.getArgument(1, String.class));
            current = submitted(original);
            createChange.accept(current);
            ObjectNode post = current.deepCopy();
            post.remove("casefile");
            return response(201, post, "\"0\"");
        });
        when(actions.get(anyString(), eq(123L))).thenAnswer(call -> response(200, current, etag()));
        when(actions.decide(anyString(), eq(123L), anyString(), anyString())).thenAnswer(call -> {
            if (version >= 2) {
                return problem("forbidden");
            }
            current.put("casefile_status", "REJECTED").put("casefile_status_name", "Rejected")
                .put("status_message", REASON);
            event(current, "Rejected", "Synthetic checker-id", REASON);
            version++;
            return response(200, current, etag());
        });
        when(actions.replace(anyString(), eq(123L), anyString(), anyString())).thenAnswer(call -> {
            if (problem != null) {
                return problem(problem);
            }
            JsonNode request = JSON.readTree(call.getArgument(2, String.class));
            boolean handover = "checker-token".equals(call.getArgument(0));
            current.set("casefile", request.path("casefile").deepCopy());
            current.put("casefile_status", "RESUBMITTED").put("casefile_status_name", "Resubmitted")
                .put("submitted_by", handover ? "checker-id" : "owner-id")
                .put("submitted_by_name", handover ? "Synthetic checker-id" : "Synthetic owner-id");
            snapshot(current);
            event(current, "Resubmitted", current.path("submitted_by_name").asText(), null);
            replaceChange.accept(current);
            version++;
            return response(200, current, etag());
        });
        when(actions.delete(anyString(), eq(123L), anyString())).thenReturn(response(204, null, null));
        steps.resetScenario();
    }

    @ParameterizedTest
    @CsvSource({"original,owner-token", "another,checker-token", "invalid,owner-token",
        "denied,denied-token", "different,owner-token"})
    void fiveCompleteJourneys(String flow, String actor) throws Exception {
        steps.rejectedCasefile();
        final ObjectNode before = current.deepCopy();
        attempt(flow);
        outcome(flow);
        if ("another".equals(flow)) {
            steps.selfCheckDenied();
        }
        steps.deleteCreatedDraft(scenario);

        ArgumentCaptor<String> put = ArgumentCaptor.forClass(String.class);
        InOrder order = inOrder(actions);
        order.verify(actions).decide(eq("checker-token"), eq(123L), anyString(), eq("\"0\""));
        order.verify(actions).replace(eq(actor), eq(123L), put.capture(), eq("\"1\""));
        String owner = "another".equals(flow) ? "checker-token" : "owner-token";
        order.verify(actions).get(owner, 123L);
        order.verify(actions).delete(eq(owner), eq(123L), anyString());
        JsonNode request = JSON.readTree(put.getValue());
        assertThat(request.size()).isEqualTo(2);
        assertThat(request.path("business_unit_id").asInt()).isEqualTo("different".equals(flow) ? 45 : 44);
        assertThat(request.at("/casefile/respondent_account/business_unit_id").asInt()).isEqualTo(44);
        assertThat(request.at("/casefile/respondent_account/application_code").asText())
            .isEqualTo("invalid".equals(flow) ? "ZZ99999" : "AP00001");
        assertThat(request.at("/casefile/respondent_account/respondent/party_details/individual_details/forenames")
            .asText()).isEqualTo("CorrectedRespondent");
        assertThat(request.at("/casefile/applicant/party_details/individual_details/forenames").asText())
            .isEqualTo("CorrectedApplicant");
        assertThat(request.at("/casefile/minor_creditors/0/party_details/individual_details/forenames").asText())
            .isEqualTo("CorrectedMinorSeven");
        assertThat(request.at("/casefile/minor_creditors/1")).isEqualTo(before.at("/casefile/minor_creditors/1"));
        assertThat(original.at("/casefile/respondent_account/respondent/party_details/individual_details/forenames")
            .asText()).isEqualTo("Synthetic");
        assertThat(users).contains("opal-test@dev.platform.hmcts.net", "opal-test-10@dev.platform.hmcts.net");
    }

    @Test
    void hooksOnlyBelongToThisTicket() throws Exception {
        assertThat(ResubmitRejectedCasefileStepDef.class.getMethod("resetScenario")
            .getAnnotation(Before.class).value()).isEqualTo("@PO10622");
        assertThat(ResubmitRejectedCasefileStepDef.class.getMethod("deleteCreatedDraft", Scenario.class)
            .getAnnotation(After.class).value()).isEqualTo("@PO10622");
    }

    @ParameterizedTest
    @ValueSource(strings = {"creator21", "checker21", "checker22", "sameIdentity", "name", "domains",
        "maintenance", "units", "duplicateUnit", "duplicatePermission", "permissionType"})
    void invalidActorStateStopsBeforeCreate(String change) {
        ObjectNode owner = user("owner-id", 21);
        ObjectNode checker = user("checker-id", 21, 22);
        ObjectNode state = change.startsWith("creator") ? owner : checker;
        ObjectNode unit = (ObjectNode) state.at("/domains/maintenance/business_unit_users/0");
        switch (change) {
            case "creator21", "checker21" -> unit.putArray("permissions").addObject().put("permission_id", 22);
            case "checker22" -> unit.putArray("permissions").addObject().put("permission_id", 21);
            case "sameIdentity" -> unit.put("business_unit_user_id", "owner-id");
            case "name" -> state.put("name", "");
            case "domains" -> state.put("domains", "private");
            case "maintenance" -> ((ObjectNode) state.path("domains")).putNull("maintenance");
            case "units" -> ((ObjectNode) state.at("/domains/maintenance")).putObject("business_unit_users");
            case "duplicateUnit" -> ((ArrayNode) state.at("/domains/maintenance/business_unit_users"))
                .add(unit.deepCopy());
            case "duplicatePermission" -> ((ArrayNode) unit.path("permissions"))
                .add(unit.path("permissions").get(0).deepCopy());
            default -> ((ObjectNode) unit.path("permissions").get(0)).put("permission_id", "21");
        }
        when(actions.userState("owner-token")).thenReturn(response(200, owner, null));
        when(actions.userState("checker-token")).thenReturn(response(200, checker, null));
        assertThatThrownBy(steps::rejectedCasefile).isInstanceOf(AssertionError.class)
            .hasMessageNotContaining("private").hasMessageNotContaining("owner-id");
        verify(actions, never()).create(anyString(), anyString());
    }

    @ParameterizedTest
    @ValueSource(strings = {"nullMaintenance", "badUnits", "badPermissions", "duplicateUnit", "permission21"})
    void deniedActorRequiresWellFormedPresentDomainAndAbsentCreatePermission(String change) {
        steps.rejectedCasefile();
        ObjectNode state = user("denied-id");
        ObjectNode unit = (ObjectNode) state.at("/domains/maintenance/business_unit_users/0");
        switch (change) {
            case "nullMaintenance" -> ((ObjectNode) state.path("domains")).putNull("maintenance");
            case "badUnits" -> ((ObjectNode) state.at("/domains/maintenance")).putObject("business_unit_users");
            case "badPermissions" -> unit.putNull("permissions");
            case "duplicateUnit" -> ((ArrayNode) state.at("/domains/maintenance/business_unit_users"))
                .add(unit.deepCopy());
            default -> ((ArrayNode) unit.path("permissions")).addObject().put("permission_id", 21);
        }
        when(actions.userState("denied-token")).thenReturn(response(200, state, null));
        assertThatThrownBy(steps::deniedCorrection).isInstanceOf(AssertionError.class);
        verify(actions, never()).replace(anyString(), anyLong(), anyString(), anyString());
    }

    @Test
    void sameDisplayNameAllowsIndependentBusinessUnitIdentities() {
        when(actions.userState("checker-token")).thenReturn(response(200,
            user("checker-id", 21, 22).put("name", "Synthetic owner-id"), null));
        when(actions.decide(anyString(), anyLong(), anyString(), anyString())).thenAnswer(call -> {
            current.put("casefile_status", "REJECTED").put("casefile_status_name", "Rejected")
                .put("status_message", REASON);
            event(current, "Rejected", "Synthetic owner-id", REASON);
            version++;
            return response(200, current, etag());
        });
        steps.rejectedCasefile();
        verify(actions).create(eq("owner-token"), anyString());
    }

    @ParameterizedTest
    @ValueSource(strings = {"casefile", "snapshot", "history", "creator", "label"})
    void originalBaselineMustMatchActualRequestAndResolvedCreator(String change) {
        createChange = body -> {
            switch (change) {
                case "casefile" -> ((ArrayNode) body.at("/casefile/minor_creditors")).remove(1);
                case "snapshot" -> ((ArrayNode) body.at("/casefile_snapshot/minor_creditor_accounts")).remove(1);
                case "history" -> ((ArrayNode) body.path("timeline_data")).removeAll();
                case "creator" -> body.put("submitted_by", "wrong-id");
                default -> body.put("casefile_status_name", "Wrong");
            }
        };
        assertThatThrownBy(steps::rejectedCasefile).isInstanceOf(AssertionError.class);
        steps.deleteCreatedDraft(scenario);
        verify(actions).delete(eq("owner-token"), eq(123L), anyString());
        verify(actions, never()).decide(anyString(), anyLong(), anyString(), anyString());
    }

    @ParameterizedTest
    @ValueSource(strings = {"body", "etag"})
    void prePutReadMustMatchRejectedBaseline(String change) {
        steps.rejectedCasefile();
        when(actions.get(anyString(), anyLong())).thenAnswer(call -> {
            if ("body".equals(change)) {
                current.put("extra", true);
            } else {
                version++;
            }
            return response(200, current, etag());
        });
        assertThatThrownBy(steps::originalCorrection).isInstanceOf(AssertionError.class);
        verify(actions, never()).replace(anyString(), anyLong(), anyString(), anyString());
    }


    @ParameterizedTest
    @ValueSource(strings = {"casefile", "actor", "label", "snapshot", "history", "version"})
    void malformedSuccessStillTransfersCleanupBeforeAssertions(String change) {
        steps.rejectedCasefile();
        replaceChange = body -> {
            switch (change) {
                case "casefile" -> body.set("casefile", original.path("casefile"));
                case "actor" -> body.put("submitted_by", "unknown");
                case "label" -> body.put("casefile_status_name", "Wrong");
                case "snapshot" -> ((ObjectNode) body.at("/casefile_snapshot/applicant_account"))
                    .put("applicant_name", "Wrong");
                case "history" -> ((ArrayNode) body.path("timeline_data")).remove(1);
                default -> version--;
            }
        };
        steps.anotherCorrection();
        assertThatThrownBy(steps::assertResubmitted).isInstanceOf(AssertionError.class);
        steps.deleteCreatedDraft(scenario);
        verify(actions).delete(eq("checker-token"), eq(123L), anyString());
        verify(actions, never()).delete(eq("owner-token"), anyLong(), anyString());
    }

    @Test
    void negativeStateIsCheckedBeforeMissingCorrelationFailure() {
        steps.rejectedCasefile();
        problem = "forbidden";
        steps.deniedCorrection();
        ObjectNode body = parse(problem("forbidden"));
        body.put("operation_id", "")
            .put("instance", "https://hmcts.gov.uk/problems/instance/");
        when(actions.replace(anyString(), anyLong(), anyString(), anyString())).thenReturn(
            new ResponseBuilder().setStatusCode(403).setContentType("application/problem+json")
                .setBody(body.toString()).build());
        // A separate fresh attempt captures the malformed response without replaying this mutation.
        steps.deleteCreatedDraft(scenario);
        steps.resetScenario();

        version = 0;
        steps.rejectedCasefile();
        steps.deniedCorrection();
        clearInvocations(actions);
        assertThatThrownBy(steps::assertDenied).isInstanceOf(AssertionError.class).hasMessageContaining("nonblank");
        verify(actions).get("owner-token", 123L);
    }

    @ParameterizedTest
    @ValueSource(strings = {"body", "etag"})
    void failedPutRequiresEntireUnchangedState(String change) {
        steps.rejectedCasefile();
        problem = "invalid";
        steps.invalidCorrection();
        if ("body".equals(change)) {
            current.put("extra", "changed");
        } else if ("etag".equals(change)) {
            version++;
        }
        assertThatThrownBy(steps::assertInvalid).isInstanceOf(AssertionError.class);
    }

    @ParameterizedTest
    @ValueSource(strings = {"old", "new", "unknown", "readError"})
    void ambiguousPutRetainsBothKnownCleanupCandidatesWithoutReplay(String readback) {
        steps.rejectedCasefile();
        final ObjectNode old = current.deepCopy();
        when(actions.replace(anyString(), anyLong(), anyString(), anyString())).thenAnswer(call -> {
            if ("new".equals(readback)) {
                current.set("casefile", JSON.readTree(call.getArgument(2, String.class)).path("casefile"));
                current.put("submitted_by", "checker-id").put("submitted_by_name", "Synthetic checker-id")
                    .put("casefile_status", "RESUBMITTED").put("casefile_status_name", "Resubmitted");
                snapshot(current);
                event(current, "Resubmitted", "Synthetic checker-id", null);
                version++;
            } else if ("unknown".equals(readback)) {
                current.put("submitted_by", "unrecognized");
            }
            throw new IllegalStateException("private transport token");
        });
        assertThatThrownBy(steps::anotherCorrection).isInstanceOf(AssertionError.class)
            .hasMessageContaining("ambiguous").hasMessageNotContaining("private").hasNoCause();
        assertThatThrownBy(steps::anotherCorrection).isInstanceOf(AssertionError.class);
        if ("readError".equals(readback)) {
            when(actions.get(anyString(), anyLong())).thenThrow(new IllegalStateException("private read"));
        }
        when(actions.delete(eq("owner-token"), anyLong(), anyString())).thenReturn(response(403, null, null));
        steps.deleteCreatedDraft(scenario);
        verify(actions, times(1)).replace(anyString(), anyLong(), anyString(), anyString());
        verify(actions).delete(eq("checker-token"), eq(123L), anyString());
        if (!"new".equals(readback)) {
            verify(actions).delete(eq("owner-token"), eq(123L), anyString());
        } else {
            verify(actions, never()).delete(eq("owner-token"), anyLong(), anyString());
        }
        assertThat(old.path("casefile_status").asText()).isEqualTo("REJECTED");
    }

    @Test
    void ambiguousOldReadThenOldDeleteTransportErrorStillTriesNewOwner() {
        ambiguousHandover();
        when(actions.delete(eq("owner-token"), anyLong(), anyString()))
            .thenThrow(new IllegalStateException("private token"));
        steps.deleteCreatedDraft(scenario);
        verify(actions).delete(eq("checker-token"), eq(123L), anyString());
    }

    @Test
    void unresolvedAmbiguousCleanupPreservesPrimaryAndAttachesOnlySafeEvidence() {
        ambiguousHandover();
        when(scenario.isFailed()).thenReturn(true);
        when(actions.delete(anyString(), anyLong(), anyString())).thenReturn(response(403, null, null));
        steps.deleteCreatedDraft(scenario);
        ArgumentCaptor<String> text = ArgumentCaptor.forClass(String.class);
        verify(scenario).attach(text.capture(), eq("text/plain"), anyString());
        assertThat(text.getValue()).contains("123", "E2E-", "403").doesNotContain("token", "Synthetic", "unrecognized");
        verify(actions, times(2)).delete(anyString(), eq(123L), anyString());
        steps.deleteCreatedDraft(scenario);
        verify(actions, times(2)).delete(anyString(), eq(123L), anyString());
        assertThatThrownBy(steps::originalCorrection).isInstanceOf(AssertionError.class);
    }

    @Test
    void cleanupConflictFailsOtherwisePassingScenarioAndClearsState() {
        steps.rejectedCasefile();
        when(actions.delete(anyString(), anyLong(), anyString())).thenReturn(response(409, null, null));
        assertThatThrownBy(() -> steps.deleteCreatedDraft(scenario)).isInstanceOf(AssertionError.class)
            .hasMessageContaining("409");
        steps.deleteCreatedDraft(scenario);
        verify(actions, times(1)).delete(anyString(), anyLong(), anyString());
        assertThatThrownBy(steps::originalCorrection).isInstanceOf(AssertionError.class);
    }

    @ParameterizedTest
    @ValueSource(booleans = {false, true})
    void attachmentFailureStillClearsEveryCredentialAndStateField(boolean assertionFailure) {
        ambiguousHandover();
        when(scenario.isFailed()).thenReturn(true);
        when(actions.delete(anyString(), anyLong(), anyString())).thenReturn(response(403, null, null));
        Throwable attachment = assertionFailure ? new AssertionError("private attachment token")
            : new IllegalStateException("private attachment token");
        doThrow(attachment).when(scenario).attach(anyString(), anyString(), anyString());
        assertThatThrownBy(() -> steps.deleteCreatedDraft(scenario)).isInstanceOf(AssertionError.class)
            .hasMessageContaining("123").hasMessageContaining("E2E-").hasMessageContaining("403")
            .hasMessageContaining("attachment failed").hasMessageNotContaining("private").hasNoCause();
        steps.deleteCreatedDraft(scenario);
        verify(actions, times(2)).delete(anyString(), anyLong(), anyString());
        assertThatThrownBy(steps::assertResubmitted).isInstanceOf(AssertionError.class);
    }

    @Test
    void capturedIdSurvivesLaterPostMetadataFailure() {
        doReturn(response(201, JSON.createObjectNode().put("draft_casefile_id", 123), "weak"))
            .when(actions).create(anyString(), anyString());
        assertThatThrownBy(steps::rejectedCasefile).isInstanceOf(AssertionError.class);
        steps.deleteCreatedDraft(scenario);
        verify(actions).delete(eq("owner-token"), eq(123L), anyString());
    }

    @Test
    void unknownPostIdRecordsMarkerWithoutGuessOrReplay() {
        doThrow(new IllegalStateException("private token")).when(actions).create(anyString(), anyString());
        assertThatThrownBy(steps::rejectedCasefile).isInstanceOf(AssertionError.class).hasNoCause();
        when(scenario.isFailed()).thenReturn(true);
        steps.deleteCreatedDraft(scenario);
        ArgumentCaptor<String> text = ArgumentCaptor.forClass(String.class);
        verify(scenario).attach(text.capture(), eq("text/plain"), anyString());
        assertThat(text.getValue()).contains("unknown", "E2E-").doesNotContain("private", "token");
        verify(actions, never()).delete(anyString(), anyLong(), anyString());
        verify(actions, times(1)).create(anyString(), anyString());
    }

    @Test
    void configurationOverridesResolveActualActorsWithoutLeakingTransportCauses() {
        ResubmitRejectedCasefileStepDef custom = steps(Map.of("RM_DRAFT_CASEFILE_INPUTTER_USER", "owner-override",
            "RM_DRAFT_CASEFILE_CHECKER_USER", "checker-override", "RM_DRAFT_CASEFILE_DENIED_USER", "denied-override"));
        custom.rejectedCasefile();
        problem = "forbidden";
        custom.deniedCorrection();
        custom.assertDenied();
        assertThat(users).contains("owner-override", "checker-override", "denied-override");
        custom.deleteCreatedDraft(scenario);
        when(actions.userState(anyString())).thenThrow(new IllegalStateException("private token"));
        assertThatThrownBy(custom::rejectedCasefile).isInstanceOf(AssertionError.class)
            .hasMessageNotContaining("private").hasNoCause();
    }

    @Test
    void unexpectedDeniedSuccessCannotTransferCleanupAuthority() {
        steps.rejectedCasefile();
        final ObjectNode before = current.deepCopy();
        doReturn(response(200, before, etag())).when(actions)
            .replace(eq("denied-token"), eq(123L), anyString(), anyString());
        doReturn(response(403, null, null)).when(actions).get("denied-token", 123L);
        doReturn(response(403, null, null)).when(actions)
            .delete(eq("denied-token"), eq(123L), anyString());
        when(scenario.isFailed()).thenReturn(true);

        steps.deniedCorrection();
        assertThatThrownBy(steps::assertDenied).isInstanceOf(AssertionError.class)
            .hasMessageContaining("Problem HTTP status differs");
        steps.deleteCreatedDraft(scenario);

        assertThat(current).isEqualTo(before);
        InOrder order = inOrder(actions);
        order.verify(actions).replace(eq("denied-token"), eq(123L), anyString(), eq("\"1\""));
        order.verify(actions).get("owner-token", 123L);
        order.verify(actions).delete(eq("owner-token"), eq(123L), anyString());
        verify(actions, never()).get("denied-token", 123L);
        verify(actions, never()).delete(eq("denied-token"), anyLong(), anyString());
        verify(actions, times(1)).replace(anyString(), anyLong(), anyString(), anyString());
    }

    @Test
    void authoritativeSuccessReadbackMustMatchEntirePutAndEtag() {
        steps.rejectedCasefile();
        steps.originalCorrection();
        current.put("unexpected", "changed");
        assertThatThrownBy(steps::assertResubmitted).isInstanceOf(AssertionError.class);
    }

    @Test
    void selfCheckUsesLatestOwnerCurrentVersionAndRejectionWithoutPublication() throws Exception {
        steps.rejectedCasefile();
        steps.anotherCorrection();
        steps.assertResubmitted();
        steps.selfCheckDenied();
        ArgumentCaptor<String> body = ArgumentCaptor.forClass(String.class);
        verify(actions).decide(eq("checker-token"), eq(123L), body.capture(), eq("\"2\""));
        assertThat(JSON.readTree(body.getValue()).path("casefile_status").asText()).isEqualTo("REJECTED");
        assertThat(JSON.readTree(body.getValue()).path("status_message").asText()).isEqualTo(REASON);
        assertThatThrownBy(steps::selfCheckDenied).isInstanceOf(AssertionError.class);
    }

    @Test
    void malformedSetupRejectionReadbackStopsBeforePut() {
        when(actions.get(anyString(), eq(123L))).thenAnswer(call -> {
            ObjectNode body = current.deepCopy();
            if (version == 1) {
                body.put("unexpected", "changed");
            }
            return response(200, body, etag());
        });
        assertThatThrownBy(steps::rejectedCasefile).isInstanceOf(AssertionError.class);
    }

    @Test
    void tokenResolutionErrorsAreSafe() {
        ResubmitRejectedCasefileStepDef invalid = new ResubmitRejectedCasefileStepDef(actions,
            new DraftCasefileRequestFactory(), key -> null, user -> {
                throw new IllegalStateException("private token");
            });
        assertThatThrownBy(invalid::rejectedCasefile).isInstanceOf(AssertionError.class)
            .hasMessageNotContaining("private").hasNoCause();
    }

    @Test
    void freshMarkerSurvivesEveryPutAndCleanupBoundary() throws Exception {
        steps.rejectedCasefile();
        steps.originalCorrection();
        steps.assertResubmitted();
        steps.deleteCreatedDraft(scenario);

        version = 0;
        steps.rejectedCasefile();
        ArgumentCaptor<String> bodies = ArgumentCaptor.forClass(String.class);
        verify(actions, times(2)).create(eq("owner-token"), bodies.capture());
        String first = JSON.readTree(bodies.getAllValues().get(0)).at("/casefile/respondent_account/remo_reference")
            .asText();
        String second = JSON.readTree(bodies.getAllValues().get(1)).at("/casefile/respondent_account/remo_reference")
            .asText();
        assertThat(first).matches("E2E-[0-9a-f]{16}").isNotEqualTo(second);
        verify(actions).delete("owner-token", 123L, first);
    }

    private void ambiguousHandover() {
        steps.rejectedCasefile();
        when(actions.replace(anyString(), anyLong(), anyString(), anyString()))
            .thenThrow(new IllegalStateException("private token"));
        assertThatThrownBy(steps::anotherCorrection).isInstanceOf(AssertionError.class);
    }

    private void attempt(String flow) {
        switch (flow) {
            case "original" -> steps.originalCorrection();
            case "another" -> steps.anotherCorrection();
            case "invalid" -> {
                problem = "invalid";
                steps.invalidCorrection();
            }
            case "denied" -> {
                problem = "forbidden";
                steps.deniedCorrection();
            }
            default -> {
                problem = "resource-conflict";
                steps.differentUnitCorrection();
            }
        }
    }

    private void outcome(String flow) {
        switch (flow) {
            case "original", "another" -> steps.assertResubmitted();
            case "invalid" -> steps.assertInvalid();
            case "denied" -> steps.assertDenied();
            default -> steps.assertConflict();
        }
    }

    private ResubmitRejectedCasefileStepDef steps(Map<String, String> config) {
        return new ResubmitRejectedCasefileStepDef(actions, new DraftCasefileRequestFactory(), config::get, user -> {
            users.add(user);
            return user.contains("checker") || user.contains("test-10") ? "checker-token"
                : user.contains("denied") || user.contains("test-2") ? "denied-token" : "owner-token";
        });
    }

    private ObjectNode submitted(JsonNode request) {
        ObjectNode body = JSON.createObjectNode().put("draft_casefile_id", 123).put("business_unit_id", 44)
            .put("casefile_type", "REMO In").put("casefile_status", "SUBMITTED")
            .put("casefile_status_name", "Submitted").put("created_date", DATE)
            .put("casefile_status_date", DATE).put("submitted_by", "owner-id")
            .put("submitted_by_name", "Synthetic owner-id").putNull("status_message");
        body.set("casefile", request.path("casefile").deepCopy());
        snapshot(body);
        body.putArray("timeline_data");
        event(body, "Submitted", "Synthetic owner-id", null);
        return body;
    }

    private void snapshot(ObjectNode body) {
        ObjectNode snapshot = body.putObject("casefile_snapshot");
        account(snapshot.putObject("respondent_account"), "respondent_name",
            body.at("/casefile/respondent_account/respondent/party_details"));
        account(snapshot.putObject("applicant_account"), "applicant_name",
            body.at("/casefile/applicant/party_details"));
        ArrayNode minors = snapshot.putArray("minor_creditor_accounts");
        for (JsonNode minor : body.at("/casefile/minor_creditors")) {
            account(minors.addObject().put("creditor_sequence", minor.path("creditor_sequence").intValue()),
                "name", minor.path("party_details"));
        }
    }

    private void account(ObjectNode account, String field, JsonNode party) {
        account.putNull("account_id").putNull("account_number").put(field,
            party.at("/individual_details/surname").asText().toUpperCase(java.util.Locale.ROOT) + ", "
                + party.at("/individual_details/forenames").asText());
    }

    private void event(ObjectNode body, String status, String name, String reason) {
        ObjectNode event = ((ArrayNode) body.path("timeline_data")).addObject().put("status", status)
            .put("status_date", DATE).put("username", name);
        if (reason != null) {
            event.put("reason_text", reason);
        }
    }

    private ObjectNode user(String id, int... permissions) {
        ObjectNode state = JSON.createObjectNode().put("name", "Synthetic " + id);
        ObjectNode entry = state.putObject("domains").putObject("maintenance").putArray("business_unit_users")
            .addObject().put("business_unit_id", 44).put("business_unit_user_id", id);
        ArrayNode entries = entry.putArray("permissions");
        for (int permission : permissions) {
            entries.addObject().put("permission_id", permission);
        }
        return state;
    }

    private Response problem(String kind) {
        int status = "forbidden".equals(kind) ? 403 : "invalid".equals(kind) ? 400 : 409;
        String operation = "550e8400-e29b-41d4-a716-446655440000";
        ObjectNode body = JSON.createObjectNode().put("type", "https://hmcts.gov.uk/problems/"
            + (status == 400 ? "opal-api-error" : kind))
            .put("title", status == 403 ? "Forbidden" : status == 400 ? "Bad Request" : "Conflict")
            .put("detail", status == 403 ? "You do not have permission to access this resource"
                : status == 400 ? "An error occurred while processing your request"
                    : "A conflict occurred with the requested resource")
            .put("status", status).put("retriable", false).put("operation_id", operation)
            .put("instance", "https://hmcts.gov.uk/problems/instance/" + operation);
        return new ResponseBuilder().setStatusCode(status).setContentType("application/problem+json")
            .setBody(body.toString()).build();
    }

    private ObjectNode parse(Response response) {
        try {
            return (ObjectNode) JSON.readTree(response.asString());
        } catch (java.io.IOException exception) {
            throw new AssertionError(exception);
        }
    }

    private String etag() {
        return "\"" + version + "\"";
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
