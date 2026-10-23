package uk.gov.hmcts.opal.actions;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mockStatic;

import io.restassured.RestAssured;
import io.restassured.builder.ResponseBuilder;
import io.restassured.response.Response;
import io.restassured.specification.RequestSpecification;
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
