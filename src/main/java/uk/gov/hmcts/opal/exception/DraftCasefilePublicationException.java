package uk.gov.hmcts.opal.exception;

import java.time.LocalDateTime;

/** Internal rollback context. The cause must never cross the JMS logging boundary. */
public class DraftCasefilePublicationException extends RuntimeException {
    private final Attempt attempt;

    public DraftCasefilePublicationException(Attempt attempt, RuntimeException cause) {
        super("Draft Casefile publication failed", cause);
        this.attempt = attempt;
    }

    public Attempt attempt() {
        return attempt;
    }

    public RuntimeException processingFailure() {
        return (RuntimeException) getCause();
    }

    public record Attempt(Long draftCasefileId, Long versionNumber, String validatedBy, LocalDateTime validatedDate) { }
}
