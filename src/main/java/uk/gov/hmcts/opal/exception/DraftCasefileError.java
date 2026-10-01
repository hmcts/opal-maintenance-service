package uk.gov.hmcts.opal.exception;

import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import uk.gov.hmcts.opal.common.exception.OpalApiError;

@Getter
@RequiredArgsConstructor
public enum DraftCasefileError implements OpalApiError {
    INVALID_REQUEST("001", HttpStatus.BAD_REQUEST, "Invalid Draft Casefile request");

    private static final String ERROR_TYPE_PREFIX = "DRAFT_CASEFILE";
    private final String errorTypeNumeric;
    private final HttpStatus httpStatus;
    private final String title;

    @Override
    public String getErrorTypePrefix() {
        return ERROR_TYPE_PREFIX;
    }
}
