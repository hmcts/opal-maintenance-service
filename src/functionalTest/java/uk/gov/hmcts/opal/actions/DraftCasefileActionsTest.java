package uk.gov.hmcts.opal.actions;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mockStatic;

import io.restassured.RestAssured;
import io.restassured.builder.ResponseBuilder;
import io.restassured.response.Response;
import io.restassured.specification.RequestSpecification;
import java.net.URI;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;
import net.serenitybdd.rest.SerenityRest;
import org.junit.jupiter.api.Test;
import org.mockito.MockedStatic;

class DraftCasefileActionsTest {

    @Test
    void retrievalUsesBearerAndExactDraftPath() {
        assertRequest("GET", null, null);
    }

    @Test
    void approvalUsesPatchBodyAndStrongIfMatch() {
        assertRequest("PATCH", "{\"decision\":\"APPROVE\"}", "\"4\"");
    }

    @Test
    void listPreservesDecodedQueryValuesWithoutInjectionOrDuplicates() {
        Map<String, String> filters = new LinkedHashMap<>();
        filters.put("business_unit_id", "44");
        filters.put("submitted_by", "Synthetic user+unit/one&restrict=counts");
        filters.put("casefile_status", "SUBMITTED,REJECTED");
        assertListRequest(filters);
    }

    @Test
    void listWithoutFiltersHasNoQueryDelimiter() {
        assertListRequest(Map.of());
    }

    @Test
    void replacementUsesInputterBodyAndIfMatch() {
        assertNewRequest("PUT", "/draft-casefiles/321", "synthetic-inputter-token", "{\"casefile\":{}}",
            "\"4\"", null);
    }

    @Test
    void evidenceRegistrationUsesCreatorAndRunReferenceWithoutBodyOrIfMatch() {
        assertNewRequest("POST", "/testing-support/draft-casefiles/321/publication-evidence",
            "synthetic-creator-token", null, null, "E2E-550e8400e29b41d4");
    }

    @Test
    void evidenceReadUsesCreatorAndRunReferenceWithoutBodyOrIfMatch() {
        assertNewRequest("GET", "/testing-support/draft-casefiles/321/publication-evidence",
            "synthetic-creator-token", null, null, "E2E-550e8400e29b41d4");
    }

    @Test
    void userStateUsesConfiguredUserServiceAndExplicitCheckerToken() {
        assertNewRequest("GET", "/v2/users/0/state", "synthetic-checker-token", null, null, null);
    }

    private void assertNewRequest(String method, String path, String token, String body, String etag, String marker) {
        AtomicBoolean requested = new AtomicBoolean();
        RequestSpecification request = RestAssured.given().filter((outgoing, response, context) -> {
            requested.set(true);
            assertThat(outgoing.getMethod()).isEqualTo(method);
            URI uri = URI.create(outgoing.getURI());
            assertThat(uri.getPath()).isEqualTo(path);
            if (path.startsWith("/v2/")) {
                String configured = System.getenv().getOrDefault("OPAL_USER_SERVICE_API_URL", "http://localhost:4555");
                assertThat(outgoing.getURI()).isEqualTo(configured.replaceFirst("/$", "") + path);
            }
            assertThat(outgoing.getHeaders().getValues("Authorization")).containsExactly("Bearer " + token);
            assertThat(outgoing.getHeaders().getValues("Accept")).containsExactly("application/json");
            assertThat(outgoing.getHeaders().getValue("Content-Type")).startsWith("application/json");
            assertThat(outgoing.getHeaders().getValue("If-Match")).isEqualTo(etag);
            assertThat(outgoing.getHeaders().getValue("Test-Run-Reference")).isEqualTo(marker);
            assertThat((String) outgoing.getBody()).isEqualTo(body);
            return new ResponseBuilder().setStatusCode(200).setBody("{}").build();
        });
        try (MockedStatic<SerenityRest> http = mockStatic(SerenityRest.class)) {
            http.when(SerenityRest::given).thenReturn(request);
            DraftCasefileActions actions = new DraftCasefileActions();
            if ("PUT".equals(method)) {
                actions.replace(token, 321L, body, etag);
            } else if ("POST".equals(method)) {
                actions.registerPublicationEvidence(token, 321L, marker);
            } else if (marker != null) {
                actions.publicationEvidence(token, 321L, marker);
            } else {
                actions.userState(token);
            }
            assertThat(requested).isTrue();
        }
    }

    private void assertListRequest(Map<String, String> filters) {
        AtomicBoolean requested = new AtomicBoolean();
        RequestSpecification request = RestAssured.given().filter((outgoing, response, context) -> {
            requested.set(true);
            URI uri = URI.create(outgoing.getURI());
            assertThat(outgoing.getMethod()).isEqualTo("GET");
            assertThat(uri.getPath()).isEqualTo("/draft-casefiles");
            assertThat(outgoing.getHeaders().getValue("Authorization")).isEqualTo("Bearer synthetic-test-token");
            Map<String, String> decoded = new LinkedHashMap<>();
            if (uri.getRawQuery() == null) {
                assertThat(filters).isEmpty();
                assertThat(outgoing.getURI()).doesNotContain("?");
            } else {
                for (String parameter : uri.getRawQuery().split("&")) {
                    String[] pair = parameter.split("=", 2);
                    String key = URLDecoder.decode(pair[0], StandardCharsets.UTF_8);
                    assertThat(decoded).doesNotContainKey(key);
                    decoded.put(key, URLDecoder.decode(pair[1], StandardCharsets.UTF_8));
                }
            }
            assertThat(decoded).isEqualTo(filters);
            return new ResponseBuilder().setStatusCode(200).setBody("{}").build();
        });
        try (MockedStatic<SerenityRest> http = mockStatic(SerenityRest.class)) {
            http.when(SerenityRest::given).thenReturn(request);
            Response result = new DraftCasefileActions().list("synthetic-test-token", filters);
            assertThat(requested).isTrue();
            assertThat(result.statusCode()).isEqualTo(200);
        }
    }

    private void assertRequest(String method, String body, String etag) {
        AtomicBoolean requested = new AtomicBoolean();
        RequestSpecification request = RestAssured.given().filter((outgoing, response, context) -> {
            requested.set(true);
            assertThat(outgoing.getMethod()).isEqualTo(method);
            assertThat(outgoing.getURI()).endsWith("/draft-casefiles/321");
            assertThat(outgoing.getHeaders().getValue("Authorization")).isEqualTo("Bearer synthetic-test-token");
            assertThat(outgoing.getHeaders().getValue("If-Match")).isEqualTo(etag);
            if (body != null) {
                assertThat((String) outgoing.getBody()).isEqualTo(body);
            }
            return new ResponseBuilder().setStatusCode(200).setBody("{}").build();
        });
        try (MockedStatic<SerenityRest> http = mockStatic(SerenityRest.class)) {
            http.when(SerenityRest::given).thenReturn(request);
            DraftCasefileActions actions = new DraftCasefileActions();
            Response result = body == null ? actions.get("synthetic-test-token", 321L)
                : actions.decide("synthetic-test-token", 321L, body, etag);
            assertThat(requested).isTrue();
            assertThat(result.statusCode()).isEqualTo(200);
        }
    }

    @Test
    void cleanupSendsTheCreatorTokenAndExactRunReferenceToTheMergedEndpoint() {
        String marker = "E2E-550e8400e29b41d4";
        AtomicBoolean requested = new AtomicBoolean();
        RequestSpecification request = RestAssured.given().filter((outgoing, response, context) -> {
            requested.set(true);
            assertThat(outgoing.getMethod()).isEqualTo("DELETE");
            assertThat(outgoing.getURI()).endsWith("/testing-support/draft-casefiles/123");
            assertThat(outgoing.getHeaders().getValues("Test-Run-Reference")).containsExactly(marker);
            assertThat(outgoing.getHeaders().getValues("Accept")).containsExactly("application/problem+json");
            assertThat(outgoing.getHeaders().getValue("Authorization")).isEqualTo("Bearer synthetic-test-token");
            return new ResponseBuilder().setStatusCode(204).setBody("").build();
        });
        try (MockedStatic<SerenityRest> http = mockStatic(SerenityRest.class)) {
            http.when(SerenityRest::given).thenReturn(request);

            Response cleanup = new DraftCasefileActions().delete("synthetic-test-token", 123L, marker);

            assertThat(requested).isTrue();
            assertThat(cleanup.statusCode()).isEqualTo(204);
        }
    }
}
