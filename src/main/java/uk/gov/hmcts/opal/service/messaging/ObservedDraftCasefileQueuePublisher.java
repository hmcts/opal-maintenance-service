package uk.gov.hmcts.opal.service.messaging;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Primary;
import org.springframework.stereotype.Component;

import java.util.Optional;
import java.util.UUID;

@Component
@Primary
@RequiredArgsConstructor
@Slf4j
@ConditionalOnProperty(prefix = "opal.testing-support-endpoints", name = "enabled", havingValue = "true")
public class ObservedDraftCasefileQueuePublisher implements DraftCasefileQueuePublisher {

    private final DraftCasefileQueuePublisherImpl delegate;
    private final PublicationEvidenceWriter writer;

    @Override
    public void publish(DraftCasefileQueueMessage message) {
        Optional<UUID> attempt = writer.begin(message.draftCasefileId());
        try {
            delegate.publish(message);
        } catch (RuntimeException exception) {
            attempt.ifPresent(id -> complete(id, false));
            throw exception;
        }
        attempt.ifPresent(id -> complete(id, true));
    }

    private void complete(UUID attemptId, boolean acknowledged) {
        try {
            if (acknowledged) {
                writer.acknowledge(attemptId);
            } else {
                writer.markUncertain(attemptId);
            }
        } catch (RuntimeException exception) {
            // Completion is best effort: STARTED remains visible without changing the send outcome.
            log.warn("Publication evidence outcome could not be stored: attempt_id={}", attemptId);
        }
    }
}
