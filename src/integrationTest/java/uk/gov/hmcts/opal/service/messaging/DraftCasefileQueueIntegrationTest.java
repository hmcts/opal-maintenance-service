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
import uk.gov.hmcts.opal.repository.PublicationEvidenceRepository;
import uk.gov.hmcts.opal.support.DraftCasefileHttpFixture;

import java.net.ServerSocket;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
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
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Opt-in tests require an otherwise unused queue provisioned for this test run. */
@EnabledIfEnvironmentVariable(named = "RUN_SERVICE_BUS_TESTS", matches = "true")
@AutoConfigureMockMvc
@TestPropertySource(properties = {"spring.flyway.locations=classpath:db/migration/ddl", "opal.redis.enabled=false",
    "management.health.redis.enabled=false", "spring.jpa.open-in-view=false",
    "opal.testing-support-endpoints.enabled=true"})
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
    private PublicationEvidenceRepository evidence;
    @Autowired
    private DraftCasefileQueuePublisher observed;
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
    void publishesPersistentIdOnlyMessageToConfiguredQueue() throws Exception {
        publisher.publish(900001L);
        assertMessage(900001L);
    }

    @Test
    void actualApprovalUsesObservedPublisherAndAcknowledgesRealBrokerSend() throws Exception {
        long id = registeredDraft();
        assertThat(observed).isInstanceOf(ObservedDraftCasefileQueuePublisher.class);
        approve(id).andExpect(status().isOk());
        assertMessage(id);
        assertAcknowledged(id);
        approve(id).andExpect(status().isConflict());
        assertAcknowledged(id);
        verify(publisher, times(1)).publish(id);
        assertNoReplay();
    }

    @Test
    void acceptedMessageAndAcknowledgmentSurviveDatabaseCommitFailureWithoutAudit() throws Exception {
        long id = registeredDraft();
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
        }).when(publisher).publish(id);
        approve(id).andExpect(status().isInternalServerError());
        assertThat(drafts.findById(id).orElseThrow()).usingRecursiveComparison().isEqualTo(before);
        verifyNoInteractions(logging);
        assertMessage(id);
        assertAcknowledged(id);
        verify(publisher, times(1)).publish(id);
        assertNoReplay();
    }

    @Test
    void unavailableBrokerFailsWithinBoundedConnectionTimeout() throws Exception {
        try (ServerSocket unavailable = new ServerSocket(0)) {
            var factory = new JmsConnectionFactory("amqp://localhost:" + unavailable.getLocalPort()
                + "?jms.connectTimeout=500&jms.requestTimeout=500&jms.sendTimeout=500");
            var failed = new DraftCasefileQueuePublisherImpl(new JmsTemplate(factory), JSON, queue);
            assertThatThrownBy(() -> failed.publish(900002L)).isInstanceOf(JmsException.class);
        }
    }

    private void assertMessage(long id) throws Exception {
        var message = template.receive(queue);
        assertThat(message).isInstanceOf(TextMessage.class);
        assertThat(((TextMessage) message).getText()).isEqualTo("{\"draft_casefile_id\":" + id + "}");
        assertThat(message.getJMSDeliveryMode()).isEqualTo(DeliveryMode.PERSISTENT);
    }

    private long registeredDraft() throws Exception {
        var body = JSON.readTree(DraftCasefileHttpFixture.requestBody());
        ((ObjectNode) body.at("/casefile/respondent_account"))
            .put("remo_reference", "E2E-0123456789abcdef");
        String created = mockMvc.perform(post("/draft-casefiles").contentType(MediaType.APPLICATION_JSON)
            .content(body.toString()).with(authentication(DraftCasefileHttpFixture.token((short) 1))))
            .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString();
        long id = JSON.readTree(created).get("draft_casefile_id").longValue();
        mockMvc.perform(post("/testing-support/draft-casefiles/{id}/publication-evidence", id)
            .with(authentication(DraftCasefileHttpFixture.token((short) 1)))
            .header("Test-Run-Reference", "E2E-0123456789abcdef"))
            .andExpect(status().isCreated()).andExpect(jsonPath("$.send_attempt_count").value(0));
        return id;
    }

    private ResultActions approve(long id) throws Exception {
        var checker = DraftCasefileHttpFixture.token((short) 1, 124L, "BUU-CHECKER",
            Set.of(new Permission(22L, "Check and validate draft Casefiles")));
        return mockMvc.perform(patch("/draft-casefiles/{id}", id).header("If-Match", "\"0\"")
            .contentType(MediaType.APPLICATION_JSON)
            .content("{\"business_unit_id\":1,\"casefile_status\":\"PUBLISHING_PENDING\"}")
            .with(authentication(checker)));
    }

    private void assertAcknowledged(long id) {
        var observation = evidence.findObservation(id).orElseThrow();
        var counts = evidence.counts(observation.observationId());
        assertThat(counts.sendAttemptCount()).isEqualTo(1L);
        assertThat(counts.acknowledgedSendCount()).isEqualTo(1L);
        assertThat(counts.uncertainSendCount()).isZero();
        assertThat(counts.unfinishedSendCount()).isZero();
        assertThat(counts.evidenceComplete()).isTrue();
    }

    private void assertNoReplay() {
        template.setReceiveTimeout(250);
        assertThat(template.receive(queue)).isNull();
    }
}
