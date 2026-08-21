package uk.gov.hmcts.reform.opal.controllers;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/testing-support")
@ConditionalOnProperty(prefix = "opal.testing-support-endpoints", name = "enabled", havingValue = "true")
public class TestingSupportController {

    @GetMapping("/ping")
    public ResponseEntity<PingResponse> ping() {
        return ResponseEntity.ok(new PingResponse("ok"));
    }

    public record PingResponse(String status) {
    }
}
