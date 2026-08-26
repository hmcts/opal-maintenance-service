package uk.gov.hmcts.reform.opal.service;

import java.util.List;
import lombok.RequiredArgsConstructor;
import org.jspecify.annotations.Nullable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import uk.gov.hmcts.opal.generated.model.CountryReferenceDataItem;
import uk.gov.hmcts.opal.generated.model.CountryReferenceDataResponse;
import uk.gov.hmcts.reform.opal.mapper.CountryMapper;
import uk.gov.hmcts.reform.opal.repository.CountryRepository;

@Service
@RequiredArgsConstructor
public class CountryService {

    private final CountryRepository repository;
    private final CountryMapper mapper;

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
