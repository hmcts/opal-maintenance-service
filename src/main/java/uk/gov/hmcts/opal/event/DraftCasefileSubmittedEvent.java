package uk.gov.hmcts.opal.event;

import java.time.Instant;
import java.util.Set;

public record DraftCasefileSubmittedEvent(Long draftId, Long userId, String ipAddress, Instant submittedAt,
                                         Set<ParticipantCategory> participantCategories) {

    public DraftCasefileSubmittedEvent {
        participantCategories = Set.copyOf(participantCategories);
    }

    public enum ParticipantCategory {
        RESPONDENT,
        APPLICANT_BENEFICIARY,
        RELATED_PARTIES,
        MINOR_CREDITOR
    }
}
