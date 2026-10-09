package uk.gov.hmcts.opal.exception;

import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import uk.gov.hmcts.opal.common.exception.OpalApiError;

@Getter
@RequiredArgsConstructor
public enum DraftCasefileConflictError implements OpalApiError {
    BUSINESS_UNIT_MISMATCH("001", HttpStatus.CONFLICT, "Draft Casefile ownership conflict"),
    WRONG_STATE("002", HttpStatus.CONFLICT, "Draft Casefile lifecycle conflict"),
    STALE_VERSION("003", HttpStatus.CONFLICT, "Draft Casefile version conflict");

    private final String errorTypePrefix = "DRAFT_CASEFILE_CONFLICT";
    private final String errorTypeNumeric;
    private final HttpStatus httpStatus;
    private final String title;
}
