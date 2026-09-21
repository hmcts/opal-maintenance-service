package uk.gov.hmcts.opal.mapper;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.mapstruct.factory.Mappers;
import uk.gov.hmcts.opal.entity.ResultEntity;

class ResultMapperTest {

    @Test
    void mapsResultCodeAndTitle() {
        var entity = ResultEntity.builder().resultId("ABC123")
            .resultTitle("Example Result").orderTerm(true).active(false).build();

        var item = Mappers.getMapper(ResultMapper.class).toReferenceDataItem(entity);

        assertThat(item.getResultId()).isEqualTo("ABC123");
        assertThat(item.getResultTitle()).isEqualTo("Example Result");
    }
}
