package uk.gov.hmcts.opal.authorisation;

import lombok.Getter;
import lombok.RequiredArgsConstructor;
import uk.gov.hmcts.opal.common.user.authorisation.model.PermissionDescriptor;

@Getter
@RequiredArgsConstructor
public enum MaintenancePermission implements PermissionDescriptor {
    CREATE_MANAGE_DRAFT_CASEFILES(21L, "Create and Manage Draft Casefiles");

    private final long id;
    private final String description;
}
