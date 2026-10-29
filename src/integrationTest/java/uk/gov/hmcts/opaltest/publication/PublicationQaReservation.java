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
@Table(name = "account_number_index")
public class PublicationQaReservation {

    @Id
    @Column(name = "account_number_index_id", nullable = false)
    private Long accountNumberIndexId;

    @Column(name = "business_unit_id", nullable = false)
    private Short businessUnitId;

    @Column(name = "account_number", nullable = false, length = 20)
    private String accountNumber;

    // PostgreSQL enum binding for the observer regression fixture; reads remain scalar Strings.
    @ColumnTransformer(write = "?::public.t_associated_record_type_enum")
    @Column(name = "associated_record_type", columnDefinition = "public.t_associated_record_type_enum")
    private String associatedRecordType;

    protected PublicationQaReservation() {
    }

    private PublicationQaReservation(PublicationQaReservation source) {
        accountNumberIndexId = source.accountNumberIndexId;
        businessUnitId = source.businessUnitId;
        accountNumber = source.accountNumber;
        associatedRecordType = source.associatedRecordType;
    }

    public Long getAccountNumberIndexId() {
        return accountNumberIndexId;
    }

    public Short getBusinessUnitId() {
        return businessUnitId;
    }

    public String getAccountNumber() {
        return accountNumber;
    }

    public String getAssociatedRecordType() {
        return associatedRecordType;
    }

    public static Builder builder() {
        return new Builder(new PublicationQaReservation());
    }

    public Builder toBuilder() {
        return new Builder(new PublicationQaReservation(this));
    }

    @Override
    public boolean equals(Object other) {
        return other instanceof PublicationQaReservation row && scalarValues().equals(row.scalarValues());
    }

    @Override
    public int hashCode() {
        return scalarValues().hashCode();
    }

    private List<Object> scalarValues() {
        return Arrays.asList(
            accountNumberIndexId, businessUnitId, accountNumber,
            associatedRecordType
        );
    }

    public static final class Builder {
        private final PublicationQaReservation value;

        private Builder(PublicationQaReservation value) {
            this.value = value;
        }

        public Builder accountNumberIndexId(Long field) {
            value.accountNumberIndexId = field;
            return this;
        }

        public Builder businessUnitId(Short field) {
            value.businessUnitId = field;
            return this;
        }

        public Builder accountNumber(String field) {
            value.accountNumber = field;
            return this;
        }

        public Builder associatedRecordType(String field) {
            value.associatedRecordType = field;
            return this;
        }

        public PublicationQaReservation build() {
            return new PublicationQaReservation(value);
        }
    }
}
