package uk.gov.hmcts.opal.service.messaging;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.Timeout;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.jdbc.Sql;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.dto.PublicationEvidenceCounts;
import uk.gov.hmcts.opal.exception.ResourceConflictException;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.repository.PublicationEvidenceRepository;

import java.time.Clock;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.context.jdbc.Sql.ExecutionPhase.AFTER_TEST_METHOD;

@TestPropertySource(properties = {
    "spring.flyway.locations=classpath:db/migration/ddl", "opal.redis.enabled=false",
    "management.health.redis.enabled=false", "opal.testing-support-endpoints.enabled=true",
    "spring.datasource.hikari.connection-init-sql=SET statement_timeout = '5s'"
})
@Import(PublicationEvidenceWriterIntegrationTest.SecondInstance.class)
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@Sql("/draft-casefile/publication-evidence-fixtures.sql")
@Sql(scripts = "/draft-casefile/publication-evidence-cleanup.sql", executionPhase = AFTER_TEST_METHOD)
@Timeout(30)
class PublicationEvidenceWriterIntegrationTest extends BaseIntegrationTest {

    private static final long DRAFT = 910626001L;
    private static final long OTHER_DRAFT = 910626002L;
    private static final String MARKER = "E2E-0123456789abcdef";

    @Autowired
    @Qualifier("publicationEvidenceWriter")
    private PublicationEvidenceWriter writer;
    @Autowired
    @Qualifier("secondPublicationEvidenceWriter")
    private PublicationEvidenceWriter secondWriter;
    @Autowired
    private PublicationEvidenceRepository repository;
    @Autowired
    private DraftCasefileRepository drafts;
    @Autowired
    private PlatformTransactionManager transactionManager;

    @ParameterizedTest
    @ValueSource(booleans = {false, true})
    void journalCommitsWhileCallerHoldsDraftLockAndSurvivesItsRollback(boolean acknowledged) {
        final var observation = repository.register(DRAFT, MARKER);
        var before = drafts.findById(DRAFT).orElseThrow();
        new TransactionTemplate(transactionManager).executeWithoutResult(transaction -> {
            var locked = drafts.findForCleanupById(DRAFT).orElseThrow();
            drafts.saveAndFlush(locked.toBuilder().statusMessage("Synthetic uncommitted change").build());
            UUID attempt = writer.begin(DRAFT).orElseThrow();
            if (acknowledged) {
                secondWriter.acknowledge(attempt);
            } else {
                secondWriter.markUncertain(attempt);
            }
            transaction.setRollbackOnly();
        });
        var after = drafts.findById(DRAFT).orElseThrow();
        assertThat(after.getStatusMessage()).isEqualTo(before.getStatusMessage());
        assertThat(after.getVersionNumber()).isEqualTo(before.getVersionNumber());
        assertThat(repository.counts(observation.observationId())).isEqualTo(
            new PublicationEvidenceCounts(1, acknowledged ? 1 : 0, acknowledged ? 0 : 1, 0));
    }

    @Test
    void unregisteredDraftIsSkippedAcrossBothInstances() {
        assertThat(writer.begin(DRAFT)).isEmpty();
        assertThat(secondWriter.begin(DRAFT)).isEmpty();
        assertThat(repository.findObservation(DRAFT)).isEmpty();
    }

    @Test
    void independentInstancesObserveAndCompleteTheSameDurableEvidence() {
        final var observation = repository.register(DRAFT, MARKER);
        final var other = repository.register(OTHER_DRAFT, MARKER);
        UUID firstAttempt = writer.begin(DRAFT).orElseThrow();
        UUID secondAttempt = secondWriter.begin(DRAFT).orElseThrow();
        secondWriter.acknowledge(firstAttempt);
        writer.markUncertain(secondAttempt);

        assertThat(writer).isNotSameAs(secondWriter);
        assertThat(firstAttempt).isNotEqualTo(secondAttempt);
        assertThat(repository.counts(observation.observationId())).isEqualTo(new PublicationEvidenceCounts(2, 1, 1, 0));
        assertThat(repository.counts(other.observationId())).isEqualTo(new PublicationEvidenceCounts(0, 0, 0, 0));
    }

    @Test
    void concurrentAttemptsHaveUniqueIdentitiesAndRemainScoped() throws Exception {
        final var observation = repository.register(DRAFT, MARKER);
        final var other = repository.register(OTHER_DRAFT, MARKER);
        CountDownLatch ready = new CountDownLatch(2);
        CountDownLatch start = new CountDownLatch(1);
        var executor = Executors.newFixedThreadPool(2);
        try {
            var first = executor.submit(attempts(writer, ready, start));
            var second = executor.submit(attempts(secondWriter, ready, start));
            assertThat(ready.await(5, TimeUnit.SECONDS)).isTrue();
            start.countDown();
            List<UUID> identities = new ArrayList<>(first.get(10, TimeUnit.SECONDS));
            identities.addAll(second.get(10, TimeUnit.SECONDS));
            assertThat(identities).hasSize(10).doesNotHaveDuplicates();
            assertThat(repository.counts(observation.observationId()))
                .isEqualTo(new PublicationEvidenceCounts(10, 0, 0, 10));
            assertThat(repository.counts(other.observationId())).isEqualTo(new PublicationEvidenceCounts(0, 0, 0, 0));
        } finally {
            start.countDown();
            executor.shutdownNow();
            assertThat(executor.awaitTermination(5, TimeUnit.SECONDS)).isTrue();
        }
    }

    @Test
    void competingCompletionsPreserveOneTerminalOutcome() throws Exception {
        final var observation = repository.register(DRAFT, MARKER);
        UUID attempt = writer.begin(DRAFT).orElseThrow();
        CountDownLatch start = new CountDownLatch(1);
        var executor = Executors.newFixedThreadPool(2);
        try {
            Callable<Boolean> acknowledge = () -> completeAfter(start, () -> writer.acknowledge(attempt));
            Callable<Boolean> uncertain = () -> completeAfter(start, () -> secondWriter.markUncertain(attempt));
            var first = executor.submit(acknowledge);
            var second = executor.submit(uncertain);
            start.countDown();
            boolean acknowledged = first.get(10, TimeUnit.SECONDS);
            boolean markedUncertain = second.get(10, TimeUnit.SECONDS);
            assertThat(acknowledged).isNotEqualTo(markedUncertain);
            assertThat(repository.counts(observation.observationId())).isEqualTo(
                new PublicationEvidenceCounts(1, acknowledged ? 1 : 0, markedUncertain ? 1 : 0, 0));
        } finally {
            start.countDown();
            executor.shutdownNow();
            assertThat(executor.awaitTermination(5, TimeUnit.SECONDS)).isTrue();
        }
    }

    private Callable<List<UUID>> attempts(PublicationEvidenceWriter instance,
                                           CountDownLatch ready, CountDownLatch start) {
        return () -> {
            ready.countDown();
            assertThat(start.await(5, TimeUnit.SECONDS)).isTrue();
            List<UUID> identities = new ArrayList<>();
            for (int index = 0; index < 5; index++) {
                identities.add(instance.begin(DRAFT).orElseThrow());
            }
            return identities;
        };
    }

    private boolean completeAfter(CountDownLatch start, Runnable completion) throws InterruptedException {
        assertThat(start.await(5, TimeUnit.SECONDS)).isTrue();
        try {
            completion.run();
            return true;
        } catch (ResourceConflictException exception) {
            return false;
        }
    }

    @TestConfiguration(proxyBeanMethods = false)
    static class SecondInstance {

        @Bean(defaultCandidate = false)
        PublicationEvidenceWriter secondPublicationEvidenceWriter(JdbcTemplate jdbc, Clock clock) {
            return new PublicationEvidenceWriter(new PublicationEvidenceRepository(jdbc, clock));
        }
    }
}
