package uk.gov.hmcts.opal.config;

import io.lettuce.core.ClientOptions;
import io.lettuce.core.MaintNotificationsConfig;
import io.lettuce.core.RedisURI;
import java.time.Duration;
import org.openapitools.jackson.nullable.JsonNullableJackson3Module;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.cache.CacheManager;
import org.springframework.cache.concurrent.ConcurrentMapCacheManager;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.data.redis.cache.RedisCacheConfiguration;
import org.springframework.data.redis.cache.RedisCacheManager;
import org.springframework.data.redis.cache.RedisCacheWriter;
import org.springframework.data.redis.connection.RedisConfiguration;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.connection.lettuce.LettuceClientConfiguration;
import org.springframework.data.redis.connection.lettuce.LettuceConnectionFactory;
import org.springframework.data.redis.serializer.GenericJacksonJsonRedisSerializer;
import org.springframework.data.redis.serializer.RedisSerializationContext.SerializationPair;
import org.springframework.data.redis.serializer.RedisSerializer;
import tools.jackson.databind.jsontype.BasicPolymorphicTypeValidator;

@Configuration
public class CacheConfig {

    @Bean
    @ConditionalOnProperty(prefix = "opal.redis", name = "enabled", havingValue = "true")
    LettuceConnectionFactory redisConnectionFactory(
        @Value("${spring.data.redis.url}") String redisUrl
    ) {
        RedisURI redisUri = RedisURI.create(redisUrl);
        RedisConfiguration redisConfiguration = LettuceConnectionFactory.createRedisConfiguration(redisUri);
        LettuceClientConfiguration.LettuceClientConfigurationBuilder clientConfiguration =
            LettuceClientConfiguration.builder()
                .clientOptions(ClientOptions.builder()
                    .maintNotificationsConfig(MaintNotificationsConfig.disabled())
                    .build());
        if (redisUri.isSsl()) {
            clientConfiguration.useSsl();
        }
        return new LettuceConnectionFactory(redisConfiguration, clientConfiguration.build());
    }

    @Bean
    @Primary
    @ConditionalOnProperty(prefix = "opal.redis", name = "enabled", havingValue = "true")
    RedisCacheManager redisCacheManager(
        RedisConnectionFactory connectionFactory,
        @Value("${opal.redis.ttl-duration:8H}") Duration ttl
    ) {
        RedisCacheConfiguration defaults = RedisCacheConfiguration.defaultCacheConfig()
            .entryTtl(ttl)
            .serializeKeysWith(SerializationPair.fromSerializer(RedisSerializer.string()))
            .serializeValuesWith(SerializationPair.fromSerializer(redisValueSerializer()));
        RedisCacheWriter cacheWriter = RedisCacheWriter.create(
            connectionFactory,
            RedisCacheWriter.RedisCacheWriterConfigurer::immediateWrites
        );

        return RedisCacheManager.builder(cacheWriter)
            .cacheDefaults(defaults)
            .build();
    }

    @Bean
    @Primary
    @ConditionalOnProperty(prefix = "opal.redis", name = "enabled", havingValue = "false", matchIfMissing = true)
    CacheManager localCacheManager() {
        return new ConcurrentMapCacheManager();
    }

    private RedisSerializer<Object> redisValueSerializer() {
        return GenericJacksonJsonRedisSerializer.builder()
            .enableDefaultTyping(BasicPolymorphicTypeValidator.builder()
                .allowIfSubType(Object.class)
                .build())
            .customize(builder -> builder.addModule(new JsonNullableJackson3Module()))
            .build();
    }
}
