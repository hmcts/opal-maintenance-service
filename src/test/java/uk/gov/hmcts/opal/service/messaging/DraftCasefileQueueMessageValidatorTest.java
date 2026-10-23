package uk.gov.hmcts.opal.service.messaging;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DraftCasefileQueueMessageValidatorTest {
    private final DraftCasefileQueueMessageValidator validator = new DraftCasefileQueueMessageValidator();

    @Test
    void parsesLegacyIdOnlyMessage() {
        var message = validator.parse("{\"draft_casefile_id\":42}");
        assertThat(message.draftCasefileId()).isEqualTo(42L);
        assertThat(message.checkerUserId()).isNull();
        assertThatThrownBy(() -> validator.validateAuditContext(message)).isInstanceOf(IllegalArgumentException.class);
    }

    @ParameterizedTest
    @ValueSource(strings = {
        "{\"draft_casefile_id\":42,\"draft_casefile_id\":43}",
        "{\"draft_casefile_id\":1.2}", "{\"draft_casefile_id\":\"42\"}",
        "{\"draft_casefile_id\":9223372036854775808}", "{\"draft_casefile_id\":0}",
        "{\"draft_casefile_id\":42,\"checker_user_id\":1.5}",
        "{\"draft_casefile_id\":42,\"originating_ip_address\":123}",
        "{\"draft_casefile_id\":42} {\"draft_casefile_id\":43}", "[]", "null"
    })
    void rejectsDuplicateOrCoercedIdentifiers(String payload) {
        assertThatThrownBy(() -> validator.parse(payload)).isInstanceOf(IllegalArgumentException.class)
            .hasMessage("Invalid publication message").hasNoCause();
    }

    @ParameterizedTest
    @ValueSource(strings = {"192.0.2.1", "2001:db8::1", "::ffff:192.0.2.1"})
    void acceptsLiteralAddresses(String ip) {
        var message = validator.parse("{\"draft_casefile_id\":42,\"checker_user_id\":123,"
            + "\"originating_ip_address\":\"" + ip + "\",\"approval_timestamp\":\"2024-01-02T00:00:00Z\"}");
        validator.validateAuditContext(message);
        assertThat(message.originatingIpAddress()).isEqualTo(ip);
    }

    @ParameterizedTest
    @ValueSource(strings = {"not-a-time", "2024-01-02", "2024-01-02T00:00:00.000000001Z"})
    void rejectsInvalidApprovalTimestampWithoutLeakingValue(String timestamp) {
        assertThatThrownBy(() -> validator.validateAuditContext(
            new DraftCasefileQueueMessage(42L, 123L, "192.0.2.1", timestamp)))
            .isInstanceOf(IllegalArgumentException.class).hasMessage("Invalid publication message").hasNoCause();
    }

    @Test
    void legacyAuditMessageCannotPublishWithoutApprovalCorrelation() {
        var message = validator.parse("""
            {"draft_casefile_id":42,"checker_user_id":123,"originating_ip_address":"192.0.2.1"}
            """);
        assertThatThrownBy(() -> validator.validateAuditContext(message)).isInstanceOf(IllegalArgumentException.class);
    }

    @ParameterizedTest
    @ValueSource(strings = {"localhost", "example.invalid", "", "192.0.2.999", "192.0.2.1,192.0.2.2"})
    void rejectsIpHostnamesWithoutDnsLookup(String ip) {
        assertThatThrownBy(() -> validator.validateAuditContext(new DraftCasefileQueueMessage(42L, 123L, ip,
            "2024-01-02T00:00:00Z")))
            .isInstanceOf(IllegalArgumentException.class).hasNoCause();
    }
}
