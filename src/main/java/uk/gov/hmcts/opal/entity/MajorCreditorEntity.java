package uk.gov.hmcts.opal.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.SequenceGenerator;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "major_creditors")
@Getter
@Builder
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@AllArgsConstructor(access = AccessLevel.PRIVATE)
public class MajorCreditorEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "major_creditor_id_seq_generator")
    @SequenceGenerator(
        name = "major_creditor_id_seq_generator",
        sequenceName = "major_creditor_id_seq",
        allocationSize = 1
    )
    @Column(name = "major_creditor_id", nullable = false)
    private Long majorCreditorId;

    @Column(name = "business_unit_id", nullable = false)
    private Short businessUnitId;

    @Column(name = "major_creditor_code", nullable = false, length = 4)
    private String majorCreditorCode;

    @Column(name = "name", nullable = false, length = 35)
    private String name;

    @Column(name = "address_line_1", nullable = false, length = 35)
    private String addressLine1;

    @Column(name = "address_line_2", length = 35)
    private String addressLine2;

    @Column(name = "address_line_3", length = 35)
    private String addressLine3;

    @Column(name = "address_line_4", length = 35)
    private String addressLine4;

    @Column(name = "address_line_5", length = 35)
    private String addressLine5;

    @Column(name = "postcode", length = 10)
    private String postcode;

    @ManyToOne(fetch = FetchType.LAZY, optional = true)
    @JoinColumn(name = "country_id")
    private CountryEntity country;

    @Column(name = "contact_name", length = 35)
    private String contactName;

    @Column(name = "contact_email", length = 254)
    private String contactEmail;

    @Column(name = "active", nullable = false)
    private Boolean active;

    @Column(name = "central_authority", nullable = false)
    private Boolean centralAuthority;
}
