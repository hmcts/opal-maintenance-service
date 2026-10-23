package uk.gov.hmcts.opal.config;

import jakarta.jms.ConnectionFactory;
import lombok.extern.slf4j.Slf4j;
import org.apache.qpid.jms.JmsConnectionFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jms.annotation.EnableJms;
import org.springframework.jms.config.DefaultJmsListenerContainerFactory;
import org.springframework.jms.connection.CachingConnectionFactory;
import uk.gov.hmcts.opal.common.config.ServiceBusConnectionStringParser;
import uk.gov.hmcts.opal.common.config.ServiceBusProperties;

@EnableJms
@Configuration
@Slf4j
@ConditionalOnProperty(prefix = "opal.draft-casefile.service-bus", name = "consumer-enabled", havingValue = "true")
public class DraftCasefileQueueJmsConfig {
    @Bean
    public CachingConnectionFactory draftCasefileConsumerConnectionFactory(
        ServiceBusProperties properties, ServiceBusConnectionStringParser parser
    ) {
        var details = parser.parse(properties.getConnectionString());
        String remoteUri = "%s://%s?amqp.idleTimeout=%d".formatted(properties.getProtocol(),
            details.fullyQualifiedNamespace(), properties.getIdleTimeoutMs());
        var qpid = new JmsConnectionFactory(remoteUri);
        qpid.setUsername(details.sharedAccessKeyName());
        qpid.setPassword(details.sharedAccessKey());
        return new CachingConnectionFactory(qpid);
    }

    @Bean
    public DefaultJmsListenerContainerFactory draftCasefileListenerContainerFactory(
        @Qualifier("draftCasefileConsumerConnectionFactory") ConnectionFactory connectionFactory
    ) {
        var factory = new DefaultJmsListenerContainerFactory();
        factory.setConnectionFactory(connectionFactory);
        factory.setSessionTransacted(true);
        // Container diagnostics must not render provider exceptions or a message body.
        factory.setErrorHandler(failure ->
            log.warn("Publication delivery failed; broker settlement controls redelivery"));
        return factory;
    }
}
