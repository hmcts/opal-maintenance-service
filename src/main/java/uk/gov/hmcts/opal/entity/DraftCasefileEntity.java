package uk.gov.hmcts.opal.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.SequenceGenerator;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.ColumnTransformer;
import org.hibernate.annotations.JdbcType;
import org.hibernate.dialect.type.PostgreSQLJsonPGObjectJsonType;

import java.time.LocalDateTime;

@Entity
@Table(name = "draft_casefiles")
@Getter
@Builder(toBuilder = true)
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@AllArgsConstructor(access = AccessLevel.PRIVATE)
public class DraftCasefileEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "draft_casefile_id_seq_generator")
    @SequenceGenerator(
        name = "draft_casefile_id_seq_generator", sequenceName = "draft_casefile_id_seq", allocationSize = 1
    )
    @Column(name = "draft_casefile_id", nullable = false)
    private Long draftCasefileId;

    @Column(name = "business_unit_id", nullable = false)
    private Short businessUnitId;

    @Column(name = "created_date", nullable = false)
    private LocalDateTime createdDate;

    @Column(name = "submitted_by", nullable = false, length = 20)
    private String submittedBy;

    @Column(name = "submitted_by_name", nullable = false, length = 100)
    private String submittedByName;

    @Column(name = "validated_date")
    private LocalDateTime validatedDate;

    @Column(name = "validated_by", length = 20)
    private String validatedBy;

    @Column(name = "validated_by_name", length = 100)
    private String validatedByName;

    // These columns use PostgreSQL json, which preserves escaped Unicode values rejected by jsonb.
    @JdbcType(PostgreSQLJsonPGObjectJsonType.class)
    @Column(name = "casefile", nullable = false, columnDefinition = "json")
    private String casefile;

    @JdbcType(PostgreSQLJsonPGObjectJsonType.class)
    @Column(name = "casefile_snapshot", nullable = false, columnDefinition = "json")
    private String casefileSnapshot;

    @ColumnTransformer(write = "?::public.t_casefile_type_enum")
    @Column(name = "casefile_type", nullable = false, columnDefinition = "public.t_casefile_type_enum")
    private String casefileType;

    @Enumerated(EnumType.STRING)
    @ColumnTransformer(write = "?::public.t_draft_casefile_status_enum")
    @Column(name = "casefile_status", nullable = false, columnDefinition = "public.t_draft_casefile_status_enum")
    private DraftCasefileStatus casefileStatus;

    @Column(name = "casefile_status_date", nullable = false)
    private LocalDateTime casefileStatusDate;

    @Column(name = "status_message", columnDefinition = "text")
    private String statusMessage;

    @JdbcType(PostgreSQLJsonPGObjectJsonType.class)
    @Column(name = "timeline_data", nullable = false, columnDefinition = "json")
    private String timelineData;

    @Column(name = "account_number", length = 25)
    private String accountNumber;

    @Column(name = "account_id")
    private Long accountId;

    @Column(name = "version_number")
    private Long versionNumber;
}
