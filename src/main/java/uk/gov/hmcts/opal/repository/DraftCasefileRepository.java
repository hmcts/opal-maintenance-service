package uk.gov.hmcts.opal.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import uk.gov.hmcts.opal.dto.DraftCasefileFilter;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;

import java.time.LocalDateTime;
import java.util.List;

public interface DraftCasefileRepository extends JpaRepository<DraftCasefileEntity, Long> {

    String FILTER_SQL = """
        FROM draft_casefiles d
        WHERE d.business_unit_id = :businessUnitId
          AND (CAST(:submittedBy AS varchar) IS NULL OR d.submitted_by = :submittedBy)
          AND (CAST(:notSubmittedBy AS varchar) IS NULL OR d.submitted_by <> :notSubmittedBy)
          AND (:allStatuses OR d.casefile_status::text IN (:statuses))
          AND (CAST(:fromInclusive AS timestamp) IS NULL OR d.casefile_status_date >= :fromInclusive)
          AND (CAST(:toExclusive AS timestamp) IS NULL OR d.casefile_status_date < :toExclusive)
        """;

    String SUMMARY_SELECT_SQL = """
        SELECT d.draft_casefile_id AS "draftCasefileId",
               d.business_unit_id AS "businessUnitId",
               d.created_date AS "createdDate",
               d.submitted_by AS "submittedBy",
               d.submitted_by_name AS "submittedByName",
               d.validated_date AS "validatedDate",
               d.casefile_snapshot::text AS "casefileSnapshot",
               d.casefile_type::text AS "casefileType",
               d.casefile_status::text AS "casefileStatus",
               d.casefile_status_date AS "casefileStatusDate"
        """;

    @Query(value = SUMMARY_SELECT_SQL + FILTER_SQL + " ORDER BY d.draft_casefile_id ASC", nativeQuery = true)
    List<DraftCasefileSummaryProjection> findSummaries(
        @Param("businessUnitId") Short businessUnitId,
        @Param("submittedBy") String submittedBy,
        @Param("notSubmittedBy") String notSubmittedBy,
        @Param("allStatuses") boolean allStatuses,
        @Param("statuses") List<String> statuses,
        @Param("fromInclusive") LocalDateTime fromInclusive,
        @Param("toExclusive") LocalDateTime toExclusive);

    default List<DraftCasefileSummaryProjection> findSummaries(DraftCasefileFilter filter) {
        return findSummaries(filter.businessUnitId(), filter.submittedBy(), filter.notSubmittedBy(),
            filter.statuses().isEmpty(), statusCodes(filter), filter.fromInclusive(), filter.toExclusive());
    }

    @Query(value = "SELECT COUNT(*) " + FILTER_SQL, nativeQuery = true)
    long countMatching(
        @Param("businessUnitId") Short businessUnitId,
        @Param("submittedBy") String submittedBy,
        @Param("notSubmittedBy") String notSubmittedBy,
        @Param("allStatuses") boolean allStatuses,
        @Param("statuses") List<String> statuses,
        @Param("fromInclusive") LocalDateTime fromInclusive,
        @Param("toExclusive") LocalDateTime toExclusive);

    default long countMatching(DraftCasefileFilter filter) {
        return countMatching(filter.businessUnitId(), filter.submittedBy(), filter.notSubmittedBy(),
            filter.statuses().isEmpty(), statusCodes(filter), filter.fromInclusive(), filter.toExclusive());
    }

    private static List<String> statusCodes(DraftCasefileFilter filter) {
        return filter.statuses().isEmpty() ? List.of("") : filter.statuses().stream().map(Enum::name).toList();
    }
}
