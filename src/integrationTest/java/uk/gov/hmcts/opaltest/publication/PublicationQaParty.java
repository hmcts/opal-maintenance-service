package uk.gov.hmcts.opaltest.publication;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.util.Arrays;
import java.util.List;
import org.hibernate.annotations.ColumnTransformer;

import java.time.LocalDate;
import java.time.LocalDateTime;

/** Scalar test mapping; deliberately outside the application entity-scan package. */
@Entity
@Table(name = "parties")
public class PublicationQaParty {

    @Id
    @Column(name = "party_id", nullable = false)
    private Long partyId;

    @Column(name = "organisation")
    private Boolean organisation;

    @Column(name = "organisation_name", length = 80)
    private String organisationName;

    @Column(name = "foreign_authority_reference", columnDefinition = "text")
    private String foreignAuthorityReference;

    @Column(name = "surname", length = 50)
    private String surname;

    @Column(name = "forenames", length = 50)
    private String forenames;

    @Column(name = "title", length = 20)
    private String title;

    @Column(name = "birth_date")
    private LocalDate birthDate;

    @Column(name = "national_insurance_number", length = 10)
    private String nationalInsuranceNumber;

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

    @Column(name = "telephone_home", length = 35)
    private String telephoneHome;

    @Column(name = "telephone_business", length = 35)
    private String telephoneBusiness;

    @Column(name = "telephone_mobile", length = 35)
    private String telephoneMobile;

    @Column(name = "email_1", length = 80)
    private String email1;

    @Column(name = "email_2", length = 80)
    private String email2;

    @Column(name = "restrict_personal_information", nullable = false)
    private Boolean restrictPersonalInformation;

    @Column(name = "restriction_reason", columnDefinition = "text")
    private String restrictionReason;

    @Column(name = "country_id", nullable = false)
    private Long countryId;

    // PostgreSQL enum binding for the observer regression fixture; reads remain scalar Strings.
    @ColumnTransformer(write = "?::public.t_party_account_type_enum")
    @Column(name = "account_type", columnDefinition = "public.t_party_account_type_enum")
    private String accountType;

    @Column(name = "last_changed_date")
    private LocalDateTime lastChangedDate;

    protected PublicationQaParty() {
    }

    private PublicationQaParty(PublicationQaParty source) {
        partyId = source.partyId;
        organisation = source.organisation;
        organisationName = source.organisationName;
        foreignAuthorityReference = source.foreignAuthorityReference;
        surname = source.surname;
        forenames = source.forenames;
        title = source.title;
        birthDate = source.birthDate;
        nationalInsuranceNumber = source.nationalInsuranceNumber;
        addressLine1 = source.addressLine1;
        addressLine2 = source.addressLine2;
        addressLine3 = source.addressLine3;
        addressLine4 = source.addressLine4;
        addressLine5 = source.addressLine5;
        postcode = source.postcode;
        telephoneHome = source.telephoneHome;
        telephoneBusiness = source.telephoneBusiness;
        telephoneMobile = source.telephoneMobile;
        email1 = source.email1;
        email2 = source.email2;
        restrictPersonalInformation = source.restrictPersonalInformation;
        restrictionReason = source.restrictionReason;
        countryId = source.countryId;
        accountType = source.accountType;
        lastChangedDate = source.lastChangedDate;
    }

    public Long getPartyId() {
        return partyId;
    }

    public Boolean getOrganisation() {
        return organisation;
    }

    public String getOrganisationName() {
        return organisationName;
    }

    public String getForeignAuthorityReference() {
        return foreignAuthorityReference;
    }

    public String getSurname() {
        return surname;
    }

    public String getForenames() {
        return forenames;
    }

    public String getTitle() {
        return title;
    }

    public LocalDate getBirthDate() {
        return birthDate;
    }

    public String getNationalInsuranceNumber() {
        return nationalInsuranceNumber;
    }

    public String getAddressLine1() {
        return addressLine1;
    }

    public String getAddressLine2() {
        return addressLine2;
    }

    public String getAddressLine3() {
        return addressLine3;
    }

    public String getAddressLine4() {
        return addressLine4;
    }

    public String getAddressLine5() {
        return addressLine5;
    }

    public String getPostcode() {
        return postcode;
    }

    public String getTelephoneHome() {
        return telephoneHome;
    }

    public String getTelephoneBusiness() {
        return telephoneBusiness;
    }

    public String getTelephoneMobile() {
        return telephoneMobile;
    }

    public String getEmail1() {
        return email1;
    }

    public String getEmail2() {
        return email2;
    }

    public Boolean getRestrictPersonalInformation() {
        return restrictPersonalInformation;
    }

    public String getRestrictionReason() {
        return restrictionReason;
    }

    public Long getCountryId() {
        return countryId;
    }

    public String getAccountType() {
        return accountType;
    }

    public LocalDateTime getLastChangedDate() {
        return lastChangedDate;
    }

    public static Builder builder() {
        return new Builder(new PublicationQaParty());
    }

    public Builder toBuilder() {
        return new Builder(new PublicationQaParty(this));
    }

    @Override
    public boolean equals(Object other) {
        return other instanceof PublicationQaParty row && scalarValues().equals(row.scalarValues());
    }

    @Override
    public int hashCode() {
        return scalarValues().hashCode();
    }

    private List<Object> scalarValues() {
        return Arrays.asList(
            partyId, organisation, organisationName,
            foreignAuthorityReference, surname, forenames,
            title, birthDate, nationalInsuranceNumber,
            addressLine1, addressLine2, addressLine3,
            addressLine4, addressLine5, postcode,
            telephoneHome, telephoneBusiness, telephoneMobile,
            email1, email2, restrictPersonalInformation,
            restrictionReason, countryId, accountType,
            lastChangedDate
        );
    }

    public static final class Builder {
        private final PublicationQaParty value;

        private Builder(PublicationQaParty value) {
            this.value = value;
        }

        public Builder partyId(Long field) {
            value.partyId = field;
            return this;
        }

        public Builder organisation(Boolean field) {
            value.organisation = field;
            return this;
        }

        public Builder organisationName(String field) {
            value.organisationName = field;
            return this;
        }

        public Builder foreignAuthorityReference(String field) {
            value.foreignAuthorityReference = field;
            return this;
        }

        public Builder surname(String field) {
            value.surname = field;
            return this;
        }

        public Builder forenames(String field) {
            value.forenames = field;
            return this;
        }

        public Builder title(String field) {
            value.title = field;
            return this;
        }

        public Builder birthDate(LocalDate field) {
            value.birthDate = field;
            return this;
        }

        public Builder nationalInsuranceNumber(String field) {
            value.nationalInsuranceNumber = field;
            return this;
        }

        public Builder addressLine1(String field) {
            value.addressLine1 = field;
            return this;
        }

        public Builder addressLine2(String field) {
            value.addressLine2 = field;
            return this;
        }

        public Builder addressLine3(String field) {
            value.addressLine3 = field;
            return this;
        }

        public Builder addressLine4(String field) {
            value.addressLine4 = field;
            return this;
        }

        public Builder addressLine5(String field) {
            value.addressLine5 = field;
            return this;
        }

        public Builder postcode(String field) {
            value.postcode = field;
            return this;
        }

        public Builder telephoneHome(String field) {
            value.telephoneHome = field;
            return this;
        }

        public Builder telephoneBusiness(String field) {
            value.telephoneBusiness = field;
            return this;
        }

        public Builder telephoneMobile(String field) {
            value.telephoneMobile = field;
            return this;
        }

        public Builder email1(String field) {
            value.email1 = field;
            return this;
        }

        public Builder email2(String field) {
            value.email2 = field;
            return this;
        }

        public Builder restrictPersonalInformation(Boolean field) {
            value.restrictPersonalInformation = field;
            return this;
        }

        public Builder restrictionReason(String field) {
            value.restrictionReason = field;
            return this;
        }

        public Builder countryId(Long field) {
            value.countryId = field;
            return this;
        }

        public Builder accountType(String field) {
            value.accountType = field;
            return this;
        }

        public Builder lastChangedDate(LocalDateTime field) {
            value.lastChangedDate = field;
            return this;
        }

        public PublicationQaParty build() {
            return new PublicationQaParty(value);
        }
    }
}
