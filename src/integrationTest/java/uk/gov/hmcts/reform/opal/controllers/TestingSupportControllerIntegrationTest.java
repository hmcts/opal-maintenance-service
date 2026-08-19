package uk.gov.hmcts.reform.opal.controllers;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import uk.gov.hmcts.opal.common.user.authorisation.client.service.UserStateClientService;
import uk.gov.hmcts.opal.common.user.authorisation.model.BusinessUnitUser;
import uk.gov.hmcts.opal.common.user.authorisation.model.UserState;
import uk.gov.hmcts.reform.opal.BaseIntegrationTest;

import java.util.Optional;
import java.util.Set;

import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
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
    void exposesPingWhenTestingSupportEndpointsAreEnabled() throws Exception {
        mockMvc.perform(get("/testing-support/ping"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.status").value("ok"));
    }

    @Test
    void rejectsUnauthenticatedAuthCheckWhenTestingSupportEndpointsAreEnabled() throws Exception {
        mockMvc.perform(get("/testing-support/auth/check"))
            .andExpect(status().isUnauthorized());
    }

    @Test
    void returnsMockedUserStateForAuthenticatedAuthCheck() throws Exception {
        UserState userState = new UserState(
            123L,
            "test-user@example.invalid",
            Set.of(new BusinessUnitUser("BUU-42", (short) 42, Set.of())));
        when(userStateClientService.getUserStateByAuthenticatedUser()).thenReturn(Optional.of(userState));

        mockMvc.perform(get("/testing-support/auth/check").with(jwt().jwt(jwt -> jwt.subject("test-subject"))))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.principalName").value("test-subject"))
            .andExpect(jsonPath("$.authenticated").value(true))
            .andExpect(jsonPath("$.userStateFound").value(true))
            .andExpect(jsonPath("$.userId").value(123))
            .andExpect(jsonPath("$.userName").value("test-user@example.invalid"))
            .andExpect(jsonPath("$.businessUnitIds[0]").value(42));
    }
}
