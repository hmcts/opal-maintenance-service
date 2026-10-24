package uk.gov.hmcts.opal.assertions;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import io.restassured.builder.ResponseBuilder;
import io.restassured.response.Response;
import java.math.BigInteger;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

class PublicationEvidenceAssertionsTest {
    private static final ObjectMapper JSON = new ObjectMapper();
    private static final String PRIVATE = "private-evidence-marker";
    private static final String[] COUNTS = {"send_attempt_count", "acknowledged_send_count",
        "uncertain_send_count", "unfinished_send_count"};

    @Test
    void acceptsRegistrationAcknowledgementAndNoSendWithoutEtags() {
        ObjectNode registration = evidence();
        assertDoesNotThrow(() -> PublicationEvidenceAssertions.registered(response(201, registration)));
        assertDoesNotThrow(() -> PublicationEvidenceAssertions.noSend(response(200, registration), registration));
        ObjectNode sent = evidence().put("send_attempt_count", 1).put("acknowledged_send_count", 1);
        assertDoesNotThrow(() -> PublicationEvidenceAssertions.acknowledged(response(200, sent), registration));
    }

    @Test
    void rejectsWrongStatusAndContentType() {
        assertThrows(AssertionError.class, () -> PublicationEvidenceAssertions.registered(response(200, evidence())));
        Response wrongType = new ResponseBuilder().setStatusCode(201).setContentType("text/plain")
            .setBody(evidence().toString()).build();
        assertThrows(AssertionError.class, () -> PublicationEvidenceAssertions.registered(wrongType));
        assertThrows(AssertionError.class,
            () -> PublicationEvidenceAssertions.noSend(response(201, evidence()), evidence()));
    }

    @ParameterizedTest
    @ValueSource(strings = {"not-a-uuid", "1-1-1-1-1", "550E8400-E29B-41D4-A716-446655440000", ""})
    void rejectsNoncanonicalObservationId(String id) {
        rejects(evidence().put("observation_id", id));
    }

    @ParameterizedTest
    @ValueSource(strings = {"2026-10-23", "2026-10-23T10:00:00", "invalid", ""})
    void rejectsUnparseableRegistrationDate(String date) {
        rejects(evidence().put("registered_at", date));
    }

    @Test
    void rejectsChangedObservationIdentityOrRegistrationTime() {
        ObjectNode changed = evidence().put("observation_id", "650e8400-e29b-41d4-a716-446655440000");
        assertThrows(AssertionError.class,
            () -> PublicationEvidenceAssertions.noSend(response(200, changed), evidence()));
        ObjectNode wrongTime = evidence().put("registered_at", "2026-10-24T10:00:00Z");
        assertThrows(AssertionError.class,
            () -> PublicationEvidenceAssertions.noSend(response(200, wrongTime), evidence()));
    }

    @Test
    void rejectsNegativeFractionalTextAndOverflowCounts() {
        for (String field : COUNTS) {
            rejects(evidence().put(field, -1));
            rejects(evidence().put(field, 0.5));
            rejects(evidence().put(field, "0"));
            rejects(evidence().put(field, new BigInteger("9223372036854775808")));
        }
    }

    @Test
    void rejectsInconsistentTotalsAndOverflowedSum() {
        rejects(evidence().put("send_attempt_count", 1));
        rejects(evidence().put("send_attempt_count", Long.MAX_VALUE)
            .put("acknowledged_send_count", Long.MAX_VALUE).put("uncertain_send_count", Long.MAX_VALUE)
            .put("unfinished_send_count", 1).put("evidence_complete", false));
    }

    @Test
    void rejectsUncertainAndStartedAttemptsAndMultipleAcknowledgements() {
        for (String field : new String[] {"uncertain_send_count", "unfinished_send_count"}) {
            ObjectNode incomplete = evidence().put("send_attempt_count", 1).put(field, 1)
                .put("evidence_complete", false);
            assertThrows(AssertionError.class,
                () -> PublicationEvidenceAssertions.acknowledged(response(200, incomplete), evidence()));
            assertThrows(AssertionError.class,
                () -> PublicationEvidenceAssertions.noSend(response(200, incomplete), evidence()));
        }
        ObjectNode multiple = evidence().put("send_attempt_count", 2).put("acknowledged_send_count", 2);
        assertThrows(AssertionError.class,
            () -> PublicationEvidenceAssertions.acknowledged(response(200, multiple), evidence()));
        rejects(multiple);
    }

    @Test
    void rejectsIncompleteFlagExtraMissingAndWrongTypedFields() {
        rejects(evidence().put("evidence_complete", false));
        rejects(evidence().put("evidence_complete", "true"));
        rejects(evidence().put("extra", PRIVATE));
        for (String field : new String[] {"observation_id", "registered_at", "send_attempt_count",
            "acknowledged_send_count", "uncertain_send_count", "unfinished_send_count", "evidence_complete"}) {
            ObjectNode missing = evidence();
            missing.remove(field);
            rejects(missing);
        }
        ObjectNode nested = evidence();
        nested.putObject("observation_id").put("private", PRIVATE);
        rejects(nested);
    }

    @ParameterizedTest
    @ValueSource(strings = {"", "{", "[]", "null", "{} {}", "{} private-evidence-marker"})
    void rejectsEmptyMalformedAndTrailingJsonSafely(String body) {
        assertSafe(response(201, body));
    }

    @Test
    void failureContainsNoPrivateValueOrCause() {
        assertSafe(response(201, evidence().put("registered_at", PRIVATE)));
        assertSafe(response(201, "{\"private\":\"" + PRIVATE));
        assertSafe(response(201, evidence() + " {\"private\":\"" + PRIVATE + "\"}"));
    }

    private void assertSafe(Response response) {
        AssertionError failure = assertThrows(AssertionError.class,
            () -> PublicationEvidenceAssertions.registered(response));
        assertFalse(failure.toString().contains(PRIVATE));
        assertNull(failure.getCause());
    }

    private void rejects(ObjectNode body) {
        assertThrows(AssertionError.class, () -> PublicationEvidenceAssertions.registered(response(201, body)));
    }

    private ObjectNode evidence() {
        return JSON.createObjectNode().put("observation_id", "550e8400-e29b-41d4-a716-446655440000")
            .put("registered_at", "2026-10-23T10:00:00Z").put("send_attempt_count", 0)
            .put("acknowledged_send_count", 0).put("uncertain_send_count", 0)
            .put("unfinished_send_count", 0).put("evidence_complete", true);
    }

    private Response response(int status, Object body) {
        return new ResponseBuilder().setStatusCode(status).setContentType("application/json")
            .setBody(body.toString()).build();
    }
}
