package uk.gov.hmcts.opal.controllers;

import lombok.RequiredArgsConstructor;
import org.jspecify.annotations.Nullable;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RestController;
import uk.gov.hmcts.opal.generated.http.api.ResultsApi;
import uk.gov.hmcts.opal.generated.model.ResultReferenceDataResponse;
import uk.gov.hmcts.opal.service.ResultService;

@RestController
@RequiredArgsConstructor
public class ResultsApiController implements ResultsApi {

    private final ResultService service;

    @Override
    public ResponseEntity<ResultReferenceDataResponse> getResults(
        @Nullable Boolean orderTerm, @Nullable Boolean active
    ) {
        return ResponseEntity.ok(service.getResults(orderTerm, active));
    }
}
