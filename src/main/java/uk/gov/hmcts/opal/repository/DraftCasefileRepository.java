package uk.gov.hmcts.opal.repository;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;

import java.util.List;
import java.util.Optional;

public interface DraftCasefileRepository extends JpaRepository<DraftCasefileEntity, Long> {

    // Text extraction rejects escaped NUL anywhere in json. Replace it only for this read;
    // the replacement character cannot create a valid ASCII testing marker.
    @Query(value = """
        SELECT draft_casefile_id
          FROM draft_casefiles
         WHERE business_unit_id = :businessUnitId
           AND submitted_by = :submittedBy
           AND CAST(replace(CAST(casefile AS text), '\\u0000', '\\ufffd') AS json)
               #>> '{respondent_account,account_comment}' = :marker
         ORDER BY draft_casefile_id
        """, nativeQuery = true)
    List<Long> findTestingSupportIdsByMarker(
        @Param("businessUnitId") Short businessUnitId,
        @Param("submittedBy") String submittedBy,
        @Param("marker") String marker
    );

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select draft from DraftCasefileEntity draft where draft.draftCasefileId = :draftCasefileId")
    Optional<DraftCasefileEntity> findForCleanupById(@Param("draftCasefileId") Long draftCasefileId);
}
