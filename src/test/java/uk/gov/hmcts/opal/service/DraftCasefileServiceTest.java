package uk.gov.hmcts.opal.service;

import jakarta.persistence.EntityNotFoundException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.InOrder;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.security.access.AccessDeniedException;
import tools.jackson.databind.json.JsonMapper;
import uk.gov.hmcts.opal.authorisation.MaintenanceUser;
import uk.gov.hmcts.opal.authorisation.MaintenanceUserService;
import uk.gov.hmcts.opal.common.exception.OpalApiException;
import uk.gov.hmcts.opal.dto.DraftCasefileRetrieval;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.event.DraftCasefilePersonalDataEvent;
import uk.gov.hmcts.opal.event.DraftCasefilePersonalDataEvent.Operation;
import uk.gov.hmcts.opal.exception.DraftCasefileError;
import uk.gov.hmcts.opal.generated.model.CasefileType;
import uk.gov.hmcts.opal.generated.model.DraftCasefileAddRequest;
import uk.gov.hmcts.opal.generated.model.DraftCasefileGetResponse;
import uk.gov.hmcts.opal.logging.DraftCasefileParticipantCategoryResolver;
import uk.gov.hmcts.opal.mapper.DraftCasefileGetMapper;
import uk.gov.hmcts.opal.mapper.DraftCasefileMapper;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.validator.DraftCasefileValidator;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Arrays;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static uk.gov.hmcts.opal.authorisation.MaintenancePermission.CHECK_VALIDATE_DRAFT_CASEFILES;
import static uk.gov.hmcts.opal.authorisation.MaintenancePermission.CREATE_MANAGE_DRAFT_CASEFILES;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class DraftCasefileServiceTest {

    private final MaintenanceUserService userService = mock(MaintenanceUserService.class);
    private final DraftCasefileValidator validator = mock(DraftCasefileValidator.class);
    private final DraftCasefileRepository repository = mock(DraftCasefileRepository.class);
    private final DraftCasefileGetMapper getMapper = mock(DraftCasefileGetMapper.class);
    private final ApplicationEventPublisher events = mock(ApplicationEventPublisher.class);
    private final Clock clock = mock(Clock.class);
    private final MaintenanceUser user = new MaintenanceUser(99L, "BUU-1", "Synthetic User", "192.0.2.1");
    private final DraftCasefileAddRequest request = new DraftCasefileAddRequest().businessUnitId((short) 1)
        .casefileType(CasefileType.REMO_IN).casefile(JsonMapper.builder().build().readTree("""
            {"respondent_account":{"respondent":{"party_details":{"organisation":false,
              "individual_details":{"surname":"Synthetic"}}}},"applicant":{"party_details":{
              "organisation":false,"individual_details":{"surname":"Synthetic"}}}}
            """));
    private final DraftCasefileService service = new DraftCasefileService(userService, validator, repository,
        new DraftCasefileMapper(new com.fasterxml.jackson.databind.ObjectMapper().findAndRegisterModules()), getMapper,
        new DraftCasefileParticipantCategoryResolver(), events, clock);

    @BeforeEach
    void setUp() {
        when(userService.requireAuthorisedUser((short) 1, CREATE_MANAGE_DRAFT_CASEFILES)).thenReturn(user);
    }

    @Test
    void identityFailureDoesNotValidatePersistOrPublish() {
        when(userService.requireAuthorisedUser((short) 1, CREATE_MANAGE_DRAFT_CASEFILES))
            .thenThrow(new AccessDeniedException("No identity"));
        assertThatThrownBy(() -> service.addDraftCasefile(request)).isInstanceOf(AccessDeniedException.class);
        verifyNoInteractions(validator, repository, events, clock);
    }

    @Test
    void referenceFailureDoesNotPersistOrPublish() {
        doThrow(new OpalApiException(DraftCasefileError.INVALID_REQUEST, "Invalid reference"))
            .when(validator).validate(request);
        assertThatThrownBy(() -> service.addDraftCasefile(request)).isInstanceOf(OpalApiException.class);
        verifyNoInteractions(repository, events, clock);
    }

    @Test
    void persistenceFailureDoesNotPublish() {
        when(clock.instant()).thenReturn(Instant.EPOCH);
        when(repository.save(any())).thenThrow(new DataAccessResourceFailureException("Unavailable"));
        assertThatThrownBy(() -> service.addDraftCasefile(request))
            .isInstanceOf(DataAccessResourceFailureException.class);
        verifyNoInteractions(events);
    }

    @Test
    void capturesOneMicrosecondInstantForEntityResponseTimelineAndMinimalEvent() {
        Instant captured = Instant.parse("2026-10-01T12:00:00.123456789Z");
        Instant expected = Instant.parse("2026-10-01T12:00:00.123456Z");
        when(clock.instant()).thenReturn(captured);
        when(repository.save(any())).thenAnswer(invocation -> {
            DraftCasefileEntity entity = invocation.getArgument(0);
            assertThat(entity.getCreatedDate().toInstant(ZoneOffset.UTC)).isEqualTo(expected);
            assertThat(entity.getCasefileStatusDate()).isEqualTo(entity.getCreatedDate());
            assertThat(JsonMapper.builder().build().readTree(entity.getCasefile())).isEqualTo(request.getCasefile());
            return entity.toBuilder().draftCasefileId(123L).versionNumber(0L).build();
        });
        var submission = service.addDraftCasefile(request);
        assertThat(submission.version()).isZero();
        var response = submission.response();
        assertThat(response.getCreatedDate().toInstant()).isEqualTo(expected);
        assertThat(response.getCasefileStatusDate()).isEqualTo(response.getCreatedDate());
        assertThat(response.getTimelineData()).singleElement()
            .satisfies(entry -> assertThat(entry.getStatusDate()).isEqualTo(response.getCreatedDate()));
        verify(clock).instant();
        verify(validator).validate(request);
        verify(userService).requireAuthorisedUser((short) 1, CREATE_MANAGE_DRAFT_CASEFILES);
        verify(events).publishEvent(new DraftCasefilePersonalDataEvent(Operation.SUBMISSION,
            123L, 99L, "192.0.2.1", expected,
            new DraftCasefileParticipantCategoryResolver().resolve(request.getCasefile())));
        assertThat(Arrays.stream(DraftCasefilePersonalDataEvent.class.getRecordComponents()).map(c -> c.getName()))
            .containsExactly("operation", "draftId", "userId", "ipAddress", "occurredAt", "participantCategories");
    }

    @Test
    void authorisesTheOwningBusinessUnitBeforeMappingAndPublishesOnlyMetadata() {
        DraftCasefileEntity row = storedDraft();
        var body = new DraftCasefileGetResponse().casefile(request.getCasefile());
        when(repository.findById(123L)).thenReturn(Optional.of(row));
        when(userService.requireAuthorisedUser((short) 1,
            CREATE_MANAGE_DRAFT_CASEFILES, CHECK_VALIDATE_DRAFT_CASEFILES)).thenReturn(user);
        when(getMapper.toResponse(row)).thenReturn(body);
        when(clock.instant()).thenReturn(Instant.EPOCH);

        assertThat(service.getDraftCasefile(123L)).isEqualTo(new DraftCasefileRetrieval(body, 4L));

        InOrder order = inOrder(repository, userService, getMapper, events);
        order.verify(repository).findById(123L);
        order.verify(userService).requireAuthorisedUser((short) 1,
            CREATE_MANAGE_DRAFT_CASEFILES, CHECK_VALIDATE_DRAFT_CASEFILES);
        order.verify(getMapper).toResponse(row);
        order.verify(events).publishEvent(new DraftCasefilePersonalDataEvent(Operation.VIEW,
            123L, user.userId(), user.ipAddress(), Instant.EPOCH,
            new DraftCasefileParticipantCategoryResolver().resolve(body.getCasefile())));
        verify(repository, never()).save(any());
        verifyNoInteractions(validator);
        assertThat(row.getVersionNumber()).isEqualTo(4L);
    }

    @Test
    void missingDraftDoesNotAuthoriseMapValidateOrPublish() {
        when(repository.findById(123L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.getDraftCasefile(123L))
            .isInstanceOf(EntityNotFoundException.class).hasMessage("Draft Casefile not found");

        verifyNoInteractions(userService, getMapper, validator, events, clock);
        verify(repository, never()).save(any());
    }

    @Test
    void deniedOwningBusinessUnitDoesNotMapValidateOrPublish() {
        DraftCasefileEntity row = storedDraft().toBuilder().businessUnitId((short) 2).build();
        when(repository.findById(123L)).thenReturn(Optional.of(row));
        when(userService.requireAuthorisedUser((short) 2,
            CREATE_MANAGE_DRAFT_CASEFILES, CHECK_VALIDATE_DRAFT_CASEFILES))
            .thenThrow(new AccessDeniedException("Not authorised for owning business unit"));

        assertThatThrownBy(() -> service.getDraftCasefile(123L)).isInstanceOf(AccessDeniedException.class);

        verify(userService).requireAuthorisedUser((short) 2,
            CREATE_MANAGE_DRAFT_CASEFILES, CHECK_VALIDATE_DRAFT_CASEFILES);
        verifyNoInteractions(getMapper, validator, events, clock);
        verify(repository, never()).save(any());
    }

    @Test
    void unreadableStoredDataDoesNotValidateOrPublish() {
        DraftCasefileEntity row = storedDraft();
        when(repository.findById(123L)).thenReturn(Optional.of(row));
        when(userService.requireAuthorisedUser((short) 1,
            CREATE_MANAGE_DRAFT_CASEFILES, CHECK_VALIDATE_DRAFT_CASEFILES)).thenReturn(user);
        when(getMapper.toResponse(row))
            .thenThrow(new IllegalStateException("Unable to read stored Draft Casefile data"));

        assertThatThrownBy(() -> service.getDraftCasefile(123L)).isInstanceOf(IllegalStateException.class);

        verifyNoInteractions(validator, events, clock);
        verify(repository, never()).save(any());
    }

    @Test
    void unavailableRepositoryDoesNotAuthoriseMapValidateOrPublish() {
        when(repository.findById(123L)).thenThrow(new DataAccessResourceFailureException("Unavailable"));

        assertThatThrownBy(() -> service.getDraftCasefile(123L))
            .isInstanceOf(DataAccessResourceFailureException.class);

        verifyNoInteractions(userService, getMapper, validator, events, clock);
        verify(repository, never()).save(any());
    }

    @Test
    void unavailableStoredVersionDoesNotValidateOrPublish() {
        DraftCasefileEntity row = storedDraft().toBuilder().versionNumber(null).build();
        when(repository.findById(123L)).thenReturn(Optional.of(row));
        when(userService.requireAuthorisedUser((short) 1,
            CREATE_MANAGE_DRAFT_CASEFILES, CHECK_VALIDATE_DRAFT_CASEFILES)).thenReturn(user);
        when(getMapper.toResponse(row)).thenReturn(new DraftCasefileGetResponse().casefile(request.getCasefile()));

        assertThatThrownBy(() -> service.getDraftCasefile(123L))
            .isInstanceOf(IllegalStateException.class).hasMessage("Stored Draft Casefile version is unavailable");

        verifyNoInteractions(validator, events, clock);
        verify(repository, never()).save(any());
    }

    private DraftCasefileEntity storedDraft() {
        return DraftCasefileEntity.builder().draftCasefileId(123L).businessUnitId((short) 1)
            .versionNumber(4L).build();
    }
}
