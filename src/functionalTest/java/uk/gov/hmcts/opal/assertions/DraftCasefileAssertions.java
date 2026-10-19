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
    private static final Set<String> CREATED_FIELDS = Set.of(
        "draft_casefile_id", "business_unit_id", "created_date", "submitted_by", "submitted_by_name",
        "casefile_snapshot", "casefile_type", "casefile_status", "casefile_status_date", "timeline_data"
    );
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
        assertTrue(body.isObject(), "Created response must be a JSON object");
        assertEquals(CREATED_FIELDS, iterableFieldNames(body), "Created response fields differ from AddResponse");
        final long id = positiveId(body.path("draft_casefile_id"));
        assertTrue(body.path("business_unit_id").isIntegralNumber(), "Business unit must be numeric");
        assertEquals(44, body.path("business_unit_id").intValue());
        final OffsetDateTime createdDate = assertDate(body.path("created_date"));
        assertEquals("L044JG", body.path("submitted_by").asText());
        assertText(body.path("submitted_by_name"), "Submitter name");
        JsonNode snapshot = body.path("casefile_snapshot");
        assertTrue(snapshot.isObject(), "Casefile snapshot must be present");
        assertTrue(snapshot.path("respondent_account").isObject(), "Respondent snapshot must be present");
        assertTrue(snapshot.path("applicant_account").isObject(), "Applicant snapshot must be present");
        assertTrue(snapshot.path("minor_creditor_accounts").isArray(), "Minor creditor snapshots must be an array");
        assertEquals("RESPONDENT, Synthetic", snapshot.at("/respondent_account/respondent_name").asText());
        assertEquals("APPLICANT, Synthetic", snapshot.at("/applicant_account/applicant_name").asText());
        for (String account : new String[] {"respondent_account", "applicant_account"}) {
            assertTrue(snapshot.path(account).path("account_id").isNull(), "New account ID must be null");
            assertTrue(snapshot.path(account).path("account_number").isNull(), "New account number must be null");
        }
        assertTrue(snapshot.path("minor_creditor_accounts").isEmpty(), "No minor creditors were submitted");
        assertEquals("REMO In", body.path("casefile_type").asText());
        assertEquals("SUBMITTED", body.path("casefile_status").asText());
        assertEquals(createdDate, assertDate(body.path("casefile_status_date")));
        JsonNode timeline = body.path("timeline_data");
        assertTrue(timeline.isArray(), "Timeline must be an array");
        assertEquals(1, timeline.size(), "A new Draft Casefile must have one timeline entry");
        assertEquals("Submitted", timeline.get(0).path("status").asText());
        assertEquals(body.path("submitted_by_name").asText(), timeline.get(0).path("username").asText());
        assertEquals(createdDate, assertDate(timeline.get(0).path("status_date")));
        return id;
    }

    public static void assertTechnicalMetadata(Response response, Response createdResponse) throws IOException {
        final long createdId = assertCreated(createdResponse);
        final JsonNode created = OBJECT_MAPPER.readTree(createdResponse.asString());
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

        for (String field : new String[] {
            "draft_casefile_id", "business_unit_id", "submitted_by", "created_date", "casefile_status",
            "casefile_status_date"
        }) {
            assertEquals(created.path(field), body.path(field), "Metadata differs from created response: " + field);
        }
        assertEquals(Long.parseLong(createdResponse.getHeader("ETag").replace("\"", "")),
            body.path("version_number").longValue(), "Metadata version differs from created ETag");
        assertEquals(created.path("casefile_snapshot").isObject(), body.path("snapshot_present").booleanValue(),
            "Metadata snapshot fact differs from created response");
        JsonNode timeline = created.path("timeline_data");
        assertEquals(timeline.size(), body.path("timeline_entry_count").intValue(),
            "Metadata timeline count differs from created response");
        for (int index = 0; index < timeline.size(); index++) {
            assertEquals(timeline.get(index).path("status"), statuses.get(index),
                "Metadata timeline status differs from created response");
        }
    }

    public static void assertPermissionProblem(Response response, String marker) throws IOException {
        assertSafeProblem(response, 403, "forbidden", "Forbidden",
            "You do not have permission to access this resource", marker);
    }

    public static void assertReferenceProblem(Response response, String marker) throws IOException {
        assertSafeProblem(response, 400, "opal-api-error", "Bad Request",
            "An error occurred while processing your request", marker);
    }

    public static void assertFailureProblem(Response response, String marker) throws IOException {
        assertSafeProblem(response, 500, "internal-server-error", "Internal Server Error",
            "An unexpected error occurred while processing your request", marker);
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

    private static void assertSafeProblem(Response response, int status, String type, String title, String detail,
                                          String marker) throws IOException {
        JsonNode body = OBJECT_MAPPER.readTree(response.asString());
        assertProblemDetail(response, status, "https://hmcts.gov.uk/problems/" + type, title, detail,
            "instance", "operation_id");
        assertEquals("https://hmcts.gov.uk/problems/instance/" + body.path("operation_id").asText(),
            body.path("instance").asText(), "Problem instance must correlate with operation ID");
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

    private static OffsetDateTime assertDate(JsonNode node) {
        assertTrue(node.isTextual(), "Date must be text");
        try {
            return OffsetDateTime.parse(node.asText());
        } catch (DateTimeParseException exception) {
            throw new AssertionError("Date must contain an offset", exception);
        }
    }

    private static void assertText(JsonNode node, String name) {
        assertTrue(node.isTextual() && !node.asText().isBlank(), name + " must be non-blank text");
    }

    private static Set<String> iterableFieldNames(JsonNode body) {
        Set<String> names = new java.util.HashSet<>();
        body.fieldNames().forEachRemaining(names::add);
        return names;
    }
}
