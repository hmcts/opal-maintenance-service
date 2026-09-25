package uk.gov.hmcts.opal.service;

import java.util.List;
import lombok.RequiredArgsConstructor;
import org.jspecify.annotations.Nullable;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import uk.gov.hmcts.opal.generated.model.CountryReferenceDataItem;
import uk.gov.hmcts.opal.generated.model.CountryReferenceDataResponse;
import uk.gov.hmcts.opal.mapper.CountryMapper;
import uk.gov.hmcts.opal.repository.CountryRepository;

@Service
@RequiredArgsConstructor
public class CountryService {

    private final CountryRepository repository;
    private final CountryMapper mapper;

    @Cacheable(
        cacheNames = "countryReferenceDataCache",
        key = "#active == null ? 'noFilter' : #active.toString()"
    )
    @Transactional(readOnly = true)
    public CountryReferenceDataResponse getCountries(@Nullable Boolean active) {
        List<CountryReferenceDataItem> refData = repository.findCountries(active).stream()
            .map(mapper::toReferenceDataItem)
            .toList();

        return CountryReferenceDataResponse.builder()
            .count(refData.size())
            .refData(refData)
            .build();
    }
}
