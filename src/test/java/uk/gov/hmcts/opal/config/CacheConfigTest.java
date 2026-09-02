package uk.gov.hmcts.opal.config;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

import io.lettuce.core.ClientOptions;
import io.lettuce.core.MaintNotificationsConfig;
import java.time.Duration;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.cache.concurrent.ConcurrentMapCacheManager;
import org.springframework.data.redis.cache.RedisCache;
import org.springframework.data.redis.cache.RedisCacheManager;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.connection.lettuce.LettuceConnectionFactory;
import uk.gov.hmcts.opal.generated.model.CountryReferenceDataResponse;

@DisplayName("Application cache configuration")
class CacheConfigTest {

    private final CacheConfig config = new CacheConfig();

    @Test
    void usesConcurrentMapWhenRedisIsDisabled() {
        var manager = config.localCacheManager();

        assertThat(manager).isInstanceOf(ConcurrentMapCacheManager.class);
        assertThat(manager.getCache("countryReferenceDataCache")).isNotNull();
        assertThat(manager.getCache("majorCreditorReferenceDataCache")).isNotNull();
        assertThat(manager.getCache("userState")).isNotNull();
    }

    @Test
    void appliesConfiguredTtlAndJsonSerializationToRedisCaches() {
        RedisConnectionFactory connectionFactory = mock(RedisConnectionFactory.class);
        RedisCacheManager manager = config.redisCacheManager(connectionFactory, Duration.ofHours(8));
        manager.afterPropertiesSet();

        RedisCache cache = (RedisCache) manager.getCache("countryReferenceDataCache");
        assertThat(cache).isNotNull();
        assertThat(cache.getCacheConfiguration().getTtlFunction()
            .getTimeToLive("key", null)).isEqualTo(Duration.ofHours(8));

        RedisCache userStateCache = (RedisCache) manager.getCache("userState");
        assertThat(userStateCache).isNotNull();
        assertThat(userStateCache.getCacheConfiguration().getTtlFunction()
            .getTimeToLive("key", null)).isEqualTo(Duration.ofHours(8));

        CountryReferenceDataResponse response = CountryReferenceDataResponse.builder()
            .count(0)
            .refData(List.of())
            .build();
        var values = cache.getCacheConfiguration().getValueSerializationPair();
        Object roundTrip = values.read(values.write(response));

        assertThat(roundTrip).isEqualTo(response);
        assertThat(roundTrip).isInstanceOf(CountryReferenceDataResponse.class);
    }

    @Test
    void enablesSslForRedissUris() {
        LettuceConnectionFactory factory = config.redisConnectionFactory("rediss://localhost:6380");

        assertThat(factory.isUseSsl()).isTrue();
        assertThat(factory.getClientConfiguration().getClientOptions())
            .map(ClientOptions::getMaintNotificationsConfig)
            .map(MaintNotificationsConfig::maintNotificationsEnabled)
            .hasValue(false);
    }

    @Test
    void leavesSslDisabledForRedisUris() {
        LettuceConnectionFactory factory = config.redisConnectionFactory("redis://localhost:6379");

        assertThat(factory.isUseSsl()).isFalse();
    }
}
