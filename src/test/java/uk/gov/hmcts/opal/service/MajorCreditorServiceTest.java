package uk.gov.hmcts.opal.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.util.List;
import java.util.stream.Stream;
import org.jspecify.annotations.Nullable;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import uk.gov.hmcts.opal.entity.MajorCreditorEntity;
import uk.gov.hmcts.opal.generated.model.MajorCreditorReferenceDataItem;
import uk.gov.hmcts.opal.mapper.MajorCreditorMapper;
import uk.gov.hmcts.opal.repository.MajorCreditorRepository;

@ExtendWith(MockitoExtension.class)
@DisplayName("PO-10254 MajorCreditorService")
class MajorCreditorServiceTest {

    @Mock
    private MajorCreditorRepository repository;

    @Mock
    private MajorCreditorMapper mapper;

    @InjectMocks
    private MajorCreditorService service;

    @ParameterizedTest(name = "centralAuthority={0}, active={1}")
    @MethodSource("filterCombinations")
    void forwardsEveryFilterCombinationAndBuildsTheResponse(
        @Nullable Boolean centralAuthority,
        @Nullable Boolean active
    ) {
        MajorCreditorEntity entity = MajorCreditorEntity.builder().majorCreditorId(901L).build();
        MajorCreditorReferenceDataItem item = MajorCreditorReferenceDataItem.builder()
            .majorCreditorId(901L)
            .build();
        when(repository.findMajorCreditors((short) 77, centralAuthority, active))
            .thenReturn(List.of(entity));
        when(mapper.toReferenceDataItem(entity)).thenReturn(item);

        var response = service.getMajorCreditors((short) 77, centralAuthority, active);

        assertThat(response.getCount()).isEqualTo(1);
        assertThat(response.getRefData()).containsExactly(item);
        verify(repository).findMajorCreditors((short) 77, centralAuthority, active);
        verify(mapper).toReferenceDataItem(entity);
    }

    @Test
    void returnsZeroAndAnEmptyArray() {
        when(repository.findMajorCreditors((short) 77, null, null)).thenReturn(List.of());

        var response = service.getMajorCreditors((short) 77, null, null);

        assertThat(response.getCount()).isZero();
        assertThat(response.getRefData()).isEmpty();
        verifyNoInteractions(mapper);
    }

    private static Stream<Arguments> filterCombinations() {
        return Stream.<Boolean>of(null, false, true)
            .flatMap(centralAuthority -> Stream.<Boolean>of(null, false, true)
                .map(active -> Arguments.of(centralAuthority, active)));
    }
}
