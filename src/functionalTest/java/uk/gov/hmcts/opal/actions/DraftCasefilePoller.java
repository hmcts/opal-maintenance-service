package uk.gov.hmcts.opal.actions;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.restassured.response.Response;
import java.io.IOException;
import java.time.Duration;
import java.util.Set;
import java.util.function.LongSupplier;
import java.util.function.Supplier;

public final class DraftCasefilePoller {
    private static final ObjectMapper JSON = new ObjectMapper();
    private static final Set<String> KNOWN_STATUSES = Set.of("SUBMITTED", "RESUBMITTED", "REJECTED", "DELETED",
        "PUBLISHING_PENDING", "PUBLISHED", "PUBLISHING_FAILED");
    private final long timeoutNanos;
    private final long intervalMillis;
    private final LongSupplier clock;
    private final Sleeper sleeper;

    @FunctionalInterface
    public interface Sleeper {
        void sleep(long millis) throws InterruptedException;
    }

    public DraftCasefilePoller() {
        this(Duration.ofSeconds(60), Duration.ofMillis(500), System::nanoTime, Thread::sleep);
    }

    public DraftCasefilePoller(Duration timeout, Duration interval, LongSupplier clock, Sleeper sleeper) {
        if (timeout.isNegative() || timeout.isZero() || interval.toMillis() <= 0) {
            throw new IllegalArgumentException("Polling durations must be positive");
        }
        timeoutNanos = timeout.toNanos();
        intervalMillis = interval.toMillis();
        this.clock = clock;
        this.sleeper = sleeper;
    }

    public Response await(Supplier<Response> read, String expectedStatus) {
        if (!Set.of("PUBLISHED", "PUBLISHING_FAILED").contains(expectedStatus)) {
            throw new IllegalArgumentException("Expected status must be a publication outcome");
        }
        long started = clock.getAsLong();
        while (clock.getAsLong() - started < timeoutNanos) {
            Response response;
            try {
                response = read.get();
            } catch (RuntimeException exception) {
                throw new AssertionError("Draft Casefile polling request failed");
            }
            String status = status(response);
            if (clock.getAsLong() - started >= timeoutNanos) {
                break;
            }
            if (expectedStatus.equals(status)) {
                return response;
            }
            if (!"PUBLISHING_PENDING".equals(status)) {
                throw new AssertionError("Draft Casefile reached an unexpected lifecycle state");
            }
            long remaining = timeoutNanos - (clock.getAsLong() - started);
            if (remaining <= 0) {
                break;
            }
            try {
                sleeper.sleep(Math.min(intervalMillis, Math.max(1, Duration.ofNanos(remaining).toMillis())));
            } catch (InterruptedException exception) {
                Thread.currentThread().interrupt();
                throw new AssertionError("Draft Casefile polling was interrupted");
            }
        }
        throw new AssertionError("Draft Casefile publication deadline expired");
    }

    private static String status(Response response) {
        if (response == null || response.statusCode() != 200) {
            throw new AssertionError("Draft Casefile polling requires HTTP 200");
        }
        if (response.contentType() == null || !response.contentType().startsWith("application/json")) {
            throw new AssertionError("Draft Casefile polling requires application/json");
        }
        final JsonNode body;
        try {
            body = JSON.readTree(response.asString());
        } catch (IOException | RuntimeException exception) {
            throw new AssertionError("Draft Casefile polling requires valid JSON");
        }
        if (body == null || !body.isObject() || !body.path("casefile_status").isTextual()
            || !KNOWN_STATUSES.contains(body.path("casefile_status").textValue())) {
            throw new AssertionError("Draft Casefile polling requires a known lifecycle state");
        }
        return body.path("casefile_status").textValue();
    }
}
