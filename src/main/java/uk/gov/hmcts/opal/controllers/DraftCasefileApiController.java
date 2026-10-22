package uk.gov.hmcts.opal.controllers;

import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RestController;
import uk.gov.hmcts.opal.dto.VersionedResponse;
import uk.gov.hmcts.opal.generated.http.api.DraftCasefileApi;
import uk.gov.hmcts.opal.generated.model.DraftCasefileAddRequest;
import uk.gov.hmcts.opal.generated.model.DraftCasefileAddResponse;
import uk.gov.hmcts.opal.generated.model.DraftCasefileGetResponse;
import uk.gov.hmcts.opal.service.DraftCasefileService;
import uk.gov.hmcts.opal.validator.OpenApiRequest;

@RestController
@RequiredArgsConstructor
public class DraftCasefileApiController implements DraftCasefileApi {

    private final DraftCasefileService service;

    @Override
    @OpenApiRequest("DraftCasefileAddRequest")
    public ResponseEntity<DraftCasefileAddResponse> addDraftCasefile(DraftCasefileAddRequest request) {
        VersionedResponse<DraftCasefileAddResponse> versionedResponse = service.addDraftCasefile(request);
        return ResponseEntity.status(HttpStatus.CREATED)
            .eTag(Long.toString(versionedResponse.version()))
            .body(versionedResponse.response());
    }

    @Override
    public ResponseEntity<DraftCasefileGetResponse> getDraftCasefile(Long id) {
        VersionedResponse<DraftCasefileGetResponse> versionedResponse = service.getDraftCasefile(id);
        return ResponseEntity.ok().eTag(Long.toString(versionedResponse.version())).body(versionedResponse.response());
    }
}
