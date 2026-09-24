package uk.gov.hmcts.opal.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.reset;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mapstruct.factory.Mappers;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.cache.CacheManager;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.cache.concurrent.ConcurrentMapCacheManager;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.test.context.junit.jupiter.SpringJUnitConfig;
import uk.gov.hmcts.opal.entity.MaintenanceApplicationEntity;
import uk.gov.hmcts.opal.mapper.MaintenanceApplicationMapper;
import uk.gov.hmcts.opal.repository.MaintenanceApplicationRepository;

@SpringJUnitConfig(MaintenanceApplicationServiceCacheTest.Config.class)
class MaintenanceApplicationServiceCacheTest {

    @Configuration
    @EnableCaching
    static class Config {
        @Bean
        CacheManager cacheManager() {
            return new ConcurrentMapCacheManager();
        }

        @Bean
        MaintenanceApplicationRepository maintenanceApplicationRepository() {
            return mock(MaintenanceApplicationRepository.class);
        }

        @Bean
        MaintenanceApplicationMapper maintenanceApplicationMapper() {
            return Mappers.getMapper(MaintenanceApplicationMapper.class);
        }

        @Bean
        MaintenanceApplicationService maintenanceApplicationService(
            MaintenanceApplicationRepository repository, MaintenanceApplicationMapper mapper
        ) {
            return new MaintenanceApplicationService(repository, mapper);
        }
    }

    @Autowired
    private MaintenanceApplicationService service;

    @Autowired
    private MaintenanceApplicationRepository repository;

    @Autowired
    private CacheManager cacheManager;

    @BeforeEach
    void clearCacheAndResetRepository() {
        cacheManager.getCache("maintenanceApplicationReferenceDataCache").clear();
        reset(repository);
    }

    @Test
    void cachesEachExactGroupAndActiveCombinationSeparately() {
        String[] groups = {"Create Casefile", "create casefile", " Create Casefile "};
        Boolean[] states = {null, true, false};
        short id = 1;
        for (String group : groups) {
            for (Boolean active : states) {
                var row = MaintenanceApplicationEntity.builder().applicationId(id++)
                    .applicationCode("TEST").applicationTitle(group).applicationGroup(group).active(true).build();
                when(repository.findMaintenanceApplications(group, active)).thenReturn(List.of(row));
                service.getMaintenanceApplications(group, active);
            }
        }
        id = 1;
        for (String group : groups) {
            for (Boolean active : states) {
                assertThat(service.getMaintenanceApplications(group, active).getRefData().getFirst().getApplicationId())
                    .isEqualTo(id++);
                verify(repository, times(1)).findMaintenanceApplications(group, active);
            }
        }
    }

    @Test
    void cachesEmptyResponses() {
        when(repository.findMaintenanceApplications("Unknown", null)).thenReturn(List.of());
        assertThat(service.getMaintenanceApplications("Unknown", null).getRefData()).isEmpty();
        assertThat(service.getMaintenanceApplications("Unknown", null).getCount()).isZero();
        verify(repository, times(1)).findMaintenanceApplications("Unknown", null);
    }

    @Test
    void doesNotCacheFailures() {
        when(repository.findMaintenanceApplications("Create Casefile", true))
            .thenThrow(new IllegalStateException("Synthetic failure")).thenReturn(List.of());
        assertThatThrownBy(() -> service.getMaintenanceApplications("Create Casefile", true))
            .isInstanceOf(IllegalStateException.class);
        assertThat(service.getMaintenanceApplications("Create Casefile", true).getCount()).isZero();
        assertThat(service.getMaintenanceApplications("Create Casefile", true).getCount()).isZero();
        verify(repository, times(2)).findMaintenanceApplications("Create Casefile", true);
    }
}
