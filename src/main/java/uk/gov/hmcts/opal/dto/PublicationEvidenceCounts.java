package uk.gov.hmcts.opal.dto;

public record PublicationEvidenceCounts(long sendAttemptCount, long acknowledgedSendCount,
                                        long uncertainSendCount, long unfinishedSendCount) {

    public boolean evidenceComplete() {
        return uncertainSendCount == 0 && unfinishedSendCount == 0;
    }
}
