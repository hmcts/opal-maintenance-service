package uk.gov.hmcts.opal.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
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

@Entity
@Table(name = "maintenance_applications")
@Getter
@Builder
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@AllArgsConstructor(access = AccessLevel.PRIVATE)
public class MaintenanceApplicationEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "application_id_seq_generator")
    @SequenceGenerator(name = "application_id_seq_generator", sequenceName = "application_id_seq", allocationSize = 1)
    @Column(name = "application_id", nullable = false)
    private Short applicationId;

    @Column(name = "application_code", nullable = false, length = 8)
    private String applicationCode;

    @Column(name = "application_title", nullable = false, length = 255)
    private String applicationTitle;

    @Column(name = "application_group", nullable = false, length = 20)
    private String applicationGroup;

    @Column(name = "active", nullable = false)
    private Boolean active;
}
