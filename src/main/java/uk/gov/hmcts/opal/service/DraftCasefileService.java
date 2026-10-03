package uk.gov.hmcts.opal.service;

import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import uk.gov.hmcts.opal.authorisation.MaintenanceUser;
import uk.gov.hmcts.opal.authorisation.MaintenanceUserService;
import uk.gov.hmcts.opal.dto.DraftCasefileRetrieval;
import uk.gov.hmcts.opal.dto.DraftCasefileSubmission;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.event.DraftCasefilePersonalDataEvent;
import uk.gov.hmcts.opal.event.DraftCasefilePersonalDataEvent.Operation;
import uk.gov.hmcts.opal.generated.model.DraftCasefileAddRequest;
import uk.gov.hmcts.opal.generated.model.DraftCasefileAddResponse;
import uk.gov.hmcts.opal.generated.model.DraftCasefileGetResponse;
import uk.gov.hmcts.opal.logging.DraftCasefileParticipantCategoryResolver;
import uk.gov.hmcts.opal.mapper.DraftCasefileGetMapper;
import uk.gov.hmcts.opal.mapper.DraftCasefileMapper;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.validator.DraftCasefileValidator;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;

import static uk.gov.hmcts.opal.authorisation.MaintenancePermission.CHECK_VALIDATE_DRAFT_CASEFILES;
import static uk.gov.hmcts.opal.authorisation.MaintenancePermission.CREATE_MANAGE_DRAFT_CASEFILES;

@Service
@RequiredArgsConstructor
public class DraftCasefileService {

    private final MaintenanceUserService maintenanceUserService;
    private final DraftCasefileValidator validator;
    private final DraftCasefileRepository repository;
    private final DraftCasefileMapper mapper;
    private final DraftCasefileGetMapper getMapper;
    private final DraftCasefileParticipantCategoryResolver participantCategoryResolver;
    private final ApplicationEventPublisher eventPublisher;
    private final Clock clock;

    @Transactional
    public DraftCasefileSubmission addDraftCasefile(DraftCasefileAddRequest request) {
        MaintenanceUser user = maintenanceUserService.requireAuthorisedUser(
            request.getBusinessUnitId(), CREATE_MANAGE_DRAFT_CASEFILES);
        validator.validate(request);
        Instant submittedAt = clock.instant().truncatedTo(ChronoUnit.MICROS);
        DraftCasefileEntity entity = repository.save(mapper.toEntity(request, user, submittedAt));
        DraftCasefileAddResponse response = mapper.toResponse(entity);
        eventPublisher.publishEvent(new DraftCasefilePersonalDataEvent(Operation.SUBMISSION,
            entity.getDraftCasefileId(), user.userId(), user.ipAddress(), submittedAt,
            participantCategoryResolver.resolve(request.getCasefile())));
        return new DraftCasefileSubmission(response, entity.getVersionNumber());
    }

    @Transactional(readOnly = true)
    public DraftCasefileRetrieval getDraftCasefile(Long id) {
        DraftCasefileEntity entity = repository.findById(id)
            .orElseThrow(() -> new EntityNotFoundException("Draft Casefile not found"));
        MaintenanceUser user = maintenanceUserService.requireAuthorisedUser(
            entity.getBusinessUnitId(), CREATE_MANAGE_DRAFT_CASEFILES, CHECK_VALIDATE_DRAFT_CASEFILES);
        DraftCasefileGetResponse response = getMapper.toResponse(entity);
        if (entity.getVersionNumber() == null) {
            throw new IllegalStateException("Stored Draft Casefile version is unavailable");
        }
        DraftCasefileRetrieval retrieval = new DraftCasefileRetrieval(response, entity.getVersionNumber());
        eventPublisher.publishEvent(new DraftCasefilePersonalDataEvent(Operation.VIEW,
            entity.getDraftCasefileId(), user.userId(), user.ipAddress(), clock.instant(),
            participantCategoryResolver.resolve(response.getCasefile())));
        return retrieval;
    }
}
