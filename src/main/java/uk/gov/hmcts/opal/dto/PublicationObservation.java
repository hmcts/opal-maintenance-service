package uk.gov.hmcts.opal.dto;

import java.time.Instant;
import java.util.UUID;

public record PublicationObservation(UUID observationId, Long draftCasefileId,
                                    String testRunReference, Instant registeredAt) {
}
