package uk.gov.hmcts.opal.logging;

import ch.qos.logback.classic.Logger;
import ch.qos.logback.classic.spi.ILoggingEvent;
import ch.qos.logback.core.read.ListAppender;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.slf4j.LoggerFactory;
import uk.gov.hmcts.opal.event.DraftCasefileSubmittedEvent;
import uk.gov.hmcts.opal.event.DraftCasefileSubmittedEvent.ParticipantCategory;
import uk.gov.hmcts.opal.logging.integration.dto.PersonalDataProcessingCategory;
import uk.gov.hmcts.opal.logging.integration.dto.PersonalDataProcessingLogDetails;
import uk.gov.hmcts.opal.logging.integration.service.LoggingService;

import java.time.Instant;
import java.time.ZoneOffset;
import java.util.EnumSet;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class DraftCasefilePersonalDataLoggingListenerTest {

    private final LoggingService logging = mock(LoggingService.class);
    private final DraftCasefilePersonalDataLoggingListener listener =
        new DraftCasefilePersonalDataLoggingListener(logging);
    private final DraftCasefileSubmittedEvent event = new DraftCasefileSubmittedEvent(123L, 99L, "192.0.2.1",
        Instant.parse("2026-10-01T12:00:00.123456789Z"), EnumSet.allOf(ParticipantCategory.class));

    @Test
    void sendsOneCollectionPerCategoryWithIdentifiersAndExactSubmissionInstant() {
        when(logging.personalDataAccessLogAsync(any())).thenReturn(true);
        listener.onSubmitted(event);
        ArgumentCaptor<PersonalDataProcessingLogDetails> payloads =
            ArgumentCaptor.forClass(PersonalDataProcessingLogDetails.class);
        verify(logging, times(4)).personalDataAccessLogAsync(payloads.capture());
        assertThat(payloads.getAllValues()).extracting(PersonalDataProcessingLogDetails::getBusinessIdentifier)
            .containsExactly("Submit Draft Casefile - Respondent", "Submit Draft Casefile - Applicant / Beneficiary",
                "Submit Draft Casefile - Related parties", "Submit Draft Casefile - Minor Creditor");
        assertThat(payloads.getAllValues()).allSatisfy(payload -> {
            assertThat(payload.getCategory()).isEqualTo(PersonalDataProcessingCategory.COLLECTION);
            assertThat(payload.getCreatedAt()).isEqualTo(event.submittedAt().atOffset(ZoneOffset.UTC));
            assertThat(payload.getCreatedBy().getIdentifier()).isEqualTo("99");
            assertThat(payload.getCreatedBy().getType().getType()).isEqualTo("OPAL_USER_ID");
            assertThat(payload.getIpAddress()).isEqualTo("192.0.2.1");
            assertThat(payload.getRecipient()).isNull();
            assertThat(payload.getIndividuals()).singleElement().satisfies(individual -> {
                assertThat(individual.getIdentifier()).isEqualTo("123");
                assertThat(individual.getType().getType()).isEqualTo("DRAFT_CASEFILE");
            });
        });
    }

    @Test
    void falseResultsDoNotEscapeOrPreventLaterCategories() {
        when(logging.personalDataAccessLogAsync(any())).thenReturn(false);
        assertThatCode(() -> listener.onSubmitted(event)).doesNotThrowAnyException();
        verify(logging, times(event.participantCategories().size())).personalDataAccessLogAsync(any());
    }

    @Test
    void exceptionsDoNotEscapeOrPreventLaterCategoriesAndDiagnosticsAreSafe() {
        when(logging.personalDataAccessLogAsync(any())).thenThrow(new IllegalStateException(
            "SYNTHETIC_CASEFILE SYNTHETIC_NAME SYNTHETIC_BANK 192.0.2.1"));
        Logger logger = (Logger) LoggerFactory.getLogger(DraftCasefilePersonalDataLoggingListener.class);
        ListAppender<ILoggingEvent> appender = new ListAppender<>();
        appender.start();
        logger.addAppender(appender);
        try {
            assertThatCode(() -> listener.onSubmitted(event)).doesNotThrowAnyException();
            verify(logging, times(4)).personalDataAccessLogAsync(any());
            assertThat(appender.list).hasSize(4).allSatisfy(entry -> {
                assertThat(entry.getFormattedMessage())
                    .startsWith("Draft Casefile personal data logging failed for role ")
                    .doesNotContain("SYNTHETIC", "192.0.2.1", "123", "99");
                assertThat(entry.getThrowableProxy()).isNull();
            });
        } finally {
            logger.detachAppender(appender);
            appender.stop();
        }
    }
}
