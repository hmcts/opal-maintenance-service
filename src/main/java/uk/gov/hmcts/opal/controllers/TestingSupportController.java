package uk.gov.hmcts.opal.controllers;

import lombok.RequiredArgsConstructor;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import uk.gov.hmcts.opal.dto.TestingSupportDraftCasefileMatches;
import uk.gov.hmcts.opal.dto.TestingSupportDraftCasefileMetadata;
import uk.gov.hmcts.opal.service.TestingSupportDraftCasefileService;

@RestController
@RequestMapping("/testing-support")
@ConditionalOnProperty(prefix = "opal.testing-support-endpoints", name = "enabled", havingValue = "true")
@RequiredArgsConstructor
public class TestingSupportController {

    private final TestingSupportDraftCasefileService draftCasefiles;

    @GetMapping("/ping")
    public ResponseEntity<PingResponse> ping() {
        return ResponseEntity.ok(new PingResponse("ok"));
    }

    @GetMapping("/draft-casefiles/{id}")
    public ResponseEntity<TestingSupportDraftCasefileMetadata> inspect(@PathVariable Long id) {
        return ResponseEntity.ok(draftCasefiles.inspect(id));
    }

    @GetMapping("/draft-casefiles/markers/{marker}")
    public ResponseEntity<TestingSupportDraftCasefileMatches> findByMarker(@PathVariable String marker) {
        return ResponseEntity.ok(draftCasefiles.findByMarker(marker));
    }

    @DeleteMapping("/draft-casefiles/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        draftCasefiles.delete(id);
        return ResponseEntity.noContent().build();
    }

    public record PingResponse(String status) {
    }
}
