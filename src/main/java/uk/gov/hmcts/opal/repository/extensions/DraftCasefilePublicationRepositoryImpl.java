package uk.gov.hmcts.opal.repository.extensions;

import jakarta.persistence.EntityManager;
import jakarta.persistence.LockModeType;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.SqlOutParameter;
import org.springframework.jdbc.core.SqlParameter;
import org.springframework.stereotype.Repository;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;

import java.sql.Types;
import java.util.List;

@Repository
@RequiredArgsConstructor
public class DraftCasefilePublicationRepositoryImpl implements DraftCasefilePublicationRepository {

    private final EntityManager entityManager;
    private final JdbcTemplate jdbcTemplate;

    @Override
    public PublicationResult publish(Long draftCasefileId) {
        // PostgreSQL JSON OUT requires OTHER; standard JPA String registration uses VARCHAR.
        var result = jdbcTemplate.call(connection -> {
            var call = connection.prepareCall("call public.p_process_draft_casefiles(?, ?, ?, ?)");
            call.setLong(1, draftCasefileId);
            call.registerOutParameter(2, Types.BIGINT);
            call.registerOutParameter(3, Types.VARCHAR);
            call.registerOutParameter(4, Types.OTHER);
            return call;
        }, List.of(new SqlParameter("draftId", Types.BIGINT),
            new SqlOutParameter("respondentId", Types.BIGINT),
            new SqlOutParameter("accountNumber", Types.VARCHAR),
            new SqlOutParameter("publishedAccounts", Types.OTHER)));
        Object accounts = result.get("publishedAccounts");
        return new PublicationResult((Long) result.get("respondentId"),
            (String) result.get("accountNumber"), accounts == null ? null : accounts.toString());
    }

    @Override
    public void initialiseLegacyVersion(DraftCasefileEntity managedDraft) {
        if (!entityManager.contains(managedDraft)
            || entityManager.getLockMode(managedDraft) != LockModeType.PESSIMISTIC_WRITE) {
            throw new IllegalStateException("Publication requires a locked managed draft");
        }
        if (managedDraft.getVersionNumber() != null) {
            return;
        }
        // Hibernate cannot increment a null @Version. Initialise only the locked, unchanged legacy row.
        int updated = entityManager.createNativeQuery("""
            UPDATE draft_casefiles SET version_number=0
            WHERE draft_casefile_id=:id AND version_number IS NULL
              AND casefile_status='PUBLISHING_PENDING' AND account_id IS NULL AND account_number IS NULL
            """).setParameter("id", managedDraft.getDraftCasefileId()).executeUpdate();
        if (updated != 1) {
            throw new IllegalStateException("Publication version initialisation refused");
        }
        entityManager.refresh(managedDraft, LockModeType.PESSIMISTIC_WRITE);
    }
}
