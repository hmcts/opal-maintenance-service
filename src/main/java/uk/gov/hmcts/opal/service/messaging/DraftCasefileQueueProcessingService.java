package uk.gov.hmcts.opal.service.messaging;

import lombok.RequiredArgsConstructor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.event.DraftCasefilePersonalDataEvent;
import uk.gov.hmcts.opal.event.DraftCasefilePersonalDataEvent.Operation;
import uk.gov.hmcts.opal.exception.DraftCasefilePublicationException;
import uk.gov.hmcts.opal.exception.DraftCasefilePublicationException.Attempt;
import uk.gov.hmcts.opal.logging.DraftCasefileParticipantCategoryResolver;
import uk.gov.hmcts.opal.mapper.DraftCasefilePublicationMapper;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.repository.extensions.DraftCasefilePublicationRepository;
import uk.gov.hmcts.opal.validator.DraftCasefilePublicationValidator;
import uk.gov.hmcts.opal.validator.OpenApiSchemaValidator;

import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;

@Service
@RequiredArgsConstructor
public class DraftCasefileQueueProcessingService {
    private final DraftCasefileRepository drafts;
    private final DraftCasefilePublicationRepository publication;
    private final DraftCasefileQueueMessageValidator messages;
    private final DraftCasefilePublicationValidator validator;
    private final DraftCasefilePublicationMapper mapper;
    private final OpenApiSchemaValidator schemas;
    private final DraftCasefileParticipantCategoryResolver categories;
    private final ApplicationEventPublisher events;
    private final Clock clock;

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public Outcome processPendingDraft(DraftCasefileQueueMessage message) {
        var draft = drafts.findForPublicationById(message.draftCasefileId()).orElse(null);
        if (draft == null) {
            return Outcome.NO_OP;
        }
        mapper.validatePublicationState(draft);
        if (draft.getCasefileStatus() != DraftCasefileStatus.PUBLISHING_PENDING) {
            return Outcome.NO_OP;
        }
        messages.validateAuditContext(message);
        if (draft.getValidatedDate() == null
            || !draft.getValidatedDate().toInstant(ZoneOffset.UTC).toString().equals(message.approvalTimestamp())) {
            throw new IllegalArgumentException("Publication message does not match saved approval");
        }
        Attempt attempt = new Attempt(draft.getDraftCasefileId(), draft.getVersionNumber(), draft.getValidatedBy(),
            draft.getValidatedDate());
        try {
            var saved = validator.validate(draft);
            mapper.validatePendingSnapshot(draft.getCasefileSnapshot(), saved);
            var result = publication.publish(draft.getDraftCasefileId());
            String snapshot = mapper.mergePublishedAccounts(draft.getCasefileSnapshot(), saved, result);
            schemas.validate("CasefileSnapshot", snapshot.getBytes(StandardCharsets.UTF_8));
            var publishedAt = clock.instant().truncatedTo(ChronoUnit.MICROS);
            publication.initialiseLegacyVersion(draft);
            draft.markPublished(result.respondentAccountId(), result.accountNumber(), snapshot,
                LocalDateTime.ofInstant(publishedAt, ZoneOffset.UTC));
            drafts.flush();
            events.publishEvent(new DraftCasefilePersonalDataEvent(Operation.PUBLICATION, draft.getDraftCasefileId(),
                message.checkerUserId(), message.originatingIpAddress(), publishedAt, categories.resolve(saved)));
            return Outcome.PUBLISHED;
        } catch (RuntimeException failure) {
            throw new DraftCasefilePublicationException(attempt, failure);
        }
    }

    public enum Outcome { PUBLISHED, NO_OP }
}
