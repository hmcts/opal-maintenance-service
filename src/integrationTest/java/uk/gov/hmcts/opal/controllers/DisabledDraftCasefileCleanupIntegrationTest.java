package uk.gov.hmcts.opal.controllers;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.support.DraftCasefileHttpFixture;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
@TestPropertySource(properties = {
    "spring.flyway.locations=classpath:db/migration/ddl",
    "opal.redis.enabled=false", "management.health.redis.enabled=false",
    "opal.testing-support-endpoints.enabled=false"
})
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
class DisabledDraftCasefileCleanupIntegrationTest extends BaseIntegrationTest {

    @Autowired
    private MockMvc mockMvc;
    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void authenticatedCleanupIsUnavailable() throws Exception {
        mockMvc.perform(delete("/testing-support/draft-casefiles/1")
                .with(authentication(DraftCasefileHttpFixture.token((short) 1)))
                .header("Test-Run-Reference", "E2E-0123456789abcdef"))
            .andExpect(status().isNotFound());
    }

    @Test
    void anonymousCleanupStillRequiresAuthentication() throws Exception {
        mockMvc.perform(delete("/testing-support/draft-casefiles/1"))
            .andExpect(status().isUnauthorized());
    }

    @Test
    void publicRuntimeDocumentationOmitsCleanup() throws Exception {
        String body = mockMvc.perform(get("/v3/api-docs")).andExpect(status().isOk())
            .andReturn().getResponse().getContentAsString();
        JsonNode paths = objectMapper.readTree(body).get("paths");
        assertThat(paths.isObject()).isTrue();
        assertThat(paths.has("/testing-support/draft-casefiles/{draft_casefile_id}")).isFalse();
    }
}
