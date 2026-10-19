package uk.gov.hmcts.opal.mapper;

import javax.annotation.processing.Generated;
import org.springframework.stereotype.Component;
import uk.gov.hmcts.opal.entity.MaintenanceApplicationEntity;
import uk.gov.hmcts.opal.generated.model.MaintenanceApplicationReferenceDataItem;

@Generated(
    value = "org.mapstruct.ap.MappingProcessor",
    date = "2026-10-16T09:39:42+0100",
    comments = "version: 1.6.3, compiler: Eclipse JDT (IDE) 3.46.200.v20260930-0211, environment: Java 25.0.4.1 (Eclipse Adoptium)"
)
@Component
public class MaintenanceApplicationMapperImpl implements MaintenanceApplicationMapper {

    @Override
    public MaintenanceApplicationReferenceDataItem toReferenceDataItem(MaintenanceApplicationEntity application) {
        if ( application == null ) {
            return null;
        }

        MaintenanceApplicationReferenceDataItem.Builder maintenanceApplicationReferenceDataItem = MaintenanceApplicationReferenceDataItem.builder();

        maintenanceApplicationReferenceDataItem.applicationId( application.getApplicationId() );
        maintenanceApplicationReferenceDataItem.applicationCode( application.getApplicationCode() );
        maintenanceApplicationReferenceDataItem.applicationTitle( application.getApplicationTitle() );
        maintenanceApplicationReferenceDataItem.applicationGroup( application.getApplicationGroup() );
        maintenanceApplicationReferenceDataItem.active( application.getActive() );

        return maintenanceApplicationReferenceDataItem.build();
    }
}
