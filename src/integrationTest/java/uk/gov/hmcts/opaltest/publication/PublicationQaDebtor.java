package uk.gov.hmcts.opaltest.publication;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.util.Arrays;
import java.util.List;

/** Scalar test mapping; deliberately outside the application entity-scan package. */
@Entity
@Table(name = "debtor_detail")
public class PublicationQaDebtor {

    @Id
    @Column(name = "debtor_detail_id", nullable = false)
    private Long debtorDetailId;

    @Column(name = "employer_name", length = 50)
    private String employerName;

    @Column(name = "employer_address_line_1", length = 35)
    private String employerAddressLine1;

    @Column(name = "employer_address_line_2", length = 35)
    private String employerAddressLine2;

    @Column(name = "employer_address_line_3", length = 35)
    private String employerAddressLine3;

    @Column(name = "employer_address_line_4", length = 35)
    private String employerAddressLine4;

    @Column(name = "employer_address_line_5", length = 35)
    private String employerAddressLine5;

    @Column(name = "employer_postcode", length = 10)
    private String employerPostcode;

    @Column(name = "employer_country_id")
    private Long employerCountryId;

    @Column(name = "employee_reference", length = 35)
    private String employeeReference;

    @Column(name = "employer_telephone", length = 35)
    private String employerTelephone;

    @Column(name = "employer_email", length = 80)
    private String employerEmail;

    @Column(name = "other_personal_information", length = 200)
    private String otherPersonalInformation;

    protected PublicationQaDebtor() {
    }

    private PublicationQaDebtor(PublicationQaDebtor source) {
        debtorDetailId = source.debtorDetailId;
        employerName = source.employerName;
        employerAddressLine1 = source.employerAddressLine1;
        employerAddressLine2 = source.employerAddressLine2;
        employerAddressLine3 = source.employerAddressLine3;
        employerAddressLine4 = source.employerAddressLine4;
        employerAddressLine5 = source.employerAddressLine5;
        employerPostcode = source.employerPostcode;
        employerCountryId = source.employerCountryId;
        employeeReference = source.employeeReference;
        employerTelephone = source.employerTelephone;
        employerEmail = source.employerEmail;
        otherPersonalInformation = source.otherPersonalInformation;
    }

    public Long getDebtorDetailId() {
        return debtorDetailId;
    }

    public String getEmployerName() {
        return employerName;
    }

    public String getEmployerAddressLine1() {
        return employerAddressLine1;
    }

    public String getEmployerAddressLine2() {
        return employerAddressLine2;
    }

    public String getEmployerAddressLine3() {
        return employerAddressLine3;
    }

    public String getEmployerAddressLine4() {
        return employerAddressLine4;
    }

    public String getEmployerAddressLine5() {
        return employerAddressLine5;
    }

    public String getEmployerPostcode() {
        return employerPostcode;
    }

    public Long getEmployerCountryId() {
        return employerCountryId;
    }

    public String getEmployeeReference() {
        return employeeReference;
    }

    public String getEmployerTelephone() {
        return employerTelephone;
    }

    public String getEmployerEmail() {
        return employerEmail;
    }

    public String getOtherPersonalInformation() {
        return otherPersonalInformation;
    }

    public static Builder builder() {
        return new Builder(new PublicationQaDebtor());
    }

    public Builder toBuilder() {
        return new Builder(new PublicationQaDebtor(this));
    }

    @Override
    public boolean equals(Object other) {
        return other instanceof PublicationQaDebtor row && scalarValues().equals(row.scalarValues());
    }

    @Override
    public int hashCode() {
        return scalarValues().hashCode();
    }

    private List<Object> scalarValues() {
        return Arrays.asList(
            debtorDetailId, employerName, employerAddressLine1,
            employerAddressLine2, employerAddressLine3, employerAddressLine4,
            employerAddressLine5, employerPostcode, employerCountryId,
            employeeReference, employerTelephone, employerEmail,
            otherPersonalInformation
        );
    }

    public static final class Builder {
        private final PublicationQaDebtor value;

        private Builder(PublicationQaDebtor value) {
            this.value = value;
        }

        public Builder debtorDetailId(Long field) {
            value.debtorDetailId = field;
            return this;
        }

        public Builder employerName(String field) {
            value.employerName = field;
            return this;
        }

        public Builder employerAddressLine1(String field) {
            value.employerAddressLine1 = field;
            return this;
        }

        public Builder employerAddressLine2(String field) {
            value.employerAddressLine2 = field;
            return this;
        }

        public Builder employerAddressLine3(String field) {
            value.employerAddressLine3 = field;
            return this;
        }

        public Builder employerAddressLine4(String field) {
            value.employerAddressLine4 = field;
            return this;
        }

        public Builder employerAddressLine5(String field) {
            value.employerAddressLine5 = field;
            return this;
        }

        public Builder employerPostcode(String field) {
            value.employerPostcode = field;
            return this;
        }

        public Builder employerCountryId(Long field) {
            value.employerCountryId = field;
            return this;
        }

        public Builder employeeReference(String field) {
            value.employeeReference = field;
            return this;
        }

        public Builder employerTelephone(String field) {
            value.employerTelephone = field;
            return this;
        }

        public Builder employerEmail(String field) {
            value.employerEmail = field;
            return this;
        }

        public Builder otherPersonalInformation(String field) {
            value.otherPersonalInformation = field;
            return this;
        }

        public PublicationQaDebtor build() {
            return new PublicationQaDebtor(value);
        }
    }
}
