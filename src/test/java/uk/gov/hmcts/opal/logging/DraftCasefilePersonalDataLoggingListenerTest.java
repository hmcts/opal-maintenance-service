package uk.gov.hmcts.opal.logging;

import ch.qos.logback.classic.Logger;
import ch.qos.logback.classic.spi.ILoggingEvent;
import ch.qos.logback.core.read.ListAppender;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.ArgumentCaptor;
import org.slf4j.LoggerFactory;
import uk.gov.hmcts.opal.event.DraftCasefileListPersonalDataEvent;
import uk.gov.hmcts.opal.event.DraftCasefilePersonalDataEvent;
import uk.gov.hmcts.opal.event.DraftCasefilePersonalDataEvent.Operation;
import uk.gov.hmcts.opal.event.DraftCasefilePersonalDataEvent.ParticipantCategory;
import uk.gov.hmcts.opal.logging.integration.dto.ParticipantIdentifier;
import uk.gov.hmcts.opal.logging.integration.dto.PersonalDataProcessingCategory;
import uk.gov.hmcts.opal.logging.integration.dto.PersonalDataProcessingLogDetails;
import uk.gov.hmcts.opal.logging.integration.service.LoggingService;

import java.time.Instant;
import java.time.ZoneOffset;
import java.util.EnumSet;
import java.util.List;
import java.util.Map;

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
    private final DraftCasefilePersonalDataEvent event = new DraftCasefilePersonalDataEvent(Operation.SUBMISSION,
        123L, 99L, "192.0.2.1",
        Instant.parse("2026-10-01T12:00:00.123456789Z"), EnumSet.allOf(ParticipantCategory.class));

    @Test
    void sendsOneCollectionPerCategoryWithIdentifiersAndExactSubmissionInstant() {
        when(logging.personalDataAccessLogAsync(any())).thenReturn(true);
        listener.onPersonalDataAccess(event);
        ArgumentCaptor<PersonalDataProcessingLogDetails> payloads =
            ArgumentCaptor.forClass(PersonalDataProcessingLogDetails.class);
        verify(logging, times(4)).personalDataAccessLogAsync(payloads.capture());
        assertThat(payloads.getAllValues()).extracting(PersonalDataProcessingLogDetails::getBusinessIdentifier)
            .containsExactly("Submit Draft Casefile - Respondent", "Submit Draft Casefile - Applicant / Beneficiary",
                "Submit Draft Casefile - Related parties", "Submit Draft Casefile - Minor Creditor");
        assertThat(payloads.getAllValues()).allSatisfy(payload -> {
            assertThat(payload.getCategory()).isEqualTo(PersonalDataProcessingCategory.COLLECTION);
            assertThat(payload.getCreatedAt()).isEqualTo(event.occurredAt().atOffset(ZoneOffset.UTC));
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
    void sendsConsultationMetadataOncePerCategory() {
        Instant viewedAt = Instant.parse("2026-10-03T12:00:00Z");
        var viewEvent = new DraftCasefilePersonalDataEvent(Operation.VIEW, 123L, 99L, "192.0.2.1",
            viewedAt, EnumSet.allOf(ParticipantCategory.class));
        when(logging.personalDataAccessLogAsync(any())).thenReturn(true);
        listener.onPersonalDataAccess(viewEvent);
        ArgumentCaptor<PersonalDataProcessingLogDetails> details =
            ArgumentCaptor.forClass(PersonalDataProcessingLogDetails.class);
        verify(logging, times(4)).personalDataAccessLogAsync(details.capture());
        assertThat(details.getAllValues()).extracting(PersonalDataProcessingLogDetails::getBusinessIdentifier)
            .containsExactly("View Draft Casefile - Respondent", "View Draft Casefile - Applicant / Beneficiary",
                "View Draft Casefile - Related parties", "View Draft Casefile - Minor Creditor");
        assertThat(details.getAllValues()).allSatisfy(entry -> {
            assertThat(entry.getCategory()).isEqualTo(PersonalDataProcessingCategory.CONSULTATION);
            assertThat(entry.getCreatedAt()).isEqualTo(viewedAt.atOffset(ZoneOffset.UTC));
            assertThat(entry.getCreatedBy().getIdentifier()).isEqualTo("99");
            assertThat(entry.getCreatedBy().getType().getType()).isEqualTo("OPAL_USER_ID");
            assertThat(entry.getIpAddress()).isEqualTo("192.0.2.1");
            assertThat(entry.getIndividuals()).singleElement().satisfies(identifier -> {
                assertThat(identifier.getIdentifier()).isEqualTo("123");
                assertThat(identifier.getType().getType()).isEqualTo("DRAFT_CASEFILE");
            });
            assertThat(entry.getRecipient()).isNull();
        });
    }

    @ParameterizedTest
    @EnumSource(value = Operation.class, names = {"SUBMISSION", "VIEW"})
    void falseResultsDoNotEscapeOrPreventLaterCategoriesAndDiagnosticsAreSafe(Operation operation) {
        when(logging.personalDataAccessLogAsync(any())).thenReturn(false);
        assertSafeFailureDiagnostics(operation);
    }

    @ParameterizedTest
    @EnumSource(value = Operation.class, names = {"SUBMISSION", "VIEW"})
    void exceptionsDoNotEscapeOrPreventLaterCategoriesAndDiagnosticsAreSafe(Operation operation) {
        when(logging.personalDataAccessLogAsync(any())).thenThrow(new IllegalStateException(
            "SYNTHETIC_CASEFILE SYNTHETIC_NAME SYNTHETIC_BANK 192.0.2.1"));
        assertSafeFailureDiagnostics(operation);
    }

    private void assertSafeFailureDiagnostics(Operation operation) {
        var failedEvent = new DraftCasefilePersonalDataEvent(operation, event.draftId(), event.userId(),
            event.ipAddress(), event.occurredAt(), event.participantCategories());
        Logger logger = (Logger) LoggerFactory.getLogger(DraftCasefilePersonalDataLoggingListener.class);
        ListAppender<ILoggingEvent> appender = new ListAppender<>();
        appender.start();
        logger.addAppender(appender);
        try {
            assertThatCode(() -> listener.onPersonalDataAccess(failedEvent)).doesNotThrowAnyException();
            ArgumentCaptor<PersonalDataProcessingLogDetails> details =
                ArgumentCaptor.forClass(PersonalDataProcessingLogDetails.class);
            verify(logging, times(4)).personalDataAccessLogAsync(details.capture());
            assertThat(details.getAllValues()).extracting(PersonalDataProcessingLogDetails::getBusinessIdentifier)
                .containsExactly(operationPrefix(operation) + "Respondent",
                    operationPrefix(operation) + "Applicant / Beneficiary",
                    operationPrefix(operation) + "Related parties", operationPrefix(operation) + "Minor Creditor");
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

    private static String operationPrefix(Operation operation) {
        return operation == Operation.SUBMISSION ? "Submit Draft Casefile - " : "View Draft Casefile - ";
    }

    @Test
    void listsSendOneConsultationPerSnapshotCategoryWithUniqueRecordIdentifiers() {
        Instant viewedAt = Instant.parse("2026-10-05T12:00:00.123456Z");
        var event = new DraftCasefileListPersonalDataEvent(99L, "192.0.2.1", viewedAt, Map.of(
            ParticipantCategory.RESPONDENT, List.of(123L, 123L, 456L),
            ParticipantCategory.APPLICANT_BENEFICIARY, List.of(123L, 456L),
            ParticipantCategory.MINOR_CREDITOR, List.of(456L, 456L)));
        when(logging.personalDataAccessLogAsync(any())).thenReturn(true);
        listener.onPersonalDataListAccess(event);
        var captured = ArgumentCaptor.forClass(PersonalDataProcessingLogDetails.class);
        verify(logging, times(3)).personalDataAccessLogAsync(captured.capture());
        assertThat(captured.getAllValues()).extracting(PersonalDataProcessingLogDetails::getBusinessIdentifier)
            .containsExactly("View Draft Casefiles - Respondent", "View Draft Casefiles - Applicant / Beneficiary",
                "View Draft Casefiles - Minor Creditor");
        assertThat(captured.getAllValues().getFirst().getIndividuals())
            .extracting(ParticipantIdentifier::getIdentifier).containsExactly("123", "456");
        assertThat(captured.getAllValues().get(2).getIndividuals())
            .extracting(ParticipantIdentifier::getIdentifier).containsExactly("456");
        assertThat(captured.getAllValues()).allSatisfy(details -> {
            assertThat(details.getCategory()).isEqualTo(PersonalDataProcessingCategory.CONSULTATION);
            assertThat(details.getCreatedBy().getIdentifier()).isEqualTo("99");
            assertThat(details.getCreatedBy().getType().getType()).isEqualTo("OPAL_USER_ID");
            assertThat(details.getCreatedAt()).isEqualTo(viewedAt.atOffset(ZoneOffset.UTC));
            assertThat(details.getIpAddress()).isEqualTo("192.0.2.1");
            assertThat(details.getRecipient()).isNull();
            assertThat(details.getIndividuals()).allSatisfy(id ->
                assertThat(id.getType().getType()).isEqualTo("DRAFT_CASEFILE"));
        });
    }

    @ParameterizedTest
    @ValueSource(booleans = {false, true})
    void listPublisherFailurePreservesResultAndAttemptsEveryCategoryWithSafeDiagnostics(boolean throwsException) {
        if (throwsException) {
            when(logging.personalDataAccessLogAsync(any())).thenThrow(
                new IllegalStateException("SYNTHETIC_PRIVATE_LIST_VALUE"));
        } else {
            when(logging.personalDataAccessLogAsync(any())).thenReturn(false);
        }
        var listEvent = new DraftCasefileListPersonalDataEvent(99L, "192.0.2.1", Instant.EPOCH, Map.of(
            ParticipantCategory.RESPONDENT, List.of(123L, 456L),
            ParticipantCategory.APPLICANT_BENEFICIARY, List.of(123L, 456L),
            ParticipantCategory.MINOR_CREDITOR, List.of(456L)));
        Logger logger = (Logger) LoggerFactory.getLogger(DraftCasefilePersonalDataLoggingListener.class);
        ListAppender<ILoggingEvent> appender = new ListAppender<>();
        appender.start();
        logger.addAppender(appender);
        try {
            assertThatCode(() -> listener.onPersonalDataListAccess(listEvent)).doesNotThrowAnyException();
            verify(logging, times(3)).personalDataAccessLogAsync(any());
            assertThat(appender.list).hasSize(3).allSatisfy(entry -> {
                assertThat(entry.getFormattedMessage()).doesNotContain("SYNTHETIC", "192.0.2.1", "123", "99");
                assertThat(entry.getThrowableProxy()).isNull();
            });
        } finally {
            logger.detachAppender(appender);
            appender.stop();
        }
    }
}
