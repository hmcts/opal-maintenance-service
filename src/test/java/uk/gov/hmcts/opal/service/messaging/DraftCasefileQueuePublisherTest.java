package uk.gov.hmcts.opal.service.messaging;

import org.junit.jupiter.api.Test;
import org.springframework.jms.UncategorizedJmsException;
import org.springframework.jms.core.JmsTemplate;
import tools.jackson.databind.json.JsonMapper;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

class DraftCasefileQueuePublisherTest {
    private final JmsTemplate template = mock(JmsTemplate.class);
    private final DraftCasefileQueuePublisher publisher = new DraftCasefileQueuePublisherImpl(
        template, JsonMapper.builder().build(), "test-publish-queue");

    @Test
    void publishesOnlyDraftId() {
        publisher.publish(42L);
        verify(template).convertAndSend("test-publish-queue", "{\"draft_casefile_id\":42}");
    }

    @Test
    void propagatesSendFailure() {
        var failure = new UncategorizedJmsException("Broker unavailable");
        doThrow(failure).when(template).convertAndSend("test-publish-queue", "{\"draft_casefile_id\":42}");
        assertThatThrownBy(() -> publisher.publish(42L)).isSameAs(failure);
    }
}
