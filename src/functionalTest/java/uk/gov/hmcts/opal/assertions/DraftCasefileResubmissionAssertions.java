package uk.gov.hmcts.opal.assertions;

import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import io.restassured.response.Response;
import java.io.IOException;
import java.time.OffsetDateTime;
import java.time.format.DateTimeParseException;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertTrue;

public final class DraftCasefileResubmissionAssertions {
    private static final ObjectMapper JSON = new ObjectMapper()
        .enable(DeserializationFeature.FAIL_ON_TRAILING_TOKENS);
    private static final Set<String> MUTABLE = Set.of("submitted_by", "submitted_by_name", "casefile",
        "casefile_snapshot", "casefile_status", "casefile_status_name", "casefile_status_date", "timeline_data");
    private static final String[] REQUIRED = {"draft_casefile_id", "business_unit_id", "created_date", "casefile_type",
        "status_message"};
    private static final Set<String> PROBLEM_FIELDS = Set.of("status", "type", "title", "detail", "retriable",
        "operation_id", "instance");

    private DraftCasefileResubmissionAssertions() {
    }

    public static JsonNode resubmitted(Response response, JsonNode before, String request,
                                       String resubmitterId, String resubmitterName) {
        JsonNode body = read(response);
        require(before != null && before.isObject(), "Rejected baseline must be a complete object");
        lifecycle(before, "REJECTED", "Rejected");
        lifecycle(body, "RESUBMITTED", "Resubmitted");
        stable(body, before);
        JsonNode requested = parse(request);
        require(requested.isObject() && requested.size() == 2 && requested.has("business_unit_id")
            && requested.path("casefile").isObject(), "Replacement must contain only Business Unit and full Casefile");
        require(requested.path("business_unit_id").equals(before.path("business_unit_id"))
            && requested.at("/casefile/respondent_account/business_unit_id").equals(before.path("business_unit_id")),
            "Replacement must retain the owning Business Unit");
        require(requested.at("/casefile/respondent_account/casefile_type").equals(before.path("casefile_type")),
            "Replacement must retain the Casefile type");
        require(body.path("casefile").equals(requested.path("casefile")),
            "Resubmission must retain the complete corrected Casefile");
        require(resubmitterId != null && !resubmitterId.isBlank()
            && resubmitterId.equals(body.path("submitted_by").textValue())
            && resubmitterName != null && !resubmitterName.isBlank()
            && resubmitterName.equals(body.path("submitted_by_name").textValue()),
            "Submitter must match the authenticated owning Business Unit user");
        snapshot(before.path("casefile_snapshot"), before.path("casefile"));
        snapshot(body.path("casefile_snapshot"), requested.path("casefile"));
        timeline(body, before, resubmitterName);
        return body;
    }

    public static void invalidContent(Response response, String marker) {
        require(response != null && response.statusCode() == 400, "Invalid content requires HTTP 400");
        require(response.getHeader("ETag") == null && response.getHeader("Location") == null,
            "Problem must not contain success headers");
        media(response, "application/problem+json");
        JsonNode body = parse(response.asString());
        require(body.isObject() && body.size() == PROBLEM_FIELDS.size(), "Invalid content problem fields differ");
        body.fieldNames().forEachRemaining(field -> require(PROBLEM_FIELDS.contains(field),
            "Invalid content problem has an unexpected field"));
        require(body.path("status").isInt() && body.path("status").intValue() == 400,
            "Invalid content problem status differs");
        require("https://hmcts.gov.uk/problems/opal-api-error".equals(body.path("type").textValue())
            && "Bad Request".equals(body.path("title").textValue())
            && "An error occurred while processing your request".equals(body.path("detail").textValue()),
            "Invalid content problem category differs");
        require(body.path("retriable").isBoolean() && !body.path("retriable").booleanValue(),
            "Invalid content problem must not be retriable");
        String operation = body.path("operation_id").textValue();
        require(operation != null && !operation.isBlank(), "Problem operation ID must be a nonblank string");
        require(("https://hmcts.gov.uk/problems/instance/" + operation).equals(body.path("instance").textValue()),
            "Problem instance must correlate with operation ID");
        for (JsonNode value : body) {
            require(value.isValueNode(), "Problem must contain only scalar fields");
            require(!value.isTextual() || marker == null || marker.isEmpty() || !value.textValue().contains(marker),
                "Problem must not expose the scenario marker");
        }
    }

    private static void stable(JsonNode body, JsonNode before) {
        for (String field : REQUIRED) {
            require(before.has(field) && body.has(field), "Stable Draft Casefile fields must be present");
        }
        require(before.path("draft_casefile_id").isIntegralNumber()
            && before.path("draft_casefile_id").canConvertToLong() && before.path("draft_casefile_id").longValue() > 0,
            "Draft identity must be a positive Long");
        require(before.path("business_unit_id").isIntegralNumber(), "Business Unit must be numeric");
        text(before.path("submitted_by"));
        text(before.path("submitted_by_name"));
        text(before.path("casefile_type"));
        text(before.path("status_message"));
        date(before.path("created_date"));
        ObjectNode expected = before.deepCopy();
        ObjectNode actual = body.deepCopy();
        expected.remove(MUTABLE);
        actual.remove(MUTABLE);
        require(actual.equals(expected), "Resubmission must retain all stable Draft Casefile metadata");
    }

    private static void lifecycle(JsonNode body, String status, String label) {
        require(status.equals(body.path("casefile_status").textValue())
            && label.equals(body.path("casefile_status_name").textValue()), "Draft lifecycle and display label differ");
    }

    private static void snapshot(JsonNode snapshot, JsonNode casefile) {
        require(casefile.isObject() && snapshot.isObject() && snapshot.size() == 3,
            "Casefile and complete account snapshot are required");
        account(snapshot.path("respondent_account"), "respondent_name",
            casefile.at("/respondent_account/respondent/party_details"), false);
        account(snapshot.path("applicant_account"), "applicant_name", casefile.at("/applicant/party_details"), false);
        Map<Integer, JsonNode> sources = minors(casefile.path("minor_creditors"));
        Map<Integer, JsonNode> accounts = minors(snapshot.path("minor_creditor_accounts"));
        require(sources.keySet().equals(Set.of(7, 23)) && accounts.keySet().equals(sources.keySet()),
            "Minor snapshots must match both non-positional source sequences");
        sources.forEach((sequence, source) ->
            account(accounts.get(sequence), "name", source.path("party_details"), true));
    }

    private static void account(JsonNode account, String nameField, JsonNode party, boolean minor) {
        require(account.isObject() && account.size() == (minor ? 4 : 3)
            && account.has("account_id") && account.path("account_id").isNull()
            && account.has("account_number") && account.path("account_number").isNull(),
            "Unpublished snapshot identities must be explicit null fields");
        require(party.isObject() && party.path("organisation").isBoolean(), "Snapshot source party is required");
        String expected;
        if (party.path("organisation").booleanValue()) {
            text(party.at("/organisation_details/organisation_name"));
            expected = party.at("/organisation_details/organisation_name").textValue();
        } else {
            text(party.at("/individual_details/surname"));
            String surname = party.at("/individual_details/surname").textValue().toUpperCase(Locale.ROOT);
            JsonNode forenames = party.at("/individual_details/forenames");
            require(forenames.isMissingNode() || forenames.isTextual(), "Person forenames must be text when present");
            expected = forenames.asText("").isBlank() ? surname : surname + ", " + forenames.textValue();
        }
        require(expected.equals(account.path(nameField).textValue()),
            "Snapshot display name must match corrected data");
    }

    private static Map<Integer, JsonNode> minors(JsonNode array) {
        require(array.isArray(), "Minor creditor collection must be an array");
        Map<Integer, JsonNode> result = new HashMap<>();
        for (JsonNode item : array) {
            JsonNode sequence = item.path("creditor_sequence");
            require(item.isObject() && sequence.isIntegralNumber() && sequence.canConvertToInt()
                && sequence.intValue() > 0, "Minor creditor sequence must be a positive integer");
            require(result.put(sequence.intValue(), item) == null, "Minor creditor sequence must be unique");
        }
        return result;
    }

    private static void timeline(JsonNode body, JsonNode before, String name) {
        JsonNode prior = before.path("timeline_data");
        JsonNode after = body.path("timeline_data");
        require(prior.isArray() && prior.size() >= 2 && after.isArray() && after.size() == prior.size() + 1,
            "Resubmission must append exactly one event to complete prior history");
        JsonNode rejected = prior.get(prior.size() - 1);
        require("Submitted".equals(prior.get(0).path("status").textValue())
            && "Rejected".equals(rejected.path("status").textValue())
            && before.path("status_message").equals(rejected.path("reason_text")),
            "Rejected baseline must contain submission and rejection history");
        require(date(prior.get(0).path("status_date")).toInstant()
            .equals(date(before.path("created_date")).toInstant())
            && date(rejected.path("status_date")).toInstant()
            .equals(date(before.path("casefile_status_date")).toInstant()),
            "Rejected history dates must match the draft state");
        OffsetDateTime timestamp = date(body.path("casefile_status_date"));
        require(!timestamp.toInstant().isBefore(date(before.path("created_date")).toInstant()),
            "Resubmission date must not precede creation");
        for (int index = 0; index < prior.size(); index++) {
            text(prior.get(index).path("username"));
            text(prior.get(index).path("status"));
            require(prior.get(index).equals(after.get(index)), "Resubmission must retain the exact timeline prefix");
            require(!timestamp.toInstant().isBefore(date(prior.get(index).path("status_date")).toInstant()),
                "Resubmission date must not precede prior history");
        }
        JsonNode event = after.get(prior.size());
        require(event.isObject() && event.size() == 3 && "Resubmitted".equals(event.path("status").textValue())
            && name.equals(event.path("username").textValue()) && !event.has("reason_text"),
            "Resubmission event must contain the authenticated actor and no reason");
        require(timestamp.toInstant().equals(date(event.path("status_date")).toInstant()),
            "Resubmission event date must match the status date");
    }

    private static JsonNode read(Response response) {
        require(response != null, "Resubmission response is required");
        media(response, "application/json");
        try {
            return DraftCasefileRetrievalAssertions.read(response);
        } catch (IOException exception) {
            throw new AssertionError("Resubmission requires valid JSON");
        }
    }

    private static void media(Response response, String expected) {
        require(response.contentType() != null
            && expected.equalsIgnoreCase(response.contentType().split(";", 2)[0].trim()),
            "Response media type differs");
    }

    private static JsonNode parse(String value) {
        try {
            JsonNode body = JSON.readTree(value);
            require(body != null, "JSON object is required");
            return body;
        } catch (IOException | RuntimeException exception) {
            throw new AssertionError("Valid JSON is required");
        }
    }

    private static OffsetDateTime date(JsonNode value) {
        text(value);
        try {
            return OffsetDateTime.parse(value.textValue());
        } catch (DateTimeParseException exception) {
            throw new AssertionError("Date must be an offset date-time");
        }
    }

    private static void text(JsonNode value) {
        require(value.isTextual() && !value.textValue().isBlank(), "Required text must be nonblank");
    }

    private static void require(boolean condition, String message) {
        assertTrue(condition, message);
    }
}
