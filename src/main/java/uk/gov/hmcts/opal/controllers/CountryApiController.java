package uk.gov.hmcts.opal.controllers;

import lombok.RequiredArgsConstructor;
import org.jspecify.annotations.Nullable;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RestController;
import uk.gov.hmcts.opal.generated.http.api.CountryApi;
import uk.gov.hmcts.opal.generated.model.CountryReferenceDataResponse;
import uk.gov.hmcts.opal.service.CountryService;

@RestController
@RequiredArgsConstructor
public class CountryApiController implements CountryApi {

    private final CountryService countryService;

    @Override
    public ResponseEntity<CountryReferenceDataResponse> getCountries(@Nullable Boolean active) {
        return ResponseEntity.ok(countryService.getCountries(active));
    }
}
