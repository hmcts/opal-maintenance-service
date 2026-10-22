package uk.gov.hmcts.opal.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import uk.gov.hmcts.opal.common.exception.OpalApiException;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.exception.DraftCasefileError;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;

import java.util.Optional;

@Service
@RequiredArgsConstructor
@ConditionalOnProperty(prefix = "opal.testing-support-endpoints",
    name = "enabled", havingValue = "true")
public class DraftCasefileCleanupService {

    private final DraftCasefileTestScope scope;
    private final DraftCasefileRepository repository;
    private final ObjectMapper objectMapper;

    @Transactional
    public void cleanup(Long draftCasefileId, String testRunReference) {
        Optional<DraftCasefileEntity> found = repository.findForCleanupById(draftCasefileId);
        if (found.isEmpty()) {
            return;
        }
        DraftCasefileEntity draft = found.orElseThrow();
        scope.requireOwnedRun(draft, testRunReference);
        requireUnpublished(draft);
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
        if (!unlinkedLifecycle || submittedWithValidation
            || draft.getAccountId() != null || draft.getAccountNumber() != null) {
            throw conflict();
        }
        try {
            JsonNode snapshot = objectMapper.readTree(draft.getCasefileSnapshot());
            if (snapshot == null || !snapshot.isObject()) {
                throw conflict();
            }
            requireEmptyAccount(snapshot.path("respondent_account"));
            requireEmptyAccount(snapshot.path("applicant_account"));
            JsonNode minors = snapshot.path("minor_creditor_accounts");
            if (!minors.isArray()) {
                throw conflict();
            }
            for (JsonNode minor : minors) {
                requireEmptyAccount(minor);
            }
        } catch (JsonProcessingException exception) {
            throw conflict();
        }
    }

    private static void requireEmptyAccount(JsonNode account) {
        if (!account.isObject() || !account.has("account_id") || !account.get("account_id").isNull()
            || !account.has("account_number") || !account.get("account_number").isNull()) {
            throw conflict();
        }
    }

    private static OpalApiException conflict() {
        return new OpalApiException(DraftCasefileError.CLEANUP_NOT_ELIGIBLE,
            "Draft Casefile is not eligible for test cleanup");
    }
}
