package uk.gov.hmcts.opal.controllers.advice;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import jakarta.validation.ConstraintViolationException;
import jakarta.validation.constraints.Min;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import uk.gov.hmcts.opal.BaseIntegrationTest;

@AutoConfigureMockMvc
@Import(RequestValidationExceptionHandlerIntegrationTest.RequestValidationTestController.class)
@TestPropertySource(properties = {
    "spring.flyway.locations=classpath:db/migration/ddl",
    "management.health.redis.enabled=false"
})
class RequestValidationExceptionHandlerIntegrationTest extends BaseIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

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
    void preservesSharedTypeMismatchProblemDetail() throws Exception {
        mockMvc.perform(get("/test-support/request-validation")
                .param("value", "not-an-integer")
                .with(user("test-user")))
            .andExpect(status().isNotAcceptable())
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
            .andExpect(jsonPath("$.type").value("https://hmcts.gov.uk/problems/type-mismatch"))
            .andExpect(jsonPath("$.title").value("Not Acceptable"))
            .andExpect(jsonPath("$.status").value(406));
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

    @Validated
    @RestController
    static class RequestValidationTestController {

        @GetMapping("/test-support/request-validation")
        String validate(@RequestParam(name = "value") @Min(1) Integer value) {
            return value.toString();
        }

        @GetMapping("/test-support/internal-constraint")
        String internalConstraint() {
            throw new ConstraintViolationException("internal validation failure", Set.of());
        }
    }
}
