package uk.gov.hmcts.opal.service.messaging;

import io.micrometer.core.instrument.MeterRegistry;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import uk.gov.hmcts.opal.exception.DraftCasefilePublicationException;
import uk.gov.hmcts.opal.service.DraftCasefilePublicationFailureService;

@Service
@RequiredArgsConstructor
@Slf4j
public class DraftCasefileQueueConsumerService {
    private final DraftCasefileQueueMessageValidator messages;
    private final DraftCasefileQueueProcessingService processing;
    private final TransientFailureHelper transientFailures;
    private final DraftCasefilePublicationFailureService failures;
    private final MeterRegistry metrics;

    public void consume(String messagePayload) {
        final DraftCasefileQueueMessage message;
        try {
            message = messages.parse(messagePayload);
        } catch (IllegalArgumentException invalid) {
            record("invalid");
            throw new IllegalArgumentException("Invalid publication message");
        }
        try {
            var outcome = processing.processPendingDraft(message);
            record(outcome == DraftCasefileQueueProcessingService.Outcome.PUBLISHED ? "published" : "noop");
        } catch (DraftCasefilePublicationException failure) {
            handleProcessingFailure(failure);
        } catch (IllegalArgumentException invalidContext) {
            record("invalid");
            throw new IllegalArgumentException("Invalid publication message");
        } catch (RuntimeException unconfirmedOutcome) {
            // A commit failure without a captured attempt cannot safely justify a terminal write.
            throw retry();
        }
    }

    private void handleProcessingFailure(DraftCasefilePublicationException failure) {
        if (transientFailures.isTransientFailure(failure.processingFailure())) {
            throw retry();
        }
        final boolean recorded;
        try {
            recorded = failures.markFailed(failure.attempt(), "Publication failed; contact support");
        } catch (RuntimeException failureToRecord) {
            throw retry();
        }
        record(recorded ? "failed" : "noop");
    }

    private IllegalStateException retry() {
        record("retry");
        return new IllegalStateException("Publication delivery requires retry");
    }

    private void record(String outcome) {
        metrics.counter("opal.draft.casefile.publication", "outcome", outcome).increment();
        log.info("Draft Casefile publication outcome: {}", outcome);
    }
}
