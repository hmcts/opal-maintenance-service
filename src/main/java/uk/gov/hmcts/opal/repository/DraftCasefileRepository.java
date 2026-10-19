package uk.gov.hmcts.opal.repository;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;

import java.util.Optional;

public interface DraftCasefileRepository extends JpaRepository<DraftCasefileEntity, Long> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select draft from DraftCasefileEntity draft where draft.draftCasefileId = :draftCasefileId")
    Optional<DraftCasefileEntity> findForCleanupById(@Param("draftCasefileId") Long draftCasefileId);
}
