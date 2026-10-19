package uk.gov.hmcts.opal.config;

import jakarta.jms.ConnectionFactory;
import org.apache.qpid.jms.JmsConnectionFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jms.connection.CachingConnectionFactory;
import org.springframework.jms.core.JmsTemplate;
import uk.gov.hmcts.opal.common.config.ServiceBusConnectionStringParser;
import uk.gov.hmcts.opal.common.config.ServiceBusProperties;

@Configuration
public class DraftCasefileQueuePublisherJmsConfig {

    @Bean
    public CachingConnectionFactory draftCasefilePublisherConnectionFactory(
        ServiceBusProperties properties, ServiceBusConnectionStringParser parser
    ) {
        var details = parser.parse(properties.getConnectionString());
        JmsConnectionFactory factory = new JmsConnectionFactory(parser.toRemoteUri(properties, details));
        factory.setUsername(details.sharedAccessKeyName());
        factory.setPassword(details.sharedAccessKey());
        CachingConnectionFactory connection = new CachingConnectionFactory(factory);
        connection.setCacheProducers(true);
        connection.setReconnectOnException(true);
        return connection;
    }

    @Bean
    public JmsTemplate draftCasefilePublisherJmsTemplate(
        @Qualifier("draftCasefilePublisherConnectionFactory") ConnectionFactory connectionFactory
    ) {
        JmsTemplate template = new JmsTemplate(connectionFactory);
        template.setDeliveryPersistent(true);
        template.setExplicitQosEnabled(true);
        return template;
    }
}
