package uk.gov.hmcts.opal.assertions;

import static org.junit.jupiter.api.Assertions.assertTrue;

import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.restassured.response.Response;
import java.io.IOException;
import java.time.OffsetDateTime;
import java.time.format.DateTimeParseException;
import java.util.Set;
import java.util.UUID;

public final class DraftCasefileDecisionAssertions {
    private static final ObjectMapper JSON = new ObjectMapper()
        .enable(DeserializationFeature.FAIL_ON_TRAILING_TOKENS);
    private static final String[] IMMUTABLE = {"draft_casefile_id", "business_unit_id", "created_date", "submitted_by",
        "submitted_by_name", "casefile_type", "casefile", "casefile_snapshot"};
    private static final String[] VALIDATION = {"validated_by", "validated_by_name", "validated_date"};
    private static final Set<String> PROBLEM_FIELDS = Set.of("type", "title", "detail", "status", "retriable",
        "operation_id", "instance");

    private DraftCasefileDecisionAssertions() {
    }

    public static JsonNode decided(Response response, JsonNode before, String target, String reason,
                                   String checkerId, String checkerName) {
        JsonNode body = read(response);
        require(Set.of("PUBLISHING_PENDING", "REJECTED", "DELETED").contains(target),
            "Expected decision target must be supported");
        require(target.equals(body.path("casefile_status").textValue()), "Decision status differs");
        for (String field : IMMUTABLE) {
            require(body.has(field) && before.has(field) && body.path(field).equals(before.path(field)),
                "Decision must retain immutable draft data");
        }
        OffsetDateTime statusDate = date(body.path("casefile_status_date"));
        require(!statusDate.toInstant().isBefore(date(before.path("casefile_status_date")).toInstant())
            && !statusDate.toInstant().isBefore(date(body.path("created_date")).toInstant()),
            "Decision timestamp must not precede the previous draft state");
        if ("PUBLISHING_PENDING".equals(target)) {
            approve(response, before, body, checkerId, checkerName);
        } else {
            for (String field : VALIDATION) {
                require(body.path(field).equals(before.path(field)), "Decision must retain validation metadata");
            }
            require(reason != null && !reason.isBlank() && reason.equals(body.path("status_message").textValue()),
                "Decision must retain the exact reason");
            JsonNode timeline = body.path("timeline_data");
            JsonNode prior = before.path("timeline_data");
            require(prior.isArray() && timeline.isArray() && timeline.size() == prior.size() + 1,
                "Decision must append exactly one timeline event");
            for (int index = 0; index < prior.size(); index++) {
                require(timeline.get(index).equals(prior.get(index)), "Decision must retain the timeline prefix");
            }
            JsonNode event = timeline.get(timeline.size() - 1);
            require(event.isObject() && ("REJECTED".equals(target) ? "Rejected" : "Deleted")
                .equals(event.path("status").textValue()), "Decision timeline status differs");
            require(checkerName != null && !checkerName.isBlank()
                && checkerName.equals(event.path("username").textValue()), "Decision timeline actor differs");
            require(reason.equals(event.path("reason_text").textValue()), "Decision timeline reason differs");
            require(date(event.path("status_date")).toInstant().equals(statusDate.toInstant()),
                "Decision timeline date must match the status date");
        }
        return body;
    }

    public static void unchanged(Response response, JsonNode before, String etag) {
        require(read(response).equals(before), "Rejected operation must retain the entire draft body");
        require(etag != null && etag.equals(response.getHeader("ETag")), "Unchanged draft must retain its ETag");
    }

    public static void approvalPersisted(Response response, JsonNode approved, String approvalEtag) {
        JsonNode body = read(response);
        String status = body.path("casefile_status").textValue();
        require("PUBLISHING_PENDING".equals(approved.path("casefile_status").textValue()),
            "Approval baseline must be PUBLISHING_PENDING");
        if ("PUBLISHING_PENDING".equals(status)) {
            require(body.equals(approved), "Pending approval readback must retain the entire approved body");
            require(approvalEtag != null && approvalEtag.equals(response.getHeader("ETag")),
                "Pending approval must retain its ETag");
            return;
        }
        require("PUBLISHED".equals(status) || "PUBLISHING_FAILED".equals(status),
            "Approval readback lifecycle differs");
        require(version(response.getHeader("ETag")) > version(approvalEtag),
            "Terminal publication must advance the approval version");
        require(!date(body.path("casefile_status_date")).toInstant()
            .isBefore(date(approved.path("casefile_status_date")).toInstant()),
            "Publication timestamp must not precede approval");
        try {
            if ("PUBLISHED".equals(status)) {
                DraftCasefileRetrievalAssertions.published(response, approved);
            } else {
                DraftCasefileRetrievalAssertions.failed(response, approved);
            }
        } catch (IOException exception) {
            throw new AssertionError("Publication readback requires valid JSON");
        }
    }

    public static void safeProblem(Response response, int status, String kind, String marker) {
        require(response != null && response.statusCode() == status, "Problem HTTP status differs");
        require(response.getHeader("ETag") == null && response.getHeader("Location") == null,
            "Problem must not contain success headers");
        require(response.contentType() != null
            && "application/problem+json".equalsIgnoreCase(response.contentType().split(";", 2)[0].trim()),
            "Problem requires application/problem+json");
        require((status == 403 && "forbidden".equals(kind)) || (status == 409
            && ("optimistic-locking".equals(kind) || "resource-conflict".equals(kind))),
            "Expected problem category must be supported");
        JsonNode body = parse(response.asString());
        require(body.isObject() && body.size() == PROBLEM_FIELDS.size(), "Problem fields differ");
        body.fieldNames().forEachRemaining(field -> require(PROBLEM_FIELDS.contains(field),
            "Problem contains an unexpected field"));
        require(body.path("status").isInt() && body.path("status").intValue() == status, "Problem status differs");
        require(body.path("retriable").isBoolean() && !body.path("retriable").booleanValue(),
            "Problem must not be retriable");
        require(("https://hmcts.gov.uk/problems/" + kind).equals(body.path("type").textValue()),
            "Problem category differs");
        if (status == 403) {
            try {
                DraftCasefileRetrievalAssertions.safeProblem(response, status, marker);
            } catch (IOException exception) {
                throw new AssertionError("Problem requires valid JSON");
            }
        } else {
            require("Conflict".equals(body.path("title").textValue()), "Problem title differs");
            String detail = "optimistic-locking".equals(kind) ? "Conflict updating record. Please try again."
                : "A conflict occurred with the requested resource";
            require(detail.equals(body.path("detail").textValue()), "Problem detail differs");
        }
        String operation = body.path("operation_id").textValue();
        require(operation != null, "Problem operation ID must be a UUID");
        try {
            require(UUID.fromString(operation).toString().equals(operation), "Problem operation ID must be a UUID");
        } catch (IllegalArgumentException exception) {
            throw new AssertionError("Problem operation ID must be a UUID");
        }
        require(("https://hmcts.gov.uk/problems/instance/" + operation).equals(body.path("instance").textValue()),
            "Problem instance must correlate with operation ID");
        for (JsonNode value : body) {
            require(value.isValueNode(), "Problem must contain only scalar fields");
            require(!value.isTextual() || marker == null || marker.isEmpty() || !value.textValue().contains(marker),
                "Problem exposes the scenario marker");
        }
    }

    private static void approve(Response response, JsonNode before, JsonNode body,
                                String checkerId, String checkerName) {
        try {
            DraftCasefileRetrievalAssertions.approved(response, before);
        } catch (IOException exception) {
            throw new AssertionError("Approval requires valid JSON");
        }
        require(checkerId != null && !checkerId.isBlank() && checkerId.equals(body.path("validated_by").textValue())
            && checkerName != null && !checkerName.isBlank()
            && checkerName.equals(body.path("validated_by_name").textValue()),
            "Approval validation actor must match the authenticated checker");
        require(!body.hasNonNull("status_message"), "Approval must clear the status message");
        JsonNode timeline = body.path("timeline_data");
        require(!timeline.get(timeline.size() - 1).hasNonNull("reason_text"),
            "Approval timeline event must not contain a reason");
    }

    private static JsonNode read(Response response) {
        try {
            return DraftCasefileRetrievalAssertions.read(response);
        } catch (IOException exception) {
            throw new AssertionError("Draft read requires valid JSON");
        }
    }

    private static JsonNode parse(String value) {
        try {
            JsonNode body = JSON.readTree(value);
            require(body != null, "Problem body is required");
            return body;
        } catch (IOException | RuntimeException exception) {
            throw new AssertionError("Problem requires valid JSON");
        }
    }

    private static long version(String etag) {
        require(etag != null && etag.matches("\"[0-9]+\""), "ETag must be a strong quoted version");
        try {
            return Long.parseLong(etag.substring(1, etag.length() - 1));
        } catch (NumberFormatException exception) {
            throw new AssertionError("ETag must fit a nonnegative Long");
        }
    }

    private static OffsetDateTime date(JsonNode value) {
        require(value.isTextual(), "Decision date must be an offset date-time");
        try {
            return OffsetDateTime.parse(value.textValue());
        } catch (DateTimeParseException exception) {
            throw new AssertionError("Decision date must be an offset date-time");
        }
    }

    private static void require(boolean condition, String message) {
        assertTrue(condition, message);
    }
}
