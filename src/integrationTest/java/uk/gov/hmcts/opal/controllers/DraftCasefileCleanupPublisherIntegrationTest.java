package uk.gov.hmcts.opal.controllers;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.aop.support.AopUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jms.core.JmsTemplate;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.context.jdbc.Sql;
import org.springframework.test.web.servlet.MockMvc;
import tools.jackson.databind.json.JsonMapper;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.common.user.authorisation.model.Permission;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.logging.integration.service.LoggingService;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.service.messaging.DraftCasefileQueuePublisher;
import uk.gov.hmcts.opal.service.messaging.DraftCasefileQueuePublisherImpl;
import uk.gov.hmcts.opal.support.DraftCasefileHttpFixture;

import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoMoreInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.test.context.jdbc.Sql.ExecutionPhase.AFTER_TEST_METHOD;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Runs the real publisher with only its JMS transport mocked; no broker acceptance is claimed. */
@AutoConfigureMockMvc
@TestPropertySource(properties = {"spring.flyway.locations=classpath:db/migration/ddl", "opal.redis.enabled=false",
    "management.health.redis.enabled=false", "opal.testing-support-endpoints.enabled=true",
    "opal.draft-casefile.service-bus.consumer-enabled=false"})
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@Sql("/draft-casefile/reference-fixtures.sql")
@Sql(scripts = "/draft-casefile/reference-cleanup.sql", executionPhase = AFTER_TEST_METHOD)
class DraftCasefileCleanupPublisherIntegrationTest extends BaseIntegrationTest {
    private static final JsonMapper JSON = JsonMapper.builder().build();
    @Autowired
    private MockMvc mvc;
    @Autowired
    private DraftCasefileQueuePublisher publisher;
    @Autowired
    private DraftCasefileRepository drafts;
    @Value("${opal.draft-casefile.service-bus.queue-name}")
    private String queue;
    @MockitoBean(name = "draftCasefilePublisherJmsTemplate")
    private JmsTemplate producer;
    @MockitoBean
    private LoggingService logging;

    @Test
    void approvalUsesBasePublisherAndInvokesProducerOnce() throws Exception {
        when(logging.personalDataAccessLogAsync(any())).thenReturn(true);
        assertThat(AopUtils.getTargetClass(publisher)).isEqualTo(DraftCasefileQueuePublisherImpl.class);
        String created = mvc.perform(post("/draft-casefiles").contentType(MediaType.APPLICATION_JSON)
                .content(DraftCasefileHttpFixture.requestBody())
                .with(authentication(DraftCasefileHttpFixture.token((short) 1))))
            .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString();
        long id = JSON.readTree(created).get("draft_casefile_id").longValue();
        var checker = DraftCasefileHttpFixture.token((short) 1, 124L, "BUU-CHECKER",
            Set.of(new Permission(22L, "Check and validate draft Casefiles")));
        for (int expectedStatus : new int[]{200, 409}) {
            mvc.perform(patch("/draft-casefiles/{id}", id).header("If-Match", "\"0\"")
                    .header("X-User-IP", "192.0.2.1").contentType(MediaType.APPLICATION_JSON)
                    .content("{\"business_unit_id\":1,\"casefile_status\":\"PUBLISHING_PENDING\"}")
                    .with(authentication(checker)))
                .andExpect(status().is(expectedStatus));
        }
        var payload = ArgumentCaptor.forClass(Object.class);
        verify(producer, times(1)).convertAndSend(eq(queue), payload.capture());
        verifyNoMoreInteractions(producer);
        var message = JSON.readTree((String) payload.getValue());
        assertThat(message.propertyNames()).containsExactlyInAnyOrder("draft_casefile_id", "checker_user_id",
            "originating_ip_address", "approval_timestamp");
        assertThat(message.path("draft_casefile_id").longValue()).isEqualTo(id);
        assertThat(message.path("checker_user_id").longValue()).isEqualTo(124L);
        assertThat(drafts.findById(id).orElseThrow().getCasefileStatus())
            .isEqualTo(DraftCasefileStatus.PUBLISHING_PENDING);
    }
}
