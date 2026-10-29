package uk.gov.hmcts.opal.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.mapper.DraftCasefilePublicationMapper;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.exception.DraftCasefilePublicationException.Attempt;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.repository.extensions.DraftCasefilePublicationRepository;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.mockito.Mockito.doThrow;

class DraftCasefilePublicationFailureServiceTest {
    private final DraftCasefileRepository drafts = mock(DraftCasefileRepository.class);
    private final DraftCasefilePublicationRepository publication = mock(DraftCasefilePublicationRepository.class);
    private final DraftCasefilePublicationFailureService service = new DraftCasefilePublicationFailureService(
        drafts, publication, Clock.fixed(Instant.parse("2026-10-22T12:00:00Z"), ZoneOffset.UTC),
        new DraftCasefilePublicationMapper());
    private final LocalDateTime approved = LocalDateTime.of(2026, 10, 21, 12, 0);
    private final Attempt attempt = new Attempt(42L, 1L, "CHECKER", approved);
    private DraftCasefileEntity draft;

    @BeforeEach
    void setUp() {
        draft = DraftCasefileEntity.builder().draftCasefileId(42L).versionNumber(1L)
            .casefileStatus(DraftCasefileStatus.PUBLISHING_PENDING)
            .validatedBy("CHECKER").validatedDate(approved).casefileSnapshot("{}").build();
        when(drafts.findForPublicationById(42L)).thenAnswer(invocation -> Optional.of(draft));
    }

    @Test
    void recordsSameAttempt() {
        assertThat(service.markFailed(attempt, "Publication failed; contact support")).isTrue();
        assertThat(draft.getCasefileStatus()).isEqualTo(DraftCasefileStatus.PUBLISHING_FAILED);
    }

    @Test
    void doesNotOverwriteWinningPublication() {
        draft = draft.toBuilder().casefileStatus(DraftCasefileStatus.PUBLISHED)
            .accountId(123L).accountNumber("00123A").casefileSnapshot("""
                {"respondent_account":{"account_id":123,"account_number":"00123A"},
                 "applicant_account":{"account_id":124,"account_number":"00124B"},"minor_creditor_accounts":[]}
                """).build();
        assertThat(service.markFailed(attempt, "Publication failed; contact support")).isFalse();
        assertThat(draft.getCasefileStatus()).isEqualTo(DraftCasefileStatus.PUBLISHED);
    }

    @Test
    void refusesChangedAttempt() {
        draft = draft.toBuilder().versionNumber(2L).build();
        assertThatThrownBy(() -> service.markFailed(attempt, "Publication failed; contact support"))
            .isInstanceOf(IllegalStateException.class);
    }

    @Test
    void refusesPartialIdentity() {
        draft = draft.toBuilder().accountNumber("00123A").build();
        assertThatThrownBy(() -> service.markFailed(attempt, "Publication failed; contact support"))
            .isInstanceOf(IllegalStateException.class);
    }

    @Test
    void propagatesFailureToPersist() {
        doThrow(new IllegalStateException("Synthetic write failure")).when(drafts).flush();
        assertThatThrownBy(() -> service.markFailed(attempt, "Publication failed; contact support"))
            .isInstanceOf(IllegalStateException.class);
    }
}
