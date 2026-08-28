package uk.gov.hmcts.opal.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.SequenceGenerator;
import jakarta.persistence.Table;
import java.time.LocalDate;
import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "countries")
@Getter
@Builder
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@AllArgsConstructor(access = AccessLevel.PRIVATE)
public class CountryEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "country_id_seq_generator")
    @SequenceGenerator(
        name = "country_id_seq_generator",
        sequenceName = "country_id_seq",
        allocationSize = 1
    )
    @Column(name = "country_id", nullable = false)
    private Long countryId;

    @Column(name = "cjs_code", nullable = false)
    private Short cjsCode;

    @Column(name = "international_code", length = 3)
    private String internationalCode;

    @Column(name = "gov_code", length = 2)
    private String govCode;

    @Column(name = "country_name", nullable = false, length = 100)
    private String countryName;

    @Column(name = "demonym", length = 100)
    private String demonym;

    @Column(name = "date_used_from", nullable = false)
    private LocalDate dateUsedFrom;

    @Column(name = "date_used_to")
    private LocalDate dateUsedTo;

    @Column(name = "active", nullable = false)
    private Boolean active;
}
