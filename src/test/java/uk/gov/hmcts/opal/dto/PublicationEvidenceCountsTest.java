package uk.gov.hmcts.opal.dto;

import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

import static org.assertj.core.api.Assertions.assertThat;

class PublicationEvidenceCountsTest {

    @ParameterizedTest
    @CsvSource({"0, 0, true", "1, 0, false", "0, 1, false", "1, 1, false"})
    void completenessRequiresNoUncertainOrUnfinishedAttempts(long uncertain, long unfinished, boolean complete) {
        assertThat(new PublicationEvidenceCounts(uncertain + unfinished, 0, uncertain, unfinished).evidenceComplete())
            .isEqualTo(complete);
    }
}
