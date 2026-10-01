package uk.gov.hmcts.opal.authentication;

import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import uk.gov.hmcts.opal.common.logging.LogUtil;
import uk.gov.hmcts.opal.common.spring.security.OpalJwtAuthenticationToken;
import uk.gov.hmcts.opal.common.user.authorisation.model.BusinessUnitUser;
import uk.gov.hmcts.opal.common.user.authorisation.model.Domain;
import uk.gov.hmcts.opal.common.user.authorisation.model.DomainBusinessUnitUsers;
import uk.gov.hmcts.opal.common.user.authorisation.model.UserStateV2;

import java.util.Optional;

@Component
public class MaintenanceUserContext {

    public MaintenanceUser forBusinessUnit(Short businessUnitId) {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (!(authentication instanceof OpalJwtAuthenticationToken token) || token.getUserState() == null) {
            throw new AccessDeniedException("Authenticated user state is unavailable");
        }

        UserStateV2 state = token.getUserState();
        if (state.getDomains() == null) {
            throw new AccessDeniedException("Authenticated user state is unavailable");
        }

        DomainBusinessUnitUsers units = state.getDomains().get(Domain.MAINTENANCE);
        BusinessUnitUser unit = Optional.ofNullable(units)
            .filter(value -> value.getBusinessUnitUsers() != null && businessUnitId != null)
            .flatMap(value -> value.getBusinessUnitUserForBusinessUnit(businessUnitId))
            .orElseThrow(() -> new AccessDeniedException("No user identity for the requested Business Unit"));

        if (state.getUserId() == null || isBlank(state.getName()) || isBlank(unit.getBusinessUnitUserId())) {
            throw new AccessDeniedException("Authenticated user identity is incomplete");
        }

        return new MaintenanceUser(state.getUserId(), unit.getBusinessUnitUserId(),
            state.getName(), LogUtil.getIpAddress());
    }

    private boolean isBlank(String value) {
        return value == null || value.isBlank();
    }
}
