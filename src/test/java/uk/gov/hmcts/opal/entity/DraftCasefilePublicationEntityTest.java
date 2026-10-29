package uk.gov.hmcts.opal.entity;

import org.junit.jupiter.api.Test;

import java.time.LocalDateTime;

import static org.assertj.core.api.Assertions.assertThat;

class DraftCasefilePublicationEntityTest {
    private static final LocalDateTime NOW = LocalDateTime.of(2026, 10, 22, 12, 0);

    @Test
    void publicationPreservesApprovalAndTimeline() {
        var original = draft();
        var updated = original.toBuilder().build();
        updated.markPublished(123L, "00123A", "{\"published\":true}", NOW);
        assertThat(updated).usingRecursiveComparison().ignoringFields("accountId", "accountNumber",
            "casefileSnapshot", "casefileStatus", "casefileStatusDate", "statusMessage").isEqualTo(original);
        assertThat(updated.getCasefileStatus()).isEqualTo(DraftCasefileStatus.PUBLISHED);
        assertThat(updated.getAccountId()).isEqualTo(123L);
        assertThat(updated.getAccountNumber()).isEqualTo("00123A");
        assertThat(updated.getStatusMessage()).isNull();
    }

    @Test
    void failurePreservesSnapshotApprovalAndTimeline() {
        var original = draft();
        var updated = original.toBuilder().build();
        updated.markPublishingFailed("Publication failed; contact support", NOW);
        assertThat(updated).usingRecursiveComparison()
            .ignoringFields("casefileStatus", "casefileStatusDate", "statusMessage").isEqualTo(original);
        assertThat(updated.getCasefileStatus()).isEqualTo(DraftCasefileStatus.PUBLISHING_FAILED);
        assertThat(updated.getCasefileStatusDate()).isEqualTo(NOW);
    }

    private DraftCasefileEntity draft() {
        return DraftCasefileEntity.builder().draftCasefileId(42L).casefile("{\"synthetic\":true}")
            .casefileSnapshot("{\"name\":\"Synthetic\"}").timelineData("[]").validatedBy("BU-CHECKER")
            .validatedByName("Synthetic checker").validatedDate(NOW.minusDays(1)).submittedBy("BU-SUBMITTER")
            .casefileStatus(DraftCasefileStatus.PUBLISHING_PENDING).versionNumber(1L).statusMessage("Old").build();
    }
}
