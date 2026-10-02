package uk.gov.hmcts.opal.exception;

import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import uk.gov.hmcts.opal.common.exception.OpalApiError;

@Getter
@RequiredArgsConstructor
public enum RequestValidationError implements OpalApiError {
    INVALID_REQUEST("001", HttpStatus.BAD_REQUEST, "Invalid request"),
    REQUEST_TOO_LARGE("002", HttpStatus.valueOf(413), "Request body too large");

    private final String errorTypePrefix = "REQUEST_VALIDATION";
    private final String errorTypeNumeric;
    private final HttpStatus httpStatus;
    private final String title;
}
