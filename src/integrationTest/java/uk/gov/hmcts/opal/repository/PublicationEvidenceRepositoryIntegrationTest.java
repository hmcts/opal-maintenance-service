package uk.gov.hmcts.opal.repository;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.jdbc.Sql;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.dto.PublicationEvidenceCounts;
import uk.gov.hmcts.opal.exception.ResourceConflictException;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.context.jdbc.Sql.ExecutionPhase.AFTER_TEST_METHOD;

@TestPropertySource(properties = {
    "spring.flyway.locations=classpath:db/migration/ddl", "opal.redis.enabled=false",
    "management.health.redis.enabled=false", "opal.testing-support-endpoints.enabled=true"
})
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@Sql("/draft-casefile/publication-evidence-fixtures.sql")
@Sql(scripts = "/draft-casefile/publication-evidence-cleanup.sql", executionPhase = AFTER_TEST_METHOD)
class PublicationEvidenceRepositoryIntegrationTest extends BaseIntegrationTest {

    private static final long DRAFT = 910626001L;
    private static final long OTHER_DRAFT = 910626002L;
    private static final String MARKER = "E2E-0123456789abcdef";
    private static final String OTHER_MARKER = "E2E-fedcba9876543210";

    @Autowired
    private PublicationEvidenceRepository repository;
    @Autowired
    private PlatformTransactionManager transactionManager;
    @Autowired
    private JdbcTemplate jdbc;

    @Test
    void repeatedRegistrationKeepsIdentityTimestampAndAttempts() {
        final var observation = repository.register(DRAFT, MARKER);
        UUID attempt = repository.insertAttempt(observation.observationId());
        repository.acknowledge(attempt);

        assertThat(repository.register(DRAFT, MARKER)).isEqualTo(observation);
        assertThat(observation.draftCasefileId()).isEqualTo(DRAFT);
        assertThat(observation.testRunReference()).isEqualTo(MARKER);
        assertThat(observation.registeredAt()).isNotNull();
        assertThat(repository.counts(observation.observationId())).isEqualTo(new PublicationEvidenceCounts(1, 1, 0, 0));
    }

    @Test
    void differentMarkerCannotReplaceObservation() {
        final var observation = repository.register(DRAFT, MARKER);
        repository.insertAttempt(observation.observationId());

        assertThatThrownBy(() -> repository.register(DRAFT, OTHER_MARKER))
            .isInstanceOf(ResourceConflictException.class);
        assertThat(repository.findObservation(DRAFT)).contains(observation);
        assertThat(repository.counts(observation.observationId())).isEqualTo(new PublicationEvidenceCounts(1, 0, 0, 1));
    }

    @Test
    void countsAreScopedAndRepresentEveryOutcome() {
        var first = repository.register(DRAFT, MARKER);
        final var other = repository.register(OTHER_DRAFT, OTHER_MARKER);
        assertThat(repository.counts(first.observationId())).isEqualTo(new PublicationEvidenceCounts(0, 0, 0, 0));
        assertThat(repository.counts(first.observationId()).evidenceComplete()).isTrue();
        repository.acknowledge(repository.insertAttempt(first.observationId()));
        repository.markUncertain(repository.insertAttempt(first.observationId()));
        repository.insertAttempt(first.observationId());
        repository.acknowledge(repository.insertAttempt(other.observationId()));

        assertThat(repository.counts(first.observationId())).isEqualTo(new PublicationEvidenceCounts(3, 1, 1, 1));
        assertThat(repository.counts(first.observationId()).evidenceComplete()).isFalse();
        assertThat(repository.counts(other.observationId())).isEqualTo(new PublicationEvidenceCounts(1, 1, 0, 0));
        assertThat(repository.counts(other.observationId()).evidenceComplete()).isTrue();
    }

    @Test
    void deletionRequiresDraftAndMarkerAndCascadesOnlyItsAttempts() {
        var first = repository.register(DRAFT, MARKER);
        final var other = repository.register(OTHER_DRAFT, OTHER_MARKER);
        repository.insertAttempt(first.observationId());
        repository.insertAttempt(other.observationId());

        repository.deleteObservation(DRAFT, OTHER_MARKER);
        repository.deleteObservation(OTHER_DRAFT, MARKER);
        assertThat(repository.findObservation(DRAFT)).contains(first);
        assertThat(repository.findObservation(OTHER_DRAFT)).contains(other);
        repository.deleteObservation(DRAFT, MARKER);
        repository.deleteObservation(DRAFT, MARKER);
        assertThat(repository.findObservation(DRAFT)).isEmpty();
        assertThat(repository.counts(first.observationId())).isEqualTo(new PublicationEvidenceCounts(0, 0, 0, 0));
        assertThat(repository.findObservation(OTHER_DRAFT)).contains(other);
        assertThat(repository.counts(other.observationId())).isEqualTo(new PublicationEvidenceCounts(1, 0, 0, 1));
    }

    @ParameterizedTest
    @ValueSource(booleans = {false, true})
    void completionIsIdempotentAndCannotChangeOutcome(boolean acknowledged) {
        final var observation = repository.register(DRAFT, MARKER);
        UUID attempt = repository.insertAttempt(observation.observationId());
        if (acknowledged) {
            repository.acknowledge(attempt);
            var completed = attemptRow(attempt);
            repository.acknowledge(attempt);
            assertThat(attemptRow(attempt)).isEqualTo(completed);
            assertThatThrownBy(() -> repository.markUncertain(attempt)).isInstanceOf(ResourceConflictException.class);
        } else {
            repository.markUncertain(attempt);
            var completed = attemptRow(attempt);
            repository.markUncertain(attempt);
            assertThat(attemptRow(attempt)).isEqualTo(completed);
            assertThatThrownBy(() -> repository.acknowledge(attempt)).isInstanceOf(ResourceConflictException.class);
        }
        assertThat(repository.counts(observation.observationId())).isEqualTo(
            new PublicationEvidenceCounts(1, acknowledged ? 1 : 0, acknowledged ? 0 : 1, 0));
    }

    @Test
    void missingAttemptCannotBeCompleted() {
        UUID missing = UUID.randomUUID();
        assertThatThrownBy(() -> repository.acknowledge(missing)).isInstanceOf(ResourceConflictException.class);
        assertThatThrownBy(() -> repository.markUncertain(missing)).isInstanceOf(ResourceConflictException.class);
    }

    @Test
    void registrationAndDeletionParticipateInCallerTransaction() {
        new TransactionTemplate(transactionManager).executeWithoutResult(transaction -> {
            repository.register(DRAFT, MARKER);
            transaction.setRollbackOnly();
        });
        assertThat(repository.findObservation(DRAFT)).isEmpty();
        final var observation = repository.register(DRAFT, MARKER);
        UUID attempt = repository.insertAttempt(observation.observationId());
        new TransactionTemplate(transactionManager).executeWithoutResult(transaction -> {
            repository.deleteObservation(DRAFT, MARKER);
            transaction.setRollbackOnly();
        });
        assertThat(repository.findObservation(DRAFT)).contains(observation);
        repository.acknowledge(attempt);
        assertThat(repository.counts(observation.observationId())).isEqualTo(new PublicationEvidenceCounts(1, 1, 0, 0));
    }

    @Test
    void completionPreservesTemporalIntegrityWhenInstanceClocksDiffer() {
        final var observation = repository.register(DRAFT, MARKER);
        var ahead = new PublicationEvidenceRepository(jdbc,
            Clock.fixed(Instant.parse("2099-10-22T10:00:00Z"), ZoneOffset.UTC));
        UUID attempt = ahead.insertAttempt(observation.observationId());
        repository.acknowledge(attempt);
        var row = attemptRow(attempt);
        assertThat(row.get("completed_at")).isEqualTo(row.get("started_at"));
        assertThat(repository.counts(observation.observationId())).isEqualTo(new PublicationEvidenceCounts(1, 1, 0, 0));
    }

    // This test exercises the JDBC persistence boundary, including immutable completion timestamps.
    private Map<String, Object> attemptRow(UUID attemptId) {
        return jdbc.queryForMap("""
            SELECT observation_id, outcome, started_at, completed_at
            FROM public.draft_casefile_test_send_attempts WHERE attempt_id = ?
            """, attemptId);
    }

}
