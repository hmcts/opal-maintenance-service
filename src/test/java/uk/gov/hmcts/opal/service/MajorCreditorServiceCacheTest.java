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
import uk.gov.hmcts.opal.mapper.MajorCreditorMapper;
import uk.gov.hmcts.opal.repository.MajorCreditorRepository;

@SpringJUnitConfig(MajorCreditorServiceCacheTest.Config.class)
@DisplayName("MajorCreditorService cache")
class MajorCreditorServiceCacheTest {

    @Autowired
    private MajorCreditorService service;

    @Autowired
    private MajorCreditorRepository repository;

    @Autowired
    private CacheManager cacheManager;

    @BeforeEach
    void clearCacheAndMocks() {
        cacheManager.getCache("majorCreditorReferenceDataCache").clear();
        clearInvocations(repository);
        when(repository.findMajorCreditors((short) 77, null, null)).thenReturn(List.of());
        when(repository.findMajorCreditors((short) 78, null, null)).thenReturn(List.of());
        when(repository.findMajorCreditors((short) 77, false, null)).thenReturn(List.of());
        when(repository.findMajorCreditors((short) 77, true, null)).thenReturn(List.of());
        when(repository.findMajorCreditors((short) 77, null, false)).thenReturn(List.of());
        when(repository.findMajorCreditors((short) 77, null, true)).thenReturn(List.of());
    }

    @Test
    void cachesRepeatedCallsForTheSameBusinessUnitAndFilters() {
        var first = service.getMajorCreditors((short) 77, null, null);
        var second = service.getMajorCreditors((short) 77, null, null);

        assertThat(second).isSameAs(first);
        verify(repository).findMajorCreditors((short) 77, null, null);
    }

    @Test
    void separatesBusinessUnitAndEveryOptionalBooleanState() {
        service.getMajorCreditors((short) 77, null, null);
        service.getMajorCreditors((short) 78, null, null);
        service.getMajorCreditors((short) 77, false, null);
        service.getMajorCreditors((short) 77, true, null);
        service.getMajorCreditors((short) 77, null, false);
        service.getMajorCreditors((short) 77, null, true);

        verify(repository).findMajorCreditors((short) 77, null, null);
        verify(repository).findMajorCreditors((short) 78, null, null);
        verify(repository).findMajorCreditors((short) 77, false, null);
        verify(repository).findMajorCreditors((short) 77, true, null);
        verify(repository).findMajorCreditors((short) 77, null, false);
        verify(repository).findMajorCreditors((short) 77, null, true);
    }

    @Configuration
    @EnableCaching
    static class Config {

        @Bean
        CacheManager cacheManager() {
            return new ConcurrentMapCacheManager();
        }

        @Bean
        MajorCreditorRepository majorCreditorRepository() {
            return mock(MajorCreditorRepository.class);
        }

        @Bean
        MajorCreditorMapper majorCreditorMapper() {
            return mock(MajorCreditorMapper.class);
        }

        @Bean
        MajorCreditorService majorCreditorService(
            MajorCreditorRepository repository,
            MajorCreditorMapper mapper
        ) {
            return new MajorCreditorService(repository, mapper);
        }
    }
}
