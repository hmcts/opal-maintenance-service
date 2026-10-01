package uk.gov.hmcts.opal.controllers.advice;

import org.junit.jupiter.api.Test;
import org.springframework.core.MethodParameter;
import org.springframework.http.HttpInputMessage;
import org.springframework.http.MediaType;
import org.springframework.http.converter.StringHttpMessageConverter;
import org.springframework.mock.http.MockHttpInputMessage;
import uk.gov.hmcts.opal.common.exception.OpalApiException;
import uk.gov.hmcts.opal.exception.RequestValidationError;
import uk.gov.hmcts.opal.validator.OpenApiRequest;
import uk.gov.hmcts.opal.validator.OpenApiSchemaValidator;

import java.nio.charset.StandardCharsets;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;

class OpenApiRequestBodyAdviceTest {

    private final OpenApiSchemaValidator validator = mock(OpenApiSchemaValidator.class);
    private final OpenApiRequestBodyAdvice advice = new OpenApiRequestBodyAdvice(validator);

    @Test
    void selectsOnlyAnnotatedMethodsRegardlessOfBodyType() throws NoSuchMethodException {
        assertThat(advice.supports(parameter("annotated"), String.class, StringHttpMessageConverter.class)).isTrue();
        assertThat(advice.supports(parameter("unannotated"), String.class, StringHttpMessageConverter.class)).isFalse();
        verifyNoInteractions(validator);
    }

    @Test
    void validatesBeforeBindingAndReplaysIdenticalBytesAndHeaders() throws Exception {
        byte[] bytes = "{ \"synthetic\": \"café\" }\n".getBytes(StandardCharsets.UTF_8);
        MockHttpInputMessage input = new MockHttpInputMessage(bytes);
        input.getHeaders().setContentType(MediaType.APPLICATION_JSON);
        input.getHeaders().set("X-Synthetic", "retained");

        HttpInputMessage replay = advice.beforeBodyRead(input, parameter("annotated"),
            String.class, StringHttpMessageConverter.class);

        verify(validator).validate("DraftCasefileAddRequest", bytes);
        assertThat(replay.getHeaders()).isSameAs(input.getHeaders());
        assertThat(replay.getBody().readAllBytes()).isEqualTo(bytes);
    }

    @Test
    void rejectedInputNeverReachesBindingOrController() throws Exception {
        byte[] bytes = "{}".getBytes(StandardCharsets.UTF_8);
        doThrow(new OpalApiException(RequestValidationError.INVALID_REQUEST))
            .when(validator).validate("DraftCasefileAddRequest", bytes);
        Runnable controller = mock(Runnable.class);
        StringHttpMessageConverter converter = mock(StringHttpMessageConverter.class);

        assertThatThrownBy(() -> {
            HttpInputMessage validated = advice.beforeBodyRead(new MockHttpInputMessage(bytes),
                parameter("annotated"), String.class, StringHttpMessageConverter.class);
            converter.read(String.class, validated);
            controller.run();
        }).isInstanceOf(OpalApiException.class);

        verifyNoInteractions(converter, controller);
    }

    @Test
    void leavesEmptyBodyHandlingToMvc() throws NoSuchMethodException {
        assertThat(advice.handleEmptyBody(null, new MockHttpInputMessage(new byte[0]), parameter("annotated"),
            String.class, StringHttpMessageConverter.class)).isNull();
        verifyNoInteractions(validator);
    }

    private static MethodParameter parameter(String name) throws NoSuchMethodException {
        return new MethodParameter(TestController.class.getDeclaredMethod(name, String.class), 0);
    }

    private static class TestController {
        @OpenApiRequest("DraftCasefileAddRequest")
        public void annotated(String body) {
        }

        public void unannotated(String body) {
        }
    }
}
