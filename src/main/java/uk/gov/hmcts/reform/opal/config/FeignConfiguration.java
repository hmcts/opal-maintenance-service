package uk.gov.hmcts.reform.opal.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import feign.Response;
import feign.codec.Decoder;
import feign.codec.ErrorDecoder;
import feign.jackson.JacksonDecoder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.Collection;
import java.util.Map;
import java.util.TreeMap;

@Configuration
public class FeignConfiguration {

    private static final String RETRY_AFTER_HEADER = "Retry-After";

    @Bean
    public Decoder feignDecoder(final ObjectMapper objectMapper) {
        return new JacksonDecoder(objectMapper);
    }

    @Bean
    public ErrorDecoder feignErrorDecoder() {
        ErrorDecoder defaultDecoder = new ErrorDecoder.Default();
        return (methodKey, response) -> defaultDecoder.decode(methodKey, sanitisedResponse(response));
    }

    private Response sanitisedResponse(Response response) {
        Map<String, Collection<String>> headers = new TreeMap<>(String.CASE_INSENSITIVE_ORDER);
        response.headers().forEach((name, values) -> {
            if (RETRY_AFTER_HEADER.equalsIgnoreCase(name)) {
                headers.put(name, values);
            }
        });
        return response.toBuilder()
            .reason(null)
            .headers(headers)
            .body(new byte[0])
            .build();
    }
}
