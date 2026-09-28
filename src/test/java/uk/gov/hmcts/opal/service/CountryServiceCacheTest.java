package uk.gov.hmcts.opal.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.cache.CacheManager;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.cache.concurrent.ConcurrentMapCacheManager;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.test.context.junit.jupiter.SpringJUnitConfig;
import uk.gov.hmcts.opal.mapper.CountryMapper;
import uk.gov.hmcts.opal.repository.CountryRepository;

@SpringJUnitConfig(CountryServiceCacheTest.Config.class)
@DisplayName("CountryService cache")
class CountryServiceCacheTest {

    @Autowired
    private CountryService service;

    @Autowired
    private CountryRepository repository;

    @Autowired
    private CacheManager cacheManager;

    @BeforeEach
    void clearCacheAndMocks() {
        cacheManager.getCache("countryReferenceDataCache").clear();
        clearInvocations(repository);
        when(repository.findCountries(null)).thenReturn(List.of());
        when(repository.findCountries(true)).thenReturn(List.of());
        when(repository.findCountries(false)).thenReturn(List.of());
    }

    @Test
    void cachesRepeatedCallsForTheSameFilter() {
        var first = service.getCountries(null);
        var second = service.getCountries(null);

        assertThat(second).isSameAs(first);
        verify(repository).findCountries(null);
    }

    @Test
    void keepsOmittedTrueAndFalseFiltersInSeparateEntries() {
        service.getCountries(null);
        service.getCountries(true);
        service.getCountries(false);
        service.getCountries(null);
        service.getCountries(true);
        service.getCountries(false);

        verify(repository).findCountries(null);
        verify(repository).findCountries(true);
        verify(repository).findCountries(false);
    }

    @Configuration
    @EnableCaching
    static class Config {

        @Bean
        CacheManager cacheManager() {
            return new ConcurrentMapCacheManager();
        }

        @Bean
        CountryRepository countryRepository() {
            return mock(CountryRepository.class);
        }

        @Bean
        CountryMapper countryMapper() {
            return mock(CountryMapper.class);
        }

        @Bean
        CountryService countryService(CountryRepository repository, CountryMapper mapper) {
            return new CountryService(repository, mapper);
        }
    }
}
