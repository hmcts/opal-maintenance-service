package uk.gov.hmcts.opal.controllers;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RestController;
import uk.gov.hmcts.opal.dto.VersionedResponse;
import uk.gov.hmcts.opal.generated.http.api.DraftCasefileApi;
import uk.gov.hmcts.opal.generated.model.DraftCasefileAddRequest;
import uk.gov.hmcts.opal.generated.model.DraftCasefileAddResponse;
import uk.gov.hmcts.opal.generated.model.DraftCasefileGetResponse;
import uk.gov.hmcts.opal.generated.model.DraftCasefileLifecycleStatus;
import uk.gov.hmcts.opal.generated.model.DraftCasefileListResponse;
import uk.gov.hmcts.opal.service.DraftCasefileService;
import uk.gov.hmcts.opal.validator.OpenApiRequest;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequiredArgsConstructor
@Slf4j(topic = "opal.DraftCasefileApiController")
public class DraftCasefileApiController implements DraftCasefileApi {

    private final DraftCasefileService service;

    @Override
    @OpenApiRequest("DraftCasefileAddRequest")
    public ResponseEntity<DraftCasefileAddResponse> addDraftCasefile(DraftCasefileAddRequest request) {
        log.debug(":POST:addDraftCasefile: businessUnitId={}", request.getBusinessUnitId());
        VersionedResponse<DraftCasefileAddResponse> versionedResponse = service.addDraftCasefile(request);
        return ResponseEntity.status(HttpStatus.CREATED)
            .eTag(Long.toString(versionedResponse.version()))
            .body(versionedResponse.response());
    }

    @Override
    public ResponseEntity<DraftCasefileGetResponse> getDraftCasefile(Long id) {
        log.debug(":GET:getDraftCasefile: draftCasefileId={}", id);
        VersionedResponse<DraftCasefileGetResponse> versionedResponse = service.getDraftCasefile(id);
        return ResponseEntity.ok().eTag(Long.toString(versionedResponse.version())).body(versionedResponse.response());
    }

    @Override
    public ResponseEntity<DraftCasefileListResponse> getDraftCasefiles(
        Short businessUnitId, String submittedBy, String notSubmittedBy,
        List<DraftCasefileLifecycleStatus> casefileStatus, LocalDate casefileStatusFromDate,
        LocalDate casefileStatusToDate, String restrict
    ) {
        log.debug(":GET:getDraftCasefiles: businessUnitId={}", businessUnitId);
        return ResponseEntity.ok(service.listDraftCasefiles(businessUnitId, submittedBy, notSubmittedBy,
            casefileStatus, casefileStatusFromDate, casefileStatusToDate, restrict));
    }
}
