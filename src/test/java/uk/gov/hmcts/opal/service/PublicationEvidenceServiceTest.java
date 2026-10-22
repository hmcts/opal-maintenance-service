package uk.gov.hmcts.opal.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.persistence.EntityNotFoundException;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.springframework.security.access.AccessDeniedException;
import uk.gov.hmcts.opal.common.exception.OpalApiException;
import uk.gov.hmcts.opal.dto.PublicationEvidenceCounts;
import uk.gov.hmcts.opal.dto.PublicationObservation;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.exception.DraftCasefileError;
import uk.gov.hmcts.opal.exception.ResourceConflictException;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.repository.PublicationEvidenceRepository;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

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

class PublicationEvidenceServiceTest {

    private static final String RUN = "E2E-0123456789abcdef";
    private static final UUID OBSERVATION = UUID.fromString("b0000000-0000-0000-0000-000000000001");
    private static final Instant REGISTERED = Instant.parse("2026-10-22T10:00:00Z");
    private final DraftCasefileRepository drafts = mock(DraftCasefileRepository.class);
    private final DraftCasefileTestScope scope = mock(DraftCasefileTestScope.class);
    private final PublicationEvidenceRepository evidence = mock(PublicationEvidenceRepository.class);
    private final PublicationEvidenceService service = new PublicationEvidenceService(drafts, scope,
        new DraftCasefileTestEligibility(new ObjectMapper()), evidence);

    @ParameterizedTest
    @EnumSource(value = DraftCasefileStatus.class, names = {"SUBMITTED", "REJECTED", "RESUBMITTED"})
    void registersEligibleDraftUnderLock(DraftCasefileStatus status) {
        DraftCasefileEntity draft = draft(status);
        when(drafts.findForCleanupById(42L)).thenReturn(Optional.of(draft));
        when(evidence.register(42L, RUN)).thenReturn(observation(RUN));
        when(evidence.counts(OBSERVATION)).thenReturn(new PublicationEvidenceCounts(0, 0, 0, 0));
        var registered = service.register(42L, RUN);
        assertThat(registered.created()).isTrue();
        assertThat(registered.evidence().getObservationId()).isEqualTo(OBSERVATION);
        assertThat(registered.evidence().getRegisteredAt().toInstant()).isEqualTo(REGISTERED);
        assertThat(registered.evidence().getEvidenceComplete()).isTrue();
        var order = inOrder(drafts, scope, evidence);
        order.verify(drafts).findForCleanupById(42L);
        order.verify(scope).requireOwnedRun(draft, RUN);
        order.verify(evidence).findObservation(42L);
        order.verify(evidence).register(42L, RUN);
    }

    @Test
    void repeatAfterApprovalPreservesObservationAndAllCounts() {
        when(drafts.findForCleanupById(42L)).thenReturn(Optional.of(draft(DraftCasefileStatus.PUBLISHING_PENDING)));
        when(evidence.findObservation(42L)).thenReturn(Optional.of(observation(RUN)));
        when(evidence.counts(OBSERVATION)).thenReturn(new PublicationEvidenceCounts(6, 3, 2, 1));
        var result = service.register(42L, RUN);
        assertThat(result.created()).isFalse();
        assertThat(result.evidence().getObservationId()).isEqualTo(OBSERVATION);
        assertThat(result.evidence().getRegisteredAt().toInstant()).isEqualTo(REGISTERED);
        assertThat(result.evidence().getSendAttemptCount()).isEqualTo(6L);
        assertThat(result.evidence().getAcknowledgedSendCount()).isEqualTo(3L);
        assertThat(result.evidence().getUncertainSendCount()).isEqualTo(2L);
        assertThat(result.evidence().getUnfinishedSendCount()).isEqualTo(1L);
        assertThat(result.evidence().getEvidenceComplete()).isFalse();
        verify(evidence, never()).register(any(), any());
    }

    @ParameterizedTest
    @EnumSource(value = DraftCasefileStatus.class,
        names = {"DELETED", "PUBLISHING_FAILED", "PUBLISHING_PENDING", "PUBLISHED"})
    void rejectsFirstRegistrationOutsideEligibleLifecycle(DraftCasefileStatus status) {
        when(drafts.findForCleanupById(42L)).thenReturn(Optional.of(draft(status)));
        assertThatThrownBy(() -> service.register(42L, RUN)).isInstanceOf(ResourceConflictException.class);
        verify(evidence, never()).register(any(), any());
    }

    @Test
    void rejectsMissingLifecycleAndLinkedRow() {
        when(drafts.findForCleanupById(42L)).thenReturn(Optional.of(draft(null)));
        assertThatThrownBy(() -> service.register(42L, RUN)).isInstanceOf(ResourceConflictException.class);
        when(drafts.findForCleanupById(42L)).thenReturn(Optional.of(
            draft(DraftCasefileStatus.SUBMITTED).toBuilder().accountId(101L).build()));
        assertThatThrownBy(() -> service.register(42L, RUN)).isInstanceOf(ResourceConflictException.class);
        verify(evidence, never()).register(any(), any());
    }

    @Test
    void rejectsLinkedSnapshotEvenWhenRowIsUnlinked() {
        var draft = draft(DraftCasefileStatus.SUBMITTED).toBuilder()
            .casefileSnapshot("""
                {"respondent_account":{"account_id":1,"account_number":null},
                 "applicant_account":{"account_id":null,"account_number":null},"minor_creditor_accounts":[]}
                """).build();
        when(drafts.findForCleanupById(42L)).thenReturn(Optional.of(draft));
        assertThatThrownBy(() -> service.register(42L, RUN)).isInstanceOf(ResourceConflictException.class);
        verify(evidence, never()).register(any(), any());
    }

    @Test
    void ownershipFailureDoesNotReadOrMutateJournal() {
        var draft = draft(DraftCasefileStatus.SUBMITTED);
        when(drafts.findForCleanupById(42L)).thenReturn(Optional.of(draft));
        doThrow(new AccessDeniedException("Denied")).when(scope).requireOwnedRun(draft, RUN);
        assertThatThrownBy(() -> service.register(42L, RUN)).isInstanceOf(AccessDeniedException.class);
        verifyNoInteractions(evidence);
    }

    @Test
    void readOwnershipFailureDoesNotAccessJournal() {
        var draft = draft(DraftCasefileStatus.SUBMITTED);
        when(drafts.findById(42L)).thenReturn(Optional.of(draft));
        doThrow(new AccessDeniedException("Denied")).when(scope).requireOwnedRun(draft, RUN);
        assertThatThrownBy(() -> service.read(42L, RUN)).isInstanceOf(AccessDeniedException.class);
        verifyNoInteractions(evidence);
    }

    @Test
    void readChecksCurrentDraftBeforeUsingJournal() {
        var draft = draft(DraftCasefileStatus.SUBMITTED);
        when(drafts.findById(42L)).thenReturn(Optional.of(draft));
        when(evidence.findObservation(42L)).thenReturn(Optional.of(observation(RUN)));
        when(evidence.counts(OBSERVATION)).thenReturn(new PublicationEvidenceCounts(1, 1, 0, 0));
        assertThat(service.read(42L, RUN).getAcknowledgedSendCount()).isEqualTo(1L);
        var order = inOrder(drafts, scope, evidence);
        order.verify(drafts).findById(42L);
        order.verify(scope).requireOwnedRun(draft, RUN);
        order.verify(evidence).findObservation(42L);
        order.verify(evidence).counts(OBSERVATION);
    }

    @Test
    void missingDraftRejectsReadAndRegistrationWithoutOrphanAccess() {
        assertThatThrownBy(() -> service.register(42L, RUN)).isInstanceOf(EntityNotFoundException.class);
        assertThatThrownBy(() -> service.read(42L, RUN)).isInstanceOf(EntityNotFoundException.class);
        verifyNoInteractions(scope, evidence);
    }

    @Test
    void unregisteredReadReturnsSpecificConflict() {
        when(drafts.findById(42L)).thenReturn(Optional.of(draft(DraftCasefileStatus.SUBMITTED)));
        var error = catchThrowableOfType(OpalApiException.class, () -> service.read(42L, RUN));
        assertThat(error.getError()).isEqualTo(DraftCasefileError.PUBLICATION_EVIDENCE_NOT_REGISTERED);
        assertThat(error.getError().getErrorTypeNumeric()).isEqualTo("003");
    }

    @Test
    void observationMarkerMismatchRejectsBothOperations() {
        var draft = draft(DraftCasefileStatus.SUBMITTED);
        when(drafts.findById(42L)).thenReturn(Optional.of(draft));
        when(drafts.findForCleanupById(42L)).thenReturn(Optional.of(draft));
        when(evidence.findObservation(42L)).thenReturn(Optional.of(observation("E2E-fedcba9876543210")));
        assertThatThrownBy(() -> service.read(42L, RUN)).isInstanceOf(AccessDeniedException.class);
        assertThatThrownBy(() -> service.register(42L, RUN)).isInstanceOf(AccessDeniedException.class);
        verify(evidence, never()).counts(any());
        verify(evidence, never()).register(any(), any());
    }

    private static PublicationObservation observation(String marker) {
        return new PublicationObservation(OBSERVATION, 42L, marker, REGISTERED);
    }

    private static DraftCasefileEntity draft(DraftCasefileStatus status) {
        return DraftCasefileEntity.builder().draftCasefileId(42L).businessUnitId((short) 1)
            .casefileStatus(status).casefileSnapshot("""
                {"respondent_account":{"account_id":null,"account_number":null},
                 "applicant_account":{"account_id":null,"account_number":null},"minor_creditor_accounts":[]}
                """).build();
    }
}
