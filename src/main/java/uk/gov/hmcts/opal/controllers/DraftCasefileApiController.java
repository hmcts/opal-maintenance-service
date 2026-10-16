package uk.gov.hmcts.opal.controllers;

import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RestController;
import uk.gov.hmcts.opal.dto.DraftCasefileSubmission;
import uk.gov.hmcts.opal.generated.http.api.DraftCasefileApi;
import uk.gov.hmcts.opal.generated.model.DraftCasefileAddRequest;
import uk.gov.hmcts.opal.generated.model.DraftCasefileAddResponse;
import uk.gov.hmcts.opal.service.DraftCasefileService;
import uk.gov.hmcts.opal.testing.DraftCasefileFailureMode;
import uk.gov.hmcts.opal.testing.DraftCasefileTestingFailure;
import uk.gov.hmcts.opal.validator.OpenApiRequest;

@RestController
@RequiredArgsConstructor
public class DraftCasefileApiController implements DraftCasefileApi {

    private final DraftCasefileService service;
    private final DraftCasefileTestingFailure testingFailure;

    @Override
    @OpenApiRequest("DraftCasefileAddRequest")
    public ResponseEntity<DraftCasefileAddResponse> addDraftCasefile(
        String xOpalTestingFailure,
        DraftCasefileAddRequest request
    ) {
        DraftCasefileFailureMode failureMode = testingFailure.resolve(xOpalTestingFailure);
        DraftCasefileSubmission submission = service.addDraftCasefile(request, failureMode);
        return ResponseEntity.status(HttpStatus.CREATED)
            .eTag(Long.toString(submission.version()))
            .body(submission.response());
    }
}
