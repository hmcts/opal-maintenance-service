package uk.gov.hmcts.opal.assertions;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import io.restassured.response.Response;
import java.io.IOException;
import java.time.OffsetDateTime;
import java.time.format.DateTimeParseException;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertTrue;

public final class DraftCasefileRetrievalAssertions {
    private static final ObjectMapper JSON = new ObjectMapper();
    private static final String[] UNCHANGED = {"draft_casefile_id", "business_unit_id", "created_date",
        "submitted_by", "submitted_by_name", "casefile_type"};
    private static final String[] VALIDATION = {"validated_date", "validated_by", "validated_by_name"};
    private static final Set<String> PROBLEM_FIELDS = Set.of("type", "title", "detail", "status", "instance",
        "operation_id", "retriable", "reason");
    private static final String[] PRIVATE_VALUES = {"synthetic", "respondent", "applicant", "minorseven",
        "minortwentythree", "ap00001", "not-an-amount", "100.00", "25.00", "35.00", "stack", "exception"};

    private DraftCasefileRetrievalAssertions() {
    }

    public static JsonNode read(Response response) throws IOException {
        require(response != null && response.statusCode() == 200, "Retrieval requires HTTP 200");
        require(response.contentType() != null && response.contentType().startsWith("application/json"),
            "Retrieval requires application/json");
        String etag = response.getHeader("ETag");
        require(etag != null && etag.matches("\"[0-9]+\""), "ETag must be a strong quoted decimal version");
        try {
            Long.parseLong(etag.substring(1, etag.length() - 1));
        } catch (NumberFormatException exception) {
            throw new AssertionError("ETag must fit a nonnegative Long");
        }
        JsonNode body = parse(response.asString());
        require(body.isObject(), "Retrieval must be a JSON object");
        require(!body.has("account_id") && !body.has("account_number"), "Account identities belong in the snapshot");
        return body;
    }

    public static void submitted(Response response, String request, JsonNode created) throws IOException {
        JsonNode body = read(response);
        JsonNode requested = parse(request);
        unchanged(body, created);
        for (String field : new String[] {"business_unit_id", "casefile_type", "casefile"}) {
            same(body.path(field), requested.path(field), field + " must match the request");
        }
        for (String field : new String[] {"casefile_status_date", "casefile_snapshot", "timeline_data"}) {
            sameRequired(body, created, field);
        }
        positiveId(body.path("draft_casefile_id"));
        require(body.path("business_unit_id").isIntegralNumber(), "Business unit must be numeric");
        text(body.path("submitted_by"), "submitted_by");
        text(body.path("submitted_by_name"), "submitted_by_name");
        require("SUBMITTED".equals(body.path("casefile_status").textValue()), "Lifecycle must be SUBMITTED");
        sameDate(body.path("created_date"), body.path("casefile_status_date"), "Submission date must match creation");
        for (String field : VALIDATION) {
            require(!body.has(field) || body.path(field).isNull(),
                "Submitted validation metadata must be absent or null");
        }
        JsonNode timeline = body.path("timeline_data");
        require(timeline.isArray() && timeline.size() == 1, "Submission must have exactly one timeline event");
        event(timeline.get(0), "Submitted", body.path("created_date"), body.path("submitted_by_name"));
        nullIdentities(body.path("casefile_snapshot"), body.path("casefile"));
        snapshotNames(body.path("casefile_snapshot"), body.path("casefile"));
    }

    public static void approved(Response response, JsonNode beforeApproval) throws IOException {
        JsonNode body = read(response);
        unchanged(body, beforeApproval);
        sameRequired(body, beforeApproval, "casefile");
        require("PUBLISHING_PENDING".equals(body.path("casefile_status").textValue()),
            "Approval must be PUBLISHING_PENDING");
        validation(body);
        sameRequired(body, beforeApproval, "casefile_snapshot");
        nullIdentities(body.path("casefile_snapshot"), body.path("casefile"));
        JsonNode before = beforeApproval.path("timeline_data");
        JsonNode after = body.path("timeline_data");
        require(before.isArray() && after.isArray() && after.size() == before.size() + 1,
            "Approval must append exactly one timeline event");
        for (int index = 0; index < before.size(); index++) {
            same(after.get(index), before.get(index), "Approval must retain the timeline prefix");
        }
        event(after.get(after.size() - 1), "Approved", body.path("validated_date"), body.path("validated_by_name"));
        sameDate(body.path("casefile_status_date"), body.path("validated_date"),
            "Approval status date must match validation");
    }

    public static void published(Response response, JsonNode approved) throws IOException {
        JsonNode body = terminal(response, approved, "PUBLISHED");
        JsonNode snapshot = body.path("casefile_snapshot");
        snapshotShape(snapshot);
        JsonNode before = approved.path("casefile_snapshot");
        preserveDisplay(snapshot.path("respondent_account"), before.path("respondent_account"));
        identity(snapshot.path("respondent_account"));
        preserveDisplay(snapshot.path("applicant_account"), before.path("applicant_account"));
        Set<Long> creditorIds = new HashSet<>();
        Set<String> creditorNumbers = new HashSet<>();
        uniqueIdentity(snapshot.path("applicant_account"), creditorIds, creditorNumbers);
        Map<Integer, JsonNode> minors = minorAccounts(snapshot.path("minor_creditor_accounts"));
        Map<Integer, JsonNode> priorMinors = minorAccounts(before.path("minor_creditor_accounts"));
        sameSequences(minors, sourceMinors(body.path("casefile")));
        sameSequences(minors, priorMinors);
        minors.forEach((sequence, account) -> {
            preserveDisplay(account, priorMinors.get(sequence));
            uniqueIdentity(account, creditorIds, creditorNumbers);
        });
    }

    public static void failed(Response response, JsonNode approved) throws IOException {
        JsonNode body = terminal(response, approved, "PUBLISHING_FAILED");
        sameRequired(body, approved, "casefile_snapshot");
        nullIdentities(body.path("casefile_snapshot"), body.path("casefile"));
        text(body.path("status_message"), "status_message");
    }

    public static void safeProblem(Response response, int status, String marker) throws IOException {
        require(status == 403 || status == 404, "Only missing or denied retrieval problems are expected");
        require(response.statusCode() == status, "Problem HTTP status differs");
        require(response.contentType() != null && response.contentType().startsWith("application/problem+json"),
            "Problem requires application/problem+json");
        JsonNode body = parse(response.asString());
        require(body.isObject(), "Problem must be a JSON object");
        body.fieldNames().forEachRemaining(field -> require(PROBLEM_FIELDS.contains(field),
            "Problem contains an unexpected field"));
        require(body.path("status").isInt() && body.path("status").intValue() == status, "Problem status differs");
        require(body.path("retriable").isBoolean() && !body.path("retriable").booleanValue(),
            "Problem must not be retriable");
        String type = status == 403 ? "forbidden" : "entity-not-found";
        require(("https://hmcts.gov.uk/problems/" + type).equals(body.path("type").textValue()),
            "Problem type differs");
        require((status == 403 ? "Forbidden" : "Entity Not Found").equals(body.path("title").textValue()),
            "Problem title differs");
        require((status == 403 ? "You do not have permission to access this resource"
            : "The requested entity could not be found").equals(body.path("detail").textValue()),
            "Problem detail differs");
        text(body.path("operation_id"), "operation_id");
        require(("https://hmcts.gov.uk/problems/instance/" + body.path("operation_id").textValue())
            .equals(body.path("instance").textValue()), "Problem instance must correlate with operation_id");
        if (status == 404) {
            require("Draft Casefile not found".equals(body.path("reason").textValue()), "Problem reason differs");
        } else {
            require(!body.has("reason"), "Denied problem must not include an exception reason");
        }
        for (JsonNode value : body) {
            require(value.isValueNode(), "Problem must not contain nested payload data");
            if (value.isTextual()) {
                require(marker == null || marker.isEmpty() || !value.textValue().contains(marker),
                    "Problem exposes the scenario marker");
                // Fixed common title, detail and reason are validated above. Dynamic fields must carry no payload.
                if (!value.equals(body.path("reason"))) {
                    String safe = value.textValue().toLowerCase(Locale.ROOT);
                    for (String privateValue : PRIVATE_VALUES) {
                        require(!safe.contains(privateValue), "Problem exposes private or diagnostic data");
                    }
                }
            }
        }
    }

    private static JsonNode terminal(Response response, JsonNode approved, String status) throws IOException {
        JsonNode body = read(response);
        require(status.equals(body.path("casefile_status").textValue()), "Publication lifecycle differs");
        unchanged(body, approved);
        sameRequired(body, approved, "casefile");
        validation(body);
        for (String field : VALIDATION) {
            sameRequired(body, approved, field);
        }
        sameRequired(body, approved, "timeline_data");
        date(body.path("casefile_status_date"));
        return body;
    }

    private static void unchanged(JsonNode body, JsonNode before) {
        for (String field : UNCHANGED) {
            sameRequired(body, before, field);
        }
        date(body.path("created_date"));
    }

    private static void validation(JsonNode body) {
        date(body.path("validated_date"));
        text(body.path("validated_by"), "validated_by");
        text(body.path("validated_by_name"), "validated_by_name");
    }

    private static void event(JsonNode event, String status, JsonNode timestamp, JsonNode username) {
        require(event != null && event.isObject(), "Timeline event must be an object");
        require(status.equals(event.path("status").textValue()), "Timeline event status differs");
        same(event.path("username"), username, "Timeline username differs");
        sameDate(event.path("status_date"), timestamp, "Timeline timestamp differs");
    }

    private static void nullIdentities(JsonNode snapshot, JsonNode casefile) {
        snapshotShape(snapshot);
        nullIdentity(snapshot.path("respondent_account"));
        nullIdentity(snapshot.path("applicant_account"));
        Map<Integer, JsonNode> minors = minorAccounts(snapshot.path("minor_creditor_accounts"));
        sameSequences(minors, sourceMinors(casefile));
        minors.values().forEach(DraftCasefileRetrievalAssertions::nullIdentity);
    }

    private static void snapshotShape(JsonNode snapshot) {
        require(snapshot.isObject() && snapshot.size() == 3 && snapshot.has("respondent_account")
            && snapshot.has("applicant_account") && snapshot.has("minor_creditor_accounts"),
            "Snapshot must contain only the three account collections");
    }

    private static void nullIdentity(JsonNode account) {
        require(account.isObject() && account.has("account_id") && account.path("account_id").isNull()
            && account.has("account_number") && account.path("account_number").isNull(),
            "Unpublished account identities must be explicit null fields");
    }

    private static void snapshotNames(JsonNode snapshot, JsonNode casefile) {
        display(snapshot.path("respondent_account").path("respondent_name"),
            casefile.at("/respondent_account/respondent/party_details"));
        display(snapshot.path("applicant_account").path("applicant_name"), casefile.at("/applicant/party_details"));
        Map<Integer, JsonNode> sources = sourceMinors(casefile);
        minorAccounts(snapshot.path("minor_creditor_accounts")).forEach((sequence, account) ->
            display(account.path("name"), sources.get(sequence).path("party_details")));
    }

    private static void display(JsonNode name, JsonNode party) {
        text(name, "Snapshot display name");
        String expected;
        if (party.path("organisation").asBoolean()) {
            expected = party.at("/organisation_details/organisation_name").asText();
        } else {
            String surname = party.at("/individual_details/surname").asText().toUpperCase(Locale.ROOT);
            String forenames = party.at("/individual_details/forenames").asText();
            expected = forenames.isBlank() ? surname : surname + ", " + forenames;
        }
        require(expected.equals(name.textValue()), "Snapshot display name differs from submitted content");
    }

    private static Map<Integer, JsonNode> sourceMinors(JsonNode casefile) {
        JsonNode sources = casefile.path("minor_creditors");
        return sources.isMissingNode() ? Map.of() : minorAccounts(sources);
    }

    private static Map<Integer, JsonNode> minorAccounts(JsonNode accounts) {
        require(accounts.isArray(), "Minor creditor collection must be an array");
        Map<Integer, JsonNode> result = new HashMap<>();
        for (JsonNode account : accounts) {
            JsonNode sequence = account.path("creditor_sequence");
            require(account.isObject() && sequence.isIntegralNumber() && sequence.canConvertToInt()
                && sequence.intValue() > 0, "Minor creditor sequence must be a positive integer");
            require(result.put(sequence.intValue(), account) == null, "Minor creditor sequence must be unique");
        }
        return result;
    }

    private static void sameSequences(Map<Integer, JsonNode> actual, Map<Integer, JsonNode> expected) {
        require(actual.keySet().equals(expected.keySet()), "Minor creditor sequence set differs from source");
    }

    private static void preserveDisplay(JsonNode actual, JsonNode expected) {
        require(actual.isObject() && expected.isObject(), "Snapshot account is missing");
        ObjectNode actualDisplay = actual.deepCopy();
        ObjectNode expectedDisplay = expected.deepCopy();
        actualDisplay.remove(Set.of("account_id", "account_number"));
        expectedDisplay.remove(Set.of("account_id", "account_number"));
        same(actualDisplay, expectedDisplay, "Snapshot display values must survive publication");
    }

    private static void uniqueIdentity(JsonNode account, Set<Long> ids, Set<String> numbers) {
        identity(account);
        require(ids.add(account.path("account_id").longValue()), "Creditor account IDs must be distinct");
        require(numbers.add(account.path("account_number").textValue()), "Creditor account numbers must be distinct");
    }

    private static void identity(JsonNode account) {
        positiveId(account.path("account_id"));
        text(account.path("account_number"), "account_number");
    }

    private static void positiveId(JsonNode value) {
        require(value.isIntegralNumber() && value.canConvertToLong() && value.longValue() > 0,
            "Account or draft ID must be a positive Long");
    }

    private static JsonNode parse(String value) {
        try {
            JsonNode body = JSON.readTree(value);
            require(body != null, "JSON body is required");
            return body;
        } catch (IOException | RuntimeException exception) {
            throw new AssertionError("Valid JSON is required");
        }
    }

    private static void sameRequired(JsonNode actual, JsonNode expected, String field) {
        require(actual.has(field) && expected.has(field), field + " must be present");
        same(actual.path(field), expected.path(field), field + " must be retained");
    }

    private static void same(JsonNode actual, JsonNode expected, String message) {
        require(actual.equals(expected), message);
    }

    private static void text(JsonNode value, String field) {
        require(value.isTextual() && !value.textValue().isBlank(), field + " must be nonblank text");
    }

    private static OffsetDateTime date(JsonNode value) {
        text(value, "Date");
        try {
            return OffsetDateTime.parse(value.textValue());
        } catch (DateTimeParseException exception) {
            throw new AssertionError("Date must be a parseable offset date-time");
        }
    }

    private static void sameDate(JsonNode actual, JsonNode expected, String message) {
        require(date(actual).toInstant().equals(date(expected).toInstant()), message);
    }

    private static void require(boolean condition, String message) {
        assertTrue(condition, message);
    }
}
