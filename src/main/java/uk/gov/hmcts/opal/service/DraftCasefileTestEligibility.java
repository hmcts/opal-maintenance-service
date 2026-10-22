package uk.gov.hmcts.opal.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;

@Component
@RequiredArgsConstructor
@ConditionalOnProperty(prefix = "opal.testing-support-endpoints", name = "enabled", havingValue = "true")
public class DraftCasefileTestEligibility {

    private final ObjectMapper objectMapper;

    public boolean isUnlinked(DraftCasefileEntity draft) {
        if (draft.getAccountId() != null || draft.getAccountNumber() != null) {
            return false;
        }
        try {
            JsonNode snapshot = objectMapper.readTree(draft.getCasefileSnapshot());
            if (snapshot == null || !snapshot.isObject()
                || !isEmptyAccount(snapshot.path("respondent_account"))
                || !isEmptyAccount(snapshot.path("applicant_account"))) {
                return false;
            }
            JsonNode minors = snapshot.path("minor_creditor_accounts");
            if (!minors.isArray()) {
                return false;
            }
            for (JsonNode minor : minors) {
                if (!isEmptyAccount(minor)) {
                    return false;
                }
            }
            return true;
        } catch (JsonProcessingException exception) {
            return false;
        }
    }

    private static boolean isEmptyAccount(JsonNode account) {
        return account.isObject() && account.has("account_id") && account.get("account_id").isNull()
            && account.has("account_number") && account.get("account_number").isNull();
    }
}
