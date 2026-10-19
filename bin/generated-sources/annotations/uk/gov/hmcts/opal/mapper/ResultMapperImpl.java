package uk.gov.hmcts.opal.mapper;

import javax.annotation.processing.Generated;
import org.springframework.stereotype.Component;
import uk.gov.hmcts.opal.entity.ResultEntity;
import uk.gov.hmcts.opal.generated.model.ResultDetailResponse;
import uk.gov.hmcts.opal.generated.model.ResultReferenceDataItem;

@Generated(
    value = "org.mapstruct.ap.MappingProcessor",
    date = "2026-10-16T10:42:44+0100",
    comments = "version: 1.6.3, compiler: Eclipse JDT (IDE) 3.46.200.v20260930-0211, environment: Java 25.0.4.1 (Eclipse Adoptium)"
)
@Component
public class ResultMapperImpl implements ResultMapper {

    @Override
    public ResultDetailResponse toDetailResponse(ResultEntity result) {
        if ( result == null ) {
            return null;
        }

        ResultDetailResponse.Builder resultDetailResponse = ResultDetailResponse.builder();

        resultDetailResponse.resultId( result.getResultId() );
        resultDetailResponse.resultTitle( result.getResultTitle() );
        resultDetailResponse.resultParameters( mapToJsonNullable( result.getResultParameters() ) );

        return resultDetailResponse.build();
    }

    @Override
    public ResultReferenceDataItem toReferenceDataItem(ResultEntity result) {
        if ( result == null ) {
            return null;
        }

        ResultReferenceDataItem.Builder resultReferenceDataItem = ResultReferenceDataItem.builder();

        resultReferenceDataItem.resultId( result.getResultId() );
        resultReferenceDataItem.resultTitle( result.getResultTitle() );

        return resultReferenceDataItem.build();
    }
}
