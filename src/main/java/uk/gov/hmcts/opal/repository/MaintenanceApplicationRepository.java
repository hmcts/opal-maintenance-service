package uk.gov.hmcts.opal.repository;

import java.util.List;
import org.jspecify.annotations.Nullable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import uk.gov.hmcts.opal.entity.MaintenanceApplicationEntity;

@Repository
public interface MaintenanceApplicationRepository extends JpaRepository<MaintenanceApplicationEntity, Short> {

    @Query("""
        SELECT application
        FROM MaintenanceApplicationEntity application
        WHERE application.applicationGroup = :applicationGroup
          AND (:active IS NULL OR application.active = :active)
        ORDER BY application.applicationTitle ASC, application.applicationId ASC
        """)
    List<MaintenanceApplicationEntity> findMaintenanceApplications(
        @Param("applicationGroup") String applicationGroup,
        @Param("active") @Nullable Boolean active
    );
}
