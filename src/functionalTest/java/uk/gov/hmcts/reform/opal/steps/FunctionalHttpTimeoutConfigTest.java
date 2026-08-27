package uk.gov.hmcts.reform.opal.steps;

import io.restassured.config.HttpClientConfig;
import org.junit.jupiter.api.Test;

import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.time.Duration;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertAll;
import static org.junit.jupiter.api.Assertions.assertTrue;

class FunctionalHttpTimeoutConfigTest {

    private static final String CONNECTION_TIMEOUT_PARAMETER = "http.connection.timeout";
    private static final String SOCKET_TIMEOUT_PARAMETER = "http.socket.timeout";
    private static final String CONNECTION_MANAGER_TIMEOUT_PARAMETER = "http.conn-manager.timeout";

    @Test
    void configuresFiniteRestAssuredTimeouts() {
        HttpClientConfig httpClientConfig = BaseStepDef.requestConfig().getHttpClientConfig();
        Map<String, ?> params = httpClientConfig.params();

        assertAll(
            () -> assertPositiveTimeout(params, CONNECTION_TIMEOUT_PARAMETER),
            () -> assertPositiveTimeout(params, SOCKET_TIMEOUT_PARAMETER),
            () -> assertPositiveTimeout(params, CONNECTION_MANAGER_TIMEOUT_PARAMETER)
        );
    }

    @Test
    void configuresFiniteTokenClientTimeouts() {
        HttpClient client = BearerTokenStepDef.tokenHttpClient();
        HttpRequest request = BearerTokenStepDef.tokenRequest("functional-test@example.invalid");

        assertAll(
            () -> assertTrue(client.connectTimeout().filter(FunctionalHttpTimeoutConfigTest::isPositive).isPresent()),
            () -> assertTrue(request.timeout().filter(FunctionalHttpTimeoutConfigTest::isPositive).isPresent())
        );
    }

    private static void assertPositiveTimeout(Map<String, ?> params, String name) {
        Object value = params.get(name);
        assertTrue(value instanceof Number && ((Number) value).longValue() > 0, name + " must be finite and positive");
    }

    private static boolean isPositive(Duration timeout) {
        return !timeout.isZero() && !timeout.isNegative();
    }
}
