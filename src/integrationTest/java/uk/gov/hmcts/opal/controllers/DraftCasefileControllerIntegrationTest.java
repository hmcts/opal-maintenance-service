package uk.gov.hmcts.opal.controllers;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.InvalidDataAccessResourceUsageException;
import org.springframework.http.MediaType;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import tools.jackson.databind.json.JsonMapper;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.dto.DraftCasefileSubmission;
import uk.gov.hmcts.opal.generated.model.DraftCasefileAddRequest;
import uk.gov.hmcts.opal.generated.model.DraftCasefileAddResponse;
import uk.gov.hmcts.opal.service.DraftCasefileService;
import uk.gov.hmcts.opal.support.DraftCasefileHttpFixture;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
@ExtendWith(OutputCaptureExtension.class)
@TestPropertySource(properties = {
    "spring.flyway.locations=classpath:db/migration/ddl",
    "opal.redis.enabled=false",
    "management.health.redis.enabled=false",
    "opal.openapi.max-request-body-bytes=4096"
})
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
class DraftCasefileControllerIntegrationTest extends BaseIntegrationTest {

    @Autowired
    private MockMvc mockMvc;
    @MockitoBean
    private DraftCasefileService service;
    private String validBody;

    @BeforeEach
    void setUp() throws Exception {
        validBody = DraftCasefileHttpFixture.requestBody();
    }

    @Test
    void acceptsRawCasefileAndArbitraryNamedStringsWithoutApplyingGeneratedDefaults() throws Exception {
        String body = validBody.replace("100.00", "arbitrary named string");
        when(service.addDraftCasefile(any())).thenReturn(
            new DraftCasefileSubmission(new DraftCasefileAddResponse().draftCasefileId(123L), 7L));
        mockMvc.perform(post("/draft-casefiles").with(authentication(DraftCasefileHttpFixture.token((short) 1)))
            .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isCreated())
            .andExpect(header().doesNotExist("Location"))
            .andExpect(header().string("ETag", "\"7\""))
            .andExpect(jsonPath("$.version_number").doesNotExist())
            .andExpect(jsonPath("$.draft_casefile_id").value(123));
        ArgumentCaptor<DraftCasefileAddRequest> captured = ArgumentCaptor.forClass(DraftCasefileAddRequest.class);
        verify(service).addDraftCasefile(captured.capture());
        assertThat(captured.getValue().getCasefile())
            .isEqualTo(JsonMapper.builder().build().readTree(body).get("casefile"));
        assertThat(captured.getValue().getCasefile().has("minor_creditors")).isFalse();
    }

    @ParameterizedTest
    @ValueSource(strings = {
        "wrong-type", "missing-required", "missing-conditional", "invalid-date", "audit", "malformed"
    })
    void rejectsStructureBeforeBindingWithoutDisclosingSubmittedValues(String scenario, CapturedOutput output)
        throws Exception {
        String marked = validBody.replace("Example", "SYNTHETIC_PRIVATE_NAME");
        String invalid = switch (scenario) {
            case "wrong-type" -> marked.replaceFirst("\"business_unit_id\":1", "\"business_unit_id\":\"1\"");
            case "missing-required" -> marked.replace("\"surname\":\"SYNTHETIC_PRIVATE_NAME\"", "");
            case "missing-conditional" -> marked.replace("\"organisation\":false", "\"organisation\":true");
            case "invalid-date" -> marked.replace("2026-09-01", "2026-02-30");
            case "audit" -> marked.replaceFirst("\\{", "{\"submitted_by\":\"SYNTHETIC_AUDIT\",");
            default -> marked.substring(0, marked.length() / 2);
        };
        String response = mockMvc.perform(post("/draft-casefiles")
                .with(authentication(DraftCasefileHttpFixture.token((short) 1)))
                .contentType(MediaType.APPLICATION_JSON).content(invalid))
            .andExpect(status().isBadRequest())
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
            .andExpect(jsonPath("$.title").value("Bad Request"))
            .andExpect(jsonPath("$.status").value(400))
            .andReturn().getResponse().getContentAsString();
        verifyNoInteractions(service);
        assertThat(response).doesNotContain("SYNTHETIC_PRIVATE_NAME", "SYNTHETIC_AUDIT", "Synthetic address", "100.00");
        assertThat(output).doesNotContain("SYNTHETIC_PRIVATE_NAME", "SYNTHETIC_AUDIT", "Synthetic address");
    }

    @Test
    void oversizedRequestReturnsPayloadTooLargeBeforeServiceInvocation() throws Exception {
        mockMvc.perform(post("/draft-casefiles").with(authentication(DraftCasefileHttpFixture.token((short) 1)))
                .contentType(MediaType.APPLICATION_JSON).content(" ".repeat(4097)))
            .andExpect(status().is(413))
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
            .andExpect(jsonPath("$.title").value("Content Too Large"));
        verifyNoInteractions(service);
    }

    @ParameterizedTest
    @ValueSource(ints = {403, 409, 500, 503})
    void usesSharedProblemDetailsForServiceFailures(int expectedStatus) throws Exception {
        RuntimeException failure = switch (expectedStatus) {
            case 403 -> new AccessDeniedException("No matching identity");
            case 409 -> new DataIntegrityViolationException("Synthetic constraint failure");
            case 503 -> new DataAccessResourceFailureException("Synthetic connection failure");
            default -> new InvalidDataAccessResourceUsageException("Synthetic persistence failure");
        };
        when(service.addDraftCasefile(any())).thenThrow(failure);
        String response = mockMvc.perform(post("/draft-casefiles")
                .with(authentication(DraftCasefileHttpFixture.token((short) 1)))
                .contentType(MediaType.APPLICATION_JSON).content(validBody))
            .andExpect(status().is(expectedStatus))
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
            .andExpect(jsonPath("$.status").value(expectedStatus))
            .andExpect(jsonPath("$.operation_id").isNotEmpty())
            .andReturn().getResponse().getContentAsString();
        assertThat(response).doesNotContain("Synthetic connection failure", "Synthetic persistence failure");
    }

    @Test
    void requiresAuthentication() throws Exception {
        mockMvc.perform(post("/draft-casefiles").contentType(MediaType.APPLICATION_JSON).content(validBody))
            .andExpect(status().isUnauthorized());
        verifyNoInteractions(service);
    }
}
