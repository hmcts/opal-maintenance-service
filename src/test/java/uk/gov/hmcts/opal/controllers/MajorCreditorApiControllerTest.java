package uk.gov.hmcts.opal.controllers;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.List;
import java.util.stream.Stream;
import org.jspecify.annotations.Nullable;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import uk.gov.hmcts.opal.generated.model.MajorCreditorReferenceDataResponse;
import uk.gov.hmcts.opal.service.MajorCreditorService;

@ExtendWith(MockitoExtension.class)
@DisplayName("PO-10254 MajorCreditorApiController")
class MajorCreditorApiControllerTest {

    @Mock private MajorCreditorService service;
    @InjectMocks private MajorCreditorApiController controller;

    @ParameterizedTest(name = "centralAuthority={0}, active={1}")
    @MethodSource("filterCombinations")
    void delegatesAllParametersAndReturnsOk(
        @Nullable Boolean centralAuthority,
        @Nullable Boolean active
    ) {
        MajorCreditorReferenceDataResponse body = MajorCreditorReferenceDataResponse.builder()
            .count(0)
            .refData(List.of())
            .build();
        when(service.getMajorCreditors((short) 77, centralAuthority, active)).thenReturn(body);

        var response = controller.getMajorCreditors((short) 77, centralAuthority, active);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).isSameAs(body);
        verify(service).getMajorCreditors((short) 77, centralAuthority, active);
    }

    private static Stream<Arguments> filterCombinations() {
        return Stream.<Boolean>of(null, false, true)
            .flatMap(centralAuthority -> Stream.<Boolean>of(null, false, true)
                .map(active -> Arguments.of(centralAuthority, active)));
    }
}
