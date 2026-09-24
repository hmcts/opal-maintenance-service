package uk.gov.hmcts.opal.mapper;

import org.mapstruct.Mapper;
import org.mapstruct.ReportingPolicy;
import uk.gov.hmcts.opal.entity.MaintenanceApplicationEntity;
import uk.gov.hmcts.opal.generated.model.MaintenanceApplicationReferenceDataItem;

@Mapper(componentModel = "spring", unmappedTargetPolicy = ReportingPolicy.ERROR)
public interface MaintenanceApplicationMapper {

    MaintenanceApplicationReferenceDataItem toReferenceDataItem(MaintenanceApplicationEntity application);
}
