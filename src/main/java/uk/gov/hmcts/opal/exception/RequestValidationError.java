package uk.gov.hmcts.opal.exception;

import lombok.Getter;
import org.springframework.http.HttpStatus;
import uk.gov.hmcts.opal.common.exception.OpalApiError;

@Getter
public enum RequestValidationError implements OpalApiError {
    INVALID_REQUEST;

    private final String errorTypePrefix = "REQUEST_VALIDATION";
    private final String errorTypeNumeric = "001";
    private final HttpStatus httpStatus = HttpStatus.BAD_REQUEST;
    private final String title = "Invalid request";
}
