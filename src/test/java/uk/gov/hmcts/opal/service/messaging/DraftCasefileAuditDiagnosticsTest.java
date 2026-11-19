package uk.gov.hmcts.opal.service.messaging;

import ch.qos.logback.classic.Level;
import ch.qos.logback.classic.Logger;
import ch.qos.logback.classic.spi.ILoggingEvent;
import ch.qos.logback.core.read.ListAppender;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.MethodSource;
import org.slf4j.LoggerFactory;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetails;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import java.util.List;
import java.util.stream.Stream;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DraftCasefileAuditDiagnosticsTest {
    private static final String PRIVATE = "SYNTHETIC_PRIVATE_AUDIT";
    private static final String TIMESTAMP = "2026-11-19T16:16:58Z";
    private final DraftCasefileQueueMessageValidator validator = new DraftCasefileQueueMessageValidator();
    private final Logger logger = (Logger) LoggerFactory.getLogger(DraftCasefileQueueMessageValidator.class);
    private final ListAppender<ILoggingEvent> captured = new ListAppender<>();
    private Level previousLevel;

    @BeforeEach
    void captureDiagnostics() {
        previousLevel = logger.getLevel();
        logger.setLevel(Level.WARN);
        captured.start();
        logger.addAppender(captured);
    }

    @AfterEach
    void clearContext() {
        logger.detachAppender(captured);
        logger.setLevel(previousLevel);
        captured.stop();
        RequestContextHolder.resetRequestAttributes();
        SecurityContextHolder.clearContext();
    }

    @ParameterizedTest
    @MethodSource("invalidMessages")
    void identifiesFailedFieldWithoutExposingValues(DraftCasefileQueueMessage message, String reason) {
        assertRejected(message);

        assertThat(captured.list).singleElement().satisfies(event -> {
            assertThat(event.getLevel()).isEqualTo(Level.WARN);
            assertThat(event.getFormattedMessage()).startsWith("Publication audit validation failed: reason=" + reason)
                .doesNotContain(PRIVATE, "192.0.2.1", TIMESTAMP, "987654321", "876543219");
            assertThat(event.getThrowableProxy()).isNull();
        });
    }

    static Stream<Arguments> invalidMessages() {
        return Stream.of(
            Arguments.of(null, "MESSAGE_MISSING"),
            Arguments.of(message(null, 876543219L, "192.0.2.1", TIMESTAMP), "DRAFT_CASEFILE_ID_INVALID"),
            Arguments.of(message(0L, 876543219L, "192.0.2.1", TIMESTAMP), "DRAFT_CASEFILE_ID_INVALID"),
            Arguments.of(message(-1L, 876543219L, "192.0.2.1", TIMESTAMP), "DRAFT_CASEFILE_ID_INVALID"),
            Arguments.of(message(987654321L, null, "192.0.2.1", TIMESTAMP), "CHECKER_USER_ID_INVALID"),
            Arguments.of(message(987654321L, 0L, "192.0.2.1", TIMESTAMP), "CHECKER_USER_ID_INVALID"),
            Arguments.of(message(987654321L, -1L, "192.0.2.1", TIMESTAMP), "CHECKER_USER_ID_INVALID"),
            Arguments.of(message(987654321L, 876543219L, null, TIMESTAMP), "IP_ADDRESS_MISSING"),
            Arguments.of(message(987654321L, 876543219L, " ", TIMESTAMP), "IP_ADDRESS_MISSING"),
            Arguments.of(message(987654321L, 876543219L, PRIVATE, TIMESTAMP), "IP_ADDRESS_INVALID"),
            Arguments.of(message(987654321L, 876543219L, "192.0.2.1", null), "APPROVAL_TIMESTAMP_INVALID"),
            Arguments.of(message(987654321L, 876543219L, "192.0.2.1", PRIVATE), "APPROVAL_TIMESTAMP_INVALID")
        );
    }

    @ParameterizedTest
    @CsvSource({"false,NONE,false,false", "true,NONE,false,false", "false,WEB,true,true",
        "true,WEB,true,true", "true,OTHER,true,false"})
    void reportsOnlyAvailabilityForIpFailure(boolean header, String detailsType, boolean detailsAvailable,
                                            boolean webDetails) {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRemoteAddr("192.0.2.1");
        request.addHeader("Authorization", PRIVATE);
        if (header) {
            request.addHeader("X-User-IP", PRIVATE);
        }
        RequestContextHolder.setRequestAttributes(new ServletRequestAttributes(request));
        var authentication = UsernamePasswordAuthenticationToken.authenticated(PRIVATE, PRIVATE, List.of());
        authentication.setDetails(switch (detailsType) {
            case "WEB" -> new WebAuthenticationDetails(request);
            case "OTHER" -> PRIVATE;
            default -> null;
        });
        SecurityContextHolder.getContext().setAuthentication(authentication);

        assertRejected(message(987654321L, 876543219L, PRIVATE, TIMESTAMP));

        assertThat(captured.list).singleElement().satisfies(event -> {
            assertThat(event.getFormattedMessage()).isEqualTo(
                "Publication audit validation failed: reason=IP_ADDRESS_INVALID, ip_header_available=" + header
                    + ", authentication_details_available=" + detailsAvailable
                    + ", web_authentication_details=" + webDetails);
            assertThat(event.getThrowableProxy()).isNull();
        });
    }

    @Test
    void missingRequestAndAuthenticationRemainGeneric() {
        assertRejected(message(42L, 123L, null, TIMESTAMP));

        assertThat(captured.list).singleElement().satisfies(event -> assertThat(event.getFormattedMessage())
            .isEqualTo("Publication audit validation failed: reason=IP_ADDRESS_MISSING, ip_header_available=false, "
                + "authentication_details_available=false, web_authentication_details=false"));
    }

    @Test
    void validContextDoesNotProduceDiagnostics() {
        validator.validateAuditContext(message(42L, 123L, "192.0.2.1", TIMESTAMP));

        assertThat(captured.list).isEmpty();
    }

    private void assertRejected(DraftCasefileQueueMessage message) {
        assertThatThrownBy(() -> validator.validateAuditContext(message))
            .isInstanceOf(IllegalArgumentException.class).hasMessage("Invalid publication message").hasNoCause();
    }

    private static DraftCasefileQueueMessage message(Long draft, Long checker, String address, String timestamp) {
        return new DraftCasefileQueueMessage(draft, checker, address, timestamp);
    }
}
