package uk.gov.hmcts.reform.opal.authentication.config;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;
import uk.gov.hmcts.opal.common.dto.ToJsonString;
import uk.gov.hmcts.opal.common.logging.LogUtil;
import uk.gov.hmcts.opal.common.logging.SecurityEventLoggingService;

import java.io.IOException;
import java.io.PrintWriter;
import java.net.URI;
import java.util.Map;

@Component
public class PrivacyPreservingOauth2AuthenticationEntryPoint implements AuthenticationEntryPoint {

    private static final String EVENT_ACTION_OUTCOME = "Failure";
    private static final String EVENT_NAME = "Authorisation Access Control";
    private static final String EVENT_OP_TYPE = "Authentication";
    private static final String UNKNOWN = "Unknown";
    private static final String UNAUTHENTICATED = "Unauthenticated";

    private final SecurityEventLoggingService securityEventLoggingService;

    public PrivacyPreservingOauth2AuthenticationEntryPoint(
        SecurityEventLoggingService securityEventLoggingService) {
        this.securityEventLoggingService = securityEventLoggingService;
    }

    @Override
    public void commence(
        HttpServletRequest request,
        HttpServletResponse response,
        AuthenticationException authenticationException) throws IOException {
        String resource = request.getRequestURI() == null ? UNKNOWN : request.getRequestURI();
        Map<String, Object> eventData = Map.of(
            "UserIdentifier", UNAUTHENTICATED,
            "Details", "Bearer authentication failed",
            "Resource", resource
        );
        securityEventLoggingService.logEvent(
            EVENT_NAME,
            EVENT_ACTION_OUTCOME,
            null,
            EVENT_OP_TYPE,
            LogUtil.getRequestTimestamp(),
            eventData
        );

        String operationId = LogUtil.getOrCreateOpalOperationId();
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
            HttpStatus.UNAUTHORIZED,
            "You are not authorized to access this resource"
        );
        problemDetail.setTitle("Unauthorized");
        problemDetail.setType(URI.create("https://hmcts.gov.uk/problems/unauthorized"));
        problemDetail.setInstance(URI.create("https://hmcts.gov.uk/problems/instance/" + operationId));
        problemDetail.setProperty("operation_id", operationId);
        problemDetail.setProperty("retriable", false);

        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        response.setContentType("application/json");
        try (PrintWriter writer = response.getWriter()) {
            writer.write(ToJsonString.OBJECT_MAPPER.writeValueAsString(problemDetail));
        }
    }
}
