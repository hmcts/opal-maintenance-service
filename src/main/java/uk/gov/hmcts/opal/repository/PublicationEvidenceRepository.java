package uk.gov.hmcts.opal.repository;

import lombok.RequiredArgsConstructor;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import uk.gov.hmcts.opal.dto.PublicationEvidenceCounts;
import uk.gov.hmcts.opal.exception.ResourceConflictException;
import uk.gov.hmcts.opal.dto.PublicationObservation;

import java.sql.Timestamp;
import java.time.Clock;
import java.util.Optional;
import java.util.UUID;

@Repository
@RequiredArgsConstructor
@ConditionalOnProperty(prefix = "opal.testing-support-endpoints", name = "enabled", havingValue = "true")
public class PublicationEvidenceRepository {

    private final JdbcTemplate jdbc;
    private final Clock clock;

    public PublicationObservation register(Long draftId, String marker) {
        jdbc.update("""
            INSERT INTO public.draft_casefile_test_observations
                (observation_id, draft_casefile_id, test_run_reference, registered_at)
            VALUES (?, ?, ?, ?)
            ON CONFLICT (draft_casefile_id) DO NOTHING
            """, UUID.randomUUID(), draftId, marker, Timestamp.from(clock.instant()));
        PublicationObservation observation = findObservation(draftId).orElseThrow();
        if (!observation.testRunReference().equals(marker)) {
            throw new ResourceConflictException("Draft Casefile observation belongs to another test run");
        }
        return observation;
    }

    public Optional<PublicationObservation> findObservation(Long draftId) {
        return jdbc.query("""
            SELECT observation_id, draft_casefile_id, test_run_reference, registered_at
            FROM public.draft_casefile_test_observations WHERE draft_casefile_id = ?
            """, (row, index) -> new PublicationObservation(row.getObject("observation_id", UUID.class),
                row.getLong("draft_casefile_id"), row.getString("test_run_reference"),
                row.getTimestamp("registered_at").toInstant()), draftId).stream().findFirst();
    }

    public PublicationEvidenceCounts counts(UUID observationId) {
        return jdbc.queryForObject("""
            SELECT COUNT(*) AS send_attempt_count,
                   COUNT(*) FILTER (WHERE outcome = 'ACKNOWLEDGED') AS acknowledged_send_count,
                   COUNT(*) FILTER (WHERE outcome = 'UNCERTAIN') AS uncertain_send_count,
                   COUNT(*) FILTER (WHERE outcome = 'STARTED') AS unfinished_send_count
            FROM public.draft_casefile_test_send_attempts WHERE observation_id = ?
            """, (row, index) -> new PublicationEvidenceCounts(row.getLong("send_attempt_count"),
                row.getLong("acknowledged_send_count"), row.getLong("uncertain_send_count"),
                row.getLong("unfinished_send_count")), observationId);
    }

    public UUID insertAttempt(UUID observationId) {
        UUID attemptId = UUID.randomUUID();
        jdbc.update("""
            INSERT INTO public.draft_casefile_test_send_attempts
                (attempt_id, observation_id, outcome, started_at)
            VALUES (?, ?, 'STARTED', ?)
            """, attemptId, observationId, Timestamp.from(clock.instant()));
        return attemptId;
    }

    public void acknowledge(UUID attemptId) {
        complete(attemptId, "ACKNOWLEDGED");
    }

    public void markUncertain(UUID attemptId) {
        complete(attemptId, "UNCERTAIN");
    }

    public void deleteObservation(Long draftId, String marker) {
        jdbc.update("""
            DELETE FROM public.draft_casefile_test_observations
            WHERE draft_casefile_id = ? AND test_run_reference = ?
            """, draftId, marker);
    }

    private void complete(UUID attemptId, String outcome) {
        // Preserve timestamp integrity if clocks differ between application instances.
        int updated = jdbc.update("""
            UPDATE public.draft_casefile_test_send_attempts
            SET outcome = ?, completed_at = GREATEST(?, started_at)
            WHERE attempt_id = ? AND outcome = 'STARTED'
            """, outcome, Timestamp.from(clock.instant()), attemptId);
        if (updated == 0) {
            Optional<String> existing = jdbc.query("""
                SELECT outcome FROM public.draft_casefile_test_send_attempts WHERE attempt_id = ?
                """, (row, index) -> row.getString("outcome"), attemptId).stream().findFirst();
            if (existing.isEmpty() || !outcome.equals(existing.orElseThrow())) {
                throw new ResourceConflictException("Publication attempt cannot complete with the requested outcome");
            }
        }
    }
}
