package uk.gov.hmcts.opal.mapper;

import javax.annotation.processing.Generated;
import org.springframework.stereotype.Component;
import uk.gov.hmcts.opal.entity.CountryEntity;
import uk.gov.hmcts.opal.generated.model.CountryReferenceDataItem;

@Generated(
    value = "org.mapstruct.ap.MappingProcessor",
    date = "2026-10-16T09:39:42+0100",
    comments = "version: 1.6.3, compiler: Eclipse JDT (IDE) 3.46.200.v20260930-0211, environment: Java 25.0.4.1 (Eclipse Adoptium)"
)
@Component
public class CountryMapperImpl implements CountryMapper {

    @Override
    public CountryReferenceDataItem toReferenceDataItem(CountryEntity country) {
        if ( country == null ) {
            return null;
        }

        CountryReferenceDataItem.Builder countryReferenceDataItem = CountryReferenceDataItem.builder();

        countryReferenceDataItem.countryId( country.getCountryId() );
        if ( country.getCjsCode() != null ) {
            countryReferenceDataItem.cjsCode( country.getCjsCode().intValue() );
        }
        countryReferenceDataItem.internationalCode( country.getInternationalCode() );
        countryReferenceDataItem.govCode( country.getGovCode() );
        countryReferenceDataItem.countryName( country.getCountryName() );
        countryReferenceDataItem.demonym( country.getDemonym() );
        countryReferenceDataItem.dateUsedFrom( country.getDateUsedFrom() );
        countryReferenceDataItem.dateUsedTo( country.getDateUsedTo() );
        countryReferenceDataItem.active( country.getActive() );

        return countryReferenceDataItem.build();
    }
}
