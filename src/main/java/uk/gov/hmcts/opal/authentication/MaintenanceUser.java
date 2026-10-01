package uk.gov.hmcts.opal.authentication;

public record MaintenanceUser(Long userId, String businessUnitUserId, String displayName, String ipAddress) {
}
