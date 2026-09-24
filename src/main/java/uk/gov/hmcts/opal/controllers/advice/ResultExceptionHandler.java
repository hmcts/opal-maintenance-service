package uk.gov.hmcts.opal.controllers.advice;

import jakarta.persistence.EntityNotFoundException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import uk.gov.hmcts.opal.common.controllers.advice.OpalProblemDetailFactory;
import uk.gov.hmcts.opal.controllers.ResultApiController;

@Order(Ordered.HIGHEST_PRECEDENCE)
@RestControllerAdvice(assignableTypes = ResultApiController.class)
public class ResultExceptionHandler {

    private static final Logger LOG = LoggerFactory.getLogger(ResultExceptionHandler.class);

    @ExceptionHandler(EntityNotFoundException.class)
    public ResponseEntity<ProblemDetail> handleNotFound(EntityNotFoundException exception) {
        ProblemDetail problem = OpalProblemDetailFactory.createProblemDetail(
            HttpStatus.NOT_FOUND, "Not Found", "Result not found",
            "result-not-found", false, null, LOG);
        return OpalProblemDetailFactory.responseWithProblemDetail(HttpStatus.NOT_FOUND, problem);
    }
}
