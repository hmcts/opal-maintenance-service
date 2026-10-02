package uk.gov.hmcts.opal.service;

import lombok.RequiredArgsConstructor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import uk.gov.hmcts.opal.authentication.MaintenanceUser;
import uk.gov.hmcts.opal.authentication.MaintenanceUserContext;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.event.DraftCasefileSubmittedEvent;
import uk.gov.hmcts.opal.generated.model.DraftCasefileAddRequest;
import uk.gov.hmcts.opal.generated.model.DraftCasefileAddResponse;
import uk.gov.hmcts.opal.logging.DraftCasefileParticipantCategoryResolver;
import uk.gov.hmcts.opal.mapper.DraftCasefileMapper;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.validator.DraftCasefileValidator;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;

import static uk.gov.hmcts.opal.authentication.MaintenancePermission.CREATE_MANAGE_DRAFT_CASEFILES;

@Service
@RequiredArgsConstructor
public class DraftCasefileService {

    private final MaintenanceUserContext userContext;
    private final DraftCasefileValidator validator;
    private final DraftCasefileRepository repository;
    private final DraftCasefileMapper mapper;
    private final DraftCasefileParticipantCategoryResolver participantCategoryResolver;
    private final ApplicationEventPublisher eventPublisher;
    private final Clock clock;

    @Transactional
    public DraftCasefileAddResponse addDraftCasefile(DraftCasefileAddRequest request) {
        MaintenanceUser user = userContext.forBusinessUnit(request.getBusinessUnitId(), CREATE_MANAGE_DRAFT_CASEFILES);
        validator.validate(request);
        Instant submittedAt = clock.instant().truncatedTo(ChronoUnit.MICROS);
        DraftCasefileEntity entity = repository.save(mapper.toEntity(request, user, submittedAt));
        DraftCasefileAddResponse response = mapper.toResponse(entity);
        eventPublisher.publishEvent(new DraftCasefileSubmittedEvent(
            entity.getDraftCasefileId(), user.userId(), user.ipAddress(), submittedAt,
            participantCategoryResolver.resolve(request.getCasefile())));
        return response;
    }
}
