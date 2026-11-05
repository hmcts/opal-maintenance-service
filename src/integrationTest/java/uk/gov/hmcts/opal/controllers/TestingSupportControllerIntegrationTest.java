package uk.gov.hmcts.opal.controllers;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import uk.gov.hmcts.opal.common.user.authorisation.client.service.UserStateClientService;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.hmcts.zephyr.automation.junit5.annotations.JiraIgnore;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
@TestPropertySource(properties = {
    "opal.testing-support-endpoints.enabled=true",
    "management.health.redis.enabled=false"
})
class TestingSupportControllerIntegrationTest extends BaseIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private UserStateClientService userStateClientService;

    @Test
    @JiraIgnore
    void exposesPingWhenTestingSupportEndpointsAreEnabled() throws Exception {
        mockMvc.perform(get("/testing-support/ping"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.status").value("ok"));
    }

    @Test
    @JiraIgnore
    void rejectsUnauthenticatedAuthCheckWhenTestingSupportEndpointsAreEnabled() throws Exception {
        mockMvc.perform(get("/testing-support/auth/check"))
            .andExpect(status().isUnauthorized());
    }

    @Test
    @JiraIgnore
    void rejectsUnauthenticatedTestingSupportSibling() throws Exception {
        mockMvc.perform(get("/testing-support/future-resource"))
            .andExpect(status().isUnauthorized());
    }
}
