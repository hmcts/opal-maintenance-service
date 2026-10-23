package uk.gov.hmcts.opal.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.junit.jupiter.params.provider.MethodSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.AccessDeniedException;
import uk.gov.hmcts.opal.authorisation.MaintenanceUser;
import uk.gov.hmcts.opal.authorisation.MaintenanceUserService;
import uk.gov.hmcts.opal.common.exception.OpalApiException;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.exception.DraftCasefileError;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;

import java.time.LocalDateTime;
import java.util.Optional;
import java.util.stream.Stream;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.catchThrowableOfType;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static uk.gov.hmcts.opal.authorisation.MaintenancePermission.CREATE_MANAGE_DRAFT_CASEFILES;

class DraftCasefileCleanupServiceTest {

    private static final String RUN = "E2E-0123456789abcdef";
    private static final String EMPTY_ACCOUNT = "{\"account_id\":null,\"account_number\":null}";
    private final MaintenanceUserService users = mock(MaintenanceUserService.class);
    private final DraftCasefileRepository repository = mock(DraftCasefileRepository.class);
    private final DraftCasefileCleanupService service = new DraftCasefileCleanupService(
        users, repository, new ObjectMapper());

    @BeforeEach
    void authoriseAutomation() {
        when(users.requireAuthorisedUser((short) 1, CREATE_MANAGE_DRAFT_CASEFILES))
            .thenReturn(new MaintenanceUser(123L, "BUU-1", "Synthetic Automation", "192.0.2.1"));
    }

    @Test
    void deletesOwnedMarkedSubmittedDraft() {
        DraftCasefileEntity draft = ownedDraft();
        found(draft);
        service.cleanup(41L, RUN);
        var ordered = inOrder(users, repository);
        ordered.verify(repository).findForCleanupById(41L);
        ordered.verify(users).requireAuthorisedUser((short) 1, CREATE_MANAGE_DRAFT_CASEFILES);
        ordered.verify(repository).delete(draft);
        ordered.verify(repository).flush();
    }

    @Test
    void absentDraftSucceedsWithoutAnOwnerToCheck() {
        when(repository.findForCleanupById(41L)).thenReturn(Optional.empty());
        service.cleanup(41L, RUN);
        verifyNoInteractions(users);
        assertNoDeletion();
    }

    @Test
    void rejectsDifferentStoredSubmitter() {
        found(ownedDraft().toBuilder().submittedBy("BUU-OTHER").build());
        assertDenied();
    }

    @Test
    void missingPermissionRejectsWithoutDeletion() {
        found(ownedDraft());
        AccessDeniedException failure = new AccessDeniedException("Permission is required");
        when(users.requireAuthorisedUser((short) 1, CREATE_MANAGE_DRAFT_CASEFILES)).thenThrow(failure);
        assertThatThrownBy(() -> service.cleanup(41L, RUN)).isSameAs(failure);
        assertNoDeletion();
    }

    @Test
    void checksPermissionInTheStoredBusinessUnit() {
        found(ownedDraft().toBuilder().businessUnitId((short) 2).build());
        AccessDeniedException failure = new AccessDeniedException("No identity for requested Business Unit");
        when(users.requireAuthorisedUser((short) 2, CREATE_MANAGE_DRAFT_CASEFILES)).thenThrow(failure);
        assertThatThrownBy(() -> service.cleanup(41L, RUN)).isSameAs(failure);
        verify(users, never()).requireAuthorisedUser((short) 1, CREATE_MANAGE_DRAFT_CASEFILES);
        assertNoDeletion();
    }

    @Test
    void anotherUserCanCleanTheirOwnDraftInAnotherBusinessUnit() {
        DraftCasefileEntity draft = ownedDraft().toBuilder().businessUnitId((short) 2).submittedBy("BUU-2").build();
        found(draft);
        when(users.requireAuthorisedUser((short) 2, CREATE_MANAGE_DRAFT_CASEFILES))
            .thenReturn(new MaintenanceUser(124L, "BUU-2", "Synthetic Submitter", "192.0.2.1"));
        service.cleanup(41L, RUN);
        verify(repository).delete(draft);
        verify(repository).flush();
    }

    @ParameterizedTest
    @ValueSource(strings = {
        "{\"respondent_account\":{\"remo_reference\":\"E2E-other\"}}",
        "{\"respondent_account\":{}}", "{}", "null", "[]", "",
        "{\"respondent_account\":{\"remo_reference\":null}}",
        "{\"respondent_account\":{\"remo_reference\":123}}",
        "{\"respondent_account\":{\"remo_reference\":true}}",
        "{\"respondent_account\":{\"remo_reference\":[]}}",
        "{\"respondent_account\":{\"remo_reference\":{}}}", "{malformed"
    })
    void rejectsMissingDifferentNonTextOrMalformedRunMarker(String casefile) {
        found(ownedDraft().toBuilder().casefile(casefile).build());
        assertDenied();
    }

    @ParameterizedTest
    @EnumSource(value = DraftCasefileStatus.class, names = "SUBMITTED", mode = EnumSource.Mode.EXCLUDE)
    void rejectsOtherLifecycleStates(DraftCasefileStatus status) {
        found(ownedDraft().toBuilder().casefileStatus(status).build());
        assertConflict();
    }

    @Test
    void rejectsMissingLifecycleState() {
        found(ownedDraft().toBuilder().casefileStatus(null).build());
        assertConflict();
    }

    @ParameterizedTest
    @MethodSource("publicationFields")
    void rejectsRowWithAccountOrValidationMetadata(DraftCasefileEntity draft) {
        found(draft);
        assertConflict();
    }

    @ParameterizedTest
    @MethodSource("unsafeSnapshots")
    void rejectsLinkedAccountsOrInvalidSnapshotStructure(String snapshot) {
        found(ownedDraft().toBuilder().casefileSnapshot(snapshot).build());
        assertConflict();
    }

    @Test
    void acceptsUnlinkedMinorAccounts() {
        DraftCasefileEntity draft = ownedDraft().toBuilder()
            .casefileSnapshot(snapshot(EMPTY_ACCOUNT, EMPTY_ACCOUNT, "[" + EMPTY_ACCOUNT + "]")).build();
        found(draft);
        service.cleanup(41L, RUN);
        verify(repository).delete(draft);
        verify(repository).flush();
    }

    @Test
    void lockedReadFailurePropagatesUnchanged() {
        DataAccessResourceFailureException failure = new DataAccessResourceFailureException("Unavailable");
        when(repository.findForCleanupById(41L)).thenThrow(failure);
        assertThatThrownBy(() -> service.cleanup(41L, RUN)).isSameAs(failure);
        assertNoDeletion();
    }

    @Test
    void flushFailurePropagatesUnchanged() {
        DraftCasefileEntity draft = ownedDraft();
        found(draft);
        DataAccessResourceFailureException failure = new DataAccessResourceFailureException("Unavailable");
        doThrow(failure).when(repository).flush();
        assertThatThrownBy(() -> service.cleanup(41L, RUN)).isSameAs(failure);
        verify(repository).delete(draft);
    }

    private void found(DraftCasefileEntity draft) {
        when(repository.findForCleanupById(41L)).thenReturn(Optional.of(draft));
    }

    private void assertDenied() {
        assertThatThrownBy(() -> service.cleanup(41L, RUN)).isInstanceOf(AccessDeniedException.class)
            .hasMessage("Draft Casefile test cleanup is not permitted");
        assertNoDeletion();
    }

    private void assertConflict() {
        OpalApiException exception = catchThrowableOfType(OpalApiException.class, () -> service.cleanup(41L, RUN));
        assertThat(exception).isNotNull();
        assertThat(exception.getError()).isEqualTo(DraftCasefileError.CLEANUP_NOT_ELIGIBLE);
        assertThat(exception.getError().getHttpStatus()).isEqualTo(HttpStatus.CONFLICT);
        assertThat(exception.getError().getErrorTypePrefix()).isEqualTo("DRAFT_CASEFILE");
        assertThat(exception.getError().getErrorTypeNumeric()).isEqualTo("002");
        assertThat(exception.getError().getTitle()).isEqualTo("Draft Casefile is not eligible for test cleanup");
        assertThat(exception.getDetail()).isEqualTo("Draft Casefile is not eligible for test cleanup");
        assertNoDeletion();
    }

    private void assertNoDeletion() {
        verify(repository, never()).delete(any(DraftCasefileEntity.class));
        verify(repository, never()).flush();
    }

    private static Stream<DraftCasefileEntity> publicationFields() {
        return Stream.of(
            ownedDraft().toBuilder().accountId(10L).build(),
            ownedDraft().toBuilder().accountNumber("SYNTHETIC").build(),
            ownedDraft().toBuilder().validatedDate(LocalDateTime.of(2026, 10, 1, 12, 0)).build(),
            ownedDraft().toBuilder().validatedBy("BUU-1").build(),
            ownedDraft().toBuilder().validatedByName("Synthetic Automation").build());
    }

    private static Stream<String> unsafeSnapshots() {
        Stream<String> invalidAccounts = Stream.of(
            "{\"account_id\":10,\"account_number\":null}",
            "{\"account_id\":null,\"account_number\":\"SYNTHETIC\"}",
            "{\"account_id\":null}", "{\"account_number\":null}", "null", "[]");
        Stream<String> accountSnapshots = invalidAccounts.flatMap(account -> Stream.of(
            snapshot(account, EMPTY_ACCOUNT, "[]"),
            snapshot(EMPTY_ACCOUNT, account, "[]"),
            snapshot(EMPTY_ACCOUNT, EMPTY_ACCOUNT, "[" + EMPTY_ACCOUNT + "," + account + "]")));
        return Stream.concat(accountSnapshots, Stream.of(
            "{malformed", "null", "[]", "", "{}",
            "{\"applicant_account\":" + EMPTY_ACCOUNT + ",\"minor_creditor_accounts\":[]}",
            "{\"respondent_account\":" + EMPTY_ACCOUNT + ",\"minor_creditor_accounts\":[]}",
            "{\"respondent_account\":" + EMPTY_ACCOUNT + ",\"applicant_account\":" + EMPTY_ACCOUNT + "}",
            snapshot(EMPTY_ACCOUNT, EMPTY_ACCOUNT, "null"),
            snapshot(EMPTY_ACCOUNT, EMPTY_ACCOUNT, "{}")));
    }

    private static String snapshot(String respondent, String applicant, String minors) {
        return "{\"respondent_account\":" + respondent + ",\"applicant_account\":" + applicant
            + ",\"minor_creditor_accounts\":" + minors + "}";
    }

    private static DraftCasefileEntity ownedDraft() {
        return DraftCasefileEntity.builder().draftCasefileId(41L).businessUnitId((short) 1)
            .submittedBy("BUU-1").casefileStatus(DraftCasefileStatus.SUBMITTED)
            .casefile("{\"respondent_account\":{\"remo_reference\":\"" + RUN + "\"}}")
            .casefileSnapshot("""
                {"respondent_account":{"account_id":null,"account_number":null},
                 "applicant_account":{"account_id":null,"account_number":null},"minor_creditor_accounts":[]}
                """)
            .build();
    }
}
