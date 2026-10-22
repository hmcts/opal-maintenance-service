package uk.gov.hmcts.opal.support;

import com.github.tomakehurst.wiremock.WireMockServer;
import com.nimbusds.jose.JOSEException;
import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.JWSHeader;
import com.nimbusds.jose.crypto.RSASSASigner;
import com.nimbusds.jose.jwk.RSAKey;
import com.nimbusds.jose.jwk.gen.RSAKeyGenerator;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;
import org.springframework.test.context.DynamicPropertyRegistry;

import java.time.Instant;
import java.util.Date;

import static com.github.tomakehurst.wiremock.client.WireMock.get;
import static com.github.tomakehurst.wiremock.client.WireMock.okJson;
import static com.github.tomakehurst.wiremock.core.WireMockConfiguration.options;

/** Disposable signed bearer and local JWKS fixture for Draft Casefile HTTP authentication tests. */
public final class DraftCasefileAuthenticationFixture implements AutoCloseable {

    private final WireMockServer server = new WireMockServer(options().dynamicPort());
    private final RSAKey key = generateKey();

    public DraftCasefileAuthenticationFixture() {
        server.start();
    }

    public WireMockServer server() {
        return server;
    }

    public void properties(DynamicPropertyRegistry registry) {
        registry.add("spring.security.oauth2.client.registration.internal-azure-ad.client-id", () -> "test-client-id");
        registry.add("spring.security.oauth2.client.registration.internal-azure-ad.issuer-uri",
            () -> server.baseUrl() + "/issuer");
        registry.add("spring.security.oauth2.client.provider.internal-azure-ad-provider.jwk-set-uri",
            () -> server.baseUrl() + "/oauth2/jwks.json");
        registry.add("user.service.url", server::baseUrl);
    }

    public void reset() {
        server.resetAll();
        server.stubFor(get("/oauth2/jwks.json").willReturn(okJson("{\"keys\":[" + key.toPublicJWK() + "]}")));
    }

    @Override
    public void close() {
        server.stop();
    }

    public String signedToken(Instant expiration) throws JOSEException {
        Instant issued = Instant.now().minusSeconds(300);
        SignedJWT jwt = new SignedJWT(new JWSHeader.Builder(JWSAlgorithm.RS256).keyID(key.getKeyID()).build(),
            new JWTClaimsSet.Builder().subject("synthetic-draft-subject").audience("test-client-id")
                .issuer(server.baseUrl() + "/issuer").issueTime(Date.from(issued)).notBeforeTime(Date.from(issued))
                .expirationTime(Date.from(expiration)).build());
        jwt.sign(new RSASSASigner(key));
        return jwt.serialize();
    }

    private static RSAKey generateKey() {
        try {
            return new RSAKeyGenerator(2048).keyID("draft-integration-key").generate();
        } catch (JOSEException exception) {
            throw new IllegalStateException("Unable to generate synthetic test key", exception);
        }
    }
}
