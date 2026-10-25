package uk.gov.hmcts.opaltest.publication;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.util.Arrays;
import java.util.List;
import org.hibernate.annotations.ColumnTransformer;
import org.hibernate.annotations.JdbcType;
import org.hibernate.dialect.type.PostgreSQLJsonPGObjectJsonType;

import java.time.LocalDateTime;

/** Scalar test mapping; deliberately outside the application entity-scan package. */
@Entity
@Table(name = "creditor_accounts")
public class PublicationQaCreditor {

    @Id
    @Column(name = "creditor_account_id", nullable = false)
    private Long creditorAccountId;

    @Column(name = "business_unit_id", nullable = false)
    private Short businessUnitId;

    @Column(name = "account_number", nullable = false, length = 20)
    private String accountNumber;

    // PostgreSQL enum binding for the observer regression fixture; reads remain scalar Strings.
    @ColumnTransformer(write = "?::public.t_creditor_account_type_enum")
    @Column(name = "creditor_account_type", nullable = false, columnDefinition = "public.t_creditor_account_type_enum")
    private String creditorAccountType;

    @Column(name = "major_creditor_id")
    private Long majorCreditorId;

    @Column(name = "minor_creditor_party_id")
    private Long minorCreditorPartyId;

    @Column(name = "from_suspense", nullable = false)
    private Boolean fromSuspense;

    @Column(name = "hold_payout", nullable = false)
    private Boolean holdPayout;

    @Column(name = "pay_by_bacs", nullable = false)
    private Boolean payByBacs;

    @Column(name = "bank_sort_code", length = 6)
    private String bankSortCode;

    @Column(name = "bank_account_number", length = 10)
    private String bankAccountNumber;

    @Column(name = "bank_account_name", length = 18)
    private String bankAccountName;

    @Column(name = "bank_account_reference", length = 18)
    private String bankAccountReference;

    @Column(name = "third_party_contact_id")
    private Long thirdPartyContactId;

    @Column(name = "last_changed_date")
    private LocalDateTime lastChangedDate;

    @JdbcType(PostgreSQLJsonPGObjectJsonType.class)
    @Column(name = "non_uk_bank_detail", columnDefinition = "json")
    private String nonUkBankDetail;

    @Column(name = "version_number")
    private Long versionNumber;

    protected PublicationQaCreditor() {
    }

    private PublicationQaCreditor(PublicationQaCreditor source) {
        creditorAccountId = source.creditorAccountId;
        businessUnitId = source.businessUnitId;
        accountNumber = source.accountNumber;
        creditorAccountType = source.creditorAccountType;
        majorCreditorId = source.majorCreditorId;
        minorCreditorPartyId = source.minorCreditorPartyId;
        fromSuspense = source.fromSuspense;
        holdPayout = source.holdPayout;
        payByBacs = source.payByBacs;
        bankSortCode = source.bankSortCode;
        bankAccountNumber = source.bankAccountNumber;
        bankAccountName = source.bankAccountName;
        bankAccountReference = source.bankAccountReference;
        thirdPartyContactId = source.thirdPartyContactId;
        lastChangedDate = source.lastChangedDate;
        nonUkBankDetail = source.nonUkBankDetail;
        versionNumber = source.versionNumber;
    }

    public Long getCreditorAccountId() {
        return creditorAccountId;
    }

    public Short getBusinessUnitId() {
        return businessUnitId;
    }

    public String getAccountNumber() {
        return accountNumber;
    }

    public String getCreditorAccountType() {
        return creditorAccountType;
    }

    public Long getMajorCreditorId() {
        return majorCreditorId;
    }

    public Long getMinorCreditorPartyId() {
        return minorCreditorPartyId;
    }

    public Boolean getFromSuspense() {
        return fromSuspense;
    }

    public Boolean getHoldPayout() {
        return holdPayout;
    }

    public Boolean getPayByBacs() {
        return payByBacs;
    }

    public String getBankSortCode() {
        return bankSortCode;
    }

    public String getBankAccountNumber() {
        return bankAccountNumber;
    }

    public String getBankAccountName() {
        return bankAccountName;
    }

    public String getBankAccountReference() {
        return bankAccountReference;
    }

    public Long getThirdPartyContactId() {
        return thirdPartyContactId;
    }

    public LocalDateTime getLastChangedDate() {
        return lastChangedDate;
    }

    public String getNonUkBankDetail() {
        return nonUkBankDetail;
    }

    public Long getVersionNumber() {
        return versionNumber;
    }

    public static Builder builder() {
        return new Builder(new PublicationQaCreditor());
    }

    public Builder toBuilder() {
        return new Builder(new PublicationQaCreditor(this));
    }

    @Override
    public boolean equals(Object other) {
        return other instanceof PublicationQaCreditor row && scalarValues().equals(row.scalarValues());
    }

    @Override
    public int hashCode() {
        return scalarValues().hashCode();
    }

    private List<Object> scalarValues() {
        return Arrays.asList(
            creditorAccountId, businessUnitId, accountNumber,
            creditorAccountType, majorCreditorId, minorCreditorPartyId,
            fromSuspense, holdPayout, payByBacs,
            bankSortCode, bankAccountNumber, bankAccountName,
            bankAccountReference, thirdPartyContactId, lastChangedDate,
            nonUkBankDetail, versionNumber
        );
    }

    public static final class Builder {
        private final PublicationQaCreditor value;

        private Builder(PublicationQaCreditor value) {
            this.value = value;
        }

        public Builder creditorAccountId(Long field) {
            value.creditorAccountId = field;
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

        public Builder creditorAccountType(String field) {
            value.creditorAccountType = field;
            return this;
        }

        public Builder majorCreditorId(Long field) {
            value.majorCreditorId = field;
            return this;
        }

        public Builder minorCreditorPartyId(Long field) {
            value.minorCreditorPartyId = field;
            return this;
        }

        public Builder fromSuspense(Boolean field) {
            value.fromSuspense = field;
            return this;
        }

        public Builder holdPayout(Boolean field) {
            value.holdPayout = field;
            return this;
        }

        public Builder payByBacs(Boolean field) {
            value.payByBacs = field;
            return this;
        }

        public Builder bankSortCode(String field) {
            value.bankSortCode = field;
            return this;
        }

        public Builder bankAccountNumber(String field) {
            value.bankAccountNumber = field;
            return this;
        }

        public Builder bankAccountName(String field) {
            value.bankAccountName = field;
            return this;
        }

        public Builder bankAccountReference(String field) {
            value.bankAccountReference = field;
            return this;
        }

        public Builder thirdPartyContactId(Long field) {
            value.thirdPartyContactId = field;
            return this;
        }

        public Builder lastChangedDate(LocalDateTime field) {
            value.lastChangedDate = field;
            return this;
        }

        public Builder nonUkBankDetail(String field) {
            value.nonUkBankDetail = field;
            return this;
        }

        public Builder versionNumber(Long field) {
            value.versionNumber = field;
            return this;
        }

        public PublicationQaCreditor build() {
            return new PublicationQaCreditor(value);
        }
    }
}
