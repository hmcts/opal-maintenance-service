package uk.gov.hmcts.opal.repository;

import java.util.List;
import org.jspecify.annotations.Nullable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import uk.gov.hmcts.opal.entity.MajorCreditorEntity;

@Repository
public interface MajorCreditorRepository extends JpaRepository<MajorCreditorEntity, Long> {

    @Query("""
        SELECT majorCreditor
        FROM MajorCreditorEntity majorCreditor
        LEFT JOIN FETCH majorCreditor.country
        WHERE majorCreditor.businessUnitId = :businessUnitId
          AND (:centralAuthority IS NULL OR majorCreditor.centralAuthority = :centralAuthority)
          AND (:active IS NULL OR majorCreditor.active = :active)
        ORDER BY majorCreditor.name ASC, majorCreditor.majorCreditorId ASC
        """)
    List<MajorCreditorEntity> findMajorCreditors(
        @Param("businessUnitId") Short businessUnitId,
        @Param("centralAuthority") @Nullable Boolean centralAuthority,
        @Param("active") @Nullable Boolean active
    );
}
