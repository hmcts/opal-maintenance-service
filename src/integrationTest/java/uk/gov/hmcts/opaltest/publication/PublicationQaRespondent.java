package uk.gov.hmcts.opaltest.publication;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.util.Arrays;
import java.util.List;
import org.hibernate.annotations.ColumnTransformer;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/** Scalar test mapping; deliberately outside the application entity-scan package. */
@Entity
@Table(name = "respondent_accounts")
public class PublicationQaRespondent {

    @Id
    @Column(name = "respondent_account_id", nullable = false)
    private Long respondentAccountId;

    @Column(name = "business_unit_id", nullable = false)
    private Short businessUnitId;

    @Column(name = "debtor_detail_id")
    private Long debtorDetailId;

    @Column(name = "account_number", nullable = false, length = 20)
    private String accountNumber;

    @Column(name = "application_id", nullable = false)
    private Short applicationId;

    @Column(name = "imposed_hearing_date")
    private LocalDateTime imposedHearingDate;

    @Column(name = "last_hearing_date")
    private LocalDateTime lastHearingDate;

    @Column(name = "last_hearing_court_id")
    private Long lastHearingCourtId;

    @Column(name = "account_balance", nullable = false)
    private BigDecimal accountBalance;

    @Column(name = "orders_balance", nullable = false)
    private BigDecimal ordersBalance;

    @Column(name = "orders_amount", nullable = false)
    private BigDecimal ordersAmount;

    // PostgreSQL enum binding for the observer regression fixture; reads remain scalar Strings.
    @ColumnTransformer(write = "?::public.t_payment_frequency_enum")
    @Column(name = "payment_period", nullable = false, columnDefinition = "public.t_payment_frequency_enum")
    private String paymentPeriod;

    @Column(name = "total_arrears", nullable = false)
    private BigDecimal totalArrears;

    // PostgreSQL enum binding for the observer regression fixture; reads remain scalar Strings.
    @ColumnTransformer(write = "?::public.t_da_account_status_enum")
    @Column(name = "account_status", nullable = false, columnDefinition = "public.t_da_account_status_enum")
    private String accountStatus;

    @Column(name = "completed_date")
    private LocalDateTime completedDate;

    @Column(name = "last_movement_date", nullable = false)
    private LocalDateTime lastMovementDate;

    @Column(name = "date_arrears_last_updated", nullable = false)
    private LocalDateTime dateArrearsLastUpdated;

    @Column(name = "last_enforcement_result_id", length = 6)
    private String lastEnforcementResultId;

    @Column(name = "last_enforcement_date")
    private LocalDateTime lastEnforcementDate;

    @Column(name = "originator_name", length = 200)
    private String originatorName;

    @Column(name = "allow_cheques", nullable = false)
    private Boolean allowCheques;

    @Column(name = "cheque_clearance_period", nullable = false)
    private Short chequeClearancePeriod;

    @Column(name = "credit_trans_clearance_period", nullable = false)
    private Short creditTransClearancePeriod;

    // PostgreSQL enum binding for the observer regression fixture; reads remain scalar Strings.
    @ColumnTransformer(write = "?::public.t_casefile_type_enum")
    @Column(name = "casefile_type", nullable = false, columnDefinition = "public.t_casefile_type_enum")
    private String casefileType;

    @Column(name = "third_party_contact_id")
    private Long thirdPartyContactId;

    @Column(name = "remo_reference", length = 20)
    private String remoReference;

    @Column(name = "ca_reference", length = 50)
    private String caReference;

    @Column(name = "interest_flag", nullable = false)
    private Boolean interestFlag;

    // PostgreSQL enum binding for the observer regression fixture; reads remain scalar Strings.
    @ColumnTransformer(write = "?::public.t_indexation_enum")
    @Column(name = "indexation", nullable = false, columnDefinition = "public.t_indexation_enum")
    private String indexation;

    // PostgreSQL enum binding for the observer regression fixture; reads remain scalar Strings.
    @ColumnTransformer(write = "?::public.t_payment_arrangement_enum")
    @Column(name = "payment_arrangement", nullable = false, columnDefinition = "public.t_payment_arrangement_enum")
    private String paymentArrangement;

    @Column(name = "account_comment", columnDefinition = "text")
    private String accountComment;

    @Column(name = "version_number", nullable = false)
    private Long versionNumber;

    protected PublicationQaRespondent() {
    }

    private PublicationQaRespondent(PublicationQaRespondent source) {
        respondentAccountId = source.respondentAccountId;
        businessUnitId = source.businessUnitId;
        debtorDetailId = source.debtorDetailId;
        accountNumber = source.accountNumber;
        applicationId = source.applicationId;
        imposedHearingDate = source.imposedHearingDate;
        lastHearingDate = source.lastHearingDate;
        lastHearingCourtId = source.lastHearingCourtId;
        accountBalance = source.accountBalance;
        ordersBalance = source.ordersBalance;
        ordersAmount = source.ordersAmount;
        paymentPeriod = source.paymentPeriod;
        totalArrears = source.totalArrears;
        accountStatus = source.accountStatus;
        completedDate = source.completedDate;
        lastMovementDate = source.lastMovementDate;
        dateArrearsLastUpdated = source.dateArrearsLastUpdated;
        lastEnforcementResultId = source.lastEnforcementResultId;
        lastEnforcementDate = source.lastEnforcementDate;
        originatorName = source.originatorName;
        allowCheques = source.allowCheques;
        chequeClearancePeriod = source.chequeClearancePeriod;
        creditTransClearancePeriod = source.creditTransClearancePeriod;
        casefileType = source.casefileType;
        thirdPartyContactId = source.thirdPartyContactId;
        remoReference = source.remoReference;
        caReference = source.caReference;
        interestFlag = source.interestFlag;
        indexation = source.indexation;
        paymentArrangement = source.paymentArrangement;
        accountComment = source.accountComment;
        versionNumber = source.versionNumber;
    }

    public Long getRespondentAccountId() {
        return respondentAccountId;
    }

    public Short getBusinessUnitId() {
        return businessUnitId;
    }

    public Long getDebtorDetailId() {
        return debtorDetailId;
    }

    public String getAccountNumber() {
        return accountNumber;
    }

    public Short getApplicationId() {
        return applicationId;
    }

    public LocalDateTime getImposedHearingDate() {
        return imposedHearingDate;
    }

    public LocalDateTime getLastHearingDate() {
        return lastHearingDate;
    }

    public Long getLastHearingCourtId() {
        return lastHearingCourtId;
    }

    public BigDecimal getAccountBalance() {
        return accountBalance;
    }

    public BigDecimal getOrdersBalance() {
        return ordersBalance;
    }

    public BigDecimal getOrdersAmount() {
        return ordersAmount;
    }

    public String getPaymentPeriod() {
        return paymentPeriod;
    }

    public BigDecimal getTotalArrears() {
        return totalArrears;
    }

    public String getAccountStatus() {
        return accountStatus;
    }

    public LocalDateTime getCompletedDate() {
        return completedDate;
    }

    public LocalDateTime getLastMovementDate() {
        return lastMovementDate;
    }

    public LocalDateTime getDateArrearsLastUpdated() {
        return dateArrearsLastUpdated;
    }

    public String getLastEnforcementResultId() {
        return lastEnforcementResultId;
    }

    public LocalDateTime getLastEnforcementDate() {
        return lastEnforcementDate;
    }

    public String getOriginatorName() {
        return originatorName;
    }

    public Boolean getAllowCheques() {
        return allowCheques;
    }

    public Short getChequeClearancePeriod() {
        return chequeClearancePeriod;
    }

    public Short getCreditTransClearancePeriod() {
        return creditTransClearancePeriod;
    }

    public String getCasefileType() {
        return casefileType;
    }

    public Long getThirdPartyContactId() {
        return thirdPartyContactId;
    }

    public String getRemoReference() {
        return remoReference;
    }

    public String getCaReference() {
        return caReference;
    }

    public Boolean getInterestFlag() {
        return interestFlag;
    }

    public String getIndexation() {
        return indexation;
    }

    public String getPaymentArrangement() {
        return paymentArrangement;
    }

    public String getAccountComment() {
        return accountComment;
    }

    public Long getVersionNumber() {
        return versionNumber;
    }

    public static Builder builder() {
        return new Builder(new PublicationQaRespondent());
    }

    public Builder toBuilder() {
        return new Builder(new PublicationQaRespondent(this));
    }

    @Override
    public boolean equals(Object other) {
        return other instanceof PublicationQaRespondent row && scalarValues().equals(row.scalarValues());
    }

    @Override
    public int hashCode() {
        return scalarValues().hashCode();
    }

    private List<Object> scalarValues() {
        return Arrays.asList(
            respondentAccountId, businessUnitId, debtorDetailId,
            accountNumber, applicationId, imposedHearingDate,
            lastHearingDate, lastHearingCourtId, accountBalance,
            ordersBalance, ordersAmount, paymentPeriod,
            totalArrears, accountStatus, completedDate,
            lastMovementDate, dateArrearsLastUpdated, lastEnforcementResultId,
            lastEnforcementDate, originatorName, allowCheques,
            chequeClearancePeriod, creditTransClearancePeriod, casefileType,
            thirdPartyContactId, remoReference, caReference,
            interestFlag, indexation, paymentArrangement,
            accountComment, versionNumber
        );
    }

    public static final class Builder {
        private final PublicationQaRespondent value;

        private Builder(PublicationQaRespondent value) {
            this.value = value;
        }

        public Builder respondentAccountId(Long field) {
            value.respondentAccountId = field;
            return this;
        }

        public Builder businessUnitId(Short field) {
            value.businessUnitId = field;
            return this;
        }

        public Builder debtorDetailId(Long field) {
            value.debtorDetailId = field;
            return this;
        }

        public Builder accountNumber(String field) {
            value.accountNumber = field;
            return this;
        }

        public Builder applicationId(Short field) {
            value.applicationId = field;
            return this;
        }

        public Builder imposedHearingDate(LocalDateTime field) {
            value.imposedHearingDate = field;
            return this;
        }

        public Builder lastHearingDate(LocalDateTime field) {
            value.lastHearingDate = field;
            return this;
        }

        public Builder lastHearingCourtId(Long field) {
            value.lastHearingCourtId = field;
            return this;
        }

        public Builder accountBalance(BigDecimal field) {
            value.accountBalance = field;
            return this;
        }

        public Builder ordersBalance(BigDecimal field) {
            value.ordersBalance = field;
            return this;
        }

        public Builder ordersAmount(BigDecimal field) {
            value.ordersAmount = field;
            return this;
        }

        public Builder paymentPeriod(String field) {
            value.paymentPeriod = field;
            return this;
        }

        public Builder totalArrears(BigDecimal field) {
            value.totalArrears = field;
            return this;
        }

        public Builder accountStatus(String field) {
            value.accountStatus = field;
            return this;
        }

        public Builder completedDate(LocalDateTime field) {
            value.completedDate = field;
            return this;
        }

        public Builder lastMovementDate(LocalDateTime field) {
            value.lastMovementDate = field;
            return this;
        }

        public Builder dateArrearsLastUpdated(LocalDateTime field) {
            value.dateArrearsLastUpdated = field;
            return this;
        }

        public Builder lastEnforcementResultId(String field) {
            value.lastEnforcementResultId = field;
            return this;
        }

        public Builder lastEnforcementDate(LocalDateTime field) {
            value.lastEnforcementDate = field;
            return this;
        }

        public Builder originatorName(String field) {
            value.originatorName = field;
            return this;
        }

        public Builder allowCheques(Boolean field) {
            value.allowCheques = field;
            return this;
        }

        public Builder chequeClearancePeriod(Short field) {
            value.chequeClearancePeriod = field;
            return this;
        }

        public Builder creditTransClearancePeriod(Short field) {
            value.creditTransClearancePeriod = field;
            return this;
        }

        public Builder casefileType(String field) {
            value.casefileType = field;
            return this;
        }

        public Builder thirdPartyContactId(Long field) {
            value.thirdPartyContactId = field;
            return this;
        }

        public Builder remoReference(String field) {
            value.remoReference = field;
            return this;
        }

        public Builder caReference(String field) {
            value.caReference = field;
            return this;
        }

        public Builder interestFlag(Boolean field) {
            value.interestFlag = field;
            return this;
        }

        public Builder indexation(String field) {
            value.indexation = field;
            return this;
        }

        public Builder paymentArrangement(String field) {
            value.paymentArrangement = field;
            return this;
        }

        public Builder accountComment(String field) {
            value.accountComment = field;
            return this;
        }

        public Builder versionNumber(Long field) {
            value.versionNumber = field;
            return this;
        }

        public PublicationQaRespondent build() {
            return new PublicationQaRespondent(value);
        }
    }
}
