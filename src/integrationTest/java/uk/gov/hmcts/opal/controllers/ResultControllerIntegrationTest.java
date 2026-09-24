package uk.gov.hmcts.opal.controllers;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.reset;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.cache.CacheManager;
import org.springframework.dao.InvalidDataAccessResourceUsageException;
import org.springframework.http.MediaType;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.entity.ResultEntity;
import uk.gov.hmcts.opal.repository.ResultRepository;

@AutoConfigureMockMvc
@TestPropertySource(properties = {
    "spring.flyway.locations=classpath:db/migration/ddl",
    "management.health.redis.enabled=false",
    "opal.test.result-detail-http=true"
})
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
class ResultControllerIntegrationTest extends BaseIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private CacheManager cacheManager;

    @Autowired
    private ObjectMapper objectMapper;

    @MockitoBean
    private ResultRepository repository;

    @BeforeEach
    void resetState() {
        cacheManager.getCache("resultDetailCache").clear();
        reset(repository);
    }

    @ParameterizedTest
    @ValueSource(strings = {"A", "ABC123", "aBc123"})
    void acceptsBoundaryLengthsAndPreservesCase(String id) throws Exception {
        when(repository.findById(id)).thenReturn(Optional.of(ResultEntity.builder()
            .resultId(id).resultTitle("Example").active(false).orderTerm(false).build()));

        String body = mockMvc.perform(get("/results/{id}", id).with(user("test-user")))
            .andExpect(status().isOk())
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
            .andReturn().getResponse().getContentAsString();
        JsonNode json = objectMapper.readTree(body);
        assertThat(json.size()).isEqualTo(3);
        assertThat(json.path("result_id").asText()).isEqualTo(id);
        assertThat(json.path("result_title").asText()).isEqualTo("Example");
        assertThat(json.has("result_parameters")).isTrue();
        assertThat(json.get("result_parameters").isNull()).isTrue();
        verify(repository).findById(id);
    }

    @Test
    void rejectsOverlongIdBeforeLookup() throws Exception {
        mockMvc.perform(get("/results/ABCDEFG").with(user("test-user")))
            .andExpect(status().isBadRequest())
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
            .andExpect(jsonPath("$.status").value(400))
            .andExpect(jsonPath("$.operation_id").isNotEmpty());
        verifyNoInteractions(repository);
    }

    @Test
    void returnsSharedNotFoundProblem() throws Exception {
        when(repository.findById("ABSENT")).thenReturn(Optional.empty());
        mockMvc.perform(get("/results/ABSENT").with(user("test-user")))
            .andExpect(status().isNotFound())
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
            .andExpect(jsonPath("$.status").value(404))
            .andExpect(jsonPath("$.title").value("Entity Not Found"))
            .andExpect(jsonPath("$.detail").value("The requested entity could not be found"))
            .andExpect(jsonPath("$.operation_id").isNotEmpty())
            .andExpect(jsonPath("$.retriable").value(false))
            .andExpect(jsonPath("$.reason").value("Result not found"));
    }

    @Test
    void requiresAuthentication() throws Exception {
        mockMvc.perform(get("/results/ABC123")).andExpect(status().isUnauthorized());
        verifyNoInteractions(repository);
    }

    @Test
    void rejectsUnsupportedResponseMediaType() throws Exception {
        mockMvc.perform(get("/results/ABC123").with(user("test-user")).accept(MediaType.APPLICATION_XML))
            .andExpect(status().isNotAcceptable());
        verifyNoInteractions(repository);
    }

    @Test
    void returnsSafeInternalError() throws Exception {
        when(repository.findById("ABC123"))
            .thenThrow(new InvalidDataAccessResourceUsageException("Synthetic internal failure"));
        String body = mockMvc.perform(get("/results/ABC123").with(user("test-user")))
            .andExpect(status().isInternalServerError())
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
            .andReturn().getResponse().getContentAsString();
        assertThat(body).doesNotContain("Synthetic internal failure", "InvalidDataAccessResourceUsageException");
    }
}
