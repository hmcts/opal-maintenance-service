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
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicLong;
import java.util.function.Consumer;
import java.util.function.Function;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.function.Executable;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.ArgumentCaptor;
import org.mockito.InOrder;
import uk.gov.hmcts.opal.actions.DraftCasefileActions;
import uk.gov.hmcts.opal.actions.DraftCasefilePoller;
import uk.gov.hmcts.opal.data.DraftCasefileRequestFactory;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoMoreInteractions;
import static org.mockito.Mockito.when;

/** Glue boundary regressions use controlled HTTP responses; they do not establish live consumer/provider coverage. */
class PublishDraftCasefileStepDefTest {
    private static final ObjectMapper JSON = new ObjectMapper();
    private static final String CREATED = "2026-10-23T10:00:00Z";
    private static final String APPROVED = "2026-10-23T11:00:00Z";
    private static final String TERMINAL = "2026-10-23T11:00:01Z";
    private static final String PRIVATE = "private-sensitive-value";
    private final DraftCasefileActions actions = mock(DraftCasefileActions.class);
    private final Scenario scenario = mock(Scenario.class);
    private final List<String> users = new ArrayList<>();
    private final PublishDraftCasefileStepDef steps = steps(Map.of());
    private ObjectNode request;
    private ObjectNode current;
    private boolean approved;
    private boolean failed;
    private boolean transition = true;
    private int terminalReads;
    private String version = "\"0\"";
    private String approvalEtagOverride;
    private Consumer<ObjectNode> postChange = node -> { };
    private Consumer<ObjectNode> approvalChange = node -> { };
    private Consumer<ObjectNode> terminalChange = node -> { };
    private Consumer<ObjectNode> stableChange = node -> { };

    @BeforeEach
    void boundary() {
        when(actions.userState(anyString())).thenAnswer(call -> response(200,
            "creator-token".equals(call.getArgument(0)) ? user("creator-id", 21) : user("checker-id", 22), null));
        doAnswer(call -> {
            request = (ObjectNode) JSON.readTree(call.getArgument(1, String.class));
            failed = "not-an-amount".equals(request.at(
                "/casefile/respondent_account/order_details/order_terms/0/result_responses/0/response").asText());
            current = submitted(request);
            version = "\"0\"";
            ObjectNode post = current.deepCopy();
            post.remove("casefile");
            postChange.accept(post);
            return response(201, post, "\"0\"");
        }).when(actions).create(anyString(), anyString());
        when(actions.get(anyString(), eq(123L))).thenAnswer(call -> {
            if (approved && transition) {
                if (terminalReads++ == 0) {
                    makeTerminal();
                    terminalChange.accept(current);
                } else {
                    stableChange.accept(current);
                }
            }
            return response(200, current, version);
        });
        when(actions.decide(anyString(), eq(123L), anyString(), anyString())).thenAnswer(call -> {
            approved = true;
            current.put("casefile_status", "PUBLISHING_PENDING").put("casefile_status_name", "Publishing pending")
                .put("casefile_status_date", APPROVED).put("validated_date", APPROVED)
                .put("validated_by", "checker-id").put("validated_by_name", "Synthetic checker-id");
            event(current, "Approved", APPROVED, "Synthetic checker-id");
            approvalChange.accept(current);
            version = approvalEtagOverride == null ? "\"1\"" : approvalEtagOverride;
            return response(200, current, version);
        });
        when(actions.delete(anyString(), eq(123L), anyString())).thenReturn(response(204, null, null));
        steps.resetScenario();
    }

    @ParameterizedTest
    @CsvSource({"none,0,false", "two,2,false", "unpublishable,2,true"})
    void threeCompleteJourneys(String fixture, int minorCount, boolean terminalFailure) throws Exception {
        given(fixture);
        if (terminalFailure) {
            steps.consumerRecordsFailure();
            steps.assertFailed();
        } else {
            steps.consumerPublishes();
            steps.assertPublished();
        }
        steps.deleteCreatedDraft(scenario);
        assertThat(request.at("/casefile/minor_creditors").size()).isEqualTo(minorCount);
        if (minorCount == 2) {
            assertThat(request.at("/casefile/minor_creditors/0/creditor_sequence").intValue()).isEqualTo(7);
            assertThat(request.at("/casefile/minor_creditors/1/creditor_sequence").intValue()).isEqualTo(23);
        }
        assertThat(request.at("/casefile/respondent_account/order_details/order_terms/0/result_responses/0/response")
            .textValue()).isEqualTo(terminalFailure ? "not-an-amount" : "100.00");
        String marker = marker();
        assertThat(marker).matches("E2E-[0-9a-f]{16}");
        assertThat(users).containsExactly("opal-test@dev.platform.hmcts.net", "opal-test-10@dev.platform.hmcts.net");
        ArgumentCaptor<String> decision = ArgumentCaptor.forClass(String.class);
        InOrder order = inOrder(actions);
        order.verify(actions).userState("creator-token");
        order.verify(actions).userState("checker-token");
        order.verify(actions).create(eq("creator-token"), anyString());
        order.verify(actions).get("creator-token", 123L);
        order.verify(actions).decide(eq("checker-token"), eq(123L), decision.capture(), eq("\"0\""));
        order.verify(actions, times(2)).get("creator-token", 123L);
        order.verify(actions).delete("creator-token", 123L, marker);
        order.verifyNoMoreInteractions();
        assertThat(JSON.readTree(decision.getValue())).isEqualTo(JSON.readTree(
            "{\"business_unit_id\":44,\"casefile_status\":\"PUBLISHING_PENDING\"}"));
    }

    @Test
    void configuredActorsUseResolvedIndependentIdsAndPermitEqualDisplayNames() {
        ObjectNode creator = user("creator-id", 21).put("name", "Same synthetic display name");
        ObjectNode checker = user("checker-id", 22).put("name", "Same synthetic display name");
        when(actions.userState("creator-token")).thenReturn(response(200, creator, null));
        when(actions.userState("checker-token")).thenReturn(response(200, checker, null));
        postChange = body -> {
            body.put("submitted_by_name", "Same synthetic display name");
            current.put("submitted_by_name", "Same synthetic display name");
            ((ObjectNode) current.at("/timeline_data/0")).put("username", "Same synthetic display name");
            body.set("timeline_data", current.path("timeline_data").deepCopy());
        };
        approvalChange = body -> {
            body.put("validated_by_name", "Same synthetic display name");
            ((ObjectNode) body.at("/timeline_data/1")).put("username", "Same synthetic display name");
        };
        PublishDraftCasefileStepDef configured = steps(Map.of("RM_DRAFT_CASEFILE_INPUTTER_USER", "creator-alias",
            "RM_DRAFT_CASEFILE_CHECKER_USER", "checker-alias"));
        configured.resetScenario();
        configured.approvedCasefile("none");
        configured.consumerPublishes();
        configured.assertPublished();
        configured.deleteCreatedDraft(scenario);
        assertThat(users).containsExactly("creator-alias", "checker-alias");
    }

    @ParameterizedTest
    @ValueSource(strings = {"creator", "checker", "aliases"})
    void identicalResolvedBusinessUnitIdentitiesFailBeforePost(String role) {
        when(actions.userState("checker-token")).thenReturn(response(200, user("creator-id", 22), null));
        PublishDraftCasefileStepDef target = "aliases".equals(role)
            ? steps(Map.of("RM_DRAFT_CASEFILE_INPUTTER_USER", "creator-alias",
                "RM_DRAFT_CASEFILE_CHECKER_USER", "checker-alias")) : steps;
        target.resetScenario();
        safeFailure(() -> target.approvedCasefile("none"));
        verify(actions, never()).create(anyString(), anyString());
    }

    @ParameterizedTest
    @CsvSource({"creator,missingPermission", "checker,missingPermission", "creator,missingUnit",
        "creator,duplicateUnit", "checker,duplicatePermission", "creator,textPermission",
        "checker,zeroPermission", "creator,overflowPermission", "creator,missingDomains",
        "checker,nullMaintenance", "creator,nonArrayUnits", "checker,blankId", "creator,blankName",
        "creator,textUnit", "checker,zeroUnit", "creator,nonArrayPermissions", "checker,scalarPermission",
        "creator,scalarUnit", "checker,overflowUnit"})
    void malformedOrUnauthorisedActorsFailBeforePost(String role, String fault) {
        ObjectNode actor = user(role + "-id", "creator".equals(role) ? 21 : 22);
        ObjectNode unit = (ObjectNode) actor.at("/domains/maintenance/business_unit_users/0");
        switch (fault) {
            case "missingPermission" -> unit.putArray("permissions");
            case "missingUnit" -> unit.put("business_unit_id", 45);
            case "duplicateUnit" -> ((ArrayNode) actor.at("/domains/maintenance/business_unit_users"))
                .add(unit.deepCopy());
            case "duplicatePermission" -> ((ArrayNode) unit.path("permissions"))
                .add(unit.at("/permissions/0").deepCopy());
            case "textPermission" -> ((ObjectNode) unit.at("/permissions/0")).put("permission_id", "21");
            case "zeroPermission" -> ((ObjectNode) unit.at("/permissions/0")).put("permission_id", 0);
            case "overflowPermission" -> ((ObjectNode) unit.at("/permissions/0"))
                .put("permission_id", Long.MAX_VALUE);
            case "missingDomains" -> actor.remove("domains");
            case "nullMaintenance" -> ((ObjectNode) actor.path("domains")).putNull("maintenance");
            case "nonArrayUnits" -> ((ObjectNode) actor.at("/domains/maintenance"))
                .put("business_unit_users", PRIVATE);
            case "blankId" -> unit.put("business_unit_user_id", " ");
            case "blankName" -> actor.put("name", " ");
            case "textUnit" -> unit.put("business_unit_id", "44");
            case "zeroUnit" -> unit.put("business_unit_id", 0);
            case "overflowUnit" -> unit.put("business_unit_id", Long.MAX_VALUE);
            case "scalarPermission" -> unit.putArray("permissions").add(PRIVATE);
            case "scalarUnit" -> ((ArrayNode) actor.at("/domains/maintenance/business_unit_users")).set(0,
                JSON.getNodeFactory().textNode(PRIVATE));
            default -> unit.put("permissions", PRIVATE);
        }
        when(actions.userState(role + "-token")).thenReturn(response(200, actor, null));
        safeFailure(() -> steps.approvedCasefile("none"));
        verify(actions, never()).create(anyString(), anyString());
    }

    @ParameterizedTest
    @ValueSource(strings = {"transport", "malformed", "null", "status", "type"})
    void unsafeUserStateFailuresAreSanitised(String fault) {
        switch (fault) {
            case "transport" -> when(actions.userState(anyString())).thenThrow(new IllegalStateException(PRIVATE));
            case "malformed" -> when(actions.userState(anyString())).thenReturn(raw(200, PRIVATE, "\"0\""));
            case "null" -> when(actions.userState(anyString())).thenReturn(null);
            case "status" -> when(actions.userState(anyString())).thenReturn(response(500, null, null));
            default -> when(actions.userState(anyString())).thenReturn(new ResponseBuilder().setStatusCode(200)
                .setContentType("text/plain").setBody(PRIVATE).build());
        }
        safeFailure(() -> steps.approvedCasefile("none"));
        verify(actions, never()).create(anyString(), anyString());
    }

    @ParameterizedTest
    @ValueSource(strings = {"tokenException", "nullToken", "blankToken", "configException"})
    void credentialFailuresHaveNoPrivateCause(String fault) {
        Function<String, String> config = key -> {
            if ("configException".equals(fault)) {
                throw new IllegalStateException(PRIVATE);
            }
            return null;
        };
        Function<String, String> tokens = user -> {
            if ("tokenException".equals(fault)) {
                throw new IllegalStateException(PRIVATE);
            }
            return "nullToken".equals(fault) ? null : " ";
        };
        PublishDraftCasefileStepDef target = new PublishDraftCasefileStepDef(actions,
            new DraftCasefileRequestFactory(), poller(), config, tokens);
        target.resetScenario();
        safeFailure(() -> target.approvedCasefile("none"));
        verify(actions, never()).create(anyString(), anyString());
    }

    @Test
    void freshMarkersAndOneFreshCreatePerScenario() {
        steps.approvedCasefile("none");
        final String first = marker();
        safeFailure(() -> steps.approvedCasefile("two"));
        steps.deleteCreatedDraft(scenario);
        approved = false;
        steps.resetScenario();
        steps.approvedCasefile("two");
        assertThat(marker()).matches("E2E-[0-9a-f]{16}").isNotEqualTo(first);
        steps.deleteCreatedDraft(scenario);
        verify(actions, times(2)).create(anyString(), anyString());
    }

    @ParameterizedTest
    @ValueSource(strings = {"etag", "type", "submitter", "name", "getBody", "getVersion"})
    void idIsCapturedBeforePostMetadataOrInitialGetFailure(String fault) {
        postChange = body -> {
            if ("submitter".equals(fault)) {
                body.put("submitted_by", PRIVATE);
            } else if ("name".equals(fault)) {
                body.put("submitted_by_name", PRIVATE);
            }
        };
        if ("etag".equals(fault) || "type".equals(fault)) {
            doAnswer(call -> {
                request = (ObjectNode) JSON.readTree(call.getArgument(1, String.class));
                ResponseBuilder builder = new ResponseBuilder().setStatusCode(201)
                    .setContentType("type".equals(fault) ? "text/plain" : "application/json")
                    .setBody("{\"draft_casefile_id\":123}");
                return builder.setHeader("ETag", "etag".equals(fault) ? "W/\"0\"" : "\"0\"").build();
            }).when(actions).create(anyString(), anyString());
        } else if ("getBody".equals(fault)) {
            when(actions.get(anyString(), anyLong())).thenReturn(raw(200, PRIVATE, "\"0\""));
        } else if ("getVersion".equals(fault)) {
            when(actions.get(anyString(), anyLong())).thenAnswer(call -> response(200, current, "\"1\""));
        }
        safeFailure(() -> steps.approvedCasefile("none"));
        steps.deleteCreatedDraft(scenario);
        verify(actions).delete(eq("creator-token"), eq(123L), anyString());
        verify(actions, never()).decide(anyString(), anyLong(), anyString(), anyString());
    }

    @ParameterizedTest
    @ValueSource(strings = {"transport", "malformed201", "noId", "negativeId", "stringId", "overflowId",
        "fractionId", "server", "null", "trailingJson"})
    void ambiguousCreatesKeepMarkerOnlyLedgerWithoutReplayOrGuessedId(String fault) {
        doAnswer(call -> {
            request = (ObjectNode) JSON.readTree(call.getArgument(1, String.class));
            return switch (fault) {
                case "transport" -> throw new IllegalStateException(PRIVATE);
                case "malformed201" -> raw(201, PRIVATE, "\"0\"");
                case "trailingJson" -> raw(201, "{\"draft_casefile_id\":123} {}", "\"0\"");
                case "noId" -> raw(201, "{}", "\"0\"");
                case "negativeId" -> raw(201, "{\"draft_casefile_id\":-1}", "\"0\"");
                case "stringId" -> raw(201, "{\"draft_casefile_id\":\"123\"}", "\"0\"");
                case "overflowId" -> raw(201, "{\"draft_casefile_id\":9223372036854775808}", "\"0\"");
                case "fractionId" -> raw(201, "{\"draft_casefile_id\":1.5}", "\"0\"");
                case "server" -> response(503, null, null);
                default -> null;
            };
        }).when(actions).create(anyString(), anyString());
        safeFailure(() -> steps.approvedCasefile("none"));
        safeFailure(() -> steps.approvedCasefile("none"));
        when(scenario.isFailed()).thenReturn(true);
        steps.deleteCreatedDraft(scenario);
        String evidence = attached();
        assertThat(evidence).contains(marker(), "no captured ID", "not replay", "manual recovery");
        verify(actions, times(1)).create(anyString(), anyString());
        verify(actions, never()).delete(anyString(), anyLong(), anyString());
        verify(actions, never()).get(anyString(), anyLong());
        steps.deleteCreatedDraft(scenario);
        verify(scenario, times(1)).attach(anyString(), anyString(), anyString());
    }

    @ParameterizedTest
    @ValueSource(strings = {"status", "actor", "immutable", "validationDate", "etag", "transport"})
    void invalidApprovalFailsAndRetainsOriginalOwnerForCleanup(String fault) {
        approvalChange = body -> {
            switch (fault) {
                case "actor" -> body.put("validated_by", PRIVATE);
                case "immutable" -> body.put("submitted_by", PRIVATE);
                case "validationDate" -> body.remove("validated_date");
                default -> { }
            }
        };
        if ("status".equals(fault)) {
            doReturn(response(409, null, null)).when(actions)
                .decide(anyString(), anyLong(), anyString(), anyString());
        } else if ("transport".equals(fault)) {
            doThrow(new IllegalStateException(PRIVATE)).when(actions)
                .decide(anyString(), anyLong(), anyString(), anyString());
        } else if ("etag".equals(fault)) {
            approvalEtagOverride = "\"0\"";
        }
        safeFailure(() -> steps.approvedCasefile("none"));
        steps.deleteCreatedDraft(scenario);
        verify(actions).delete(eq("creator-token"), eq(123L), anyString());
        verify(actions, times(1)).decide(anyString(), anyLong(), anyString(), anyString());
    }

    @ParameterizedTest
    @ValueSource(strings = {"wrongState", "deadline", "transport", "malformed", "null"})
    void pollFailureIsStrictAndCleanupStillUsesCapturedOwner(String fault) {
        steps.approvedCasefile("none");
        switch (fault) {
            case "wrongState" -> failed = true;
            case "deadline" -> transition = false;
            case "transport" -> when(actions.get(anyString(), anyLong()))
                .thenThrow(new IllegalStateException(PRIVATE));
            case "malformed" -> when(actions.get(anyString(), anyLong())).thenReturn(raw(200, PRIVATE, "\"2\""));
            default -> when(actions.get(anyString(), anyLong())).thenReturn(null);
        }
        AssertionError failure = safeFailure(steps::consumerPublishes);
        if ("deadline".equals(fault)) {
            assertThat(failure).hasMessageContaining("deadline");
        }
        steps.deleteCreatedDraft(scenario);
        verify(actions).delete(eq("creator-token"), eq(123L), anyString());
    }

    @ParameterizedTest
    @ValueSource(strings = {"checksum", "immutable", "unsafeMessage", "missingIdentity"})
    void strictTerminalOracleIsInvokedBeforeStableRead(String fault) {
        terminalChange = body -> {
            switch (fault) {
                case "checksum" -> ((ObjectNode) body.at("/casefile_snapshot/respondent_account"))
                    .put("account_number", "12345678Z");
                case "immutable" -> body.put("validated_date", TERMINAL);
                case "missingIdentity" -> ((ObjectNode) body.at("/casefile_snapshot/applicant_account"))
                    .putNull("account_id");
                default -> body.put("status_message", PRIVATE);
            }
        };
        if ("unsafeMessage".equals(fault)) {
            steps.approvedUnpublishableCasefile();
            steps.consumerRecordsFailure();
            safeFailure(steps::assertFailed);
        } else {
            steps.approvedCasefile("two");
            steps.consumerPublishes();
            safeFailure(steps::assertPublished);
        }
        assertThat(terminalReads).isEqualTo(1);
        steps.deleteCreatedDraft(scenario);
    }

    @ParameterizedTest
    @CsvSource({"published,body", "published,etag", "failed,body", "failed,etag"})
    void stableReadRequiresExactTerminalBodyAndEtag(String outcome, String fault) {
        stableChange = body -> {
            if ("body".equals(fault)) {
                body.put("extra", PRIVATE);
            } else {
                version = "\"03\"";
            }
        };
        if ("failed".equals(outcome)) {
            steps.approvedUnpublishableCasefile();
            steps.consumerRecordsFailure();
            safeFailure(steps::assertFailed);
        } else {
            steps.approvedCasefile("two");
            steps.consumerPublishes();
            safeFailure(steps::assertPublished);
        }
        assertThat(terminalReads).isEqualTo(2);
        steps.deleteCreatedDraft(scenario);
    }

    @ParameterizedTest
    @CsvSource({"false,status", "true,status", "false,transport", "true,transport", "false,null", "true,null"})
    void cleanupFailureReportsSafeEvidenceAndClearsState(boolean primaryFailed, String fault) {
        steps.approvedCasefile("none");
        if ("status".equals(fault)) {
            when(actions.delete(anyString(), anyLong(), anyString())).thenReturn(response(409, null, null));
        } else if ("transport".equals(fault)) {
            when(actions.delete(anyString(), anyLong(), anyString())).thenThrow(new IllegalStateException(PRIVATE));
        } else {
            when(actions.delete(anyString(), anyLong(), anyString())).thenReturn(null);
        }
        when(scenario.isFailed()).thenReturn(primaryFailed);
        String evidence;
        if (primaryFailed) {
            steps.deleteCreatedDraft(scenario);
            evidence = attached();
        } else {
            evidence = safeFailure(() -> steps.deleteCreatedDraft(scenario)).getMessage();
        }
        assertThat(evidence).contains("123", marker(), "status".equals(fault) ? "409" : "request error");
        steps.deleteCreatedDraft(scenario);
        verify(actions, times(1)).delete(eq("creator-token"), eq(123L), anyString());
    }

    @ParameterizedTest
    @ValueSource(strings = {"runtime", "assertion"})
    void attachmentFailureRetainsFullSafeLedgerAndClearsState(String fault) {
        steps.approvedCasefile("none");
        when(actions.delete(anyString(), anyLong(), anyString())).thenReturn(response(409, null, null));
        when(scenario.isFailed()).thenReturn(true);
        if ("runtime".equals(fault)) {
            doThrow(new IllegalStateException(PRIVATE)).when(scenario).attach(anyString(), anyString(), anyString());
        } else {
            doThrow(new AssertionError(PRIVATE)).when(scenario).attach(anyString(), anyString(), anyString());
        }
        AssertionError failure = safeFailure(() -> steps.deleteCreatedDraft(scenario));
        assertThat(failure).hasMessageContaining("123").hasMessageContaining(marker()).hasMessageContaining("409")
            .hasMessageContaining("attachment failed");
        steps.deleteCreatedDraft(scenario);
        verify(actions, times(1)).delete(anyString(), anyLong(), anyString());
    }

    @ParameterizedTest
    @ValueSource(strings = {"creator-alias", "CREATOR-ALIAS"})
    void sameConfiguredUsersFailBeforeCredentialsOrNetwork(String checkerUser) {
        PublishDraftCasefileStepDef target = new PublishDraftCasefileStepDef(actions,
            new DraftCasefileRequestFactory(), poller(), Map.of("RM_DRAFT_CASEFILE_INPUTTER_USER", "creator-alias",
                "RM_DRAFT_CASEFILE_CHECKER_USER", checkerUser)::get, user -> {
                    // Even a seam capable of distinct tokens/resolved IDs must never run for the same user.
                    users.add(user);
                    return users.size() == 1 ? "creator-token" : "checker-token";
                });
        target.resetScenario();
        safeFailure(() -> target.approvedCasefile("none"));
        assertThat(users).isEmpty();
        verifyNoMoreInteractions(actions);
    }

    @Test
    void successfulCleanupAfterPrimaryFailureDoesNotAttachOrRetry() {
        steps.approvedCasefile("none");
        when(scenario.isFailed()).thenReturn(true);
        steps.deleteCreatedDraft(scenario);
        steps.deleteCreatedDraft(scenario);
        verify(actions, times(1)).delete(eq("creator-token"), eq(123L), anyString());
        verifyNoMoreInteractions(scenario);
    }

    @Test
    void failedOracleRejectsInventedIdentityBeforeStableRead() {
        terminalChange = body -> ((ObjectNode) body.at("/casefile_snapshot/respondent_account"))
            .put("account_id", 900);
        steps.approvedUnpublishableCasefile();
        steps.consumerRecordsFailure();
        safeFailure(steps::assertFailed);
        assertThat(terminalReads).isEqualTo(1);
        steps.deleteCreatedDraft(scenario);
    }

    @ParameterizedTest
    @ValueSource(strings = {"runtime", "assertion"})
    void unknownIdAttachmentFailureStillRetainsMarkerAndRecoveryInstructions(String fault) {
        doAnswer(call -> {
            request = (ObjectNode) JSON.readTree(call.getArgument(1, String.class));
            throw new IllegalStateException(PRIVATE);
        }).when(actions).create(anyString(), anyString());
        safeFailure(() -> steps.approvedCasefile("none"));
        when(scenario.isFailed()).thenReturn(true);
        if ("runtime".equals(fault)) {
            doThrow(new IllegalStateException(PRIVATE)).when(scenario).attach(anyString(), anyString(), anyString());
        } else {
            doThrow(new AssertionError(PRIVATE)).when(scenario).attach(anyString(), anyString(), anyString());
        }
        AssertionError failure = safeFailure(() -> steps.deleteCreatedDraft(scenario));
        assertThat(failure).hasMessageContaining(marker()).hasMessageContaining("no captured ID")
            .hasMessageContaining("manual recovery").hasMessageContaining("attachment failed");
        steps.deleteCreatedDraft(scenario);
        verify(actions, never()).delete(anyString(), anyLong(), anyString());
        verify(scenario, times(1)).attach(anyString(), anyString(), anyString());
    }

    @Test
    void hooksAreScopedToOnlyThisFeatureTag() throws Exception {
        assertThat(PublishDraftCasefileStepDef.class.getMethod("resetScenario").getAnnotation(Before.class).value())
            .isEqualTo("@PO10621");
        assertThat(PublishDraftCasefileStepDef.class.getMethod("deleteCreatedDraft", Scenario.class)
            .getAnnotation(After.class).value()).isEqualTo("@PO10621");
    }

    @Test
    void cleanupWithoutAnAttemptDoesNothing() {
        steps.deleteCreatedDraft(scenario);
        verifyNoMoreInteractions(actions, scenario);
    }

    private void given(String fixture) {
        if ("unpublishable".equals(fixture)) {
            steps.approvedUnpublishableCasefile();
        } else {
            steps.approvedCasefile(fixture);
        }
    }

    private PublishDraftCasefileStepDef steps(Map<String, String> config) {
        return new PublishDraftCasefileStepDef(actions, new DraftCasefileRequestFactory(), poller(), config::get,
            user -> {
                users.add(user);
                return user.contains("checker") || user.contains("test-10") ? "checker-token" : "creator-token";
            });
    }

    private DraftCasefilePoller poller() {
        AtomicLong clock = new AtomicLong();
        return new DraftCasefilePoller(Duration.ofMillis(3), Duration.ofMillis(1), clock::get,
            millis -> clock.addAndGet(Duration.ofMillis(millis).toNanos()));
    }

    private AssertionError safeFailure(Executable executable) {
        AssertionError failure = assertThrows(AssertionError.class, executable);
        assertThat(failure).hasNoCause().hasMessageNotContaining(PRIVATE);
        return failure;
    }

    private String attached() {
        ArgumentCaptor<String> evidence = ArgumentCaptor.forClass(String.class);
        verify(scenario).attach(evidence.capture(), eq("text/plain"), anyString());
        assertThat(evidence.getValue()).doesNotContain(PRIVATE, "creator-token", "checker-token", "Synthetic");
        return evidence.getValue();
    }

    private String marker() {
        return request.at("/casefile/respondent_account/remo_reference").textValue();
    }

    private ObjectNode user(String id, int permission) {
        ObjectNode body = JSON.createObjectNode().put("name", "Synthetic " + id);
        body.putObject("domains").putObject("maintenance").putArray("business_unit_users").addObject()
            .put("business_unit_id", 44).put("business_unit_user_id", id)
            .putArray("permissions").addObject().put("permission_id", permission);
        return body;
    }

    private ObjectNode submitted(JsonNode original) {
        ObjectNode body = JSON.createObjectNode().put("draft_casefile_id", 123).put("business_unit_id", 44)
            .put("casefile_type", "REMO In").put("casefile_status", "SUBMITTED")
            .put("casefile_status_name", "Submitted").put("created_date", CREATED)
            .put("casefile_status_date", CREATED).put("submitted_by", "creator-id")
            .put("submitted_by_name", "Synthetic creator-id").putNull("status_message");
        body.set("casefile", original.path("casefile").deepCopy());
        ObjectNode snapshot = body.putObject("casefile_snapshot");
        account(snapshot.putObject("respondent_account"), "respondent_name", "RESPONDENT, Synthetic");
        account(snapshot.putObject("applicant_account"), "applicant_name", "APPLICANT, Synthetic");
        ArrayNode minors = snapshot.putArray("minor_creditor_accounts");
        for (JsonNode minor : original.at("/casefile/minor_creditors")) {
            account(minors.addObject().put("creditor_sequence", minor.path("creditor_sequence").intValue()),
                "name", minor.at("/party_details/individual_details/surname").textValue()
                    .toUpperCase(java.util.Locale.ROOT) + ", Synthetic");
        }
        body.putArray("timeline_data");
        event(body, "Submitted", CREATED, "Synthetic creator-id");
        return body;
    }

    private void account(ObjectNode node, String field, String name) {
        node.putNull("account_id").putNull("account_number").put(field, name);
    }

    private void event(ObjectNode body, String status, String date, String name) {
        ((ArrayNode) body.path("timeline_data")).addObject().put("status", status).put("status_date", date)
            .put("username", name);
    }

    private void makeTerminal() {
        current.put("casefile_status", failed ? "PUBLISHING_FAILED" : "PUBLISHED")
            .put("casefile_status_name", failed ? "Publishing failed" : "Published")
            .put("casefile_status_date", TERMINAL);
        if (failed) {
            current.put("status_message", "Publication failed; contact support");
        } else {
            identity((ObjectNode) current.at("/casefile_snapshot/respondent_account"), 701, "12345678H");
            identity((ObjectNode) current.at("/casefile_snapshot/applicant_account"), 801, "11111111R");
            int index = 0;
            String[] numbers = {"22222222L", "33333333F"};
            for (JsonNode minor : current.at("/casefile_snapshot/minor_creditor_accounts")) {
                identity((ObjectNode) minor, 802 + index, numbers[index++]);
            }
        }
        version = "\"2\"";
    }

    private void identity(ObjectNode account, long id, String number) {
        account.put("account_id", id).put("account_number", number);
    }

    private Response response(int status, JsonNode body, String etag) {
        return raw(status, body == null ? "" : body.toString(), etag);
    }

    private Response raw(int status, String body, String etag) {
        ResponseBuilder builder = new ResponseBuilder().setStatusCode(status).setContentType("application/json")
            .setBody(body);
        if (etag != null) {
            builder.setHeader("ETag", etag);
        }
        return builder.build();
    }
}
