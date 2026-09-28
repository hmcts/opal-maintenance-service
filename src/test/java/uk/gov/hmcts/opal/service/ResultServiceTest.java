package uk.gov.hmcts.opal.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import jakarta.persistence.EntityNotFoundException;
import java.util.List;
import java.util.Optional;
import java.util.stream.Stream;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;
import org.mapstruct.factory.Mappers;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import uk.gov.hmcts.opal.entity.ResultEntity;
import uk.gov.hmcts.opal.generated.model.ResultReferenceDataItem;
import uk.gov.hmcts.opal.mapper.ResultMapper;
import uk.gov.hmcts.opal.repository.ResultRepository;

@ExtendWith(MockitoExtension.class)
class ResultServiceTest {

    @Mock
    private ResultRepository repository;
    private ResultService service;

    @BeforeEach
    void setUp() {
        service = new ResultService(repository, Mappers.getMapper(ResultMapper.class));
    }

    static Stream<Arguments> filters() {
        return Stream.of((Boolean) null, Boolean.TRUE, Boolean.FALSE)
            .flatMap(orderTerm -> Stream.of((Boolean) null, Boolean.TRUE, Boolean.FALSE)
                .map(active -> Arguments.of(orderTerm, active)));
    }

    @ParameterizedTest
    @MethodSource("filters")
    void preservesFiltersAndRepositoryOrder(Boolean orderTerm, Boolean active) {
        ResultEntity first = ResultEntity.builder().resultId("AA0001")
            .resultTitle("Alpha").orderTerm(true).active(true).build();
        ResultEntity second = ResultEntity.builder().resultId("ZZ0001")
            .resultTitle("Zulu").orderTerm(false).active(false).build();
        when(repository.findResults(orderTerm, active)).thenReturn(List.of(first, second));

        var response = service.getResults(orderTerm, active);

        assertThat(response.getCount()).isEqualTo(2);
        assertThat(response.getRefData()).extracting(ResultReferenceDataItem::getResultId)
            .containsExactly("AA0001", "ZZ0001");
        verify(repository).findResults(orderTerm, active);
    }

    @Test
    void returnsEmptyList() {
        when(repository.findResults(null, null)).thenReturn(List.of());

        var response = service.getResults(null, null);

        assertThat(response.getCount()).isZero();
        assertThat(response.getRefData()).isEmpty();
    }

    @Test
    void propagatesRepositoryFailure() {
        var failure = new IllegalStateException("Synthetic repository failure");
        when(repository.findResults(null, null)).thenThrow(failure);

        assertThatThrownBy(() -> service.getResults(null, null)).isSameAs(failure);
    }

    @Test
    void returnsInactiveNonOrderResultWithoutChangingMetadata() {
        String metadata = "[{\"name\":\"reason\",\"type\":\"text\"}]";
        when(repository.findById("ABC123")).thenReturn(Optional.of(ResultEntity.builder()
            .resultId("ABC123").resultTitle("Example").active(false).orderTerm(false)
            .resultParameters(metadata).build()));

        var response = service.getResult("ABC123");

        assertThat(response.getResultId()).isEqualTo("ABC123");
        assertThat(response.getResultTitle()).isEqualTo("Example");
        assertThat(response.getResultParameters().get()).isEqualTo(metadata);
        verify(repository).findById("ABC123");
    }

    @Test
    void rejectsMissingResult() {
        when(repository.findById("ABSENT")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.getResult("ABSENT"))
            .isInstanceOf(EntityNotFoundException.class).hasMessage("Result not found");
    }
}
