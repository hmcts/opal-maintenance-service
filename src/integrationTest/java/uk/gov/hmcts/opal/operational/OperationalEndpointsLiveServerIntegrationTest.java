package uk.gov.hmcts.opal.operational;

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
    "management.health.redis.enabled=false",
    "opal.testing-support-endpoints.enabled=false"
})
class OperationalEndpointsLiveServerIntegrationTest extends BaseIntegrationTest {

    private static final HttpClient HTTP_CLIENT = HttpClient.newHttpClient();

    @LocalServerPort
    private int serverPort;

    @Test
    void exposesPrometheusMetricsWithoutAuthentication() throws Exception {
        HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create("http://localhost:" + serverPort + "/prometheus"))
            .GET()
            .build();

        HttpResponse<String> response =
            HTTP_CLIENT.send(request, HttpResponse.BodyHandlers.ofString());

        assertAll(
            () -> assertThat(response.statusCode()).isEqualTo(200),
            () -> assertThat(response.headers()
                .firstValue("Content-Type")
                .orElse(""))
                .startsWith("text/plain"),
            () -> assertThat(response.body()).contains("# HELP")
        );
    }
}
