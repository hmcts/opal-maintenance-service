package uk.gov.hmcts.opal.mapper;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.LocalDate;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mapstruct.factory.Mappers;
import uk.gov.hmcts.opal.entity.CountryEntity;

@DisplayName("PO-10251 CountryMapper")
class CountryMapperTest {

    private final CountryMapper mapper = Mappers.getMapper(CountryMapper.class);

    @Test
    @DisplayName("PO-10251 maps all nine country fields")
    void mapsAllCountryFields() {
        CountryEntity entity = CountryEntity.builder()
            .countryId(41L)
            .cjsCode((short) 32001)
            .internationalCode("GBR")
            .govCode("UK")
            .countryName("United Kingdom")
            .demonym("British")
            .dateUsedFrom(LocalDate.of(1900, 1, 1))
            .dateUsedTo(LocalDate.of(2099, 12, 31))
            .active(true)
            .build();

        var item = mapper.toReferenceDataItem(entity);

        assertThat(item.getCountryId()).isEqualTo(41L);
        assertThat(item.getCjsCode()).isEqualTo(32001);
        assertThat(item.getInternationalCode()).isEqualTo("GBR");
        assertThat(item.getGovCode()).isEqualTo("UK");
        assertThat(item.getCountryName()).isEqualTo("United Kingdom");
        assertThat(item.getDemonym()).isEqualTo("British");
        assertThat(item.getDateUsedFrom()).isEqualTo(LocalDate.of(1900, 1, 1));
        assertThat(item.getDateUsedTo()).isEqualTo(LocalDate.of(2099, 12, 31));
        assertThat(item.getActive()).isTrue();
    }

    @Test
    @DisplayName("PO-10251 preserves nullable optional country fields")
    void preservesNullableOptionalFields() {
        CountryEntity entity = CountryEntity.builder()
            .countryId(42L)
            .cjsCode((short) 32002)
            .countryName("Atlantis")
            .dateUsedFrom(LocalDate.of(2000, 1, 1))
            .active(false)
            .build();

        var item = mapper.toReferenceDataItem(entity);

        assertThat(item.getInternationalCode()).isNull();
        assertThat(item.getGovCode()).isNull();
        assertThat(item.getDemonym()).isNull();
        assertThat(item.getDateUsedTo()).isNull();
    }
}
