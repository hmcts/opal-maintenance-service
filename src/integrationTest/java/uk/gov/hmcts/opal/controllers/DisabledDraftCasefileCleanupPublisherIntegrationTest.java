package uk.gov.hmcts.opal.controllers;

import org.springframework.test.context.TestPropertySource;

@TestPropertySource(properties = "opal.testing-support-endpoints.enabled=false")
class DisabledDraftCasefileCleanupPublisherIntegrationTest extends DraftCasefileCleanupPublisherIntegrationTest {
}
