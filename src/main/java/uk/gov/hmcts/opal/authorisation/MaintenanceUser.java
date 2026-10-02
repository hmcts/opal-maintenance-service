package uk.gov.hmcts.opal.authorisation;

public record MaintenanceUser(Long userId, String businessUnitUserId, String displayName, String ipAddress) {
}
