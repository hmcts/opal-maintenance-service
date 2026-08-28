package uk.gov.hmcts.opal.controllers;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.List;
import org.jspecify.annotations.Nullable;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.NullSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import uk.gov.hmcts.opal.generated.model.CountryReferenceDataResponse;
import uk.gov.hmcts.opal.service.CountryService;

@ExtendWith(MockitoExtension.class)
@DisplayName("PO-10251 CountryApiController")
class CountryApiControllerTest {

    @Mock
    private CountryService service;

    @InjectMocks
    private CountryApiController controller;

    @ParameterizedTest(name = "PO-10251 delegates active={0} and returns 200")
    @NullSource
    @ValueSource(booleans = {true, false})
    void delegatesFilterAndReturnsOk(@Nullable Boolean active) {
        CountryReferenceDataResponse body = CountryReferenceDataResponse.builder()
            .count(0)
            .refData(List.of())
            .build();
        when(service.getCountries(active)).thenReturn(body);

        var response = controller.getCountries(active);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).isSameAs(body);
        verify(service).getCountries(active);
    }
}
