package uk.gov.hmcts.opal.controllers.advice;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.MethodParameter;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpInputMessage;
import org.springframework.http.converter.HttpMessageConverter;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.servlet.mvc.method.annotation.RequestBodyAdviceAdapter;
import uk.gov.hmcts.opal.common.exception.OpalApiException;
import uk.gov.hmcts.opal.exception.RequestValidationError;
import uk.gov.hmcts.opal.validator.OpenApiRequest;
import uk.gov.hmcts.opal.validator.OpenApiSchemaValidator;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.lang.reflect.Type;
import java.util.Objects;

@ControllerAdvice
public class OpenApiRequestBodyAdvice extends RequestBodyAdviceAdapter {

    private final OpenApiSchemaValidator validator;
    private final int maxRequestBodyBytes;

    public OpenApiRequestBodyAdvice(OpenApiSchemaValidator validator,
                                   @Value("${opal.openapi.max-request-body-bytes}") int maxRequestBodyBytes) {
        if (maxRequestBodyBytes <= 0 || maxRequestBodyBytes == Integer.MAX_VALUE) {
            throw new IllegalArgumentException("OpenAPI request body limit must be a positive byte count");
        }
        this.validator = validator;
        this.maxRequestBodyBytes = maxRequestBodyBytes;
    }

    @Override
    public boolean supports(MethodParameter parameter, Type targetType,
                            Class<? extends HttpMessageConverter<?>> converterType) {
        return parameter.hasMethodAnnotation(OpenApiRequest.class);
    }

    @Override
    public HttpInputMessage beforeBodyRead(HttpInputMessage inputMessage, MethodParameter parameter,
                                          Type targetType, Class<? extends HttpMessageConverter<?>> converterType)
        throws IOException {
        OpenApiRequest annotation = Objects.requireNonNull(parameter.getMethodAnnotation(OpenApiRequest.class));
        if (inputMessage.getHeaders().getContentLength() > maxRequestBodyBytes) {
            throw new OpalApiException(RequestValidationError.REQUEST_TOO_LARGE);
        }
        byte[] body = inputMessage.getBody().readNBytes(maxRequestBodyBytes + 1);
        if (body.length > maxRequestBodyBytes) {
            throw new OpalApiException(RequestValidationError.REQUEST_TOO_LARGE);
        }
        validator.validate(annotation.value(), body);
        return new BufferedInputMessage(inputMessage.getHeaders(), body);
    }

    private record BufferedInputMessage(HttpHeaders headers, byte[] body) implements HttpInputMessage {
        @Override
        public InputStream getBody() {
            return new ByteArrayInputStream(body);
        }

        @Override
        public HttpHeaders getHeaders() {
            return headers;
        }
    }
}
