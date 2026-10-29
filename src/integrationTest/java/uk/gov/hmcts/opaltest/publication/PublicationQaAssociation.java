package uk.gov.hmcts.opaltest.publication;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.util.Arrays;
import java.util.List;
import org.hibernate.annotations.ColumnTransformer;

/** Scalar test mapping; deliberately outside the application entity-scan package. */
@Entity
@Table(name = "respondent_account_parties")
public class PublicationQaAssociation {

    @Id
    @Column(name = "respondent_account_party_id", nullable = false)
    private Long respondentAccountPartyId;

    @Column(name = "respondent_account_id", nullable = false)
    private Long respondentAccountId;

    @Column(name = "associated_account_id", nullable = false)
    private Long associatedAccountId;

    // PostgreSQL enum binding for the observer regression fixture; reads remain scalar Strings.
    @ColumnTransformer(write = "?::public.t_association_type_enum")
    @Column(name = "association_type", nullable = false, columnDefinition = "public.t_association_type_enum")
    private String associationType;

    protected PublicationQaAssociation() {
    }

    private PublicationQaAssociation(PublicationQaAssociation source) {
        respondentAccountPartyId = source.respondentAccountPartyId;
        respondentAccountId = source.respondentAccountId;
        associatedAccountId = source.associatedAccountId;
        associationType = source.associationType;
    }

    public Long getRespondentAccountPartyId() {
        return respondentAccountPartyId;
    }

    public Long getRespondentAccountId() {
        return respondentAccountId;
    }

    public Long getAssociatedAccountId() {
        return associatedAccountId;
    }

    public String getAssociationType() {
        return associationType;
    }

    public static Builder builder() {
        return new Builder(new PublicationQaAssociation());
    }

    public Builder toBuilder() {
        return new Builder(new PublicationQaAssociation(this));
    }

    @Override
    public boolean equals(Object other) {
        return other instanceof PublicationQaAssociation row && scalarValues().equals(row.scalarValues());
    }

    @Override
    public int hashCode() {
        return scalarValues().hashCode();
    }

    private List<Object> scalarValues() {
        return Arrays.asList(
            respondentAccountPartyId, respondentAccountId, associatedAccountId,
            associationType
        );
    }

    public static final class Builder {
        private final PublicationQaAssociation value;

        private Builder(PublicationQaAssociation value) {
            this.value = value;
        }

        public Builder respondentAccountPartyId(Long field) {
            value.respondentAccountPartyId = field;
            return this;
        }

        public Builder respondentAccountId(Long field) {
            value.respondentAccountId = field;
            return this;
        }

        public Builder associatedAccountId(Long field) {
            value.associatedAccountId = field;
            return this;
        }

        public Builder associationType(String field) {
            value.associationType = field;
            return this;
        }

        public PublicationQaAssociation build() {
            return new PublicationQaAssociation(value);
        }
    }
}
