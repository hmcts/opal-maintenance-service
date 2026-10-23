package uk.gov.hmcts.opal.steps;

import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.cucumber.java.After;
import io.cucumber.java.Before;
import io.cucumber.java.Scenario;
import io.cucumber.java.en.Given;
import io.cucumber.java.en.Then;
import io.cucumber.java.en.When;
import io.restassured.response.Response;
import java.io.IOException;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.function.Supplier;
import uk.gov.hmcts.opal.actions.DraftCasefileActions;
import uk.gov.hmcts.opal.actions.DraftCasefilePoller;
import uk.gov.hmcts.opal.assertions.DraftCasefileListAssertions;
import uk.gov.hmcts.opal.assertions.DraftCasefileRetrievalAssertions;
import uk.gov.hmcts.opal.data.DraftCasefileRequestFactory;

import static org.junit.jupiter.api.Assertions.assertTrue;

public class ListDraftCasefilesStepDef {
    private static final ObjectMapper JSON = new ObjectMapper()
        .enable(DeserializationFeature.FAIL_ON_TRAILING_TOKENS);
    private static final String INPUTTER = "opal-test@dev.platform.hmcts.net";
    private static final String CHECKER = "opal-test-10@dev.platform.hmcts.net";
    private static final String REASON = "Synthetic list journey rejection";
    private final DraftCasefileActions actions;
    private final DraftCasefileRequestFactory requests;
    private final DraftCasefilePoller poller;
    private final Function<String, String> config;
    private final Function<String, String> tokens;
    private final List<OwnedDraft> owned = new ArrayList<>();
    private final Map<String, String> filters = new LinkedHashMap<>();
    private OwnedDraft primary;
    private OwnedDraft self;
    private OwnedDraft rejected;
    private Response listed;
    private String listToken;

    public ListDraftCasefilesStepDef() {
        this(new DraftCasefileActions(), new DraftCasefileRequestFactory(), new DraftCasefilePoller(),
            System::getenv, user -> {
                new BearerTokenStepDef().useTestUser(user);
                return BearerTokenStepDef.getToken();
            });
    }

    ListDraftCasefilesStepDef(DraftCasefileActions actions, DraftCasefileRequestFactory requests,
                             DraftCasefilePoller poller, Function<String, String> config,
                             Function<String, String> tokens) {
        this.actions = actions;
        this.requests = requests;
        this.poller = poller;
        this.config = config;
        this.tokens = tokens;
    }

    @Before("@PO10619")
    public void resetScenario() {
        clear();
    }

    @Given("owned matching and nonmatching Draft Casefiles for list filters")
    public void prepareFilters() {
        prepareReview();
        rejected = create(inputter(), false);
        reject(rejected);
        filters.put("submitted_by", submitter(primary));
        String day = responseDay(primary.created.path("casefile_status_date"));
        filters.put("casefile_status_from_date", day);
        filters.put("casefile_status_to_date", day);
        listToken = primary.ownerToken;
    }

    @Given("an owned rejected Draft Casefile for list counts")
    public void prepareRejected() {
        primary = create(inputter(), false);
        reject(primary);
        ownFilters("REJECTED");
    }

    @Given("an independently owned failed publication for list verification")
    public void prepareFailed() {
        prepareTerminal(true);
    }

    @Given("owned submissions by the inputter and the reviewing checker")
    public void prepareReview() {
        distinctUsers(inputter(), checker());
        primary = create(inputter(), false);
        self = create(checker(), false);
        assertTrue(!submitter(primary).equals(submitter(self)), "Role Business Unit User IDs must differ");
        filters.put("business_unit_id", "44");
        filters.put("casefile_status", "SUBMITTED,RESUBMITTED");
        filters.put("not_submitted_by", submitter(self));
        listToken = self.ownerToken;
    }

    @Given("an owned submission for a contradictory authorised list filter")
    public void prepareEmpty() {
        primary = create(inputter(), false);
        ownFilters("SUBMITTED");
        filters.put("not_submitted_by", submitter(primary));
    }

    @Given("an independently owned published casefile with two minor creditors for list verification")
    public void preparePublished() {
        prepareTerminal(false);
    }

    private void prepareTerminal(boolean failed) {
        primary = create(inputter(), failed);
        approve(primary);
        Response terminal = poller.await(() -> actions.get(primary.ownerToken, primary.id),
            failed ? "PUBLISHING_FAILED" : "PUBLISHED");
        assertTerminal(terminal, failed);
        ownFilters(failed ? "PUBLISHING_FAILED" : "PUBLISHED");
    }

    @When("the role user lists Draft Casefiles with the scenario filters")
    public void list() {
        listed = call(() -> actions.list(listToken, Map.copyOf(filters)));
    }

    @Then("every list summary satisfies all filters and only the matching owned drafts appear")
    public void assertFiltered() {
        JsonNode body = DraftCasefileListAssertions.summaries(listed, filters);
        DraftCasefileListAssertions.contains(body, Set.of(primary.id), Set.of(self.id, rejected.id));
    }

    @Then("the checker sees the other user's reviewable draft and excludes their own")
    public void assertReview() {
        JsonNode body = DraftCasefileListAssertions.summaries(listed, filters);
        DraftCasefileListAssertions.contains(body, Set.of(primary.id), Set.of(self.id));
    }

    @Then("the matching owned draft is listed and counts restriction returns the same matching count only")
    public void assertCounts() {
        JsonNode body = DraftCasefileListAssertions.summaries(listed, filters);
        DraftCasefileListAssertions.contains(body, Set.of(primary.id), Set.of());
        Map<String, String> restricted = new LinkedHashMap<>(filters);
        restricted.put("restrict", "counts");
        Response counts = call(() -> actions.list(listToken, restricted));
        DraftCasefileListAssertions.counts(counts, body.path("count").longValue());
    }

    @Then("the authorised list has zero count and an empty summaries array")
    public void assertEmpty() {
        JsonNode body = DraftCasefileListAssertions.summaries(listed, filters);
        assertTrue(body.path("count").longValue() == 0 && body.path("summaries").isEmpty(),
            "Contradictory submitter filters must produce an empty list");
    }

    @Then("the published summary matches full retrieval identities validation and unchanged approval history")
    public void assertPublished() {
        assertPairedTerminal(false);
    }

    @Then("the failed summary matches full retrieval null identities validation and unchanged approval history")
    public void assertFailed() {
        assertPairedTerminal(true);
    }

    private void assertPairedTerminal(boolean failed) {
        JsonNode body = DraftCasefileListAssertions.summaries(listed, filters);
        DraftCasefileListAssertions.contains(body, Set.of(primary.id), Set.of());
        Response detail = call(() -> actions.get(primary.ownerToken, primary.id));
        assertTerminal(detail, failed);
        DraftCasefileListAssertions.matchesDetail(DraftCasefileListAssertions.summary(body, primary.id), read(detail));
    }

    private void assertTerminal(Response response, boolean failed) {
        check(() -> {
            if (failed) {
                DraftCasefileRetrievalAssertions.failed(response, primary.approved);
            } else {
                DraftCasefileRetrievalAssertions.published(response, primary.approved);
            }
        });
    }

    private OwnedDraft create(String user, boolean failed) {
        OwnedDraft draft = new OwnedDraft();
        draft.marker = "E2E-" + UUID.randomUUID().toString().replace("-", "").substring(0, 16);
        draft.ownerIdentity = user;
        draft.ownerToken = token(user);
        draft.request = failed ? requests.unpublishable(draft.marker) : requests.withMinorCreditors(draft.marker);
        owned.add(draft);
        // An interrupted POST may already have committed: retain marker ownership and never replay it.
        draft.unknownCreate = true;
        Response response = call(() -> actions.create(draft.ownerToken, draft.request));
        if (response.statusCode() != 201) {
            draft.unknownCreate = false;
            throw new AssertionError("Scenario Draft Casefile creation requires HTTP 201");
        }
        JsonNode body = parse(response);
        JsonNode id = body.path("draft_casefile_id");
        assertTrue(id.isIntegralNumber() && id.canConvertToLong() && id.longValue() > 0,
            "Created Draft Casefile requires a positive Long ID");
        draft.id = id.longValue();
        draft.unknownCreate = false;
        draft.created = body;
        assertTrue("SUBMITTED".equals(body.path("casefile_status").textValue()), "Creation must be SUBMITTED");
        assertTrue(body.path("business_unit_id").isIntegralNumber()
            && body.path("business_unit_id").intValue() == 44, "Created Business Unit must be 44");
        for (String field : new String[] {"created_date", "casefile_status_date", "submitted_by",
            "submitted_by_name", "casefile_type", "casefile_snapshot", "timeline_data"}) {
            assertTrue(body.hasNonNull(field), "Created baseline metadata must be present");
        }
        submitter(draft);
        responseDay(body.path("created_date"));
        assertTrue(response.contentType() != null && response.contentType().startsWith("application/json"),
            "Creation requires application/json");
        assertTrue("\"0\"".equals(response.header("ETag")), "Creation requires initial ETag");
        return draft;
    }

    private void approve(OwnedDraft draft) {
        Response beforeResponse = call(() -> actions.get(draft.ownerToken, draft.id));
        check(() -> DraftCasefileRetrievalAssertions.submitted(beforeResponse, draft.request, draft.created));
        final JsonNode before = read(beforeResponse);
        String checkerUser = checker();
        distinctUsers(draft.ownerIdentity, checkerUser);
        String checkerToken = token(checkerUser);
        String etag = beforeResponse.header("ETag");
        String decision = JSON.createObjectNode().put("business_unit_id", 44)
            .put("casefile_status", "PUBLISHING_PENDING").toString();
        Response response = call(() -> actions.decide(checkerToken, draft.id, decision, etag));
        draft.approved = read(response);
        assertVersionAdvanced(etag, response.header("ETag"));
        check(() -> DraftCasefileRetrievalAssertions.approved(response, before));
        assertTrue(!draft.approved.path("validated_by").equals(draft.approved.path("submitted_by")),
            "Checker Business Unit User ID must differ from the submitter");
    }

    private void reject(OwnedDraft draft) {
        distinctUsers(draft.ownerIdentity, checker());
        Response beforeResponse = call(() -> actions.get(draft.ownerToken, draft.id));
        final JsonNode before = read(beforeResponse);
        String checkerToken = token(checker());
        String etag = beforeResponse.header("ETag");
        String decision = JSON.createObjectNode().put("business_unit_id", 44).put("casefile_status", "REJECTED")
            .put("status_message", REASON).toString();
        Response response = call(() -> actions.decide(checkerToken, draft.id, decision, etag));
        JsonNode after = read(response);
        assertVersionAdvanced(etag, response.header("ETag"));
        assertTrue("REJECTED".equals(after.path("casefile_status").textValue())
            && REASON.equals(after.path("status_message").textValue()), "Rejection decision must be returned");
        // Rejection retains validation metadata; only approval assigns validated_by.
        for (String field : new String[] {"draft_casefile_id", "business_unit_id", "submitted_by", "submitted_by_name",
            "created_date", "casefile_type", "casefile", "casefile_snapshot", "validated_by", "validated_by_name",
            "validated_date"}) {
            assertTrue(before.path(field).equals(after.path(field)),
                "Rejection must retain stored identity and content");
        }
        JsonNode prior = before.path("timeline_data");
        JsonNode timeline = after.path("timeline_data");
        assertTrue(prior.isArray() && timeline.isArray() && timeline.size() == prior.size() + 1,
            "Rejection must append one decision event");
        for (int index = 0; index < prior.size(); index++) {
            assertTrue(prior.get(index).equals(timeline.get(index)), "Rejection must retain prior history");
        }
        JsonNode event = timeline.get(timeline.size() - 1);
        assertTrue("Rejected".equals(event.path("status").textValue())
            && event.path("username").isTextual() && !event.path("username").textValue().isBlank()
            && event.path("status_date").equals(after.path("casefile_status_date")),
            "Rejection history must contain the checker and decision timestamp");
    }

    private void ownFilters(String status) {
        filters.put("business_unit_id", "44");
        filters.put("submitted_by", submitter(primary));
        filters.put("casefile_status", status);
        listToken = primary.ownerToken;
    }

    @After("@PO10619")
    public void deleteCreatedDrafts(Scenario scenario) {
        try {
            List<String> failures = new ArrayList<>();
            for (OwnedDraft draft : owned) {
                if (draft.id == null) {
                    if (draft.unknownCreate) {
                        failures.add("Unknown owned create ID with marker " + draft.marker
                            + "; operator follow-up required");
                    }
                    continue;
                }
                String identity = "ID " + draft.id + " with marker " + draft.marker;
                try {
                    Response response = actions.delete(draft.ownerToken, draft.id, draft.marker);
                    if (response == null || response.statusCode() != 204) {
                        failures.add(identity + (response == null ? " with no response"
                            : " with status " + response.statusCode()));
                    }
                } catch (RuntimeException exception) {
                    failures.add(identity + " with a request error");
                }
            }
            if (!failures.isEmpty()) {
                String evidence = "PO-10619 retained Draft Casefiles: " + String.join("; ", failures);
                if (!scenario.isFailed()) {
                    throw new AssertionError(evidence);
                }
                try {
                    scenario.attach(evidence, "text/plain", "PO-10619 cleanup failure");
                } catch (RuntimeException exception) {
                    throw new AssertionError(evidence + "; cleanup evidence attachment failed");
                }
            }
        } finally {
            clear();
        }
    }

    private static void assertVersionAdvanced(String before, String after) {
        assertTrue(Long.parseLong(after.substring(1, after.length() - 1))
            > Long.parseLong(before.substring(1, before.length() - 1)), "Decision must advance the ETag");
    }

    private String inputter() {
        return configured("RM_DRAFT_CASEFILE_INPUTTER_USER", INPUTTER);
    }

    private String checker() {
        return configured("RM_DRAFT_CASEFILE_CHECKER_USER", CHECKER);
    }

    private String configured(String variable, String fallback) {
        String value = config.apply(variable);
        return value == null || value.isBlank() ? fallback : value;
    }

    private static void distinctUsers(String owner, String reviewer) {
        assertTrue(!owner.equalsIgnoreCase(reviewer), "Checker must differ from the inputter");
    }

    private static String submitter(OwnedDraft draft) {
        JsonNode value = draft.created.path("submitted_by");
        assertTrue(value.isTextual() && !value.textValue().isBlank(), "POST must identify the Business Unit User");
        return value.textValue();
    }

    private static String responseDay(JsonNode value) {
        try {
            return OffsetDateTime.parse(value.textValue()).withOffsetSameInstant(ZoneOffset.UTC)
                .toLocalDate().toString();
        } catch (DateTimeParseException | NullPointerException exception) {
            throw new AssertionError("Created date must be an offset date-time");
        }
    }

    private String token(String user) {
        try {
            String value = tokens.apply(user);
            assertTrue(value != null && !value.isBlank(), "Functional access token must be nonblank");
            return value;
        } catch (RuntimeException exception) {
            throw new AssertionError("Functional access token resolution failed");
        }
    }

    private static Response call(Supplier<Response> action) {
        try {
            Response response = action.get();
            assertTrue(response != null, "Draft Casefile request returned no response");
            return response;
        } catch (RuntimeException exception) {
            throw new AssertionError("Draft Casefile request failed");
        }
    }

    private static JsonNode parse(Response response) {
        try {
            JsonNode value = JSON.readTree(response.asString());
            assertTrue(value != null && value.isObject(), "Draft Casefile requires a JSON object");
            return value;
        } catch (IOException | RuntimeException exception) {
            throw new AssertionError("Draft Casefile requires valid JSON");
        }
    }

    private static JsonNode read(Response response) {
        try {
            return DraftCasefileRetrievalAssertions.read(response);
        } catch (IOException exception) {
            throw new AssertionError("Draft Casefile retrieval requires valid JSON");
        }
    }

    private static void check(JsonCheck assertion) {
        try {
            assertion.run();
        } catch (IOException exception) {
            throw new AssertionError("Draft Casefile assertions require valid JSON");
        }
    }

    private void clear() {
        for (OwnedDraft draft : owned) {
            draft.ownerToken = null;
            draft.ownerIdentity = null;
            draft.request = null;
            draft.created = null;
            draft.approved = null;
        }
        owned.clear();
        filters.clear();
        primary = null;
        self = null;
        rejected = null;
        listed = null;
        listToken = null;
    }

    @FunctionalInterface
    private interface JsonCheck {
        void run() throws IOException;
    }

    // Deliberately not a record: generated toString must never expose tokens or casefile content.
    private static final class OwnedDraft {
        private Long id;
        private String marker;
        private String ownerToken;
        private String ownerIdentity;
        private String request;
        private boolean unknownCreate;
        private JsonNode created;
        private JsonNode approved;
    }
}
