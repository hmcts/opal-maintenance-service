package uk.gov.hmcts.opal.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;

import java.util.List;

public interface DraftCasefileRepository extends JpaRepository<DraftCasefileEntity, Long> {

    @Query(value = """
        SELECT draft_casefile_id
          FROM draft_casefiles
         WHERE business_unit_id = :businessUnitId
           AND submitted_by = :submittedBy
           AND casefile #>> '{respondent_account,account_comment}' = :marker
         ORDER BY draft_casefile_id
        """, nativeQuery = true)
    List<Long> findTestingSupportIdsByMarker(
        @Param("businessUnitId") Short businessUnitId,
        @Param("submittedBy") String submittedBy,
        @Param("marker") String marker
    );
}
