package uk.gov.hmcts.opal.controllers;

import lombok.RequiredArgsConstructor;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RestController;
import uk.gov.hmcts.opal.generated.http.api.TestingSupportApi;
import uk.gov.hmcts.opal.service.DraftCasefileCleanupService;

@RestController
@RequiredArgsConstructor
@ConditionalOnProperty(prefix = "opal.testing-support-endpoints",
    name = {"enabled", "draft-casefile-cleanup.enabled"}, havingValue = "true")
public class TestingSupportDraftCasefileController implements TestingSupportApi {

    private final DraftCasefileCleanupService service;

    @Override
    public ResponseEntity<Void> cleanupDraftCasefile(Long draftCasefileId, String testRunReference) {
        service.cleanup(draftCasefileId, testRunReference);
        return ResponseEntity.noContent().build();
    }
}
