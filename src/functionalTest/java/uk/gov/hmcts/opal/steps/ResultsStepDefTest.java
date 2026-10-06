package uk.gov.hmcts.opal.steps;

import static com.github.tomakehurst.wiremock.client.WireMock.anyRequestedFor;
import static com.github.tomakehurst.wiremock.client.WireMock.anyUrl;
import static com.github.tomakehurst.wiremock.core.WireMockConfiguration.options;
import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import com.github.tomakehurst.wiremock.WireMockServer;
import io.cucumber.datatable.DataTable;
import io.cucumber.datatable.DataTableTypeRegistry;
import io.cucumber.datatable.DataTableTypeRegistryTableConverter;
import io.restassured.builder.ResponseBuilder;
import io.restassured.response.Response;
import java.util.List;
import java.util.Locale;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

class ResultsStepDefTest {

    private static final String MATCHING_TARGET = "OPAL_RESULTS_TEST_URL";
    private static final String EMPTY_TARGET = "OPAL_RESULTS_EMPTY_TEST_URL";

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
        for (String setting : List.of(MATCHING_TARGET, EMPTY_TARGET)) {
            assertInvalidTarget(setting, null);
            assertInvalidTarget(setting, "");
            assertInvalidTarget(setting, " ");
        }
    }

    @Test
    void rejectsInvalidTargetsWithSettingNameOnly() {
        for (String setting : List.of(MATCHING_TARGET, EMPTY_TARGET)) {
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
        assertEquals("https://example.test/results", ResultsStepDef.validatedTarget(EMPTY_TARGET,
                                                                                 "https://example.test/results"));
    }

    @Test
    void requiresDistinctTargetsBeforeHttp() {
        WireMockServer server = new WireMockServer(options().dynamicPort());
        server.start();
        try {
            String target = "http://localhost:" + server.port();
            ResultsStepDef stepDef = configuredSteps(target, target + "/");
            IllegalStateException failure = assertThrows(IllegalStateException.class,
                                                        stepDef::requestUnauthenticatedResults);
            assertEquals(MATCHING_TARGET + " and " + EMPTY_TARGET + " must be distinct", failure.getMessage());
            server.verify(0, anyRequestedFor(anyUrl()));
        } finally {
            server.stop();
        }
    }

    @Test
    void requiresBothTargetsBeforeAnyRequest() {
        WireMockServer server = new WireMockServer(options().dynamicPort());
        server.start();
        try {
            String target = "http://localhost:" + server.port();
            for (String missingSetting : List.of(MATCHING_TARGET, EMPTY_TARGET)) {
                ResultsStepDef stepDef = configuredSteps(
                    MATCHING_TARGET.equals(missingSetting) ? null : target,
                    EMPTY_TARGET.equals(missingSetting) ? null : target
                );
                List<Runnable> requests = List.of(stepDef::requestActiveResults, stepDef::requestEmptyResults,
                                                 stepDef::requestMalformedResults,
                                                 stepDef::requestUnauthenticatedResults);
                for (Runnable request : requests) {
                    IllegalStateException failure = assertThrows(IllegalStateException.class, request::run);
                    assertEquals(missingSetting, failure.getMessage());
                }
            }
            server.verify(0, anyRequestedFor(anyUrl()));
        } finally {
            server.stop();
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
        return new ResultsStepDef() {
            @Override
            protected String environmentSetting(String setting) {
                return MATCHING_TARGET.equals(setting) ? matching : empty;
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
}
