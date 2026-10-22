package uk.gov.hmcts.opal.controllers;

import lombok.RequiredArgsConstructor;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RestController;
import uk.gov.hmcts.opal.dto.RegisteredPublicationEvidence;
import uk.gov.hmcts.opal.generated.http.api.TestingSupportApi;
import uk.gov.hmcts.opal.generated.model.TestingSupportPublicationEvidence;
import uk.gov.hmcts.opal.service.DraftCasefileCleanupService;
import uk.gov.hmcts.opal.service.PublicationEvidenceService;

@RestController
@RequiredArgsConstructor
@ConditionalOnProperty(prefix = "opal.testing-support-endpoints",
    name = "enabled", havingValue = "true")
public class TestingSupportDraftCasefileController implements TestingSupportApi {

    private final DraftCasefileCleanupService service;
    private final PublicationEvidenceService evidence;

    @Override
    public ResponseEntity<Void> cleanupDraftCasefile(Long draftCasefileId, String testRunReference) {
        service.cleanup(draftCasefileId, testRunReference);
        return ResponseEntity.noContent().build();
    }

    @Override
    public ResponseEntity<TestingSupportPublicationEvidence> registerPublicationEvidence(
        Long draftCasefileId, String testRunReference) {
        RegisteredPublicationEvidence registered = evidence.register(draftCasefileId, testRunReference);
        return ResponseEntity.status(registered.created() ? HttpStatus.CREATED : HttpStatus.OK)
            .body(registered.evidence());
    }

    @Override
    public ResponseEntity<TestingSupportPublicationEvidence> getPublicationEvidence(
        Long draftCasefileId, String testRunReference) {
        return ResponseEntity.ok(evidence.read(draftCasefileId, testRunReference));
    }
}
