package uk.gov.hmcts.opal.steps;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.cucumber.java.After;
import io.cucumber.java.Before;
import io.cucumber.java.en.Given;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;

public class BearerTokenStepDef extends BaseStepDef {

    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();
    private static final HttpClient TOKEN_HTTP_CLIENT = HttpClient.newBuilder()
        .connectTimeout(CONNECT_TIMEOUT)
        .build();
    private static final ThreadLocal<String> TOKEN = new ThreadLocal<>();

    @Before
    public void resetToken() {
        TOKEN.remove();
    }

    @After
    public void clearToken() {
        TOKEN.remove();
    }

    @Given("I am testing as the {string} user")
    public void useTestUser(String userEmail) {
        TOKEN.set(fetchToken(userEmail));
    }

    public static String getToken() {
        String token = TOKEN.get();
        if (token == null || token.isBlank()) {
            throw new IllegalStateException("No bearer token is configured for this scenario");
        }
        return token;
    }

    private static String fetchToken(String userEmail) {
        HttpRequest request = tokenRequest(userEmail);

        try {
            HttpResponse<String> response = tokenHttpClient().send(
                request,
                HttpResponse.BodyHandlers.ofString()
            );
            if (response.statusCode() != 200) {
                throw new IllegalStateException(
                    "Failed to fetch functional-test access token, status: " + response.statusCode()
                );
            }

            JsonNode body = OBJECT_MAPPER.readTree(response.body());
            String token = body.path("access_token").asText();
            if (token.isBlank()) {
                throw new IllegalStateException("User Service returned a blank functional-test access token");
            }
            return token;
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Interrupted while fetching functional-test access token", exception);
        } catch (IOException exception) {
            throw new IllegalStateException("Failed to fetch functional-test access token", exception);
        }
    }

    static HttpClient tokenHttpClient() {
        return TOKEN_HTTP_CLIENT;
    }

    static HttpRequest tokenRequest(String userEmail) {
        return HttpRequest.newBuilder()
            .uri(URI.create(userServiceUrl() + "/testing-support/token/user"))
            .timeout(REQUEST_TIMEOUT)
            .header("Accept", "application/json")
            .header("Content-Type", "application/json")
            .header("X-User-Email", userEmail)
            .GET()
            .build();
    }
}
