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
import uk.gov.hmcts.opal.repository.DraftCasefileCleanupRepository;

import java.util.Optional;

@Service
@RequiredArgsConstructor
@ConditionalOnProperty(prefix = "opal.testing-support-endpoints",
    name = "enabled", havingValue = "true")
public class DraftCasefileCleanupService {

    private final DraftCasefileTestScope scope;
    private final DraftCasefileRepository repository;
    private final DraftCasefileTestEligibility eligibility;
    private final DraftCasefileCleanupRepository graphs;

    @Transactional
    public void cleanup(Long draftCasefileId, String testRunReference) {
        Optional<DraftCasefileEntity> found = repository.findForCleanupById(draftCasefileId);
        if (found.isEmpty()) {
            return;
        }
        DraftCasefileEntity draft = found.orElseThrow();
        scope.requireOwnedRun(draft, testRunReference);
        DraftCasefileCleanupRepository.Graph graph = null;
        if (draft.getCasefileStatus() == DraftCasefileStatus.PUBLISHED) {
            requireApproval(draft);
            graphs.lockPublicationTargetsForCleanup();
            graph = graphs.lockGraph(draft, testRunReference);
        } else {
            requireUnpublished(draft);
        }
        if (draft.getVersionNumber() == null) {
            graphs.deleteUnversionedDraft(draftCasefileId);
        } else {
            repository.delete(draft);
        }
        repository.flush();
        if (graph != null) {
            graphs.deleteGraph(graph);
        }
    }

    private void requireUnpublished(DraftCasefileEntity draft) {
        if (draft.getCasefileStatus() == null) {
            throw conflict();
        }
        boolean unlinkedLifecycle = switch (draft.getCasefileStatus()) {
            case SUBMITTED, REJECTED, RESUBMITTED, DELETED, PUBLISHING_FAILED, PUBLISHING_PENDING -> true;
            case PUBLISHED -> false;
        };
        boolean submittedWithValidation = draft.getCasefileStatus() == DraftCasefileStatus.SUBMITTED
            && (draft.getValidatedDate() != null || draft.getValidatedBy() != null
                || draft.getValidatedByName() != null);
        if (!unlinkedLifecycle || submittedWithValidation || !eligibility.isUnlinked(draft)) {
            throw conflict();
        }
        if (draft.getCasefileStatus() == DraftCasefileStatus.PUBLISHING_PENDING) {
            requireApproval(draft);
        }
    }

    private void requireApproval(DraftCasefileEntity draft) {
        if (draft.getValidatedDate() == null || draft.getValidatedBy() == null
            || draft.getValidatedBy().isBlank() || draft.getValidatedByName() == null
            || draft.getValidatedByName().isBlank() || draft.getValidatedBy().equals(draft.getSubmittedBy())) {
            throw conflict();
        }
    }

    private static OpalApiException conflict() {
        return new OpalApiException(DraftCasefileError.CLEANUP_NOT_ELIGIBLE,
            "Draft Casefile is not eligible for test cleanup");
    }
}
