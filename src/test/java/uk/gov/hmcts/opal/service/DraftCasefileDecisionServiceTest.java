package uk.gov.hmcts.opal.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.EnumSource;
import org.mockito.ArgumentCaptor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.security.access.AccessDeniedException;
import tools.jackson.databind.json.JsonMapper;
import uk.gov.hmcts.opal.authorisation.MaintenanceUser;
import uk.gov.hmcts.opal.authorisation.MaintenanceUserService;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.config.JacksonCompatibilityConfiguration;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.event.DraftCasefilePersonalDataEvent;
import uk.gov.hmcts.opal.exception.ResourceConflictException;
import uk.gov.hmcts.opal.generated.model.DraftCasefileGetResponse;
import uk.gov.hmcts.opal.generated.model.DraftCasefileUpdateRequest;
import uk.gov.hmcts.opal.generated.model.DraftCasefileUpdateRequest.CasefileStatusEnum;
import uk.gov.hmcts.opal.logging.DraftCasefileParticipantCategoryResolver;
import uk.gov.hmcts.opal.mapper.DraftCasefileAddResponseMapper;
import uk.gov.hmcts.opal.mapper.DraftCasefileGetMapper;
import uk.gov.hmcts.opal.mapper.DraftCasefileJsonMapper;
import uk.gov.hmcts.opal.mapper.DraftCasefileMapper;
import uk.gov.hmcts.opal.mapper.DraftCasefileSummaryMapper;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.service.messaging.DraftCasefileQueuePublisher;
import uk.gov.hmcts.opal.validator.DraftCasefileQueryValidator;
import uk.gov.hmcts.opal.validator.DraftCasefileValidator;
import uk.gov.hmcts.opal.validator.IfMatchValidator;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.inOrder;
import static uk.gov.hmcts.opal.authorisation.MaintenancePermission.CHECK_VALIDATE_DRAFT_CASEFILES;
import static uk.gov.hmcts.opal.event.DraftCasefilePersonalDataEvent.ParticipantCategory.RESPONDENT;
import static uk.gov.hmcts.opal.event.DraftCasefilePersonalDataEvent.ParticipantCategory.APPLICANT_BENEFICIARY;
import static uk.gov.hmcts.opal.event.DraftCasefilePersonalDataEvent.ParticipantCategory.MINOR_CREDITOR;

class DraftCasefileDecisionServiceTest {
    private static final JsonMapper JSON = JsonMapper.builder().build();
    private static final Instant NOW = Instant.parse("2026-10-19T10:00:00.123456789Z");
    private final MaintenanceUserService users = mock(MaintenanceUserService.class);
    private final DraftCasefileRepository repository = mock(DraftCasefileRepository.class);
    private final DraftCasefileGetMapper responses = mock(DraftCasefileGetMapper.class);
    private final DraftCasefileQueuePublisher publisher = mock(DraftCasefileQueuePublisher.class);
    private final ApplicationEventPublisher events = mock(ApplicationEventPublisher.class);
    private final MaintenanceUser checker = new MaintenanceUser(123L, "BUU-2", "Synthetic Checker", "192.0.2.1");
    private final DraftCasefileService service = new DraftCasefileService(users, mock(DraftCasefileValidator.class),
        new DraftCasefileQueryValidator(), new IfMatchValidator(), repository,
        new DraftCasefileMapper(new JacksonCompatibilityConfiguration().objectMapper(),
            new DraftCasefileJsonMapper(JSON, new JacksonCompatibilityConfiguration().objectMapper())),
        mock(DraftCasefileAddResponseMapper.class), responses, mock(DraftCasefileSummaryMapper.class),
        new DraftCasefileParticipantCategoryResolver(), events, Clock.fixed(NOW, ZoneOffset.UTC), publisher);

    private DraftCasefileEntity existing;

    @BeforeEach
    void setUp() {
        existing = DraftCasefileEntity.builder().draftCasefileId(42L).businessUnitId((short) 1)
            .versionNumber(4L).submittedBy("123").submittedByName("Synthetic Submitter")
            .casefileStatus(DraftCasefileStatus.SUBMITTED).statusMessage("Old reason")
            .createdDate(LocalDateTime.of(2026, 10, 1, 12, 0)).validatedBy("BUU-OLD")
            .validatedByName("Synthetic Earlier Checker").validatedDate(LocalDateTime.of(2026, 10, 2, 12, 0))
            .casefile("{\"applicant\":{\"bank_account_details\":{\"uk_bank_details\":{}}},\"minor_creditors\":[{},{}]}")
            .casefileSnapshot("{\"escaped\":\"\\u0000\"}").accountId(99L).accountNumber("SYNTH-99")
            .timelineData("""
                [{"username":"Synthetic Earlier Checker","status":"Rejected",
                  "status_date":"2026-10-02T12:00:00Z","reason_text":"Old reason"}]
                """).build();
        when(repository.findById(42L)).thenAnswer(invocation -> Optional.of(existing));
        when(users.requireAuthorisedUser((short) 1, CHECK_VALIDATE_DRAFT_CASEFILES)).thenReturn(checker);
        when(repository.saveAndFlush(any())).thenAnswer(invocation -> {
            DraftCasefileEntity entity = invocation.getArgument(0);
            return entity.toBuilder().versionNumber(5L).build();
        });
        when(responses.toResponse(any())).thenAnswer(invocation ->
            new DraftCasefileGetResponse().casefile(JSON.readTree(existing.getCasefile())));
    }

    @ParameterizedTest
    @CsvSource({"SUBMITTED,PUBLISHING_PENDING,Approved", "SUBMITTED,REJECTED,Rejected", "SUBMITTED,DELETED,Deleted",
        "RESUBMITTED,PUBLISHING_PENDING,Approved", "RESUBMITTED,REJECTED,Rejected", "RESUBMITTED,DELETED,Deleted"})
    void decidesAndPreservesUnchangedData(DraftCasefileStatus source, CasefileStatusEnum target,
                                        String timelineStatus) {
        existing = existing.toBuilder().casefileStatus(source).build();
        boolean approved = target == CasefileStatusEnum.PUBLISHING_PENDING;
        var request = request(target);
        assertThat(service.updateDraftCasefile(42L, request, "\"4\"").version()).isEqualTo(5L);
        ArgumentCaptor<DraftCasefileEntity> captured = ArgumentCaptor.forClass(DraftCasefileEntity.class);
        verify(repository).saveAndFlush(captured.capture());
        DraftCasefileEntity saved = captured.getValue();
        assertThat(saved).usingRecursiveComparison().ignoringFields("casefileStatus", "casefileStatusDate",
            "statusMessage", "timelineData", "validatedBy", "validatedByName", "validatedDate").isEqualTo(existing);
        assertThat(saved.getCasefileStatus().name()).isEqualTo(target.name());
        assertThat(saved.getCasefileStatusDate()).isEqualTo(LocalDateTime.parse("2026-10-19T10:00:00.123456"));
        assertThat(saved.getStatusMessage()).isEqualTo(approved ? null : "Synthetic reason");
        assertThat(saved.getValidatedBy())
            .isEqualTo(approved ? checker.businessUnitUserId() : existing.getValidatedBy());
        assertThat(saved.getValidatedByName())
            .isEqualTo(approved ? checker.displayName() : existing.getValidatedByName());
        assertThat(saved.getValidatedDate())
            .isEqualTo(approved ? saved.getCasefileStatusDate() : existing.getValidatedDate());
        var timeline = JSON.readTree(saved.getTimelineData());
        assertThat(timeline.size()).isEqualTo(2);
        assertThat(timeline.get(0)).isEqualTo(JSON.readTree(existing.getTimelineData()).get(0));
        assertThat(timeline.get(1).get("status").asString()).isEqualTo(timelineStatus);
        assertThat(timeline.get(1).get("username").asString()).isEqualTo(checker.displayName());
        assertThat(timeline.get(1).has("reason_text")).isEqualTo(!approved);
        if (approved) {
            var order = inOrder(repository, publisher, events);
            order.verify(repository).saveAndFlush(any());
            order.verify(publisher).publish(42L);
            order.verify(events).publishEvent(any(DraftCasefilePersonalDataEvent.class));
        } else {
            verifyNoInteractions(publisher);
        }
        var event = ArgumentCaptor.forClass(DraftCasefilePersonalDataEvent.class);
        verify(events).publishEvent(event.capture());
        assertThat(event.getValue().participantCategories()).containsExactlyInAnyOrder(RESPONDENT,
            APPLICANT_BENEFICIARY, MINOR_CREDITOR);
    }

    @ParameterizedTest
    @EnumSource(value = DraftCasefileStatus.class, names = {"SUBMITTED", "RESUBMITTED"}, mode = EnumSource.Mode.EXCLUDE)
    void refusesOtherLifecycleStates(DraftCasefileStatus state) {
        existing = existing.toBuilder().casefileStatus(state).build();
        var approval = request(CasefileStatusEnum.PUBLISHING_PENDING);
        assertThatThrownBy(() -> service.updateDraftCasefile(42L, approval, "\"4\""))
            .isInstanceOf(ResourceConflictException.class);
        verify(repository, never()).saveAndFlush(any());
        verifyNoInteractions(publisher, events);
    }

    @Test
    void refusesSelfCheckUsingBusinessUnitIdentity() {
        existing = existing.toBuilder().submittedBy(checker.businessUnitUserId()).build();
        assertThatThrownBy(() -> service.updateDraftCasefile(42L, request(CasefileStatusEnum.REJECTED), "\"4\""))
            .isInstanceOf(AccessDeniedException.class);
        verifyNoInteractions(publisher, events);
        verify(repository, never()).saveAndFlush(any());
    }

    @Test
    void refusesWrongBusinessUnit() {
        var request = request(CasefileStatusEnum.DELETED).businessUnitId((short) 2);
        assertThatThrownBy(() -> service.updateDraftCasefile(42L, request, "\"4\""))
            .isInstanceOf(ResourceConflictException.class);
        verifyNoInteractions(publisher, events);
    }

    private DraftCasefileUpdateRequest request(CasefileStatusEnum target) {
        return new DraftCasefileUpdateRequest().businessUnitId((short) 1).casefileStatus(target)
            .statusMessage(target == CasefileStatusEnum.PUBLISHING_PENDING ? null : "Synthetic reason");
    }
}
