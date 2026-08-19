package uk.gov.hmcts.reform.opal.controllers;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.core.Authentication;
import uk.gov.hmcts.opal.common.config.OpalCommonConfiguration;
import uk.gov.hmcts.opal.common.spring.security.OpalJwtAuthenticationToken;
import uk.gov.hmcts.opal.common.user.authorisation.client.service.UserStateClientService;
import uk.gov.hmcts.opal.common.user.authorisation.model.BusinessUnitUser;
import uk.gov.hmcts.opal.common.user.authorisation.model.Domain;
import uk.gov.hmcts.opal.common.user.authorisation.model.DomainBusinessUnitUsers;
import uk.gov.hmcts.opal.common.user.authorisation.model.UserState;
import uk.gov.hmcts.opal.common.user.authorisation.model.UserStateV2;
import uk.gov.hmcts.opal.common.user.authorisation.model.UserStatus;

import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TestingSupportControllerTest {

    @Mock
    private UserStateClientService userStateClientService;

    @Mock
    private OpalCommonConfiguration commonConfiguration;

    @Mock
    private Authentication authentication;

    @InjectMocks
    private TestingSupportAuthController testingSupportAuthController;

    @Test
    void returnsOkPingResponse() {
        assertThat(new TestingSupportController().ping().getBody())
            .isEqualTo(new TestingSupportController.PingResponse("ok"));
    }

    @Test
    void returnsEmptySummaryWhenUserStateIsUnavailable() {
        when(authentication.getName()).thenReturn("test-subject");
        when(authentication.isAuthenticated()).thenReturn(true);
        when(userStateClientService.getUserStateByAuthenticatedUser()).thenReturn(Optional.empty());

        var response = testingSupportAuthController.check(authentication);

        assertThat(response.getBody()).isEqualTo(
            new TestingSupportAuthController.AuthCheckResponse(
                "test-subject", true, false, null, null, Set.of()));
    }

    @Test
    void returnsResolvedSummaryForStandardAuthentication() {
        UserState userState = new UserState(
            123L,
            "test-user@example.invalid",
            Set.of(new BusinessUnitUser("BUU-42", (short) 42, Set.of())));
        when(authentication.getName()).thenReturn("test-subject");
        when(authentication.isAuthenticated()).thenReturn(true);
        when(userStateClientService.getUserStateByAuthenticatedUser()).thenReturn(Optional.of(userState));

        var response = testingSupportAuthController.check(authentication);

        assertThat(response.getBody()).isEqualTo(
            new TestingSupportAuthController.AuthCheckResponse(
                "test-subject", true, true, 123L, "test-user@example.invalid", Set.of((short) 42)));
    }

    @Test
    void returnsMaintenanceBusinessUnitsForOpalJwtAuthentication() {
        UserStateV2 userState = new UserStateV2(
            123L,
            "test-user@example.invalid",
            "Test User",
            UserStatus.ACTIVE,
            1L,
            "test-user-state",
            Map.of(
                Domain.MAINTENANCE,
                new DomainBusinessUnitUsers(List.of(new BusinessUnitUser("BUU-42", (short) 42, Set.of())))));
        OpalJwtAuthenticationToken opalJwtAuthenticationToken = mock(OpalJwtAuthenticationToken.class);
        when(commonConfiguration.getDomain()).thenReturn("maintenance");
        when(opalJwtAuthenticationToken.getName()).thenReturn("test-subject");
        when(opalJwtAuthenticationToken.isAuthenticated()).thenReturn(true);
        when(opalJwtAuthenticationToken.getUserState()).thenReturn(userState);

        var response = testingSupportAuthController.check(opalJwtAuthenticationToken);

        assertThat(response.getBody()).isEqualTo(
            new TestingSupportAuthController.AuthCheckResponse(
                "test-subject", true, true, 123L, "test-user@example.invalid", Set.of((short) 42)));
    }
}
