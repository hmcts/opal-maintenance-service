package uk.gov.hmcts.opal.support.publication;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.repository.CountryRepository;
import uk.gov.hmcts.opal.repository.MaintenanceApplicationRepository;
import uk.gov.hmcts.opal.repository.MajorCreditorRepository;
import uk.gov.hmcts.opaltest.publication.PublicationQaAlias;
import uk.gov.hmcts.opaltest.publication.PublicationQaContact;
import uk.gov.hmcts.opaltest.publication.PublicationQaCreditor;
import uk.gov.hmcts.opaltest.publication.PublicationQaDebtor;
import uk.gov.hmcts.opaltest.publication.PublicationQaOrderTerm;
import uk.gov.hmcts.opaltest.publication.PublicationQaParty;
import uk.gov.hmcts.opaltest.publication.PublicationQaRespondent;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;

import static uk.gov.hmcts.opal.support.publication.PublicationQaGraph.require;

/** Input-derived backend graph assertions, deliberately separate from the database routine's field-contract suite. */
final class PublicationQaGraphAssertions {

    private final ObjectMapper json;
    private final CountryRepository countries;
    private final MaintenanceApplicationRepository applications;
    private final MajorCreditorRepository majors;

    PublicationQaGraphAssertions(ObjectMapper json, CountryRepository countries,
                                 MaintenanceApplicationRepository applications, MajorCreditorRepository majors) {
        this.json = json;
        this.countries = countries;
        this.applications = applications;
        this.majors = majors;
    }

    void assertPublished(PublicationQaGraph.Snapshot added, DraftCasefileEntity draft, JsonNode input) {
        require(draft.getCasefileStatus() == DraftCasefileStatus.PUBLISHED
            && input.equals(json.readTree(draft.getCasefile())), "Publication must preserve submitted data");
        JsonNode respondentInput = input.path("respondent_account");
        require(added.respondents().size() == 1, "Publication must insert exactly one respondent");
        PublicationQaRespondent respondent = added.respondents().values().iterator().next();
        require(positive(respondent.getRespondentAccountId())
            && Objects.equals(draft.getAccountId(), respondent.getRespondentAccountId())
            && Objects.equals(draft.getAccountNumber(), respondent.getAccountNumber())
            && Objects.equals(draft.getBusinessUnitId(), respondent.getBusinessUnitId()),
            "Draft respondent link differs from the inserted graph");
        required(respondent.getRemoReference(), respondentInput, "remo_reference");
        require(respondent.getRemoReference().matches("E2E-[0-9a-f]{16}"), "Published respondent marker differs");
        respondent(respondent, respondentInput);
        JsonNode snapshot = json.readTree(draft.getCasefileSnapshot());
        identity(snapshot.path("respondent_account"), respondent.getRespondentAccountId(),
            respondent.getAccountNumber());
        Expected expected = new Expected();
        Long respondentParty = association(added, respondent.getRespondentAccountId(), "Respondent");
        party(added, respondentParty, respondentInput.at("/respondent/party_details"), "Respondent", expected);
        PublicationQaCreditor applicant = account(added, snapshot.path("applicant_account"), draft.getBusinessUnitId());
        require(Objects.equals(association(added, respondent.getRespondentAccountId(), "Applicant"),
            applicant.getCreditorAccountId()), "Applicant association differs from the published identity");
        minor(added, applicant, input.path("applicant"), expected);
        Map<Integer, Long> minors = minors(added, snapshot, input, draft.getBusinessUnitId(), expected);
        orders(added, input, respondent, applicant.getCreditorAccountId(), minors, expected);
        require(added.creditors().keySet().equals(expected.creditors), "Unexpected or missing creditor accounts");
        require(added.parties().keySet().equals(expected.parties), "Unexpected or missing party rows");
        require(added.aliases().keySet().equals(expected.aliases), "Unexpected or missing alias rows");
        debtor(added, respondent, respondentInput.path("respondent"));
        contact(added, respondent.getThirdPartyContactId(),
            respondentInput.at("/respondent/third_party_details"), expected);
        contact(added, applicant.getThirdPartyContactId(), input.at("/applicant/third_party_details"), expected);
        require(added.contacts().keySet().equals(expected.contacts), "Unexpected or missing third-party contacts");
        notes(added, respondent, respondentInput.path("notes"), draft);
        associations(added, respondent, respondentInput);
        reservations(added, respondent);
    }

    void assertMinorParty(PublicationQaGraph.Snapshot rows, Long partyId, JsonNode input) {
        party(rows, partyId, input, "Minor Creditor", new Expected());
    }

    private void respondent(PublicationQaRespondent row, JsonNode input) {
        var application = applications.findByApplicationCode(input.path("application_code").asString());
        require(application.isPresent() && Objects.equals(row.getApplicationId(), application.get().getApplicationId()),
            "Respondent application does not match the supplied business code");
        required(row.getCasefileType(), input, "casefile_type");
        optional(row.getOriginatorName(), input, "originator_name");
        optional(row.getCaReference(), input, "central_authority_reference");
        optional(row.getAccountComment(), input, "account_comment");
        JsonNode order = input.path("order_details");
        required(row.getPaymentPeriod(), order, "payment_period");
        required(row.getIndexation(), order, "indexation");
        required(row.getPaymentArrangement(), order, "payment_arrangement");
        require(Objects.equals(row.getInterestFlag(), order.path("interest_flag").booleanValue()),
            "Respondent interest setting differs");
        require(row.getImposedHearingDate() != null
            && row.getImposedHearingDate().toLocalDate().equals(LocalDate.parse(order.path("date_ordered").asString()))
            && row.getDateArrearsLastUpdated() != null && row.getDateArrearsLastUpdated().toLocalDate()
                .equals(LocalDate.parse(order.path("date_arrears_last_updated").asString())),
            "Respondent order dates differ");
        require("L".equals(row.getAccountStatus()) && zero(row.getAccountBalance())
            && row.getOrdersAmount() != null && row.getOrdersBalance() != null && row.getTotalArrears() != null,
            "Published respondent must have live status and initial financial values");
    }

    private Map<Integer, Long> minors(PublicationQaGraph.Snapshot rows, JsonNode snapshot, JsonNode input,
                                     Short businessUnit, Expected expected) {
        Map<Integer, JsonNode> submitted = new HashMap<>();
        input.path("minor_creditors").forEach(minor -> require(
            submitted.put(minor.path("creditor_sequence").intValue(), minor) == null,
            "Submitted minor sequences must be unique"));
        Map<Integer, Long> result = new HashMap<>();
        require(snapshot.path("minor_creditor_accounts").isArray(), "Published minor identities must be an array");
        snapshot.path("minor_creditor_accounts").forEach(identity -> {
            JsonNode sequence = identity.path("creditor_sequence");
            require(sequence.isIntegralNumber() && sequence.canConvertToInt() && sequence.intValue() > 0,
                "Published minor sequence must be a positive integer");
            int key = sequence.intValue();
            require(submitted.containsKey(key) && !result.containsKey(key), "Published minor sequence differs");
            PublicationQaCreditor creditor = account(rows, identity, businessUnit);
            minor(rows, creditor, submitted.get(key), expected);
            result.put(key, creditor.getCreditorAccountId());
        });
        require(result.keySet().equals(submitted.keySet()), "Published minors must match all submitted sequences");
        return result;
    }

    private void minor(PublicationQaGraph.Snapshot rows, PublicationQaCreditor creditor, JsonNode input,
                       Expected expected) {
        require("MN".equals(creditor.getCreditorAccountType()) && creditor.getMajorCreditorId() == null
            && positive(creditor.getMinorCreditorPartyId()) && expected.creditors.add(creditor.getCreditorAccountId()),
            "Minor creditor identity or type differs");
        party(rows, creditor.getMinorCreditorPartyId(), input.path("party_details"), "Minor Creditor", expected);
        JsonNode bank = input.path("bank_account_details");
        require(Boolean.valueOf("UK Bank".equals(bank.path("bank_account_type").asString()))
            .equals(creditor.getPayByBacs()), "Minor creditor payment method differs");
        if ("UK Bank".equals(bank.path("bank_account_type").asString())) {
            required(creditor.getBankSortCode(), bank.path("uk_bank_details"), "sort_code");
            required(creditor.getBankAccountNumber(), bank.path("uk_bank_details"), "account_number");
            required(creditor.getBankAccountName(), bank.path("uk_bank_details"), "account_name");
            required(creditor.getBankAccountReference(), bank.path("uk_bank_details"), "payment_reference");
        } else if ("Non-UK Bank".equals(bank.path("bank_account_type").asString())) {
            require(creditor.getNonUkBankDetail() != null
                && bank.path("non_uk_bank_details").equals(json.readTree(creditor.getNonUkBankDetail())),
                "Non-UK bank details differ");
        }
        if (input.has("creditor_sequence")) {
            require(creditor.getThirdPartyContactId() == null, "Minor creditor has an unexpected third-party contact");
        }
    }

    private PublicationQaCreditor account(PublicationQaGraph.Snapshot rows, JsonNode identity, Short unit) {
        JsonNode id = identity.path("account_id");
        require(id.isIntegralNumber() && id.canConvertToLong() && id.longValue() > 0,
            "Published creditor identity must be a positive bigint");
        PublicationQaCreditor row = rows.creditors().get(id.longValue());
        require(row != null && Objects.equals(unit, row.getBusinessUnitId())
            && Boolean.FALSE.equals(row.getFromSuspense())
            && Boolean.FALSE.equals(row.getHoldPayout()), "Published creditor row or initial flags differ");
        identity(identity, row.getCreditorAccountId(), row.getAccountNumber());
        return row;
    }

    private void party(PublicationQaGraph.Snapshot rows, Long id, JsonNode input, String accountType,
        Expected expected) {
        require(positive(id) && expected.parties.add(id), "Party identities must be distinct");
        PublicationQaParty row = rows.parties().get(id);
        require(row != null && Objects.equals(row.getOrganisation(), input.path("organisation").booleanValue())
            && accountType.equals(row.getAccountType()), "Published party role differs");
        JsonNode individual = input.path("individual_details");
        JsonNode organisation = input.path("organisation_details");
        if (input.path("organisation").booleanValue()) {
            required(row.getOrganisationName(), organisation, "organisation_name");
            optional(row.getForeignAuthorityReference(), organisation, "foreign_authority_reference");
        } else {
            required(row.getSurname(), individual, "surname");
            optional(row.getForenames(), individual, "forenames");
            optional(row.getNationalInsuranceNumber(), individual, "national_insurance_number");
        }
        required(row.getAddressLine1(), input.path("address"), "address_line_1");
        require(Objects.equals(row.getCountryId(), country(input.path("address"))), "Party country resolution differs");
        input.path("aliases").forEach(alias -> {
            List<PublicationQaAlias> matches = rows.aliases().values().stream().filter(candidate ->
                id.equals(candidate.getPartyId()) && Objects.equals(candidate.getSequenceNumber(),
                    alias.path("sequence_number").intValue())).toList();
            require(matches.size() == 1 && expected.aliases.add(matches.getFirst().getAliasId()),
                "Alias sequence or party link differs");
            PublicationQaAlias actual = matches.getFirst();
            optional(actual.getSurname(), alias, "surname");
            optional(actual.getForenames(), alias, "forenames");
            optional(actual.getOrganisationName(), alias, "organisation_name");
        });
    }

    private void orders(PublicationQaGraph.Snapshot rows, JsonNode input, PublicationQaRespondent respondent,
                        Long applicant, Map<Integer, Long> minors, Expected expected) {
        List<PublicationQaOrderTerm> remaining = new ArrayList<>(rows.orderTerms().values());
        Map<String, Long> majorAccounts = new HashMap<>();
        input.at("/respondent_account/order_details/order_terms").forEach(term -> {
            Long creditor = switch (term.path("creditor_type").asString()) {
                case "Applicant" -> applicant;
                case "Minor Creditor" -> minors.get(term.path("minor_creditor_sequence").intValue());
                case "Major Creditor" -> majorAccounts.computeIfAbsent(term.path("major_creditor_code").asString(),
                    code -> major(rows, respondent.getBusinessUnitId(), code, expected));
                default -> null;
            };
            require(positive(creditor), "Order term creditor is unresolved");
            BigDecimal amount = responseAmount(term, "Amount");
            BigDecimal arrears = responseAmount(term, "Arrears");
            expected.orderAmount = expected.orderAmount.add(amount);
            expected.arrears = expected.arrears.add(arrears);
            PublicationQaOrderTerm match = remaining.stream().filter(row ->
                creditor.equals(row.getCreditorAccountId())
                    && term.path("result_id").asString().equals(row.getResultId())
                    && equalAmount(row.getImposedAmount(), amount)
                    && equalAmount(orZero(row.getArrearsAmount()), arrears))
                .findFirst().orElse(null);
            require(match != null && respondent.getRespondentAccountId().equals(match.getRespondentAccountId())
                && match.getImposedDate() != null && match.getImposedDate().toLocalDate()
                    .equals(respondent.getImposedHearingDate().toLocalDate())
                && Boolean.FALSE.equals(match.getCompleted()),
                "Order term values or respondent/creditor relationships differ");
            remaining.remove(match);
        });
        require(remaining.isEmpty(), "Publication inserted unexpected order terms");
        require(equalAmount(respondent.getOrdersAmount(), expected.orderAmount)
            && equalAmount(respondent.getTotalArrears(), expected.arrears),
            "Respondent financial totals differ from independently checked input order amounts");
    }

    private BigDecimal responseAmount(JsonNode term, String parameter) {
        List<String> responses = new ArrayList<>();
        term.path("result_responses").forEach(response -> {
            if (parameter.equals(response.path("parameter_name").asString())) {
                responses.add(response.path("response").asString());
            }
        });
        require(responses.size() <= 1, "Order financial input is ambiguous");
        try {
            return responses.isEmpty() ? BigDecimal.ZERO : new BigDecimal(responses.getFirst());
        } catch (NumberFormatException exception) {
            throw new AssertionError("Order financial input must be numeric");
        }
    }

    private static BigDecimal orZero(BigDecimal value) {
        return value == null ? BigDecimal.ZERO : value;
    }

    private Long major(PublicationQaGraph.Snapshot rows, Short unit, String code, Expected expected) {
        var reference = majors.findByBusinessUnitIdAndMajorCreditorCode(unit, code);
        require(reference.isPresent(), "Major creditor business code is unresolved");
        var matches = rows.creditors().values().stream().filter(row -> Objects.equals(row.getBusinessUnitId(), unit)
            && Objects.equals(row.getMajorCreditorId(), reference.get().getMajorCreditorId())).toList();
        require(matches.size() == 1, "Repeated major creditor selections must share exactly one account");
        PublicationQaCreditor row = matches.getFirst();
        require(positive(row.getCreditorAccountId()) && "MJ".equals(row.getCreditorAccountType())
            && Boolean.FALSE.equals(row.getPayByBacs())
            && Boolean.FALSE.equals(row.getFromSuspense()) && Boolean.FALSE.equals(row.getHoldPayout())
            && row.getMinorCreditorPartyId() == null && expected.creditors.add(row.getCreditorAccountId()),
            "Major creditor account type, flags or identity differ");
        return row.getCreditorAccountId();
    }

    private void debtor(PublicationQaGraph.Snapshot rows, PublicationQaRespondent respondent, JsonNode input) {
        JsonNode source = input.path("debtor_details");
        JsonNode other = input.at("/party_details/individual_details/other_personal_information");
        boolean present = source.isObject() || other.isString();
        require(rows.debtors().size() == (present ? 1 : 0), "Unexpected or missing debtor details");
        if (present) {
            require(positive(respondent.getDebtorDetailId()), "Respondent debtor link is missing");
            PublicationQaDebtor row = rows.debtors().get(respondent.getDebtorDetailId());
            require(row != null, "Respondent debtor details are missing");
            if (source.isObject()) {
                required(row.getEmployerName(), source, "employer_name");
                required(row.getEmployerAddressLine1(), source.path("employer_address"), "address_line_1");
                require(Objects.equals(row.getEmployerCountryId(), country(source.path("employer_address"))),
                    "Employer country resolution differs");
                optional(row.getEmployeeReference(), source, "employee_reference");
            }
            if (other.isString()) {
                require(other.stringValue().equals(row.getOtherPersonalInformation()),
                    "Other respondent details differ");
            }
        } else {
            require(respondent.getDebtorDetailId() == null, "Unexpected respondent debtor link");
        }
    }

    private void contact(PublicationQaGraph.Snapshot rows, Long id, JsonNode input, Expected expected) {
        if (!input.isObject()) {
            require(id == null, "Unexpected third-party contact link");
            return;
        }
        require(positive(id) && expected.contacts.add(id), "Third-party contact identity differs");
        PublicationQaContact row = rows.contacts().get(id);
        require(row != null, "Third-party contact row is missing");
        required(row.getNameOrganisation(), input, "name");
        required(row.getRelationship(), input, "relationship");
        optional(row.getReference(), input, "reference");
        required(row.getAddressLine1(), input.path("address"), "address_line_1");
        require(Objects.equals(row.getCountry(), country(input.path("address"))), "Third-party country differs");
    }

    private void notes(PublicationQaGraph.Snapshot rows, PublicationQaRespondent respondent, JsonNode input,
                       DraftCasefileEntity draft) {
        require(rows.notes().size() == (input.isObject() ? 1 : 0), "Unexpected or missing case note");
        if (input.isObject()) {
            var note = rows.notes().values().iterator().next();
            require("respondent_accounts".equals(note.getAssociatedRecordType()) && "NT".equals(note.getNoteType())
                && respondent.getRespondentAccountId().toString().equals(note.getAssociatedRecordId())
                && note.getPostedDate() != null, "Case note is linked to a different account");
            required(note.getNoteText(), input, "note_text");
            require(draft.getSubmittedBy() != null && draft.getSubmittedByName() != null
                && draft.getSubmittedBy().equals(note.getPostedBy())
                && draft.getSubmittedByName().equals(note.getPostedByName()),
                "Case note submitter differs from the saved draft");
        }
    }

    private void associations(PublicationQaGraph.Snapshot rows, PublicationQaRespondent respondent, JsonNode input) {
        boolean centralAuthority = input.has("central_authority_code");
        require(rows.associations().size() == (centralAuthority ? 3 : 2)
            && rows.associations().values().stream().allMatch(row ->
                respondent.getRespondentAccountId().equals(row.getRespondentAccountId())),
            "Unexpected or missing respondent associations");
        if (centralAuthority) {
            var major = majors.findByBusinessUnitIdAndMajorCreditorCode(respondent.getBusinessUnitId(),
                input.path("central_authority_code").asString());
            require(major.isPresent() && major.get().getMajorCreditorId().equals(
                association(rows, respondent.getRespondentAccountId(), "Central Authority")),
                "Central Authority association differs from the selected business code");
        }
    }

    private Long association(PublicationQaGraph.Snapshot rows, Long respondentId, String type) {
        var matches = rows.associations().values().stream().filter(row ->
            respondentId.equals(row.getRespondentAccountId()) && type.equals(row.getAssociationType())).toList();
        require(matches.size() == 1, "Respondent association identity differs");
        return matches.getFirst().getAssociatedAccountId();
    }

    private void reservations(PublicationQaGraph.Snapshot rows, PublicationQaRespondent respondent) {
        Map<String, String> numbers = new HashMap<>();
        number(numbers, respondent.getAccountNumber(), "respondent_accounts");
        rows.creditors().values().forEach(row -> number(numbers, row.getAccountNumber(), "creditor_accounts"));
        require(rows.reservations().size() == numbers.size(), "Account reservation count differs");
        Set<String> observed = new HashSet<>();
        rows.reservations().values().forEach(row -> require(
            respondent.getBusinessUnitId().equals(row.getBusinessUnitId()) && observed.add(row.getAccountNumber())
                && Objects.equals(numbers.get(row.getAccountNumber()), row.getAssociatedRecordType()),
            "Account reservation identity or type differs"));
        require(observed.equals(numbers.keySet()), "Account reservations differ from the published graph");
    }

    private void number(Map<String, String> numbers, String value, String type) {
        require(value != null && value.matches("[0-9]{8}[A-Z]"), "Published account number format differs");
        int[] weights = {5, 1, 4, 2, 7, 5, 1, 4};
        int total = 0;
        for (int index = 0; index < weights.length; index++) {
            total += (value.charAt(index) - '0') * weights[index];
        }
        require(value.charAt(8) == (char) ('A' + Math.floorMod(-total, 23)), "Published account check letter differs");
        require(numbers.put(value, type) == null, "Published account numbers must be unique across account types");
    }

    private Long country(JsonNode address) {
        var matches = countries.findByCjsCode((short) address.path("cjs_code").intValue());
        require(matches.size() == 1, "Supplied country code must resolve exactly once");
        return matches.getFirst().getCountryId();
    }

    private void identity(JsonNode input, Long id, String number) {
        JsonNode value = input.path("account_id");
        require(value.isIntegralNumber() && value.canConvertToLong() && Objects.equals(value.longValue(), id)
            && Objects.equals(input.path("account_number").stringValue(), number),
            "Snapshot account identity differs from the inserted graph");
    }

    private void required(String actual, JsonNode input, String field) {
        require(input.path(field).isString() && Objects.equals(actual, input.path(field).stringValue()),
            "Published " + field + " differs from submitted input");
    }

    private void optional(String actual, JsonNode input, String field) {
        if (input.hasNonNull(field)) {
            required(actual, input, field);
        }
    }

    private static boolean positive(Long value) {
        return value != null && value > 0;
    }

    private static boolean zero(BigDecimal value) {
        return equalAmount(value, BigDecimal.ZERO);
    }

    private static boolean equalAmount(BigDecimal left, BigDecimal right) {
        return left != null && left.compareTo(right) == 0;
    }

    private static final class Expected {
        private BigDecimal orderAmount = BigDecimal.ZERO;
        private BigDecimal arrears = BigDecimal.ZERO;
        private final Set<Long> parties = new HashSet<>();
        private final Set<Long> creditors = new HashSet<>();
        private final Set<Long> aliases = new HashSet<>();
        private final Set<Long> contacts = new HashSet<>();
    }
}
