package uk.gov.hmcts.opal.config;

import feign.FeignException;
import feign.Request;
import feign.Response;
import feign.RetryableException;
import feign.codec.ErrorDecoder;
import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.util.Collection;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

class FeignConfigurationTest {

    private static final String DOWNSTREAM_BODY = "downstream-identity-body-64824a37";
    private static final String DOWNSTREAM_REASON = "downstream-reason-efa63d24";
    private static final String UNSAFE_HEADER = "downstream-unsafe-header-8bc00e91";
    private static final Request REQUEST = Request.create(
        Request.HttpMethod.GET,
        "http://user-service.test/v2/users/0/state",
        Map.of("Authorization", List.of("Bearer request-secret")),
        Request.Body.empty(),
        null
    );

    private final ErrorDecoder errorDecoder = new FeignConfiguration().feignErrorDecoder();

    @Test
    void preservesNotFoundStatusWithoutDownstreamResponseData() {
        Exception exception = errorDecoder.decode(
            "UserClient#getUserStateByIdWithAuthToken",
            response(404, Map.of("Set-Cookie", List.of(UNSAFE_HEADER)))
        );

        assertThat(exception).isInstanceOf(FeignException.NotFound.class);
        assertSanitised((FeignException) exception, 404);
    }

    @Test
    void preservesInternalServerErrorStatusWithoutDownstreamResponseData() {
        Exception exception = errorDecoder.decode(
            "UserClient#getUserStateByIdWithAuthToken",
            response(500, Map.of("Set-Cookie", List.of(UNSAFE_HEADER)))
        );

        assertThat(exception).isInstanceOf(FeignException.InternalServerError.class);
        assertSanitised((FeignException) exception, 500);
    }

    @Test
    void preservesRetryAfterSemanticsWithoutDownstreamResponseData() {
        Exception exception = errorDecoder.decode(
            "UserClient#getUserStateByIdWithAuthToken",
            response(503, Map.of("Retry-After", List.of("5"), "Set-Cookie", List.of(UNSAFE_HEADER)))
        );

        assertThat(exception).isInstanceOf(RetryableException.class);
        assertThat(((RetryableException) exception).retryAfter()).isNotNull();
        assertSanitised((FeignException) exception, 503);
    }

    private static Response response(int status, Map<String, Collection<String>> headers) {
        return Response.builder()
            .status(status)
            .reason(DOWNSTREAM_REASON)
            .headers(headers)
            .request(REQUEST)
            .body(DOWNSTREAM_BODY, StandardCharsets.UTF_8)
            .build();
    }

    private static void assertSanitised(FeignException exception, int status) {
        assertThat(exception.status()).isEqualTo(status);
        assertThat(exception.contentUTF8()).isEmpty();
        assertThat(exception.responseHeaders()).isEmpty();
        assertThat(exception.getMessage()).doesNotContain(DOWNSTREAM_BODY, DOWNSTREAM_REASON, UNSAFE_HEADER);
    }
}
