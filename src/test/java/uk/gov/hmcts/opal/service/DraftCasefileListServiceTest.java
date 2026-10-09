package uk.gov.hmcts.opal.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.mockito.InOrder;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.data.projection.SpelAwareProxyProjectionFactory;
import org.springframework.security.access.AccessDeniedException;
import uk.gov.hmcts.opal.authorisation.MaintenanceUser;
import uk.gov.hmcts.opal.authorisation.MaintenanceUserService;
import uk.gov.hmcts.opal.dto.DraftCasefileFilter;
import uk.gov.hmcts.opal.common.exception.OpalApiException;
import uk.gov.hmcts.opal.event.DraftCasefileListPersonalDataEvent;
import uk.gov.hmcts.opal.event.DraftCasefilePersonalDataEvent.ParticipantCategory;
import uk.gov.hmcts.opal.generated.model.CasefileSnapshot;
import uk.gov.hmcts.opal.generated.model.CasefileSnapshotMinorCreditorAccount;
import uk.gov.hmcts.opal.generated.model.DraftCasefileSummary;
import uk.gov.hmcts.opal.logging.DraftCasefileParticipantCategoryResolver;
import uk.gov.hmcts.opal.mapper.DraftCasefileAddResponseMapper;
import uk.gov.hmcts.opal.mapper.DraftCasefileGetMapper;
import uk.gov.hmcts.opal.mapper.DraftCasefileMapper;
import uk.gov.hmcts.opal.mapper.DraftCasefileSummaryMapper;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.repository.DraftCasefileSummaryProjection;
import uk.gov.hmcts.opal.validator.DraftCasefileValidator;
import uk.gov.hmcts.opal.validator.DraftCasefileQueryValidator;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static uk.gov.hmcts.opal.authorisation.MaintenancePermission.CHECK_VALIDATE_DRAFT_CASEFILES;
import static uk.gov.hmcts.opal.authorisation.MaintenancePermission.CREATE_MANAGE_DRAFT_CASEFILES;

class DraftCasefileListServiceTest {
    private final MaintenanceUserService users = mock(MaintenanceUserService.class);
    private final DraftCasefileRepository repository = mock(DraftCasefileRepository.class);
    private final DraftCasefileSummaryMapper summaryMapper = mock(DraftCasefileSummaryMapper.class);
    private final ApplicationEventPublisher events = mock(ApplicationEventPublisher.class);
    private final Clock clock = mock(Clock.class);
    private final MaintenanceUser user = new MaintenanceUser(99L, "BUU-1", "Synthetic User", "192.0.2.1");
    private final DraftCasefileFilter filter =
        new DraftCasefileFilter((short) 31021, null, null, List.of(), null, null);
    private final DraftCasefileService service = new DraftCasefileService(
        users, mock(DraftCasefileValidator.class), new DraftCasefileQueryValidator(), repository,
        mock(DraftCasefileMapper.class),
        mock(DraftCasefileAddResponseMapper.class), mock(DraftCasefileGetMapper.class), summaryMapper,
        new DraftCasefileParticipantCategoryResolver(),
        events, clock);

    @BeforeEach
    void authorise() {
        when(users.requireAuthorisedUser((short) 31021,
            CREATE_MANAGE_DRAFT_CASEFILES, CHECK_VALIDATE_DRAFT_CASEFILES)).thenReturn(user);
    }

    @Test
    void invalidQueryDoesNotAuthoriseQueryOrPublish() {
        assertThatThrownBy(() -> service.listDraftCasefiles(
            (short) 31021, null, null, null, null, null, "unsupported"))
            .isInstanceOf(OpalApiException.class);
        verifyNoInteractions(users, repository, summaryMapper, events, clock);
    }

    @Test
    void countAuthorisesFirstAndDoesNotReadMapOrPublishSummaries() {
        when(repository.countMatching(filter)).thenReturn(7L);
        var response = service.listDraftCasefiles((short) 31021, null, null, null, null, null, "counts");
        assertThat(response.getCount()).isEqualTo(7L);
        assertThat(response.getSummaries()).isNull();
        InOrder order = inOrder(users, repository);
        order.verify(users).requireAuthorisedUser((short) 31021,
            CREATE_MANAGE_DRAFT_CASEFILES, CHECK_VALIDATE_DRAFT_CASEFILES);
        order.verify(repository).countMatching(filter);
        verify(repository, never()).findSummaries(any(DraftCasefileFilter.class));
        verifyNoInteractions(summaryMapper, events, clock);
    }

    @Test
    void deniedBusinessUnitDoesNotQueryMapOrPublish() {
        when(users.requireAuthorisedUser((short) 31021,
            CREATE_MANAGE_DRAFT_CASEFILES, CHECK_VALIDATE_DRAFT_CASEFILES))
            .thenThrow(new AccessDeniedException("Denied"));
        assertThatThrownBy(() -> service.listDraftCasefiles((short) 31021, null, null, null, null, null, null))
            .isInstanceOf(AccessDeniedException.class);
        assertThatThrownBy(() -> service.listDraftCasefiles((short) 31021, null, null, null, null, null, "counts"))
            .isInstanceOf(AccessDeniedException.class);
        verifyNoInteractions(repository, summaryMapper, events, clock);
    }

    @Test
    void emptyNormalResultContainsEmptyListAndPublishesNoEvent() {
        when(repository.findSummaries(filter)).thenReturn(List.of());
        var response = service.listDraftCasefiles((short) 31021, null, null, null, null, null, null);
        assertThat(response.getCount()).isZero();
        assertThat(response.getSummaries()).isEmpty();
        verify(repository, never()).countMatching(any(DraftCasefileFilter.class));
        verifyNoInteractions(summaryMapper, events, clock);
    }

    @Test
    void mapsAllSummariesBeforeCapturingInstantAndPublishingGroupedMetadata() {
        var first = row(123L);
        var second = row(456L);
        when(repository.findSummaries(filter)).thenReturn(List.of(first, second, second));
        var firstSummary = summary(123L, false);
        var secondSummary = summary(456L, true);
        when(summaryMapper.toSummary(first)).thenReturn(firstSummary);
        when(summaryMapper.toSummary(second)).thenReturn(secondSummary);
        when(clock.instant()).thenReturn(Instant.EPOCH);
        var response = service.listDraftCasefiles((short) 31021, null, null, null, null, null, null);
        assertThat(response.getCount()).isEqualTo(3L);
        assertThat(response.getSummaries()).containsExactly(firstSummary, secondSummary, secondSummary);
        var event = ArgumentCaptor.forClass(DraftCasefileListPersonalDataEvent.class);
        InOrder order = inOrder(users, repository, summaryMapper, clock, events);
        order.verify(users).requireAuthorisedUser((short) 31021,
            CREATE_MANAGE_DRAFT_CASEFILES, CHECK_VALIDATE_DRAFT_CASEFILES);
        order.verify(repository).findSummaries(filter);
        order.verify(summaryMapper).toSummary(first);
        order.verify(summaryMapper, org.mockito.Mockito.times(2)).toSummary(second);
        order.verify(clock).instant();
        order.verify(events).publishEvent(event.capture());
        assertThat(event.getValue().draftIdsByCategory()).containsExactlyInAnyOrderEntriesOf(Map.of(
            ParticipantCategory.RESPONDENT, List.of(123L, 456L),
            ParticipantCategory.APPLICANT_BENEFICIARY, List.of(123L, 456L),
            ParticipantCategory.MINOR_CREDITOR, List.of(456L)));
        assertThat(event.getValue().userId()).isEqualTo(99L);
        assertThat(event.getValue().ipAddress()).isEqualTo("192.0.2.1");
        assertThat(event.getValue().occurredAt()).isEqualTo(Instant.EPOCH);
        verify(repository, never()).countMatching(any(DraftCasefileFilter.class));
    }

    @Test
    void repositoryOrPartialMappingFailureDoesNotPublish() {
        when(repository.countMatching(filter)).thenThrow(new DataAccessResourceFailureException("Unavailable"));
        assertThatThrownBy(() -> service.listDraftCasefiles((short) 31021, null, null, null, null, null, "counts"))
            .isInstanceOf(DataAccessResourceFailureException.class);
        when(repository.findSummaries(filter)).thenThrow(new DataAccessResourceFailureException("Unavailable"));
        assertThatThrownBy(() -> service.listDraftCasefiles((short) 31021, null, null, null, null, null, null))
            .isInstanceOf(DataAccessResourceFailureException.class);
        var first = row(123L);
        var second = row(456L);
        org.mockito.Mockito.doReturn(List.of(first, second)).when(repository).findSummaries(filter);
        when(summaryMapper.toSummary(first)).thenReturn(summary(123L, false));
        when(summaryMapper.toSummary(second)).thenThrow(new IllegalStateException("Unreadable snapshot"));
        assertThatThrownBy(() -> service.listDraftCasefiles((short) 31021, null, null, null, null, null, null))
            .isInstanceOf(IllegalStateException.class);
        verifyNoInteractions(events, clock);
    }

    private static DraftCasefileSummaryProjection row(long id) {
        return new SpelAwareProxyProjectionFactory().createProjection(
            DraftCasefileSummaryProjection.class, Map.of("draftCasefileId", id));
    }

    private static DraftCasefileSummary summary(long id, boolean minors) {
        return new DraftCasefileSummary().draftCasefileId(id).casefileSnapshot(
            new CasefileSnapshot().minorCreditorAccounts(minors
                ? List.of(new CasefileSnapshotMinorCreditorAccount(), new CasefileSnapshotMinorCreditorAccount())
                : List.of()));
    }
}
