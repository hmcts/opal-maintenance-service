package uk.gov.hmcts.reform.opal.steps;

import io.restassured.config.HttpClientConfig;
import io.restassured.config.LogConfig;
import io.restassured.config.RestAssuredConfig;
import io.restassured.response.Response;
import io.restassured.specification.RequestSpecification;
import net.serenitybdd.rest.SerenityRest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;

import java.time.Duration;

public abstract class BaseStepDef {

    static final Duration CONNECT_TIMEOUT = Duration.ofSeconds(10);
    static final Duration REQUEST_TIMEOUT = Duration.ofSeconds(30);

    private static final String CONNECTION_TIMEOUT_PARAMETER = "http.connection.timeout";
    private static final String SOCKET_TIMEOUT_PARAMETER = "http.socket.timeout";
    private static final String CONNECTION_MANAGER_TIMEOUT_PARAMETER = "http.conn-manager.timeout";
    private static final String TEST_URL = withoutTrailingSlash(
        System.getenv().getOrDefault("TEST_URL", "http://localhost:4551")
    );
    private static final String USER_SERVICE_URL = withoutTrailingSlash(
        System.getenv().getOrDefault("OPAL_USER_SERVICE_API_URL", "http://localhost:4555")
    );

    protected static Response getWithBearer(String path, String token) {
        return jsonRequest()
            .header(HttpHeaders.AUTHORIZATION, "Bearer " + token)
            .when()
            .get(TEST_URL + path);
    }

    protected static Response getWithoutBearer(String path) {
        return jsonRequest().when().get(TEST_URL + path);
    }

    protected static String userServiceUrl() {
        return USER_SERVICE_URL;
    }

    private static RequestSpecification jsonRequest() {
        return SerenityRest.given()
            .config(requestConfig())
            .accept(MediaType.APPLICATION_JSON_VALUE)
            .contentType(MediaType.APPLICATION_JSON_VALUE);
    }

    static RestAssuredConfig requestConfig() {
        int connectTimeoutMillis = Math.toIntExact(CONNECT_TIMEOUT.toMillis());
        int requestTimeoutMillis = Math.toIntExact(REQUEST_TIMEOUT.toMillis());
        HttpClientConfig httpClientConfig = HttpClientConfig.httpClientConfig()
            .setParam(CONNECTION_TIMEOUT_PARAMETER, connectTimeoutMillis)
            .setParam(SOCKET_TIMEOUT_PARAMETER, requestTimeoutMillis)
            .setParam(CONNECTION_MANAGER_TIMEOUT_PARAMETER, (long) connectTimeoutMillis);

        return RestAssuredConfig.config()
            .httpClient(httpClientConfig)
            .logConfig(LogConfig.logConfig().blacklistHeader(HttpHeaders.AUTHORIZATION));
    }

    private static String withoutTrailingSlash(String url) {
        return url.endsWith("/") ? url.substring(0, url.length() - 1) : url;
    }
}
