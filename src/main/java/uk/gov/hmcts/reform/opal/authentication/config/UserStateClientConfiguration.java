package uk.gov.hmcts.reform.opal.authentication.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.cache.CacheManager;
import org.springframework.cache.support.NoOpCacheManager;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.data.redis.core.StringRedisTemplate;
import uk.gov.hmcts.opal.common.user.authorisation.client.UserClient;
import uk.gov.hmcts.opal.common.user.authorisation.client.mapper.UserStateMapper;

@Configuration
public class UserStateClientConfiguration {

    @Bean
    @Primary
    RedisAwareUserStateClientService redisAwareUserStateClientService(
        UserClient userClient,
        UserStateMapper userStateMapper,
        StringRedisTemplate redisTemplate,
        ObjectMapper objectMapper,
        @Value("${opal.redis.enabled:false}") boolean redisEnabled) {
        return new RedisAwareUserStateClientService(
            userClient,
            userStateMapper,
            redisTemplate,
            objectMapper,
            redisEnabled
        );
    }

    @Bean
    @Primary
    @ConditionalOnProperty(prefix = "opal.redis", name = "enabled", havingValue = "false", matchIfMissing = true)
    CacheManager disabledRedisCacheManager() {
        return new NoOpCacheManager();
    }
}
