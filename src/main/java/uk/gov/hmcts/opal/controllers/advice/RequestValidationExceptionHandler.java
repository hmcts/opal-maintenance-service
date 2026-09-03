package uk.gov.hmcts.opal.controllers.advice;

import jakarta.validation.ConstraintViolation;
import jakarta.validation.ConstraintViolationException;
import jakarta.validation.ElementKind;
import jakarta.validation.Path;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.aop.support.AopUtils;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.AnnotatedElementUtils;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import uk.gov.hmcts.opal.common.controllers.advice.OpalProblemDetailFactory;

@Order(Ordered.HIGHEST_PRECEDENCE)
@RestControllerAdvice(basePackages = "uk.gov.hmcts.opal.controllers")
public class RequestValidationExceptionHandler {

    private static final Logger LOG = LoggerFactory.getLogger(RequestValidationExceptionHandler.class);

    @ExceptionHandler(MissingServletRequestParameterException.class)
    public ResponseEntity<ProblemDetail> handleMissingServletRequestParameterException(
        MissingServletRequestParameterException exception
    ) {
        return problemResponse(
            HttpStatus.BAD_REQUEST,
            "Bad Request",
            "A required request parameter is missing",
            "missing-required-parameter",
            exception
        );
    }

    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<ProblemDetail> handleConstraintViolationException(
        ConstraintViolationException exception
    ) {
        if (containsOnlyControllerParameterViolations(exception)) {
            return problemResponse(
                HttpStatus.BAD_REQUEST,
                "Bad Request",
                "A request parameter value violates its constraints",
                "constraint-violation",
                exception
            );
        }

        return problemResponse(
            HttpStatus.INTERNAL_SERVER_ERROR,
            "Internal Server Error",
            "An unexpected error occurred while processing your request",
            "internal-server-error",
            exception
        );
    }

    private boolean containsOnlyControllerParameterViolations(ConstraintViolationException exception) {
        return !exception.getConstraintViolations().isEmpty()
            && exception.getConstraintViolations().stream().allMatch(this::isControllerParameterViolation);
    }

    private boolean isControllerParameterViolation(ConstraintViolation<?> violation) {
        Object rootBean = violation.getRootBean();
        Class<?> rootBeanClass = rootBean == null
            ? violation.getRootBeanClass()
            : AopUtils.getTargetClass(rootBean);

        if (!AnnotatedElementUtils.hasAnnotation(rootBeanClass, Controller.class)) {
            return false;
        }

        for (Path.Node node : violation.getPropertyPath()) {
            if (node.getKind() == ElementKind.PARAMETER) {
                return true;
            }
        }
        return false;
    }

    private ResponseEntity<ProblemDetail> problemResponse(
        HttpStatus status,
        String title,
        String detail,
        String type,
        Exception exception
    ) {
        ProblemDetail problemDetail = OpalProblemDetailFactory.createProblemDetail(
            status,
            title,
            detail,
            type,
            false,
            exception,
            LOG
        );
        return OpalProblemDetailFactory.responseWithProblemDetail(status, problemDetail);
    }
}
