package uk.gov.hmcts.reform.opal.authentication.config;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.cache.CacheManager;
import org.springframework.cache.support.NoOpCacheManager;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;

@Configuration
public class UserStateClientConfiguration {


    @Bean
    @Primary
    @ConditionalOnProperty(prefix = "opal.redis", name = "enabled", havingValue = "false", matchIfMissing = true)
    CacheManager disabledRedisCacheManager() {
        return new NoOpCacheManager();
    }
}
