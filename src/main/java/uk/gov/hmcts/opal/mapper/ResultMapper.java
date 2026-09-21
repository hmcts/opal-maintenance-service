package uk.gov.hmcts.opal.mapper;

import org.mapstruct.Mapper;
import org.mapstruct.ReportingPolicy;
import uk.gov.hmcts.opal.entity.ResultEntity;
import uk.gov.hmcts.opal.generated.model.ResultReferenceDataItem;

@Mapper(componentModel = "spring", unmappedTargetPolicy = ReportingPolicy.ERROR)
public interface ResultMapper {

    ResultReferenceDataItem toReferenceDataItem(ResultEntity result);
}
