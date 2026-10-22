package uk.gov.hmcts.opal.service.messaging;

import jakarta.jms.DeliveryMode;
import jakarta.jms.TextMessage;
import org.apache.qpid.jms.JmsConnectionFactory;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
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
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import tools.jackson.databind.json.JsonMapper;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.logging.integration.service.LoggingService;
import uk.gov.hmcts.opal.support.DraftCasefileHttpFixture;

import java.net.ServerSocket;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.Mockito.when;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.test.context.jdbc.Sql.ExecutionPhase.AFTER_TEST_METHOD;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static uk.gov.hmcts.opal.authorisation.MaintenancePermission.CHECK_VALIDATE_DRAFT_CASEFILES;

/** Opt-in tests require an otherwise unused queue provisioned for this test run. */
@EnabledIfEnvironmentVariable(named = "RUN_SERVICE_BUS_TESTS", matches = "true")
@AutoConfigureMockMvc
@TestPropertySource(properties = {"spring.flyway.locations=classpath:db/migration/ddl", "opal.redis.enabled=false",
    "management.health.redis.enabled=false", "spring.jpa.open-in-view=false"})
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@Sql("/draft-casefile/reference-fixtures.sql")
@Sql(scripts = "/draft-casefile/reference-cleanup.sql", executionPhase = AFTER_TEST_METHOD)
class DraftCasefileQueueIntegrationTest extends BaseIntegrationTest {
    private static final JsonMapper JSON = JsonMapper.builder().build();
    @Autowired
    private MockMvc mockMvc;
    @Autowired
    private JdbcTemplate jdbc;
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
        publisher.publish(new DraftCasefileQueueMessage(900001L, 123L, "192.0.2.1"));
        assertMessage(900001L);
    }

    @Test
    void acceptedMessageSurvivesDatabaseCommitFailureWithoutAudit() throws Exception {
        String created = mockMvc.perform(post("/draft-casefiles").contentType(MediaType.APPLICATION_JSON)
            .content(DraftCasefileHttpFixture.requestBody())
            .with(authentication(DraftCasefileHttpFixture.token((short) 1))))
            .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString();
        long id = JSON.readTree(created).get("draft_casefile_id").longValue();
        jdbc.update("UPDATE draft_casefiles SET submitted_by = 'BUU-INPUTTER' WHERE draft_casefile_id = ?", id);
        final Map<String, Object> before = row(id);
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
        mockMvc.perform(patch("/draft-casefiles/{id}", id).header("If-Match", "\"0\"")
            .contentType(MediaType.APPLICATION_JSON)
            .content("{\"business_unit_id\":1,\"casefile_status\":\"PUBLISHING_PENDING\"}")
            .with(authentication(DraftCasefileHttpFixture.token((short) 1, CHECK_VALIDATE_DRAFT_CASEFILES))))
            .andExpect(status().isInternalServerError());
        assertThat(row(id)).isEqualTo(before);
        verifyNoInteractions(logging);
        assertMessage(id);
    }

    @Test
    void unavailableBrokerFailsWithinBoundedConnectionTimeout() throws Exception {
        try (ServerSocket unavailable = new ServerSocket(0)) {
            var factory = new JmsConnectionFactory("amqp://localhost:" + unavailable.getLocalPort()
                + "?jms.connectTimeout=500&jms.requestTimeout=500&jms.sendTimeout=500");
            var failed = new DraftCasefileQueuePublisherImpl(new JmsTemplate(factory), JSON, queue,
                new DraftCasefileQueueMessageValidator());
            assertThatThrownBy(() -> failed.publish(new DraftCasefileQueueMessage(900002L, 123L, "192.0.2.1")))
                .isInstanceOf(JmsException.class);
        }
    }

    private void assertMessage(long id) throws Exception {
        var message = template.receive(queue);
        assertThat(message).isInstanceOf(TextMessage.class);
        var body = JSON.readTree(((TextMessage) message).getText());
        assertThat(body.get("draft_casefile_id").longValue()).isEqualTo(id);
        assertThat(body.get("checker_user_id").longValue()).isPositive();
        assertThat(body.get("originating_ip_address").asString()).isNotBlank();
        assertThat(message.getJMSDeliveryMode()).isEqualTo(DeliveryMode.PERSISTENT);
    }

    private Map<String, Object> row(long id) {
        return jdbc.queryForMap("SELECT * FROM draft_casefiles WHERE draft_casefile_id = ?", id);
    }
}
