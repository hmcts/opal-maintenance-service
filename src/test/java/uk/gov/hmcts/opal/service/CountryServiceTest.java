package uk.gov.hmcts.opal.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.util.List;
import org.jspecify.annotations.Nullable;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.NullSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import uk.gov.hmcts.opal.generated.model.CountryReferenceDataItem;
import uk.gov.hmcts.opal.entity.CountryEntity;
import uk.gov.hmcts.opal.mapper.CountryMapper;
import uk.gov.hmcts.opal.repository.CountryRepository;

@ExtendWith(MockitoExtension.class)
@DisplayName("PO-10251 CountryService")
class CountryServiceTest {

    @Mock
    private CountryRepository repository;

    @Mock
    private CountryMapper mapper;

    @InjectMocks
    private CountryService service;

    @ParameterizedTest(name = "PO-10251 maps repository results when active={0}")
    @NullSource
    @ValueSource(booleans = {true, false})
    void mapsOrderedRepositoryResults(@Nullable Boolean active) {
        CountryEntity firstEntity = CountryEntity.builder().countryId(1L).build();
        CountryEntity secondEntity = CountryEntity.builder().countryId(2L).build();
        CountryReferenceDataItem firstItem = CountryReferenceDataItem.builder()
            .countryId(1L)
            .build();
        CountryReferenceDataItem secondItem = CountryReferenceDataItem.builder()
            .countryId(2L)
            .build();
        when(repository.findCountries(active)).thenReturn(List.of(firstEntity, secondEntity));
        when(mapper.toReferenceDataItem(firstEntity)).thenReturn(firstItem);
        when(mapper.toReferenceDataItem(secondEntity)).thenReturn(secondItem);

        var response = service.getCountries(active);

        assertThat(response.getCount()).isEqualTo(2);
        assertThat(response.getRefData()).containsExactly(firstItem, secondItem);
        verify(repository).findCountries(active);
        verify(mapper).toReferenceDataItem(firstEntity);
        verify(mapper).toReferenceDataItem(secondEntity);
    }

    @Test
    @DisplayName("PO-10251 returns a zero count and empty refData")
    void returnsEmptyResponse() {
        when(repository.findCountries(null)).thenReturn(List.of());

        var response = service.getCountries(null);

        assertThat(response.getCount()).isZero();
        assertThat(response.getRefData()).isEmpty();
        verify(repository).findCountries(null);
        verifyNoInteractions(mapper);
    }
}
