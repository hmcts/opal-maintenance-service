package uk.gov.hmcts.opal.controllers.advice;

import jakarta.validation.ConstraintViolationException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import uk.gov.hmcts.opal.common.controllers.advice.OpalProblemDetailFactory;
import uk.gov.hmcts.opal.controllers.MajorCreditorApiController;

@Order(Ordered.HIGHEST_PRECEDENCE)
@RestControllerAdvice(assignableTypes = MajorCreditorApiController.class)
public class MajorCreditorExceptionHandler {

    private static final Logger LOG = LoggerFactory.getLogger(MajorCreditorExceptionHandler.class);

    @ExceptionHandler(MissingServletRequestParameterException.class)
    public ResponseEntity<ProblemDetail> handleMissingServletRequestParameterException(
        MissingServletRequestParameterException exception
    ) {
        return badRequest(
            "A required request parameter is missing",
            "missing-required-parameter",
            exception
        );
    }

    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<ProblemDetail> handleConstraintViolationException(
        ConstraintViolationException exception
    ) {
        return badRequest(
            "A request parameter value violates its constraints",
            "constraint-violation",
            exception
        );
    }

    private ResponseEntity<ProblemDetail> badRequest(String detail, String type, Exception exception) {
        ProblemDetail problemDetail = OpalProblemDetailFactory.createProblemDetail(
            HttpStatus.BAD_REQUEST,
            "Bad Request",
            detail,
            type,
            false,
            exception,
            LOG
        );
        return OpalProblemDetailFactory.responseWithProblemDetail(HttpStatus.BAD_REQUEST, problemDetail);
    }
}
