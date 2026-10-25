package uk.gov.hmcts.opal.assertions;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import io.restassured.response.Response;

import java.io.IOException;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeParseException;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertTrue;

public final class DraftCasefilePublicationAssertions {
    private static final Set<String> CHANGED = Set.of("casefile_status", "casefile_status_name",
        "casefile_status_date", "casefile_snapshot", "status_message");
    private static final int[] CHECK_WEIGHTS = {5, 1, 4, 2, 7, 5, 1, 4};

    private DraftCasefilePublicationAssertions() {
    }

    public static JsonNode published(Response response, JsonNode approved, String approvalEtag) throws IOException {
        JsonNode body = terminal(response, approved, approvalEtag, "PUBLISHED", "Published");
        DraftCasefileRetrievalAssertions.published(response, approved);
        require(!body.hasNonNull("status_message"), "Published status message must be absent or null");
        numbers(body.path("casefile_snapshot"));
        return body;
    }

    public static JsonNode failed(Response response, JsonNode approved, String approvalEtag) throws IOException {
        JsonNode body = terminal(response, approved, approvalEtag, "PUBLISHING_FAILED", "Publishing failed");
        DraftCasefileRetrievalAssertions.failed(response, approved);
        // The maintained consumer exposes this generic message, never the underlying failure or submitted data.
        require("Publication failed; contact support".equals(body.path("status_message").textValue()),
            "Failed publication must return the supported safe status message");
        return body;
    }

    public static JsonNode stable(Response response, JsonNode terminal, String terminalEtag) throws IOException {
        final JsonNode body = read(response);
        require(terminal != null && terminal.isObject() && isTerminal(terminal),
            "Stable retrieval requires a terminal baseline");
        version(terminalEtag);
        require(terminalEtag.equals(response.getHeader("ETag")), "Terminal ETag must remain exactly unchanged");
        require(body.equals(terminal), "Terminal retrieval must retain the exact JSON body");
        return body;
    }

    private static JsonNode terminal(Response response, JsonNode approved, String approvalEtag,
                                     String status, String label) throws IOException {
        JsonNode body = read(response);
        require(approved != null && approved.isObject()
            && "PUBLISHING_PENDING".equals(approved.path("casefile_status").textValue())
            && "Publishing pending".equals(approved.path("casefile_status_name").textValue()),
            "Publication requires the complete approval baseline");
        require(status.equals(body.path("casefile_status").textValue())
            && label.equals(body.path("casefile_status_name").textValue()), "Publication lifecycle label differs");
        require(version(response.getHeader("ETag")) > version(approvalEtag),
            "Publication ETag must advance beyond approval");
        ObjectNode actual = body.deepCopy();
        ObjectNode expected = approved.deepCopy();
        actual.remove(CHANGED);
        expected.remove(CHANGED);
        require(actual.equals(expected), "Publication must retain every immutable field and its JSON presence");
        OffsetDateTime approvalDate = utc(approved.path("casefile_status_date"));
        require(!approvalDate.toInstant().isBefore(utc(approved.path("created_date")).toInstant()),
            "Approval lifecycle date must not precede creation");
        require(approvalDate.toInstant().equals(utc(approved.path("validated_date")).toInstant()),
            "Approval lifecycle date must match validation");
        require(!utc(body.path("casefile_status_date")).toInstant().isBefore(approvalDate.toInstant()),
            "Publication lifecycle date must not precede approval");
        snapshotNames(approved);
        nullIdentities(approved.path("casefile_snapshot"));
        snapshotNames(body);
        return body;
    }

    private static JsonNode read(Response response) throws IOException {
        JsonNode body = DraftCasefileRetrievalAssertions.read(response);
        require("application/json".equalsIgnoreCase(response.contentType().split(";", 2)[0].trim()),
            "Publication retrieval requires application/json");
        return body;
    }

    private static boolean isTerminal(JsonNode body) {
        String status = body.path("casefile_status").textValue();
        return "PUBLISHED".equals(status) || "PUBLISHING_FAILED".equals(status);
    }

    private static long version(String etag) {
        require(etag != null && etag.matches("\"[0-9]+\""), "ETag must be a strong quoted decimal version");
        try {
            return Long.parseLong(etag.substring(1, etag.length() - 1));
        } catch (NumberFormatException exception) {
            throw new AssertionError("ETag must fit a nonnegative Long");
        }
    }

    private static OffsetDateTime utc(JsonNode value) {
        require(value.isTextual(), "Lifecycle date must be a UTC offset date-time");
        try {
            OffsetDateTime date = OffsetDateTime.parse(value.textValue());
            require(ZoneOffset.UTC.equals(date.getOffset()), "Lifecycle date must use UTC");
            return date;
        } catch (DateTimeParseException exception) {
            throw new AssertionError("Lifecycle date must be a valid UTC offset date-time");
        }
    }

    private static void snapshotNames(JsonNode body) {
        JsonNode snapshot = body.path("casefile_snapshot");
        require(snapshot.isObject() && snapshot.size() == 3 && snapshot.has("respondent_account")
            && snapshot.has("applicant_account") && snapshot.has("minor_creditor_accounts"),
            "Snapshot must contain only its three account collections");
        JsonNode input = body.path("casefile");
        display(snapshot.path("respondent_account"), "respondent_name",
            input.at("/respondent_account/respondent/party_details"), false);
        display(snapshot.path("applicant_account"), "applicant_name", input.at("/applicant/party_details"), false);
        Map<Integer, JsonNode> sources = new HashMap<>();
        for (JsonNode minor : input.path("minor_creditors")) {
            JsonNode sequence = minor.path("creditor_sequence");
            require(sequence.isIntegralNumber() && sequence.canConvertToInt() && sequence.intValue() > 0,
                "Minor creditor sequence must be a positive integer");
            require(sources.put(sequence.intValue(), minor.path("party_details")) == null,
                "Minor creditor source sequence must be unique");
        }
        JsonNode accounts = snapshot.path("minor_creditor_accounts");
        require(accounts.isArray(), "Minor creditor accounts must be an array");
        for (JsonNode minor : accounts) {
            JsonNode party = sources.get(minor.path("creditor_sequence").intValue());
            require(party != null, "Minor creditor account must match a submitted sequence");
            display(minor, "name", party, true);
        }
    }

    private static void display(JsonNode account, String field, JsonNode party, boolean minor) {
        require(account.isObject() && account.size() == (minor ? 4 : 3)
            && account.has("account_id") && account.has("account_number") && account.has(field)
            && (!minor || account.has("creditor_sequence")), "Snapshot account must match its physical schema");
        String expected;
        if (party.path("organisation").asBoolean()) {
            expected = party.at("/organisation_details/organisation_name").asText();
        } else {
            String surname = party.at("/individual_details/surname").asText().toUpperCase(Locale.ROOT);
            String forenames = party.at("/individual_details/forenames").asText();
            expected = forenames.isBlank() ? surname : surname + ", " + forenames;
        }
        require(!expected.isBlank() && expected.equals(account.path(field).textValue()),
            "Snapshot display name must match the submitted party");
    }

    private static void nullIdentities(JsonNode snapshot) {
        nullIdentity(snapshot.path("respondent_account"));
        nullIdentity(snapshot.path("applicant_account"));
        snapshot.path("minor_creditor_accounts").forEach(DraftCasefilePublicationAssertions::nullIdentity);
    }

    private static void nullIdentity(JsonNode account) {
        require(account.path("account_id").isNull() && account.path("account_number").isNull(),
            "Approval snapshot identities must be explicit null fields");
    }

    private static void numbers(JsonNode snapshot) {
        Set<String> accountNumbers = new HashSet<>();
        number(snapshot.path("respondent_account"), accountNumbers);
        number(snapshot.path("applicant_account"), accountNumbers);
        snapshot.path("minor_creditor_accounts").forEach(account -> number(account, accountNumbers));
    }

    private static void number(JsonNode account, Set<String> accountNumbers) {
        JsonNode value = account.path("account_number");
        require(value.isTextual() && value.textValue().matches("[0-9]{8}[A-Z]"),
            "Published account number must contain eight digits and an uppercase check letter");
        String number = value.textValue();
        int total = 0;
        for (int index = 0; index < CHECK_WEIGHTS.length; index++) {
            total += (number.charAt(index) - '0') * CHECK_WEIGHTS[index];
        }
        // Independent arithmetic assertion of f_get_check_letter's modulo-23 complement.
        char expected = (char) ('A' + Math.floorMod(-total, 23));
        require(number.charAt(8) == expected, "Published account number check letter differs");
        require(accountNumbers.add(number), "Published account numbers must be distinct across all account types");
    }

    private static void require(boolean condition, String message) {
        assertTrue(condition, message);
    }
}
