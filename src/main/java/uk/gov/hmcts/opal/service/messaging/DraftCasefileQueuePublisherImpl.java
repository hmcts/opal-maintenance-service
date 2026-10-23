package uk.gov.hmcts.opal.service.messaging;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jms.core.JmsTemplate;
import org.springframework.stereotype.Component;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.ObjectMapper;

@Component
public class DraftCasefileQueuePublisherImpl implements DraftCasefileQueuePublisher {
    private final JmsTemplate jmsTemplate;
    private final ObjectMapper objectMapper;
    private final String queueName;

    public DraftCasefileQueuePublisherImpl(
        @Qualifier("draftCasefilePublisherJmsTemplate") JmsTemplate jmsTemplate,
        ObjectMapper objectMapper,
        @Value("${opal.draft-casefile.service-bus.queue-name}") String queueName
    ) {
        this.jmsTemplate = jmsTemplate;
        this.objectMapper = objectMapper;
        this.queueName = queueName;
    }

    @Override
    public void publish(Long draftCasefileId) {
        final String payload;
        try {
            payload = objectMapper.writeValueAsString(new DraftCasefileQueueMessage(draftCasefileId));
        } catch (JacksonException exception) {
            throw new IllegalStateException("Unable to serialize publication message");
        }
        jmsTemplate.convertAndSend(queueName, payload);
    }
}
