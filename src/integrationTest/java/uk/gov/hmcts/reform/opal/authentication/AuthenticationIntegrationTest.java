package uk.gov.hmcts.reform.opal.authentication;

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
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.security.core.Authentication;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import uk.gov.hmcts.reform.opal.BaseIntegrationTest;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Date;
import java.util.Map;

import static com.github.tomakehurst.wiremock.client.WireMock.aResponse;
import static com.github.tomakehurst.wiremock.client.WireMock.equalTo;
import static com.github.tomakehurst.wiremock.client.WireMock.getRequestedFor;
import static com.github.tomakehurst.wiremock.client.WireMock.okJson;
import static com.github.tomakehurst.wiremock.client.WireMock.urlEqualTo;
import static com.github.tomakehurst.wiremock.core.WireMockConfiguration.options;
import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertAll;
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
@ExtendWith(OutputCaptureExtension.class)
@Import(AuthenticationIntegrationTest.AuthenticatedTestController.class)
class AuthenticationIntegrationTest extends BaseIntegrationTest {

    private static final String AUTHENTICATED_PATH = "/integration-test/authenticated";
    private static final String DOWNSTREAM_IDENTITY_BODY = "downstream-identity-body-64824a37";
    private static final String DOWNSTREAM_UNSAFE_HEADER = "downstream-unsafe-header-8bc00e91";
    private static final String EXPECTED_AUDIENCE = "test-client-id";
    private static final String PRIVATE_OBJECT_ID = "private-object-id-732edac6";
    private static final String PRIVATE_SUBJECT = "private-subject-a4e618c9";
    private static final String TEST_REMOTE_ADDRESS = "198.51.100.42";
    private static final String USER_STATE_PATH = "/v2/users/0/state";
    private static final String USER_STATE_RESPONSE = """
        {
          "user_id": 123,
          "username": "test-user@example.invalid",
          "name": "Test User",
          "status": "ACTIVE",
          "version": 1,
          "domains": {
            "maintenance": {
              "business_unit_users": [{
                "business_unit_user_id": "BUU-42",
                "business_unit_id": 42,
                "permissions": []
              }]
            }
          }
        }
        """;
    private static final WireMockServer WIRE_MOCK_SERVER = new WireMockServer(options().dynamicPort());
    private static final RSAKey RSA_KEY = generateRsaKey();

    static {
        WIRE_MOCK_SERVER.start();
    }

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private StringRedisTemplate redisTemplate;

    @LocalServerPort
    private int serverPort;

    private ValueOperations<String, String> redisValueOperations;

    @DynamicPropertySource
    static void registerAuthenticationProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.security.oauth2.client.registration.internal-azure-ad.client-id",
                     () -> "test-client-id");
        registry.add("spring.security.oauth2.client.registration.internal-azure-ad.issuer-uri",
                     () -> WIRE_MOCK_SERVER.baseUrl() + "/issuer");
        registry.add("spring.security.oauth2.client.provider.internal-azure-ad-provider.jwk-set-uri",
                     () -> WIRE_MOCK_SERVER.baseUrl() + "/oauth2/jwks.json");
        registry.add("user.service.url", WIRE_MOCK_SERVER::baseUrl);
        registry.add("opal.redis.enabled", () -> false);
        registry.add("management.health.db.enabled", () -> false);
    }

    @BeforeEach
    void resetWireMock() {
        WIRE_MOCK_SERVER.resetAll();
        redisValueOperations = mock();
        when(redisTemplate.opsForValue()).thenReturn(redisValueOperations);
        clearInvocations(redisTemplate, redisValueOperations);
    }

    @AfterAll
    static void stopWireMock() {
        WIRE_MOCK_SERVER.stop();
    }

    @Test
    void allowsContractedGetEndpointsWithoutAuthentication() throws Exception {
        mockMvc.perform(get("/"))
            .andExpect(status().isOk());
        mockMvc.perform(get("/health"))
            .andExpect(status().isOk());
        mockMvc.perform(get("/prometheus"))
            .andExpect(status().isOk());
        mockMvc.perform(get("/swagger-ui.html"))
            .andExpect(status().is3xxRedirection());
        mockMvc.perform(get("/swagger-ui/index.html"))
            .andExpect(status().isOk());
        mockMvc.perform(get("/v3/api-docs"))
            .andExpect(status().isOk());
        mockMvc.perform(get("/v3/api-docs.yaml"))
            .andExpect(status().isOk());
        mockMvc.perform(get("/v3/api-docs/swagger-config"))
            .andExpect(status().isOk());
    }

    @Test
    void rejectsUnauthenticatedSiblingRoutes() {
        assertAll(
            () -> mockMvc.perform(get("/v3/future-resource"))
                .andExpect(status().isUnauthorized()),
            () -> mockMvc.perform(get("/testing-support/future-resource"))
                .andExpect(status().isUnauthorized())
        );
    }

    @Test
    void rejectsUnauthenticatedOperationalAndStaticSiblings() {
        assertAll(
            () -> mockMvc.perform(get("/info"))
                .andExpect(status().isUnauthorized()),
            () -> mockMvc.perform(get("/health/db"))
                .andExpect(status().isUnauthorized()),
            () -> mockMvc.perform(get("/css/future-resource"))
                .andExpect(status().isUnauthorized())
        );
    }

    @Test
    void rejectsWrongMethodOnPublicPath() throws Exception {
        mockMvc.perform(post("/v3/api-docs"))
            .andExpect(status().isUnauthorized());
    }

    @Test
    void leavesDisabledTestingSupportEndpointsAbsent() throws Exception {
        mockMvc.perform(get("/testing-support/ping"))
            .andExpect(status().isNotFound());
        mockMvc.perform(get("/testing-support/auth/check"))
            .andExpect(status().isNotFound());
    }

    @Test
    void authenticatesValidTokenUsingUserStateAndRelaysBearerHeader() throws Exception {
        stubJwkSet();
        WIRE_MOCK_SERVER.stubFor(com.github.tomakehurst.wiremock.client.WireMock.get(USER_STATE_PATH)
                                     .willReturn(okJson(USER_STATE_RESPONSE)));
        String token = tokenWith("test-subject", issuer(), Instant.now().plus(5, ChronoUnit.MINUTES));

        mockMvc.perform(get(AUTHENTICATED_PATH).header(HttpHeaders.AUTHORIZATION, bearer(token)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.name").value("test-subject"))
            .andExpect(jsonPath("$.authenticated").value(true));

        WIRE_MOCK_SERVER.verify(getRequestedFor(urlEqualTo(USER_STATE_PATH))
                                   .withHeader(HttpHeaders.AUTHORIZATION, equalTo(bearer(token))));
        verifyNoInteractions(redisTemplate, redisValueOperations);
    }

    @Test
    void rejectsTokenWithoutAudienceBeforeUserStateResolution() throws Exception {
        stubJwkSet();
        WIRE_MOCK_SERVER.stubFor(com.github.tomakehurst.wiremock.client.WireMock.get(USER_STATE_PATH)
                                     .willReturn(okJson(USER_STATE_RESPONSE)));
        String token = tokenWithoutAudience(
            "test-subject",
            issuer(),
            Instant.now().plus(5, ChronoUnit.MINUTES)
        );

        assertRejectedBeforeUserStateResolution(token);
    }

    @Test
    void rejectsTokenWithWrongAudienceBeforeUserStateResolution() throws Exception {
        stubJwkSet();
        WIRE_MOCK_SERVER.stubFor(com.github.tomakehurst.wiremock.client.WireMock.get(USER_STATE_PATH)
                                     .willReturn(okJson(USER_STATE_RESPONSE)));
        String token = tokenWithAudience(
            "test-subject",
            "wrong-audience",
            issuer(),
            Instant.now().plus(5, ChronoUnit.MINUTES)
        );

        assertRejectedBeforeUserStateResolution(token);
    }

    @Test
    void rejectsMalformedTokenWithoutLoggingRemoteAddressAsUserIdentifier(CapturedOutput output) throws Exception {
        mockMvc.perform(get(AUTHENTICATED_PATH)
                            .with(request -> {
                                request.setRemoteAddr(TEST_REMOTE_ADDRESS);
                                return request;
                            })
                            .header(HttpHeaders.AUTHORIZATION, "Bearer not-a-jwt"))
            .andExpect(status().isUnauthorized());

        assertThat(output)
            .doesNotContain("UserIdentifier=" + TEST_REMOTE_ADDRESS)
            .contains("UserIdentifier=Unauthenticated");
    }

    @Test
    void rejectsExpiredToken() throws Exception {
        stubJwkSet();
        String token = tokenWith("test-subject", issuer(), Instant.now().minus(1, ChronoUnit.MINUTES));

        mockMvc.perform(get(AUTHENTICATED_PATH).header(HttpHeaders.AUTHORIZATION, bearer(token)))
            .andExpect(status().isUnauthorized());
    }

    @Test
    void rejectsTokenFromWrongIssuer() throws Exception {
        stubJwkSet();
        String token = tokenWith("test-subject", WIRE_MOCK_SERVER.baseUrl() + "/wrong-issuer",
                                 Instant.now().plus(5, ChronoUnit.MINUTES));

        mockMvc.perform(get(AUTHENTICATED_PATH).header(HttpHeaders.AUTHORIZATION, bearer(token)))
            .andExpect(status().isUnauthorized());
    }

    @Test
    void rejectsTokenWhenUserStateIsNotFoundWithoutLoggingTokenIdentifiers(CapturedOutput output) throws Exception {
        stubJwkSet();
        WIRE_MOCK_SERVER.stubFor(com.github.tomakehurst.wiremock.client.WireMock.get(USER_STATE_PATH)
                                     .willReturn(aResponse().withStatus(404)));
        String token = tokenWith(PRIVATE_SUBJECT, PRIVATE_OBJECT_ID, issuer(),
                                 Instant.now().plus(5, ChronoUnit.MINUTES));

        mockMvc.perform(get(AUTHENTICATED_PATH).header(HttpHeaders.AUTHORIZATION, bearer(token)))
            .andExpect(status().isUnauthorized())
            .andExpect(content().contentType(MediaType.APPLICATION_JSON))
            .andExpect(jsonPath("$.type").value("https://hmcts.gov.uk/problems/unauthorized"))
            .andExpect(jsonPath("$.title").value("Unauthorized"))
            .andExpect(jsonPath("$.status").value(401))
            .andExpect(jsonPath("$.detail").value("You are not authorized to access this resource"))
            .andExpect(jsonPath("$.properties.retriable").value(false));

        assertThat(output)
            .doesNotContain(PRIVATE_SUBJECT, PRIVATE_OBJECT_ID)
            .contains("UserIdentifier=Unauthenticated");
    }

    @Test
    void doesNotLeakDownstreamIdentityWhenUserStateFails(CapturedOutput output) throws Exception {
        stubJwkSet();
        WIRE_MOCK_SERVER.stubFor(com.github.tomakehurst.wiremock.client.WireMock.get(USER_STATE_PATH)
                                     .willReturn(aResponse().withStatus(500)
                                                               .withHeader("Set-Cookie", DOWNSTREAM_UNSAFE_HEADER)
                                                               .withBody(DOWNSTREAM_IDENTITY_BODY)));
        String token = tokenWith("test-subject", issuer(), Instant.now().plus(5, ChronoUnit.MINUTES));

        HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create("http://localhost:" + serverPort + AUTHENTICATED_PATH))
            .header(HttpHeaders.AUTHORIZATION, bearer(token))
            .GET()
            .build();
        HttpResponse<String> response = HttpClient.newHttpClient()
            .send(request, HttpResponse.BodyHandlers.ofString());

        assertThat(response.statusCode() / 100).isNotEqualTo(2);
        assertThat(response.body())
            .doesNotContain(DOWNSTREAM_IDENTITY_BODY, DOWNSTREAM_UNSAFE_HEADER);
        assertThat(output).doesNotContain(DOWNSTREAM_IDENTITY_BODY, DOWNSTREAM_UNSAFE_HEADER);
    }

    private static void stubJwkSet() {
        String jwkSet = "{\"keys\":[" + RSA_KEY.toPublicJWK() + "]}";
        WIRE_MOCK_SERVER.stubFor(com.github.tomakehurst.wiremock.client.WireMock.get("/oauth2/jwks.json")
                                     .willReturn(okJson(jwkSet)));
    }

    private static String tokenWith(String subject, String tokenIssuer, Instant expiration) throws JOSEException {
        return tokenWith(subject, null, EXPECTED_AUDIENCE, tokenIssuer, expiration);
    }

    private static String tokenWith(String subject, String objectId, String tokenIssuer, Instant expiration)
        throws JOSEException {
        return tokenWith(subject, objectId, EXPECTED_AUDIENCE, tokenIssuer, expiration);
    }

    private static String tokenWith(
        String subject,
        String objectId,
        String audience,
        String tokenIssuer,
        Instant expiration) throws JOSEException {
        Instant issuedAt = Instant.now().minus(1, ChronoUnit.MINUTES);
        JWTClaimsSet.Builder claimsBuilder = new JWTClaimsSet.Builder()
            .subject(subject)
            .issuer(tokenIssuer)
            .issueTime(Date.from(issuedAt))
            .notBeforeTime(Date.from(issuedAt))
            .expirationTime(Date.from(expiration));
        if (objectId != null) {
            claimsBuilder.claim("oid", objectId);
        }
        if (audience != null) {
            claimsBuilder.audience(audience);
        }
        JWTClaimsSet claims = claimsBuilder.build();
        SignedJWT jwt = new SignedJWT(
            new JWSHeader.Builder(JWSAlgorithm.RS256).keyID(RSA_KEY.getKeyID()).build(),
            claims
        );
        jwt.sign(new RSASSASigner(RSA_KEY));
        return jwt.serialize();
    }

    private static String tokenWithoutAudience(String subject, String tokenIssuer, Instant expiration)
        throws JOSEException {
        return tokenWith(subject, null, null, tokenIssuer, expiration);
    }

    private static String tokenWithAudience(
        String subject,
        String audience,
        String tokenIssuer,
        Instant expiration) throws JOSEException {
        return tokenWith(subject, null, audience, tokenIssuer, expiration);
    }

    private void assertRejectedBeforeUserStateResolution(String token) throws Exception {
        int responseStatus = mockMvc.perform(
            get(AUTHENTICATED_PATH).header(HttpHeaders.AUTHORIZATION, bearer(token))
        ).andReturn().getResponse().getStatus();

        assertAll(
            () -> assertThat(responseStatus).isEqualTo(401),
            () -> WIRE_MOCK_SERVER.verify(0, getRequestedFor(urlEqualTo(USER_STATE_PATH))),
            () -> verifyNoInteractions(redisTemplate, redisValueOperations)
        );
    }

    private static RSAKey generateRsaKey() {
        try {
            return new RSAKeyGenerator(2048).keyID("integration-test-key").generate();
        } catch (JOSEException exception) {
            throw new IllegalStateException("Unable to generate integration test RSA key", exception);
        }
    }

    private static String issuer() {
        return WIRE_MOCK_SERVER.baseUrl() + "/issuer";
    }

    private static String bearer(String token) {
        return "Bearer " + token;
    }

    @RestController
    static class AuthenticatedTestController {

        @GetMapping(AUTHENTICATED_PATH)
        Map<String, Object> authenticated(Authentication authentication) {
            return Map.of("name", authentication.getName(), "authenticated", authentication.isAuthenticated());
        }
    }
}
