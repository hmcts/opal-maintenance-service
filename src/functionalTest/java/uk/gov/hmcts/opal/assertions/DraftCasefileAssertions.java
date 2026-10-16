package uk.gov.hmcts.opal.assertions;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.restassured.response.Response;
import org.springframework.http.MediaType;

import java.io.IOException;
import java.time.OffsetDateTime;
import java.time.format.DateTimeParseException;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static uk.gov.hmcts.opal.assertions.ProblemDetailAssertions.assertProblemDetail;

public final class DraftCasefileAssertions {

    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();
    private static final Set<String> METADATA_FIELDS = Set.of(
        "draft_casefile_id", "business_unit_id", "submitted_by", "created_date", "casefile_status",
        "casefile_status_date", "version_number", "snapshot_present", "timeline_entry_count",
        "timeline_statuses"
    );
    private static final String[] PRIVATE_VALUES = {
        "Synthetic address", "Synthetic", "Respondent", "Applicant", "100.00", "AP00001", "ZZ99999"
    };

    private DraftCasefileAssertions() {
    }

    public static long assertCreated(Response response) throws IOException {
        assertEquals(201, response.statusCode());
        assertJson(response);
        assertEquals("\"0\"", response.getHeader("ETag"));
        assertNull(response.getHeader("Location"), "Created Draft Casefile must not include Location");

        JsonNode body = OBJECT_MAPPER.readTree(response.asString());
        assertTrue(body.isObject() && body.size() == 1, "Created response must contain only draft_casefile_id");
        long id = positiveId(body.path("draft_casefile_id"));
        return id;
    }

    public static void assertTechnicalMetadata(Response response, long createdId) throws IOException {
        assertEquals(200, response.statusCode());
        assertJson(response);
        JsonNode body = OBJECT_MAPPER.readTree(response.asString());
        assertTrue(body.isObject(), "Metadata must be a JSON object");
        assertEquals(METADATA_FIELDS, iterableFieldNames(body), "Metadata must contain only technical fields");
        assertEquals(createdId, positiveId(body.path("draft_casefile_id")));
        assertTrue(body.path("business_unit_id").isIntegralNumber(), "Business unit must be numeric");
        assertEquals(44, body.path("business_unit_id").intValue());
        assertEquals("L044JG", body.path("submitted_by").asText());
        assertDate(body.path("created_date"));
        assertEquals("SUBMITTED", body.path("casefile_status").asText());
        assertDate(body.path("casefile_status_date"));
        assertTrue(body.path("version_number").isIntegralNumber(), "Version must be numeric");
        assertEquals(0, body.path("version_number").longValue());
        assertTrue(body.path("snapshot_present").isBoolean() && body.path("snapshot_present").booleanValue(),
            "Snapshot must be present");
        assertTrue(body.path("timeline_entry_count").isIntegralNumber(), "Timeline count must be numeric");
        assertEquals(1, body.path("timeline_entry_count").intValue());
        JsonNode statuses = body.path("timeline_statuses");
        assertTrue(statuses.isArray(), "Timeline statuses must be an array");
        assertEquals(1, statuses.size());
        assertEquals("Submitted", statuses.get(0).asText());
    }

    public static void assertPermissionProblem(Response response, String marker) throws IOException {
        assertSafeProblem(response, 403, marker);
    }

    public static void assertReferenceProblem(Response response, String marker) throws IOException {
        assertSafeProblem(response, 400, marker);
    }

    public static void assertFailureProblem(Response response, String marker) throws IOException {
        assertSafeProblem(response, 500, marker);
    }

    public static void assertNoMarkerMatches(Response response) throws IOException {
        assertEquals(200, response.statusCode());
        assertJson(response);
        JsonNode body = OBJECT_MAPPER.readTree(response.asString());
        assertTrue(body.path("count").isIntegralNumber(), "Marker count must be numeric");
        assertEquals(0, body.path("count").intValue());
        JsonNode ids = body.path("draft_casefile_ids");
        assertTrue(ids.isArray(), "Marker IDs must be an array");
        assertTrue(ids.isEmpty(), "Marker lookup must contain no IDs");
    }

    public static void assertCleanup(Response response) {
        assertEquals(204, response.statusCode());
    }

    private static void assertSafeProblem(Response response, int status, String marker) throws IOException {
        JsonNode body = OBJECT_MAPPER.readTree(response.asString());
        for (String field : new String[] {"type", "title", "detail"}) {
            assertTrue(body.path(field).isTextual() && !body.path(field).asText().isBlank(),
                "Problem field is missing or blank: " + field);
        }
        assertProblemDetail(response, status, body.path("type").asText(), body.path("title").asText(),
            body.path("detail").asText(), "operation_id");
        String raw = response.asString();
        assertFalse(raw.contains(marker), "Problem must not expose the scenario marker");
        for (String value : PRIVATE_VALUES) {
            assertFalse(raw.contains(value), "Problem must not expose request payload values");
        }
        assertFalse(body.has("casefile") || body.has("casefile_snapshot") || body.has("timeline_data"),
            "Problem must not expose persisted payload fields");
    }

    private static void assertJson(Response response) {
        String contentType = response.contentType();
        assertTrue(contentType != null && contentType.startsWith(MediaType.APPLICATION_JSON_VALUE),
            "Expected application/json but received " + contentType);
    }

    private static long positiveId(JsonNode node) {
        assertTrue(node.isIntegralNumber() && node.canConvertToLong() && node.longValue() > 0,
            "Draft Casefile ID must be a positive integer");
        return node.longValue();
    }

    private static void assertDate(JsonNode node) {
        assertTrue(node.isTextual(), "Date must be text");
        try {
            OffsetDateTime.parse(node.asText());
        } catch (DateTimeParseException exception) {
            throw new AssertionError("Date must contain an offset", exception);
        }
    }

    private static Set<String> iterableFieldNames(JsonNode body) {
        Set<String> names = new java.util.HashSet<>();
        body.fieldNames().forEachRemaining(names::add);
        return names;
    }
}
