package uk.gov.hmcts.opal.service.messaging;

import jakarta.jms.JMSException;
import jakarta.jms.Message;
import org.apache.qpid.jms.JmsConnectionFactory;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.QueryTimeoutException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jms.config.SimpleJmsListenerEndpoint;
import org.springframework.jms.connection.CachingConnectionFactory;
import org.springframework.jms.core.JmsTemplate;
import org.springframework.jms.listener.DefaultMessageListenerContainer;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.springframework.test.context.jdbc.Sql;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.common.config.ServiceBusConnectionStringParser;
import uk.gov.hmcts.opal.common.config.ServiceBusProperties;
import uk.gov.hmcts.opal.config.DraftCasefileQueueJmsConfig;
import uk.gov.hmcts.opal.exception.DraftCasefilePublicationException;
import uk.gov.hmcts.opal.exception.DraftCasefilePublicationException.Attempt;
import uk.gov.hmcts.opal.logging.integration.service.LoggingService;
import uk.gov.hmcts.opal.service.DraftCasefilePublicationFailureService;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;

import static org.assertj.core.api.Assertions.assertThat;
import static org.awaitility.Awaitility.await;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.when;
import static org.springframework.test.context.jdbc.Sql.ExecutionPhase.AFTER_TEST_METHOD;

/** Requires an otherwise unused test- queue, with its provisioned delivery limit supplied explicitly. */
@EnabledIfEnvironmentVariable(named = "RUN_SERVICE_BUS_TESTS", matches = "true")
@TestPropertySource(properties = {"opal.redis.enabled=false", "management.health.redis.enabled=false",
    "spring.jpa.open-in-view=false", "opal.draft-casefile.service-bus.consumer-enabled=false",
    "opal.testing-support-endpoints.enabled=true"})
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@Sql("/draft-casefile/publication-fixtures.sql")
@Sql(scripts = "/draft-casefile/publication-cleanup.sql", executionPhase = AFTER_TEST_METHOD)
class DraftCasefileQueueConsumerIntegrationTest extends BaseIntegrationTest {
    @Autowired
    private DraftCasefileQueueConsumerService consumer;
    @Autowired
    private JdbcTemplate jdbc;
    @Autowired
    private ServiceBusProperties properties;
    @Autowired
    private ServiceBusConnectionStringParser parser;
    @MockitoSpyBean
    private DraftCasefileQueueProcessingService processing;
    @MockitoSpyBean
    private DraftCasefilePublicationFailureService failures;
    @MockitoBean
    private LoggingService logging;
    private CachingConnectionFactory connection;
    private DefaultMessageListenerContainer container;
    private JmsTemplate template;
    private String queue;
    private final String correlation = UUID.randomUUID().toString();
    private final AtomicInteger deliveries = new AtomicInteger();
    private final AtomicInteger completedDeliveries = new AtomicInteger();
    private final AtomicInteger brokerDeliveryCount = new AtomicInteger();
    private volatile boolean failAcknowledgement;
    private static final String PAYLOAD = """
        {"draft_casefile_id":1062901,"checker_user_id":123,"originating_ip_address":"192.0.2.1",
         "approval_timestamp":"2024-01-02T00:00:00Z"}
        """;

    @BeforeEach
    void startIsolatedListener() {
        queue = System.getenv("TEST_SERVICEBUS_QUEUE");
        if (queue == null || !queue.startsWith("test-")) {
            throw new IllegalStateException("TEST_SERVICEBUS_QUEUE must name a dedicated test- queue");
        }
        var config = new DraftCasefileQueueJmsConfig();
        connection = config.draftCasefileConsumerConnectionFactory(properties, parser);
        String uri = System.getenv("TEST_SERVICEBUS_AMQP_URI");
        if (uri != null) {
            ((JmsConnectionFactory) connection.getTargetConnectionFactory()).setRemoteURI(uri);
        }
        template = new JmsTemplate(connection);
        template.setDeliveryPersistent(true);
        template.setReceiveTimeout(250);
        var listener = new DraftCasefileQueueListener(consumer);
        var endpoint = new SimpleJmsListenerEndpoint();
        endpoint.setId("publication-settlement-test");
        endpoint.setDestination(queue);
        endpoint.setSelector(selector());
        endpoint.setMessageListener(message -> {
            int delivery = deliveries.incrementAndGet();
            try {
                brokerDeliveryCount.accumulateAndGet(message.getIntProperty("JMSXDeliveryCount"), Math::max);
                assertThat(TransactionSynchronizationManager.isActualTransactionActive()).isFalse();
                assertThat(TransactionSynchronizationManager.isSynchronizationActive()).isFalse();
                listener.onMessage(message);
                completedDeliveries.incrementAndGet();
            } catch (JMSException exception) {
                throw new IllegalStateException("Synthetic listener transport failure");
            }
            if (failAcknowledgement && delivery == 1) {
                throw new IllegalStateException("Synthetic lost acknowledgement");
            }
        });
        container = config.draftCasefileListenerContainerFactory(connection).createListenerContainer(endpoint);
        container.afterPropertiesSet();
        container.start();
        when(logging.personalDataAccessLogAsync(any())).thenReturn(true);
    }

    @AfterEach
    void stopOwnedListener() {
        if (container != null) {
            container.shutdown();
        }
        if (connection != null) {
            connection.destroy();
        }
    }

    @Test
    void missingDraftDeliveriesSettleThroughGuardWithoutAmbientSpringTransaction() {
        String missing = "{\"draft_casefile_id\":9223372036854775807}";
        send(missing);
        await().atMost(Duration.ofSeconds(45)).untilAsserted(() -> assertThat(completedDeliveries).hasValue(1));
        send(missing);
        await().atMost(Duration.ofSeconds(45)).untilAsserted(() -> assertThat(completedDeliveries).hasValue(2));
        assertSettled();
        verify(processing, times(2)).processPendingDraft(argThat(message ->
            message.draftCasefileId().equals(Long.MAX_VALUE)));
        verifyNoInteractions(failures, logging);
    }

    @Test
    void normalCompletionSettlesDelivery() {
        send(PAYLOAD);
        await().atMost(Duration.ofSeconds(45)).untilAsserted(() -> assertThat(status()).isEqualTo("PUBLISHED"));
        assertSettled();
    }

    @Test
    void transientFailureRedeliversAndPublishes() {
        var attempts = new AtomicInteger();
        doAnswer(invocation -> {
            if (attempts.incrementAndGet() == 1) {
                throw new DraftCasefilePublicationException(attempt(), new QueryTimeoutException("Synthetic timeout"));
            }
            return invocation.callRealMethod();
        }).when(processing).processPendingDraft(any());
        send(PAYLOAD);
        await().atMost(Duration.ofSeconds(45)).untilAsserted(() -> assertThat(status()).isEqualTo("PUBLISHED"));
        assertThat(deliveries.get()).isGreaterThanOrEqualTo(2);
        assertSettled();
    }

    @Test
    void committedPublicationSurvivesLostAcknowledgement() {
        failAcknowledgement = true;
        send(PAYLOAD);
        await().atMost(Duration.ofSeconds(45))
            .untilAsserted(() -> assertThat(deliveries.get()).isGreaterThanOrEqualTo(2));
        assertSettled();
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM respondent_accounts WHERE business_unit_id=32055",
            Long.class)).isEqualTo(1L);
    }

    @Test
    void failedFailurePersistenceRedeliversThenSettlesTerminalOutcome() {
        jdbc.update("UPDATE draft_casefiles SET validated_by=submitted_by WHERE draft_casefile_id=1062901");
        var attempts = new AtomicInteger();
        doAnswer(invocation -> {
            if (attempts.incrementAndGet() == 1) {
                throw new IllegalStateException("Synthetic failure persistence outage");
            }
            return invocation.callRealMethod();
        }).when(failures).markFailed(any(), any());
        send(PAYLOAD);
        await().atMost(Duration.ofSeconds(45)).untilAsserted(() -> assertThat(status()).isEqualTo("PUBLISHING_FAILED"));
        assertThat(deliveries.get()).isGreaterThanOrEqualTo(2);
        assertSettled();
    }

    @Test
    void invalidLegacyMessageReachesConfiguredDeadLetterLimit() {
        int expectedLimit = Integer.parseInt(System.getenv("TEST_SERVICEBUS_MAX_DELIVERIES"));
        assertThat(expectedLimit).isPositive();
        send("{\"draft_casefile_id\":1062901}");
        var deadLetter = new AtomicReference<Message>();
        await().atMost(Duration.ofSeconds(60)).until(() -> {
            deadLetter.set(template.receiveSelected(queue + "/$DeadLetterQueue", selector()));
            return deadLetter.get() != null;
        });
        assertThat(brokerDeliveryCount.get()).isEqualTo(expectedLimit);
        assertThat(status()).isEqualTo("PUBLISHING_PENDING");
    }

    private void send(String body) {
        template.convertAndSend(queue, body, message -> {
            message.setJMSCorrelationID(correlation);
            return message;
        });
    }

    private void assertSettled() {
        container.shutdown();
        assertThat(template.receiveSelected(queue, selector())).isNull();
    }

    private String selector() {
        return "JMSCorrelationID='" + correlation + "'";
    }

    private String status() {
        return jdbc.queryForObject("SELECT casefile_status::text FROM draft_casefiles WHERE draft_casefile_id=1062901",
            String.class);
    }

    private Attempt attempt() {
        return new Attempt(1062901L, 1L, "P55_APPROVE", LocalDateTime.of(2024, 1, 2, 0, 0));
    }
}
