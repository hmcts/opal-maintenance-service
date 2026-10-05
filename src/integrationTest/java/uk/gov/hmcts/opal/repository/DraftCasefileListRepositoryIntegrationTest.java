package uk.gov.hmcts.opal.repository;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.MethodSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.jdbc.Sql;
import tools.jackson.databind.json.JsonMapper;
import tools.jackson.databind.node.ObjectNode;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.dto.DraftCasefileFilter;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.support.DraftCasefileSqlCaptureConfiguration;
import uk.gov.hmcts.opal.support.DraftCasefileSqlCaptureConfiguration.StatementCapture;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Locale;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.context.jdbc.Sql.ExecutionPhase.AFTER_TEST_METHOD;

@TestPropertySource(properties = {
    "spring.flyway.locations=classpath:db/migration/ddl",
    "opal.redis.enabled=false",
    "management.health.redis.enabled=false",
    "spring.jpa.open-in-view=false"
})
@Import(DraftCasefileSqlCaptureConfiguration.class)
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@Sql("/draft-casefile/list-fixtures.sql")
@Sql(scripts = "/draft-casefile/list-cleanup.sql", executionPhase = AFTER_TEST_METHOD)
class DraftCasefileListRepositoryIntegrationTest extends BaseIntegrationTest {
    @Autowired
    private DraftCasefileRepository repository;
    @Autowired
    private JdbcTemplate jdbc;
    @Autowired
    private StatementCapture capture;

    @ParameterizedTest
    @MethodSource("filters")
    void summariesAndCountsApplyIdenticalFilters(DraftCasefileFilter filter) {
        var summaries = repository.findSummaries(filter);
        assertThat(repository.countMatching(filter)).isEqualTo(summaries.size());
        assertThat(summaries).allSatisfy(row -> assertThat(row.getBusinessUnitId()).isEqualTo((short) 31021));
    }

    private static List<DraftCasefileFilter> filters() {
        return List.of(filter(null, null, List.of(), null, null),
            filter("BUU-1", null, List.of(), null, null),
            filter(null, "BUU-1", List.of(), null, null),
            filter("BUU-1", "BUU-1", List.of(), null, null),
            filter("UNKNOWN", null, List.of(), null, null),
            filter(null, null, List.of(DraftCasefileStatus.REJECTED), null, null),
            filter(null, null, List.of(DraftCasefileStatus.SUBMITTED, DraftCasefileStatus.RESUBMITTED), null, null),
            filter(null, null, List.of(), LocalDateTime.parse("2026-10-02T00:00:00"), null),
            filter(null, null, List.of(), null, LocalDateTime.parse("2026-10-02T00:00:00")));
    }

    private static DraftCasefileFilter filter(String submittedBy, String notSubmittedBy,
                                             List<DraftCasefileStatus> statuses,
                                             LocalDateTime from, LocalDateTime to) {
        return new DraftCasefileFilter((short) 31021, submittedBy, notSubmittedBy, statuses, from, to);
    }

    @Test
    void inclusiveUtcDayContainsBothEdgesAndExcludesNextMidnight() {
        var filter = filter(null, null, List.of(DraftCasefileStatus.SUBMITTED, DraftCasefileStatus.RESUBMITTED),
            LocalDateTime.parse("2026-10-01T00:00:00"), LocalDateTime.parse("2026-10-02T00:00:00"));
        assertThat(repository.findSummaries(filter)).extracting(DraftCasefileSummaryProjection::getDraftCasefileId)
            .containsExactly(910201L, 910202L);
        assertThat(repository.countMatching(filter)).isEqualTo(2);
    }

    @Test
    void oldRejectedAndContradictorySubmittersHaveNoImplicitRestriction() {
        var rejected = filter("BUU-1", null, List.of(DraftCasefileStatus.REJECTED), null, null);
        assertThat(repository.findSummaries(rejected)).extracting(DraftCasefileSummaryProjection::getDraftCasefileId)
            .containsExactly(910203L);
        assertThat(repository.countMatching(rejected)).isEqualTo(1);
        var contradictory = filter("BUU-1", "BUU-1", List.of(), null, null);
        assertThat(repository.findSummaries(contradictory)).isEmpty();
        assertThat(repository.countMatching(contradictory)).isZero();
    }

    @Test
    void countExecutesOneScalarSelectWithoutJsonInspectionOrSummaryColumns() {
        capture.clear();
        assertThat(repository.countMatching(filter(null, null, List.of(), null, null))).isEqualTo(6);
        assertThat(capture.draftSelects()).singleElement().satisfies(sql -> {
            String normalised = sql.toLowerCase(Locale.ROOT);
            assertThat(normalised).startsWith("select count(*)");
            assertThat(normalised).doesNotContain("casefile_snapshot", "timeline_data", "json_", "#>", "->",
                "submitted_by_name", "status_message", "validated_by", "version_number");
        });
    }

    @Test
    void summarySelectHasNoEntityOrCompleteJsonProjectionAndHasNativeScalarTypes() {
        capture.clear();
        var rows = repository.findSummaries(filter(null, null, List.of(), null, null));
        assertThat(rows).hasSize(6);
        assertThat(rows.getFirst().getCreatedDate()).isEqualTo(LocalDateTime.parse("2026-09-01T10:00:00"));
        assertThat(rows.getFirst().getCasefileType()).isEqualTo("REMO In");
        assertThat(rows.getFirst().getCasefileStatus()).isEqualTo("SUBMITTED");
        assertThat(capture.draftSelects()).singleElement().satisfies(sql -> {
            assertThat(sql).contains("casefile_snapshot");
            assertThat(sql).doesNotContain("d.*", "timeline_data", "status_message", "version_number", "json_",
                "#>", "->", "d.casefile as", "d.casefile,");
        });
    }

    @Test
    void acceptedEscapedZeroInEitherJsonAggregateDoesNotBreakProjection() {
        JsonMapper json = JsonMapper.builder().build();
        String stored = jdbc.queryForObject(
            "SELECT casefile::text FROM draft_casefiles WHERE draft_casefile_id = ?", String.class, 910201L);
        ObjectNode casefile = (ObjectNode) json.readTree(stored);
        ((ObjectNode) casefile.get("respondent_account")).put("account_comment", "Synthetic " + (char) 0);
        jdbc.update("UPDATE draft_casefiles SET casefile = ?::json WHERE draft_casefile_id = ?",
            json.writeValueAsString(casefile), 910201L);
        String snapshot = jdbc.queryForObject(
            "SELECT casefile_snapshot::text FROM draft_casefiles WHERE draft_casefile_id = ?", String.class, 910201L);
        ObjectNode changed = (ObjectNode) json.readTree(snapshot);
        ((ObjectNode) changed.get("respondent_account")).put("respondent_name", "Synthetic " + (char) 0);
        String encoded = json.writeValueAsString(changed);
        jdbc.update("UPDATE draft_casefiles SET casefile_snapshot = ?::json WHERE draft_casefile_id = ?",
            encoded, 910201L);
        var filter = filter(null, null, List.of(), null, null);
        assertThat(repository.findSummaries(filter)).hasSize(6);
        assertThat(repository.findSummaries(filter).getFirst().getCasefileSnapshot()).isEqualTo(encoded);
        assertThat(repository.countMatching(filter)).isEqualTo(6);
    }
}
