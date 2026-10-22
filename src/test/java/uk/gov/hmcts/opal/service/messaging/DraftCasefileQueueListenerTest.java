package uk.gov.hmcts.opal.service.messaging;

import jakarta.jms.JMSException;
import jakarta.jms.Message;
import jakarta.jms.TextMessage;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class DraftCasefileQueueListenerTest {
    private final DraftCasefileQueueConsumerService consumer = mock(DraftCasefileQueueConsumerService.class);
    private final DraftCasefileQueueListener listener = new DraftCasefileQueueListener(consumer);

    @Test
    void delegatesTextMessage() throws JMSException {
        var message = mock(TextMessage.class);
        when(message.getText()).thenReturn("{}");
        listener.onMessage(message);
        verify(consumer).consume("{}");
    }

    @Test
    void rejectsNonTextMessage() {
        assertThatThrownBy(() -> listener.onMessage(mock(Message.class)))
            .isInstanceOf(IllegalArgumentException.class).hasNoCause();
    }

    @Test
    void removesSensitiveTransportDiagnostic() throws JMSException {
        var message = mock(TextMessage.class);
        when(message.getText()).thenThrow(new JMSException("SYNTHETIC_PRIVATE 192.0.2.1"));
        assertThatThrownBy(() -> listener.onMessage(message))
            .hasMessage("Unable to read publication delivery").hasNoCause();
    }
}
