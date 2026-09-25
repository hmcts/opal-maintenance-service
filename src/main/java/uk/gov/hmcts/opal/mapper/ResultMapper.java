package uk.gov.hmcts.opal.mapper;

import org.mapstruct.Mapper;
import org.mapstruct.ReportingPolicy;
import org.openapitools.jackson.nullable.JsonNullable;
import uk.gov.hmcts.opal.entity.ResultEntity;
import uk.gov.hmcts.opal.generated.model.ResultDetailResponse;
import uk.gov.hmcts.opal.generated.model.ResultReferenceDataItem;

@Mapper(componentModel = "spring", unmappedTargetPolicy = ReportingPolicy.ERROR)
public interface ResultMapper {

    ResultDetailResponse toDetailResponse(ResultEntity result);

    ResultReferenceDataItem toReferenceDataItem(ResultEntity result);

    default <T> JsonNullable<T> mapToJsonNullable(T value) {
        return JsonNullable.of(value);
    }
}
