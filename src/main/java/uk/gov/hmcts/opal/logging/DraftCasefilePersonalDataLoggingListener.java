package uk.gov.hmcts.opal.logging;

import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;
import uk.gov.hmcts.opal.event.DraftCasefileListPersonalDataEvent;
import uk.gov.hmcts.opal.event.DraftCasefilePersonalDataEvent.Operation;
import uk.gov.hmcts.opal.event.DraftCasefilePersonalDataEvent.ParticipantCategory;
import uk.gov.hmcts.opal.event.DraftCasefilePersonalDataEvent;
import uk.gov.hmcts.opal.logging.integration.dto.IdentifierType;
import uk.gov.hmcts.opal.logging.integration.dto.ParticipantIdentifier;
import uk.gov.hmcts.opal.logging.integration.dto.PersonalDataProcessingCategory;
import uk.gov.hmcts.opal.logging.integration.dto.PersonalDataProcessingLogDetails;
import uk.gov.hmcts.opal.logging.integration.service.LoggingService;

import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;

@Component
@RequiredArgsConstructor
public class DraftCasefilePersonalDataLoggingListener {

    private static final Logger LOG = LoggerFactory.getLogger(DraftCasefilePersonalDataLoggingListener.class);
    private final LoggingService loggingService;

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = false)
    public void onPersonalDataAccess(DraftCasefilePersonalDataEvent event) {
        for (ParticipantCategory category : ParticipantCategory.values()) {
            if (event.participantCategories().contains(category)) {
                send(event, category);
            }
        }
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = false)
    public void onPersonalDataListAccess(DraftCasefileListPersonalDataEvent event) {
        for (ParticipantCategory category : ParticipantCategory.values()) {
            List<Long> draftIds = event.draftIdsByCategory().getOrDefault(category, List.of());
            if (!draftIds.isEmpty()) {
                send(Operation.LIST_VIEW, event.userId(), event.ipAddress(), event.occurredAt(), draftIds, category);
            }
        }
    }

    private void send(DraftCasefilePersonalDataEvent event, ParticipantCategory category) {
        send(event.operation(), event.userId(), event.ipAddress(), event.occurredAt(),
            List.of(event.draftId()), category);
    }

    private void send(Operation operation, Long userId, String ipAddress, Instant occurredAt,
                      List<Long> draftIds, ParticipantCategory category) {
        PersonalDataProcessingLogDetails details = PersonalDataProcessingLogDetails.builder()
            .category(processingCategory(operation))
            .businessIdentifier(operationName(operation, category))
            .createdAt(occurredAt.atOffset(ZoneOffset.UTC))
            .createdBy(new ParticipantIdentifier(userId.toString(), DraftIdentifierType.OPAL_USER_ID))
            .ipAddress(ipAddress)
            .individuals(draftIds.stream()
                .map(id -> new ParticipantIdentifier(id.toString(), DraftIdentifierType.DRAFT_CASEFILE)).toList())
            .build();
        try {
            if (!loggingService.personalDataAccessLogAsync(details)) {
                logFailure(category);
            }
        } catch (RuntimeException exception) {
            // Preserve the committed result and omit sensitive publisher diagnostics.
            logFailure(category);
        }
    }

    private static void logFailure(ParticipantCategory category) {
        LOG.error("Draft Casefile personal data logging failed for role {}", category);
    }

    private static PersonalDataProcessingCategory processingCategory(Operation operation) {
        return switch (operation) {
            case SUBMISSION -> PersonalDataProcessingCategory.COLLECTION;
            case VIEW, LIST_VIEW -> PersonalDataProcessingCategory.CONSULTATION;
        };
    }

    private static String operationName(Operation operation, ParticipantCategory category) {
        String action = switch (operation) {
            case SUBMISSION -> "Submit Draft Casefile - ";
            case VIEW -> "View Draft Casefile - ";
            case LIST_VIEW -> "View Draft Casefiles - ";
        };
        return action + switch (category) {
            case RESPONDENT -> "Respondent";
            case APPLICANT_BENEFICIARY -> "Applicant / Beneficiary";
            case RELATED_PARTIES -> "Related parties";
            case MINOR_CREDITOR -> "Minor Creditor";
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
