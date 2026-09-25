package uk.gov.hmcts.opal.controllers;

import lombok.RequiredArgsConstructor;
import org.jspecify.annotations.Nullable;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RestController;
import uk.gov.hmcts.opal.generated.http.api.MajorCreditorApi;
import uk.gov.hmcts.opal.generated.model.MajorCreditorReferenceDataResponse;
import uk.gov.hmcts.opal.service.MajorCreditorService;

@RestController
@RequiredArgsConstructor
public class MajorCreditorApiController implements MajorCreditorApi {

    private final MajorCreditorService majorCreditorService;

    @Override
    public ResponseEntity<MajorCreditorReferenceDataResponse> getMajorCreditors(
        Short businessUnitId,
        @Nullable Boolean centralAuthority,
        @Nullable Boolean active
    ) {
        return ResponseEntity.ok(
            majorCreditorService.getMajorCreditors(businessUnitId, centralAuthority, active)
        );
    }
}
