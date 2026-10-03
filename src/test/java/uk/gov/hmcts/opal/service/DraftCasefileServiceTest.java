package uk.gov.hmcts.opal.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.security.access.AccessDeniedException;
import tools.jackson.databind.json.JsonMapper;
import uk.gov.hmcts.opal.authorisation.MaintenanceUser;
import uk.gov.hmcts.opal.authorisation.MaintenanceUserService;
import uk.gov.hmcts.opal.common.exception.OpalApiException;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.event.DraftCasefilePersonalDataEvent;
import uk.gov.hmcts.opal.event.DraftCasefilePersonalDataEvent.Operation;
import uk.gov.hmcts.opal.exception.DraftCasefileError;
import uk.gov.hmcts.opal.generated.model.CasefileType;
import uk.gov.hmcts.opal.generated.model.DraftCasefileAddRequest;
import uk.gov.hmcts.opal.logging.DraftCasefileParticipantCategoryResolver;
import uk.gov.hmcts.opal.mapper.DraftCasefileMapper;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.validator.DraftCasefileValidator;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Arrays;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static uk.gov.hmcts.opal.authorisation.MaintenancePermission.CREATE_MANAGE_DRAFT_CASEFILES;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class DraftCasefileServiceTest {

    private final MaintenanceUserService userService = mock(MaintenanceUserService.class);
    private final DraftCasefileValidator validator = mock(DraftCasefileValidator.class);
    private final DraftCasefileRepository repository = mock(DraftCasefileRepository.class);
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
        new DraftCasefileMapper(new com.fasterxml.jackson.databind.ObjectMapper().findAndRegisterModules()),
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
}
