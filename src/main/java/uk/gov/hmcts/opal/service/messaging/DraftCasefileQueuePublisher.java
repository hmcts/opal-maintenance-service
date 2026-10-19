package uk.gov.hmcts.opal.service.messaging;

public interface DraftCasefileQueuePublisher {
    void publish(Long draftCasefileId);
}
