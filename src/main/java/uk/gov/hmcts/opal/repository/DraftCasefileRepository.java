package uk.gov.hmcts.opal.repository;

import jakarta.persistence.LockModeType;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import uk.gov.hmcts.opal.dto.DraftCasefileFilter;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity_;
import uk.gov.hmcts.opal.repository.jpa.DraftCasefileSpecs;

import java.util.List;
import java.util.Optional;

public interface DraftCasefileRepository extends JpaRepository<DraftCasefileEntity, Long>,
    JpaSpecificationExecutor<DraftCasefileEntity> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select draft from DraftCasefileEntity draft where draft.draftCasefileId = :draftCasefileId")
    Optional<DraftCasefileEntity> findForCleanupById(@Param("draftCasefileId") Long draftCasefileId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select draft from DraftCasefileEntity draft where draft.draftCasefileId = :draftCasefileId")
    Optional<DraftCasefileEntity> findForPublicationById(@Param("draftCasefileId") Long draftCasefileId);

    default List<DraftCasefileSummaryProjection> findSummaries(DraftCasefileFilter filter) {
        return findBy(DraftCasefileSpecs.matches(filter), query -> query
            .as(DraftCasefileSummaryProjection.class)
            .sortBy(Sort.by(DraftCasefileEntity_.DRAFT_CASEFILE_ID))
            .all());
    }

    default long countMatching(DraftCasefileFilter filter) {
        return count(DraftCasefileSpecs.matches(filter));
    }
}
