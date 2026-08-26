package uk.gov.hmcts.reform.opal.repository;

import java.util.List;
import org.jspecify.annotations.Nullable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import uk.gov.hmcts.reform.opal.entity.CountryEntity;

@Repository
public interface CountryRepository extends JpaRepository<CountryEntity, Long> {

    @Query("""
        SELECT country
        FROM CountryEntity country
        WHERE (:active IS NULL OR country.active = :active)
        ORDER BY
            CASE WHEN country.internationalCode = 'GBR' THEN 0 ELSE 1 END,
            country.countryName ASC,
            country.countryId ASC
        """)
    List<CountryEntity> findCountries(@Param("active") @Nullable Boolean active);
}
