package uk.gov.hmcts.opal.repository;

import java.util.List;
import org.jspecify.annotations.Nullable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import uk.gov.hmcts.opal.entity.ResultEntity;

@Repository
public interface ResultRepository extends JpaRepository<ResultEntity, String> {

    @Query("""
        SELECT result
        FROM ResultEntity result
        WHERE (:orderTerm IS NULL OR result.orderTerm = :orderTerm)
          AND (:active IS NULL OR result.active = :active)
        ORDER BY result.resultTitle ASC, result.resultId ASC
        """)
    List<ResultEntity> findResults(
        @Param("orderTerm") @Nullable Boolean orderTerm,
        @Param("active") @Nullable Boolean active
    );
}
