package uk.gov.hmcts.opal.service.messaging;

import jakarta.jms.JMSException;
import jakarta.jms.Message;
import jakarta.jms.TextMessage;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.jms.annotation.JmsListener;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
@ConditionalOnProperty(prefix = "opal.draft-casefile.service-bus", name = "consumer-enabled", havingValue = "true")
public class DraftCasefileQueueListener {
    private final DraftCasefileQueueConsumerService consumer;

    @JmsListener(destination = "${opal.draft-casefile.service-bus.queue-name}",
        containerFactory = "draftCasefileListenerContainerFactory")
    public void onMessage(Message message) throws JMSException {
        if (!(message instanceof TextMessage textMessage)) {
            throw new IllegalArgumentException("Publication message must be a TextMessage");
        }
        final String payload;
        try {
            payload = textMessage.getText();
        } catch (JMSException exception) {
            throw new IllegalStateException("Unable to read publication delivery");
        }
        consumer.consume(payload);
    }
}
