package uk.gov.hmcts.opal.controllers;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.reset;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.annotation.DirtiesContext.ClassMode.AFTER_CLASS;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.cache.Cache;
import org.springframework.cache.CacheManager;
import org.springframework.dao.InvalidDataAccessResourceUsageException;
import org.springframework.http.MediaType;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.repository.MaintenanceApplicationRepository;

@AutoConfigureMockMvc
@TestPropertySource(properties = {
    "spring.flyway.locations=classpath:db/migration/ddl",
    "opal.redis.enabled=false",
    "management.health.redis.enabled=false",
    "opal.test.maintenance-application-http=true"
})
@DirtiesContext(classMode = AFTER_CLASS)
class MaintenanceApplicationControllerIntegrationTest extends BaseIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private CacheManager cacheManager;

    @MockitoBean
    private MaintenanceApplicationRepository repository;

    @BeforeEach
    void clearCacheAndResetRepository() {
        Cache cache = cacheManager.getCache("maintenanceApplicationReferenceDataCache");
        if (cache != null) {
            cache.clear();
        }
        reset(repository);
    }

    @ParameterizedTest
    @ValueSource(strings = {"", "123456789012345678901"})
    void rejectsInvalidGroupLengthBeforeLookup(String group) throws Exception {
        mockMvc.perform(get("/maintenance-applications").param("application_group", group)
                .with(user("test-user")))
            .andExpect(status().isBadRequest())
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON));
        verifyNoInteractions(repository);
    }

    @Test
    void rejectsMissingGroupBeforeLookup() throws Exception {
        mockMvc.perform(get("/maintenance-applications").with(user("test-user")))
            .andExpect(status().isBadRequest());
        verifyNoInteractions(repository);
    }

    @ParameterizedTest
    @ValueSource(strings = {
        "A", "12345678901234567890", "Create Casefile", "create casefile", " Create Casefile ", " "
    })
    void preservesValidGroupExactly(String group) throws Exception {
        when(repository.findMaintenanceApplications(group, null)).thenReturn(List.of());
        mockMvc.perform(get("/maintenance-applications").param("application_group", group)
                .with(user("test-user")))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.count").value(0))
            .andExpect(jsonPath("$.refData").isEmpty());
        verify(repository).findMaintenanceApplications(group, null);
    }

    @Test
    void requiresAuthentication() throws Exception {
        mockMvc.perform(get("/maintenance-applications").param("application_group", "Create Casefile"))
            .andExpect(status().isUnauthorized());
        verifyNoInteractions(repository);
    }

    @Test
    void rejectsMalformedBooleanWithoutEchoingInput() throws Exception {
        String body = mockMvc.perform(get("/maintenance-applications")
                .param("application_group", "Create Casefile").param("active", "invalid-boolean")
                .with(user("test-user")))
            .andExpect(status().isBadRequest())
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
            .andExpect(jsonPath("$.reason").doesNotExist())
            .andExpect(jsonPath("$.operation_id").isNotEmpty())
            .andReturn().getResponse().getContentAsString();
        assertThat(body).doesNotContain("invalid-boolean");
        verifyNoInteractions(repository);
    }

    @Test
    void rejectsUnsupportedResponseMediaType() throws Exception {
        mockMvc.perform(get("/maintenance-applications").param("application_group", "Create Casefile")
                .accept(MediaType.APPLICATION_XML).with(user("test-user")))
            .andExpect(status().isNotAcceptable());
        verifyNoInteractions(repository);
    }

    @Test
    void usesSharedSafeDatabaseErrorHandling() throws Exception {
        when(repository.findMaintenanceApplications("Create Casefile", null))
            .thenThrow(new InvalidDataAccessResourceUsageException("Synthetic internal failure"));
        String body = mockMvc.perform(get("/maintenance-applications")
                .param("application_group", "Create Casefile").with(user("test-user")))
            .andExpect(status().isInternalServerError())
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
            .andReturn().getResponse().getContentAsString();
        assertThat(body).doesNotContain("Synthetic internal failure", "InvalidDataAccessResourceUsageException");
    }
}
