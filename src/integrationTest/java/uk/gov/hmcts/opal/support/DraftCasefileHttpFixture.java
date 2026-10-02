package uk.gov.hmcts.opal.support;

import org.springframework.core.io.ClassPathResource;
import org.springframework.security.oauth2.jwt.Jwt;
import uk.gov.hmcts.opal.authorisation.MaintenancePermission;
import uk.gov.hmcts.opal.common.spring.security.OpalJwtAuthenticationToken;
import uk.gov.hmcts.opal.common.user.authorisation.model.BusinessUnitUser;
import uk.gov.hmcts.opal.common.user.authorisation.model.Domain;
import uk.gov.hmcts.opal.common.user.authorisation.model.DomainBusinessUnitUsers;
import uk.gov.hmcts.opal.common.user.authorisation.model.Permission;
import uk.gov.hmcts.opal.common.user.authorisation.model.UserStateV2;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Set;

public final class DraftCasefileHttpFixture {

    private DraftCasefileHttpFixture() {
    }

    public static String requestBody() throws IOException {
        return new ClassPathResource("draft-casefile/minimal-request.json").getContentAsString(StandardCharsets.UTF_8);
    }

    public static OpalJwtAuthenticationToken token(short businessUnitId) {
        UserStateV2 state = UserStateV2.builder().userId(123L).name("Synthetic Submitter")
            .domains(Map.of(Domain.MAINTENANCE, new DomainBusinessUnitUsers(List.of(
                new BusinessUnitUser("BUU-1", businessUnitId, Set.of(new Permission(
                    MaintenancePermission.CREATE_MANAGE_DRAFT_CASEFILES.getId(),
                    MaintenancePermission.CREATE_MANAGE_DRAFT_CASEFILES.getDescription()))))))).build();
        Jwt jwt = Jwt.withTokenValue("synthetic-test-token").header("alg", "none").claim("sub", "synthetic-user")
            .issuedAt(Instant.EPOCH).expiresAt(Instant.EPOCH.plusSeconds(60)).build();
        return new OpalJwtAuthenticationToken(state, Domain.MAINTENANCE, jwt, List.of(), null);
    }
}
