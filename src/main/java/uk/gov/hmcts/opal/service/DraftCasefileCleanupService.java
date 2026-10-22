package uk.gov.hmcts.opal.service;

import lombok.RequiredArgsConstructor;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import uk.gov.hmcts.opal.common.exception.OpalApiException;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.exception.DraftCasefileError;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.repository.PublicationEvidenceRepository;

import java.util.Optional;

@Service
@RequiredArgsConstructor
@ConditionalOnProperty(prefix = "opal.testing-support-endpoints",
    name = "enabled", havingValue = "true")
public class DraftCasefileCleanupService {

    private final DraftCasefileTestScope scope;
    private final DraftCasefileRepository repository;
    private final DraftCasefileTestEligibility eligibility;
    private final PublicationEvidenceRepository evidence;

    @Transactional
    public void cleanup(Long draftCasefileId, String testRunReference) {
        Optional<DraftCasefileEntity> found = repository.findForCleanupById(draftCasefileId);
        if (found.isEmpty()) {
            return;
        }
        DraftCasefileEntity draft = found.orElseThrow();
        scope.requireOwnedRun(draft, testRunReference);
        requireUnpublished(draft);
        evidence.findObservation(draftCasefileId).ifPresent(observation ->
            evidence.deleteObservation(draftCasefileId, observation.testRunReference()));
        repository.delete(draft);
        repository.flush();
    }

    private void requireUnpublished(DraftCasefileEntity draft) {
        if (draft.getCasefileStatus() == null) {
            throw conflict();
        }
        boolean unlinkedLifecycle = switch (draft.getCasefileStatus()) {
            case SUBMITTED, REJECTED, RESUBMITTED, DELETED, PUBLISHING_FAILED -> true;
            case PUBLISHING_PENDING, PUBLISHED -> false;
        };
        boolean submittedWithValidation = draft.getCasefileStatus() == DraftCasefileStatus.SUBMITTED
            && (draft.getValidatedDate() != null || draft.getValidatedBy() != null
                || draft.getValidatedByName() != null);
        if (!unlinkedLifecycle || submittedWithValidation || !eligibility.isUnlinked(draft)) {
            throw conflict();
        }
    }

    private static OpalApiException conflict() {
        return new OpalApiException(DraftCasefileError.CLEANUP_NOT_ELIGIBLE,
            "Draft Casefile is not eligible for test cleanup");
    }
}
