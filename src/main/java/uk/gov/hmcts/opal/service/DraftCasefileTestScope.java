package uk.gov.hmcts.opal.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import uk.gov.hmcts.opal.authorisation.MaintenanceUser;
import uk.gov.hmcts.opal.authorisation.MaintenanceUserService;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;

import static uk.gov.hmcts.opal.authorisation.MaintenancePermission.CREATE_MANAGE_DRAFT_CASEFILES;

@Service
@RequiredArgsConstructor
@ConditionalOnProperty(prefix = "opal.testing-support-endpoints",
    name = "enabled", havingValue = "true")
public class DraftCasefileTestScope {

    private final MaintenanceUserService users;
    private final ObjectMapper objectMapper;

    public void requireOwnedRun(DraftCasefileEntity draft, String testRunReference) {
        MaintenanceUser caller = users.requireAuthorisedUser(
            draft.getBusinessUnitId(), CREATE_MANAGE_DRAFT_CASEFILES);
        if (!caller.businessUnitUserId().equals(draft.getSubmittedBy())) {
            throw denied();
        }
        requireMatchingRun(draft.getCasefile(), testRunReference);
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

    private static AccessDeniedException denied() {
        return new AccessDeniedException("Draft Casefile test cleanup is not permitted");
    }

}
