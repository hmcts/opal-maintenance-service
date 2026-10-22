package uk.gov.hmcts.opal.repository.extensions;

import uk.gov.hmcts.opal.entity.DraftCasefileEntity;

public interface DraftCasefilePublicationRepository {

    PublicationResult publish(Long draftCasefileId);

    void initialiseLegacyVersion(DraftCasefileEntity managedDraft);

    record PublicationResult(Long respondentAccountId, String accountNumber, String publishedAccountsJson) { }
}
