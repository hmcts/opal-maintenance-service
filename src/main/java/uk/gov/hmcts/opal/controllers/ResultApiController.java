package uk.gov.hmcts.opal.controllers;

import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RestController;
import uk.gov.hmcts.opal.generated.http.api.ResultApi;
import uk.gov.hmcts.opal.generated.model.ResultDetailResponse;
import uk.gov.hmcts.opal.service.ResultService;

@RestController
@RequiredArgsConstructor
public class ResultApiController implements ResultApi {

    private final ResultService service;

    @Override
    public ResponseEntity<ResultDetailResponse> getResult(String resultId) {
        return ResponseEntity.ok(service.getResult(resultId));
    }
}
