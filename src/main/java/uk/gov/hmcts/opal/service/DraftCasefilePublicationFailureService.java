package uk.gov.hmcts.opal.service;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.mapper.DraftCasefilePublicationMapper;
import uk.gov.hmcts.opal.exception.DraftCasefilePublicationException.Attempt;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.repository.extensions.DraftCasefilePublicationRepository;

import java.time.Clock;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.Objects;

@Service
@RequiredArgsConstructor
public class DraftCasefilePublicationFailureService {
    private final DraftCasefileRepository drafts;
    private final DraftCasefilePublicationRepository publication;
    private final Clock clock;
    private final DraftCasefilePublicationMapper mapper;

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public boolean markFailed(Attempt attempt, String safeStatusMessage) {
        var draft = drafts.findForPublicationById(attempt.draftCasefileId()).orElse(null);
        if (draft == null) {
            return false;
        }
        mapper.validatePublicationState(draft);
        if (draft.getCasefileStatus() != DraftCasefileStatus.PUBLISHING_PENDING) {
            return false;
        }
        if (!Objects.equals(draft.getVersionNumber(), attempt.versionNumber())
            || !Objects.equals(draft.getValidatedBy(), attempt.validatedBy())
            || !Objects.equals(draft.getValidatedDate(), attempt.validatedDate())) {
            throw new IllegalStateException("Publication attempt has changed");
        }
        publication.initialiseLegacyVersion(draft);
        draft.markPublishingFailed(safeStatusMessage,
            LocalDateTime.ofInstant(clock.instant().truncatedTo(ChronoUnit.MICROS), ZoneOffset.UTC));
        drafts.flush();
        return true;
    }
}
