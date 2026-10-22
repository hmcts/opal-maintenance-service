package uk.gov.hmcts.opal.config;

import ch.qos.logback.classic.Logger;
import ch.qos.logback.classic.spi.ILoggingEvent;
import ch.qos.logback.core.read.ListAppender;
import jakarta.jms.ConnectionFactory;
import org.apache.qpid.jms.JmsConnectionFactory;
import org.apache.qpid.jms.policy.JmsDefaultPrefetchPolicy;
import org.junit.jupiter.api.Test;
import org.slf4j.LoggerFactory;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.util.ErrorHandler;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.jms.config.SimpleJmsListenerEndpoint;
import uk.gov.hmcts.opal.common.config.ServiceBusConnectionStringParser;
import uk.gov.hmcts.opal.common.config.ServiceBusProperties;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

class DraftCasefileQueueJmsConfigTest {
    @Test
    void consumerDisabledByDefault() {
        new ApplicationContextRunner().withUserConfiguration(DraftCasefileQueueJmsConfig.class)
            .run(context -> assertThat(context).doesNotHaveBean("draftCasefileListenerContainerFactory"));
    }

    @Test
    void enabledConfigurationRegistersExactlyOneConsumerFactory() {
        var properties = new ServiceBusProperties();
        properties.setConnectionString("Endpoint=sb://localhost/;SharedAccessKeyName=test;SharedAccessKey=test");
        new ApplicationContextRunner().withUserConfiguration(DraftCasefileQueueJmsConfig.class)
            .withBean(ServiceBusProperties.class, () -> properties)
            .withBean(ServiceBusConnectionStringParser.class, () -> new ServiceBusConnectionStringParser(properties))
            .withPropertyValues("opal.draft-casefile.service-bus.consumer-enabled=true")
            .run(context -> assertThat(context).hasSingleBean(
                org.springframework.jms.config.DefaultJmsListenerContainerFactory.class));
    }

    @Test
    void containerErrorHandlerNeverRendersSensitiveCause() {
        var factory = new DraftCasefileQueueJmsConfig()
            .draftCasefileListenerContainerFactory(mock(ConnectionFactory.class));
        var endpoint = new SimpleJmsListenerEndpoint();
        endpoint.setId("safe-error-test");
        endpoint.setDestination("test-publication");
        endpoint.setMessageListener(message -> { });
        var container = factory.createListenerContainer(endpoint);
        var handler = (ErrorHandler) ReflectionTestUtils.getField(container, "errorHandler");
        var logger = (Logger) LoggerFactory.getLogger(DraftCasefileQueueJmsConfig.class);
        var captured = new ListAppender<ILoggingEvent>();
        captured.start();
        logger.addAppender(captured);
        try {
            handler.handleError(new IllegalStateException("SYNTHETIC_PRIVATE 192.0.2.1"));
            assertThat(captured.list).isNotEmpty().allSatisfy(event -> {
                assertThat(event.getFormattedMessage()).doesNotContain("SYNTHETIC_PRIVATE", "192.0.2.1");
                assertThat(event.getThrowableProxy()).isNull();
            });
        } finally {
            logger.detachAppender(captured);
        }
    }

    @Test
    void usesFinesDefaultsAndTransactedSettlement() {
        var config = new DraftCasefileQueueJmsConfig();
        var properties = new ServiceBusProperties();
        properties.setConnectionString("Endpoint=sb://localhost/;SharedAccessKeyName=test;SharedAccessKey=test");
        properties.setProtocol("amqp");
        properties.setIdleTimeoutMs(5678);
        var connection = config.draftCasefileConsumerConnectionFactory(properties,
            new ServiceBusConnectionStringParser(properties));
        try {
            var target = (JmsConnectionFactory) connection.getTargetConnectionFactory();
            assertThat(target.getRemoteURI()).isEqualTo("amqp://localhost?amqp.idleTimeout=5678");
            assertThat(((JmsDefaultPrefetchPolicy) target.getPrefetchPolicy()).getQueuePrefetch())
                .isEqualTo(new JmsDefaultPrefetchPolicy().getQueuePrefetch());
            var factory = config.draftCasefileListenerContainerFactory(mock(ConnectionFactory.class));
            var endpoint = new SimpleJmsListenerEndpoint();
            endpoint.setId("publication-test");
            endpoint.setDestination("test-publication");
            endpoint.setMessageListener(message -> { });
            var container = factory.createListenerContainer(endpoint);
            assertThat(container.isSessionTransacted()).isTrue();
            assertThat(container.getConcurrentConsumers()).isEqualTo(1);
        } finally {
            connection.destroy();
        }
    }
}
