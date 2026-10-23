package uk.gov.hmcts.opal.controllers;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.zaxxer.hikari.HikariDataSource;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.springframework.aop.aspectj.AbstractAspectJAdvice;
import org.springframework.aop.framework.Advised;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jms.UncategorizedJmsException;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.springframework.test.context.jdbc.Sql;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.interceptor.TransactionInterceptor;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.transaction.support.TransactionTemplate;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.common.user.authorisation.model.Permission;
import uk.gov.hmcts.opal.dto.PublicationEvidenceCounts;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.generated.model.DraftCasefileUpdateRequest;
import uk.gov.hmcts.opal.logging.integration.service.LoggingService;
import uk.gov.hmcts.opal.mapper.DraftCasefileGetMapper;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.repository.PublicationEvidenceRepository;
import uk.gov.hmcts.opal.service.DraftCasefileService;
import uk.gov.hmcts.opal.service.DraftCasefileCleanupService;
import uk.gov.hmcts.opal.service.PublicationEvidenceService;
import uk.gov.hmcts.opal.service.messaging.DraftCasefileQueuePublisherImpl;
import uk.gov.hmcts.opal.service.messaging.PublicationEvidenceWriter;
import uk.gov.hmcts.opal.support.DraftCasefileHttpFixture;

import java.time.Duration;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Set;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.awaitility.Awaitility.await;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.test.context.jdbc.Sql.ExecutionPhase.AFTER_TEST_METHOD;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
@TestPropertySource(properties = {"spring.flyway.locations=classpath:db/migration/ddl", "opal.redis.enabled=false",
    "management.health.redis.enabled=false", "opal.testing-support-endpoints.enabled=true",
    "spring.datasource.hikari.maximum-pool-size=10", "spring.datasource.hikari.connection-timeout=2000"})
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@Sql({"/draft-casefile/reference-fixtures.sql", "/draft-casefile/cleanup-scope-fixtures.sql"})
@Sql(scripts = "/draft-casefile/cleanup-scope-cleanup.sql", executionPhase = AFTER_TEST_METHOD)
class PublicationEvidenceConcurrencyIntegrationTest extends BaseIntegrationTest {

    private static final String RUN = "E2E-0123456789abcdef";
    private static final String PATH = "/testing-support/draft-casefiles/{id}/publication-evidence";
    @Autowired
    private MockMvc mvc;
    @Autowired
    private ObjectMapper json;
    @Autowired
    private HikariDataSource pool;
    @Autowired
    private DraftCasefileService service;
    @Autowired
    private DraftCasefileRepository drafts;
    @Autowired
    private DraftCasefileCleanupService cleanup;
    @Autowired
    private PublicationEvidenceService reads;
    @Autowired
    private PlatformTransactionManager transactionManager;
    @MockitoSpyBean
    private PublicationEvidenceRepository evidence;
    @Autowired
    private PublicationEvidenceWriter writer;
    @MockitoSpyBean
    private DraftCasefileGetMapper mapper;
    @MockitoBean
    private DraftCasefileQueuePublisherImpl delegate;
    @MockitoBean
    private LoggingService logging;

    @BeforeEach
    void setUp() {
        when(logging.personalDataAccessLogAsync(any())).thenReturn(true);
    }

    @Test
    void readRetainsUncertainAndUnfinishedSnapshotWhenCleanupCommitsAfterObservationLookup() throws Exception {
        long id = submit();
        register(id);
        var observation = evidence.findObservation(id).orElseThrow();
        writer.markUncertain(writer.begin(id).orElseThrow());
        writer.begin(id).orElseThrow();
        CountDownLatch observationLoaded = new CountDownLatch(1);
        CountDownLatch cleanupCommitted = new CountDownLatch(1);
        AtomicReference<Thread> reader = new AtomicReference<>();
        doAnswer(invocation -> {
            Object result = invocation.callRealMethod();
            if (Thread.currentThread() == reader.get()) {
                observationLoaded.countDown();
                assertThat(cleanupCommitted.await(10, TimeUnit.SECONDS)).isTrue();
            }
            return result;
        }).when(evidence).findObservation(id);
        var executor = Executors.newSingleThreadExecutor();
        try {
            final Future<JsonNode> response = executor.submit(() -> {
                reader.set(Thread.currentThread());
                return json.readTree(mvc.perform(get(PATH, id)
                    .with(authentication(DraftCasefileHttpFixture.token((short) 1)))
                    .header("Test-Run-Reference", RUN)).andExpect(status().isOk())
                    .andReturn().getResponse().getContentAsString());
            });
            assertThat(observationLoaded.await(10, TimeUnit.SECONDS)).isTrue();
            mvc.perform(delete("/testing-support/draft-casefiles/{id}", id)
                .with(authentication(DraftCasefileHttpFixture.token((short) 1)))
                .header("Test-Run-Reference", RUN)).andExpect(status().isNoContent());
            assertThat(drafts.findById(id)).isEmpty();
            assertThat(evidence.findObservation(id)).isEmpty();
            cleanupCommitted.countDown();
            JsonNode snapshot = response.get(10, TimeUnit.SECONDS);
            assertThat(snapshot.path("observation_id").asText()).isEqualTo(observation.observationId().toString());
            assertThat(snapshot.path("send_attempt_count").asLong()).isEqualTo(2);
            assertThat(snapshot.path("uncertain_send_count").asLong()).isEqualTo(1);
            assertThat(snapshot.path("unfinished_send_count").asLong()).isEqualTo(1);
            assertThat(snapshot.path("evidence_complete").asBoolean()).isFalse();
        } finally {
            cleanupCommitted.countDown();
            executor.shutdownNow();
            assertThat(executor.awaitTermination(10, TimeUnit.SECONDS)).isTrue();
        }
    }

    @ParameterizedTest
    @CsvSource({"false,false", "true,false", "false,true", "true,true"})
    void poolLimitApprovalsQueueBeforeTransactionAndKeepScopedDurableOutcomes(
        boolean failOne, boolean pauseDuringCompletion
    ) throws Exception {
        int maximum = pool.getMaximumPoolSize();
        assertThat(maximum).isEqualTo(10);
        List<Long> ids = new ArrayList<>();
        for (int index = 0; index < maximum; index++) {
            long id = submit();
            register(id);
            ids.add(id);
        }
        if (failOne) {
            doThrow(new UncategorizedJmsException("Synthetic transport uncertainty"))
                .when(delegate).publish(ids.getFirst());
        }
        CountDownLatch outerConnectionsHeld = new CountDownLatch(maximum - 1);
        CountDownLatch beginJournal = new CountDownLatch(1);
        AtomicInteger entered = new AtomicInteger();
        doAnswer(invocation -> {
            assertThat(TransactionSynchronizationManager.isActualTransactionActive()).isTrue();
            if (entered.incrementAndGet() < maximum) {
                if (pauseDuringCompletion) {
                    TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                        @Override
                        public void afterCompletion(int status) {
                            outerConnectionsHeld.countDown();
                            awaitRelease(beginJournal);
                        }
                    });
                } else {
                    outerConnectionsHeld.countDown();
                    awaitRelease(beginJournal);
                }
            }
            return invocation.callRealMethod();
        }).when(mapper).toResponse(any());
        var executor = Executors.newFixedThreadPool(maximum);
        List<Future<RuntimeException>> approvals = new ArrayList<>();
        AtomicReference<Thread> queued = new AtomicReference<>();
        try {
            for (int index = 0; index < maximum - 1; index++) {
                long id = ids.get(index);
                approvals.add(executor.submit(() -> approve(id)));
            }
            assertThat(outerConnectionsHeld.await(10, TimeUnit.SECONDS)).isTrue();
            approvals.add(executor.submit(() -> {
                queued.set(Thread.currentThread());
                return approve(ids.getLast());
            }));
            await().atMost(Duration.ofSeconds(5)).until(() -> waitingForAdmission(queued.get()));
            assertThat(entered).hasValue(maximum - 1);
            assertThat(pool.getHikariPoolMXBean().getActiveConnections()).isEqualTo(maximum - 1);
            assertThat(pool.getHikariPoolMXBean().getThreadsAwaitingConnection()).isZero();
            beginJournal.countDown();
            for (int index = 0; index < maximum; index++) {
                RuntimeException failure = approvals.get(index).get(15, TimeUnit.SECONDS);
                if (failOne && index == 0) {
                    assertThat(failure).isInstanceOf(UncategorizedJmsException.class);
                } else {
                    assertThat(failure).isNull();
                }
                long id = ids.get(index);
                var observation = evidence.findObservation(id).orElseThrow();
                assertThat(evidence.counts(observation.observationId())).isEqualTo(
                    new PublicationEvidenceCounts(1, failOne && index == 0 ? 0 : 1,
                        failOne && index == 0 ? 1 : 0, 0));
                assertThat(drafts.findById(id).orElseThrow().getCasefileStatus()).isEqualTo(
                    failOne && index == 0 ? DraftCasefileStatus.SUBMITTED : DraftCasefileStatus.PUBLISHING_PENDING);
            }
            assertThat(entered).hasValue(maximum);
            assertThat(pool.getHikariPoolMXBean().getActiveConnections()).isZero();
        } finally {
            beginJournal.countDown();
            executor.shutdownNow();
            assertThat(executor.awaitTermination(10, TimeUnit.SECONDS)).isTrue();
        }
    }

    @Test
    void admissionPrecedesTransactionAdviceForEveryGuardedService() {
        for (Object guarded : List.of(service, cleanup, reads)) {
            var advisors = ((Advised) guarded).getAdvisors();
            int admission = -1;
            int transaction = -1;
            for (int index = 0; index < advisors.length; index++) {
                var advice = advisors[index].getAdvice();
                if (advice instanceof AbstractAspectJAdvice aspect
                    && aspect.getAspectName().equals("draftCasefileAdmission")) {
                    admission = index;
                }
                if (advice instanceof TransactionInterceptor) {
                    transaction = index;
                }
            }
            assertThat(admission).isGreaterThanOrEqualTo(0).isLessThan(transaction);
        }
    }

    @Test
    void ambientTransactionsFailBeforeDraftWorkAndDoNotLeakAdmission() throws Exception {
        long id = submit();
        register(id);
        new TransactionTemplate(transactionManager).executeWithoutResult(transaction -> {
            // This caller genuinely retains an outer connection before entering the service.
            drafts.findById(id).orElseThrow();
            for (Runnable operation : List.<Runnable>of(() -> service.getDraftCasefile(id),
                () -> cleanup.cleanup(id, RUN), () -> reads.read(id, RUN), () -> reads.register(id, RUN))) {
                assertThatThrownBy(operation::run).isInstanceOf(IllegalStateException.class)
                    .hasMessage("Testing-support draft operations must enter outside a transaction");
            }
        });
        assertThat(approve(id)).isNull();
        assertThat(evidence.counts(evidence.findObservation(id).orElseThrow().observationId()))
            .isEqualTo(new PublicationEvidenceCounts(1, 1, 0, 0));
    }

    private void awaitRelease(CountDownLatch release) {
        try {
            assertThat(release.await(15, TimeUnit.SECONDS)).isTrue();
        } catch (InterruptedException interrupted) {
            Thread.currentThread().interrupt();
            throw new AssertionError("Interrupted while coordinating transaction", interrupted);
        }
    }

    private boolean waitingForAdmission(Thread thread) {
        return thread != null && thread.getState() == Thread.State.WAITING
            && Arrays.stream(thread.getStackTrace()).anyMatch(frame ->
                frame.getClassName().equals("uk.gov.hmcts.opal.service.DraftCasefileAdmission"));
    }

    private RuntimeException approve(long id) {
        SecurityContextHolder.getContext().setAuthentication(DraftCasefileHttpFixture.token((short) 1,
            124L, "BUU-CHECKER", Set.of(new Permission(22L, "Check and validate draft Casefiles"))));
        try {
            service.updateDraftCasefile(id, new DraftCasefileUpdateRequest().businessUnitId((short) 1)
                .casefileStatus(DraftCasefileUpdateRequest.CasefileStatusEnum.PUBLISHING_PENDING), "\"0\"");
            return null;
        } catch (RuntimeException failure) {
            return failure;
        } finally {
            SecurityContextHolder.clearContext();
        }
    }

    private long submit() throws Exception {
        ObjectNode request = (ObjectNode) json.readTree(DraftCasefileHttpFixture.requestBody());
        ((ObjectNode) request.at("/casefile/respondent_account")).put("remo_reference", RUN);
        return json.readTree(mvc.perform(post("/draft-casefiles")
            .with(authentication(DraftCasefileHttpFixture.token((short) 1)))
            .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsBytes(request)))
            .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString())
            .path("draft_casefile_id").longValue();
    }

    private void register(long id) throws Exception {
        mvc.perform(post(PATH, id).with(authentication(DraftCasefileHttpFixture.token((short) 1)))
            .header("Test-Run-Reference", RUN)).andExpect(status().isCreated());
    }
}
