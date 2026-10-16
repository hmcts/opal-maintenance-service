package uk.gov.hmcts.opal.testing;

public class DraftCasefileTestingFailureException extends RuntimeException {

    public DraftCasefileTestingFailureException() {
        super("Controlled Draft Casefile failure after save");
    }
}
