package uk.gov.hmcts.opal.config;

import jakarta.validation.constraints.AssertTrue;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

import java.util.Set;

@ConfigurationProperties("opal.testing-support-endpoints.draft-casefile-cleanup")
@Validated
public record DraftCasefileCleanupProperties(
    boolean enabled, String environment, Short businessUnitId, Long userId, String businessUnitUserId
) {
    private static final Set<String> TEST_ENVIRONMENTS =
        Set.of("local", "integration", "dev", "stg", "staging");

    @AssertTrue(message = "Draft Casefile cleanup requires an allowed test environment and automation owner")
    public boolean isSafeConfiguration() {
        return !enabled || environment != null && TEST_ENVIRONMENTS.contains(environment)
            && businessUnitId != null && businessUnitId > 0
            && userId != null && userId > 0
            && businessUnitUserId != null && !businessUnitUserId.isBlank()
            && businessUnitUserId.length() <= 20
            && businessUnitUserId.equals(businessUnitUserId.strip());
    }
}
