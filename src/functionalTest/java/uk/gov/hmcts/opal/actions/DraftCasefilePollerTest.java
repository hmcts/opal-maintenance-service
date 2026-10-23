package uk.gov.hmcts.opal.actions;

import io.restassured.builder.ResponseBuilder;
import io.restassured.response.Response;
import java.time.Duration;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class DraftCasefilePollerTest {
    private final AtomicLong clock = new AtomicLong();
    private final AtomicInteger reads = new AtomicInteger();
    private final DraftCasefilePoller poller = new DraftCasefilePoller(Duration.ofSeconds(1),
        Duration.ofMillis(500), clock::get, millis -> clock.addAndGet(millis * 1_000_000));

    @Test
    void pendingThenPublishedReadsOncePerIteration() {
        Response result = poller.await(() -> status(reads.incrementAndGet() == 1
            ? "PUBLISHING_PENDING" : "PUBLISHED"), "PUBLISHED");
        assertEquals("PUBLISHED", result.jsonPath().getString("casefile_status"));
        assertEquals(2, reads.get());
    }

    @Test
    void alreadyTerminalReadsOnce() {
        poller.await(() -> {
            reads.incrementAndGet();
            return status("PUBLISHING_FAILED");
        }, "PUBLISHING_FAILED");
        assertEquals(1, reads.get());
        assertEquals(0, clock.get());
    }

    @Test
    void terminalMismatchFailsImmediately() {
        assertThrows(AssertionError.class, () -> poller.await(() -> {
            reads.incrementAndGet();
            return status("PUBLISHING_FAILED");
        }, "PUBLISHED"));
        assertEquals(1, reads.get());
    }

    @Test
    void non200FailsImmediately() {
        assertThrows(AssertionError.class, () -> poller.await(
            () -> new ResponseBuilder().setStatusCode(403).setBody("private response").build(), "PUBLISHED"));
        assertEquals(0, clock.get());
    }

    @Test
    void missingUnknownAndMalformedStatusFailWithoutRetry() {
        for (String body : new String[] {"{}", "{\"casefile_status\":\"UNKNOWN\"}", "not-json"}) {
            assertThrows(AssertionError.class, () -> poller.await(() -> new ResponseBuilder()
                .setStatusCode(200).setContentType("application/json").setBody(body).build(), "PUBLISHED"));
        }
        assertEquals(0, clock.get());
    }

    @Test
    void pendingExpiresAtTheDeadline() {
        assertThrows(AssertionError.class, () -> poller.await(() -> {
            reads.incrementAndGet();
            return status("PUBLISHING_PENDING");
        }, "PUBLISHED"));
        assertEquals(2, reads.get());
        assertEquals(1_000_000_000, clock.get());
    }

    @Test
    void interruptionRestoresTheFlagAndHidesCauseText() {
        DraftCasefilePoller interrupted = new DraftCasefilePoller(Duration.ofSeconds(1),
            Duration.ofMillis(500), clock::get, millis -> {
                throw new InterruptedException("private token");
            });
        try {
            AssertionError failure = assertThrows(AssertionError.class,
                () -> interrupted.await(() -> status("PUBLISHING_PENDING"), "PUBLISHED"));
            assertTrue(Thread.currentThread().isInterrupted());
            assertFalse(failure.toString().contains("private token"));
            assertEquals(null, failure.getCause());
        } finally {
            Thread.interrupted();
        }
    }

    @Test
    void responseAfterDeadlineCannotBeAccepted() {
        assertThrows(AssertionError.class, () -> poller.await(() -> {
            clock.set(1_000_000_000);
            return status("PUBLISHED");
        }, "PUBLISHED"));
    }

    private Response status(String value) {
        return new ResponseBuilder().setStatusCode(200).setContentType("application/json")
            .setBody("{\"casefile_status\":\"" + value + "\"}").build();
    }
}
