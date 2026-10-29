package uk.gov.hmcts.opal.service.messaging;

import jakarta.jms.JMSException;
import jakarta.jms.Message;
import org.apache.qpid.jms.JmsConnectionFactory;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestReporter;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.webmvc.test.autoconfigure.MockMvcPrint;
import org.springframework.context.annotation.Import;
import org.springframework.core.io.ClassPathResource;
import org.springframework.dao.QueryTimeoutException;
import org.springframework.jdbc.datasource.init.ResourceDatabasePopulator;
import org.springframework.jms.config.DefaultJmsListenerContainerFactory;
import org.springframework.jms.config.SimpleJmsListenerEndpoint;
import org.springframework.jms.connection.CachingConnectionFactory;
import org.springframework.jms.core.JmsTemplate;
import org.springframework.jms.listener.DefaultMessageListenerContainer;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.springframework.test.context.jdbc.Sql;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import tools.jackson.databind.ObjectMapper;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.common.config.ServiceBusConnectionStringParser;
import uk.gov.hmcts.opal.common.config.ServiceBusProperties;
import uk.gov.hmcts.opal.config.DraftCasefileQueueJmsConfig;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.logging.integration.service.LoggingService;
import uk.gov.hmcts.opal.mapper.DraftCasefilePublicationMapper;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.repository.MajorCreditorRepository;
import uk.gov.hmcts.opal.repository.extensions.DraftCasefilePublicationRepository;
import uk.gov.hmcts.opal.service.DraftCasefilePublicationFailureService;
import uk.gov.hmcts.opal.support.publication.PublicationQaFixture;
import uk.gov.hmcts.opal.support.publication.PublicationQaFixture.OwnedDraft;
import uk.gov.hmcts.opal.support.publication.PublicationQaGraph;
import uk.gov.hmcts.opal.support.publication.PublicationQaGraphConfiguration;
import uk.gov.hmcts.opal.support.publication.PublicationQaSettlementContainer;
import uk.gov.hmcts.opal.support.publication.PublicationQaTransactions;
import uk.gov.hmcts.opal.validator.OpenApiSchemaValidator;

import javax.sql.DataSource;

import java.net.URI;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

import static org.awaitility.Awaitility.await;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.when;

/** Actual broker evidence requires an existing dedicated test- queue and the real database publication provider. */
@EnabledIfEnvironmentVariable(named = "RUN_SERVICE_BUS_TESTS", matches = "true")
@AutoConfigureMockMvc(print = MockMvcPrint.NONE)
@Import(PublicationQaGraphConfiguration.class)
@TestPropertySource(properties = {"spring.flyway.locations=classpath:db/migration/ddl", "opal.redis.enabled=false",
    "management.health.redis.enabled=false", "spring.jpa.open-in-view=false",
    "opal.draft-casefile.service-bus.consumer-enabled=false", "logging.level.org.apache.qpid.jms=OFF",
    "logging.level.org.springframework.jms=OFF", "logging.level.org.hibernate=OFF",
    "logging.level.uk.gov.hmcts.opal.support.publication.PublicationQaSettlementContainer=OFF"})
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@Sql({"/draft-casefile/reference-fixtures.sql", "/draft-casefile/cleanup-scope-fixtures.sql",
    "/draft-casefile/publication-qa-reference-fixtures.sql"})
class DraftCasefilePublicationBrokerQaIntegrationTest extends BaseIntegrationTest {
    @Autowired
    private DataSource dataSource;
    @Autowired
    private MockMvc mvc;
    @Autowired
    private ObjectMapper json;
    @Autowired
    private PlatformTransactionManager transactionManager;
    @Autowired
    private DraftCasefileRepository drafts;
    @Autowired
    private MajorCreditorRepository majorCreditors;
    @Autowired
    private PublicationQaGraph graph;
    @Autowired
    private DraftCasefileQueueConsumerService consumer;
    @Autowired
    private OpenApiSchemaValidator schemas;
    @Autowired
    private ServiceBusProperties properties;
    @Autowired
    private ServiceBusConnectionStringParser parser;
    @MockitoBean
    private DraftCasefileQueuePublisherImpl outbound;
    @MockitoBean
    private LoggingService logging;
    @MockitoSpyBean
    private DraftCasefilePublicationRepository publication;
    @MockitoSpyBean
    private DraftCasefilePublicationMapper mapper;
    @MockitoSpyBean
    private DraftCasefilePublicationFailureService failures;

    private final String correlation = UUID.randomUUID().toString();
    private final AtomicInteger providerAttempts = new AtomicInteger();
    private final AtomicInteger providerReturns = new AtomicInteger();
    private final AtomicInteger faultHooks = new AtomicInteger();
    private final AtomicInteger observations = new AtomicInteger();
    // Written only by the single listener; read by JUnit only after stop callback and executor termination.
    private final List<Integer> deliveryCounts = new ArrayList<>();
    private final PublicationQaTransactions transactions = new PublicationQaTransactions();
    private PublicationQaFixture fixture;
    private OwnedDraft owned;
    private DraftCasefileEntity pending;
    private DraftCasefileEntity duplicateBefore;
    private PublicationQaGraph.Snapshot duplicateGraph;
    private CachingConnectionFactory connection;
    private PublicationQaSettlementContainer container;
    private JmsTemplate template;
    private ExecutorService executor;
    private String queue;
    private int deliveryLimit;
    private Mode mode;
    private CountDownLatch stopCallback;
    private boolean joined;
    private boolean connectionDisposed;

    @BeforeEach
    void setUp() {
        queue = System.getenv("TEST_SERVICEBUS_QUEUE");
        assertTrue(queue != null && queue.matches("test-[A-Za-z0-9._-]+"),
            "TEST_SERVICEBUS_QUEUE must name an existing dedicated test- queue");
        try {
            deliveryLimit = Integer.parseInt(System.getenv("TEST_SERVICEBUS_MAX_DELIVERIES"));
        } catch (RuntimeException invalid) {
            throw new AssertionError("TEST_SERVICEBUS_MAX_DELIVERIES must be an explicit positive integer");
        }
        assertTrue(deliveryLimit > 0, "TEST_SERVICEBUS_MAX_DELIVERIES must be an explicit positive integer");
        fixture = new PublicationQaFixture(mvc, json, drafts, majorCreditors, transactionManager, graph,
            outbound, schemas);
        when(logging.personalDataAccessLogAsync(any())).thenReturn(true);
        doAnswer(invocation -> {
            transactions.observe("processing");
            providerAttempts.incrementAndGet();
            Object result = invocation.callRealMethod();
            providerReturns.incrementAndGet();
            return result;
        }).when(publication).publish(any());
        doAnswer(invocation -> {
            transactions.observe("failure");
            return invocation.callRealMethod();
        }).when(failures).markFailed(any(), any());
    }

    @AfterEach
    void cleanup(TestReporter reporter) {
        try {
            stopAndJoin();
        } finally {
            try {
                reporter.publishEntry("publication-broker-qa", "provider_attempts=" + providerAttempts.get()
                    + "; successful_returns=" + providerReturns.get() + "; post_provider_hooks=" + faultHooks.get()
                    + "; pre_commit_observations=" + observations.get()
                    + "; actual_jms_commits=" + (container == null ? 0 : container.settled())
                    + "; actual_jms_rollbacks=" + (container == null ? 0 : container.rolledBack())
                    + "; listener_joined=" + joined);
                // Never delete owned database evidence while an owned listener may still be accessing it.
                if (joined) {
                    try {
                        if (fixture != null) {
                            fixture.cleanupCaptured();
                        }
                        // Unconditional AFTER_TEST_METHOD @Sql would delete owned data even after join failure.
                        new ResourceDatabasePopulator(new ClassPathResource("draft-casefile/cleanup-scope-cleanup.sql"),
                            new ClassPathResource("draft-casefile/publication-qa-reference-cleanup.sql"))
                            .execute(dataSource);
                    } catch (RuntimeException | AssertionError failure) {
                        throw new AssertionError("Owned publication fixture cleanup failed; investigation required");
                    }
                }
            } finally {
                disposeConnection();
            }
        }
    }

    @Test
    void fullGraphIsCommittedBeforeActualJmsCommit() {
        begin(Mode.SUCCESS);
        awaitSettlement();
        stopAndJoin();
        assertCounts(1, 0, 1, 0);
        assertPublished();
        assertOwnedQueuesEmpty();
    }

    @Test
    void terminalRollbackAndDistinctFailureCommitPrecedeJmsCommit() {
        begin(Mode.TERMINAL);
        awaitSettlement();
        stopAndJoin();
        assertCounts(1, 1, 1, 0);
        transactions.assertRollbackBeforeFailureCommit();
        assertFailed();
        assertOwnedQueuesEmpty();
    }

    @Test
    void onePostProviderTransientRollsBackThenHigherDeliveryCountPublishes() {
        assertTrue(deliveryLimit >= 2, "Retry scenario requires a configured delivery limit of at least two");
        begin(Mode.TRANSIENT_ONCE);
        awaitSettlement();
        stopAndJoin();
        assertCounts(2, 2, 1, 1);
        assertPublished();
        assertOwnedQueuesEmpty();
    }

    @Test
    void databaseCommitBeforeCallbackFaultRollsBackJmsAndDuplicateCreatesOneGraph() {
        assertTrue(deliveryLimit >= 2, "Duplicate scenario requires a configured delivery limit of at least two");
        begin(Mode.CALLBACK_FAULT);
        awaitSettlement();
        stopAndJoin();
        assertCounts(1, 0, 1, 1);
        assertEquals(2, deliveryCounts.size(), "The callback fault must cause an actual broker redelivery");
        fixture.assertSameDraft(duplicateBefore, fixture.committed(owned.id()));
        graph.assertUnchanged(duplicateGraph);
        assertPublished();
        assertOwnedQueuesEmpty();
    }

    @Test
    void repeatedPostProviderTransientReachesExactDeadLetterLimitWithNoGraph() {
        begin(Mode.EXHAUSTED);
        await().atMost(Duration.ofSeconds(60)).pollInterval(Duration.ofMillis(250)).until(() -> {
            container.assertHealthy();
            Message dead = receive(queue + "/$DeadLetterQueue");
            if (dead == null) {
                return false;
            }
            try {
                assertTrue(correlation.equals(dead.getJMSCorrelationID()), "Dead letter correlation must be owned");
            } catch (JMSException failure) {
                throw new AssertionError("Owned dead letter metadata could not be read");
            }
            return true;
        });
        stopAndJoin();
        assertCounts(deliveryLimit, deliveryLimit, 0, deliveryLimit);
        assertEquals(deliveryLimit, deliveryCounts.size(), "Every configured broker delivery must be observed");
        assertPending();
        assertOwnedQueuesEmpty();
    }

    private void begin(Mode selected) {
        mode = selected;
        owned = fixture.approve(true);
        pending = fixture.committed(owned.id());
        clearInvocations(logging, failures, publication);
        if (mode == Mode.TERMINAL || mode == Mode.TRANSIENT_ONCE || mode == Mode.EXHAUSTED) {
            doAnswer(invocation -> {
                transactions.observe("processing");
                int hook = faultHooks.incrementAndGet();
                if (mode == Mode.TRANSIENT_ONCE && hook > 1) {
                    return invocation.callRealMethod();
                }
                if (mode == Mode.TERMINAL) {
                    throw new IllegalStateException("Synthetic post-provider terminal failure");
                }
                throw new QueryTimeoutException("Synthetic post-provider transient failure");
            }).when(mapper).mergePublishedAccounts(any(), any(), any());
        }
        try {
            connection = new DraftCasefileQueueJmsConfig().draftCasefileConsumerConnectionFactory(properties, parser);
            JmsConnectionFactory qpid = (JmsConnectionFactory) connection.getTargetConnectionFactory();
            String override = System.getenv("TEST_SERVICEBUS_AMQP_URI");
            if (override != null) {
                URI uri = URI.create(override);
                assertTrue(("amqp".equals(uri.getScheme()) || "amqps".equals(uri.getScheme()))
                    && uri.getHost() != null && uri.getRawUserInfo() == null
                    && uri.getRawQuery() == null && uri.getRawFragment() == null
                    && (uri.getRawPath() == null || uri.getRawPath().isEmpty()),
                    "TEST_SERVICEBUS_AMQP_URI must be a credential-free AMQP endpoint without options");
                qpid.setRemoteURI(override);
            }
            qpid.setConnectTimeout(5_000);
            qpid.setRequestTimeout(5_000);
            qpid.setSendTimeout(5_000);
            qpid.setCloseTimeout(5_000);
            template = new JmsTemplate(connection);
            template.setDeliveryPersistent(true);
            template.setReceiveTimeout(250);
            executor = Executors.newSingleThreadExecutor();
            var factory = new DefaultJmsListenerContainerFactory() {
                @Override
                protected DefaultMessageListenerContainer createContainerInstance() {
                    return new PublicationQaSettlementContainer(correlation, () -> observeBeforeCommit());
                }
            };
            factory.setConnectionFactory(connection);
            factory.setSessionTransacted(true);
            factory.setTaskExecutor(executor);
            factory.setReceiveTimeout(250L);
            factory.setErrorHandler(failure -> { });
            var endpoint = new SimpleJmsListenerEndpoint();
            endpoint.setId("publication-qa-" + correlation);
            endpoint.setDestination(queue);
            endpoint.setSelector(selector());
            endpoint.setMessageListener(this::onMessage);
            container = (PublicationQaSettlementContainer) factory.createListenerContainer(endpoint);
            container.setAcceptMessagesWhileStopping(true);
            container.afterPropertiesSet();
            container.start();
            template.convertAndSend(queue, owned.payload(), message -> {
                message.setJMSCorrelationID(correlation);
                return message;
            });
        } catch (RuntimeException failure) {
            throw new AssertionError("Dedicated publication broker setup or send failed");
        }
    }

    private void onMessage(Message message) {
        try {
            assertTrue(correlation.equals(message.getJMSCorrelationID()), "Listener must receive only owned messages");
            assertTrue(!TransactionSynchronizationManager.isActualTransactionActive()
                && !TransactionSynchronizationManager.isSynchronizationActive(),
                "JMS callback must not wrap the real service in an external database transaction");
            deliveryCounts.add(message.getIntProperty("JMSXDeliveryCount"));
            try {
                new DraftCasefileQueueListener(consumer).onMessage(message);
            } catch (RuntimeException retry) {
                assertTrue((mode == Mode.TRANSIENT_ONCE || mode == Mode.EXHAUSTED)
                    && retry.getClass() == IllegalStateException.class && retry.getCause() == null
                    && "Publication delivery requires retry".equals(retry.getMessage()),
                    "Callback failed before the expected retry stage");
                requireProvider(deliveryCounts.size(), true);
                assertPending();
                transactions.assertRolledBack("processing");
                assertEquals(0, container.settled(), "Transient attempts must not settle successfully");
                throw new PublicationQaSettlementContainer.Retry();
            }
            if (mode == Mode.CALLBACK_FAULT && deliveryCounts.size() == 1) {
                requireProvider(1, false);
                assertPublished();
                duplicateBefore = fixture.committed(owned.id());
                duplicateGraph = graph.snapshot();
                assertEquals(0, container.settled(), "Callback fault must precede any JMS commit");
                // DB committed / JMS uncommitted duplicate window; this does not claim remote acknowledgement loss.
                throw new PublicationQaSettlementContainer.Retry();
            }
        } catch (PublicationQaSettlementContainer.Retry expected) {
            throw expected;
        } catch (JMSException | RuntimeException | AssertionError unexpected) {
            container.recordFailure(PublicationQaSettlementContainer.Failure.CALLBACK);
            throw new IllegalStateException("Publication callback prerequisite failed");
        }
    }

    private void observeBeforeCommit() {
        int expected = mode == Mode.TRANSIENT_ONCE ? 2 : 1;
        requireProvider(expected, mode == Mode.TERMINAL || mode == Mode.TRANSIENT_ONCE);
        assertTrue(mode != Mode.EXHAUSTED, "Repeated transient attempts must never reach JMS commit");
        if (mode == Mode.TERMINAL) {
            transactions.assertRollbackBeforeFailureCommit();
            assertFailed();
        } else {
            assertPublished();
            if (mode == Mode.CALLBACK_FAULT) {
                assertEquals(2, deliveryCounts.size(), "First callback must roll back JMS before duplicate commit");
                fixture.assertSameDraft(duplicateBefore, fixture.committed(owned.id()));
                graph.assertUnchanged(duplicateGraph);
            }
        }
        observations.incrementAndGet();
    }

    private void awaitSettlement() {
        await().atMost(Duration.ofSeconds(45)).pollInterval(Duration.ofMillis(100)).until(() -> {
            container.assertHealthy();
            return container.settled() == 1;
        });
    }

    private void stopAndJoin() {
        if (joined) {
            return;
        }
        try {
            if (container != null) {
                if (stopCallback == null) {
                    stopCallback = new CountDownLatch(1);
                    container.stop(stopCallback::countDown);
                }
                if (!stopCallback.await(15, TimeUnit.SECONDS)) {
                    executor.shutdownNow();
                    assertTrue(executor.awaitTermination(10, TimeUnit.SECONDS)
                        && stopCallback.getCount() == 0 && container.getActiveConsumerCount() == 0,
                        "Owned publication listener did not stop completely; owned data retained");
                }
                // The stop callback confirms processing has ceased before Spring closes cached JMS resources.
                assertEquals(0, container.getActiveConsumerCount(), "Owned publication consumer is still active");
                container.shutdown();
            }
            if (executor != null) {
                executor.shutdown();
                if (!executor.awaitTermination(15, TimeUnit.SECONDS)) {
                    executor.shutdownNow();
                    assertTrue(executor.awaitTermination(10, TimeUnit.SECONDS),
                        "Owned publication listener executor did not terminate; owned data retained");
                }
            }
            joined = true;
        } catch (InterruptedException interrupted) {
            Thread.currentThread().interrupt();
            throw new AssertionError("Interrupted while joining owned publication listener; owned data retained");
        } catch (RuntimeException failure) {
            throw new AssertionError("Owned publication listener teardown failed; owned data retained");
        }
    }

    private void disposeConnection() {
        // Queue inspections follow stopAndJoin; closing earlier lets JmsTemplate reopen an unowned connection.
        if (joined && connection != null && !connectionDisposed) {
            try {
                connection.destroy();
                connectionDisposed = true;
            } catch (RuntimeException failure) {
                throw new AssertionError("Owned publication broker transport disposal failed");
            }
        }
    }

    private void assertCounts(int providers, int hooks, int commits, int rollbacks) {
        container.assertHealthy();
        requireProvider(providers, hooks > 0);
        assertEquals(hooks, faultHooks.get(), "Post-provider fault stage count differs");
        assertEquals(commits, observations.get(), "Each successful JMS commit requires a complete prior oracle");
        assertEquals(commits, container.settled(), "Count only successfully returned actual JMS commits");
        assertEquals(rollbacks, container.rolledBack(), "Expected actual JMS rollback count differs");
        int deliveries = mode == Mode.CALLBACK_FAULT ? 2 : providers;
        assertEquals(deliveries, deliveryCounts.size(), "Unexpected number of broker deliveries");
        for (int index = 0; index < deliveryCounts.size(); index++) {
            assertEquals(index + 1, deliveryCounts.get(index), "Broker delivery count must advance on redelivery");
        }
    }

    private void requireProvider(int expected, boolean faultRequired) {
        assertEquals(expected, providerAttempts.get(), "Real provider attempt prerequisite not reached");
        assertEquals(expected, providerReturns.get(), "Real provider successful-return prerequisite not reached");
        if (faultRequired) {
            assertEquals(expected, faultHooks.get(), "Post-provider fault hook prerequisite not reached");
        }
    }

    private void assertPublished() {
        DraftCasefileEntity published = fixture.committed(owned.id());
        assertEquals(DraftCasefileStatus.PUBLISHED, published.getCasefileStatus(),
            "Publication must be independently committed before JMS settlement");
        transactions.assertCommitted("processing");
        graph.assertPublished(owned.graphBefore(), published, owned.approved().get("casefile"));
        assertApproval(published);
    }

    private void assertFailed() {
        DraftCasefileEntity failed = fixture.committed(owned.id());
        assertEquals(DraftCasefileStatus.PUBLISHING_FAILED, failed.getCasefileStatus());
        assertEquals("Publication failed; contact support", failed.getStatusMessage());
        assertTrue(failed.getAccountId() == null && failed.getAccountNumber() == null
            && Objects.equals(pending.getCasefileSnapshot(), failed.getCasefileSnapshot()),
            "Terminal rollback must preserve the approved snapshot without live account identities");
        graph.assertUnchanged(owned.graphBefore());
        assertApproval(failed);
    }

    private void assertApproval(DraftCasefileEntity actual) {
        assertTrue(Objects.equals(pending.getCasefile(), actual.getCasefile())
            && Objects.equals(pending.getTimelineData(), actual.getTimelineData())
            && Objects.equals(pending.getValidatedBy(), actual.getValidatedBy())
            && Objects.equals(pending.getValidatedByName(), actual.getValidatedByName())
            && Objects.equals(pending.getValidatedDate(), actual.getValidatedDate()),
            "Publication must preserve the original approval and exact history");
    }

    private void assertPending() {
        fixture.assertSameDraft(pending, fixture.committed(owned.id()));
        graph.assertUnchanged(owned.graphBefore());
    }

    private void assertOwnedQueuesEmpty() {
        assertTrue(receive(queue) == null, "Owned main-queue delivery remains after verified settlement or DLQ");
        assertTrue(receive(queue + "/$DeadLetterQueue") == null, "Unexpected owned dead-letter delivery remains");
    }

    private Message receive(String destination) {
        try {
            return template.receiveSelected(destination, selector());
        } catch (RuntimeException failure) {
            throw new AssertionError("Owned publication broker receive failed");
        }
    }

    private String selector() {
        return "JMSCorrelationID='" + correlation + "'";
    }

    private enum Mode { SUCCESS, TERMINAL, TRANSIENT_ONCE, CALLBACK_FAULT, EXHAUSTED }
}
