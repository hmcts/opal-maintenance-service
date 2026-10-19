package uk.gov.hmcts.opal.mapper;

import javax.annotation.processing.Generated;
import org.springframework.stereotype.Component;
import uk.gov.hmcts.opal.entity.CountryEntity;
import uk.gov.hmcts.opal.entity.MajorCreditorEntity;
import uk.gov.hmcts.opal.generated.model.MajorCreditorReferenceDataItem;

@Generated(
    value = "org.mapstruct.ap.MappingProcessor",
    date = "2026-10-16T09:39:42+0100",
    comments = "version: 1.6.3, compiler: Eclipse JDT (IDE) 3.46.200.v20260930-0211, environment: Java 25.0.4.1 (Eclipse Adoptium)"
)
@Component
public class MajorCreditorMapperImpl implements MajorCreditorMapper {

    @Override
    public MajorCreditorReferenceDataItem toReferenceDataItem(MajorCreditorEntity majorCreditor) {
        if ( majorCreditor == null ) {
            return null;
        }

        MajorCreditorReferenceDataItem.Builder majorCreditorReferenceDataItem = MajorCreditorReferenceDataItem.builder();

        majorCreditorReferenceDataItem.countryId( mapToJsonNullable( majorCreditorCountryCountryId( majorCreditor ) ) );
        majorCreditorReferenceDataItem.countryName( mapToJsonNullable( majorCreditorCountryCountryName( majorCreditor ) ) );
        majorCreditorReferenceDataItem.majorCreditorId( majorCreditor.getMajorCreditorId() );
        majorCreditorReferenceDataItem.businessUnitId( majorCreditor.getBusinessUnitId() );
        majorCreditorReferenceDataItem.majorCreditorCode( majorCreditor.getMajorCreditorCode() );
        majorCreditorReferenceDataItem.name( majorCreditor.getName() );
        majorCreditorReferenceDataItem.addressLine1( majorCreditor.getAddressLine1() );
        majorCreditorReferenceDataItem.addressLine2( mapToJsonNullable( majorCreditor.getAddressLine2() ) );
        majorCreditorReferenceDataItem.addressLine3( mapToJsonNullable( majorCreditor.getAddressLine3() ) );
        majorCreditorReferenceDataItem.addressLine4( mapToJsonNullable( majorCreditor.getAddressLine4() ) );
        majorCreditorReferenceDataItem.addressLine5( mapToJsonNullable( majorCreditor.getAddressLine5() ) );
        majorCreditorReferenceDataItem.postcode( mapToJsonNullable( majorCreditor.getPostcode() ) );
        majorCreditorReferenceDataItem.contactName( mapToJsonNullable( majorCreditor.getContactName() ) );
        majorCreditorReferenceDataItem.contactEmail( mapToJsonNullable( majorCreditor.getContactEmail() ) );
        majorCreditorReferenceDataItem.active( majorCreditor.getActive() );
        majorCreditorReferenceDataItem.centralAuthority( majorCreditor.getCentralAuthority() );

        return majorCreditorReferenceDataItem.build();
    }

    private Long majorCreditorCountryCountryId(MajorCreditorEntity majorCreditorEntity) {
        CountryEntity country = majorCreditorEntity.getCountry();
        if ( country == null ) {
            return null;
        }
        return country.getCountryId();
    }

    private String majorCreditorCountryCountryName(MajorCreditorEntity majorCreditorEntity) {
        CountryEntity country = majorCreditorEntity.getCountry();
        if ( country == null ) {
            return null;
        }
        return country.getCountryName();
    }
}
