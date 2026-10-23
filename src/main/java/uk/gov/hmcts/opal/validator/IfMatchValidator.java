package uk.gov.hmcts.opal.validator;

import org.springframework.stereotype.Component;
import uk.gov.hmcts.opal.common.exception.OpalApiException;
import uk.gov.hmcts.opal.exception.RequestValidationError;

/** Parses an If-Match version without exposing supplied header values. */
@Component
public class IfMatchValidator {

    public long parseIfMatch(String ifMatch) {
        if (ifMatch == null || !ifMatch.matches("\"[0-9]+\"")) {
            throw invalid();
        }
        try {
            return Long.parseLong(ifMatch.substring(1, ifMatch.length() - 1));
        } catch (NumberFormatException exception) {
            throw invalid();
        }
    }

    private static OpalApiException invalid() {
        return new OpalApiException(RequestValidationError.INVALID_REQUEST,
            "If-Match must contain one quoted non-negative version");
    }
}
