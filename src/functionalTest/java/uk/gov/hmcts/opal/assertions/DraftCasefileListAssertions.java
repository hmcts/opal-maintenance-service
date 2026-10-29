package uk.gov.hmcts.opal.assertions;

import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.restassured.response.Response;
import java.io.IOException;
import java.time.Instant;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeParseException;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertTrue;

public final class DraftCasefileListAssertions {
    private static final ObjectMapper JSON = new ObjectMapper()
        .enable(DeserializationFeature.FAIL_ON_TRAILING_TOKENS);
    private static final Set<String> REQUIRED = Set.of("draft_casefile_id", "business_unit_id", "created_date",
        "submitted_by", "submitted_by_name", "casefile_snapshot", "casefile_type", "casefile_status",
        "casefile_status_name", "casefile_status_date");
    private static final Set<String> STATUSES = Set.of("SUBMITTED", "DELETED", "REJECTED", "PUBLISHING_PENDING",
        "PUBLISHED", "PUBLISHING_FAILED", "RESUBMITTED");
    private static final Set<String> TYPES = Set.of("REMO In", "REMO Out", "REMO Out (CMS)");

    private DraftCasefileListAssertions() {
    }

    public static JsonNode summaries(Response response, Map<String, String> filters) {
        JsonNode body = read(response);
        fields(body, Set.of("count", "summaries"), Set.of(), "List envelope must contain only count and summaries");
        JsonNode rows = body.path("summaries");
        require(rows.isArray(), "Summaries must be an array");
        require(nonnegativeLong(body.path("count")) == rows.size(), "Count must equal summary length");
        long businessUnit = businessUnitFilter(filters);
        long previous = 0;
        for (JsonNode row : rows) {
            validateRow(row);
            long id = positiveLong(row.path("draft_casefile_id"));
            require(id > previous, "Summary IDs must be unique and ascending");
            previous = id;
            require(row.path("business_unit_id").longValue() == businessUnit, "Summary Business Unit differs");
            applyFilters(row, filters);
        }
        return body;
    }

    public static void contains(JsonNode body, Set<Long> included, Set<Long> excluded) {
        Set<Long> actual = new HashSet<>();
        require(body != null && body.path("summaries").isArray(), "Summaries must be an array");
        for (JsonNode row : body.path("summaries")) {
            require(actual.add(positiveLong(row.path("draft_casefile_id"))), "Summary IDs must be unique");
        }
        require(included.stream().allMatch(id -> id != null && id > 0 && actual.contains(id)),
            "Every owned positive must be present");
        require(excluded.stream().allMatch(id -> id != null && id > 0 && !actual.contains(id)),
            "Every owned negative must be absent");
    }

    public static void counts(Response response, long expected) {
        JsonNode body = read(response);
        fields(body, Set.of("count"), Set.of(), "Counts response must contain only count");
        require(expected >= 0 && nonnegativeLong(body.path("count")) == expected, "Counts result differs");
    }

    public static JsonNode summary(JsonNode body, long id) {
        require(id > 0 && body != null && body.path("summaries").isArray(),
            "Summary selection requires an array and ID");
        JsonNode selected = null;
        int matches = 0;
        for (JsonNode row : body.path("summaries")) {
            if (positiveLong(row.path("draft_casefile_id")) == id) {
                selected = row;
                matches++;
            }
        }
        require(matches == 1, "Summary selection must match exactly one row");
        return selected;
    }

    public static void matchesDetail(JsonNode summary, JsonNode detail) {
        validateRow(summary);
        require(detail != null && detail.isObject(), "Detail must be an object");
        for (String field : REQUIRED) {
            require(detail.has(field) && summary.path(field).equals(detail.path(field)),
                "Shared summary and detail field differs");
        }
        JsonNode validation = summary.path("validated_date");
        JsonNode detailValidation = detail.path("validated_date");
        require((validation.isMissingNode() || validation.isNull())
                ? detailValidation.isMissingNode() || detailValidation.isNull() : validation.equals(detailValidation),
            "Summary and detail validation date differs");
    }

    private static void validateRow(JsonNode row) {
        fields(row, REQUIRED, Set.of("validated_date"), "Summary contains missing or unexpected fields");
        positiveLong(row.path("draft_casefile_id"));
        long unit = positiveLong(row.path("business_unit_id"));
        require(unit <= Short.MAX_VALUE, "Business Unit must fit a positive Short");
        text(row.path("submitted_by"));
        text(row.path("submitted_by_name"));
        text(row.path("casefile_status_name"));
        require(row.path("casefile_type").isTextual() && TYPES.contains(row.path("casefile_type").textValue()),
            "Casefile type must be known");
        String status = row.path("casefile_status").textValue();
        require(status != null && STATUSES.contains(status), "Casefile lifecycle must be known");
        date(row.path("created_date"));
        date(row.path("casefile_status_date"));
        require(row.path("casefile_snapshot").isObject(), "Casefile snapshot must be an object");
        JsonNode validation = row.path("validated_date");
        if ("PUBLISHED".equals(status) || "PUBLISHING_FAILED".equals(status)
            || !validation.isMissingNode() && !validation.isNull()) {
            date(validation);
        }
    }

    private static void applyFilters(JsonNode row, Map<String, String> filters) {
        String submitter = row.path("submitted_by").textValue();
        require(!filters.containsKey("submitted_by") || submitter.equals(filters.get("submitted_by")),
            "Summary submitter differs from inclusion filter");
        require(!filters.containsKey("not_submitted_by") || !submitter.equals(filters.get("not_submitted_by")),
            "Summary submitter violates exclusion filter");
        if (filters.containsKey("casefile_status")) {
            Set<String> statuses = new HashSet<>(Arrays.asList(filters.get("casefile_status").split(",", -1)));
            require(STATUSES.containsAll(statuses), "Lifecycle filter must contain known statuses");
            require(statuses.contains(row.path("casefile_status").textValue()), "Summary lifecycle violates filter");
        }
        Instant statusDate = date(row.path("casefile_status_date")).toInstant();
        if (filters.containsKey("casefile_status_from_date")) {
            require(!statusDate.isBefore(day(filters.get("casefile_status_from_date"))),
                "Summary status date precedes inclusive UTC lower bound");
        }
        if (filters.containsKey("casefile_status_to_date")) {
            Instant exclusiveEnd = day(filters.get("casefile_status_to_date")).plusSeconds(86400);
            require(statusDate.isBefore(exclusiveEnd), "Summary status date exceeds inclusive UTC upper bound");
        }
    }

    private static long businessUnitFilter(Map<String, String> filters) {
        try {
            long unit = Long.parseLong(filters.get("business_unit_id"));
            require(unit > 0 && unit <= Short.MAX_VALUE, "Business Unit filter must be a positive Short");
            return unit;
        } catch (RuntimeException exception) {
            throw new AssertionError("Business Unit filter must be a positive Short");
        }
    }

    private static Instant day(String value) {
        try {
            return LocalDate.parse(value).atStartOfDay().toInstant(ZoneOffset.UTC);
        } catch (DateTimeParseException exception) {
            throw new AssertionError("Date filter must be an ISO date");
        }
    }

    private static JsonNode read(Response response) {
        require(response != null && response.statusCode() == 200, "Collection requires HTTP 200");
        String contentType = response.contentType();
        require(contentType != null && "application/json".equalsIgnoreCase(contentType.split(";", 2)[0].trim()),
            "Collection requires application/json");
        require(response.getHeader("ETag") == null, "Collection must not contain an ETag");
        try {
            JsonNode body = JSON.readTree(response.asString());
            require(body != null && body.isObject(), "Collection must be a JSON object");
            return body;
        } catch (IOException | RuntimeException exception) {
            throw new AssertionError("Collection requires valid JSON without trailing content");
        }
    }

    private static void fields(JsonNode node, Set<String> required, Set<String> optional, String message) {
        require(node != null && node.isObject(), message);
        required.forEach(field -> require(node.has(field), message));
        node.fieldNames().forEachRemaining(field ->
            require(required.contains(field) || optional.contains(field), message));
    }

    private static long nonnegativeLong(JsonNode value) {
        require(value.isIntegralNumber() && value.canConvertToLong() && value.longValue() >= 0,
            "Count must be a nonnegative integral Long");
        return value.longValue();
    }

    private static long positiveLong(JsonNode value) {
        require(value.isIntegralNumber() && value.canConvertToLong() && value.longValue() > 0,
            "ID must be a positive integral Long");
        return value.longValue();
    }

    private static void text(JsonNode value) {
        require(value.isTextual() && !value.textValue().isBlank(), "Summary text must be nonblank");
    }

    private static OffsetDateTime date(JsonNode value) {
        text(value);
        try {
            return OffsetDateTime.parse(value.textValue());
        } catch (DateTimeParseException exception) {
            throw new AssertionError("Summary date must be an offset date-time");
        }
    }

    private static void require(boolean condition, String message) {
        assertTrue(condition, message);
    }
}
