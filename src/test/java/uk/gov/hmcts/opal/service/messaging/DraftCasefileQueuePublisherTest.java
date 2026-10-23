package uk.gov.hmcts.opal.service.messaging;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.jms.UncategorizedJmsException;
import org.springframework.jms.core.JmsTemplate;
import tools.jackson.databind.json.JsonMapper;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

class DraftCasefileQueuePublisherTest {
    private final JmsTemplate template = mock(JmsTemplate.class);
    private final DraftCasefileQueuePublisher publisher = new DraftCasefileQueuePublisherImpl(
        template, JsonMapper.builder().build(), "test-publish-queue", new DraftCasefileQueueMessageValidator());

    @Test
    void publishesAuthenticatedApprovalContext() {
        publisher.publish(new DraftCasefileQueueMessage(42L, 123L, "192.0.2.1", "2024-01-02T00:00:00Z"));
        var payload = ArgumentCaptor.forClass(String.class);
        verify(template).convertAndSend(eq("test-publish-queue"), payload.capture());
        var body = JsonMapper.builder().build().readTree(payload.getValue());
        assertThat(body.size()).isEqualTo(4);
        assertThat(body.get("draft_casefile_id").longValue()).isEqualTo(42L);
        assertThat(body.get("checker_user_id").longValue()).isEqualTo(123L);
        assertThat(body.get("approval_timestamp").asString()).isEqualTo("2024-01-02T00:00:00Z");
        assertThat(body.get("originating_ip_address").asString()).isEqualTo("192.0.2.1");
    }

    @Test
    void rejectsInvalidProducerContextBeforeSend() {
        assertThatThrownBy(() -> publisher.publish(new DraftCasefileQueueMessage(42L, 123L, null,
            "2024-01-02T00:00:00Z")))
            .isInstanceOf(IllegalArgumentException.class).hasNoCause();
        verifyNoInteractions(template);
    }

    @Test
    void propagatesSendFailure() {
        var failure = new UncategorizedJmsException("Broker unavailable");
        doThrow(failure).when(template).convertAndSend(eq("test-publish-queue"), anyString());
        assertThatThrownBy(() -> publisher.publish(new DraftCasefileQueueMessage(42L, 123L, "192.0.2.1",
            "2024-01-02T00:00:00Z")))
            .isSameAs(failure);
    }
}
