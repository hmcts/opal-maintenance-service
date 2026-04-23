package uk.gov.hmcts.reform.opal.controllers;

import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;

class SampleSmokeTest {
    private static final String TEST_URL = System.getenv().getOrDefault("TEST_URL", "http://localhost:4551");
    private static final HttpClient HTTP_CLIENT = HttpClient.newHttpClient();

    @Test
    void smokeTest() throws IOException, InterruptedException {
        HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create(TEST_URL + "/"))
            .GET()
            .build();

        HttpResponse<String> response = HTTP_CLIENT.send(request, HttpResponse.BodyHandlers.ofString());

        Assertions.assertEquals(200, response.statusCode());
        Assertions.assertTrue(response.body().startsWith("Welcome"));
    }
}
