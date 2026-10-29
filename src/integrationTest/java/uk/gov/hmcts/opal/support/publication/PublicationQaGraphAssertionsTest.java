package uk.gov.hmcts.opal.support.publication;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.node.ArrayNode;
import tools.jackson.databind.node.ObjectNode;
import uk.gov.hmcts.opal.entity.CountryEntity;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.entity.MaintenanceApplicationEntity;
import uk.gov.hmcts.opal.entity.MajorCreditorEntity;
import uk.gov.hmcts.opal.repository.CountryRepository;
import uk.gov.hmcts.opal.repository.MaintenanceApplicationRepository;
import uk.gov.hmcts.opal.repository.MajorCreditorRepository;
import uk.gov.hmcts.opaltest.publication.PublicationQaAlias;
import uk.gov.hmcts.opaltest.publication.PublicationQaAssociation;
import uk.gov.hmcts.opaltest.publication.PublicationQaContact;
import uk.gov.hmcts.opaltest.publication.PublicationQaCreditor;
import uk.gov.hmcts.opaltest.publication.PublicationQaDebtor;
import uk.gov.hmcts.opaltest.publication.PublicationQaNote;
import uk.gov.hmcts.opaltest.publication.PublicationQaOrderTerm;
import uk.gov.hmcts.opaltest.publication.PublicationQaParty;
import uk.gov.hmcts.opaltest.publication.PublicationQaReservation;
import uk.gov.hmcts.opaltest.publication.PublicationQaRespondent;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.function.UnaryOperator;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/** Detached assertion-oracle regressions only: no publication procedure or backend operation is simulated. */
class PublicationQaGraphAssertionsTest {

    private static final String MARKER = "E2E-0123456789abcdef";
    private static final LocalDateTime WHEN = LocalDateTime.of(2026, 9, 1, 0, 0);
    private final ObjectMapper json = new ObjectMapper();
    private PublicationQaGraphAssertions assertions;

    @BeforeEach
    void references() {
        CountryRepository countries = mock(CountryRepository.class);
        MaintenanceApplicationRepository applications = mock(MaintenanceApplicationRepository.class);
        MajorCreditorRepository majors = mock(MajorCreditorRepository.class);
        when(countries.findByCjsCode((short) 1)).thenReturn(List.of(CountryEntity.builder().countryId(301L).build()));
        when(applications.findByApplicationCode("TEST"))
            .thenReturn(Optional.of(MaintenanceApplicationEntity.builder().applicationId((short) 22).build()));
        when(majors.findByBusinessUnitIdAndMajorCreditorCode((short) 1, "MJ1"))
            .thenReturn(Optional.of(MajorCreditorEntity.builder().majorCreditorId(77L).build()));
        assertions = new PublicationQaGraphAssertions(json, countries, applications, majors);
    }

    @ParameterizedTest
    @ValueSource(booleans = {false, true})
    void acceptsCompleteDetachedGraphWithSequenceMappedMinors(boolean minors) {
        Fixture fixture = fixture(minors);
        assertions.assertPublished(fixture.rows(), fixture.draft(), fixture.input());
    }

    @Test
    void rejectsMissingRespondentParty() {
        rejects(rows -> replace(rows, Map.of(), rows.orderTerms(), rows.reservations(), rows.creditors(),
            rows.aliases()));
    }

    @Test
    void rejectsIncorrectAggregateOrderAmount() {
        Fixture fixture = fixture(true);
        var changed = respondent(fixture.rows(), fixture.rows().respondents().get(1000L).toBuilder()
            .ordersAmount(new BigDecimal("999.00")).build());
        assertThrows(AssertionError.class, () -> assertions.assertPublished(changed, fixture.draft(), fixture.input()));
    }

    @Test
    void rejectsIncorrectAggregateArrears() {
        Fixture fixture = fixture(true);
        var changed = respondent(fixture.rows(), fixture.rows().respondents().get(1000L).toBuilder()
            .totalArrears(new BigDecimal("999.00")).build());
        assertThrows(AssertionError.class, () -> assertions.assertPublished(changed, fixture.draft(), fixture.input()));
    }

    @Test
    void rejectsUnspecifiedOrderArrears() {
        rejects(rows -> {
            var terms = new HashMap<>(rows.orderTerms());
            terms.put(1L, terms.get(1L).toBuilder().arrearsAmount(new BigDecimal("5.50")).build());
            return replace(rows, rows.parties(), terms, rows.reservations(), rows.creditors(), rows.aliases());
        });
    }

    @Test
    void acceptsInputCheckedArrearsAndTheirTotal() {
        Fixture fixture = fixture(true);
        ((ArrayNode) fixture.input().at("/respondent_account/order_details/order_terms/0/result_responses"))
            .addObject().put("parameter_name", "Arrears").put("response", "5.50");
        var terms = new HashMap<>(fixture.rows().orderTerms());
        terms.put(1L, terms.get(1L).toBuilder().arrearsAmount(new BigDecimal("5.50")).build());
        var changed = replace(fixture.rows(), fixture.rows().parties(), terms, fixture.rows().reservations(),
            fixture.rows().creditors(), fixture.rows().aliases());
        changed = respondent(changed, changed.respondents().get(1000L).toBuilder()
            .totalArrears(new BigDecimal("5.50")).build());
        assertions.assertPublished(changed, fixture.draft().toBuilder().casefile(fixture.input().toString()).build(),
            fixture.input());
    }

    @Test
    void rejectsIncorrectOrderCreditor() {
        rejects(rows -> {
            var terms = new HashMap<>(rows.orderTerms());
            terms.put(1L, terms.get(1L).toBuilder().creditorAccountId(3000L).build());
            return replace(rows, rows.parties(), terms, rows.reservations(), rows.creditors(), rows.aliases());
        });
    }

    @Test
    void rejectsMissingReservation() {
        rejects(rows -> replace(rows, rows.parties(), rows.orderTerms(), Map.of(), rows.creditors(), rows.aliases()));
    }

    @Test
    void rejectsMissingOptionalAlias() {
        rejects(rows -> replace(rows, rows.parties(), rows.orderTerms(), rows.reservations(), rows.creditors(),
            Map.of()));
    }

    @Test
    void rejectsIncorrectOptionalContact() {
        Fixture fixture = fixture(true);
        var contacts = new HashMap<>(fixture.rows().contacts());
        contacts.put(8000L, contacts.get(8000L).toBuilder().relationship("Incorrect").build());
        var rows = fixture.rows();
        var changed = new PublicationQaGraph.Snapshot(rows.respondents(), rows.creditors(), rows.parties(),
            rows.associations(), rows.aliases(), rows.debtors(), contacts, rows.orderTerms(), rows.notes(),
            rows.reservations());
        assertThrows(AssertionError.class, () -> assertions.assertPublished(changed, fixture.draft(), fixture.input()));
    }

    @Test
    void rejectsIncorrectNoteSubmitter() {
        Fixture fixture = fixture(true);
        var rows = fixture.rows();
        var note = rows.notes().get(9000L).toBuilder().postedBy("Different submitter").build();
        var changed = new PublicationQaGraph.Snapshot(rows.respondents(), rows.creditors(), rows.parties(),
            rows.associations(), rows.aliases(), rows.debtors(), rows.contacts(), rows.orderTerms(),
            Map.of(9000L, note), rows.reservations());
        assertThrows(AssertionError.class, () -> assertions.assertPublished(changed, fixture.draft(), fixture.input()));
    }

    @Test
    void rejectsMajorCreditorBacsFlag() {
        rejects(rows -> {
            var creditors = new HashMap<>(rows.creditors());
            creditors.put(3000L, creditors.get(3000L).toBuilder().payByBacs(true).build());
            return replace(rows, rows.parties(), rows.orderTerms(), rows.reservations(), creditors, rows.aliases());
        });
    }

    @Test
    void rejectsSecondAccountForRepeatedMajor() {
        rejects(rows -> {
            var creditors = new HashMap<>(rows.creditors());
            creditors.put(3001L, creditors.get(3000L).toBuilder().creditorAccountId(3001L).build());
            return replace(rows, rows.parties(), rows.orderTerms(), rows.reservations(), creditors, rows.aliases());
        });
    }

    @ParameterizedTest
    @ValueSource(ints = {23, 99})
    void rejectsDuplicateOrUnknownSnapshotSequence(int sequence) {
        Fixture fixture = fixture(true);
        ObjectNode snapshot = (ObjectNode) json.readTree(fixture.draft().getCasefileSnapshot());
        ((ObjectNode) snapshot.path("minor_creditor_accounts").get(0)).put("creditor_sequence", sequence);
        DraftCasefileEntity changed = fixture.draft().toBuilder().casefileSnapshot(snapshot.toString()).build();
        assertThrows(AssertionError.class, () -> assertions.assertPublished(fixture.rows(), changed, fixture.input()));
    }

    @Test
    void rejectsChangedBaselineSibling() {
        Fixture fixture = fixture(true);
        var before = replace(fixture.rows(), fixture.rows().parties(), fixture.rows().orderTerms(),
            fixture.rows().reservations(), fixture.rows().creditors(), fixture.rows().aliases());
        var changedRespondents = new HashMap<>(before.respondents());
        changedRespondents.put(1000L, changedRespondents.get(1000L).toBuilder().accountComment("Changed").build());
        var after = new PublicationQaGraph.Snapshot(changedRespondents, before.creditors(), before.parties(),
            before.associations(), before.aliases(), before.debtors(), before.contacts(), before.orderTerms(),
            before.notes(), before.reservations());
        assertThrows(AssertionError.class, () -> PublicationQaGraph.inserted(before, after));
    }

    private void rejects(UnaryOperator<PublicationQaGraph.Snapshot> mutation) {
        Fixture fixture = fixture(true);
        assertThrows(AssertionError.class,
            () -> assertions.assertPublished(mutation.apply(fixture.rows()), fixture.draft(), fixture.input()));
    }

    private PublicationQaGraph.Snapshot respondent(PublicationQaGraph.Snapshot source,
                                                   PublicationQaRespondent respondent) {
        return new PublicationQaGraph.Snapshot(Map.of(1000L, respondent), source.creditors(), source.parties(),
            source.associations(), source.aliases(), source.debtors(), source.contacts(), source.orderTerms(),
            source.notes(), source.reservations());
    }

    private PublicationQaGraph.Snapshot replace(PublicationQaGraph.Snapshot source,
                                                Map<Long, PublicationQaParty> parties,
                                                Map<Long, PublicationQaOrderTerm> terms,
                                                Map<Long, PublicationQaReservation> reservations,
                                                Map<Long, PublicationQaCreditor> creditors,
                                                Map<Long, PublicationQaAlias> aliases) {
        return new PublicationQaGraph.Snapshot(source.respondents(), creditors, parties, source.associations(),
            aliases, source.debtors(), source.contacts(), terms, source.notes(), reservations);
    }

    private Fixture fixture(boolean minors) {
        final ObjectNode input = (ObjectNode) json.readTree("""
            {"respondent_account":{"business_unit_id":1,"application_code":"TEST","casefile_type":"REMO In",
             "remo_reference":"E2E-0123456789abcdef","respondent":{"party_details":{
             "organisation":false,"individual_details":{"surname":"Respondent"},
             "address":{"address_line_1":"Synthetic address","cjs_code":1},
             "aliases":[{"sequence_number":1,"surname":"Alias","forenames":"Synthetic"}]},
             "debtor_details":{"employer_name":"Synthetic Employer",
             "employer_address":{"address_line_1":"Synthetic employer address","cjs_code":1}},
             "third_party_details":{"name":"Synthetic Agent","relationship":"Agent",
             "address":{"address_line_1":"Synthetic agent address","cjs_code":1}}},
             "order_details":{"date_ordered":"2026-09-01","date_arrears_last_updated":"2026-09-01",
             "interest_flag":false,"indexation":"None","payment_arrangement":"Court","payment_period":"Monthly",
             "order_terms":[{"result_id":"MAT","creditor_type":"Applicant",
             "result_responses":[{"parameter_name":"Amount","response":"12.30"}]},
             {"result_id":"MAT","creditor_type":"Major Creditor","major_creditor_code":"MJ1",
             "result_responses":[{"parameter_name":"Amount","response":"3.30"}]},
             {"result_id":"MAT","creditor_type":"Major Creditor","major_creditor_code":"MJ1",
             "result_responses":[{"parameter_name":"Amount","response":"4.40"}]}]},
             "notes":{"note_text":"Synthetic note"}},
             "applicant":{"party_details":{"organisation":false,"individual_details":{"surname":"Applicant"},
             "address":{"address_line_1":"Synthetic address","cjs_code":1}},
             "bank_account_details":{"bank_account_type":"None or not applicable"}}}
            """);
        Map<Long, PublicationQaParty> parties = new HashMap<>();
        parties.put(4000L, party(4000, "Respondent", "Respondent"));
        parties.put(5000L, party(5000, "Applicant", "Minor Creditor"));
        Map<Long, PublicationQaCreditor> creditors = new HashMap<>();
        creditors.put(2000L, creditor(2000, 5000L, number(2)));
        creditors.put(3000L, creditor(3000, null, number(5)).toBuilder().creditorAccountType("MJ")
            .majorCreditorId(77L).build());
        Map<Long, PublicationQaOrderTerm> terms = new HashMap<>();
        terms.put(1L, term(1, 2000, "12.30"));
        terms.put(2L, term(2, 3000, "3.30"));
        terms.put(3L, term(3, 3000, "4.40"));
        ObjectNode snapshot = json.createObjectNode();
        account(snapshot.putObject("respondent_account"), 1000, number(1));
        account(snapshot.putObject("applicant_account"), 2000, number(2));
        snapshot.putArray("minor_creditor_accounts");
        Map<Long, PublicationQaReservation> reservations = new HashMap<>();
        reservation(reservations, 1000, number(1), "respondent_accounts");
        reservation(reservations, 2000, number(2), "creditor_accounts");
        reservation(reservations, 3000, number(5), "creditor_accounts");
        if (minors) {
            input.putArray("minor_creditors");
            addMinor(input, snapshot, parties, creditors, terms, reservations, 23, 4);
            addMinor(input, snapshot, parties, creditors, terms, reservations, 7, 3);
            // Output array order deliberately differs from the submitted 23/7 sequence order.
            ArrayNode identities = (ArrayNode) snapshot.path("minor_creditor_accounts");
            JsonNode first = identities.get(0);
            identities.set(0, identities.get(1));
            identities.set(1, first);
        }
        var respondent = PublicationQaRespondent.builder().respondentAccountId(1000L).businessUnitId((short) 1)
            .accountNumber(number(1)).applicationId((short) 22).casefileType("REMO In").remoReference(MARKER)
            .accountStatus("L").accountBalance(BigDecimal.ZERO).ordersBalance(BigDecimal.ZERO)
            .ordersAmount(new BigDecimal(minors ? "22.20" : "20.00")).totalArrears(BigDecimal.ZERO)
                .imposedHearingDate(WHEN)
            .dateArrearsLastUpdated(WHEN).paymentPeriod("Monthly").interestFlag(false).indexation("None")
            .paymentArrangement("Court").debtorDetailId(7000L).thirdPartyContactId(8000L).build();
        var rows = new PublicationQaGraph.Snapshot(Map.of(1000L, respondent), creditors, parties,
            Map.of(1L, association(1, 4000, "Respondent"), 2L, association(2, 2000, "Applicant")),
            Map.of(6000L, PublicationQaAlias.builder().aliasId(6000L).partyId(4000L).surname("Alias")
                .forenames("Synthetic").sequenceNumber(1).build()),
            Map.of(7000L, PublicationQaDebtor.builder().debtorDetailId(7000L).employerName("Synthetic Employer")
                .employerAddressLine1("Synthetic employer address").employerCountryId(301L).build()),
            Map.of(8000L, PublicationQaContact.builder().thirdPartyContactId(8000L).nameOrganisation("Synthetic Agent")
                .relationship("Agent").addressLine1("Synthetic agent address").country(301L).build()),
            terms, Map.of(9000L, PublicationQaNote.builder().noteId(9000L).noteType("NT")
                .associatedRecordType("respondent_accounts").associatedRecordId("1000")
                .noteText("Synthetic note").postedDate(WHEN).postedBy("Synthetic")
                .postedByName("Synthetic Submitter").build()), reservations);
        DraftCasefileEntity draft = DraftCasefileEntity.builder().draftCasefileId(1L).businessUnitId((short) 1)
            .submittedBy("Synthetic").submittedByName("Synthetic Submitter")
            .accountId(1000L).accountNumber(number(1)).casefile(input.toString()).casefileType("REMO In")
            .casefileStatus(DraftCasefileStatus.PUBLISHED).casefileSnapshot(snapshot.toString()).build();
        return new Fixture(input, draft, rows);
    }

    private void addMinor(ObjectNode input, ObjectNode snapshot, Map<Long, PublicationQaParty> parties,
                          Map<Long, PublicationQaCreditor> creditors, Map<Long, PublicationQaOrderTerm> terms,
                          Map<Long, PublicationQaReservation> reservations, int sequence, int suffix) {
        var minor = (ObjectNode) input.path("applicant").deepCopy();
        minor.put("creditor_sequence", sequence);
        ((ObjectNode) minor.at("/party_details/individual_details")).put("surname", "Minor" + sequence);
        ((ArrayNode) input.path("minor_creditors")).add(minor);
        var identity = ((ArrayNode) snapshot.path("minor_creditor_accounts")).addObject();
        identity.put("creditor_sequence", sequence);
        account(identity, 2000 + sequence, number(suffix));
        parties.put(5000L + sequence, party(5000 + sequence, "Minor" + sequence, "Minor Creditor"));
        creditors.put(2000L + sequence, creditor(2000 + sequence, 5000L + sequence, number(suffix)));
        var inputTerm = ((ArrayNode) input.at("/respondent_account/order_details/order_terms"))
            .addObject().put("result_id", "MAT").put("creditor_type", "Minor Creditor")
            .put("minor_creditor_sequence", sequence);
        inputTerm.putArray("result_responses").addObject().put("parameter_name", "Amount").put("response", "1.10");
        terms.put(100L + sequence, term(100 + sequence, 2000 + sequence, "1.10"));
        reservation(reservations, 2000 + sequence, number(suffix), "creditor_accounts");
    }

    private PublicationQaParty party(long id, String surname, String type) {
        return PublicationQaParty.builder().partyId(id).organisation(false).surname(surname)
            .addressLine1("Synthetic address").countryId(301L).restrictPersonalInformation(false)
                .accountType(type).build();
    }

    private PublicationQaCreditor creditor(long id, Long partyId, String number) {
        return PublicationQaCreditor.builder().creditorAccountId(id).minorCreditorPartyId(partyId)
            .businessUnitId((short) 1).accountNumber(number).creditorAccountType("MN")
            .fromSuspense(false).holdPayout(false).payByBacs(false).build();
    }

    private PublicationQaOrderTerm term(long id, long creditor, String amount) {
        return PublicationQaOrderTerm.builder().orderTermsId(id).respondentAccountId(1000L)
            .creditorAccountId(creditor).resultId("MAT").postedDate(WHEN).imposedDate(WHEN)
            .imposedAmount(new BigDecimal(amount)).completed(false).build();
    }

    private PublicationQaAssociation association(long id, long associated, String type) {
        return PublicationQaAssociation.builder().respondentAccountPartyId(id).respondentAccountId(1000L)
            .associatedAccountId(associated).associationType(type).build();
    }

    private void reservation(Map<Long, PublicationQaReservation> rows, long id, String number, String type) {
        rows.put(id, PublicationQaReservation.builder().accountNumberIndexId(id).businessUnitId((short) 1)
            .accountNumber(number).associatedRecordType(type).build());
    }

    private void account(ObjectNode target, long id, String number) {
        target.put("account_id", id).put("account_number", number);
    }

    private String number(int suffix) {
        String digits = "4400000" + suffix;
        int[] weights = {5, 1, 4, 2, 7, 5, 1, 4};
        int total = 0;
        for (int index = 0; index < weights.length; index++) {
            total += (digits.charAt(index) - '0') * weights[index];
        }
        return digits + (char) ('A' + Math.floorMod(-total, 23));
    }

    private record Fixture(JsonNode input, DraftCasefileEntity draft, PublicationQaGraph.Snapshot rows) {
    }
}
