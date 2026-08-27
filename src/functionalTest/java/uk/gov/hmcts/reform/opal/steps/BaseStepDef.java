package uk.gov.hmcts.reform.opal.steps;

import io.restassured.config.LogConfig;
import io.restassured.config.RestAssuredConfig;
import io.restassured.response.Response;
import io.restassured.specification.RequestSpecification;
import net.serenitybdd.rest.SerenityRest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;

public abstract class BaseStepDef {

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
        RestAssuredConfig config = RestAssuredConfig.config().logConfig(
            LogConfig.logConfig().blacklistHeader(HttpHeaders.AUTHORIZATION)
        );
        return SerenityRest.given()
            .config(config)
            .accept(MediaType.APPLICATION_JSON_VALUE)
            .contentType(MediaType.APPLICATION_JSON_VALUE);
    }

    private static String withoutTrailingSlash(String url) {
        return url.endsWith("/") ? url.substring(0, url.length() - 1) : url;
    }
}
