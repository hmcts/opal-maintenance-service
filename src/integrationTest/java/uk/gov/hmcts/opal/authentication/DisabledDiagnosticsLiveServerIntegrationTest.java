package uk.gov.hmcts.opal.authentication;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.test.context.TestPropertySource;
import uk.gov.hmcts.opal.BaseIntegrationTest;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertAll;

@TestPropertySource(properties = {
    "opal.redis.enabled=false",
    "opal.testing-support-endpoints.enabled=false",
    "management.health.redis.enabled=false"
})
class DisabledDiagnosticsLiveServerIntegrationTest extends BaseIntegrationTest {

    private static final HttpClient HTTP_CLIENT = HttpClient.newHttpClient();

    @LocalServerPort
    private int serverPort;

    @Test
    void returnsNotFoundForDisabledTestingSupportEndpoints() throws Exception {
        HttpResponse<String> pingResponse = get("/testing-support/ping");
        HttpResponse<String> authCheckResponse = get("/testing-support/auth/check");

        assertAll(
            () -> assertThat(pingResponse.statusCode()).isEqualTo(404),
            () -> assertThat(authCheckResponse.statusCode()).isEqualTo(404)
        );
    }

    @Test
    void keepsErrorAndUnknownTestingSupportRequestsProtected() {
        assertAll(
            () -> assertThat(get("/error").statusCode()).isEqualTo(401),
            () -> assertThat(get("/testing-support/future-resource").statusCode()).isEqualTo(401)
        );
    }

    private HttpResponse<String> get(String path) throws Exception {
        HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create("http://localhost:" + serverPort + path))
            .GET()
            .build();
        return HTTP_CLIENT.send(request, HttpResponse.BodyHandlers.ofString());
    }
}
