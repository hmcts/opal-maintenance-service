package uk.gov.hmcts.opal.steps;

import static com.github.tomakehurst.wiremock.client.WireMock.get;
import static com.github.tomakehurst.wiremock.client.WireMock.getRequestedFor;
import static com.github.tomakehurst.wiremock.client.WireMock.okJson;
import static com.github.tomakehurst.wiremock.client.WireMock.urlEqualTo;
import static com.github.tomakehurst.wiremock.core.WireMockConfiguration.options;
import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mockStatic;

import com.github.tomakehurst.wiremock.WireMockServer;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import io.cucumber.datatable.DataTable;
import io.cucumber.datatable.DataTableTypeRegistry;
import io.cucumber.datatable.DataTableTypeRegistryTableConverter;
import io.restassured.builder.ResponseBuilder;
import io.restassured.response.Response;
import java.util.List;
import java.util.Locale;
import org.junit.jupiter.api.Test;
import org.mockito.MockedStatic;
import org.springframework.http.MediaType;

class ResultsStepDefTest {

    private static final ObjectMapper MAPPER = new ObjectMapper();
    private static final String META = "[{\"name\":\"Custom\",\"type\":\"synthetic-unfamiliar\"}]";

    private static final String MATCHING_TARGET = "TEST_URL";
    private static final String EMPTY_TARGET = "OPAL_RESULTS_EMPTY_TEST_URL";
    private static final String DETAIL_TARGET = "OPAL_RESULTS_DETAIL_TEST_URL";

    @Test
    void emptyRequestUsesNormalServiceAndInactiveFilter() {
        Response empty = new ResponseBuilder().setStatusCode(200)
            .setContentType(MediaType.APPLICATION_JSON_VALUE)
            .setBody("{\"count\":0,\"refData\":[]}").build();
        try (MockedStatic<BaseStepDef> http = mockStatic(BaseStepDef.class);
             MockedStatic<BearerTokenStepDef> token = mockStatic(BearerTokenStepDef.class)) {
            token.when(BearerTokenStepDef::getToken).thenReturn("synthetic-test-token");
            http.when(() -> BaseStepDef.getWithBearer(
                "https://example.test", "/results?order_term=true&active=false", "synthetic-test-token"))
                .thenReturn(empty);
            ResultsStepDef steps = normalServiceSteps("https://example.test/");
            steps.requestEmptyResults();
            assertSame(empty, steps.latestResponse());
            http.verify(() -> BaseStepDef.getWithBearer(
                "https://example.test", "/results?order_term=true&active=false", "synthetic-test-token"));
        }
    }

    @Test
    void rejectsResultsInAnUnexpectedDisplayOrder() {
        DataTable expected = DataTable.create(List.of(
            List.of("result_id", "result_title"),
            List.of("MLUMP", "Lump sum order"),
            List.of("MCHILD", "Maintenance Order for child(ren)")
        ), new DataTableTypeRegistryTableConverter(new DataTableTypeRegistry(Locale.UK)));
        assertThrows(AssertionError.class, () -> ResultsStepDef.assertExpectedResults("""
            {"count":2,"refData":[
              {"result_id":"MCHILD","result_title":"Maintenance Order for child(ren)"},
              {"result_id":"MLUMP","result_title":"Lump sum order"}
            ]}
            """, expected));
    }

    @Test
    void rejectsUnrelatedResultEvenWhenExpectedResultIsPresent() {
        DataTable expected = expectedResults();
        assertThrows(AssertionError.class, () -> ResultsStepDef.assertExpectedResults("""
            {"count":2,"refData":[
              {"result_id":"MAT","result_title":"Matrimonial Order for Adult"},
              {"result_id":"MNSTD","result_title":"Non-standard order"}
            ]}
            """, expected));
    }

    @Test
    void rejectsNonEmptyResponseReportedWithZeroCount() {
        assertThrows(AssertionError.class, () -> ResultsStepDef.assertEmptyResults("""
            {"count":0,"refData":[
              {"result_id":"MAT","result_title":"Matrimonial Order for Adult"}
            ]}
            """));
    }

    @Test
    void acceptsExactExpectedResults() {
        assertDoesNotThrow(() -> ResultsStepDef.assertExpectedResults("""
            {"count":1,"refData":[{"result_id":"MAT","result_title":"Matrimonial Order for Adult"}]}
            """, expectedResults()));
    }

    @Test
    void acceptsEmptyResults() {
        assertDoesNotThrow(() -> ResultsStepDef.assertEmptyResults("""
            {"count":0,"refData":[]}
            """));
    }

    @Test
    void rejectsMissingExpectedResult() {
        assertInvalidResults("""
            {"count":0,"refData":[]}
            """);
    }

    @Test
    void rejectsDuplicateResultIdentifiers() {
        assertInvalidResults("""
            {"count":2,"refData":[
              {"result_id":"MAT","result_title":"Matrimonial Order for Adult"},
              {"result_id":"MAT","result_title":"Matrimonial Order for Adult"}
            ]}
            """);
    }

    @Test
    void rejectsWrongResultTitle() {
        assertInvalidResults("""
            {"count":1,"refData":[{"result_id":"MAT","result_title":"Another title"}]}
            """);
    }

    @Test
    void rejectsInconsistentCount() {
        assertInvalidResults("""
            {"count":2,"refData":[{"result_id":"MAT","result_title":"Matrimonial Order for Adult"}]}
            """);
    }

    @Test
    void rejectsBlankResultCode() {
        assertInvalidResults("""
            {"count":1,"refData":[{"result_id":" ","result_title":"Matrimonial Order for Adult"}]}
            """);
    }

    @Test
    void rejectsBlankResultTitle() {
        assertInvalidResults("""
            {"count":1,"refData":[{"result_id":"MAT","result_title":" "}]}
            """);
    }

    @Test
    void rejectsMissingResultsArray() {
        assertInvalidResults("""
            {"count":1}
            """);
    }

    @Test
    void rejectsMissingEmptyResultsArray() {
        assertThrows(AssertionError.class, () -> ResultsStepDef.assertEmptyResults("""
            {"count":0}
            """));
    }

    @Test
    void rejectsNonZeroEmptyResultsCount() {
        assertThrows(AssertionError.class, () -> ResultsStepDef.assertEmptyResults("""
            {"count":1,"refData":[]}
            """));
    }

    @Test
    void acceptsValidationProblemDetails() {
        ResultsStepDef stepDef = new ResultsStepDef();
        stepDef.latestResponse(validationResponse("\"operation_id\":\"test-operation-id\",", ""));
        assertDoesNotThrow(stepDef::assertValidationProblemDetails);
    }

    @Test
    void rejectsValidationProblemDetailsWithoutOperationId() {
        ResultsStepDef stepDef = new ResultsStepDef();
        stepDef.latestResponse(validationResponse("", ""));
        assertThrows(AssertionError.class, stepDef::assertValidationProblemDetails);
    }

    @Test
    void rejectsValidationProblemDetailsEchoingRejectedValue() {
        ResultsStepDef stepDef = new ResultsStepDef();
        stepDef.latestResponse(validationResponse(
            "\"operation_id\":\"test-operation-id\",", ",\"extra\":\"not-a-boolean\""));
        assertThrows(AssertionError.class, stepDef::assertValidationProblemDetails);
    }

    @Test
    void acceptsUnauthorizedProblemDetails() {
        ResultsStepDef stepDef = new ResultsStepDef();
        stepDef.latestResponse(unauthorizedResponse(""));
        assertDoesNotThrow(stepDef::assertUnauthorizedProblemDetails);
    }

    @Test
    void rejectsUnauthorizedProblemDetailsContainingResults() {
        ResultsStepDef stepDef = new ResultsStepDef();
        stepDef.latestResponse(unauthorizedResponse(",\"refData\":[]"));
        assertThrows(AssertionError.class, stepDef::assertUnauthorizedProblemDetails);
    }

    @Test
    void rejectsMissingOrBlankTargetsWithSettingNameOnly() {
        for (String setting : List.of(MATCHING_TARGET)) {
            assertInvalidTarget(setting, null);
            assertInvalidTarget(setting, "");
            assertInvalidTarget(setting, " ");
        }
    }

    @Test
    void rejectsInvalidTargetsWithSettingNameOnly() {
        for (String setting : List.of(MATCHING_TARGET)) {
            for (String value : List.of(
                "not a URL", "ftp://localhost", "http:///results", "http://localhost:0",
                "http://localhost:65536", "http://localhost?filter=value", "http://localhost#fragment",
                "http://userinfo@localhost"
            )) {
                assertInvalidTarget(setting, value);
            }
        }
    }

    @Test
    void acceptsHttpAndHttpsTargetsAndNormalizesTrailingSlash() {
        assertEquals("http://localhost:4551", ResultsStepDef.validatedTarget(MATCHING_TARGET,
                                                                           "http://localhost:4551/"));
        assertEquals("https://example.test/results", ResultsStepDef.validatedTarget(MATCHING_TARGET,
                                                                                 "https://example.test/results"));
    }

    @Test
    void normalUnauthenticatedRequestUsesOnlyTestUrl() {
        WireMockServer server = new WireMockServer(options().dynamicPort());
        server.start();
        try {
            server.stubFor(get(urlEqualTo("/results?order_term=true&active=true"))
                .willReturn(okJson("{\"count\":0,\"refData\":[]}")));
            ResultsStepDef steps = normalServiceSteps("http://localhost:" + server.port() + "/");
            steps.requestUnauthenticatedResults();
            assertEquals(200, steps.latestResponse().statusCode());
            server.verify(1, getRequestedFor(urlEqualTo("/results?order_term=true&active=true")));
        } finally {
            server.stop();
        }
    }

    @Test
    void normalTargetUsesLocalhostFallback() {
        assertEquals("http://localhost:4551", normalServiceSteps(null).resultsTarget());
    }

    @Test
    void emptyRequestRejectsInvalidNormalTargetBeforeHttp() {
        IllegalStateException failure = assertThrows(IllegalStateException.class,
            () -> normalServiceSteps("not a URL").requestEmptyResults());
        assertEquals("TEST_URL", failure.getMessage());
    }

    @Test
    void detailTargetFallsBackToValidatedTestUrlWithoutEmptyTarget() {
        ResultsStepDef stepDef = configuredSteps("http://localhost:4551/", null, null);
        assertEquals("http://localhost:4551", stepDef.detailTarget());
    }

    @Test
    void detailTargetUsesLocalhostFallbackWithoutConfiguredTargets() {
        ResultsStepDef stepDef = configuredSteps(null, null, null);
        assertEquals("http://localhost:4551", stepDef.detailTarget());
    }

    @Test
    void detailTargetNormalizesExplicitUrl() {
        ResultsStepDef stepDef = configuredSteps("not a URL", null, "https://example.test/details/");
        assertEquals("https://example.test/details", stepDef.detailTarget());
    }

    @Test
    void detailTargetRejectsExplicitBlankOrInvalidUrl() {
        for (String value : List.of("", " ", "ftp://example.test", "https://example.test?query=yes")) {
            ResultsStepDef stepDef = configuredSteps("http://localhost:4551", null, value);
            IllegalStateException failure = assertThrows(IllegalStateException.class, stepDef::detailTarget);
            assertEquals(DETAIL_TARGET, failure.getMessage());
        }
    }

    @Test
    void unauthenticatedDetailRequestUsesDetailTargetBeforeMatchingTarget() {
        WireMockServer matching = new WireMockServer(options().dynamicPort());
        WireMockServer detail = new WireMockServer(options().dynamicPort());
        matching.start();
        detail.start();
        try {
            detail.stubFor(get(urlEqualTo("/results/Q301T1"))
                .willReturn(okJson("{\"result_id\":\"Q301T1\"}")));
            ResultsStepDef stepDef = configuredSteps("http://localhost:" + matching.port(), null,
                "http://localhost:" + detail.port());
            stepDef.selectResult("Q301T1");
            stepDef.requestSelectedResultWithoutAuthentication();
            assertEquals(200, stepDef.latestResponse().statusCode());
            detail.verify(1, getRequestedFor(urlEqualTo("/results/Q301T1")));
            matching.verify(0, anyRequestedFor(anyUrl()));
        } finally {
            detail.stop();
            matching.stop();
        }
    }

    private DataTable expectedResults() {
        return DataTable.create(List.of(
            List.of("result_id", "result_title"),
            List.of("MAT", "Matrimonial Order for Adult")
        ), new DataTableTypeRegistryTableConverter(new DataTableTypeRegistry(Locale.UK)));
    }

    private void assertInvalidResults(String body) {
        assertThrows(AssertionError.class, () -> ResultsStepDef.assertExpectedResults(body, expectedResults()));
    }

    private void assertInvalidTarget(String setting, String value) {
        IllegalStateException failure = assertThrows(IllegalStateException.class,
                                                    () -> ResultsStepDef.validatedTarget(setting, value));
        assertEquals(setting, failure.getMessage());
    }

    private ResultsStepDef configuredSteps(String matching, String empty) {
        return configuredSteps(matching, empty, null);
    }

    private ResultsStepDef configuredSteps(String matching, String empty, String detail) {
        return new ResultsStepDef() {
            @Override
            protected String environmentSetting(String setting) {
                return switch (setting) {
                    case MATCHING_TARGET -> matching;
                    case EMPTY_TARGET -> empty;
                    case DETAIL_TARGET -> detail;
                    default -> null;
                };
            }
        };
    }

    private ResultsStepDef normalServiceSteps(String target) {
        return new ResultsStepDef() {
            @Override
            protected String environmentSetting(String setting) {
                return "TEST_URL".equals(setting) ? target : null;
            }
        };
    }

    private Response validationResponse(String operationIdField, String additionalField) {
        return new ResponseBuilder()
            .setStatusCode(400)
            .setContentType(MediaType.APPLICATION_PROBLEM_JSON_VALUE)
            .setBody("""
                {
                  "type":"https://hmcts.gov.uk/problems/type-mismatch",
                  "title":"Bad Request",
                  "status":400,
                  "detail":"Parameter 'order_term' must be of type Boolean",
                  "instance":"/results",
                  %s
                  "retriable":false%s
                }
                """.formatted(operationIdField, additionalField))
            .build();
    }

    private Response unauthorizedResponse(String additionalField) {
        return new ResponseBuilder()
            .setStatusCode(401)
            .setContentType(MediaType.APPLICATION_PROBLEM_JSON_VALUE)
            .setBody("""
                {
                  "type":"https://hmcts.gov.uk/problems/unauthorized",
                  "title":"Unauthorized",
                  "status":401,
                  "detail":"You are not authorized to access this resource",
                  "instance":"/results",
                  "operation_id":"test-operation-id",
                  "retriable":false%s
                }
                """.formatted(additionalField))
            .build();
    }

    @Test
    void acceptsUnchangedMetadata() {
        assertDoesNotThrow(() -> ResultsStepDef.assertResultResponse(
            result("Q301U1", "Synthetic result", META), "Q301U1", "Synthetic result", META));
    }

    @Test
    void rejectsWrongIdentity() {
        assertThrows(AssertionError.class, () -> ResultsStepDef.assertResultResponse(
            result("Q301I1", "Synthetic result", META), "Q301U1", "Synthetic result", META));
    }

    @Test
    void rejectsWrongTitle() {
        assertThrows(AssertionError.class, () -> ResultsStepDef.assertResultResponse(
            result("Q301U1", "Wrong result", META), "Q301U1", "Synthetic result", META));
    }

    @Test
    void rejectsChangedMetadata() {
        assertThrows(AssertionError.class, () -> ResultsStepDef.assertResultResponse(
            result("Q301U1", "Synthetic result", "[]"), "Q301U1", "Synthetic result", META));
    }

    @Test
    void rejectsMetadataReturnedAsAnObject() {
        ObjectNode body = resultBody("Q301U1", "Synthetic result", META);
        body.set("result_parameters", MAPPER.createObjectNode().put("name", "Custom"));
        assertThrows(AssertionError.class, () -> ResultsStepDef.assertResultResponse(
            response(200, body), "Q301U1", "Synthetic result", META));
    }

    @Test
    void acceptsExplicitNull() {
        assertDoesNotThrow(() -> ResultsStepDef.assertResultResponse(
            result("Q301N1", "Synthetic result", null), "Q301N1", "Synthetic result", null));
    }

    @Test
    void rejectsMissingNullField() {
        ObjectNode body = resultBody("Q301N1", "Synthetic result", null);
        body.remove("result_parameters");
        assertThrows(AssertionError.class, () -> ResultsStepDef.assertResultResponse(
            response(200, body), "Q301N1", "Synthetic result", null));
    }

    @Test
    void distinguishesNullFromEmptyMetadata() {
        assertThrows(AssertionError.class, () -> ResultsStepDef.assertResultResponse(
            result("Q301E1", "Synthetic result", null), "Q301E1", "Synthetic result", "[]"));
    }

    @Test
    void rejectsAmountMandatoryFlagAsText() {
        String metadata = "[{\"name\":\"Amount\",\"prompt\":\"Amount\",\"type\":\"decimal-2dp\","
            + "\"mandatory\":\"true\",\"min\":0,\"max\":10000}]";
        assertThrows(AssertionError.class, () -> ResultsStepDef.assertAmountMetadata(
            result("Q301A1", "Synthetic result", metadata)));
    }

    @Test
    void acceptsCorrelatedNotFoundWithoutResultData() {
        assertDoesNotThrow(() -> ResultsStepDef.assertMissingResultResponse(response(404, problem(404))));
    }

    @Test
    void rejectsMissingCorrelation() {
        ObjectNode body = problem(404);
        body.remove("operation_id");
        assertThrows(AssertionError.class,
            () -> ResultsStepDef.assertMissingResultResponse(response(404, body)));
    }

    @Test
    void rejectsUnauthorizedResultDisclosure() {
        ObjectNode body = problem(401);
        body.put("result_parameters", META);
        assertThrows(AssertionError.class,
            () -> ResultsStepDef.assertUnauthorizedResultResponse(response(401, body)));
    }

    private static Response result(String id, String title, String metadata) {
        return response(200, resultBody(id, title, metadata));
    }

    private static ObjectNode resultBody(String id, String title, String metadata) {
        ObjectNode body = MAPPER.createObjectNode().put("result_id", id).put("result_title", title);
        if (metadata == null) {
            body.putNull("result_parameters");
        } else {
            body.put("result_parameters", metadata);
        }
        return body;
    }

    private static ObjectNode problem(int status) {
        boolean missing = status == 404;
        ObjectNode body = MAPPER.createObjectNode()
            .put("type", "https://hmcts.gov.uk/problems/" + (missing ? "entity-not-found" : "unauthorized"))
            .put("title", missing ? "Entity Not Found" : "Unauthorized")
            .put("status", status)
            .put("detail", missing ? "The requested entity could not be found"
                : "You are not authorized to access this resource")
            .put("instance", "/results/Q301X1")
            .put("operation_id", "synthetic-operation-id")
            .put("retriable", false);
        if (missing) {
            body.put("reason", "Result not found");
        }
        return body;
    }

    private static Response response(int status, ObjectNode body) {
        return new ResponseBuilder().setStatusCode(status)
            .setContentType(status == 200 ? "application/json" : "application/problem+json")
            .setBody(body.toString()).build();
    }
}
