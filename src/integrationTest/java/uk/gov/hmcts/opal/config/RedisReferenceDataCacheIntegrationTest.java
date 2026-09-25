package uk.gov.hmcts.opal.config;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.redis.testcontainers.RedisContainer;
import java.time.Duration;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.NullSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.openapitools.jackson.nullable.JsonNullable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.cache.CacheManager;
import org.springframework.data.redis.cache.RedisCacheManager;
import org.springframework.data.redis.core.RedisCallback;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.entity.CountryEntity;
import uk.gov.hmcts.opal.entity.MajorCreditorEntity;
import uk.gov.hmcts.opal.entity.ResultEntity;
import uk.gov.hmcts.opal.repository.CountryRepository;
import uk.gov.hmcts.opal.repository.MajorCreditorRepository;
import uk.gov.hmcts.opal.repository.ResultRepository;
import uk.gov.hmcts.opal.service.CountryService;
import uk.gov.hmcts.opal.service.MajorCreditorService;
import uk.gov.hmcts.opal.service.ResultService;

@Testcontainers
@AutoConfigureMockMvc
@TestPropertySource(properties = {
    "spring.flyway.locations=classpath:db/migration/ddl",
    "opal.redis.ttl-duration=8H",
    "management.health.redis.enabled=true"
})
@DisplayName("Reference-data caches backed by Redis")
class RedisReferenceDataCacheIntegrationTest extends BaseIntegrationTest {

    private static final String COUNTRY_KEY = "countryReferenceDataCache::noFilter";
    private static final String MAJOR_CREDITOR_KEY = "majorCreditorReferenceDataCache::77_noFilter_true";
    private static final String RESULT_KEY = "resultReferenceDataCache::noFilter_true";

    @Container
    private static final RedisContainer REDIS =
        new RedisContainer(DockerImageName.parse("redis:6.2.6"));

    @Autowired
    private CacheManager cacheManager;

    @Autowired
    private StringRedisTemplate redisTemplate;

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private CountryService countryService;

    @Autowired
    private MajorCreditorService majorCreditorService;

    @Autowired
    private ResultService resultService;

    @MockitoBean
    private CountryRepository countryRepository;

    @MockitoBean
    private MajorCreditorRepository majorCreditorRepository;

    @MockitoBean
    private ResultRepository resultRepository;

    @DynamicPropertySource
    static void redisProperties(DynamicPropertyRegistry registry) {
        registry.add("opal.redis.enabled", () -> true);
        registry.add("spring.data.redis.url", REDIS::getRedisURI);
    }

    @BeforeEach
    void clearRedisAndRepositoryInvocations() {
        redisTemplate.execute((RedisCallback<Void>) connection -> {
            connection.serverCommands().flushDb();
            return null;
        });
        clearInvocations(countryRepository);
        clearInvocations(majorCreditorRepository);
        clearInvocations(resultRepository);
    }

    @Test
    void countryResponseRoundTripsThroughRedisWithFinesKeyAndTtl() {
        CountryEntity country = CountryEntity.builder()
            .countryId(101L)
            .cjsCode((short) 2001)
            .countryName("France")
            .dateUsedFrom(LocalDate.of(2000, 1, 1))
            .active(true)
            .build();
        when(countryRepository.findCountries(null)).thenReturn(List.of(country));

        final var first = countryService.getCountries(null);
        verify(countryRepository).findCountries(null);
        clearInvocations(countryRepository);

        var cached = countryService.getCountries(null);

        assertThat(cacheManager).isInstanceOf(RedisCacheManager.class);
        assertThat(cached).isEqualTo(first);
        assertThat(cached.getRefData()).hasSize(1);
        verifyNoInteractions(countryRepository);
        assertRedisEntryHasEightHourTtl(COUNTRY_KEY);
    }

    @Test
    void majorCreditorResponseRoundTripsThroughRedisWithFinesKeyAndTtl() {
        CountryEntity country = CountryEntity.builder()
            .countryId(101L)
            .countryName("France")
            .active(false)
            .build();
        MajorCreditorEntity creditor = MajorCreditorEntity.builder()
            .majorCreditorId(901L)
            .businessUnitId((short) 77)
            .majorCreditorCode("0123")
            .name("Example Creditor")
            .addressLine1("1 Example Street")
            .country(country)
            .active(true)
            .centralAuthority(false)
            .build();
        when(majorCreditorRepository.findMajorCreditors((short) 77, null, true))
            .thenReturn(List.of(creditor));

        final var first = majorCreditorService.getMajorCreditors((short) 77, null, true);
        verify(majorCreditorRepository).findMajorCreditors((short) 77, null, true);
        clearInvocations(majorCreditorRepository);

        var cached = majorCreditorService.getMajorCreditors((short) 77, null, true);

        assertThat(cacheManager).isInstanceOf(RedisCacheManager.class);
        assertThat(cached).isEqualTo(first);
        assertThat(cached.getRefData()).singleElement()
            .satisfies(item -> {
                assertThat(item.getCountryId()).isEqualTo(JsonNullable.of(101L));
                assertThat(item.getCountryName()).isEqualTo(JsonNullable.of("France"));
            });
        verifyNoInteractions(majorCreditorRepository);
        assertRedisEntryHasEightHourTtl(MAJOR_CREDITOR_KEY);
    }

    @Test
    void resultResponseRoundTripsThroughRedisWithEightHourTtl() {
        when(resultRepository.findResults(null, true)).thenReturn(List.of(ResultEntity.builder()
            .resultId("ABC123").resultTitle("Example Result").orderTerm(true).active(true).build()));
        var first = resultService.getResults(null, true);
        verify(resultRepository).findResults(null, true);
        clearInvocations(resultRepository);
        var cached = resultService.getResults(null, true);
        assertThat(cached).isEqualTo(first);
        assertThat(cached.getRefData().getFirst().getResultTitle()).isEqualTo("Example Result");
        verifyNoInteractions(resultRepository);
        assertRedisEntryHasEightHourTtl(RESULT_KEY);
    }

    @Test
    void reportsRedisAsHealthyThroughSpringBootAutoConfiguration() throws Exception {
        mockMvc.perform(get("/health"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.components.redis.status").value("UP"));
    }

    @ParameterizedTest
    @NullSource
    @ValueSource(strings = {"[]", "[{\"name\":\"reason\"}]"})
    void detailResponseRoundTripsThroughRedis(String metadata) throws Exception {
        when(resultRepository.findById("ABC123")).thenReturn(Optional.of(ResultEntity.builder()
            .resultId("ABC123").resultTitle("Example").active(false).orderTerm(false)
            .resultParameters(metadata).build()));
        var first = resultService.getResult("ABC123");
        verify(resultRepository).findById("ABC123");
        clearInvocations(resultRepository);

        var cached = resultService.getResult("ABC123");
        assertThat(cached).isNotSameAs(first);
        assertThat(cached.getResultId()).isEqualTo("ABC123");
        assertThat(cached.getResultParameters().get()).isEqualTo(metadata);
        verifyNoInteractions(resultRepository);
        assertRedisEntryHasEightHourTtl("resultDetailCache::ABC123");

        String body = mockMvc.perform(get("/results/ABC123").with(user("test-user")))
            .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        var json = new ObjectMapper().readTree(body);
        assertThat(json.size()).isEqualTo(3);
        assertThat(json.has("result_parameters")).isTrue();
        if (metadata == null) {
            assertThat(json.get("result_parameters").isNull()).isTrue();
        } else {
            assertThat(json.get("result_parameters").isTextual()).isTrue();
            assertThat(json.get("result_parameters").asText()).isEqualTo(metadata);
        }
        verifyNoInteractions(resultRepository);
    }

    private void assertRedisEntryHasEightHourTtl(String key) {
        assertThat(redisTemplate.hasKey(key)).isTrue();
        Long ttlSeconds = redisTemplate.getExpire(key, TimeUnit.SECONDS);
        assertThat(ttlSeconds).isBetween(
            Duration.ofHours(7).toSeconds(),
            Duration.ofHours(8).toSeconds()
        );
    }
}
