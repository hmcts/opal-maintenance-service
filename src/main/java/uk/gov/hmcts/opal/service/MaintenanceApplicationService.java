package uk.gov.hmcts.opal.service;

import java.util.List;
import lombok.RequiredArgsConstructor;
import org.jspecify.annotations.Nullable;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import uk.gov.hmcts.opal.generated.model.MaintenanceApplicationReferenceDataItem;
import uk.gov.hmcts.opal.generated.model.MaintenanceApplicationReferenceDataResponse;
import uk.gov.hmcts.opal.mapper.MaintenanceApplicationMapper;
import uk.gov.hmcts.opal.repository.MaintenanceApplicationRepository;

@Service
@RequiredArgsConstructor
public class MaintenanceApplicationService {

    private final MaintenanceApplicationRepository repository;
    private final MaintenanceApplicationMapper mapper;

    @Transactional(readOnly = true)
    @Cacheable(
        cacheNames = "maintenanceApplicationReferenceDataCache",
        key = "#applicationGroup + '_' + (#active == null ? 'noFilter' : #active.toString())"
    )
    public MaintenanceApplicationReferenceDataResponse getMaintenanceApplications(
        String applicationGroup, @Nullable Boolean active
    ) {
        List<MaintenanceApplicationReferenceDataItem> items = repository
            .findMaintenanceApplications(applicationGroup, active).stream()
            .map(mapper::toReferenceDataItem)
            .toList();
        return MaintenanceApplicationReferenceDataResponse.builder()
            .count(items.size())
            .refData(items)
            .build();
    }
}
