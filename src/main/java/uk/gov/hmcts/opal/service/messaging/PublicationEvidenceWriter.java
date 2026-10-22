package uk.gov.hmcts.opal.service.messaging;

import lombok.RequiredArgsConstructor;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import uk.gov.hmcts.opal.repository.PublicationEvidenceRepository;

import java.util.Optional;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@ConditionalOnProperty(prefix = "opal.testing-support-endpoints", name = "enabled", havingValue = "true")
public class PublicationEvidenceWriter {

    private final PublicationEvidenceRepository repository;

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public Optional<UUID> begin(Long draftId) {
        return repository.findObservation(draftId)
            .map(observation -> repository.insertAttempt(observation.observationId()));
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void acknowledge(UUID attemptId) {
        repository.acknowledge(attemptId);
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void markUncertain(UUID attemptId) {
        repository.markUncertain(attemptId);
    }
}
