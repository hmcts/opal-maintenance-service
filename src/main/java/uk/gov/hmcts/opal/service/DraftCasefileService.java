package uk.gov.hmcts.opal.service;

import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import uk.gov.hmcts.opal.authorisation.MaintenanceUser;
import uk.gov.hmcts.opal.authorisation.MaintenanceUserService;
import uk.gov.hmcts.opal.dto.DraftCasefileFilter;
import uk.gov.hmcts.opal.dto.VersionedResponse;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.event.DraftCasefileListPersonalDataEvent;
import uk.gov.hmcts.opal.event.DraftCasefilePersonalDataEvent.Operation;
import uk.gov.hmcts.opal.event.DraftCasefilePersonalDataEvent.ParticipantCategory;
import uk.gov.hmcts.opal.event.DraftCasefilePersonalDataEvent;
import uk.gov.hmcts.opal.generated.model.DraftCasefileAddRequest;
import uk.gov.hmcts.opal.generated.model.DraftCasefileAddResponse;
import uk.gov.hmcts.opal.generated.model.DraftCasefileGetResponse;
import uk.gov.hmcts.opal.generated.model.DraftCasefileListResponse;
import uk.gov.hmcts.opal.generated.model.DraftCasefileSummary;
import uk.gov.hmcts.opal.logging.DraftCasefileParticipantCategoryResolver;
import uk.gov.hmcts.opal.mapper.DraftCasefileGetMapper;
import uk.gov.hmcts.opal.mapper.DraftCasefileMapper;
import uk.gov.hmcts.opal.mapper.DraftCasefileSummaryMapper;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.repository.DraftCasefileSummaryProjection;
import uk.gov.hmcts.opal.validator.DraftCasefileValidator;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.EnumMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

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
    private final DraftCasefileSummaryMapper summaryMapper;
    private final DraftCasefileParticipantCategoryResolver participantCategoryResolver;
    private final ApplicationEventPublisher eventPublisher;
    private final Clock clock;

    @Transactional
    public VersionedResponse<DraftCasefileAddResponse> addDraftCasefile(DraftCasefileAddRequest request) {
        MaintenanceUser user = maintenanceUserService.requireAuthorisedUser(
            request.getBusinessUnitId(), CREATE_MANAGE_DRAFT_CASEFILES);
        validator.validate(request);
        Instant submittedAt = clock.instant().truncatedTo(ChronoUnit.MICROS);
        DraftCasefileEntity entity = repository.save(mapper.toEntity(request, user, submittedAt));
        DraftCasefileAddResponse response = mapper.toResponse(entity);
        eventPublisher.publishEvent(new DraftCasefilePersonalDataEvent(Operation.SUBMISSION,
            entity.getDraftCasefileId(), user.userId(), user.ipAddress(), submittedAt,
            participantCategoryResolver.resolve(request.getCasefile())));
        return new VersionedResponse<>(response, entity.getVersionNumber());
    }

    @Transactional(readOnly = true)
    public VersionedResponse<DraftCasefileGetResponse> getDraftCasefile(Long id) {
        DraftCasefileEntity entity = repository.findById(id)
            .orElseThrow(() -> new EntityNotFoundException("Draft Casefile not found"));
        MaintenanceUser user = maintenanceUserService.requireAuthorisedUser(
            entity.getBusinessUnitId(), CREATE_MANAGE_DRAFT_CASEFILES, CHECK_VALIDATE_DRAFT_CASEFILES);
        DraftCasefileGetResponse response = getMapper.toResponse(entity);
        if (entity.getVersionNumber() == null) {
            throw new IllegalStateException("Stored Draft Casefile version is unavailable");
        }
        VersionedResponse<DraftCasefileGetResponse> versionedResponse =
            new VersionedResponse<>(response, entity.getVersionNumber());
        eventPublisher.publishEvent(new DraftCasefilePersonalDataEvent(Operation.VIEW,
            entity.getDraftCasefileId(), user.userId(), user.ipAddress(), clock.instant(),
            participantCategoryResolver.resolve(response.getCasefile())));
        return versionedResponse;
    }

    @Transactional(readOnly = true)
    public DraftCasefileListResponse listDraftCasefiles(DraftCasefileFilter filter, boolean countsOnly) {
        MaintenanceUser user = maintenanceUserService.requireAuthorisedUser(filter.businessUnitId(),
            CREATE_MANAGE_DRAFT_CASEFILES, CHECK_VALIDATE_DRAFT_CASEFILES);
        if (countsOnly) {
            return new DraftCasefileListResponse().count(repository.countMatching(filter));
        }
        List<DraftCasefileSummaryProjection> rows = repository.findSummaries(filter);
        List<DraftCasefileSummary> summaries = rows.stream().map(summaryMapper::toSummary).toList();
        DraftCasefileListResponse response = new DraftCasefileListResponse()
            .count((long) summaries.size()).summaries(summaries);
        if (!rows.isEmpty()) {
            eventPublisher.publishEvent(listAccessEvent(user, summaries));
        }
        return response;
    }

    private DraftCasefileListPersonalDataEvent listAccessEvent(
        MaintenanceUser user, List<DraftCasefileSummary> summaries
    ) {
        Map<ParticipantCategory, Set<Long>> grouped = new EnumMap<>(ParticipantCategory.class);
        for (DraftCasefileSummary summary : summaries) {
            Set<ParticipantCategory> categories =
                participantCategoryResolver.resolveSummary(summary.getCasefileSnapshot());
            for (ParticipantCategory category : categories) {
                grouped.computeIfAbsent(category, unused -> new LinkedHashSet<>()).add(summary.getDraftCasefileId());
            }
        }
        Map<ParticipantCategory, List<Long>> identifiers = new EnumMap<>(ParticipantCategory.class);
        grouped.forEach((category, ids) -> identifiers.put(category, List.copyOf(ids)));
        return new DraftCasefileListPersonalDataEvent(user.userId(), user.ipAddress(), clock.instant(), identifiers);
    }
}
