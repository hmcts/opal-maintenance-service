package uk.gov.hmcts.opal.validator;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.http.HttpStatus;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;
import tools.jackson.databind.node.ObjectNode;
import uk.gov.hmcts.opal.common.exception.OpalApiException;
import uk.gov.hmcts.opal.entity.CountryEntity;
import uk.gov.hmcts.opal.entity.MaintenanceApplicationEntity;
import uk.gov.hmcts.opal.entity.MajorCreditorEntity;
import uk.gov.hmcts.opal.entity.ResultEntity;
import uk.gov.hmcts.opal.exception.DraftCasefileError;
import uk.gov.hmcts.opal.generated.model.DraftCasefileAddRequest;
import uk.gov.hmcts.opal.repository.CountryRepository;
import uk.gov.hmcts.opal.repository.MaintenanceApplicationRepository;
import uk.gov.hmcts.opal.repository.MajorCreditorRepository;
import uk.gov.hmcts.opal.repository.ResultRepository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.catchThrowableOfType;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class DraftCasefileValidatorTest {

    private static final JsonMapper MAPPER = JsonMapper.builder().build();
    private final CountryRepository countries = mock(CountryRepository.class);
    private final MaintenanceApplicationRepository applications = mock(MaintenanceApplicationRepository.class);
    private final MajorCreditorRepository creditors = mock(MajorCreditorRepository.class);
    private final ResultRepository results = mock(ResultRepository.class);
    private final DraftCasefileValidator validator =
        new DraftCasefileValidator(countries, applications, creditors, results);
    private DraftCasefileAddRequest request;

    @BeforeEach
    void validReferences() {
        request = MAPPER.readValue("""
            {"business_unit_id":1,"casefile_type":"REMO In","casefile":{
              "respondent_account":{"business_unit_id":1,"casefile_type":"REMO In","application_code":"SYNTH",
                "respondent":{"party_details":{"organisation":false,"individual_details":{"surname":"Synthetic"},
                  "address":{"address_line_1":"Synthetic address","cjs_code":1}}},
                "order_details":{"date_ordered":"2026-08-01","date_arrears_last_updated":"2026-08-02",
                  "interest_flag":false,"indexation":"None","payment_arrangement":"Court","payment_period":"Monthly",
                  "order_terms":[{"result_id":"SYNTH","result_responses":[
                    {"parameter_name":"Arbitrary","response":"not a number or date"}]}]}},
              "applicant":{"party_details":{"organisation":false,"individual_details":{"surname":"Synthetic"},
                "address":{"address_line_1":"Synthetic address","cjs_code":1}},
                "bank_account_details":{"bank_account_type":"None or not applicable"}}}}
            """, DraftCasefileAddRequest.class);
        when(countries.findByCjsCode((short) 1)).thenReturn(List.of(CountryEntity.builder().active(true).build()));
        when(applications.findByApplicationCode("SYNTH")).thenReturn(Optional.of(
            MaintenanceApplicationEntity.builder().active(true).applicationGroup("Other").build()));
        result(true, true, false);
    }

    @Test
    void acceptsOmittedOptionalObjectsAndUninterpretedResultResponsesWithoutChangingInput() {
        assertAcceptedUnchanged();
    }

    @ParameterizedTest
    @CsvSource({"business_unit_id,2", "casefile_type,REMO Out"})
    void rejectsConflictingEnvelopeValuesToPreventInconsistentOwnership(String field, String value) {
        if (field.equals("business_unit_id")) {
            account().put(field, Integer.parseInt(value));
        } else {
            account().put(field, value);
        }
        assertInvalid(field.equals("business_unit_id")
            ? "Business Unit values must match" : "Casefile types must match");
    }

    @ParameterizedTest
    @ValueSource(booleans = {true, false})
    void rejectsMissingOrInactiveApplicationToPreventPublishingUnselectableCode(boolean missing) {
        when(applications.findByApplicationCode("SYNTH")).thenReturn(missing ? Optional.empty()
            : Optional.of(MaintenanceApplicationEntity.builder().active(false).build()));
        assertInvalid("Application must identify an active Maintenance Application");
    }

    @ParameterizedTest
    @ValueSource(strings = {"respondent", "applicant", "minor", "employer",
        "respondentThirdParty", "applicantThirdParty"})
    void rejectsUnknownCountryAtEveryReferencePathToPreventUnresolvablePublication(String path) {
        countryAddress(path).put("cjs_code", 2);
        when(countries.findByCjsCode((short) 2)).thenReturn(List.of());
        assertInvalid("Country CJS code must identify exactly one Country");
    }

    @Test
    void rejectsInactiveCountryToPreventRetiredSelection() {
        when(countries.findByCjsCode((short) 1)).thenReturn(List.of(CountryEntity.builder().active(false).build()));
        assertInvalid("Country must be active");
    }

    @Test
    void rejectsAmbiguousCountryEvenWhenOnlyOneMatchingRowIsActive() {
        when(countries.findByCjsCode((short) 1)).thenReturn(List.of(
            CountryEntity.builder().active(true).build(), CountryEntity.builder().active(false).build()));
        assertInvalid("Country CJS code must identify exactly one Country");
    }

    @ParameterizedTest
    @CsvSource({"2999-01-01,2999-12-31", "1990-01-01,1991-01-01"})
    void acceptsActiveCountriesRegardlessOfEffectiveDates(String from, String to) {
        when(countries.findByCjsCode((short) 1)).thenReturn(List.of(CountryEntity.builder().active(true)
            .dateUsedFrom(LocalDate.parse(from)).dateUsedTo(LocalDate.parse(to)).build()));
        assertAcceptedUnchanged();
    }

    @ParameterizedTest
    @ValueSource(strings = {"missing", "wrongBu", "inactive", "notAuthority"})
    void rejectsInvalidAuthorityToPreventMisroutingCentralAuthority(String scenario) {
        account().put("central_authority_code", "SYN");
        if (scenario.equals("wrongBu")) {
            when(creditors.findByBusinessUnitIdAndMajorCreditorCode((short) 2, "SYN"))
                .thenReturn(Optional.of(creditor(true, true)));
        } else if (!scenario.equals("missing")) {
            when(creditors.findByBusinessUnitIdAndMajorCreditorCode((short) 1, "SYN"))
                .thenReturn(Optional.of(creditor(!scenario.equals("inactive"), !scenario.equals("notAuthority"))));
        }
        assertInvalid("Central Authority must identify an active Central Authority in the Business Unit");
    }

    @Test
    void acceptsActiveCentralAuthorityInOwningBusinessUnit() {
        account().put("central_authority_code", "SYN");
        when(creditors.findByBusinessUnitIdAndMajorCreditorCode((short) 1, "SYN"))
            .thenReturn(Optional.of(creditor(true, true)));
        assertAcceptedUnchanged();
    }

    @Test
    void rejectsMissingResultToPreventUnresolvableOrderTerm() {
        when(results.findById("SYNTH")).thenReturn(Optional.empty());
        assertInvalid("Result must identify an existing Result");
    }

    @ParameterizedTest
    @CsvSource({"false,true", "true,false", "false,false"})
    void rejectsInactiveOrNonOrderResultToPreventInappropriateOrderTerm(boolean active, boolean orderTerm) {
        result(active, orderTerm, false);
        assertInvalid("Result must be an active Order Term Result");
    }

    @Test
    void rejectsMissingCreditorSelectionForResultRequiringCreditor() {
        result(true, true, true);
        assertInvalid("Result requires a creditor selection");
    }

    @Test
    void acceptsApplicantSelectionWithSubmittedApplicant() {
        result(true, true, true);
        term().put("creditor_type", "Applicant");
        assertAcceptedUnchanged();
    }

    @Test
    void rejectsDuplicateMinorIdentifiersToPreventAmbiguousCreditorAssignment() {
        addMinor();
        ((ObjectNode) request.getCasefile()).withArray("minor_creditors").add(minor().deepCopy());
        assertInvalid("Minor Creditor sequences must be unique");
    }

    @Test
    void rejectsDanglingMinorLinkToPreventUnresolvableCreditorAssignment() {
        result(true, true, true);
        term().put("creditor_type", "Minor Creditor").put("minor_creditor_sequence", 1);
        assertInvalid("Minor Creditor sequence must identify a submitted Minor Creditor");
    }

    @Test
    void acceptsMinorCreditorSelectionByIdentifierRatherThanPosition() {
        addMinor();
        minor().put("creditor_sequence", Integer.MAX_VALUE);
        result(true, true, true);
        term().put("creditor_type", "Minor Creditor").put("minor_creditor_sequence", Integer.MAX_VALUE);
        assertAcceptedUnchanged();
    }

    @ParameterizedTest
    @ValueSource(strings = {"missing", "wrongBu", "inactive"})
    void rejectsInvalidMajorCreditorToPreventIncorrectPaymentDestination(String scenario) {
        result(true, true, true);
        term().put("creditor_type", "Major Creditor").put("major_creditor_code", "SYN");
        if (scenario.equals("wrongBu")) {
            when(creditors.findByBusinessUnitIdAndMajorCreditorCode((short) 2, "SYN"))
                .thenReturn(Optional.of(creditor(true, false)));
        } else if (scenario.equals("inactive")) {
            when(creditors.findByBusinessUnitIdAndMajorCreditorCode((short) 1, "SYN"))
                .thenReturn(Optional.of(creditor(false, false)));
        }
        assertInvalid("Major Creditor must identify an active creditor in the Business Unit");
    }

    @Test
    void acceptsActiveMajorCreditorWithoutImposingCentralAuthorityCategory() {
        result(true, true, true);
        term().put("creditor_type", "Major Creditor").put("major_creditor_code", "SYN");
        when(creditors.findByBusinessUnitIdAndMajorCreditorCode((short) 1, "SYN"))
            .thenReturn(Optional.of(creditor(true, false)));
        assertAcceptedUnchanged();
    }

    @ParameterizedTest
    @CsvSource({"creditor_type,Applicant", "minor_creditor_sequence,1", "major_creditor_code,SYN"})
    void rejectsEveryCreditorFieldWhenResultRequiresNone(String field, String value) {
        if (field.equals("minor_creditor_sequence")) {
            term().put(field, Integer.parseInt(value));
        } else {
            term().put(field, value);
        }
        assertInvalid("Creditor fields must be absent when Result requires no creditor");
    }

    @Test
    void validatesEveryOrderTermRatherThanOnlyFirst() {
        ObjectNode second = term().deepCopy();
        second.put("result_id", "ABSENT");
        ((ObjectNode) account().get("order_details")).withArray("order_terms").add(second);
        assertInvalid("Result must identify an existing Result");
    }

    @Test
    void acceptsSuppliedReferencesAlongsideAnotherCreditorSelection() {
        result(true, true, true);
        addMinor();
        term().put("creditor_type", "Applicant").put("minor_creditor_sequence", 1).put("major_creditor_code", "SYN");
        when(creditors.findByBusinessUnitIdAndMajorCreditorCode((short) 1, "SYN"))
            .thenReturn(Optional.of(creditor(true, false)));
        assertAcceptedUnchanged();
    }

    @Test
    void rejectsDanglingSuppliedMinorLinkAlongsideApplicantSelection() {
        result(true, true, true);
        term().put("creditor_type", "Applicant").put("minor_creditor_sequence", 1);
        assertInvalid("Minor Creditor sequence must identify a submitted Minor Creditor");
    }

    @Test
    void rejectsUnknownSuppliedMajorCodeAlongsideApplicantSelection() {
        result(true, true, true);
        term().put("creditor_type", "Applicant").put("major_creditor_code", "SYN");
        assertInvalid("Major Creditor must identify an active creditor in the Business Unit");
    }

    @ParameterizedTest
    @ValueSource(strings = {"respondent", "applicant", "minor", "employer",
        "respondentThirdParty", "applicantThirdParty"})
    void acceptsValidCountriesInOptionalAndRequiredPaths(String path) {
        countryAddress(path);
        assertAcceptedUnchanged();
    }

    private void assertAcceptedUnchanged() {
        JsonNode original = request.getCasefile().deepCopy();
        assertThatCode(() -> validator.validate(request)).doesNotThrowAnyException();
        assertThat(request.getCasefile()).isEqualTo(original);
    }

    private void assertInvalid(String detail) {
        JsonNode original = request.getCasefile().deepCopy();
        OpalApiException exception = catchThrowableOfType(OpalApiException.class, () -> validator.validate(request));
        assertThat(exception).isNotNull();
        assertThat(exception.getError()).isEqualTo(DraftCasefileError.INVALID_REQUEST);
        assertThat(exception.getError().getHttpStatus()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(exception.getError().getErrorTypePrefix()).isEqualTo("DRAFT_CASEFILE");
        assertThat(exception.getError().getErrorTypeNumeric()).isEqualTo("001");
        assertThat(exception.getError().getTitle()).isEqualTo("Invalid Draft Casefile request");
        assertThat(exception.getDetail()).isEqualTo(detail);
        assertThat(request.getCasefile()).isEqualTo(original);
    }

    private void result(boolean active, boolean orderTerm, boolean requiresCreditor) {
        when(results.findById("SYNTH")).thenReturn(Optional.of(ResultEntity.builder().active(active)
            .orderTerm(orderTerm).requiresCreditor(requiresCreditor)
            .resultParameters("{\"amount\":{\"required\":true},\"ordersHidden\":true}").build()));
    }

    private static MajorCreditorEntity creditor(boolean active, boolean authority) {
        return MajorCreditorEntity.builder().active(active).centralAuthority(authority).build();
    }

    private ObjectNode account() {
        return (ObjectNode) request.getCasefile().get("respondent_account");
    }

    private ObjectNode term() {
        return (ObjectNode) account().at("/order_details/order_terms/0");
    }

    private ObjectNode minor() {
        return (ObjectNode) request.getCasefile().at("/minor_creditors/0");
    }

    private void addMinor() {
        ObjectNode minor = (ObjectNode) request.getCasefile().get("applicant").deepCopy();
        minor.put("creditor_sequence", 1);
        ((ObjectNode) request.getCasefile()).putArray("minor_creditors").add(minor);
    }

    private ObjectNode countryAddress(String path) {
        ObjectNode respondent = (ObjectNode) account().get("respondent");
        ObjectNode applicant = (ObjectNode) request.getCasefile().get("applicant");
        if (path.equals("minor")) {
            addMinor();
            return (ObjectNode) minor().at("/party_details/address");
        }
        if (path.equals("employer")) {
            ObjectNode details = respondent.putObject("debtor_details").put("employer_name", "Synthetic employer");
            details.set("employer_address", applicant.at("/party_details/address").deepCopy());
            return (ObjectNode) details.get("employer_address");
        }
        if (path.endsWith("ThirdParty")) {
            ObjectNode party = path.equals("respondentThirdParty") ? respondent : applicant;
            ObjectNode details = party.putObject("third_party_details").put("name", "Synthetic contact")
                .put("relationship", "Synthetic relationship");
            details.set("address", applicant.at("/party_details/address").deepCopy());
            return (ObjectNode) details.get("address");
        }
        return (ObjectNode) (path.equals("respondent") ? respondent : applicant).at("/party_details/address");
    }
}
