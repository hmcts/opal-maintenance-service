package uk.gov.hmcts.opal.authorisation;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.jwt.Jwt;
import uk.gov.hmcts.opal.common.logging.LogUtil;
import uk.gov.hmcts.opal.common.spring.security.OpalJwtAuthenticationToken;
import uk.gov.hmcts.opal.common.user.authorisation.model.BusinessUnitUser;
import uk.gov.hmcts.opal.common.user.authorisation.model.Domain;
import uk.gov.hmcts.opal.common.user.authorisation.model.DomainBusinessUnitUsers;
import uk.gov.hmcts.opal.common.user.authorisation.model.Permission;
import uk.gov.hmcts.opal.common.user.authorisation.model.UserStateV2;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static uk.gov.hmcts.opal.authorisation.MaintenancePermission.CREATE_MANAGE_DRAFT_CASEFILES;

class MaintenanceUserServiceTest {

    private final MaintenanceUserService userService = new MaintenanceUserService();

    @AfterEach
    void clearSecurityContext() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void resolvesTheRequestedBusinessUnitIdentityWithPermission() {
        authenticate(state(Map.of(Domain.MAINTENANCE, businessUnitUsers(
            permittedUser("BUU-1", (short) 1),
            permittedUser("BUU-2", (short) 2)))), Domain.MAINTENANCE);

        MaintenanceUser unitOne = userService.requireAuthorisedUser((short) 1, CREATE_MANAGE_DRAFT_CASEFILES);
        MaintenanceUser unitTwo = userService.requireAuthorisedUser((short) 2, CREATE_MANAGE_DRAFT_CASEFILES);

        assertThat(unitOne.userId()).isEqualTo(123L);
        assertThat(unitOne.businessUnitUserId()).isEqualTo("BUU-1");
        assertThat(unitOne.displayName()).isEqualTo("Test User");
        assertThat(unitOne.ipAddress()).isEqualTo(LogUtil.getIpAddress());
        assertThat(unitTwo.businessUnitUserId()).isEqualTo("BUU-2");
    }

    @Test
    void deniesWhenPermissionIsAbsentForRequestedBusinessUnit() {
        authenticate(state(Map.of(Domain.MAINTENANCE, businessUnitUsers(
            new BusinessUnitUser("BUU-1", (short) 1, Set.of()),
            permittedUser("BUU-2", (short) 2)))), Domain.MAINTENANCE);

        assertThatThrownBy(() -> userService.requireAuthorisedUser((short) 1, CREATE_MANAGE_DRAFT_CASEFILES))
            .isInstanceOf(AccessDeniedException.class)
            .hasMessage("Create and Manage Draft Casefiles permission is required");
        assertThat(userService.requireAuthorisedUser((short) 2, CREATE_MANAGE_DRAFT_CASEFILES)
            .businessUnitUserId())
            .isEqualTo("BUU-2");
    }

    @Test
    void deniesWhenUserHasOnlyCheckerPermission() {
        authenticate(state(Map.of(Domain.MAINTENANCE, businessUnitUsers(
            new BusinessUnitUser("BUU-1", (short) 1,
                Set.of(new Permission(22L, "Check and validate draft Casefiles")))))), Domain.MAINTENANCE);

        assertThatThrownBy(() -> userService.requireAuthorisedUser((short) 1, CREATE_MANAGE_DRAFT_CASEFILES))
            .isInstanceOf(AccessDeniedException.class)
            .hasMessage("Create and Manage Draft Casefiles permission is required");
    }

    @Test
    void deniesBusinessUnitWithoutItsOwnIdentity() {
        authenticate(state(Map.of(Domain.MAINTENANCE, businessUnitUsers(
            new BusinessUnitUser("BUU-1", (short) 1, Set.of())))), Domain.MAINTENANCE);

        assertThatThrownBy(() -> userService.requireAuthorisedUser((short) 2, CREATE_MANAGE_DRAFT_CASEFILES))
            .isInstanceOf(AccessDeniedException.class)
            .hasMessage("No user identity for the requested Business Unit");
    }

    @Test
    void deniesWhenMaintenanceDomainIsAbsent() {
        authenticate(state(Map.of(Domain.FINES, businessUnitUsers(
            new BusinessUnitUser("FINES-1", (short) 1, Set.of())))), Domain.FINES);

        assertThatThrownBy(() -> userService.requireAuthorisedUser((short) 1, CREATE_MANAGE_DRAFT_CASEFILES))
            .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void deniesWhenDomainsAreUnavailable() {
        UserStateV2 userState = state(Map.of(Domain.MAINTENANCE, businessUnitUsers(
            new BusinessUnitUser("BUU-1", (short) 1, Set.of()))));
        authenticate(userState, Domain.MAINTENANCE);
        userState.setDomains(null);

        assertThatThrownBy(() -> userService.requireAuthorisedUser((short) 1, CREATE_MANAGE_DRAFT_CASEFILES))
            .isInstanceOf(AccessDeniedException.class)
            .hasMessage("No user identity for the requested Business Unit");
    }

    @Test
    void deniesIncompleteRequiredIdentity() {
        UserStateV2 userState = state(Map.of(Domain.MAINTENANCE, businessUnitUsers(
            new BusinessUnitUser("BUU-1", (short) 1, Set.of()))));
        authenticate(userState, Domain.MAINTENANCE);
        userState.setName(" ");
        assertThatThrownBy(() -> userService.requireAuthorisedUser((short) 1, CREATE_MANAGE_DRAFT_CASEFILES))
            .isInstanceOf(AccessDeniedException.class)
            .hasMessage("Authenticated user identity is incomplete");

        userState.setName("Test User");
        userState.getDomains().get(Domain.MAINTENANCE).getBusinessUnitUsers().getFirst()
            .setBusinessUnitUserId(" ");
        assertThatThrownBy(() -> userService.requireAuthorisedUser((short) 1, CREATE_MANAGE_DRAFT_CASEFILES))
            .isInstanceOf(AccessDeniedException.class)
            .hasMessage("Authenticated user identity is incomplete");
    }

    @Test
    void deniesWhenAuthenticationIsUnavailable() {
        assertThatThrownBy(() -> userService.requireAuthorisedUser((short) 1, CREATE_MANAGE_DRAFT_CASEFILES))
            .isInstanceOf(AccessDeniedException.class)
            .hasMessage("Authenticated user state is unavailable");
    }

    private static UserStateV2 state(Map<Domain, DomainBusinessUnitUsers> domains) {
        return UserStateV2.builder()
            .userId(123L)
            .name("Test User")
            .domains(domains)
            .build();
    }

    private static DomainBusinessUnitUsers businessUnitUsers(BusinessUnitUser... users) {
        return new DomainBusinessUnitUsers(List.of(users));
    }

    private static BusinessUnitUser permittedUser(String id, short businessUnitId) {
        MaintenancePermission permission = MaintenancePermission.CREATE_MANAGE_DRAFT_CASEFILES;
        return new BusinessUnitUser(id, businessUnitId,
            Set.of(new Permission(permission.getId(), permission.getDescription())));
    }

    private static void authenticate(UserStateV2 userState, Domain domain) {
        Jwt jwt = Jwt.withTokenValue("synthetic-test-token")
            .header("alg", "none")
            .claim("sub", "synthetic-user")
            .issuedAt(Instant.EPOCH)
            .expiresAt(Instant.EPOCH.plusSeconds(60))
            .build();
        SecurityContextHolder.getContext().setAuthentication(
            new OpalJwtAuthenticationToken(userState, domain, jwt, List.of(), null));
    }
}
