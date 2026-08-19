package uk.gov.hmcts.reform.opal.controllers;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import uk.gov.hmcts.opal.common.config.OpalCommonConfiguration;
import uk.gov.hmcts.opal.common.spring.security.OpalJwtAuthenticationToken;
import uk.gov.hmcts.opal.common.user.authorisation.client.service.UserStateClientService;
import uk.gov.hmcts.opal.common.user.authorisation.model.Domain;
import uk.gov.hmcts.opal.common.user.authorisation.model.DomainBusinessUnitUsers;
import uk.gov.hmcts.opal.common.user.authorisation.model.UserState;
import uk.gov.hmcts.opal.common.user.authorisation.model.UserStateV2;

import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/testing-support/auth")
@ConditionalOnProperty(prefix = "opal.testing-support-endpoints", name = "enabled", havingValue = "true")
public class TestingSupportAuthController {

    private final UserStateClientService userStateClientService;
    private final OpalCommonConfiguration commonConfiguration;

    public TestingSupportAuthController(
        UserStateClientService userStateClientService,
        OpalCommonConfiguration commonConfiguration) {
        this.userStateClientService = userStateClientService;
        this.commonConfiguration = commonConfiguration;
    }

    @GetMapping("/check")
    public ResponseEntity<AuthCheckResponse> check(Authentication authentication) {
        if (authentication instanceof OpalJwtAuthenticationToken opalJwtAuthenticationToken) {
            return ResponseEntity.ok(summaryFor(opalJwtAuthenticationToken));
        }

        return ResponseEntity.ok(userStateClientService.getUserStateByAuthenticatedUser()
                                     .map(userState -> summaryFor(authentication, userState))
                                     .orElseGet(() -> emptySummaryFor(authentication)));
    }

    private AuthCheckResponse summaryFor(OpalJwtAuthenticationToken authentication) {
        UserStateV2 userState = authentication.getUserState();
        if (userState == null) {
            return emptySummaryFor(authentication);
        }

        Domain domain = Domain.findByDisplayName(commonConfiguration.getDomain());
        DomainBusinessUnitUsers domainBusinessUnitUsers = userState.getDomainBusinessUnitUsers(domain);
        Set<Short> businessUnitIds = Optional.ofNullable(domainBusinessUnitUsers)
            .map(DomainBusinessUnitUsers::getBusinessUnitUsers)
            .orElseGet(List::of)
            .stream()
            .map(businessUnitUser -> businessUnitUser.getBusinessUnitId())
            .collect(Collectors.toUnmodifiableSet());
        return new AuthCheckResponse(
            authentication.getName(),
            authentication.isAuthenticated(),
            true,
            userState.getUserId(),
            userState.getUsername(),
            businessUnitIds);
    }

    private AuthCheckResponse summaryFor(Authentication authentication, UserState userState) {
        Set<Short> businessUnitIds = userState.getBusinessUnitUser()
            .stream()
            .map(businessUnitUser -> businessUnitUser.getBusinessUnitId())
            .collect(Collectors.toUnmodifiableSet());
        return new AuthCheckResponse(
            authentication.getName(),
            authentication.isAuthenticated(),
            true,
            userState.getUserId(),
            userState.getUserName(),
            businessUnitIds);
    }

    private AuthCheckResponse emptySummaryFor(Authentication authentication) {
        return new AuthCheckResponse(
            authentication.getName(), authentication.isAuthenticated(), false, null, null, Set.of());
    }

    public record AuthCheckResponse(
        String principalName,
        boolean authenticated,
        boolean userStateFound,
        Long userId,
        String userName,
        Set<Short> businessUnitIds
    ) {
    }
}
