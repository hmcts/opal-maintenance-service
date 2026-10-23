package uk.gov.hmcts.opal.steps;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import io.cucumber.java.Scenario;
import io.restassured.builder.ResponseBuilder;
import io.restassured.response.Response;
import java.time.Duration;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.ArgumentCaptor;
import uk.gov.hmcts.opal.actions.DraftCasefileActions;
import uk.gov.hmcts.opal.actions.DraftCasefilePoller;
import uk.gov.hmcts.opal.data.DraftCasefileRequestFactory;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class ListDraftCasefilesStepDefTest {
    private static final ObjectMapper JSON = new ObjectMapper();
    private static final String OWNER = "owner-token";
    private static final String CHECKER = "checker-token";
    private final DraftCasefileActions actions = mock(DraftCasefileActions.class);
    private final Scenario scenario = mock(Scenario.class);
    private final Map<Long, ObjectNode> rows = new LinkedHashMap<>();
    private final Map<Long, String> owners = new LinkedHashMap<>();
    private final Map<Long, String> markers = new LinkedHashMap<>();
    private final List<Map<String, String>> queries = new ArrayList<>();
    private final List<String> queryTokens = new ArrayList<>();
    private final List<String> resolvedUsers = new ArrayList<>();
    private final List<JsonNode> decisions = new ArrayList<>();
    private ListDraftCasefilesStepDef steps;
    private Consumer<ObjectNode> changeCreated = row -> { };
    private Consumer<ObjectNode> changeListRow = row -> { };
    private Consumer<ObjectNode> changeTerminal = row -> { };
    private boolean stayPending;

    @BeforeEach
    void syntheticHttpBoundary() {
        steps = steps(Map.of());
        when(actions.create(anyString(), anyString())).thenAnswer(invocation -> {
            String token = invocation.getArgument(0);
            JsonNode request = JSON.readTree(invocation.getArgument(1, String.class));
            long id = 101L + rows.size();
            ObjectNode row = submitted(id, request, token);
            changeCreated.accept(row);
            rows.put(id, row);
            owners.put(id, token);
            markers.put(id, request.at("/casefile/respondent_account/remo_reference").textValue());
            ObjectNode post = row.deepCopy();
            post.remove("casefile");
            return response(201, post, "\"0\"");
        });
        when(actions.get(anyString(), anyLong())).thenAnswer(invocation -> {
            long id = invocation.getArgument(1);
            assertThat(invocation.getArgument(0, String.class)).isEqualTo(owners.get(id));
            ObjectNode row = rows.get(id);
            if ("PUBLISHING_PENDING".equals(row.path("casefile_status").textValue()) && !stayPending) {
                publish(row);
            }
            return response(200, row, "\"5\"");
        });
        when(actions.decide(anyString(), anyLong(), anyString(), anyString())).thenAnswer(invocation -> {
            assertThat(invocation.getArgument(0, String.class)).isEqualTo(CHECKER);
            assertThat(invocation.getArgument(3, String.class)).isEqualTo("\"5\"");
            ObjectNode row = rows.get(invocation.getArgument(1, Long.class));
            JsonNode decision = JSON.readTree(invocation.getArgument(2, String.class));
            decisions.add(decision);
            String status = decision.path("casefile_status").textValue();
            assertThat(decision.path("business_unit_id").intValue()).isEqualTo(44);
            row.put("casefile_status", status).put("casefile_status_name", status)
                .put("casefile_status_date", "2026-10-23T01:01:00Z");
            if ("PUBLISHING_PENDING".equals(status)) {
                assertThat(decision.has("status_message")).isFalse();
                row.put("validated_by", "BU-CHECKER").put("validated_by_name", "Synthetic Checker")
                    .put("validated_date", "2026-10-23T01:01:00Z");
            } else {
                assertThat(status).isEqualTo("REJECTED");
                assertThat(decision.path("status_message").textValue()).isNotBlank();
                row.set("status_message", decision.path("status_message"));
            }
            ((ArrayNode) row.path("timeline_data")).addObject()
                .put("status", "REJECTED".equals(status) ? "Rejected" : "Approved")
                .put("status_date", "2026-10-23T01:01:00Z").put("username", "Synthetic Checker");
            return response(200, row, "\"6\"");
        });
        when(actions.list(anyString(), any())).thenAnswer(invocation -> {
            String token = invocation.getArgument(0);
            Map<String, String> query = invocation.getArgument(1);
            queries.add(Map.copyOf(query));
            queryTokens.add(token);
            assertThat(query.get("business_unit_id")).isEqualTo("44");
            ArrayNode summaries = JSON.createArrayNode();
            for (ObjectNode row : rows.values()) {
                if (matches(row, query)) {
                    ObjectNode summary = summary(row);
                    changeListRow.accept(summary);
                    summaries.add(summary);
                }
            }
            ObjectNode result = JSON.createObjectNode().put("count", summaries.size());
            if (!"counts".equals(query.get("restrict"))) {
                result.set("summaries", summaries);
            }
            return response(200, result, null);
        });
        when(actions.delete(anyString(), anyLong(), anyString())).thenAnswer(invocation -> {
            long id = invocation.getArgument(1);
            assertThat(invocation.getArgument(0, String.class)).isEqualTo(owners.get(id));
            assertThat(invocation.getArgument(2, String.class)).isEqualTo(markers.get(id));
            return response(204, JSON.createObjectNode(), null);
        });
        steps.resetScenario();
    }

    @Test
    void completeFilterJourneyUsesRealPostIdentitiesUtcDayAndAllOwnedNegatives() {
        steps.prepareFilters();
        steps.list();
        steps.assertFiltered();
        steps.deleteCreatedDrafts(scenario);

        assertThat(queries).containsExactly(Map.of("business_unit_id", "44", "submitted_by", "BU-OWNER",
            "not_submitted_by", "BU-CHECKER", "casefile_status", "SUBMITTED,RESUBMITTED",
            "casefile_status_from_date", "2026-10-23", "casefile_status_to_date", "2026-10-23"));
        assertThat(queryTokens).containsExactly(OWNER);
        assertThat(decisions).hasSize(1);
        assertThat(decisions.get(0).path("casefile_status").textValue()).isEqualTo("REJECTED");
        assertCleanup(3);
        assertThat(markers.values()).hasSize(3).doesNotHaveDuplicates()
            .allMatch(marker -> marker.matches("E2E-[0-9a-f]{16}"));
    }

    @Test
    void completeRejectedCountJourneyUsesMatchingNormalAndCountFilters() {
        steps.prepareRejected();
        addSharedMatchingRow();
        steps.list();
        steps.assertCounts();
        steps.deleteCreatedDrafts(scenario);

        assertCountQueries("REJECTED");
        assertThat(decisions).hasSize(1);
        assertCleanup(1);
    }

    @Test
    void completeFailedCountJourneyUsesApprovalAndStrictRealPoller() {
        steps.prepareFailed();
        steps.list();
        steps.assertCounts();
        steps.deleteCreatedDrafts(scenario);

        assertCountQueries("PUBLISHING_FAILED");
        assertApprovalAndPolling();
        assertCleanup(1);
    }

    @Test
    void completeReviewJourneyUsesCheckerTokenAndCheckerPostIdentityForExclusion() {
        steps.prepareReview();
        steps.list();
        steps.assertReview();
        steps.deleteCreatedDrafts(scenario);

        assertThat(queries).containsExactly(Map.of("business_unit_id", "44",
            "not_submitted_by", "BU-CHECKER", "casefile_status", "SUBMITTED,RESUBMITTED"));
        assertThat(queryTokens).containsExactly(CHECKER);
        assertCleanup(2);
    }

    @Test
    void completeEmptyJourneyUsesContradictoryActualPostIdentity() {
        steps.prepareEmpty();
        steps.list();
        steps.assertEmpty();
        steps.deleteCreatedDrafts(scenario);

        assertThat(queries).containsExactly(Map.of("business_unit_id", "44", "submitted_by", "BU-OWNER",
            "not_submitted_by", "BU-OWNER", "casefile_status", "SUBMITTED"));
        assertThat(queryTokens).containsExactly(OWNER);
        assertCleanup(1);
    }

    @Test
    void completePublishedJourneyPairsFullRetrievalWithSummaryAndPreservesAllFourAccountIdentities() {
        steps.preparePublished();
        steps.list();
        steps.assertPublished();
        steps.deleteCreatedDrafts(scenario);

        assertThat(queries).containsExactly(Map.of("business_unit_id", "44", "submitted_by", "BU-OWNER",
            "casefile_status", "PUBLISHED"));
        assertThat(queryTokens).containsExactly(OWNER);
        assertApprovalAndPolling();
        verify(actions, times(3)).get(OWNER, 101L);
        assertCleanup(1);
    }

    @Test
    void completeFailedSummaryJourneyPairsRetrievalAndRetainsNullIdentitiesAndApprovalHistory() {
        steps.prepareFailed();
        steps.list();
        steps.assertFailed();
        steps.deleteCreatedDrafts(scenario);

        assertThat(queries).containsExactly(Map.of("business_unit_id", "44", "submitted_by", "BU-OWNER",
            "casefile_status", "PUBLISHING_FAILED"));
        assertApprovalAndPolling();
        verify(actions, times(3)).get(OWNER, 101L);
        assertCleanup(1);
    }

    @ParameterizedTest
    @ValueSource(ints = {0, 1})
    void consistentPostAndStoredMinorLossFailsBeforeApprovalAndRetainsCleanupOwnership(int retained) throws Exception {
        changeCreated = row -> {
            ArrayNode casefileMinors = (ArrayNode) row.at("/casefile/minor_creditors");
            ArrayNode snapshotMinors = (ArrayNode) row.at("/casefile_snapshot/minor_creditor_accounts");
            while (casefileMinors.size() > retained) {
                casefileMinors.remove(casefileMinors.size() - 1);
                snapshotMinors.remove(snapshotMinors.size() - 1);
            }
        };

        assertThatThrownBy(steps::preparePublished).isInstanceOf(AssertionError.class)
            .hasMessageContaining("casefile must match the request");
        ArgumentCaptor<String> source = ArgumentCaptor.forClass(String.class);
        verify(actions).create(eq(OWNER), source.capture());
        assertThat(JSON.readTree(source.getValue()).at("/casefile/minor_creditors").size()).isEqualTo(2);
        assertThat(rows.get(101L).at("/casefile/minor_creditors").size()).isEqualTo(retained);
        assertThat(rows.get(101L).at("/casefile_snapshot/minor_creditor_accounts").size()).isEqualTo(retained);
        verify(actions, never()).decide(anyString(), anyLong(), anyString(), anyString());
        assertThat(queries).isEmpty();
        when(scenario.isFailed()).thenReturn(true);
        steps.deleteCreatedDrafts(scenario);
        assertCleanup(1);
    }

    @Test
    void changedSummarySnapshotFailsSharedFieldVerificationWithoutExposingPayload() {
        steps.preparePublished();
        changeListRow = row -> ((ObjectNode) row.path("casefile_snapshot")).put("private", "private payload");
        steps.list();
        assertThatThrownBy(steps::assertPublished).isInstanceOf(AssertionError.class)
            .hasMessageContaining("Shared summary and detail field differs").hasMessageNotContaining("private payload");
        when(scenario.isFailed()).thenReturn(true);
        steps.deleteCreatedDrafts(scenario);
        assertCleanup(1);
    }

    @Test
    void changedTerminalHistoryIsRejectedBeforeList() {
        changeTerminal = row -> ((ArrayNode) row.path("timeline_data")).addObject().put("status", "Published");
        assertThatThrownBy(steps::preparePublished).isInstanceOf(AssertionError.class)
            .hasMessageContaining("timeline_data must be retained");
        when(scenario.isFailed()).thenReturn(true);
        steps.deleteCreatedDrafts(scenario);
        assertCleanup(1);
    }

    @Test
    void failedSetupCapturesIdBeforeMetadataAssertionsAndStillDeletes() {
        when(actions.create(anyString(), anyString())).thenReturn(response(201,
            JSON.createObjectNode().put("draft_casefile_id", 909), "\"0\""));
        when(actions.delete(eq(OWNER), eq(909L), anyString())).thenReturn(response(204, JSON.createObjectNode(), null));
        assertThatThrownBy(steps::prepareEmpty).isInstanceOf(AssertionError.class);
        when(scenario.isFailed()).thenReturn(true);
        steps.deleteCreatedDrafts(scenario);
        verify(actions).delete(eq(OWNER), eq(909L), anyString());
    }

    @Test
    void malformed201ReportsUnknownMarkerWithoutGuessingIdOrRepeatingPost() {
        when(actions.create(anyString(), anyString())).thenReturn(new ResponseBuilder().setStatusCode(201)
            .setContentType("application/json").setBody("private invalid payload").build());
        assertThatThrownBy(steps::prepareEmpty).isInstanceOf(AssertionError.class).hasNoCause()
            .hasMessageNotContaining("private");
        when(scenario.isFailed()).thenReturn(true);
        steps.deleteCreatedDrafts(scenario);
        assertThat(attachment()).contains("Unknown owned create ID", "E2E-", "operator follow-up")
            .doesNotContain("private", OWNER);
        verify(actions, times(1)).create(anyString(), anyString());
        verify(actions, never()).delete(anyString(), anyLong(), anyString());
    }

    @Test
    void interruptedPostRetainsUnknownOwnershipAndSanitizesCause() {
        when(actions.create(anyString(), anyString())).thenThrow(new IllegalStateException("private owner-token"));
        assertThatThrownBy(steps::prepareEmpty).isInstanceOf(AssertionError.class).hasNoCause()
            .hasMessageNotContaining("private");
        when(scenario.isFailed()).thenReturn(true);
        steps.deleteCreatedDrafts(scenario);
        assertThat(attachment()).contains("Unknown owned create ID", "E2E-").doesNotContain("private", OWNER);
    }

    @Test
    void cleanupAttemptsEveryOwnedDraftAfterConflictAndRequestExceptionUsingOriginalTokens() {
        steps.prepareFilters();
        when(actions.delete(eq(OWNER), eq(101L), anyString()))
            .thenReturn(response(409, JSON.createObjectNode().put("private", "payload"), null));
        when(actions.delete(eq(CHECKER), eq(102L), anyString()))
            .thenThrow(new IllegalStateException("private checker-token"));
        assertThatThrownBy(() -> steps.deleteCreatedDrafts(scenario)).isInstanceOf(AssertionError.class)
            .hasMessageContaining("101").hasMessageContaining("102").hasMessageContaining("409")
            .hasMessageContaining("request error").hasMessageNotContaining("private")
            .hasMessageNotContaining(CHECKER).hasNoCause();
        assertCleanup(3);
        steps.deleteCreatedDrafts(scenario);
        assertCleanup(3);
    }

    @Test
    void primaryFailureIsPreservedAndSafeLedgerAttachedAfterAllCleanupAttempts() {
        steps.prepareReview();
        when(actions.delete(eq(OWNER), eq(101L), anyString())).thenReturn(response(409, JSON.createObjectNode(), null));
        when(scenario.isFailed()).thenReturn(true);
        steps.deleteCreatedDrafts(scenario);
        assertThat(attachment()).contains("101", "409", "E2E-").doesNotContain(OWNER, CHECKER, "Synthetic");
        assertCleanup(2);
    }

    @Test
    void attachmentFailureStillClearsCredentialsAndPreservesPrimaryFailure() {
        steps.prepareEmpty();
        when(actions.delete(eq(OWNER), eq(101L), anyString())).thenReturn(response(409, JSON.createObjectNode(), null));
        when(scenario.isFailed()).thenReturn(true);
        doThrow(new IllegalStateException("private")).when(scenario).attach(anyString(), anyString(), anyString());
        assertThatThrownBy(() -> steps.deleteCreatedDrafts(scenario)).isInstanceOf(AssertionError.class)
            .hasMessageContaining("101").hasMessageContaining("409").hasMessageContaining("E2E-")
            .hasMessageContaining("attachment failed").hasMessageNotContaining("private").hasNoCause();
        steps.deleteCreatedDrafts(scenario);
        assertCleanup(1);
    }

    @Test
    void defaultsAndOverridesResolveBothRoleIdentitiesWithoutGuessingBusinessUnitUserIds() {
        steps.prepareReview();
        assertThat(resolvedUsers).containsExactly("opal-test@dev.platform.hmcts.net",
            "opal-test-10@dev.platform.hmcts.net");
        steps.deleteCreatedDrafts(scenario);
        resolvedUsers.clear();
        ListDraftCasefilesStepDef overrides = steps(Map.of("RM_DRAFT_CASEFILE_INPUTTER_USER", "owner-override",
            "RM_DRAFT_CASEFILE_CHECKER_USER", "checker-override"));
        overrides.prepareReview();
        overrides.list();
        overrides.assertReview();
        overrides.deleteCreatedDrafts(scenario);
        assertThat(resolvedUsers).containsExactly("owner-override", "checker-override");
        assertThat(queries.get(0).get("not_submitted_by")).isEqualTo("BU-CHECKER");
    }

    @Test
    void sameConfiguredCheckerIsRejectedBeforeCreatingReviewFixtures() {
        ListDraftCasefilesStepDef invalid = steps(Map.of("RM_DRAFT_CASEFILE_CHECKER_USER",
            "OPAL-TEST@DEV.PLATFORM.HMCTS.NET"));
        assertThatThrownBy(invalid::prepareReview).isInstanceOf(AssertionError.class)
            .hasMessageContaining("Checker must differ");
        verify(actions, never()).create(anyString(), anyString());
    }

    @Test
    void sameBusinessUnitUserIdentityIsRejectedEvenForDistinctConfiguredUsers() {
        when(actions.create(eq(CHECKER), anyString())).thenAnswer(invocation -> response(201,
            submitted(102, JSON.readTree(invocation.getArgument(1, String.class)), OWNER), "\"0\""));
        assertThatThrownBy(steps::prepareReview).isInstanceOf(AssertionError.class)
            .hasMessageContaining("Business Unit User IDs must differ");
    }

    @Test
    void strictPublicationDeadlineFailsAndRetainsOwnershipForCleanup() {
        stayPending = true;
        assertThatThrownBy(steps::prepareFailed).isInstanceOf(AssertionError.class)
            .hasMessageContaining("publication deadline expired");
        when(scenario.isFailed()).thenReturn(true);
        steps.deleteCreatedDrafts(scenario);
        assertCleanup(1);
        assertThat(queries).isEmpty();
    }

    @Test
    void unexpectedPublicationOutcomeFailsAndRetainsOwnershipForCleanup() {
        changeTerminal = row -> row.put("casefile_status", "PUBLISHED");
        assertThatThrownBy(steps::prepareFailed).isInstanceOf(AssertionError.class)
            .hasMessageContaining("unexpected lifecycle state");
        when(scenario.isFailed()).thenReturn(true);
        steps.deleteCreatedDrafts(scenario);
        assertCleanup(1);
    }

    @Test
    void resetDiscardsPreviousCredentialsAndFixtures() {
        steps.prepareEmpty();
        steps.deleteCreatedDrafts(scenario);
        steps.resetScenario();
        steps.prepareEmpty();
        steps.list();
        steps.assertEmpty();
        steps.deleteCreatedDrafts(scenario);
        assertCleanup(2);
        assertThat(markers.values()).doesNotHaveDuplicates();
    }

    private void addSharedMatchingRow() {
        ObjectNode shared = rows.get(101L).deepCopy().put("draft_casefile_id", 999);
        rows.put(999L, shared);
    }

    private void assertCountQueries(String status) {
        Map<String, String> normal = Map.of("business_unit_id", "44", "submitted_by", "BU-OWNER",
            "casefile_status", status);
        Map<String, String> counts = new LinkedHashMap<>(normal);
        counts.put("restrict", "counts");
        assertThat(queries).containsExactly(normal, counts);
        assertThat(queryTokens).containsExactly(OWNER, OWNER);
    }

    private void assertApprovalAndPolling() {
        assertThat(decisions).containsExactly(JSON.createObjectNode().put("business_unit_id", 44)
            .put("casefile_status", "PUBLISHING_PENDING"));
        verify(actions).decide(eq(CHECKER), eq(101L), anyString(), eq("\"5\""));
        verify(actions, org.mockito.Mockito.atLeast(2)).get(OWNER, 101L);
    }

    private void assertCleanup(int count) {
        verify(actions, times(count)).delete(anyString(), anyLong(), anyString());
        for (Map.Entry<Long, String> owner : owners.entrySet()) {
            verify(actions).delete(owner.getValue(), owner.getKey(), markers.get(owner.getKey()));
        }
    }

    private String attachment() {
        ArgumentCaptor<String> evidence = ArgumentCaptor.forClass(String.class);
        verify(scenario).attach(evidence.capture(), eq("text/plain"), eq("PO-10619 cleanup failure"));
        return evidence.getValue();
    }

    private ListDraftCasefilesStepDef steps(Map<String, String> config) {
        long[] elapsed = {0};
        DraftCasefilePoller poller = new DraftCasefilePoller(Duration.ofSeconds(1), Duration.ofMillis(500),
            () -> elapsed[0], millis -> elapsed[0] += Duration.ofMillis(millis).toNanos());
        return new ListDraftCasefilesStepDef(actions, new DraftCasefileRequestFactory(), poller, config::get, user -> {
            resolvedUsers.add(user);
            return user.equals("opal-test-10@dev.platform.hmcts.net") || user.equals("checker-override")
                ? CHECKER : OWNER;
        });
    }

    private ObjectNode submitted(long id, JsonNode request, String token) {
        ObjectNode row = JSON.createObjectNode().put("draft_casefile_id", id).put("business_unit_id", 44)
            .put("casefile_type", "REMO In").put("casefile_status", "SUBMITTED")
            .put("casefile_status_name", "Submitted")
            .put("created_date", "2026-10-22T23:30:00-01:00").put("casefile_status_date", "2026-10-22T23:30:00-01:00")
            .put("submitted_by", CHECKER.equals(token) ? "BU-CHECKER" : "BU-OWNER")
            .put("submitted_by_name", CHECKER.equals(token) ? "Synthetic Checker" : "Synthetic Inputter");
        row.set("casefile", request.path("casefile"));
        ObjectNode snapshot = row.putObject("casefile_snapshot");
        account(snapshot.putObject("respondent_account"), "respondent_name", "RESPONDENT, Synthetic");
        account(snapshot.putObject("applicant_account"), "applicant_name", "APPLICANT, Synthetic");
        ArrayNode minors = snapshot.putArray("minor_creditor_accounts");
        account(minors.addObject().put("creditor_sequence", 7), "name", "MINORSEVEN, Synthetic");
        account(minors.addObject().put("creditor_sequence", 23), "name", "MINORTWENTYTHREE, Synthetic");
        row.putArray("timeline_data").addObject().put("status", "Submitted")
            .put("status_date", "2026-10-22T23:30:00-01:00").put("username", row.path("submitted_by_name").textValue());
        return row;
    }

    private void publish(ObjectNode row) {
        boolean failed = "not-an-amount".equals(row.at(
            "/casefile/respondent_account/order_details/order_terms/0/result_responses/0/response").textValue());
        row.put("casefile_status", failed ? "PUBLISHING_FAILED" : "PUBLISHED")
            .put("casefile_status_name", failed ? "Publishing failed" : "Published")
            .put("casefile_status_date", "2026-10-23T01:02:00Z");
        if (failed) {
            row.put("status_message", "Synthetic publication unsuccessful");
        } else {
            identity((ObjectNode) row.at("/casefile_snapshot/respondent_account"), 1, "R1");
            identity((ObjectNode) row.at("/casefile_snapshot/applicant_account"), 1, "C1");
            identity((ObjectNode) row.at("/casefile_snapshot/minor_creditor_accounts/0"), 2, "C2");
            identity((ObjectNode) row.at("/casefile_snapshot/minor_creditor_accounts/1"), 3, "C3");
        }
        changeTerminal.accept(row);
    }

    private static void account(ObjectNode node, String field, String name) {
        node.putNull("account_id").putNull("account_number").put(field, name);
    }

    private static void identity(ObjectNode node, long id, String number) {
        node.put("account_id", id).put("account_number", number);
    }

    private static ObjectNode summary(ObjectNode row) {
        ObjectNode summary = row.deepCopy();
        summary.remove(List.of("casefile", "timeline_data", "validated_by", "validated_by_name", "status_message"));
        return summary;
    }

    private static boolean matches(ObjectNode row, Map<String, String> query) {
        String submitter = row.path("submitted_by").textValue();
        return (!query.containsKey("submitted_by") || submitter.equals(query.get("submitted_by")))
            && (!query.containsKey("not_submitted_by") || !submitter.equals(query.get("not_submitted_by")))
            && (!query.containsKey("casefile_status")
                || List.of(query.get("casefile_status").split(",")).contains(row.path("casefile_status").textValue()));
    }

    private static Response response(int status, JsonNode body, String etag) {
        ResponseBuilder builder = new ResponseBuilder().setStatusCode(status).setContentType("application/json")
            .setBody(body.toString());
        if (etag != null) {
            builder.setHeader("ETag", etag);
        }
        return builder.build();
    }
}
