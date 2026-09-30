package uk.gov.hmcts.opal.steps;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;

import io.restassured.builder.ResponseBuilder;
import io.restassured.response.Response;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

class MaintenanceApplicationsStepDefTest {

    @Test
    void acceptsActiveCreateCasefileApplicationsWithRepresentativeRecord() {
        assertDoesNotThrow(() -> MaintenanceApplicationsStepDef.assertActiveMaintenanceApplicationsResponse("""
            {
              "count": 2,
              "refData": [
                {
                  "application_id": 101,
                  "application_code": "AP00001",
                  "application_title": "Application to Appeal",
                  "application_group": "Create Casefile",
                  "active": true
                },
                {
                  "application_id": 102,
                  "application_code": "MO72001",
                  "application_title": "Applications for a Provisional Order to be confirmed",
                  "application_group": "Create Casefile",
                  "active": true
                }
              ]
            }
            """));
    }

    @Test
    void rejectsInactiveApplicationFromActiveResponse() {
        assertInvalidActiveResponse("""
            {
              "count": 1,
              "refData": [{
                "application_id": 101,
                "application_code": "AP00001",
                "application_title": "Application to Appeal",
                "application_group": "Create Casefile",
                "active": false
              }]
            }
            """);
    }

    @Test
    void rejectsApplicationFromAnotherGroup() {
        assertInvalidActiveResponse("""
            {
              "count": 1,
              "refData": [{
                "application_id": 101,
                "application_code": "AP00001",
                "application_title": "Application to Appeal",
                "application_group": "Other",
                "active": true
              }]
            }
            """);
    }

    @Test
    void rejectsBlankApplicationCode() {
        assertInvalidActiveResponse("""
            {
              "count": 1,
              "refData": [{
                "application_id": 101,
                "application_code": " ",
                "application_title": "Application to Appeal",
                "application_group": "Create Casefile",
                "active": true
              }]
            }
            """);
    }

    @Test
    void rejectsDuplicateApplicationIdentifiers() {
        assertInvalidActiveResponse("""
            {
              "count": 2,
              "refData": [
                {
                  "application_id": 101,
                  "application_code": "AP00001",
                  "application_title": "Application to Appeal",
                  "application_group": "Create Casefile",
                  "active": true
                },
                {
                  "application_id": 101,
                  "application_code": "MO72001",
                  "application_title": "Another Application",
                  "application_group": "Create Casefile",
                  "active": true
                }
              ]
            }
            """);
    }

    @Test
    void rejectsResponseWithoutRepresentativeApplication() {
        assertInvalidActiveResponse("""
            {
              "count": 1,
              "refData": [{
                "application_id": 102,
                "application_code": "MO72001",
                "application_title": "Applications for a Provisional Order to be confirmed",
                "application_group": "Create Casefile",
                "active": true
              }]
            }
            """);
    }

    @Test
    void acceptsEmptyInactiveResponse() {
        assertDoesNotThrow(() -> MaintenanceApplicationsStepDef.assertEmptyMaintenanceApplicationsResponse("""
            {"count": 0, "refData": []}
            """));
    }

    @Test
    void rejectsNonEmptyInactiveResponse() {
        assertThrows(AssertionError.class, () ->
            MaintenanceApplicationsStepDef.assertEmptyMaintenanceApplicationsResponse("""
                {
                  "count": 1,
                  "refData": [{
                    "application_id": 101,
                    "application_code": "AP00001",
                    "application_title": "Application to Appeal",
                    "application_group": "Create Casefile",
                    "active": false
                  }]
                }
                """));
    }

    @Test
    void acceptsCurrentValidationProblemDetails() {
        MaintenanceApplicationsStepDef stepDef = new MaintenanceApplicationsStepDef();
        stepDef.latestResponse(validationResponse(""));

        assertDoesNotThrow(stepDef::assertMaintenanceApplicationValidationProblemDetails);
    }

    @Test
    void rejectsValidationProblemDetailsThatExposeRejectedValue() {
        MaintenanceApplicationsStepDef stepDef = new MaintenanceApplicationsStepDef();
        stepDef.latestResponse(validationResponse(", \"reason\": \"not-a-boolean\""));

        assertThrows(AssertionError.class, stepDef::assertMaintenanceApplicationValidationProblemDetails);
    }

    private void assertInvalidActiveResponse(String body) {
        assertThrows(
            AssertionError.class,
            () -> MaintenanceApplicationsStepDef.assertActiveMaintenanceApplicationsResponse(body)
        );
    }

    private Response validationResponse(String additionalField) {
        return new ResponseBuilder()
            .setStatusCode(400)
            .setContentType(MediaType.APPLICATION_PROBLEM_JSON_VALUE)
            .setBody("""
                {
                  "type": "https://hmcts.gov.uk/problems/type-mismatch",
                  "title": "Bad Request",
                  "status": 400,
                  "detail": "Parameter 'active' must be of type Boolean",
                  "instance": "/maintenance-applications",
                  "operation_id": "test-operation-id",
                  "retriable": false%s
                }
                """.formatted(additionalField))
            .build();
    }
}
