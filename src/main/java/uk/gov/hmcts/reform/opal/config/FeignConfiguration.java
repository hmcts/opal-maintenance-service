package uk.gov.hmcts.reform.opal.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import feign.codec.Decoder;
import feign.jackson.JacksonDecoder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class FeignConfiguration {

    @Bean
    public Decoder feignDecoder(final ObjectMapper objectMapper) {
        return new JacksonDecoder(objectMapper);
    }
}
