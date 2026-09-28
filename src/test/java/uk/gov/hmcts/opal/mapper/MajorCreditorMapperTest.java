package uk.gov.hmcts.opal.mapper;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mapstruct.factory.Mappers;
import org.openapitools.jackson.nullable.JsonNullable;
import uk.gov.hmcts.opal.entity.CountryEntity;
import uk.gov.hmcts.opal.entity.MajorCreditorEntity;

@DisplayName("PO-10254 MajorCreditorMapper")
class MajorCreditorMapperTest {

    private final MajorCreditorMapper mapper = Mappers.getMapper(MajorCreditorMapper.class);

    @Test
    void mapsEveryFieldAndIncludesAnInactiveCountry() {
        CountryEntity country = CountryEntity.builder()
            .countryId(101L)
            .countryName("France")
            .active(false)
            .build();
        MajorCreditorEntity entity = MajorCreditorEntity.builder()
            .majorCreditorId(901L)
            .businessUnitId((short) 77)
            .majorCreditorCode("0123")
            .name("Example Creditor")
            .addressLine1("1 Example Street")
            .addressLine2("District")
            .addressLine3("Town")
            .addressLine4("County")
            .addressLine5("Region")
            .postcode("AB1 2CD")
            .country(country)
            .contactName("Contact")
            .contactEmail("contact@example.test")
            .active(true)
            .centralAuthority(false)
            .build();

        var item = mapper.toReferenceDataItem(entity);

        assertThat(item.getMajorCreditorId()).isEqualTo(901L);
        assertThat(item.getBusinessUnitId()).isEqualTo((short) 77);
        assertThat(item.getMajorCreditorCode()).isEqualTo("0123");
        assertThat(item.getName()).isEqualTo("Example Creditor");
        assertThat(item.getAddressLine1()).isEqualTo("1 Example Street");
        assertThat(item.getAddressLine2()).isEqualTo(JsonNullable.of("District"));
        assertThat(item.getAddressLine3()).isEqualTo(JsonNullable.of("Town"));
        assertThat(item.getAddressLine4()).isEqualTo(JsonNullable.of("County"));
        assertThat(item.getAddressLine5()).isEqualTo(JsonNullable.of("Region"));
        assertThat(item.getPostcode()).isEqualTo(JsonNullable.of("AB1 2CD"));
        assertThat(item.getCountryId()).isEqualTo(JsonNullable.of(101L));
        assertThat(item.getCountryName()).isEqualTo(JsonNullable.of("France"));
        assertThat(item.getContactName()).isEqualTo(JsonNullable.of("Contact"));
        assertThat(item.getContactEmail()).isEqualTo(JsonNullable.of("contact@example.test"));
        assertThat(item.getActive()).isTrue();
        assertThat(item.getCentralAuthority()).isFalse();
    }

    @Test
    void mapsNullableFieldsAndMissingCountryAsNull() {
        MajorCreditorEntity entity = MajorCreditorEntity.builder()
            .majorCreditorId(902L)
            .businessUnitId((short) 77)
            .majorCreditorCode("0124")
            .name("No Country")
            .addressLine1("2 Example Street")
            .active(false)
            .centralAuthority(true)
            .build();

        var item = mapper.toReferenceDataItem(entity);

        assertThat(item.getAddressLine2()).isEqualTo(JsonNullable.of(null));
        assertThat(item.getAddressLine3()).isEqualTo(JsonNullable.of(null));
        assertThat(item.getAddressLine4()).isEqualTo(JsonNullable.of(null));
        assertThat(item.getAddressLine5()).isEqualTo(JsonNullable.of(null));
        assertThat(item.getPostcode()).isEqualTo(JsonNullable.of(null));
        assertThat(item.getCountryId()).isEqualTo(JsonNullable.of(null));
        assertThat(item.getCountryName()).isEqualTo(JsonNullable.of(null));
        assertThat(item.getContactName()).isEqualTo(JsonNullable.of(null));
        assertThat(item.getContactEmail()).isEqualTo(JsonNullable.of(null));
    }
}
