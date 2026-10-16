package uk.gov.hmcts.opal.service;

import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import uk.gov.hmcts.opal.authorisation.MaintenanceUser;
import uk.gov.hmcts.opal.authorisation.MaintenanceUserService;
import uk.gov.hmcts.opal.dto.TestingSupportDraftCasefileMatches;
import uk.gov.hmcts.opal.dto.TestingSupportDraftCasefileMetadata;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.mapper.TestingSupportDraftCasefileMapper;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.testing.DraftCasefileTestMarker;

import java.util.List;

import static uk.gov.hmcts.opal.authorisation.MaintenancePermission.CREATE_MANAGE_DRAFT_CASEFILES;

@Service
@RequiredArgsConstructor
public class TestingSupportDraftCasefileService {

    private static final short SUPPORTED_BUSINESS_UNIT_ID = 44;

    private final MaintenanceUserService maintenanceUserService;
    private final DraftCasefileRepository repository;
    private final TestingSupportDraftCasefileMapper mapper;
    private final DraftCasefileTestMarker markerValidator;

    @Transactional(readOnly = true)
    public TestingSupportDraftCasefileMetadata inspect(Long id) {
        MaintenanceUser user = supportUser();
        DraftCasefileEntity entity = eligible(id, user);
        return mapper.toMetadata(entity);
    }

    @Transactional(readOnly = true)
    public TestingSupportDraftCasefileMatches findByMarker(String marker) {
        MaintenanceUser user = supportUser();
        markerValidator.requireValid(marker);
        List<Long> ids = repository.findTestingSupportIdsByMarker(
            SUPPORTED_BUSINESS_UNIT_ID, user.businessUnitUserId(), marker);
        return new TestingSupportDraftCasefileMatches(ids.size(), List.copyOf(ids));
    }

    @Transactional
    public void delete(Long id) {
        MaintenanceUser user = supportUser();
        DraftCasefileEntity entity = eligible(id, user);
        repository.delete(entity);
        repository.flush();
    }

    private MaintenanceUser supportUser() {
        return maintenanceUserService.requireAuthorisedUser(
            SUPPORTED_BUSINESS_UNIT_ID, CREATE_MANAGE_DRAFT_CASEFILES);
    }

    private DraftCasefileEntity eligible(Long id, MaintenanceUser user) {
        DraftCasefileEntity entity = repository.findById(id).orElseThrow(this::notFound);
        if (entity.getBusinessUnitId() != SUPPORTED_BUSINESS_UNIT_ID
            || !user.businessUnitUserId().equals(entity.getSubmittedBy())
            || !markerValidator.isValid(mapper.marker(entity))) {
            throw notFound();
        }
        return entity;
    }

    private ResponseStatusException notFound() {
        return new ResponseStatusException(HttpStatus.NOT_FOUND);
    }
}
