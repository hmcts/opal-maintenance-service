package uk.gov.hmcts.opal.logging;

import ch.qos.logback.classic.Level;
import ch.qos.logback.classic.Logger;
import ch.qos.logback.classic.spi.ILoggingEvent;
import ch.qos.logback.core.read.ListAppender;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jms.UncategorizedJmsException;
import org.springframework.jms.core.JmsTemplate;
import org.springframework.jms.core.MessagePostProcessor;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionTemplate;
import tools.jackson.databind.json.JsonMapper;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.authentication.MaintenanceUser;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.event.DraftCasefileSubmittedEvent;
import uk.gov.hmcts.opal.event.DraftCasefileSubmittedEvent.ParticipantCategory;
import uk.gov.hmcts.opal.generated.model.CasefileType;
import uk.gov.hmcts.opal.generated.model.DraftCasefileAddRequest;
import uk.gov.hmcts.opal.logging.integration.config.PdpoAsyncProperties;
import uk.gov.hmcts.opal.logging.integration.dto.PersonalDataProcessingLogDetails;
import uk.gov.hmcts.opal.logging.integration.mapper.PdpoQueueLogDetailsMapperImpl;
import uk.gov.hmcts.opal.logging.integration.service.LoggingService;
import uk.gov.hmcts.opal.logging.integration.service.LoggingServiceImpl;
import uk.gov.hmcts.opal.logging.integration.service.PdpoAsyncPublisherImpl;
import uk.gov.hmcts.opal.logging.integration.service.PdpoSyncPublisher;
import uk.gov.hmcts.opal.mapper.DraftCasefileMapper;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;

import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.EnumSet;
import java.util.Set;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@TestPropertySource(properties = {
    "spring.flyway.locations=classpath:db/migration/ddl",
    "opal.redis.enabled=false",
    "management.health.redis.enabled=false"
})
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
class DraftCasefilePersonalDataLoggingTransactionIntegrationTest extends BaseIntegrationTest {

    private static final Instant SUBMITTED = Instant.parse("2026-10-01T12:00:00.123456Z");
    @Autowired
    private ApplicationEventPublisher events;
    @Autowired
    private PlatformTransactionManager transactionManager;
    @Autowired
    private DraftCasefileRepository repository;
    @Autowired
    private DraftCasefileMapper mapper;
    @Autowired
    private JdbcTemplate jdbc;
    @MockitoBean
    private LoggingService logging;
    private Long savedId;

    @AfterEach
    void cleanUpOwnRows() {
        new TransactionTemplate(transactionManager).executeWithoutResult(transaction -> {
            if (savedId != null) {
                repository.deleteById(savedId);
                repository.flush();
            }
            jdbc.update("DELETE FROM business_units WHERE business_unit_id = 31012");
        });
    }

    @Test
    void publishesOnlyAfterCommitAndCommittedDraftIsVisibleInANewTransaction() {
        AtomicInteger verifiedReads = new AtomicInteger();
        when(logging.personalDataAccessLogAsync(any())).thenAnswer(invocation -> {
            PersonalDataProcessingLogDetails details = invocation.getArgument(0);
            TransactionTemplate independentRead = new TransactionTemplate(transactionManager);
            independentRead.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
            independentRead.executeWithoutResult(transaction -> {
                DraftCasefileEntity saved = repository.findById(savedId).orElseThrow();
                assertThat(saved.getCreatedDate().toInstant(ZoneOffset.UTC)).isEqualTo(SUBMITTED);
                assertThat(details.getIndividuals().getFirst().getIdentifier()).isEqualTo(savedId.toString());
                assertThat(details.getCreatedAt().toInstant()).isEqualTo(SUBMITTED);
                verifiedReads.incrementAndGet();
            });
            return true;
        });
        new TransactionTemplate(transactionManager).executeWithoutResult(transaction -> {
            saveDraftAndPublish();
            verifyNoInteractions(logging);
        });
        verify(logging, times(4)).personalDataAccessLogAsync(any());
        assertThat(verifiedReads).hasValue(4);
    }

    @Test
    void rollbackDoesNotPublishOrPersistDraft() {
        new TransactionTemplate(transactionManager).executeWithoutResult(transaction -> {
            saveDraftAndPublish();
            verifyNoInteractions(logging);
            transaction.setRollbackOnly();
        });
        verifyNoInteractions(logging);
        assertThat(repository.findById(savedId)).isEmpty();
        savedId = null;
    }

    @Test
    void eventOutsideTransactionDoesNotPublish() {
        events.publishEvent(event(123L));
        verifyNoInteractions(logging);
    }

    @ParameterizedTest
    @ValueSource(booleans = {false, true})
    void publisherFailurePreservesCommittedDraftAndProcessesLaterCategories(boolean throwsException) {
        if (throwsException) {
            when(logging.personalDataAccessLogAsync(any())).thenThrow(new IllegalStateException("Synthetic failure"));
        } else {
            when(logging.personalDataAccessLogAsync(any())).thenReturn(false);
        }
        assertThatCode(() -> new TransactionTemplate(transactionManager).executeWithoutResult(transaction -> {
            saveDraftAndPublish();
            verifyNoInteractions(logging);
        })).doesNotThrowAnyException();
        assertThat(repository.findById(savedId)).isPresent();
        verify(logging, times(4)).personalDataAccessLogAsync(any());
    }

    @Test
    void realPublisherFailureUsesApplicationLoggingConfigurationWithoutExposingPayloadOrException() {
        JmsTemplate jms = mock(JmsTemplate.class);
        doThrow(new UncategorizedJmsException("SYNTHETIC_CASEFILE SYNTHETIC_NAME SYNTHETIC_BANK",
            new IllegalStateException("SYNTHETIC_RAW_EXCEPTION")))
            .when(jms).convertAndSend(eq("synthetic-pdpo"), any(), any(MessagePostProcessor.class));
        PdpoAsyncProperties properties = new PdpoAsyncProperties("amqp", "", "synthetic-pdpo", "PDPO",
            2, Duration.ZERO, Duration.ofSeconds(1));
        PdpoAsyncPublisherImpl publisher = new PdpoAsyncPublisherImpl(jms, properties,
            new PdpoQueueLogDetailsMapperImpl());
        LoggingService realLogging = new LoggingServiceImpl(publisher, mock(PdpoSyncPublisher.class));
        DraftCasefilePersonalDataLoggingListener listener = new DraftCasefilePersonalDataLoggingListener(realLogging);
        Logger root = (Logger) LoggerFactory.getLogger(Logger.ROOT_LOGGER_NAME);
        ListAppender<ILoggingEvent> appender = new ListAppender<>();
        appender.start();
        root.addAppender(appender);
        try {
            listener.onSubmitted(new DraftCasefileSubmittedEvent(987654321L, 987654322L, "192.0.2.77", SUBMITTED,
                Set.of(ParticipantCategory.RESPONDENT)));
            verify(jms, times(properties.maxRetries())).convertAndSend(eq("synthetic-pdpo"), any(),
                any(MessagePostProcessor.class));
            assertThat(properties.retryDelay()).isEqualTo(Duration.ZERO);
            assertThat(appender.list).singleElement().satisfies(entry -> {
                assertThat(entry.getLevel()).isEqualTo(Level.ERROR);
                assertThat(entry.getFormattedMessage())
                    .isEqualTo("Draft Casefile personal data logging failed for role RESPONDENT");
                assertThat(entry.getThrowableProxy()).isNull();
            });
            assertThat(appender.list).extracting(ILoggingEvent::getFormattedMessage)
                .allSatisfy(message -> assertThat(message).doesNotContain("SYNTHETIC", "987654321", "987654322",
                    "192.0.2.77", "logDetails", "individuals"));
        } finally {
            root.detachAppender(appender);
            appender.stop();
        }
    }

    private void saveDraftAndPublish() {
        jdbc.update("""
            INSERT INTO business_units
                (business_unit_id, business_unit_code, business_unit_name, business_unit_type, welsh_language)
            VALUES (31012, 'ZD12', 'Synthetic Logging Unit', 'Area', false)
            """);
        DraftCasefileAddRequest request = new DraftCasefileAddRequest().businessUnitId((short) 31012)
            .casefileType(CasefileType.REMO_IN).casefile(JsonMapper.builder().build().readTree("""
                {"respondent_account":{"respondent":{"party_details":{"organisation":false,
                  "individual_details":{"surname":"Synthetic"}}}},"applicant":{"party_details":{
                  "organisation":true,"organisation_details":{"organisation_name":"Synthetic Organisation"}}}}
                """));
        savedId = repository.saveAndFlush(mapper.toEntity(request,
            new MaintenanceUser(99L, "synthetic-bu-user", "Synthetic User", null), SUBMITTED)).getDraftCasefileId();
        events.publishEvent(event(savedId));
    }

    private static DraftCasefileSubmittedEvent event(Long id) {
        return new DraftCasefileSubmittedEvent(id, 99L, "192.0.2.1", SUBMITTED,
            EnumSet.allOf(ParticipantCategory.class));
    }
}
