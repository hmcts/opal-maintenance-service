package uk.gov.hmcts.opal.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.web.server.ResponseStatusException;
import uk.gov.hmcts.opal.authorisation.MaintenanceUser;
import uk.gov.hmcts.opal.authorisation.MaintenanceUserService;
import uk.gov.hmcts.opal.common.exception.OpalApiException;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.mapper.TestingSupportDraftCasefileMapper;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.testing.DraftCasefileTestMarker;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static uk.gov.hmcts.opal.authorisation.MaintenancePermission.CREATE_MANAGE_DRAFT_CASEFILES;

class TestingSupportDraftCasefileServiceTest {

    private static final String MARKER = "PO10287-550e8400-e29b-41d4-a716-446655440000";
    private final MaintenanceUserService users = mock(MaintenanceUserService.class);
    private final DraftCasefileRepository repository = mock(DraftCasefileRepository.class);
    private final TestingSupportDraftCasefileMapper mapper =
        new TestingSupportDraftCasefileMapper(new ObjectMapper().findAndRegisterModules());
    private final TestingSupportDraftCasefileService service =
        new TestingSupportDraftCasefileService(users, repository, mapper, new DraftCasefileTestMarker());
    private final MaintenanceUser user = new MaintenanceUser(99L, "L044JG", "Synthetic User", null);

    @BeforeEach
    void setUp() {
        when(users.requireAuthorisedUser((short) 44, CREATE_MANAGE_DRAFT_CASEFILES)).thenReturn(user);
    }

    @Test
    void ownerCanInspectTechnicalMetadata() {
        when(repository.findById(123L)).thenReturn(Optional.of(entity()));
        var metadata = service.inspect(123L);
        assertThat(metadata.draftCasefileId()).isEqualTo(123L);
        assertThat(metadata.submittedBy()).isEqualTo("L044JG");
        assertThat(metadata.timelineStatuses()).containsExactly("Submitted");
        var order = inOrder(users, repository);
        order.verify(users).requireAuthorisedUser((short) 44, CREATE_MANAGE_DRAFT_CASEFILES);
        order.verify(repository).findById(123L);
    }

    @Test
    void authorisesBeforeRejectingInvalidLookupMarker() {
        assertThatThrownBy(() -> service.findByMarker("PO10287-%"))
            .isInstanceOf(OpalApiException.class);
        verify(users).requireAuthorisedUser((short) 44, CREATE_MANAGE_DRAFT_CASEFILES);
        verifyNoInteractions(repository);
    }

    @Test
    void lookupUsesBusinessUnitAndAuthenticatedBui() {
        when(repository.findTestingSupportIdsByMarker((short) 44, "L044JG", MARKER))
            .thenReturn(List.of(12L, 23L));
        var matches = service.findByMarker(MARKER);
        assertThat(matches.count()).isEqualTo(2);
        assertThat(matches.draftCasefileIds()).containsExactly(12L, 23L);
        assertThatThrownBy(() -> matches.draftCasefileIds().add(34L))
            .isInstanceOf(UnsupportedOperationException.class);
        verify(repository).findTestingSupportIdsByMarker((short) 44, "L044JG", MARKER);
    }

    @Test
    void absentRecordIsHidden() {
        assertNotFound(() -> service.inspect(123L));
    }

    @Test
    void differentBusinessUnitIsHidden() {
        when(repository.findById(123L)).thenReturn(Optional.of(entity().toBuilder()
            .businessUnitId((short) 43).build()));
        assertNotFound(() -> service.inspect(123L));
    }

    @Test
    void differentCreatorIsHidden() {
        when(repository.findById(123L)).thenReturn(Optional.of(entity().toBuilder()
            .submittedBy("OTHER").build()));
        assertNotFound(() -> service.inspect(123L));
    }

    @Test
    void unmarkedRecordIsHidden() {
        when(repository.findById(123L)).thenReturn(Optional.of(entity().toBuilder()
            .casefile("{\"respondent_account\":{\"account_comment\":\"ordinary\"}}").build()));
        assertNotFound(() -> service.inspect(123L));
    }

    @Test
    void missingPermissionStopsBeforeReadingData() {
        when(users.requireAuthorisedUser((short) 44, CREATE_MANAGE_DRAFT_CASEFILES))
            .thenThrow(new AccessDeniedException("Permission required"));
        assertThatThrownBy(() -> service.inspect(123L)).isInstanceOf(AccessDeniedException.class);
        assertThatThrownBy(() -> service.findByMarker(MARKER)).isInstanceOf(AccessDeniedException.class);
        assertThatThrownBy(() -> service.delete(123L)).isInstanceOf(AccessDeniedException.class);
        verifyNoInteractions(repository);
    }

    @Test
    void eligibleDeleteDeletesAndFlushes() {
        DraftCasefileEntity entity = entity();
        when(repository.findById(123L)).thenReturn(Optional.of(entity));
        service.delete(123L);
        var order = inOrder(repository);
        order.verify(repository).findById(123L);
        order.verify(repository).delete(entity);
        order.verify(repository).flush();
    }

    @Test
    void ineligibleDeleteNeverMutates() {
        when(repository.findById(123L)).thenReturn(Optional.of(entity().toBuilder().submittedBy("OTHER").build()));
        assertNotFound(() -> service.delete(123L));
        verify(repository, never()).delete(org.mockito.ArgumentMatchers.any());
        verify(repository, never()).flush();
    }

    private void assertNotFound(Runnable operation) {
        assertThatThrownBy(operation::run).isInstanceOf(ResponseStatusException.class)
            .satisfies(exception -> assertThat(((ResponseStatusException) exception).getStatusCode())
                .isEqualTo(HttpStatus.NOT_FOUND));
    }

    private static DraftCasefileEntity entity() {
        LocalDateTime created = LocalDateTime.of(2026, 10, 16, 10, 11);
        return DraftCasefileEntity.builder()
            .draftCasefileId(123L).businessUnitId((short) 44).submittedBy("L044JG")
            .submittedByName("Synthetic User").createdDate(created).casefileStatus(DraftCasefileStatus.SUBMITTED)
            .casefileStatusDate(created).versionNumber(0L)
            .casefile("{\"respondent_account\":{\"account_comment\":\"" + MARKER + "\"}}")
            .casefileSnapshot("null").timelineData("[{\"status\":\"Submitted\"}]").build();
    }
}
