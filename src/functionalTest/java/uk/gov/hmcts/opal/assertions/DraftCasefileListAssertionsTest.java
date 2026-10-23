package uk.gov.hmcts.opal.assertions;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import io.restassured.builder.ResponseBuilder;
import io.restassured.response.Response;
import java.util.Map;
import java.util.Set;
import java.util.function.Consumer;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;

class DraftCasefileListAssertionsTest {
    private static final ObjectMapper JSON = new ObjectMapper();
    private static final Map<String, String> BU = Map.of("business_unit_id", "44");
    private static final String PRIVATE = "PRIVATE-FIXTURE-MARKER";

    @Test
    void emptyAndCountsOnlyResponsesAreValid() {
        assertDoesNotThrow(() -> DraftCasefileListAssertions.summaries(response("{\"count\":0,\"summaries\":[]}"), BU));
        assertDoesNotThrow(() -> DraftCasefileListAssertions.counts(response("{\"count\":0}"), 0));
        assertDoesNotThrow(() -> DraftCasefileListAssertions.counts(response("{\"count\":9223372036854775807}"),
            Long.MAX_VALUE));
    }

    @Test
    void filteredTerminalRowsPreserveCompleteMultiMinorSnapshots() {
        ObjectNode first = row(7);
        first.put("casefile_status", "PUBLISHED");
        first.put("casefile_status_name", "Published");
        first.put("validated_date", "2026-10-01T00:00:00Z");
        first.put("casefile_status_date", "2026-10-02T00:30:00+01:00");
        ObjectNode second = row(23);
        second.put("casefile_status", "PUBLISHING_FAILED");
        second.put("casefile_status_name", "Publishing failed");
        nullIdentities(second);
        second.put("validated_date", "2026-10-01T01:00:00Z");
        second.put("casefile_status_date", "2026-10-01T23:59:59.999999999Z");
        ObjectNode body = envelope(first, second);
        Map<String, String> filters = Map.of("business_unit_id", "44", "submitted_by", "synthetic-submitter",
            "not_submitted_by", "other-submitter", "casefile_status", "PUBLISHED,PUBLISHING_FAILED",
            "casefile_status_from_date", "2026-10-01", "casefile_status_to_date", "2026-10-01");

        JsonNode result = DraftCasefileListAssertions.summaries(response(body.toString()), filters);

        DraftCasefileListAssertions.contains(result, Set.of(7L, 23L), Set.of(8L, 24L));
        assertThat(DraftCasefileListAssertions.summary(result, 23).path("draft_casefile_id").longValue()).isEqualTo(23);
        DraftCasefileListAssertions.matchesDetail(first, detail(first));
        DraftCasefileListAssertions.matchesDetail(second, detail(second));
    }

    @Test
    void omittedDateFiltersDoNotInventAWindow() {
        ObjectNode row = row(Long.MAX_VALUE);
        row.put("casefile_status_date", "1990-01-01T00:00:00Z");
        assertDoesNotThrow(() -> DraftCasefileListAssertions.summaries(response(envelope(row).toString()), BU));
    }

    @Test
    void nullableOptionalValidationMayBeAbsentOrNull() {
        ObjectNode row = row(7);
        ObjectNode detail = detail(row);
        detail.putNull("validated_date");
        DraftCasefileListAssertions.matchesDetail(row, detail);
        row.putNull("validated_date");
        detail.remove("validated_date");
        DraftCasefileListAssertions.matchesDetail(row, detail);
        DraftCasefileListAssertions.summaries(response(envelope(row).toString()), BU);
    }

    @ParameterizedTest
    @ValueSource(strings = {"draft_casefile_id", "business_unit_id", "created_date", "submitted_by",
        "submitted_by_name", "casefile_snapshot", "casefile_type", "casefile_status", "casefile_status_name",
        "casefile_status_date"})
    void requiredSummaryFieldsCannotBeMissing(String field) {
        rejectRow(row -> row.remove(field));
    }

    @ParameterizedTest
    @ValueSource(strings = {"draft_casefile_id", "business_unit_id", "created_date", "submitted_by",
        "submitted_by_name", "casefile_snapshot", "casefile_type", "casefile_status", "casefile_status_name",
        "casefile_status_date"})
    void requiredSummaryFieldsCannotBeNull(String field) {
        rejectRow(row -> row.putNull(field));
    }

    @ParameterizedTest
    @ValueSource(strings = {"casefile", "timeline_data", "validated_by", "validated_by_name", "status_message",
        "account_id", "account_number", "unexpected", "personal_data"})
    void summariesRejectDetailAndUnknownFields(String field) {
        rejectRow(row -> row.put(field, PRIVATE));
    }

    @ParameterizedTest
    @ValueSource(strings = {"-1", "0", "1.5", "9223372036854775808", "\"7\""})
    void identifiersMustBePositiveIntegralLongs(String value) throws Exception {
        JsonNode invalid = JSON.readTree(value);
        rejectRow(row -> row.set("draft_casefile_id", invalid));
    }

    @ParameterizedTest
    @ValueSource(strings = {"-1", "1.5", "9223372036854775808", "\"1\"", "null"})
    void countsMustBeNonnegativeIntegralLongs(String value) {
        reject(() -> DraftCasefileListAssertions.summaries(response("{\"count\":" + value + ",\"summaries\":[]}"), BU));
        reject(() -> DraftCasefileListAssertions.counts(response("{\"count\":" + value + "}"), 1));
    }

    @ParameterizedTest
    @ValueSource(strings = {"{}", "{\"count\":0}", "{\"count\":0,\"summaries\":null}",
        "{\"count\":0,\"summaries\":{}}", "{\"count\":1,\"summaries\":[]}",
        "{\"count\":0,\"summaries\":[],\"personal_data\":\"PRIVATE-FIXTURE-MARKER\"}"})
    void listEnvelopeIsExact(String body) {
        reject(() -> DraftCasefileListAssertions.summaries(response(body), BU));
    }

    @ParameterizedTest
    @ValueSource(strings = {"{\"count\":0,\"summaries\":[]}",
        "{\"count\":0,\"personal_data\":\"PRIVATE-FIXTURE-MARKER\"}", "{}", "{\"count\":1}"})
    void countsEnvelopeRejectsOtherFieldsAndWrongResult(String body) {
        reject(() -> DraftCasefileListAssertions.counts(response(body), 0));
    }

    @Test
    void summaryIdsMustBeUniqueAndAscending() {
        reject(() -> DraftCasefileListAssertions.summaries(response(envelope(row(7), row(7)).toString()), BU));
        reject(() -> DraftCasefileListAssertions.summaries(response(envelope(row(23), row(7)).toString()), BU));
    }

    @Test
    void businessUnitsAreRequiredBoundedNumericAndFiltered() {
        rejectRow(row -> row.put("business_unit_id", 45));
        rejectRow(row -> row.put("business_unit_id", 32768));
        rejectRow(row -> row.put("business_unit_id", "44"));
        rejectRow(row -> row.put("business_unit_id", 44.5));
        reject(() -> DraftCasefileListAssertions.summaries(response(envelope(row(7)).toString()), Map.of()));
    }

    @Test
    void submitterAndLifecycleFiltersAreEnforced() {
        rejectFilter(Map.of("business_unit_id", "44", "submitted_by", "other-submitter"));
        rejectFilter(Map.of("business_unit_id", "44", "not_submitted_by", "synthetic-submitter"));
        rejectFilter(Map.of("business_unit_id", "44", "casefile_status", "REJECTED,RESUBMITTED"));
        rejectFilter(Map.of("business_unit_id", "44", "casefile_status", "UNKNOWN"));
        rejectRow(row -> row.put("casefile_status", PRIVATE));
        rejectRow(row -> row.put("casefile_type", PRIVATE));
    }

    @Test
    void utcDayBoundsUseStatusDateRatherThanCreatedOrLocalDay() {
        ObjectNode row = row(7);
        row.put("created_date", "1990-01-01T00:00:00Z");
        row.put("casefile_status_date", "2026-10-02T00:00:00+01:00");
        Map<String, String> filters = Map.of("business_unit_id", "44", "casefile_status_from_date", "2026-10-01",
            "casefile_status_to_date", "2026-10-01");
        DraftCasefileListAssertions.summaries(response(envelope(row).toString()), filters);
        row.put("casefile_status_date", "2026-10-01T00:59:59+01:00");
        reject(() -> DraftCasefileListAssertions.summaries(response(envelope(row).toString()), filters));
        row.put("casefile_status_date", "2026-10-02T00:00:00Z");
        reject(() -> DraftCasefileListAssertions.summaries(response(envelope(row).toString()), filters));
    }

    @ParameterizedTest
    @ValueSource(strings = {"created_date", "casefile_status_date", "validated_date"})
    void datesRequireParseableOffsets(String field) {
        rejectRow(row -> row.put(field, "2026-10-01T12:00:00"));
        rejectRow(row -> row.put(field, PRIVATE));
    }

    @ParameterizedTest
    @ValueSource(strings = {"submitted_by", "submitted_by_name", "casefile_status_name"})
    void displayAndSubmitterTextMustBeNonblank(String field) {
        rejectRow(row -> row.put(field, "  "));
        rejectRow(row -> row.put(field, 7));
    }

    @ParameterizedTest
    @ValueSource(strings = {"PUBLISHED", "PUBLISHING_FAILED"})
    void terminalRowsRequireNonNullValidation(String status) {
        rejectRow(row -> row.put("casefile_status", status));
        rejectRow(row -> {
            row.put("casefile_status", status);
            row.putNull("validated_date");
        });
    }

    @Test
    void everyOwnedPositiveAndNegativeIsChecked() {
        ObjectNode body = envelope(row(7), row(23));
        reject(() -> DraftCasefileListAssertions.contains(body, Set.of(7L, 24L), Set.of(30L)));
        reject(() -> DraftCasefileListAssertions.contains(body, Set.of(7L), Set.of(23L, 30L)));
    }

    @Test
    void summarySelectionRequiresExactlyOneMatch() {
        reject(() -> DraftCasefileListAssertions.summary(envelope(row(7)), 23));
        reject(() -> DraftCasefileListAssertions.summary(envelope(row(7), row(7)), 7));
    }

    @ParameterizedTest
    @ValueSource(strings = {"draft_casefile_id", "business_unit_id", "created_date", "submitted_by",
        "submitted_by_name", "casefile_type", "casefile_status", "casefile_status_name", "casefile_status_date"})
    void detailMustMatchEverySharedField(String field) {
        ObjectNode summary = row(7);
        ObjectNode detail = detail(summary);
        detail.put(field, PRIVATE);
        reject(() -> DraftCasefileListAssertions.matchesDetail(summary, detail));
        detail.remove(field);
        reject(() -> DraftCasefileListAssertions.matchesDetail(summary, detail));
    }

    @Test
    void detailMustMatchEntireSnapshotAndValidationDate() {
        ObjectNode summary = row(7);
        summary.put("casefile_status", "PUBLISHED");
        summary.put("validated_date", "2026-10-01T01:00:00Z");
        ObjectNode detail = detail(summary);
        ((ObjectNode) detail.at("/casefile_snapshot/respondent_account")).put("account_id", 999);
        reject(() -> DraftCasefileListAssertions.matchesDetail(summary, detail));
        detail.set("casefile_snapshot", summary.path("casefile_snapshot").deepCopy());
        ((ObjectNode) detail.at("/casefile_snapshot/minor_creditor_accounts/1")).put("creditor_sequence", 24);
        reject(() -> DraftCasefileListAssertions.matchesDetail(summary, detail));
        detail.set("casefile_snapshot", summary.path("casefile_snapshot").deepCopy());
        detail.put("validated_date", "2026-10-01T02:00:00Z");
        reject(() -> DraftCasefileListAssertions.matchesDetail(summary, detail));
        detail.remove("validated_date");
        reject(() -> DraftCasefileListAssertions.matchesDetail(summary, detail));
    }

    @ParameterizedTest
    @ValueSource(strings = {"", "null", "[]", "PRIVATE-FIXTURE-MARKER", "{\"count\":0} {}",
        "{\"count\":0} PRIVATE-FIXTURE-MARKER", "{\"count\":0,\"summaries\":[]} {}"})
    void invalidOrTrailingJsonFailsSafely(String body) {
        reject(() -> DraftCasefileListAssertions.counts(response(body), 0));
        reject(() -> DraftCasefileListAssertions.summaries(response(body), BU));
    }

    @Test
    void responseStatusMediaTypeAndCollectionEtagAreEnforced() {
        ResponseBuilder builder = new ResponseBuilder().setBody(envelope(row(7)).toString());
        reject(() -> DraftCasefileListAssertions.summaries(builder.setStatusCode(201)
            .setContentType("application/json").build(), BU));
        reject(() -> DraftCasefileListAssertions.summaries(builder.setStatusCode(200)
            .setContentType("application/json-private").build(), BU));
        reject(() -> DraftCasefileListAssertions.summaries(builder.setContentType("application/json")
            .setHeader("ETag", "\"1\"").build(), BU));
        reject(() -> DraftCasefileListAssertions.counts(builder.setBody("{\"count\":0}").build(), 0));
    }

    private void rejectRow(Consumer<ObjectNode> mutation) {
        ObjectNode row = row(7);
        mutation.accept(row);
        reject(() -> DraftCasefileListAssertions.summaries(response(envelope(row).toString()), BU));
    }

    private void rejectFilter(Map<String, String> filters) {
        reject(() -> DraftCasefileListAssertions.summaries(response(envelope(row(7)).toString()), filters));
    }

    private void reject(Runnable assertion) {
        AssertionError error = assertThrows(AssertionError.class, assertion::run);
        assertThat(error.getMessage()).doesNotContain(PRIVATE, "synthetic-submitter", "SYNTHETIC, Respondent",
            "SYNTHETIC, Applicant", "synthetic-minor-seven", "synthetic-minor-twentythree");
        assertThat(error.getCause()).isNull();
    }

    private static Response response(String body) {
        return new ResponseBuilder().setStatusCode(200).setContentType("application/json; charset=UTF-8")
            .setBody(body).build();
    }

    private static ObjectNode envelope(ObjectNode... rows) {
        ObjectNode body = JSON.createObjectNode().put("count", rows.length);
        ArrayNode summaries = body.putArray("summaries");
        for (ObjectNode row : rows) {
            summaries.add(row);
        }
        return body;
    }

    private static ObjectNode detail(ObjectNode summary) {
        ObjectNode detail = summary.deepCopy();
        detail.putObject("casefile").put("private_content", PRIVATE);
        detail.putArray("timeline_data");
        detail.put("validated_by", "synthetic-checker");
        return detail;
    }

    private static void nullIdentities(ObjectNode row) {
        JsonNode snapshot = row.path("casefile_snapshot");
        ((ObjectNode) snapshot.path("respondent_account")).putNull("account_id").putNull("account_number");
        ((ObjectNode) snapshot.path("applicant_account")).putNull("account_id").putNull("account_number");
        for (JsonNode minor : snapshot.path("minor_creditor_accounts")) {
            ((ObjectNode) minor).putNull("account_id").putNull("account_number");
        }
    }

    private static ObjectNode row(long id) {
        ObjectNode row = JSON.createObjectNode().put("draft_casefile_id", id).put("business_unit_id", 44)
            .put("created_date", "2026-09-01T10:00:00Z").put("submitted_by", "synthetic-submitter")
            .put("submitted_by_name", "Synthetic Submitter").put("casefile_type", "REMO In")
            .put("casefile_status", "SUBMITTED").put("casefile_status_name", "Submitted")
            .put("casefile_status_date", "2026-10-01T12:00:00Z");
        ObjectNode snapshot = row.putObject("casefile_snapshot");
        snapshot.putObject("respondent_account").put("account_id", 701).put("account_number", "SYN701")
            .put("respondent_name", "SYNTHETIC, Respondent");
        snapshot.putObject("applicant_account").put("account_id", 702).put("account_number", "SYN702")
            .put("applicant_name", "SYNTHETIC, Applicant");
        ArrayNode minors = snapshot.putArray("minor_creditor_accounts");
        minors.addObject().put("creditor_sequence", 7).put("account_id", 703).put("account_number", "SYN703")
            .put("name", "synthetic-minor-seven");
        minors.addObject().put("creditor_sequence", 23).put("account_id", 704).put("account_number", "SYN704")
            .put("name", "synthetic-minor-twentythree");
        return row;
    }
}
