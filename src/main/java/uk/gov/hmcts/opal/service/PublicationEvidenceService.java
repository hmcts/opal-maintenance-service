package uk.gov.hmcts.opal.service;

import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;
import uk.gov.hmcts.opal.common.exception.OpalApiException;
import uk.gov.hmcts.opal.dto.PublicationEvidenceCounts;
import uk.gov.hmcts.opal.dto.PublicationObservation;
import uk.gov.hmcts.opal.dto.RegisteredPublicationEvidence;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.exception.DraftCasefileError;
import uk.gov.hmcts.opal.exception.ResourceConflictException;
import uk.gov.hmcts.opal.generated.model.TestingSupportPublicationEvidence;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.repository.PublicationEvidenceRepository;

import java.time.ZoneOffset;
import java.util.Optional;

@Service
@RequiredArgsConstructor
@ConditionalOnProperty(prefix = "opal.testing-support-endpoints", name = "enabled", havingValue = "true")
public class PublicationEvidenceService {

    private final DraftCasefileRepository drafts;
    private final DraftCasefileTestScope scope;
    private final DraftCasefileTestEligibility eligibility;
    private final PublicationEvidenceRepository evidence;

    @Transactional
    public RegisteredPublicationEvidence register(Long id, String testRunReference) {
        DraftCasefileEntity draft = drafts.findForCleanupById(id)
            .orElseThrow(() -> new EntityNotFoundException("Draft Casefile not found"));
        scope.requireOwnedRun(draft, testRunReference);
        Optional<PublicationObservation> existing = evidence.findObservation(id);
        if (existing.isPresent()) {
            return new RegisteredPublicationEvidence(response(requireMatchingRun(existing.orElseThrow(),
                testRunReference)), false);
        }
        requireEligible(draft);
        return new RegisteredPublicationEvidence(response(evidence.register(id, testRunReference)), true);
    }

    @Transactional(readOnly = true, isolation = Isolation.REPEATABLE_READ)
    public TestingSupportPublicationEvidence read(Long id, String testRunReference) {
        DraftCasefileEntity draft = drafts.findById(id)
            .orElseThrow(() -> new EntityNotFoundException("Draft Casefile not found"));
        scope.requireOwnedRun(draft, testRunReference);
        PublicationObservation observation = evidence.findObservation(id).orElseThrow(() ->
            new OpalApiException(DraftCasefileError.PUBLICATION_EVIDENCE_NOT_REGISTERED,
                "Publication evidence is not registered"));
        return response(requireMatchingRun(observation, testRunReference));
    }

    private void requireEligible(DraftCasefileEntity draft) {
        boolean eligibleStatus = draft.getCasefileStatus() != null && switch (draft.getCasefileStatus()) {
            case SUBMITTED, REJECTED, RESUBMITTED -> true;
            default -> false;
        };
        if (!eligibleStatus || !eligibility.isUnlinked(draft)) {
            throw new ResourceConflictException("Draft Casefile is not eligible for publication evidence registration");
        }
    }

    private PublicationObservation requireMatchingRun(PublicationObservation observation, String testRunReference) {
        if (!observation.testRunReference().equals(testRunReference)) {
            throw new AccessDeniedException("Draft Casefile publication evidence is not permitted");
        }
        return observation;
    }

    private TestingSupportPublicationEvidence response(PublicationObservation observation) {
        PublicationEvidenceCounts counts = evidence.counts(observation.observationId());
        return new TestingSupportPublicationEvidence().observationId(observation.observationId())
            .registeredAt(observation.registeredAt().atOffset(ZoneOffset.UTC))
            .sendAttemptCount(counts.sendAttemptCount()).acknowledgedSendCount(counts.acknowledgedSendCount())
            .uncertainSendCount(counts.uncertainSendCount()).unfinishedSendCount(counts.unfinishedSendCount())
            .evidenceComplete(counts.evidenceComplete());
    }
}
