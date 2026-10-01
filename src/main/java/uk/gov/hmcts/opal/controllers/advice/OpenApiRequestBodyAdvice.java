package uk.gov.hmcts.opal.controllers.advice;

import org.springframework.core.MethodParameter;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpInputMessage;
import org.springframework.http.converter.HttpMessageConverter;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.servlet.mvc.method.annotation.RequestBodyAdviceAdapter;
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

    public OpenApiRequestBodyAdvice(OpenApiSchemaValidator validator) {
        this.validator = validator;
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
        byte[] body = inputMessage.getBody().readAllBytes();
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
