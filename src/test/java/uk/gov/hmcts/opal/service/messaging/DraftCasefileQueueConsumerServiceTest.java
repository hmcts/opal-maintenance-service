package uk.gov.hmcts.opal.service.messaging;

import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.junit.jupiter.api.Test;
import org.springframework.dao.QueryTimeoutException;
import uk.gov.hmcts.opal.exception.DraftCasefilePublicationException;
import uk.gov.hmcts.opal.exception.DraftCasefilePublicationException.Attempt;
import uk.gov.hmcts.opal.service.DraftCasefilePublicationFailureService;

import java.time.LocalDateTime;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class DraftCasefileQueueConsumerServiceTest {
    private final DraftCasefileQueueProcessingService processing = mock(DraftCasefileQueueProcessingService.class);
    private final DraftCasefilePublicationFailureService failures = mock(DraftCasefilePublicationFailureService.class);
    private final SimpleMeterRegistry metrics = new SimpleMeterRegistry();
    private final DraftCasefileQueueConsumerService consumer = new DraftCasefileQueueConsumerService(
        new DraftCasefileQueueMessageValidator(), processing, new TransientFailureHelper(), failures, metrics);
    private final Attempt attempt = new Attempt(42L, 1L, "CHECKER", LocalDateTime.of(2026, 10, 22, 12, 0));
    private final String payload = "{\"draft_casefile_id\":42,\"checker_user_id\":123,"
        + "\"originating_ip_address\":\"192.0.2.1\"}";

    @Test
    void acknowledgesDuplicateNoOp() {
        when(processing.processPendingDraft(any())).thenReturn(DraftCasefileQueueProcessingService.Outcome.NO_OP);
        consumer.consume(payload);
        verifyNoInteractions(failures);
        assertThat(metrics.get("opal.draft.casefile.publication").tag("outcome", "noop").counter().count())
            .isEqualTo(1);
    }

    @Test
    void rethrowsFinesRecognisedTransientFailures() {
        when(processing.processPendingDraft(any())).thenThrow(new DraftCasefilePublicationException(attempt,
            new QueryTimeoutException("SYNTHETIC_PRIVATE")));
        assertThatThrownBy(() -> consumer.consume(payload)).hasMessage("Publication delivery requires retry")
            .hasNoCause();
        verifyNoInteractions(failures);
    }

    @Test
    void recordsOtherProcessingFailures() {
        when(processing.processPendingDraft(any())).thenThrow(new DraftCasefilePublicationException(attempt,
            new IllegalStateException("SYNTHETIC_PRIVATE")));
        when(failures.markFailed(eq(attempt), any())).thenReturn(true);
        consumer.consume(payload);
        verify(failures).markFailed(attempt, "Publication failed; contact support");
    }

    @Test
    void rethrowsFailurePersistenceErrors() {
        when(processing.processPendingDraft(any())).thenThrow(new DraftCasefilePublicationException(attempt,
            new IllegalStateException("SYNTHETIC_PRIVATE")));
        when(failures.markFailed(eq(attempt), any())).thenThrow(new IllegalStateException("SYNTHETIC_PRIVATE"));
        assertThatThrownBy(() -> consumer.consume(payload)).hasNoCause()
            .hasMessage("Publication delivery requires retry");
    }

    @Test
    void doesNotInventAttemptForCommitFailure() {
        when(processing.processPendingDraft(any())).thenThrow(new IllegalStateException("SYNTHETIC_PRIVATE"));
        assertThatThrownBy(() -> consumer.consume(payload)).hasNoCause();
        verifyNoInteractions(failures);
    }

    @Test
    void malformedPayloadDoesNotExposeSourceOrWriteFailure() {
        assertThatThrownBy(() -> consumer.consume("SYNTHETIC_PRIVATE 192.0.2.1"))
            .hasMessage("Invalid publication message").hasNoCause();
        verifyNoInteractions(failures, processing);
    }
}
