package uk.gov.hmcts.opal.config;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.mockito.Mockito.withSettings;

import io.lettuce.core.ClientOptions;
import io.lettuce.core.MaintNotificationsConfig;
import java.nio.ByteBuffer;
import java.time.Duration;
import java.util.List;
import java.util.concurrent.atomic.AtomicBoolean;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.cache.concurrent.ConcurrentMapCacheManager;
import org.springframework.data.redis.cache.RedisCache;
import org.springframework.data.redis.cache.RedisCacheManager;
import org.springframework.data.redis.connection.ReactiveRedisConnection;
import org.springframework.data.redis.connection.ReactiveRedisConnectionFactory;
import org.springframework.data.redis.connection.ReactiveStringCommands;
import org.springframework.data.redis.connection.RedisConnection;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.connection.RedisStringCommands;
import org.springframework.data.redis.connection.SetCondition;
import org.springframework.data.redis.connection.lettuce.LettuceConnectionFactory;
import org.springframework.data.redis.core.types.Expiration;
import reactor.core.publisher.Mono;
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
    void writesToRedisBeforeCachePutReturns() {
        RedisConnectionFactory connectionFactory = mock(
            RedisConnectionFactory.class,
            withSettings().extraInterfaces(ReactiveRedisConnectionFactory.class)
        );
        ReactiveRedisConnectionFactory reactiveConnectionFactory =
            (ReactiveRedisConnectionFactory) connectionFactory;
        ReactiveRedisConnection reactiveConnection = mock(ReactiveRedisConnection.class);
        ReactiveStringCommands reactiveCommands = mock(ReactiveStringCommands.class);
        when(reactiveConnectionFactory.getReactiveConnection()).thenReturn(reactiveConnection);
        when(reactiveConnection.stringCommands()).thenReturn(reactiveCommands);
        when(reactiveCommands.set(
            any(ByteBuffer.class),
            any(ByteBuffer.class),
            any(SetCondition.class),
            any(Expiration.class)
        )).thenReturn(Mono.never());

        AtomicBoolean writeCompleted = new AtomicBoolean();
        RedisConnection connection = mock(RedisConnection.class);
        RedisStringCommands commands = mock(RedisStringCommands.class);
        when(connectionFactory.getConnection()).thenReturn(connection);
        when(connection.stringCommands()).thenReturn(commands);
        when(commands.set(
            any(byte[].class),
            any(byte[].class),
            any(SetCondition.class),
            any(Expiration.class)
        )).thenAnswer(invocation -> writeCompleted.compareAndSet(false, true));

        RedisCacheManager manager = config.redisCacheManager(connectionFactory, Duration.ofHours(8));
        manager.afterPropertiesSet();
        manager.getCache("countryReferenceDataCache").put("key", "value");

        assertThat(writeCompleted).isTrue();
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
