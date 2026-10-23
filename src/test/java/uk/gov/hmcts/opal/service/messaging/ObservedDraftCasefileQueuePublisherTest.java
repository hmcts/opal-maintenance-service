package uk.gov.hmcts.opal.service.messaging;

import org.junit.jupiter.api.Test;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.jms.UncategorizedJmsException;

import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.same;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.verifyNoMoreInteractions;
import static org.mockito.Mockito.when;

class ObservedDraftCasefileQueuePublisherTest {

    private static final UUID ATTEMPT = UUID.fromString("a0000000-0000-0000-0000-000000000001");
    private static final DraftCasefileQueueMessage MESSAGE =
        new DraftCasefileQueueMessage(42L, 124L, "192.0.2.1", "2024-01-02T00:00:00Z");
    private final PublicationEvidenceWriter writer = mock(PublicationEvidenceWriter.class);
    private final DraftCasefileQueuePublisherImpl delegate = mock(DraftCasefileQueuePublisherImpl.class);
    private final ObservedDraftCasefileQueuePublisher publisher =
        new ObservedDraftCasefileQueuePublisher(delegate, writer);

    @Test
    void recordsAttemptBeforeSendAndAcknowledgesAfterReturn() {
        when(writer.begin(42L)).thenReturn(Optional.of(ATTEMPT));
        publisher.publish(MESSAGE);
        var order = inOrder(writer, delegate);
        order.verify(writer).begin(42L);
        order.verify(delegate).publish(same(MESSAGE));
        order.verify(writer).acknowledge(ATTEMPT);
        verifyNoMoreInteractions(writer, delegate);
    }

    @Test
    void unregisteredSendDelegatesWithoutCompletionWrite() {
        when(writer.begin(42L)).thenReturn(Optional.empty());
        publisher.publish(MESSAGE);
        verify(writer).begin(42L);
        verify(delegate).publish(same(MESSAGE));
        verifyNoMoreInteractions(writer, delegate);
    }

    @Test
    void beginFailurePreventsSend() {
        var failure = new DataAccessResourceFailureException("Synthetic persistence failure");
        when(writer.begin(42L)).thenThrow(failure);
        assertThatThrownBy(() -> publisher.publish(MESSAGE)).isSameAs(failure);
        verifyNoInteractions(delegate);
    }

    @Test
    void preservesTransportFailureWithoutRetry() {
        when(writer.begin(42L)).thenReturn(Optional.of(ATTEMPT));
        var failure = new UncategorizedJmsException("Synthetic transport uncertainty");
        doThrow(failure).when(delegate).publish(same(MESSAGE));
        assertThatThrownBy(() -> publisher.publish(MESSAGE)).isSameAs(failure);
        var order = inOrder(writer, delegate);
        order.verify(writer).begin(42L);
        order.verify(delegate).publish(same(MESSAGE));
        order.verify(writer).markUncertain(ATTEMPT);
        verify(delegate, times(1)).publish(same(MESSAGE));
        verifyNoMoreInteractions(writer, delegate);
    }

    @Test
    void unregisteredFailurePreservesExceptionWithoutCompletionWrite() {
        when(writer.begin(42L)).thenReturn(Optional.empty());
        var failure = new UncategorizedJmsException("Synthetic transport uncertainty");
        doThrow(failure).when(delegate).publish(same(MESSAGE));
        assertThatThrownBy(() -> publisher.publish(MESSAGE)).isSameAs(failure);
        verify(writer).begin(42L);
        verify(delegate).publish(same(MESSAGE));
        verifyNoMoreInteractions(writer, delegate);
    }

    @Test
    void acknowledgmentFailurePreservesSuccessfulSendWithoutRetry() {
        when(writer.begin(42L)).thenReturn(Optional.of(ATTEMPT));
        doThrow(new DataAccessResourceFailureException("Synthetic persistence failure"))
            .when(writer).acknowledge(ATTEMPT);
        publisher.publish(MESSAGE);
        verify(delegate, times(1)).publish(same(MESSAGE));
        verify(writer).begin(42L);
        verify(writer).acknowledge(ATTEMPT);
        verifyNoMoreInteractions(writer, delegate);
    }

    @Test
    void uncertainWriteFailurePreservesTransportExceptionWithoutRetry() {
        when(writer.begin(42L)).thenReturn(Optional.of(ATTEMPT));
        var failure = new UncategorizedJmsException("Synthetic transport uncertainty");
        doThrow(failure).when(delegate).publish(same(MESSAGE));
        doThrow(new DataAccessResourceFailureException("Synthetic persistence failure"))
            .when(writer).markUncertain(ATTEMPT);
        assertThatThrownBy(() -> publisher.publish(MESSAGE)).isSameAs(failure);
        verify(delegate, times(1)).publish(same(MESSAGE));
        verify(writer).begin(42L);
        verify(writer).markUncertain(ATTEMPT);
        verifyNoMoreInteractions(writer, delegate);
    }
}
