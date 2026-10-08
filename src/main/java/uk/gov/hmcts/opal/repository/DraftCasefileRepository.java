package uk.gov.hmcts.opal.repository;

import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import uk.gov.hmcts.opal.dto.DraftCasefileFilter;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity_;
import uk.gov.hmcts.opal.repository.jpa.DraftCasefileSpecs;

import java.util.List;

public interface DraftCasefileRepository extends JpaRepository<DraftCasefileEntity, Long>,
    JpaSpecificationExecutor<DraftCasefileEntity> {

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
