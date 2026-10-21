package uk.gov.hmcts.opal.authentication;

import com.github.tomakehurst.wiremock.WireMockServer;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
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
import tools.jackson.databind.json.JsonMapper;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.logging.integration.service.LoggingService;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.support.DraftCasefileAuthenticationFixture;
import uk.gov.hmcts.opal.support.DraftCasefileHttpFixture;

import java.time.Instant;

import static com.github.tomakehurst.wiremock.client.WireMock.get;
import static com.github.tomakehurst.wiremock.client.WireMock.getRequestedFor;
import static com.github.tomakehurst.wiremock.client.WireMock.okJson;
import static com.github.tomakehurst.wiremock.client.WireMock.urlEqualTo;
import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.context.jdbc.Sql.ExecutionPhase.AFTER_TEST_METHOD;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
@TestPropertySource(properties = {
    "spring.flyway.locations=classpath:db/migration/ddl",
    "opal.redis.enabled=false",
    "management.health.redis.enabled=false"
})
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@Sql("/draft-casefile/reference-fixtures.sql")
@Sql(scripts = "/draft-casefile/reference-cleanup.sql", executionPhase = AFTER_TEST_METHOD)
class DraftCasefileAuthenticationIntegrationTest extends BaseIntegrationTest {

    private static final DraftCasefileAuthenticationFixture AUTH = new DraftCasefileAuthenticationFixture();
    private static final WireMockServer WIRE_MOCK = AUTH.server();
    private static final String USER_STATE_PATH = "/v2/users/0/state";

    @Autowired
    private MockMvc mockMvc;
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
    }

    @AfterAll
    static void stopWireMock() {
        AUTH.close();
    }

    @Test
    void signedJwtAndMatchingUserServicePermissionCreateDraft() throws Exception {
        stubUserState(1);
        String response = mockMvc.perform(post("/draft-casefiles")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + AUTH.signedToken(Instant.now().plusSeconds(300)))
                .contentType(MediaType.APPLICATION_JSON).content(DraftCasefileHttpFixture.requestBody()))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.submitted_by").value("BUU-1"))
            .andExpect(jsonPath("$.submitted_by_name").value("Synthetic Authenticated Submitter"))
            .andReturn().getResponse().getContentAsString();
        long id = JsonMapper.builder().build().readTree(response).get("draft_casefile_id").longValue();
        assertThat(repository.findById(id)).isPresent();
        verify(logging, times(2)).personalDataAccessLogAsync(any());
        WIRE_MOCK.verify(1, getRequestedFor(urlEqualTo(USER_STATE_PATH)));
    }

    @Test
    void signedJwtWithoutCreatorPermissionIsForbidden() throws Exception {
        stubUserState(1, "[]");
        mockMvc.perform(post("/draft-casefiles")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + AUTH.signedToken(Instant.now().plusSeconds(300)))
                .contentType(MediaType.APPLICATION_JSON).content(DraftCasefileHttpFixture.requestBody()))
            .andExpect(status().isForbidden());
        assertThat(repository.count()).isZero();
        verifyNoInteractions(logging);
    }

    @Test
    void signedJwtWithOnlyCheckerPermissionIsForbidden() throws Exception {
        stubUserState(1, "[{\"permission_id\":22,\"permission_name\":\"Check and validate draft Casefiles\"}]");
        mockMvc.perform(post("/draft-casefiles")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + AUTH.signedToken(Instant.now().plusSeconds(300)))
                .contentType(MediaType.APPLICATION_JSON).content(DraftCasefileHttpFixture.requestBody()))
            .andExpect(status().isForbidden());
        assertThat(repository.count()).isZero();
        verifyNoInteractions(logging);
    }

    @Test
    void signedJwtWithDifferentBusinessUnitIdentityIsForbidden() throws Exception {
        stubUserState(2);
        mockMvc.perform(post("/draft-casefiles")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + AUTH.signedToken(Instant.now().plusSeconds(300)))
                .contentType(MediaType.APPLICATION_JSON).content(DraftCasefileHttpFixture.requestBody()))
            .andExpect(status().isForbidden());
        assertThat(repository.count()).isZero();
        verifyNoInteractions(logging);
        WIRE_MOCK.verify(1, getRequestedFor(urlEqualTo(USER_STATE_PATH)));
    }

    @Test
    void expiredJwtIsRejectedBeforeUserLookupOrPersistence() throws Exception {
        mockMvc.perform(post("/draft-casefiles")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + AUTH.signedToken(Instant.now().minusSeconds(120)))
                .contentType(MediaType.APPLICATION_JSON).content(DraftCasefileHttpFixture.requestBody()))
            .andExpect(status().isUnauthorized());
        assertThat(repository.count()).isZero();
        verifyNoInteractions(logging);
        WIRE_MOCK.verify(0, getRequestedFor(urlEqualTo(USER_STATE_PATH)));
    }

    private static void stubUserState(int businessUnitId) {
        stubUserState(businessUnitId,
            "[{\"permission_id\":21,\"permission_name\":\"Create and Manage Draft Casefiles\"}]");
    }

    private static void stubUserState(int businessUnitId, String permissions) {
        WIRE_MOCK.stubFor(get(USER_STATE_PATH).willReturn(okJson("""
            {"user_id":123,"username":"synthetic-user@example.invalid","name":"Synthetic Authenticated Submitter",
             "status":"ACTIVE","version":1,"domains":{"maintenance":{"business_unit_users":[{
              "business_unit_user_id":"BUU-1","business_unit_id":%d,"permissions":%s}]}}}
            """.formatted(businessUnitId, permissions))));
    }
}
