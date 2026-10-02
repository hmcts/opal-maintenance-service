package uk.gov.hmcts.opal.authorisation;

import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import uk.gov.hmcts.opal.common.logging.LogUtil;
import uk.gov.hmcts.opal.common.spring.security.OpalJwtAuthenticationToken;
import uk.gov.hmcts.opal.common.user.authorisation.model.BusinessUnitUser;
import uk.gov.hmcts.opal.common.user.authorisation.model.Domain;
import uk.gov.hmcts.opal.common.user.authorisation.model.DomainBusinessUnitUsers;
import uk.gov.hmcts.opal.common.user.authorisation.model.UserStateV2;

import java.util.Optional;

@Service
public class MaintenanceUserService {

    /**
     * Reads the authenticated user's details from the security context,
     * supplied by User Service, and checks they hold the required permission
     * within the requested Maintenance business unit.
     *
     * <p>Each user has a separate set of permissions for each business unit they belong to.
     * A business unit user represents that link and its permission set.
     *
     * @return the authorised user's IDs, display name and IP address
     * @throws AccessDeniedException if the required user details or permission are missing
     */
    public MaintenanceUser requireAuthorisedUser(Short businessUnitId, MaintenancePermission requiredPermission) {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (!(authentication instanceof OpalJwtAuthenticationToken token) || token.getUserState() == null) {
            throw new AccessDeniedException("Authenticated user state is unavailable");
        }

        UserStateV2 userState = token.getUserState();
        if (userState.getDomains() == null) {
            throw new AccessDeniedException("Authenticated user state is unavailable");
        }

        DomainBusinessUnitUsers maintenanceBusinessUnitUsers = userState.getDomains().get(Domain.MAINTENANCE);
        BusinessUnitUser businessUnitUser = Optional.ofNullable(maintenanceBusinessUnitUsers)
            .filter(value -> value.getBusinessUnitUsers() != null && businessUnitId != null)
            .flatMap(value -> value.getBusinessUnitUserForBusinessUnit(businessUnitId))
            .orElseThrow(() -> new AccessDeniedException("No user identity for the requested Business Unit"));

        if (userState.getUserId() == null || isBlank(userState.getName())
            || isBlank(businessUnitUser.getBusinessUnitUserId())) {
            throw new AccessDeniedException("Authenticated user identity is incomplete");
        }
        if (businessUnitUser.getPermissions() == null || !businessUnitUser.hasPermission(requiredPermission)) {
            throw new AccessDeniedException(requiredPermission.getDescription() + " permission is required");
        }

        return new MaintenanceUser(userState.getUserId(), businessUnitUser.getBusinessUnitUserId(),
            userState.getName(), LogUtil.getIpAddress());
    }

    private boolean isBlank(String value) {
        return value == null || value.isBlank();
    }
}
