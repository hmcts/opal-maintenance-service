package uk.gov.hmcts.opal.authentication;

import com.github.tomakehurst.wiremock.WireMockServer;
import com.nimbusds.jose.JOSEException;
import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.JWSHeader;
import com.nimbusds.jose.crypto.RSASSASigner;
import com.nimbusds.jose.jwk.RSAKey;
import com.nimbusds.jose.jwk.gen.RSAKeyGenerator;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.boot.test.web.server.LocalServerPort;
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
import uk.gov.hmcts.opal.support.DraftCasefileHttpFixture;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Instant;
import java.util.Date;

import static com.github.tomakehurst.wiremock.client.WireMock.aResponse;
import static com.github.tomakehurst.wiremock.client.WireMock.get;
import static com.github.tomakehurst.wiremock.client.WireMock.getRequestedFor;
import static com.github.tomakehurst.wiremock.client.WireMock.okJson;
import static com.github.tomakehurst.wiremock.client.WireMock.urlEqualTo;
import static com.github.tomakehurst.wiremock.core.WireMockConfiguration.options;
import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.context.jdbc.Sql.ExecutionPhase.AFTER_TEST_METHOD;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
@ExtendWith(OutputCaptureExtension.class)
@TestPropertySource(properties = {
    "spring.flyway.locations=classpath:db/migration/ddl",
    "opal.redis.enabled=false",
    "management.health.redis.enabled=false"
})
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@Sql("/draft-casefile/reference-fixtures.sql")
@Sql(scripts = "/draft-casefile/reference-cleanup.sql", executionPhase = AFTER_TEST_METHOD)
class DraftCasefileAuthenticationIntegrationTest extends BaseIntegrationTest {

    private static final WireMockServer WIRE_MOCK = new WireMockServer(options().dynamicPort());
    private static final RSAKey KEY = generateKey();
    private static final String USER_STATE_PATH = "/v2/users/0/state";

    static {
        WIRE_MOCK.start();
    }

    @Autowired
    private MockMvc mockMvc;
    @Autowired
    private DraftCasefileRepository repository;
    @MockitoBean
    private LoggingService logging;
    @LocalServerPort
    private int serverPort;

    @DynamicPropertySource
    static void authenticationProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.security.oauth2.client.registration.internal-azure-ad.client-id", () -> "test-client-id");
        registry.add("spring.security.oauth2.client.registration.internal-azure-ad.issuer-uri",
            () -> WIRE_MOCK.baseUrl() + "/issuer");
        registry.add("spring.security.oauth2.client.provider.internal-azure-ad-provider.jwk-set-uri",
            () -> WIRE_MOCK.baseUrl() + "/oauth2/jwks.json");
        registry.add("user.service.url", WIRE_MOCK::baseUrl);
    }

    @BeforeEach
    void setUp() {
        WIRE_MOCK.resetAll();
        WIRE_MOCK.stubFor(get("/oauth2/jwks.json").willReturn(okJson("{\"keys\":[" + KEY.toPublicJWK() + "]}")));
        when(logging.personalDataAccessLogAsync(any())).thenReturn(true);
    }

    @AfterAll
    static void stopWireMock() {
        WIRE_MOCK.stop();
    }

    @Test
    void signedJwtAndMatchingUserServicePermissionCreateDraft() throws Exception {
        stubUserState(1);
        String response = mockMvc.perform(post("/draft-casefiles")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + signedToken(Instant.now().plusSeconds(300)))
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
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + signedToken(Instant.now().plusSeconds(300)))
                .contentType(MediaType.APPLICATION_JSON).content(DraftCasefileHttpFixture.requestBody()))
            .andExpect(status().isForbidden());
        assertThat(repository.count()).isZero();
        verifyNoInteractions(logging);
    }

    @Test
    void signedJwtWithOnlyCheckerPermissionIsForbidden() throws Exception {
        stubUserState(1, "[{\"permission_id\":22,\"permission_name\":\"Check and validate draft Casefiles\"}]");
        mockMvc.perform(post("/draft-casefiles")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + signedToken(Instant.now().plusSeconds(300)))
                .contentType(MediaType.APPLICATION_JSON).content(DraftCasefileHttpFixture.requestBody()))
            .andExpect(status().isForbidden());
        assertThat(repository.count()).isZero();
        verifyNoInteractions(logging);
    }

    @Test
    void signedJwtWithDifferentBusinessUnitIdentityIsForbidden() throws Exception {
        stubUserState(2);
        mockMvc.perform(post("/draft-casefiles")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + signedToken(Instant.now().plusSeconds(300)))
                .contentType(MediaType.APPLICATION_JSON).content(DraftCasefileHttpFixture.requestBody()))
            .andExpect(status().isForbidden());
        assertThat(repository.count()).isZero();
        verifyNoInteractions(logging);
        WIRE_MOCK.verify(1, getRequestedFor(urlEqualTo(USER_STATE_PATH)));
    }

    @Test
    void expiredJwtIsRejectedBeforeUserLookupOrPersistence() throws Exception {
        mockMvc.perform(post("/draft-casefiles")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + signedToken(Instant.now().minusSeconds(120)))
                .contentType(MediaType.APPLICATION_JSON).content(DraftCasefileHttpFixture.requestBody()))
            .andExpect(status().isUnauthorized());
        assertThat(repository.count()).isZero();
        verifyNoInteractions(logging);
        WIRE_MOCK.verify(0, getRequestedFor(urlEqualTo(USER_STATE_PATH)));
    }

    @ParameterizedTest
    @ValueSource(ints = {21, 22})
    void signedJwtWithEitherOwningUnitPermissionRetrievesCommittedDraft(int permission) throws Exception {
        long id = submitDraft();
        stubUserState(1, "[{\"permission_id\":%d,\"permission_name\":\"Synthetic permission\"}]".formatted(permission));
        String response = mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                .get("/draft-casefiles/{id}", id)
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + signedToken(Instant.now().plusSeconds(300))))
            .andExpect(status().isOk()).andExpect(header().string("ETag", "\"0\""))
            .andExpect(jsonPath("$.casefile_status").value("SUBMITTED"))
            .andExpect(jsonPath("$.casefile.respondent_account.respondent.party_details.individual_details.surname")
                .value("Example"))
            .andReturn().getResponse().getContentAsString();
        assertThat(JsonMapper.builder().build().readTree(response).get("draft_casefile_id").longValue()).isEqualTo(id);
        verify(logging, times(2)).personalDataAccessLogAsync(any());
        WIRE_MOCK.verify(1, getRequestedFor(urlEqualTo(USER_STATE_PATH)));
    }

    @ParameterizedTest
    @ValueSource(strings = {"empty", "other-unit", "missing-identity"})
    void signedJwtWithoutOwningUnitPermissionCannotRetrieve(String failure, CapturedOutput output) throws Exception {
        final int outputStart = output.getAll().length();
        long id = submitDraft();
        stubUserState(failure.equals("missing-identity") ? 2 : 1, "[]");
        if (failure.equals("other-unit")) {
            WIRE_MOCK.stubFor(get(USER_STATE_PATH).willReturn(okJson("""
                {"user_id":123,"username":"synthetic-user@example.invalid",
                 "name":"Synthetic Authenticated Submitter","status":"ACTIVE","version":1,
                 "domains":{"maintenance":{"business_unit_users":[
                  {"business_unit_user_id":"BUU-1","business_unit_id":1,"permissions":[]},
                  {"business_unit_user_id":"BUU-2","business_unit_id":2,
                   "permissions":[{"permission_id":22,"permission_name":"Synthetic checker"}]}]}}}
                """)));
        }
        String response = mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                .get("/draft-casefiles/{id}", id)
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + signedToken(Instant.now().plusSeconds(300))))
            .andExpect(status().isForbidden()).andExpect(jsonPath("$.operation_id").isNotEmpty())
            .andReturn().getResponse().getContentAsString();
        assertThat(response).doesNotContain("Synthetic address", "Example");
        assertThat(output.getAll().substring(outputStart)).doesNotContain("Synthetic address");
        verifyNoInteractions(logging);
        WIRE_MOCK.verify(1, getRequestedFor(urlEqualTo(USER_STATE_PATH)));
    }

    @ParameterizedTest
    @ValueSource(booleans = {false, true})
    void invalidOrExpiredJwtCannotRetrieveBeforeUserLookup(boolean expired) throws Exception {
        long id = submitDraft();
        String token = expired ? signedToken(Instant.now().minusSeconds(120)) : "not-a-jwt";
        String response = mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                .get("/draft-casefiles/{id}", id).header(HttpHeaders.AUTHORIZATION, "Bearer " + token))
            .andExpect(status().isUnauthorized()).andExpect(jsonPath("$.operation_id").isNotEmpty())
            .andReturn().getResponse().getContentAsString();
        assertThat(response).doesNotContain("Synthetic address", "Example");
        verifyNoInteractions(logging);
        WIRE_MOCK.verify(0, getRequestedFor(urlEqualTo(USER_STATE_PATH)));
    }

    @Test
    void unavailableUserServiceCannotRetrieveOrDiscloseDownstreamValues(CapturedOutput output) throws Exception {
        final int outputStart = output.getAll().length();
        long id = submitDraft();
        WIRE_MOCK.stubFor(get(USER_STATE_PATH).willReturn(aResponse().withStatus(503)
            .withBody("SYNTHETIC_PRIVATE_USER_SERVICE_VALUE")));
        HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create("http://localhost:" + serverPort + "/draft-casefiles/" + id))
            .header(HttpHeaders.AUTHORIZATION, "Bearer " + signedToken(Instant.now().plusSeconds(300)))
            .GET().build();
        HttpResponse<String> response = HttpClient.newHttpClient().send(request, HttpResponse.BodyHandlers.ofString());
        assertThat(response.statusCode()).isEqualTo(500);
        assertThat(response.body()).doesNotContain("SYNTHETIC_PRIVATE_USER_SERVICE_VALUE", "Synthetic address");
        assertThat(output.getAll().substring(outputStart))
            .doesNotContain("SYNTHETIC_PRIVATE_USER_SERVICE_VALUE", "Synthetic address");
        verifyNoInteractions(logging);
        WIRE_MOCK.verify(1, getRequestedFor(urlEqualTo(USER_STATE_PATH)));
    }

    private long submitDraft() throws Exception {
        stubUserState(1);
        String response = mockMvc.perform(post("/draft-casefiles")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + signedToken(Instant.now().plusSeconds(300)))
                .contentType(MediaType.APPLICATION_JSON).content(DraftCasefileHttpFixture.requestBody()))
            .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString();
        clearInvocations(logging);
        WIRE_MOCK.resetRequests();
        return JsonMapper.builder().build().readTree(response).get("draft_casefile_id").longValue();
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

    private static String signedToken(Instant expiration) throws JOSEException {
        Instant issued = Instant.now().minusSeconds(300);
        SignedJWT jwt = new SignedJWT(new JWSHeader.Builder(JWSAlgorithm.RS256).keyID(KEY.getKeyID()).build(),
            new JWTClaimsSet.Builder().subject("synthetic-draft-subject").audience("test-client-id")
                .issuer(WIRE_MOCK.baseUrl() + "/issuer").issueTime(Date.from(issued)).notBeforeTime(Date.from(issued))
                .expirationTime(Date.from(expiration)).build());
        jwt.sign(new RSASSASigner(KEY));
        return jwt.serialize();
    }

    private static RSAKey generateKey() {
        try {
            return new RSAKeyGenerator(2048).keyID("draft-integration-key").generate();
        } catch (JOSEException exception) {
            throw new IllegalStateException("Unable to generate synthetic test key", exception);
        }
    }

    @ParameterizedTest
    @CsvSource({"21,false", "22,false", "21,true", "22,true"})
    void signedJwtWithEitherPermissionCanListOrCount(int permission, boolean counts) throws Exception {
        long id = submitDraft();
        stubUserState(1, "[{\"permission_id\":%d,\"permission_name\":\"Synthetic permission\"}]".formatted(permission));
        var request = org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get("/draft-casefiles")
            .param("business_unit_id", "1")
            .header(HttpHeaders.AUTHORIZATION, "Bearer " + signedToken(Instant.now().plusSeconds(300)));
        if (counts) {
            request.param("restrict", "counts");
        }
        String raw = mockMvc.perform(request).andExpect(status().isOk())
            .andExpect(jsonPath("$.count").value(1))
            .andReturn().getResponse().getContentAsString();
        var body = JsonMapper.builder().build().readTree(raw);
        if (counts) {
            assertThat(body.propertyNames()).containsExactly("count");
            verifyNoInteractions(logging);
        } else {
            assertThat(body.get("summaries").get(0).get("draft_casefile_id").longValue()).isEqualTo(id);
            verify(logging, times(2)).personalDataAccessLogAsync(any());
        }
        WIRE_MOCK.verify(1, getRequestedFor(urlEqualTo(USER_STATE_PATH)));
    }

    @ParameterizedTest
    @CsvSource({"false,false", "false,true", "true,false", "true,true"})
    void invalidOrExpiredJwtCannotListBeforeUserLookup(boolean expired, boolean counts) throws Exception {
        String token = expired ? signedToken(Instant.now().minusSeconds(120)) : "not-a-jwt";
        var request = org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get("/draft-casefiles")
            .param("business_unit_id", "1").header(HttpHeaders.AUTHORIZATION, "Bearer " + token);
        if (counts) {
            request.param("restrict", "counts");
        }
        mockMvc.perform(request).andExpect(status().isUnauthorized())
            .andExpect(jsonPath("$.operation_id").isNotEmpty());
        verifyNoInteractions(logging);
        WIRE_MOCK.verify(0, getRequestedFor(urlEqualTo(USER_STATE_PATH)));
    }

    @ParameterizedTest
    @CsvSource({"empty,false", "other-unit,false", "missing-identity,false",
        "empty,true", "other-unit,true", "missing-identity,true"})
    void signedJwtWithoutRequestedUnitPermissionCannotList(String failure, boolean counts) throws Exception {
        stubUserState(failure.equals("missing-identity") ? 2 : 1, "[]");
        if (failure.equals("other-unit")) {
            WIRE_MOCK.stubFor(get(USER_STATE_PATH).willReturn(okJson("""
                {"user_id":123,"username":"synthetic-user@example.invalid",
                 "name":"Synthetic Submitter","status":"ACTIVE","version":1,
                 "domains":{"maintenance":{"business_unit_users":[
                  {"business_unit_user_id":"BUU-1","business_unit_id":1,"permissions":[]},
                  {"business_unit_user_id":"BUU-2","business_unit_id":2,
                   "permissions":[{"permission_id":22,"permission_name":"Synthetic checker"}]}]}}}
                """)));
        }
        var request = org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get("/draft-casefiles")
            .param("business_unit_id", "1")
            .header(HttpHeaders.AUTHORIZATION, "Bearer " + signedToken(Instant.now().plusSeconds(300)));
        if (counts) {
            request.param("restrict", "counts");
        }
        mockMvc.perform(request).andExpect(status().isForbidden()).andExpect(jsonPath("$.operation_id").isNotEmpty());
        verifyNoInteractions(logging);
        WIRE_MOCK.verify(1, getRequestedFor(urlEqualTo(USER_STATE_PATH)));
    }
}
