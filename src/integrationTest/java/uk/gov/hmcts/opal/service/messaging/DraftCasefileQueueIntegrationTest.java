package uk.gov.hmcts.opal.service.messaging;

import jakarta.jms.DeliveryMode;
import jakarta.jms.TextMessage;
import org.apache.qpid.jms.JmsConnectionFactory;
import org.junit.jupiter.api.BeforeEach;
import org.mockito.ArgumentCaptor;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jms.JmsException;
import org.springframework.jms.connection.CachingConnectionFactory;
import org.springframework.jms.core.JmsTemplate;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.springframework.test.context.jdbc.Sql;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import tools.jackson.databind.json.JsonMapper;
import tools.jackson.databind.node.ObjectNode;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.common.user.authorisation.model.Permission;
import uk.gov.hmcts.opal.logging.integration.service.LoggingService;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.support.DraftCasefileHttpFixture;

import java.net.ServerSocket;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.test.context.jdbc.Sql.ExecutionPhase.AFTER_TEST_METHOD;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Opt-in tests require an otherwise unused queue provisioned for this test run. */
@EnabledIfEnvironmentVariable(named = "RUN_SERVICE_BUS_TESTS", matches = "true")
@AutoConfigureMockMvc
@TestPropertySource(properties = {"spring.flyway.locations=classpath:db/migration/ddl", "opal.redis.enabled=false",
    "management.health.redis.enabled=false", "spring.jpa.open-in-view=false",
    "opal.testing-support-endpoints.enabled=true", "opal.draft-casefile.service-bus.consumer-enabled=false"})
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@Sql("/draft-casefile/reference-fixtures.sql")
@Sql(scripts = "/draft-casefile/reference-cleanup.sql", executionPhase = AFTER_TEST_METHOD)
class DraftCasefileQueueIntegrationTest extends BaseIntegrationTest {
    private static final JsonMapper JSON = JsonMapper.builder().build();
    @Autowired
    private MockMvc mockMvc;
    @Autowired
    private DraftCasefileRepository drafts;
    @Autowired
    private DraftCasefileQueuePublisher selectedPublisher;
    @MockitoSpyBean
    private DraftCasefileQueuePublisherImpl publisher;
    @MockitoBean
    private LoggingService logging;
    @Autowired
    @Qualifier("draftCasefilePublisherJmsTemplate")
    private JmsTemplate template;
    @Autowired
    @Qualifier("draftCasefilePublisherConnectionFactory")
    private CachingConnectionFactory connection;
    @Value("${opal.draft-casefile.service-bus.queue-name}")
    private String queue;

    @DynamicPropertySource
    static void queueProperties(DynamicPropertyRegistry registry) {
        registry.add("opal.draft-casefile.service-bus.queue-name", () -> {
            String name = System.getenv("TEST_SERVICEBUS_QUEUE");
            if (name == null || !name.startsWith("test-")) {
                throw new IllegalStateException("TEST_SERVICEBUS_QUEUE must name a dedicated test- queue");
            }
            return name;
        });
    }

    @BeforeEach
    void setUp() {
        // The shared parser uses the default AMQP port. A disposable emulator can expose a mapped port.
        String uri = System.getenv("TEST_SERVICEBUS_AMQP_URI");
        if (uri != null) {
            connection.resetConnection();
            ((JmsConnectionFactory) connection.getTargetConnectionFactory()).setRemoteURI(uri);
        }
        template.setReceiveTimeout(5000);
        when(logging.personalDataAccessLogAsync(any())).thenReturn(true);
    }

    @Test
    void publishesPersistentApprovalMessageToConfiguredQueue() throws Exception {
        var message = new DraftCasefileQueueMessage(900001L, 123L, "192.0.2.1", "2024-01-02T00:00:00Z");
        publisher.publish(message);
        assertMessage(message);
    }

    @Test
    void actualApprovalUsesBasePublisherAndSendsOnceToRealBroker() throws Exception {
        long id = submittedDraft();
        assertThat(selectedPublisher).isInstanceOf(DraftCasefileQueuePublisherImpl.class);
        approve(id).andExpect(status().isOk());
        assertMessage(sentMessage(id));
        approve(id).andExpect(status().isConflict());
        verify(publisher, times(1)).publish(argThat(message -> message.draftCasefileId().equals(id)));
        assertNoReplay();
    }

    @Test
    void acceptedMessageSurvivesDatabaseCommitFailureWithoutAudit() throws Exception {
        long id = submittedDraft();
        final var before = drafts.findById(id).orElseThrow();
        clearInvocations(logging);
        doAnswer(invocation -> {
            invocation.callRealMethod();
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void beforeCommit(boolean readOnly) {
                    throw new IllegalStateException("Synthetic commit failure");
                }
            });
            return null;
        }).when(publisher).publish(argThat(message -> message.draftCasefileId().equals(id)));
        approve(id).andExpect(status().isInternalServerError());
        assertThat(drafts.findById(id).orElseThrow()).usingRecursiveComparison().isEqualTo(before);
        verifyNoInteractions(logging);
        assertMessage(sentMessage(id));
        verify(publisher, times(1)).publish(argThat(message -> message.draftCasefileId().equals(id)));
        assertNoReplay();
    }

    @Test
    void unavailableBrokerFailsWithinBoundedConnectionTimeout() throws Exception {
        try (ServerSocket unavailable = new ServerSocket(0)) {
            var factory = new JmsConnectionFactory("amqp://localhost:" + unavailable.getLocalPort()
                + "?jms.connectTimeout=500&jms.requestTimeout=500&jms.sendTimeout=500");
            var failed = new DraftCasefileQueuePublisherImpl(new JmsTemplate(factory), JSON, queue,
                new DraftCasefileQueueMessageValidator());
            assertThatThrownBy(() -> failed.publish(new DraftCasefileQueueMessage(900002L, 123L, "192.0.2.1",
                "2024-01-02T00:00:00Z")))
                .isInstanceOf(JmsException.class);
        }
    }

    private DraftCasefileQueueMessage sentMessage(long id) {
        var captured = ArgumentCaptor.forClass(DraftCasefileQueueMessage.class);
        verify(publisher, times(1)).publish(captured.capture());
        assertThat(captured.getValue().draftCasefileId()).isEqualTo(id);
        assertThat(captured.getValue().checkerUserId()).isEqualTo(124L);
        return captured.getValue();
    }

    private void assertMessage(DraftCasefileQueueMessage expected) throws Exception {
        var message = template.receive(queue);
        assertThat(message).isInstanceOf(TextMessage.class);
        var body = JSON.readTree(((TextMessage) message).getText());
        assertThat(body.propertyNames()).containsExactlyInAnyOrder("draft_casefile_id", "checker_user_id",
            "originating_ip_address", "approval_timestamp");
        assertThat(body.get("draft_casefile_id").longValue()).isEqualTo(expected.draftCasefileId());
        assertThat(body.get("checker_user_id").longValue()).isEqualTo(expected.checkerUserId());
        assertThat(body.get("originating_ip_address").asString()).isEqualTo(expected.originatingIpAddress());
        assertThat(body.get("approval_timestamp").asString()).isEqualTo(expected.approvalTimestamp());
        assertThat(message.getJMSDeliveryMode()).isEqualTo(DeliveryMode.PERSISTENT);
    }

    private long submittedDraft() throws Exception {
        var body = JSON.readTree(DraftCasefileHttpFixture.requestBody());
        ((ObjectNode) body.at("/casefile/respondent_account"))
            .put("remo_reference", "E2E-0123456789abcdef");
        String created = mockMvc.perform(post("/draft-casefiles").contentType(MediaType.APPLICATION_JSON)
            .content(body.toString()).with(authentication(DraftCasefileHttpFixture.token((short) 1))))
            .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString();
        long id = JSON.readTree(created).get("draft_casefile_id").longValue();
        return id;
    }

    private ResultActions approve(long id) throws Exception {
        var checker = DraftCasefileHttpFixture.token((short) 1, 124L, "BUU-CHECKER",
            Set.of(new Permission(22L, "Check and validate draft Casefiles")));
        return mockMvc.perform(patch("/draft-casefiles/{id}", id).header("If-Match", "\"0\"")
            .header("X-User-IP", "192.0.2.1")
            .contentType(MediaType.APPLICATION_JSON)
            .content("{\"business_unit_id\":1,\"casefile_status\":\"PUBLISHING_PENDING\"}")
            .with(authentication(checker)));
    }

    private void assertNoReplay() {
        template.setReceiveTimeout(250);
        assertThat(template.receive(queue)).isNull();
    }
}
