package uk.gov.hmcts.opal.authentication;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.context.jdbc.Sql;
import org.springframework.test.web.servlet.MockMvc;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.logging.integration.service.LoggingService;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.support.DraftCasefileAuthenticationFixture;
import uk.gov.hmcts.opal.support.DraftCasefileHttpFixture;

import java.time.Instant;
import java.time.LocalDateTime;

import static com.github.tomakehurst.wiremock.client.WireMock.get;
import static com.github.tomakehurst.wiremock.client.WireMock.getRequestedFor;
import static com.github.tomakehurst.wiremock.client.WireMock.okJson;
import static com.github.tomakehurst.wiremock.client.WireMock.urlEqualTo;
import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.context.jdbc.Sql.ExecutionPhase.AFTER_TEST_METHOD;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
@TestPropertySource(properties = {
    "spring.flyway.locations=classpath:db/migration/ddl",
    "opal.redis.enabled=false", "management.health.redis.enabled=false",
    "opal.testing-support-endpoints.enabled=true",
})
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@Sql("/draft-casefile/reference-fixtures.sql")
@Sql(scripts = "/draft-casefile/reference-cleanup.sql", executionPhase = AFTER_TEST_METHOD)
class DraftCasefileCleanupAuthenticationIntegrationTest extends BaseIntegrationTest {

    private static final DraftCasefileAuthenticationFixture AUTH = new DraftCasefileAuthenticationFixture();
    private static final String RUN = "E2E-0123456789abcdef";
    private static final String PATH = "/testing-support/draft-casefiles/{id}";
    private static final String USER_STATE_PATH = "/v2/users/0/state";
    @Autowired
    private MockMvc mockMvc;
    @Autowired
    private ObjectMapper objectMapper;
    @Autowired
    private DraftCasefileRepository repository;
    @MockitoBean
    private LoggingService logging;

    @DynamicPropertySource
    static void authenticationProperties(DynamicPropertyRegistry registry) {
        AUTH.properties(registry);
    }

    @BeforeEach
    void setUp() {
        AUTH.reset();
        when(logging.personalDataAccessLogAsync(any())).thenReturn(true);
        stubUserState("permitted");
    }

    @AfterAll
    static void stopWireMock() {
        AUTH.close();
    }

    @ParameterizedTest
    @EnumSource(value = DraftCasefileStatus.class,
        names = {"SUBMITTED", "REJECTED", "RESUBMITTED", "DELETED", "PUBLISHING_FAILED"})
    void realSignedBearerSubmitsAndCleansDraft(DraftCasefileStatus lifecycle) throws Exception {
        String bearer = bearer();
        long id = submit(bearer);
        DraftCasefileEntity draft = repository.findById(id).orElseThrow();
        var builder = draft.toBuilder().casefileStatus(lifecycle);
        if (lifecycle != DraftCasefileStatus.SUBMITTED) {
            builder.validatedBy("BUU-CHECKER").validatedByName("Synthetic Checker")
                .validatedDate(LocalDateTime.of(2026, 10, 22, 10, 0));
        }
        repository.saveAndFlush(builder.build());
        mockMvc.perform(delete(PATH, id).header(HttpHeaders.AUTHORIZATION, bearer).header("Test-Run-Reference", RUN))
            .andExpect(status().isNoContent());
        assertThat(repository.findById(id)).isEmpty();
        AUTH.server().verify(2, getRequestedFor(urlEqualTo(USER_STATE_PATH)));
    }

    @Test
    void anotherAuthenticatedSubmitterCanCleanTheirOwnDraft() throws Exception {
        stubUserState("wrong-user");
        String bearer = bearer();
        long id = submit(bearer);
        assertThat(repository.findById(id).orElseThrow().getSubmittedBy()).isEqualTo("BUU-OTHER");
        mockMvc.perform(delete(PATH, id).header(HttpHeaders.AUTHORIZATION, bearer).header("Test-Run-Reference", RUN))
            .andExpect(status().isNoContent());
        assertThat(repository.findById(id)).isEmpty();
    }

    @ParameterizedTest
    @ValueSource(strings = {"no-permission", "checker", "wrong-user", "wrong-buu", "wrong-bu"})
    void userServiceIdentityAndPermissionRestrictCleanup(String variant) throws Exception {
        String bearer = bearer();
        DraftCasefileEntity before = repository.findById(submit(bearer)).orElseThrow();
        stubUserState(variant);
        mockMvc.perform(delete(PATH, before.getDraftCasefileId()).header(HttpHeaders.AUTHORIZATION, bearer)
                .header("Test-Run-Reference", RUN)).andExpect(status().isForbidden());
        assertUnchanged(before);
    }

    @ParameterizedTest
    @ValueSource(strings = {"expired", "malformed", "missing"})
    void invalidBearerCannotDeleteOrReachUserService(String variant) throws Exception {
        DraftCasefileEntity before = repository.findById(submit(bearer())).orElseThrow();
        AUTH.server().resetRequests();
        var request = delete(PATH, before.getDraftCasefileId()).header("Test-Run-Reference", RUN);
        if (!variant.equals("missing")) {
            String token = variant.equals("expired")
                ? AUTH.signedToken(Instant.now().minusSeconds(120)) : "malformed";
            request.header(HttpHeaders.AUTHORIZATION, "Bearer " + token);
        }
        mockMvc.perform(request).andExpect(status().isUnauthorized());
        assertUnchanged(before);
        AUTH.server().verify(0, getRequestedFor(urlEqualTo(USER_STATE_PATH)));
    }

    private String bearer() throws Exception {
        return "Bearer " + AUTH.signedToken(Instant.now().plusSeconds(300));
    }

    private long submit(String bearer) throws Exception {
        ObjectNode request = (ObjectNode) objectMapper.readTree(DraftCasefileHttpFixture.requestBody());
        ((ObjectNode) request.at("/casefile/respondent_account")).put("remo_reference", RUN);
        String response = mockMvc.perform(post("/draft-casefiles").header(HttpHeaders.AUTHORIZATION, bearer)
                .contentType(MediaType.APPLICATION_JSON).content(objectMapper.writeValueAsBytes(request)))
            .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString();
        return objectMapper.readTree(response).get("draft_casefile_id").longValue();
    }

    private void assertUnchanged(DraftCasefileEntity before) {
        assertThat(repository.findById(before.getDraftCasefileId()).orElseThrow())
            .usingRecursiveComparison().isEqualTo(before);
    }

    private void stubUserState(String variant) {
        String permissions = switch (variant) {
            case "no-permission" -> "[]";
            case "checker" -> "[{\"permission_id\":22,\"permission_name\":\"Check and validate draft Casefiles\"}]";
            default -> "[{\"permission_id\":21,\"permission_name\":\"Create and Manage Draft Casefiles\"}]";
        };
        AUTH.server().stubFor(get(USER_STATE_PATH).willReturn(okJson("""
            {"user_id":%d,"username":"synthetic-user@example.invalid","name":"Synthetic Automation",
             "status":"ACTIVE","version":1,"domains":{"maintenance":{"business_unit_users":[{
             "business_unit_user_id":"%s","business_unit_id":%d,"permissions":%s}]}}}
            """.formatted(variant.equals("wrong-user") ? 124 : 123,
                (variant.equals("wrong-buu") || variant.equals("wrong-user")) ? "BUU-OTHER" : "BUU-1",
                variant.equals("wrong-bu") ? 2 : 1, permissions))));
    }
}
