package uk.gov.hmcts.opal.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import uk.gov.hmcts.opal.authorisation.MaintenanceUser;
import uk.gov.hmcts.opal.authorisation.MaintenanceUserService;
import uk.gov.hmcts.opal.common.exception.OpalApiException;
import uk.gov.hmcts.opal.config.DraftCasefileCleanupProperties;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.exception.DraftCasefileError;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;

import java.util.Optional;

import static uk.gov.hmcts.opal.authorisation.MaintenancePermission.CREATE_MANAGE_DRAFT_CASEFILES;

@Service
@RequiredArgsConstructor
@ConditionalOnProperty(prefix = "opal.testing-support-endpoints",
    name = {"enabled", "draft-casefile-cleanup.enabled"}, havingValue = "true")
public class DraftCasefileCleanupService {

    private final MaintenanceUserService users;
    private final DraftCasefileRepository repository;
    private final DraftCasefileCleanupProperties properties;
    private final ObjectMapper objectMapper;

    @Transactional
    public void cleanup(Long draftCasefileId, String testRunReference) {
        MaintenanceUser caller = users.requireAuthorisedUser(
            properties.businessUnitId(), CREATE_MANAGE_DRAFT_CASEFILES);
        if (!properties.userId().equals(caller.userId())
            || !properties.businessUnitUserId().equals(caller.businessUnitUserId())) {
            throw denied();
        }
        Optional<DraftCasefileEntity> found = repository.findForCleanupById(draftCasefileId);
        if (found.isEmpty()) {
            return;
        }
        DraftCasefileEntity draft = found.orElseThrow();
        if (!properties.businessUnitId().equals(draft.getBusinessUnitId())
            || !properties.businessUnitUserId().equals(draft.getSubmittedBy())) {
            throw denied();
        }
        requireMatchingRun(draft.getCasefile(), testRunReference);
        requireUnpublished(draft);
        repository.delete(draft);
        repository.flush();
    }

    private void requireMatchingRun(String storedCasefile, String reference) {
        try {
            JsonNode root = objectMapper.readTree(storedCasefile);
            JsonNode marker = root == null ? null : root.at("/respondent_account/remo_reference");
            if (marker == null || !marker.isTextual() || !reference.equals(marker.textValue())) {
                throw denied();
            }
        } catch (JsonProcessingException exception) {
            throw denied();
        }
    }

    private void requireUnpublished(DraftCasefileEntity draft) {
        if (draft.getCasefileStatus() != DraftCasefileStatus.SUBMITTED
            || draft.getAccountId() != null || draft.getAccountNumber() != null
            || draft.getValidatedDate() != null || draft.getValidatedBy() != null
            || draft.getValidatedByName() != null) {
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

    private static AccessDeniedException denied() {
        return new AccessDeniedException("Draft Casefile test cleanup is not permitted");
    }

    private static OpalApiException conflict() {
        return new OpalApiException(DraftCasefileError.CLEANUP_NOT_ELIGIBLE,
            "Draft Casefile is not eligible for test cleanup");
    }
}
