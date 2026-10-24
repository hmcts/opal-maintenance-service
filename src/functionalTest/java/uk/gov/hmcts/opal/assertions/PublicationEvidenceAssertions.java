package uk.gov.hmcts.opal.assertions;

import static org.junit.jupiter.api.Assertions.assertTrue;

import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.restassured.response.Response;
import java.io.IOException;
import java.math.BigInteger;
import java.time.OffsetDateTime;
import java.time.format.DateTimeParseException;
import java.util.Set;
import java.util.UUID;

public final class PublicationEvidenceAssertions {
    private static final ObjectMapper JSON = new ObjectMapper()
        .enable(DeserializationFeature.FAIL_ON_TRAILING_TOKENS);
    private static final Set<String> FIELDS = Set.of("observation_id", "registered_at", "send_attempt_count",
        "acknowledged_send_count", "uncertain_send_count", "unfinished_send_count", "evidence_complete");

    private PublicationEvidenceAssertions() {
    }

    public static JsonNode registered(Response response) {
        JsonNode body = read(response, 201);
        expectedCounts(body, 0);
        return body;
    }

    public static void acknowledged(Response response, JsonNode registration) {
        observed(response, registration, 1);
    }

    public static void noSend(Response response, JsonNode registration) {
        observed(response, registration, 0);
    }

    private static void observed(Response response, JsonNode registration, long count) {
        validate(registration);
        expectedCounts(registration, 0);
        JsonNode body = read(response, 200);
        require(body.path("observation_id").equals(registration.path("observation_id")),
            "Publication observation identity must be retained");
        require(date(body.path("registered_at")).toInstant()
            .equals(date(registration.path("registered_at")).toInstant()),
            "Publication registration timestamp must be retained");
        expectedCounts(body, count);
    }

    private static JsonNode read(Response response, int status) {
        require(response != null && response.statusCode() == status, "Publication evidence HTTP status differs");
        require(response.contentType() != null
            && "application/json".equalsIgnoreCase(response.contentType().split(";", 2)[0].trim()),
            "Publication evidence requires application/json");
        JsonNode body;
        try {
            body = JSON.readTree(response.asString());
        } catch (IOException | RuntimeException exception) {
            throw new AssertionError("Publication evidence requires valid JSON");
        }
        validate(body);
        return body;
    }

    private static void validate(JsonNode body) {
        require(body != null && body.isObject() && body.size() == FIELDS.size(),
            "Publication evidence must contain exactly the seven contract fields");
        body.fieldNames().forEachRemaining(field -> require(FIELDS.contains(field),
            "Publication evidence contains an unexpected field"));
        JsonNode id = body.path("observation_id");
        require(id.isTextual(), "Observation ID must be a canonical UUID");
        try {
            require(UUID.fromString(id.textValue()).toString().equals(id.textValue()),
                "Observation ID must be a canonical UUID");
        } catch (IllegalArgumentException exception) {
            throw new AssertionError("Observation ID must be a canonical UUID");
        }
        date(body.path("registered_at"));
        long attempts = count(body, "send_attempt_count");
        long acknowledged = count(body, "acknowledged_send_count");
        long uncertain = count(body, "uncertain_send_count");
        long unfinished = count(body, "unfinished_send_count");
        BigInteger total = BigInteger.valueOf(acknowledged).add(BigInteger.valueOf(uncertain))
            .add(BigInteger.valueOf(unfinished));
        require(total.equals(BigInteger.valueOf(attempts)), "Publication evidence counts must reconcile");
        JsonNode complete = body.path("evidence_complete");
        require(complete.isBoolean() && complete.booleanValue() == (uncertain == 0 && unfinished == 0),
            "Publication evidence completeness must match the attempt outcomes");
    }

    private static void expectedCounts(JsonNode body, long acknowledged) {
        require(count(body, "send_attempt_count") == acknowledged
            && count(body, "acknowledged_send_count") == acknowledged
            && count(body, "uncertain_send_count") == 0 && count(body, "unfinished_send_count") == 0
            && body.path("evidence_complete").booleanValue(), "Publication evidence outcome differs");
    }

    private static long count(JsonNode body, String field) {
        JsonNode count = body.path(field);
        require(count.isIntegralNumber() && count.canConvertToLong() && count.longValue() >= 0,
            "Publication evidence count must be a nonnegative Long");
        return count.longValue();
    }

    private static OffsetDateTime date(JsonNode value) {
        require(value.isTextual(), "Registration timestamp must be an offset date-time");
        try {
            return OffsetDateTime.parse(value.textValue());
        } catch (DateTimeParseException exception) {
            throw new AssertionError("Registration timestamp must be an offset date-time");
        }
    }

    private static void require(boolean condition, String message) {
        assertTrue(condition, message);
    }
}
