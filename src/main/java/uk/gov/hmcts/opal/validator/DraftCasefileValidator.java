package uk.gov.hmcts.opal.validator;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import tools.jackson.databind.JsonNode;
import uk.gov.hmcts.opal.common.exception.OpalApiException;
import uk.gov.hmcts.opal.entity.CountryEntity;
import uk.gov.hmcts.opal.entity.ResultEntity;
import uk.gov.hmcts.opal.exception.RequestValidationError;
import uk.gov.hmcts.opal.generated.model.DraftCasefileAddRequest;
import uk.gov.hmcts.opal.repository.CountryRepository;
import uk.gov.hmcts.opal.repository.MaintenanceApplicationRepository;
import uk.gov.hmcts.opal.repository.MajorCreditorRepository;
import uk.gov.hmcts.opal.repository.ResultRepository;

import java.util.HashSet;
import java.util.List;
import java.util.Set;

/** Validates reference and relationship facts after OpenAPI structural validation. */
@Component
@RequiredArgsConstructor
public class DraftCasefileValidator {

    private final CountryRepository countries;
    private final MaintenanceApplicationRepository applications;
    private final MajorCreditorRepository creditors;
    private final ResultRepository results;

    public void validate(DraftCasefileAddRequest request) {
        JsonNode casefile = request.getCasefile();
        JsonNode account = casefile.get("respondent_account");
        Short businessUnitId = request.getBusinessUnitId();
        if (businessUnitId.intValue() != account.get("business_unit_id").intValue()) {
            throw invalid("Business Unit values must match");
        }
        if (!request.getCasefileType().getValue().equals(account.get("casefile_type").stringValue())) {
            throw invalid("Casefile types must match");
        }
        validateApplication(account.get("application_code").stringValue());
        if (account.has("central_authority_code")) {
            validateCentralAuthority(businessUnitId, account.get("central_authority_code").stringValue());
        }
        JsonNode respondent = account.get("respondent");
        validatePartyCountries(respondent);
        if (respondent.has("debtor_details")) {
            validateCountry(respondent.get("debtor_details").get("employer_address"));
        }
        validatePartyCountries(casefile.get("applicant"));
        Set<Integer> minorSequences = validateMinorCreditors(casefile);
        for (JsonNode term : account.get("order_details").get("order_terms")) {
            validateOrderTerm(term, businessUnitId, minorSequences);
        }
    }

    private void validateApplication(String code) {
        if (applications.findByApplicationCode(code)
            .filter(application -> Boolean.TRUE.equals(application.getActive())).isEmpty()) {
            throw invalid("Application must identify an active Maintenance Application");
        }
    }

    private void validateCentralAuthority(Short businessUnitId, String code) {
        if (creditors.findByBusinessUnitIdAndMajorCreditorCode(businessUnitId, code)
            .filter(creditor -> Boolean.TRUE.equals(creditor.getActive())
                && Boolean.TRUE.equals(creditor.getCentralAuthority())).isEmpty()) {
            throw invalid("Central Authority must identify an active Central Authority in the Business Unit");
        }
    }

    private void validatePartyCountries(JsonNode party) {
        validateCountry(party.get("party_details").get("address"));
        if (party.has("third_party_details")) {
            validateCountry(party.get("third_party_details").get("address"));
        }
    }

    private void validateCountry(JsonNode address) {
        List<CountryEntity> matches = countries.findByCjsCode(address.get("cjs_code").shortValue());
        if (matches.size() != 1) {
            throw invalid("Country CJS code must identify exactly one Country");
        }
        if (!Boolean.TRUE.equals(matches.getFirst().getActive())) {
            throw invalid("Country must be active");
        }
    }

    private Set<Integer> validateMinorCreditors(JsonNode casefile) {
        Set<Integer> sequences = new HashSet<>();
        for (JsonNode minor : casefile.path("minor_creditors")) {
            if (!sequences.add(minor.get("creditor_sequence").intValue())) {
                throw invalid("Minor Creditor sequences must be unique");
            }
            validateCountry(minor.get("party_details").get("address"));
        }
        return sequences;
    }

    private void validateOrderTerm(JsonNode term, Short businessUnitId, Set<Integer> minorSequences) {
        ResultEntity result = results.findById(term.get("result_id").stringValue())
            .orElseThrow(() -> invalid("Result must identify an existing Result"));
        if (!Boolean.TRUE.equals(result.getActive()) || !Boolean.TRUE.equals(result.getOrderTerm())) {
            throw invalid("Result must be an active Order Term Result");
        }
        if (!Boolean.TRUE.equals(result.getRequiresCreditor())) {
            if (term.has("creditor_type") || term.has("minor_creditor_sequence") || term.has("major_creditor_code")) {
                throw invalid("Creditor fields must be absent when Result requires no creditor");
            }
            return;
        }
        if (!term.has("creditor_type")) {
            throw invalid("Result requires a creditor selection");
        }
        // The schema guarantees Applicant exists and selected sequence/code properties are present.
        if (term.has("minor_creditor_sequence")
            && !minorSequences.contains(term.get("minor_creditor_sequence").intValue())) {
            throw invalid("Minor Creditor sequence must identify a submitted Minor Creditor");
        }
        if (term.has("major_creditor_code")) {
            validateMajorCreditor(businessUnitId, term.get("major_creditor_code").stringValue());
        }
    }

    private void validateMajorCreditor(Short businessUnitId, String code) {
        if (creditors.findByBusinessUnitIdAndMajorCreditorCode(businessUnitId, code)
            .filter(creditor -> Boolean.TRUE.equals(creditor.getActive())).isEmpty()) {
            throw invalid("Major Creditor must identify an active creditor in the Business Unit");
        }
    }

    private static OpalApiException invalid(String detail) {
        return new OpalApiException(RequestValidationError.INVALID_REQUEST, detail);
    }
}
