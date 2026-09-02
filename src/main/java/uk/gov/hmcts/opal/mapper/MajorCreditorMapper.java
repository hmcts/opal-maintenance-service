package uk.gov.hmcts.opal.mapper;

import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.ReportingPolicy;
import org.openapitools.jackson.nullable.JsonNullable;
import uk.gov.hmcts.opal.entity.MajorCreditorEntity;
import uk.gov.hmcts.opal.generated.model.MajorCreditorReferenceDataItem;

@Mapper(componentModel = "spring", unmappedTargetPolicy = ReportingPolicy.ERROR)
public interface MajorCreditorMapper {

    @Mapping(source = "country.countryId", target = "countryId")
    @Mapping(source = "country.countryName", target = "countryName")
    MajorCreditorReferenceDataItem toReferenceDataItem(MajorCreditorEntity majorCreditor);

    default <T> JsonNullable<T> mapToJsonNullable(T value) {
        return JsonNullable.of(value);
    }
}
