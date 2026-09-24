package uk.gov.hmcts.opal.controllers;

import lombok.RequiredArgsConstructor;
import org.jspecify.annotations.Nullable;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RestController;
import uk.gov.hmcts.opal.generated.http.api.MaintenanceApplicationApi;
import uk.gov.hmcts.opal.generated.model.MaintenanceApplicationReferenceDataResponse;
import uk.gov.hmcts.opal.service.MaintenanceApplicationService;

@RestController
@RequiredArgsConstructor
public class MaintenanceApplicationApiController implements MaintenanceApplicationApi {

    private final MaintenanceApplicationService service;

    @Override
    public ResponseEntity<MaintenanceApplicationReferenceDataResponse> getMaintenanceApplications(
        String applicationGroup, @Nullable Boolean active
    ) {
        return ResponseEntity.ok(service.getMaintenanceApplications(applicationGroup, active));
    }
}
