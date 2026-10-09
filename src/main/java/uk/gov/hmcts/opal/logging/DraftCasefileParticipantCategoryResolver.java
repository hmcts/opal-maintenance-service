package uk.gov.hmcts.opal.logging;

import org.springframework.stereotype.Component;
import tools.jackson.databind.JsonNode;
import uk.gov.hmcts.opal.event.DraftCasefilePersonalDataEvent.ParticipantCategory;
import uk.gov.hmcts.opal.generated.model.CasefileSnapshot;

import java.util.EnumSet;
import java.util.Set;

@Component
public class DraftCasefileParticipantCategoryResolver {

    public Set<ParticipantCategory> resolve(JsonNode casefile) {
        Set<ParticipantCategory> categories = EnumSet.of(ParticipantCategory.RESPONDENT,
            ParticipantCategory.APPLICANT_BENEFICIARY);
        JsonNode respondent = casefile.at("/respondent_account/respondent");
        JsonNode applicant = casefile.path("applicant");
        if (respondent.hasNonNull("debtor_details") || respondent.hasNonNull("third_party_details")
            || applicant.hasNonNull("third_party_details") || hasBankDetails(applicant)) {
            categories.add(ParticipantCategory.RELATED_PARTIES);
        }
        for (JsonNode creditor : casefile.path("minor_creditors")) {
            categories.add(ParticipantCategory.MINOR_CREDITOR);
            if (hasBankDetails(creditor)) {
                categories.add(ParticipantCategory.RELATED_PARTIES);
            }
        }
        return Set.copyOf(categories);
    }

    public Set<ParticipantCategory> resolveSummary(CasefileSnapshot snapshot) {
        Set<ParticipantCategory> categories = EnumSet.of(
            ParticipantCategory.RESPONDENT, ParticipantCategory.APPLICANT_BENEFICIARY);
        if (snapshot.getMinorCreditorAccounts() != null && !snapshot.getMinorCreditorAccounts().isEmpty()) {
            categories.add(ParticipantCategory.MINOR_CREDITOR);
        }
        return Set.copyOf(categories);
    }

    private static boolean hasBankDetails(JsonNode participant) {
        JsonNode bankAccount = participant.path("bank_account_details");
        return bankAccount.hasNonNull("uk_bank_details") || bankAccount.hasNonNull("non_uk_bank_details");
    }
}
