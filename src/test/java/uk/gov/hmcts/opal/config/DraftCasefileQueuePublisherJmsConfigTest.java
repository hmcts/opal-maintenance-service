package uk.gov.hmcts.opal.config;

import jakarta.jms.DeliveryMode;
import org.junit.jupiter.api.Test;
import org.apache.qpid.jms.JmsConnectionFactory;
import uk.gov.hmcts.opal.common.config.ServiceBusConnectionStringParser;
import uk.gov.hmcts.opal.common.config.ServiceBusProperties;

import static org.assertj.core.api.Assertions.assertThat;

class DraftCasefileQueuePublisherJmsConfigTest {
    @Test
    void usesPersistentDeliveryAndSharedConnectionSettings() {
        var properties = new ServiceBusProperties();
        properties.setConnectionString("Endpoint=sb://localhost/;SharedAccessKeyName=test;SharedAccessKey=test");
        properties.setProtocol("amqp");
        properties.setSendTimeoutMs(1234);
        properties.setIdleTimeoutMs(5678);
        var config = new DraftCasefileQueuePublisherJmsConfig();
        var connection = config.draftCasefilePublisherConnectionFactory(
            properties, new ServiceBusConnectionStringParser(properties));
        try {
            var factory = (JmsConnectionFactory) connection.getTargetConnectionFactory();
            assertThat(factory.getRemoteURI()).contains("amqp://localhost",
                "amqp.idleTimeout=5678");
            assertThat(factory.getSendTimeout()).isEqualTo(1234);
            var template = config.draftCasefilePublisherJmsTemplate(connection);
            assertThat(template.getDeliveryMode()).isEqualTo(DeliveryMode.PERSISTENT);
            assertThat(template.isExplicitQosEnabled()).isTrue();
        } finally {
            connection.destroy();
        }
    }
}
