package uk.gov.hmcts.opaltest.publication;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.util.Arrays;
import java.util.List;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/** Scalar test mapping; deliberately outside the application entity-scan package. */
@Entity
@Table(name = "order_terms")
public class PublicationQaOrderTerm {

    @Id
    @Column(name = "order_terms_id", nullable = false)
    private Long orderTermsId;

    @Column(name = "respondent_account_id", nullable = false)
    private Long respondentAccountId;

    @Column(name = "creditor_account_id", nullable = false)
    private Long creditorAccountId;

    @Column(name = "result_id", nullable = false, length = 6)
    private String resultId;

    @Column(name = "posted_date", nullable = false)
    private LocalDateTime postedDate;

    @Column(name = "posted_by", length = 20)
    private String postedBy;

    @Column(name = "posted_by_name", length = 100)
    private String postedByName;

    @Column(name = "original_posted_date")
    private LocalDateTime originalPostedDate;

    @Column(name = "imposed_date", nullable = false)
    private LocalDateTime imposedDate;

    @Column(name = "imposed_amount", nullable = false)
    private BigDecimal imposedAmount;

    @Column(name = "arrears_amount")
    private BigDecimal arrearsAmount;

    @Column(name = "completed", nullable = false)
    private Boolean completed;

    @Column(name = "child_name", length = 100)
    private String childName;

    @Column(name = "child_birth_date")
    private LocalDateTime childBirthDate;

    @Column(name = "expiry_date")
    private LocalDateTime expiryDate;

    @Column(name = "expiry_terms")
    private Boolean expiryTerms;

    @Column(name = "remitted_amount")
    private BigDecimal remittedAmount;

    protected PublicationQaOrderTerm() {
    }

    private PublicationQaOrderTerm(PublicationQaOrderTerm source) {
        orderTermsId = source.orderTermsId;
        respondentAccountId = source.respondentAccountId;
        creditorAccountId = source.creditorAccountId;
        resultId = source.resultId;
        postedDate = source.postedDate;
        postedBy = source.postedBy;
        postedByName = source.postedByName;
        originalPostedDate = source.originalPostedDate;
        imposedDate = source.imposedDate;
        imposedAmount = source.imposedAmount;
        arrearsAmount = source.arrearsAmount;
        completed = source.completed;
        childName = source.childName;
        childBirthDate = source.childBirthDate;
        expiryDate = source.expiryDate;
        expiryTerms = source.expiryTerms;
        remittedAmount = source.remittedAmount;
    }

    public Long getOrderTermsId() {
        return orderTermsId;
    }

    public Long getRespondentAccountId() {
        return respondentAccountId;
    }

    public Long getCreditorAccountId() {
        return creditorAccountId;
    }

    public String getResultId() {
        return resultId;
    }

    public LocalDateTime getPostedDate() {
        return postedDate;
    }

    public String getPostedBy() {
        return postedBy;
    }

    public String getPostedByName() {
        return postedByName;
    }

    public LocalDateTime getOriginalPostedDate() {
        return originalPostedDate;
    }

    public LocalDateTime getImposedDate() {
        return imposedDate;
    }

    public BigDecimal getImposedAmount() {
        return imposedAmount;
    }

    public BigDecimal getArrearsAmount() {
        return arrearsAmount;
    }

    public Boolean getCompleted() {
        return completed;
    }

    public String getChildName() {
        return childName;
    }

    public LocalDateTime getChildBirthDate() {
        return childBirthDate;
    }

    public LocalDateTime getExpiryDate() {
        return expiryDate;
    }

    public Boolean getExpiryTerms() {
        return expiryTerms;
    }

    public BigDecimal getRemittedAmount() {
        return remittedAmount;
    }

    public static Builder builder() {
        return new Builder(new PublicationQaOrderTerm());
    }

    public Builder toBuilder() {
        return new Builder(new PublicationQaOrderTerm(this));
    }

    @Override
    public boolean equals(Object other) {
        return other instanceof PublicationQaOrderTerm row && scalarValues().equals(row.scalarValues());
    }

    @Override
    public int hashCode() {
        return scalarValues().hashCode();
    }

    private List<Object> scalarValues() {
        return Arrays.asList(
            orderTermsId, respondentAccountId, creditorAccountId,
            resultId, postedDate, postedBy,
            postedByName, originalPostedDate, imposedDate,
            imposedAmount, arrearsAmount, completed,
            childName, childBirthDate, expiryDate,
            expiryTerms, remittedAmount
        );
    }

    public static final class Builder {
        private final PublicationQaOrderTerm value;

        private Builder(PublicationQaOrderTerm value) {
            this.value = value;
        }

        public Builder orderTermsId(Long field) {
            value.orderTermsId = field;
            return this;
        }

        public Builder respondentAccountId(Long field) {
            value.respondentAccountId = field;
            return this;
        }

        public Builder creditorAccountId(Long field) {
            value.creditorAccountId = field;
            return this;
        }

        public Builder resultId(String field) {
            value.resultId = field;
            return this;
        }

        public Builder postedDate(LocalDateTime field) {
            value.postedDate = field;
            return this;
        }

        public Builder postedBy(String field) {
            value.postedBy = field;
            return this;
        }

        public Builder postedByName(String field) {
            value.postedByName = field;
            return this;
        }

        public Builder originalPostedDate(LocalDateTime field) {
            value.originalPostedDate = field;
            return this;
        }

        public Builder imposedDate(LocalDateTime field) {
            value.imposedDate = field;
            return this;
        }

        public Builder imposedAmount(BigDecimal field) {
            value.imposedAmount = field;
            return this;
        }

        public Builder arrearsAmount(BigDecimal field) {
            value.arrearsAmount = field;
            return this;
        }

        public Builder completed(Boolean field) {
            value.completed = field;
            return this;
        }

        public Builder childName(String field) {
            value.childName = field;
            return this;
        }

        public Builder childBirthDate(LocalDateTime field) {
            value.childBirthDate = field;
            return this;
        }

        public Builder expiryDate(LocalDateTime field) {
            value.expiryDate = field;
            return this;
        }

        public Builder expiryTerms(Boolean field) {
            value.expiryTerms = field;
            return this;
        }

        public Builder remittedAmount(BigDecimal field) {
            value.remittedAmount = field;
            return this;
        }

        public PublicationQaOrderTerm build() {
            return new PublicationQaOrderTerm(value);
        }
    }
}
