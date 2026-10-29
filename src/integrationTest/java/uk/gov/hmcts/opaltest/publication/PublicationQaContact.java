package uk.gov.hmcts.opaltest.publication;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.util.Arrays;
import java.util.List;

/** Scalar test mapping; deliberately outside the application entity-scan package. */
@Entity
@Table(name = "third_party_contact")
public class PublicationQaContact {

    @Id
    @Column(name = "third_party_contact_id", nullable = false)
    private Long thirdPartyContactId;

    @Column(name = "name_organisation", nullable = false, length = 40)
    private String nameOrganisation;

    @Column(name = "relationship", nullable = false, length = 40)
    private String relationship;

    @Column(name = "reference", length = 40)
    private String reference;

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

    @Column(name = "country", nullable = false)
    private Long country;

    @Column(name = "version_number")
    private Long versionNumber;

    protected PublicationQaContact() {
    }

    private PublicationQaContact(PublicationQaContact source) {
        thirdPartyContactId = source.thirdPartyContactId;
        nameOrganisation = source.nameOrganisation;
        relationship = source.relationship;
        reference = source.reference;
        addressLine1 = source.addressLine1;
        addressLine2 = source.addressLine2;
        addressLine3 = source.addressLine3;
        addressLine4 = source.addressLine4;
        addressLine5 = source.addressLine5;
        postcode = source.postcode;
        country = source.country;
        versionNumber = source.versionNumber;
    }

    public Long getThirdPartyContactId() {
        return thirdPartyContactId;
    }

    public String getNameOrganisation() {
        return nameOrganisation;
    }

    public String getRelationship() {
        return relationship;
    }

    public String getReference() {
        return reference;
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

    public Long getCountry() {
        return country;
    }

    public Long getVersionNumber() {
        return versionNumber;
    }

    public static Builder builder() {
        return new Builder(new PublicationQaContact());
    }

    public Builder toBuilder() {
        return new Builder(new PublicationQaContact(this));
    }

    @Override
    public boolean equals(Object other) {
        return other instanceof PublicationQaContact row && scalarValues().equals(row.scalarValues());
    }

    @Override
    public int hashCode() {
        return scalarValues().hashCode();
    }

    private List<Object> scalarValues() {
        return Arrays.asList(
            thirdPartyContactId, nameOrganisation, relationship,
            reference, addressLine1, addressLine2,
            addressLine3, addressLine4, addressLine5,
            postcode, country, versionNumber
        );
    }

    public static final class Builder {
        private final PublicationQaContact value;

        private Builder(PublicationQaContact value) {
            this.value = value;
        }

        public Builder thirdPartyContactId(Long field) {
            value.thirdPartyContactId = field;
            return this;
        }

        public Builder nameOrganisation(String field) {
            value.nameOrganisation = field;
            return this;
        }

        public Builder relationship(String field) {
            value.relationship = field;
            return this;
        }

        public Builder reference(String field) {
            value.reference = field;
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

        public Builder country(Long field) {
            value.country = field;
            return this;
        }

        public Builder versionNumber(Long field) {
            value.versionNumber = field;
            return this;
        }

        public PublicationQaContact build() {
            return new PublicationQaContact(value);
        }
    }
}
