package uk.gov.hmcts.opal.controllers.advice;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import jakarta.validation.ConstraintViolationException;
import jakarta.validation.constraints.Min;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import uk.gov.hmcts.common.exceptions.standard.UnauthorizedException;
import uk.gov.hmcts.opal.BaseIntegrationTest;

@AutoConfigureMockMvc
@ExtendWith(OutputCaptureExtension.class)
@Import(MaintenanceGlobalExceptionHandlerIntegrationTest.RequestValidationTestController.class)
@TestPropertySource(properties = {
    "spring.flyway.locations=classpath:db/migration/ddl",
    "management.health.redis.enabled=false"
})
class MaintenanceGlobalExceptionHandlerIntegrationTest extends BaseIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void returnsUnauthorizedProblemDetailWithoutDisclosingExceptionDetails() throws Exception {
        mockMvc.perform(get("/test-support/unauthorized").with(user("test-user")))
            .andExpect(status().isUnauthorized())
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
            .andExpect(jsonPath("$.type").value("https://hmcts.gov.uk/problems/unauthorized"))
            .andExpect(jsonPath("$.title").value("Unauthorized"))
            .andExpect(jsonPath("$.detail").value("Missing or invalid access token"))
            .andExpect(jsonPath("$.status").value(401))
            .andExpect(jsonPath("$.operation_id").isNotEmpty())
            .andExpect(jsonPath("$.retriable").value(false));
    }

    @Test
    void returnsBadRequestProblemDetailWhenRequiredParameterIsMissing() throws Exception {
        mockMvc.perform(get("/test-support/request-validation").with(user("test-user")))
            .andExpect(status().isBadRequest())
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
            .andExpect(jsonPath("$.type")
                .value("https://hmcts.gov.uk/problems/missing-required-parameter"))
            .andExpect(jsonPath("$.title").value("Bad Request"))
            .andExpect(jsonPath("$.detail").value("A required request parameter is missing"))
            .andExpect(jsonPath("$.status").value(400))
            .andExpect(jsonPath("$.instance").isNotEmpty())
            .andExpect(jsonPath("$.operation_id").isNotEmpty())
            .andExpect(jsonPath("$.retriable").value(false));
    }

    @Test
    void returnsBadRequestProblemDetailForControllerParameterConstraintViolation() throws Exception {
        mockMvc.perform(get("/test-support/request-validation")
                .param("value", "0")
                .with(user("test-user")))
            .andExpect(status().isBadRequest())
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
            .andExpect(jsonPath("$.type").value("https://hmcts.gov.uk/problems/constraint-violation"))
            .andExpect(jsonPath("$.title").value("Bad Request"))
            .andExpect(jsonPath("$.detail").value("A request parameter value violates its constraints"))
            .andExpect(jsonPath("$.status").value(400))
            .andExpect(jsonPath("$.instance").isNotEmpty())
            .andExpect(jsonPath("$.operation_id").isNotEmpty())
            .andExpect(jsonPath("$.retriable").value(false));
    }

    @Test
    void returnsBadRequestForParameterTypeMismatch() throws Exception {
        mockMvc.perform(get("/test-support/request-validation")
                .param("value", "not-an-integer")
                .with(user("test-user")))
            .andExpect(status().isBadRequest())
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
            .andExpect(jsonPath("$.type").value("https://hmcts.gov.uk/problems/type-mismatch"))
            .andExpect(jsonPath("$.title").value("Bad Request"))
            .andExpect(jsonPath("$.status").value(400))
            .andExpect(jsonPath("$.detail").value("Parameter 'value' must be of type Integer"))
            .andExpect(jsonPath("$.reason").doesNotExist())
            .andExpect(jsonPath("$.operation_id").isNotEmpty())
            .andExpect(jsonPath("$.retriable").value(false));
    }

    @Test
    void returnsSanitisedServerProblemDetailForNonRequestConstraintViolation() throws Exception {
        mockMvc.perform(get("/test-support/internal-constraint").with(user("test-user")))
            .andExpect(status().isInternalServerError())
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
            .andExpect(jsonPath("$.type").value("https://hmcts.gov.uk/problems/internal-server-error"))
            .andExpect(jsonPath("$.title").value("Internal Server Error"))
            .andExpect(jsonPath("$.detail")
                .value("An unexpected error occurred while processing your request"))
            .andExpect(jsonPath("$.status").value(500))
            .andExpect(jsonPath("$.instance").isNotEmpty())
            .andExpect(jsonPath("$.operation_id").isNotEmpty())
            .andExpect(jsonPath("$.retriable").value(false));
    }

    @Test
    void returnsSafeCorrelatedServerProblemWithoutLoggingIllegalStateDetails(CapturedOutput output) throws Exception {
        var result = mockMvc.perform(get("/test-support/illegal-state").with(user("test-user")))
            .andExpect(status().isInternalServerError())
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
            .andExpect(jsonPath("$.type").value("https://hmcts.gov.uk/problems/internal-server-error"))
            .andExpect(jsonPath("$.title").value("Internal Server Error"))
            .andExpect(jsonPath("$.detail")
                .value("An unexpected error occurred while processing your request"))
            .andExpect(jsonPath("$.status").value(500))
            .andExpect(jsonPath("$.instance").isNotEmpty())
            .andExpect(jsonPath("$.operation_id").isNotEmpty())
            .andExpect(jsonPath("$.retriable").value(false))
            .andReturn();
        String response = result.getResponse().getContentAsString();
        String operationId = result.getResponse().getHeader("operation_id");
        assertThat(operationId).isNotBlank();
        assertThat(response).contains(operationId);
        assertThat(response).doesNotContain("SYNTHETIC_PRIVATE_MESSAGE", "SYNTHETIC_PRIVATE_CAUSE");
        assertThat(output).doesNotContain("SYNTHETIC_PRIVATE_MESSAGE", "SYNTHETIC_PRIVATE_CAUSE");
    }

    @Validated
    @RestController
    static class RequestValidationTestController {

        @GetMapping("/test-support/unauthorized")
        String unauthorized() {
            throw new UnauthorizedException("Unauthorized", "Synthetic internal authentication details");
        }

        @GetMapping("/test-support/request-validation")
        String validate(@RequestParam(name = "value") @Min(1) Integer value) {
            return value.toString();
        }

        @GetMapping("/test-support/illegal-state")
        String illegalState() {
            throw new IllegalStateException("SYNTHETIC_PRIVATE_MESSAGE",
                new IllegalArgumentException("SYNTHETIC_PRIVATE_CAUSE"));
        }

        @GetMapping("/test-support/internal-constraint")
        String internalConstraint() {
            throw new ConstraintViolationException("internal validation failure", Set.of());
        }
    }
}
