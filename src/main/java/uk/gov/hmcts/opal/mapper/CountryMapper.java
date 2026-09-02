package uk.gov.hmcts.opal.mapper;

import org.mapstruct.Mapper;
import org.mapstruct.ReportingPolicy;
import uk.gov.hmcts.opal.entity.CountryEntity;
import uk.gov.hmcts.opal.generated.model.CountryReferenceDataItem;

@Mapper(componentModel = "spring", unmappedTargetPolicy = ReportingPolicy.ERROR)
public interface CountryMapper {

    CountryReferenceDataItem toReferenceDataItem(CountryEntity country);
}
