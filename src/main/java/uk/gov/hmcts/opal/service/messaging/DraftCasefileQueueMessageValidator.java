package uk.gov.hmcts.opal.service.messaging;

import com.google.common.net.InetAddresses;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetails;
import org.springframework.stereotype.Component;
import tools.jackson.core.JacksonException;
import tools.jackson.core.StreamReadFeature;
import tools.jackson.databind.DeserializationFeature;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;
import uk.gov.hmcts.opal.common.logging.LogUtil;

import java.time.Instant;
import java.time.format.DateTimeParseException;

@Component
public class DraftCasefileQueueMessageValidator {
    private static final Logger LOG = LoggerFactory.getLogger(DraftCasefileQueueMessageValidator.class);
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
        if (message == null) {
            throw invalidAuditContext("MESSAGE_MISSING");
        }
        if (message.draftCasefileId() == null || message.draftCasefileId() <= 0) {
            throw invalidAuditContext("DRAFT_CASEFILE_ID_INVALID");
        }
        if (message.checkerUserId() == null || message.checkerUserId() <= 0) {
            throw invalidAuditContext("CHECKER_USER_ID_INVALID");
        }
        if (message.originatingIpAddress() == null || message.originatingIpAddress().isBlank()) {
            throw invalidIp("IP_ADDRESS_MISSING");
        }
        if (!InetAddresses.isInetAddress(message.originatingIpAddress())) {
            throw invalidIp("IP_ADDRESS_INVALID");
        }
        try {
            validateTimestamp(message.approvalTimestamp());
        } catch (IllegalArgumentException exception) {
            throw invalidAuditContext("APPROVAL_TIMESTAMP_INVALID");
        }
    }

    private static IllegalArgumentException invalidAuditContext(String reason) {
        LOG.warn("Publication audit validation failed: reason={}", reason);
        return invalid();
    }

    private static IllegalArgumentException invalidIp(String reason) {
        boolean headerAvailable = LogUtil.getCurrentRequest()
            .map(request -> request.getHeader("X-User-IP"))
            .filter(value -> !value.isBlank()).isPresent();
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        Object details = authentication == null ? null : authentication.getDetails();
        LOG.warn("Publication audit validation failed: reason={}, ip_header_available={}, "
                + "authentication_details_available={}, web_authentication_details={}",
            reason, headerAvailable, details != null, details instanceof WebAuthenticationDetails);
        return invalid();
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
