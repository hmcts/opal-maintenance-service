package uk.gov.hmcts.reform.opal.controllers;

import lombok.RequiredArgsConstructor;
import org.jspecify.annotations.Nullable;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RestController;
import uk.gov.hmcts.opal.generated.http.api.CountryApi;
import uk.gov.hmcts.opal.generated.model.CountryReferenceDataResponse;
import uk.gov.hmcts.reform.opal.service.CountryService;

@RestController
@RequiredArgsConstructor
public class CountryApiController implements CountryApi {

    private final CountryService service;

    @Override
    public ResponseEntity<CountryReferenceDataResponse> getCountries(@Nullable Boolean active) {
        return ResponseEntity.ok(service.getCountries(active));
    }
}
