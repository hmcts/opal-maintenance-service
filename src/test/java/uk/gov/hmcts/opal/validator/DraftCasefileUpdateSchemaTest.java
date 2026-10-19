package uk.gov.hmcts.opal.validator;

import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.core.io.support.PathMatchingResourcePatternResolver;
import uk.gov.hmcts.opal.common.exception.OpalApiException;

import java.io.IOException;
import java.nio.charset.StandardCharsets;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DraftCasefileUpdateSchemaTest {
    private static OpenApiSchemaValidator validator;

    @BeforeAll
    static void load() throws IOException {
        validator = new OpenApiSchemaValidator(new PathMatchingResourcePatternResolver()
            .getResources("classpath*:openapi-bundled.yaml"));
    }

    @ParameterizedTest
    @ValueSource(strings = {"PUBLISHING_PENDING", "REJECTED", "DELETED"})
    void acceptsValidDecisions(String target) {
        String reason = target.equals("PUBLISHING_PENDING") ? "" : ",\"status_message\":\"" + "x".repeat(250) + "\"";
        assertThatCode(() -> validate("{\"business_unit_id\":1,\"casefile_status\":\"" + target + "\""
            + reason + "}")).doesNotThrowAnyException();
    }

    @ParameterizedTest
    @ValueSource(strings = {
        "{}", "{\"business_unit_id\":1,\"casefile_status\":\"REJECTED\"}",
        "{\"business_unit_id\":1,\"casefile_status\":\"PUBLISHED\"}",
        "{\"business_unit_id\":1,\"casefile_status\":\"PUBLISHING_PENDING\",\"status_message\":\"reason\"}",
        "{\"business_unit_id\":1,\"casefile_status\":\"DELETED\",\"status_message\":\"   \"}",
        "{\"business_unit_id\":1,\"casefile_status\":\"DELETED\",\"status_message\":null}",
        "{\"business_unit_id\":1,\"casefile_status\":\"PUBLISHING_PENDING\",\"version_number\":0}",
        "{\"business_unit_id\":null,\"casefile_status\":\"PUBLISHING_PENDING\"}"
    })
    void rejectsInvalidRequests(String json) {
        assertThatThrownBy(() -> validate(json)).isInstanceOf(OpalApiException.class);
    }

    @ParameterizedTest
    @ValueSource(strings = {"casefile", "casefile_snapshot", "timeline_data", "validated_by", "unknown"})
    void rejectsServerOwnedOrUnknownProperties(String property) {
        assertThatThrownBy(() -> validate("{\"business_unit_id\":1,\"casefile_status\":\"PUBLISHING_PENDING\",\""
            + property + "\":null}")).isInstanceOf(OpalApiException.class);
    }

    @ParameterizedTest
    @ValueSource(strings = {"REJECTED", "DELETED"})
    void rejectsReasonOverLimit(String target) {
        assertThatThrownBy(() -> validate("{\"business_unit_id\":1,\"casefile_status\":\"" + target
            + "\",\"status_message\":\"" + "x".repeat(251) + "\"}")).isInstanceOf(OpalApiException.class);
    }

    private static void validate(String json) {
        validator.validate("DraftCasefileUpdateRequest", json.getBytes(StandardCharsets.UTF_8));
    }
}
