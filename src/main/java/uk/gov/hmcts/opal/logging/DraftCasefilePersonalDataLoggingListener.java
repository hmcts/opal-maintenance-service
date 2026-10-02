package uk.gov.hmcts.opal.logging;

import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;
import uk.gov.hmcts.opal.event.DraftCasefileSubmittedEvent;
import uk.gov.hmcts.opal.event.DraftCasefileSubmittedEvent.ParticipantCategory;
import uk.gov.hmcts.opal.logging.integration.dto.IdentifierType;
import uk.gov.hmcts.opal.logging.integration.dto.ParticipantIdentifier;
import uk.gov.hmcts.opal.logging.integration.dto.PersonalDataProcessingCategory;
import uk.gov.hmcts.opal.logging.integration.dto.PersonalDataProcessingLogDetails;
import uk.gov.hmcts.opal.logging.integration.service.LoggingService;

import java.time.ZoneOffset;
import java.util.List;

@Component
@RequiredArgsConstructor
public class DraftCasefilePersonalDataLoggingListener {

    private static final Logger LOG = LoggerFactory.getLogger(DraftCasefilePersonalDataLoggingListener.class);
    private final LoggingService loggingService;

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = false)
    public void onSubmitted(DraftCasefileSubmittedEvent event) {
        for (ParticipantCategory category : ParticipantCategory.values()) {
            if (event.participantCategories().contains(category)) {
                send(event, category);
            }
        }
    }

    private void send(DraftCasefileSubmittedEvent event, ParticipantCategory category) {
        PersonalDataProcessingLogDetails details = PersonalDataProcessingLogDetails.builder()
            .category(PersonalDataProcessingCategory.COLLECTION)
            .businessIdentifier(operationName(category))
            .createdAt(event.submittedAt().atOffset(ZoneOffset.UTC))
            .createdBy(new ParticipantIdentifier(event.userId().toString(), DraftIdentifierType.OPAL_USER_ID))
            .ipAddress(event.ipAddress())
            .individuals(List.of(new ParticipantIdentifier(event.draftId().toString(),
                DraftIdentifierType.DRAFT_CASEFILE)))
            .build();
        try {
            if (!loggingService.personalDataAccessLogAsync(details)) {
                logFailure(category);
            }
        } catch (RuntimeException exception) {
            // The publisher is an external side effect: preserve the committed result and omit sensitive diagnostics.
            logFailure(category);
        }
    }

    private static void logFailure(ParticipantCategory category) {
        LOG.error("Draft Casefile personal data logging failed for role {}", category);
    }

    private static String operationName(ParticipantCategory category) {
        return switch (category) {
            case RESPONDENT -> "Submit Draft Casefile - Respondent";
            case APPLICANT_BENEFICIARY -> "Submit Draft Casefile - Applicant / Beneficiary";
            case RELATED_PARTIES -> "Submit Draft Casefile - Related parties";
            case MINOR_CREDITOR -> "Submit Draft Casefile - Minor Creditor";
        };
    }

    private enum DraftIdentifierType implements IdentifierType {
        OPAL_USER_ID,
        DRAFT_CASEFILE;

        @Override
        public String getType() {
            return name();
        }
    }
}
