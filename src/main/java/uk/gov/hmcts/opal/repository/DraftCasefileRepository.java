package uk.gov.hmcts.opal.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;

public interface DraftCasefileRepository extends JpaRepository<DraftCasefileEntity, Long> {
}
