package uk.gov.hmcts.opal.testing;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import uk.gov.hmcts.opal.common.exception.OpalApiException;
import uk.gov.hmcts.opal.exception.DraftCasefileError;

@Component
public class DraftCasefileTestingFailure {

    private final boolean enabled;

    public DraftCasefileTestingFailure(@Value("${opal.testing-support-endpoints.enabled:false}") boolean enabled) {
        this.enabled = enabled;
    }

    public DraftCasefileFailureMode resolve(String value) {
        if (value == null) {
            return DraftCasefileFailureMode.NONE;
        }
        if (!enabled) {
            throw new OpalApiException(DraftCasefileError.INVALID_REQUEST,
                "Testing failure injection is disabled");
        }
        if (!"after-save".equals(value)) {
            throw new OpalApiException(DraftCasefileError.INVALID_REQUEST,
                "Unsupported testing failure mode");
        }
        return DraftCasefileFailureMode.AFTER_SAVE;
    }

    public void afterSave(DraftCasefileFailureMode mode) {
        if (mode == DraftCasefileFailureMode.AFTER_SAVE) {
            throw new DraftCasefileTestingFailureException();
        }
    }
}
