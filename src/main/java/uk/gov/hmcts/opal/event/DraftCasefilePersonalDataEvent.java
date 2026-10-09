package uk.gov.hmcts.opal.event;

import java.time.Instant;
import java.util.Set;

public record DraftCasefilePersonalDataEvent(Operation operation, Long draftId, Long userId, String ipAddress,
                                             Instant occurredAt, Set<ParticipantCategory> participantCategories) {

    public DraftCasefilePersonalDataEvent {
        participantCategories = Set.copyOf(participantCategories);
    }

    public enum Operation {
        SUBMISSION,
        VIEW
    }

    public enum ParticipantCategory {
        RESPONDENT,
        APPLICANT_BENEFICIARY,
        RELATED_PARTIES,
        MINOR_CREDITOR
    }
}
