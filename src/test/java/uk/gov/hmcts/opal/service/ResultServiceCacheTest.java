package uk.gov.hmcts.opal.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.reset;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import jakarta.persistence.EntityNotFoundException;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mapstruct.factory.Mappers;
import org.springframework.cache.CacheManager;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.cache.concurrent.ConcurrentMapCacheManager;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.test.context.junit.jupiter.SpringJUnitConfig;
import uk.gov.hmcts.opal.entity.ResultEntity;
import uk.gov.hmcts.opal.mapper.ResultMapper;
import uk.gov.hmcts.opal.repository.ResultRepository;

@SpringJUnitConfig(ResultServiceCacheTest.Config.class)
class ResultServiceCacheTest {

    @Configuration
    @EnableCaching
    static class Config {
        @Bean
        CacheManager cacheManager() {
            return new ConcurrentMapCacheManager();
        }

        @Bean
        ResultRepository resultRepository() {
            return mock(ResultRepository.class);
        }

        @Bean
        ResultMapper resultMapper() {
            return Mappers.getMapper(ResultMapper.class);
        }

        @Bean
        ResultService resultService(ResultRepository repository, ResultMapper mapper) {
            return new ResultService(repository, mapper);
        }
    }

    @org.springframework.beans.factory.annotation.Autowired
    private ResultService service;

    @org.springframework.beans.factory.annotation.Autowired
    private ResultRepository repository;

    @org.springframework.beans.factory.annotation.Autowired
    private CacheManager cacheManager;

    @BeforeEach
    void clearCacheAndResetRepository() {
        cacheManager.getCache("resultReferenceDataCache").clear();
        cacheManager.getCache("resultDetailCache").clear();
        reset(repository);
    }

    @Test
    void separatesAndCachesAllNineFilterCombinations() {
        Boolean[] states = {null, true, false};
        int index = 0;
        for (Boolean orderTerm : states) {
            for (Boolean active : states) {
                String id = "R" + index++;
                when(repository.findResults(orderTerm, active)).thenReturn(List.of(ResultEntity.builder()
                    .resultId(id).resultTitle(id).orderTerm(true).active(true).build()));
                assertThat(service.getResults(orderTerm, active).getRefData().getFirst().getResultId())
                    .isEqualTo(id);
            }
        }
        index = 0;
        for (Boolean orderTerm : states) {
            for (Boolean active : states) {
                assertThat(service.getResults(orderTerm, active).getRefData().getFirst().getResultId())
                    .isEqualTo("R" + index++);
                verify(repository, times(1)).findResults(orderTerm, active);
            }
        }
    }

    @Test
    void cachesEmptyResponse() {
        when(repository.findResults(null, null)).thenReturn(List.of());
        assertThat(service.getResults(null, null).getRefData()).isEmpty();
        assertThat(service.getResults(null, null).getCount()).isZero();
        verify(repository, times(1)).findResults(null, null);
    }

    @Test
    void retriesAfterFailureAndCachesOnlyTheSuccess() {
        when(repository.findResults(true, true))
            .thenThrow(new IllegalStateException("Synthetic failure")).thenReturn(List.of());
        assertThatThrownBy(() -> service.getResults(true, true)).isInstanceOf(IllegalStateException.class);
        assertThat(service.getResults(true, true).getCount()).isZero();
        assertThat(service.getResults(true, true).getCount()).isZero();
        verify(repository, times(2)).findResults(true, true);
    }

    @Test
    void cachesDetailByExactIdSeparatelyFromList() {
        for (String id : List.of("ABC123", "abc123")) {
            when(repository.findById(id)).thenReturn(Optional.of(ResultEntity.builder()
                .resultId(id).resultTitle(id).resultParameters("[]").active(false).orderTerm(false).build()));
            assertThat(service.getResult(id).getResultId()).isEqualTo(id);
        }
        when(repository.findResults(null, null)).thenReturn(List.of());
        assertThat(service.getResults(null, null).getRefData()).isEmpty();
        for (String id : List.of("ABC123", "abc123")) {
            assertThat(service.getResult(id).getResultId()).isEqualTo(id);
            verify(repository, times(1)).findById(id);
        }
    }

    @Test
    void cachesSuccessfulDetailWithNullMetadata() {
        when(repository.findById("ABC123")).thenReturn(Optional.of(ResultEntity.builder()
            .resultId("ABC123").resultTitle("Example").active(true).orderTerm(true).build()));
        assertThat(service.getResult("ABC123").getResultParameters().get()).isNull();
        assertThat(service.getResult("ABC123").getResultParameters().get()).isNull();
        verify(repository, times(1)).findById("ABC123");
    }

    @Test
    void doesNotCacheMissingResult() {
        var entity = ResultEntity.builder().resultId("ABC123").resultTitle("Example").build();
        when(repository.findById("ABC123")).thenReturn(Optional.empty()).thenReturn(Optional.of(entity));
        assertThatThrownBy(() -> service.getResult("ABC123")).isInstanceOf(EntityNotFoundException.class);
        assertThat(service.getResult("ABC123").getResultId()).isEqualTo("ABC123");
        assertThat(service.getResult("ABC123").getResultId()).isEqualTo("ABC123");
        verify(repository, times(2)).findById("ABC123");
    }

    @Test
    void doesNotCacheDetailRepositoryFailure() {
        var entity = ResultEntity.builder().resultId("ABC123").resultTitle("Example").build();
        when(repository.findById("ABC123")).thenThrow(new IllegalStateException("Synthetic failure"))
            .thenReturn(Optional.of(entity));
        assertThatThrownBy(() -> service.getResult("ABC123")).isInstanceOf(IllegalStateException.class);
        assertThat(service.getResult("ABC123").getResultId()).isEqualTo("ABC123");
        assertThat(service.getResult("ABC123").getResultId()).isEqualTo("ABC123");
        verify(repository, times(2)).findById("ABC123");
    }
}
