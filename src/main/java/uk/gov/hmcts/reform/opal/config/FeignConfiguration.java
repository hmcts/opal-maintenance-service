package uk.gov.hmcts.reform.opal.config;


import feign.Response;
import feign.codec.Decoder;
import feign.codec.ErrorDecoder;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.cloud.openfeign.support.FeignHttpMessageConverters;
import org.springframework.cloud.openfeign.support.ResponseEntityDecoder;
import org.springframework.cloud.openfeign.support.SpringDecoder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.Collection;
import java.util.Map;
import java.util.TreeMap;

@Configuration
public class FeignConfiguration {

    private static final String RETRY_AFTER_HEADER = "Retry-After";

    @Bean
    public Decoder feignDecoder(ObjectProvider<FeignHttpMessageConverters> messageConverters) {
        return new ResponseEntityDecoder(new SpringDecoder(messageConverters));
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
