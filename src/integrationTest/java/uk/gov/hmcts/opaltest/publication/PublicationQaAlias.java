package uk.gov.hmcts.opaltest.publication;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.util.Arrays;
import java.util.List;

/** Scalar test mapping; deliberately outside the application entity-scan package. */
@Entity
@Table(name = "aliases")
public class PublicationQaAlias {

    @Id
    @Column(name = "alias_id", nullable = false)
    private Long aliasId;

    @Column(name = "party_id", nullable = false)
    private Long partyId;

    @Column(name = "surname", nullable = false, length = 50)
    private String surname;

    @Column(name = "forenames", nullable = false, length = 50)
    private String forenames;

    @Column(name = "organisation_name", length = 50)
    private String organisationName;

    @Column(name = "sequence_number", nullable = false)
    private Integer sequenceNumber;

    protected PublicationQaAlias() {
    }

    private PublicationQaAlias(PublicationQaAlias source) {
        aliasId = source.aliasId;
        partyId = source.partyId;
        surname = source.surname;
        forenames = source.forenames;
        organisationName = source.organisationName;
        sequenceNumber = source.sequenceNumber;
    }

    public Long getAliasId() {
        return aliasId;
    }

    public Long getPartyId() {
        return partyId;
    }

    public String getSurname() {
        return surname;
    }

    public String getForenames() {
        return forenames;
    }

    public String getOrganisationName() {
        return organisationName;
    }

    public Integer getSequenceNumber() {
        return sequenceNumber;
    }

    public static Builder builder() {
        return new Builder(new PublicationQaAlias());
    }

    public Builder toBuilder() {
        return new Builder(new PublicationQaAlias(this));
    }

    @Override
    public boolean equals(Object other) {
        return other instanceof PublicationQaAlias row && scalarValues().equals(row.scalarValues());
    }

    @Override
    public int hashCode() {
        return scalarValues().hashCode();
    }

    private List<Object> scalarValues() {
        return Arrays.asList(
            aliasId, partyId, surname,
            forenames, organisationName, sequenceNumber
        );
    }

    public static final class Builder {
        private final PublicationQaAlias value;

        private Builder(PublicationQaAlias value) {
            this.value = value;
        }

        public Builder aliasId(Long field) {
            value.aliasId = field;
            return this;
        }

        public Builder partyId(Long field) {
            value.partyId = field;
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

        public Builder organisationName(String field) {
            value.organisationName = field;
            return this;
        }

        public Builder sequenceNumber(Integer field) {
            value.sequenceNumber = field;
            return this;
        }

        public PublicationQaAlias build() {
            return new PublicationQaAlias(value);
        }
    }
}
