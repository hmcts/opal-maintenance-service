package uk.gov.hmcts.opal.support.publication;

import jakarta.persistence.EntityManager;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionTemplate;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
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

import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.function.Function;
import java.util.function.Predicate;
import java.util.function.Supplier;

import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Complete scalar observations for serial backend operations in a disposable Testcontainers database only.
 * Table-wide snapshots deliberately include siblings: a rollback must preserve every pre-existing row.
 */
public final class PublicationQaGraph {

    private final EntityManager entities;
    private final PlatformTransactionManager transactions;
    private final ObjectMapper json;
    private final PublicationQaGraphAssertions assertions;

    public PublicationQaGraph(EntityManager entities, PlatformTransactionManager transactions,
                              ObjectMapper json, CountryRepository countries,
                              MaintenanceApplicationRepository applications,
                              MajorCreditorRepository majorCreditors) {
        this.entities = entities;
        this.transactions = transactions;
        this.json = json;
        assertions = new PublicationQaGraphAssertions(json, countries, applications, majorCreditors);
    }

    public Snapshot snapshot() {
        return independently(true, this::read);
    }

    public void assertUnchanged(Snapshot before) {
        assertTrue(before.equals(snapshot()), "Publication graph or reservation rows changed");
    }

    public void assertPublished(Snapshot before, DraftCasefileEntity draft, JsonNode submittedCasefile) {
        independently(true, () -> {
            DraftCasefileEntity committed = entities.find(DraftCasefileEntity.class, draft.getDraftCasefileId());
            require(committed != null && Objects.equals(committed.getAccountId(), draft.getAccountId())
                && Objects.equals(committed.getAccountNumber(), draft.getAccountNumber())
                && Objects.equals(committed.getCasefileSnapshot(), draft.getCasefileSnapshot())
                && committed.getCasefileStatus() == draft.getCasefileStatus(),
                "Publication draft must be independently committed");
            assertions.assertPublished(inserted(before, read()), committed, submittedCasefile);
            return null;
        });
    }

    public void removeOwned(Snapshot before, long draftId, String marker) {
        independently(false, () -> {
            DraftCasefileEntity draft = entities.find(DraftCasefileEntity.class, draftId);
            require(marker != null && marker.matches("E2E-[0-9a-f]{16}") && draft != null,
                "Cleanup requires a saved draft and a valid owned marker");
            require(marker.equals(json.readTree(draft.getCasefile()).at("/respondent_account/remo_reference")
                .asString()), "Cleanup draft marker differs");
            Snapshot current = read();
            Snapshot additions = inserted(before, current);
            Snapshot owned = owned(additions, draft, marker);
            verifyExclusive(current, owned, draftId);
            removeRows(PublicationQaOrderTerm.class, owned.orderTerms());
            removeRows(PublicationQaNote.class, owned.notes());
            removeRows(PublicationQaAssociation.class, owned.associations());
            entities.remove(entities.find(DraftCasefileEntity.class, draftId));
            entities.flush();
            removeRows(PublicationQaRespondent.class, owned.respondents());
            removeRows(PublicationQaCreditor.class, owned.creditors());
            removeRows(PublicationQaAlias.class, owned.aliases());
            removeRows(PublicationQaParty.class, owned.parties());
            removeRows(PublicationQaDebtor.class, owned.debtors());
            removeRows(PublicationQaContact.class, owned.contacts());
            removeRows(PublicationQaReservation.class, owned.reservations());
            return null;
        });
    }

    private Snapshot owned(Snapshot added, DraftCasefileEntity draft, String marker) {
        Map<Long, PublicationQaRespondent> respondents = matching(added.respondents(), row ->
            marker.equals(row.getRemoReference()) && Objects.equals(draft.getBusinessUnitId(),
                row.getBusinessUnitId()));
        require(respondents.size() <= 1, "Cleanup respondent ownership is ambiguous");
        if (respondents.isEmpty()) {
            require(draft.getAccountId() == null && empty(added), "Cleanup cannot identify partial graph ownership");
            return added;
        }
        Long respondentId = respondents.keySet().iterator().next();
        require(draft.getAccountId() == null || respondentId.equals(draft.getAccountId()),
            "Cleanup draft account link differs");
        var associations = matching(added.associations(), row -> respondentId.equals(row.getRespondentAccountId()));
        Set<Long> partyIds = new HashSet<>();
        Set<Long> creditorIds = new HashSet<>();
        associations.values().forEach(row -> {
            if ("Respondent".equals(row.getAssociationType())) {
                partyIds.add(row.getAssociatedAccountId());
            } else if ("Applicant".equals(row.getAssociationType())) {
                creditorIds.add(row.getAssociatedAccountId());
            }
        });
        require(partyIds.size() == 1, "Cleanup requires the owned respondent party link");
        boolean unresolvedMinors = snapshotMinorCreditors(added, draft, creditorIds);
        var terms = matching(added.orderTerms(), row -> respondentId.equals(row.getRespondentAccountId()));
        terms.values().forEach(row -> creditorIds.add(row.getCreditorAccountId()));
        require(!unresolvedMinors || added.creditors().keySet().equals(creditorIds),
            "Cleanup cannot identify unresolved minor accounts safely");
        var creditors = matching(added.creditors(), row -> creditorIds.contains(row.getCreditorAccountId()));
        creditors.values().forEach(row -> addNonNull(partyIds, row.getMinorCreditorPartyId()));
        var parties = matching(added.parties(), row -> partyIds.contains(row.getPartyId()));
        require(parties.keySet().equals(partyIds), "Cleanup cannot own a pre-existing or missing party");
        Set<Long> debtorIds = new HashSet<>();
        Set<Long> contactIds = new HashSet<>();
        respondents.values().forEach(row -> {
            addNonNull(debtorIds, row.getDebtorDetailId());
            addNonNull(contactIds, row.getThirdPartyContactId());
        });
        creditors.values().forEach(row -> addNonNull(contactIds, row.getThirdPartyContactId()));
        var aliases = matching(added.aliases(), row -> partyIds.contains(row.getPartyId()));
        var debtors = matching(added.debtors(), row -> debtorIds.contains(row.getDebtorDetailId()));
        var contacts = matching(added.contacts(), row -> contactIds.contains(row.getThirdPartyContactId()));
        var notes = matching(added.notes(), row -> noteOwned(row, respondentId, creditors.keySet()));
        Set<String> accountNumbers = new HashSet<>();
        respondents.values().forEach(row -> accountNumbers.add(row.getAccountNumber()));
        creditors.values().forEach(row -> accountNumbers.add(row.getAccountNumber()));
        var reservations = matching(added.reservations(),
            row -> draft.getBusinessUnitId().equals(row.getBusinessUnitId())
            && accountNumbers.contains(row.getAccountNumber()));
        return new Snapshot(respondents, creditors, parties, associations, aliases, debtors, contacts,
            terms, notes, reservations);
    }

    private boolean snapshotMinorCreditors(Snapshot added, DraftCasefileEntity draft, Set<Long> creditorIds) {
        Map<Integer, JsonNode> submitted = new HashMap<>();
        json.readTree(draft.getCasefile()).path("minor_creditors").forEach(minor -> {
            JsonNode sequence = minor.path("creditor_sequence");
            require(sequence.isIntegralNumber() && sequence.canConvertToInt() && sequence.intValue() > 0
                && submitted.put(sequence.intValue(), minor) == null, "Cleanup submitted minor sequence differs");
        });
        JsonNode identities = json.readTree(draft.getCasefileSnapshot()).path("minor_creditor_accounts");
        if (submitted.isEmpty() && identities.isMissingNode()) {
            return false;
        }
        require(identities.isArray() && identities.size() == submitted.size(),
            "Cleanup minor identities do not match the submitted collection");
        Set<Integer> observed = new HashSet<>();
        boolean unresolved = false;
        for (JsonNode identity : identities) {
            JsonNode sequence = identity.path("creditor_sequence");
            require(sequence.isIntegralNumber() && sequence.canConvertToInt()
                && submitted.containsKey(sequence.intValue()) && observed.add(sequence.intValue()),
                "Cleanup snapshot minor sequence differs");
            JsonNode id = identity.path("account_id");
            if (id.isNull()) {
                require(identity.path("account_number").isNull(), "Cleanup unpublished minor identity is ambiguous");
                unresolved = true;
                continue;
            }
            require(id.isIntegralNumber() && id.canConvertToLong() && id.longValue() > 0
                && creditorIds.add(id.longValue()), "Cleanup minor account identity differs");
            PublicationQaCreditor creditor = added.creditors().get(id.longValue());
            require(creditor != null && Objects.equals(creditor.getBusinessUnitId(), draft.getBusinessUnitId())
                && "MN".equals(creditor.getCreditorAccountType())
                && identity.path("account_number").isString()
                && Objects.equals(identity.path("account_number").stringValue(), creditor.getAccountNumber()),
                "Cleanup minor account is not newly inserted with the expected unit and number");
            assertions.assertMinorParty(added, creditor.getMinorCreditorPartyId(),
                submitted.get(sequence.intValue()).path("party_details"));
        }
        require(observed.equals(submitted.keySet()), "Cleanup minor sequence collection differs");
        return unresolved;
    }

    private void verifyExclusive(Snapshot current, Snapshot owned, long draftId) {
        current.orderTerms().values().stream().filter(row -> !contains(owned.orderTerms(), row.getOrderTermsId()))
            .forEach(row -> require(!contains(owned.creditors(), row.getCreditorAccountId())
                && !contains(owned.respondents(), row.getRespondentAccountId()),
                "Cleanup order links include a sibling"));
        current.associations().values().stream()
            .filter(row -> !contains(owned.associations(), row.getRespondentAccountPartyId()))
            .forEach(row -> require(!contains(owned.respondents(), row.getRespondentAccountId())
                && !("Respondent".equals(row.getAssociationType())
                    && contains(owned.parties(), row.getAssociatedAccountId()))
                && !("Applicant".equals(row.getAssociationType())
                    && contains(owned.creditors(), row.getAssociatedAccountId())),
                "Cleanup association links include a sibling"));
        current.creditors().values().stream().filter(row -> !contains(owned.creditors(), row.getCreditorAccountId()))
            .forEach(row -> require(!contains(owned.parties(), row.getMinorCreditorPartyId())
                && !contains(owned.contacts(), row.getThirdPartyContactId()),
                "Cleanup creditor children include a sibling"));
        current.respondents().values().stream()
            .filter(row -> !contains(owned.respondents(), row.getRespondentAccountId()))
            .forEach(row -> require(!contains(owned.debtors(), row.getDebtorDetailId())
                && !contains(owned.contacts(), row.getThirdPartyContactId()),
                "Cleanup respondent children include a sibling"));
        rows(DraftCasefileEntity.class, DraftCasefileEntity::getDraftCasefileId).values()
            .stream().filter(row -> row.getDraftCasefileId() != draftId)
            .forEach(row -> require(!contains(owned.respondents(), row.getAccountId()),
                "Cleanup respondent is linked from a sibling draft"));
    }

    private static boolean contains(Map<Long, ?> rows, Long id) {
        return id != null && rows.containsKey(id);
    }

    private static boolean noteOwned(PublicationQaNote note, Long respondentId, Set<Long> creditorIds) {
        return ("respondent_accounts".equals(note.getAssociatedRecordType())
            && respondentId.toString().equals(note.getAssociatedRecordId()))
            || ("creditor_accounts".equals(note.getAssociatedRecordType())
                && creditorIds.stream().anyMatch(id -> id.toString().equals(note.getAssociatedRecordId())));
    }

    private static void addNonNull(Set<Long> target, Long value) {
        if (value != null) {
            target.add(value);
        }
    }

    private <T> T independently(boolean readOnly, Supplier<T> action) {
        TransactionTemplate transaction = new TransactionTemplate(transactions);
        transaction.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
        transaction.setReadOnly(readOnly);
        return transaction.execute(status -> {
            entities.clear();
            try {
                return action.get();
            } finally {
                entities.clear();
            }
        });
    }

    private Snapshot read() {
        return new Snapshot(
            rows(PublicationQaRespondent.class, PublicationQaRespondent::getRespondentAccountId),
            rows(PublicationQaCreditor.class, PublicationQaCreditor::getCreditorAccountId),
            rows(PublicationQaParty.class, PublicationQaParty::getPartyId),
            rows(PublicationQaAssociation.class, PublicationQaAssociation::getRespondentAccountPartyId),
            rows(PublicationQaAlias.class, PublicationQaAlias::getAliasId),
            rows(PublicationQaDebtor.class, PublicationQaDebtor::getDebtorDetailId),
            rows(PublicationQaContact.class, PublicationQaContact::getThirdPartyContactId),
            rows(PublicationQaOrderTerm.class, PublicationQaOrderTerm::getOrderTermsId),
            rows(PublicationQaNote.class, PublicationQaNote::getNoteId),
            rows(PublicationQaReservation.class, PublicationQaReservation::getAccountNumberIndexId));
    }

    private <T> Map<Long, T> rows(Class<T> type, Function<T, Long> key) {
        var criteria = entities.getCriteriaBuilder().createQuery(type);
        criteria.select(criteria.from(type));
        Map<Long, T> result = new HashMap<>();
        entities.createQuery(criteria).getResultList().forEach(row -> result.put(key.apply(row), row));
        return result;
    }

    private <T> void removeRows(Class<T> type, Map<Long, T> rows) {
        rows.keySet().forEach(id -> entities.remove(entities.find(type, id)));
        entities.flush();
        entities.clear();
    }

    static Snapshot inserted(Snapshot before, Snapshot after) {
        return new Snapshot(
            inserted(before.respondents(), after.respondents(), "respondents"),
            inserted(before.creditors(), after.creditors(), "creditors"),
            inserted(before.parties(), after.parties(), "parties"),
            inserted(before.associations(), after.associations(), "associations"),
            inserted(before.aliases(), after.aliases(), "aliases"),
            inserted(before.debtors(), after.debtors(), "debtors"),
            inserted(before.contacts(), after.contacts(), "contacts"),
            inserted(before.orderTerms(), after.orderTerms(), "orderTerms"),
            inserted(before.notes(), after.notes(), "notes"),
            inserted(before.reservations(), after.reservations(), "reservations"));
    }

    private static <T> Map<Long, T> inserted(Map<Long, T> before, Map<Long, T> after, String category) {
        require(before.entrySet().stream().allMatch(entry -> Objects.equals(entry.getValue(),
            after.get(entry.getKey()))),
            "Baseline rows changed in " + category);
        Map<Long, T> additions = new HashMap<>(after);
        before.keySet().forEach(additions::remove);
        return additions;
    }

    private static <T> Map<Long, T> matching(Map<Long, T> source, Predicate<T> predicate) {
        Map<Long, T> result = new HashMap<>();
        source.forEach((id, row) -> {
            if (predicate.test(row)) {
                result.put(id, row);
            }
        });
        return result;
    }

    private static boolean empty(Snapshot value) {
        return value.respondents().isEmpty()
            && value.creditors().isEmpty()
            && value.parties().isEmpty()
            && value.associations().isEmpty()
            && value.aliases().isEmpty()
            && value.debtors().isEmpty()
            && value.contacts().isEmpty()
            && value.orderTerms().isEmpty()
            && value.notes().isEmpty()
            && value.reservations().isEmpty();
    }

    static void require(boolean condition, String message) {
        assertTrue(condition, message);
    }

    private static <T> Map<Long, T> detached(Map<Long, T> source, Function<T, T> copy) {
        Map<Long, T> result = new HashMap<>();
        source.forEach((id, row) -> result.put(id, copy.apply(row)));
        return Map.copyOf(result);
    }

    /** Immutable maps of detached scalar objects; the row types expose no mutators or dump-prone toString. */
    public record Snapshot(
        Map<Long, PublicationQaRespondent> respondents,
        Map<Long, PublicationQaCreditor> creditors,
        Map<Long, PublicationQaParty> parties,
        Map<Long, PublicationQaAssociation> associations,
        Map<Long, PublicationQaAlias> aliases,
        Map<Long, PublicationQaDebtor> debtors,
        Map<Long, PublicationQaContact> contacts,
        Map<Long, PublicationQaOrderTerm> orderTerms,
        Map<Long, PublicationQaNote> notes,
        Map<Long, PublicationQaReservation> reservations) {

        public Snapshot {
            respondents = detached(respondents, row -> row.toBuilder().build());
            creditors = detached(creditors, row -> row.toBuilder().build());
            parties = detached(parties, row -> row.toBuilder().build());
            associations = detached(associations, row -> row.toBuilder().build());
            aliases = detached(aliases, row -> row.toBuilder().build());
            debtors = detached(debtors, row -> row.toBuilder().build());
            contacts = detached(contacts, row -> row.toBuilder().build());
            orderTerms = detached(orderTerms, row -> row.toBuilder().build());
            notes = detached(notes, row -> row.toBuilder().build());
            reservations = detached(reservations, row -> row.toBuilder().build());
        }
    }
}
