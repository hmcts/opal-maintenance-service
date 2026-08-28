package uk.gov.hmcts.opal.mapper;

import org.springframework.stereotype.Component;
import uk.gov.hmcts.opal.generated.model.CountryReferenceDataItem;
import uk.gov.hmcts.opal.entity.CountryEntity;

@Component
public class CountryMapper {

    public CountryReferenceDataItem toReferenceDataItem(CountryEntity country) {
        return CountryReferenceDataItem.builder()
            .countryId(country.getCountryId())
            .cjsCode(country.getCjsCode().intValue())
            .internationalCode(country.getInternationalCode())
            .govCode(country.getGovCode())
            .countryName(country.getCountryName())
            .demonym(country.getDemonym())
            .dateUsedFrom(country.getDateUsedFrom())
            .dateUsedTo(country.getDateUsedTo())
            .active(country.getActive())
            .build();
    }
}
