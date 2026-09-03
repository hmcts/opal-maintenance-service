package uk.gov.hmcts.opal.service;

import java.util.List;
import lombok.RequiredArgsConstructor;
import org.jspecify.annotations.Nullable;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import uk.gov.hmcts.opal.generated.model.MajorCreditorReferenceDataItem;
import uk.gov.hmcts.opal.generated.model.MajorCreditorReferenceDataResponse;
import uk.gov.hmcts.opal.mapper.MajorCreditorMapper;
import uk.gov.hmcts.opal.repository.MajorCreditorRepository;

@Service
@RequiredArgsConstructor
public class MajorCreditorService {

    private final MajorCreditorRepository repository;
    private final MajorCreditorMapper mapper;

    @Cacheable(
        cacheNames = "majorCreditorReferenceDataCache",
        key = "#businessUnitId + '_'"
            + " + (#centralAuthority == null ? 'noFilter' : #centralAuthority.toString())"
            + " + '_' + (#active == null ? 'noFilter' : #active.toString())"
    )
    @Transactional(readOnly = true)
    public MajorCreditorReferenceDataResponse getMajorCreditors(
        Short businessUnitId,
        @Nullable Boolean centralAuthority,
        @Nullable Boolean active
    ) {
        List<MajorCreditorReferenceDataItem> refData = repository
            .findMajorCreditors(businessUnitId, centralAuthority, active)
            .stream()
            .map(mapper::toReferenceDataItem)
            .toList();

        return MajorCreditorReferenceDataResponse.builder()
            .count(refData.size())
            .refData(refData)
            .build();
    }
}
