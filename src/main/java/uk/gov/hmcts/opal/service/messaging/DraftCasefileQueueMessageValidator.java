package uk.gov.hmcts.opal.service.messaging;

import com.google.common.net.InetAddresses;
import org.springframework.stereotype.Component;
import tools.jackson.core.JacksonException;
import tools.jackson.core.StreamReadFeature;
import tools.jackson.databind.DeserializationFeature;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

import java.time.Instant;
import java.time.format.DateTimeParseException;

@Component
public class DraftCasefileQueueMessageValidator {
    private static final JsonMapper JSON = JsonMapper.builder()
        .enable(StreamReadFeature.STRICT_DUPLICATE_DETECTION)
        .enable(DeserializationFeature.FAIL_ON_TRAILING_TOKENS).build();

    public DraftCasefileQueueMessage parse(String payload) {
        if (payload == null) {
            throw invalid();
        }
        try {
            JsonNode body = JSON.readTree(payload);
            if (body == null || !body.isObject()) {
                throw invalid();
            }
            Long id = identifier(body.get("draft_casefile_id"));
            Long checker = body.has("checker_user_id") ? identifier(body.get("checker_user_id")) : null;
            String ip = null;
            if (body.has("originating_ip_address")) {
                JsonNode address = body.get("originating_ip_address");
                if (!address.isString() || !InetAddresses.isInetAddress(address.asString())) {
                    throw invalid();
                }
                ip = address.asString();
            }
            String approvedAt = null;
            if (body.has("approval_timestamp")) {
                JsonNode timestamp = body.get("approval_timestamp");
                if (!timestamp.isString()) {
                    throw invalid();
                }
                approvedAt = timestamp.asString();
                validateTimestamp(approvedAt);
            }
            return new DraftCasefileQueueMessage(id, checker, ip, approvedAt);
        } catch (JacksonException exception) {
            throw invalid();
        }
    }

    private static void validateTimestamp(String value) {
        if (value == null) {
            throw invalid();
        }
        try {
            Instant timestamp = Instant.parse(value);
            if (timestamp.getNano() % 1000 != 0 || !timestamp.toString().equals(value)) {
                throw invalid();
            }
        } catch (DateTimeParseException exception) {
            throw invalid();
        }
    }

    public void validateAuditContext(DraftCasefileQueueMessage message) {
        if (message == null || message.draftCasefileId() == null || message.draftCasefileId() <= 0
            || message.checkerUserId() == null || message.checkerUserId() <= 0
            || message.originatingIpAddress() == null
            || !InetAddresses.isInetAddress(message.originatingIpAddress())) {
            throw invalid();
        }
        validateTimestamp(message.approvalTimestamp());
    }

    private static Long identifier(JsonNode value) {
        if (value == null || !value.isIntegralNumber() || !value.canConvertToLong() || value.longValue() <= 0) {
            throw invalid();
        }
        return value.longValue();
    }

    private static IllegalArgumentException invalid() {
        return new IllegalArgumentException("Invalid publication message");
    }
}
