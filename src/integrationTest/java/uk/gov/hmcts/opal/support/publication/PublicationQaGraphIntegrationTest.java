package uk.gov.hmcts.opal.support.publication;

import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Import;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.jdbc.Sql;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
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
import java.time.LocalDate;
import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.context.jdbc.Sql.ExecutionPhase.AFTER_TEST_METHOD;

/** Observer regressions with manual typed rows; these do not exercise or simulate publication. */
@Import(PublicationQaGraphConfiguration.class)
@TestPropertySource(properties = {
    "spring.flyway.locations=classpath:db/migration/ddl",
    "spring.jpa.hibernate.ddl-auto=validate",
    "opal.redis.enabled=false", "management.health.redis.enabled=false"
})
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@Sql({"/draft-casefile/reference-fixtures.sql", "/draft-casefile/cleanup-scope-fixtures.sql"})
@Sql(scripts = "/draft-casefile/cleanup-scope-cleanup.sql", executionPhase = AFTER_TEST_METHOD)
class PublicationQaGraphIntegrationTest extends BaseIntegrationTest {

    private static final long OWN = 9000000401L;
    private static final long SIBLING = 9000000402L;
    private static final long UNREFERENCED = 9000000403L;
    private static final String MARKER = "E2E-0123456789abcdef";
    private static final LocalDateTime WHEN = LocalDateTime.of(2026, 10, 1, 12, 0);

    @Autowired
    private PublicationQaGraph graph;
    @Autowired
    private EntityManager entities;
    @Autowired
    private PlatformTransactionManager transactions;

    @Test
    void rereadsMigratedTablesWithoutChanges() {
        var before = graph.snapshot();
        assertTrue(before.respondents().containsKey(101L), "Migrated reference account must hydrate");
        assertTrue(before.creditors().isEmpty() && before.parties().isEmpty() && before.associations().isEmpty()
            && before.aliases().isEmpty() && before.debtors().isEmpty() && before.contacts().isEmpty()
            && before.orderTerms().isEmpty() && before.notes().isEmpty() && before.reservations().isEmpty(),
            "Unused migrated tables must hydrate as empty maps");
        graph.assertUnchanged(before);
        assertTrue(before.equals(graph.snapshot()), "Repeated detached snapshots must be equal");
    }

    @Test
    void snapshotsAreImmutableAndDetectChangedRows() {
        var before = graph.snapshot();
        assertThrows(UnsupportedOperationException.class, () -> before.respondents().clear());
        try {
            write(() -> entities.merge(before.respondents().get(101L).toBuilder().accountComment("Changed").build()));
            assertTrue(before.respondents().get(101L).getAccountComment() == null,
                "A snapshot must remain detached from later persistence changes");
            assertThrows(AssertionError.class, () -> graph.assertUnchanged(before));
        } finally {
            write(() -> entities.merge(before.respondents().get(101L)));
        }
        graph.assertUnchanged(before);
    }

    @Test
    void detectsCommittedInsertionsAndIgnoresRolledBackRows() {
        var before = graph.snapshot();
        try {
            write(() -> entities.persist(party(OWN)));
            assertThrows(AssertionError.class, () -> graph.assertUnchanged(before));
        } finally {
            write(() -> remove(PublicationQaParty.class, OWN));
        }
        new TransactionTemplate(transactions).executeWithoutResult(status -> {
            entities.persist(party(OWN));
            entities.flush();
            status.setRollbackOnly();
        });
        graph.assertUnchanged(before);
    }

    @Test
    void snapshotConstructorCopiesManagedRows() {
        var before = graph.snapshot();
        new TransactionTemplate(transactions).executeWithoutResult(status -> {
            PublicationQaRespondent managed = entities.find(PublicationQaRespondent.class, 101L);
            final var copy = new PublicationQaGraph.Snapshot(java.util.Map.of(101L, managed), before.creditors(),
                before.parties(), before.associations(), before.aliases(), before.debtors(), before.contacts(),
                before.orderTerms(), before.notes(), before.reservations());
            entities.merge(managed.toBuilder().accountComment("Changed managed instance").build());
            entities.flush();
            status.setRollbackOnly();
            assertTrue(copy.respondents().get(101L).getAccountComment() == null,
                "Public snapshot construction must copy managed row values");
        });
        graph.assertUnchanged(before);
    }

    @Test
    void snapshotsUseIndependentCommittedTransactions() {
        var before = graph.snapshot();
        new TransactionTemplate(transactions).executeWithoutResult(status -> {
            entities.merge(before.respondents().get(101L).toBuilder().accountComment("Uncommitted").build());
            entities.flush();
            graph.assertUnchanged(before);
            status.setRollbackOnly();
        });
        graph.assertUnchanged(before);
    }

    @Test
    void refusesSharedChildrenBeforeDeletingAnything() {
        var before = graph.snapshot();
        long draftId = fixture(before);
        try {
            write(() -> entities.persist(PublicationQaCreditor.builder().creditorAccountId(SIBLING)
                .businessUnitId((short) 1).accountNumber("SyntheticSibling").creditorAccountType("MN")
                .minorCreditorPartyId(OWN).fromSuspense(false).holdPayout(false).payByBacs(false).build()));
            var populated = graph.snapshot();
            assertThrows(AssertionError.class, () -> graph.removeOwned(before, draftId, MARKER));
            graph.assertUnchanged(populated);
        } finally {
            write(() -> remove(PublicationQaCreditor.class, SIBLING));
            cleanupFixture(draftId);
        }
    }

    @Test
    void cleansOnlyItsGraphAndRetainsBaselineAndLaterSibling() {
        var before = graph.snapshot();
        long draftId = fixture(before);
        try {
            write(() -> entities.persist(party(SIBLING)));
            var populated = graph.snapshot();
            assertTrue(populated.orderTerms().containsKey(OWN) && populated.notes().containsKey(OWN)
                && populated.contacts().containsKey(OWN) && populated.debtors().containsKey(OWN)
                && populated.reservations().containsKey(OWN) && populated.aliases().containsKey(OWN),
                "Every populated mapping must hydrate from the migrated database");
            assertTrue(populated.creditors().get(OWN).getNonUkBankDetail() != null
                && populated.parties().get(OWN).getBirthDate().equals(LocalDate.of(2000, 1, 2)),
                "JSON and DATE scalar mappings must hydrate populated values");
            graph.removeOwned(before, draftId, MARKER);
            var after = graph.snapshot();
            assertTrue(after.respondents().equals(before.respondents()), "Baseline respondent must survive");
            assertTrue(after.parties().keySet().equals(java.util.Set.of(SIBLING)), "Later sibling must survive");
            assertTrue(after.creditors().isEmpty() && after.associations().isEmpty() && after.aliases().isEmpty()
                && after.contacts().isEmpty() && after.debtors().isEmpty() && after.orderTerms().isEmpty()
                && after.notes().isEmpty() && after.reservations().isEmpty(), "Owned children must be removed");
            write(() -> assertTrue(entities.find(DraftCasefileEntity.class, draftId) == null,
                "Owned draft must be removed"));
        } finally {
            cleanupFixture(draftId);
        }
    }

    @Test
    void cleansSubmittedMinorWithoutAnOrderAndRetainsSibling() {
        var before = graph.snapshot();
        long draftId = fixture(before);
        try {
            write(() -> {
                entities.persist(party(SIBLING));
                entities.persist(party(UNREFERENCED).toBuilder().accountType("Minor Creditor").build());
                entities.persist(PublicationQaCreditor.builder().creditorAccountId(UNREFERENCED)
                    .businessUnitId((short) 1).accountNumber("44000003K").creditorAccountType("MN")
                    .minorCreditorPartyId(UNREFERENCED).fromSuspense(false).holdPayout(false).payByBacs(false).build());
                DraftCasefileEntity saved = entities.find(DraftCasefileEntity.class, draftId);
                String input = "{\"respondent_account\":{\"remo_reference\":\"" + MARKER + "\"},"
                    + "\"minor_creditors\":[{\"creditor_sequence\":7,\"party_details\":{\"organisation\":false,"
                    + "\"individual_details\":{\"surname\":\"Synthetic Observer\"},"
                    + "\"address\":{\"address_line_1\":\"Synthetic address\",\"cjs_code\":1}}}]}";
                String snapshot = "{\"minor_creditor_accounts\":[{\"creditor_sequence\":7,"
                    + "\"account_id\":" + UNREFERENCED + ",\"account_number\":\"44000003K\"}]}";
                entities.merge(saved.toBuilder().casefile(input).casefileSnapshot(snapshot).build());
            });
            graph.removeOwned(before, draftId, MARKER);
            var after = graph.snapshot();
            assertTrue(after.creditors().isEmpty(), "Unreferenced submitted minor account must be removed");
            assertTrue(after.parties().keySet().equals(java.util.Set.of(SIBLING)),
                "Unreferenced minor party must be removed while retaining the later sibling");
            assertTrue(after.respondents().equals(before.respondents()), "Baseline respondent must survive");
        } finally {
            cleanupFixture(draftId);
        }
    }

    @Test
    void refusesIncorrectMarkerBeforeDeletingAnything() {
        var before = graph.snapshot();
        long draftId = fixture(before);
        try {
            var populated = graph.snapshot();
            assertThrows(AssertionError.class, () -> graph.removeOwned(before, draftId, "E2E-ffffffffffffffff"));
            graph.assertUnchanged(populated);
        } finally {
            cleanupFixture(draftId);
        }
    }

    @Test
    void refusesBaselineChangesBeforeDeletingAnything() {
        var before = graph.snapshot();
        long draftId = fixture(before);
        try {
            write(() -> entities.merge(before.respondents().get(101L).toBuilder().accountComment("Changed").build()));
            var populated = graph.snapshot();
            assertThrows(AssertionError.class, () -> graph.removeOwned(before, draftId, MARKER));
            graph.assertUnchanged(populated);
        } finally {
            write(() -> entities.merge(before.respondents().get(101L)));
            cleanupFixture(draftId);
        }
    }

    private long fixture(PublicationQaGraph.Snapshot before) {
        return new TransactionTemplate(transactions).execute(status -> {
            entities.persist(PublicationQaDebtor.builder().debtorDetailId(OWN)
                .employerName("Synthetic Employer").build());
            entities.persist(PublicationQaContact.builder().thirdPartyContactId(OWN)
                .nameOrganisation("Synthetic Contact").relationship("Agent").addressLine1("Synthetic address")
                .country(5000000301L).versionNumber(1L).build());
            entities.persist(party(OWN));
            entities.persist(PublicationQaAlias.builder().aliasId(OWN).partyId(OWN).surname("Synthetic Alias")
                .forenames("Test").sequenceNumber(1).build());
            entities.persist(before.respondents().get(101L).toBuilder().respondentAccountId(OWN)
                .accountNumber("44000001S").remoReference(MARKER).debtorDetailId(OWN)
                .thirdPartyContactId(OWN).build());
            entities.persist(PublicationQaCreditor.builder().creditorAccountId(OWN).businessUnitId((short) 1)
                .accountNumber("44000002O").creditorAccountType("MN").minorCreditorPartyId(OWN)
                .fromSuspense(false).holdPayout(false).payByBacs(false).versionNumber(1L)
                .nonUkBankDetail("{\"account_name\":\"Synthetic Observer\"}").build());
            entities.persist(PublicationQaAssociation.builder().respondentAccountPartyId(OWN)
                .respondentAccountId(OWN).associatedAccountId(OWN).associationType("Respondent").build());
            entities.persist(PublicationQaOrderTerm.builder().orderTermsId(OWN).respondentAccountId(OWN)
                .creditorAccountId(OWN).resultId("MAT").postedDate(WHEN).imposedDate(WHEN)
                .imposedAmount(new BigDecimal("12.34")).completed(false).build());
            entities.persist(PublicationQaNote.builder().noteId(OWN).noteType("NT")
                .associatedRecordType("respondent_accounts").associatedRecordId(Long.toString(OWN))
                .noteText("Synthetic observer note").postedDate(WHEN).build());
            entities.persist(PublicationQaReservation.builder().accountNumberIndexId(OWN).businessUnitId((short) 1)
                .accountNumber("44000001S").associatedRecordType("respondent_accounts").build());
            DraftCasefileEntity draft = DraftCasefileEntity.builder().businessUnitId((short) 1).createdDate(WHEN)
                .submittedBy("Synthetic").submittedByName("Synthetic Submitter").casefileType("REMO In")
                .casefileStatus(DraftCasefileStatus.PUBLISHED).casefileStatusDate(WHEN).timelineData("[]")
                .casefile("{\"respondent_account\":{\"remo_reference\":\"" + MARKER + "\"}}")
                .casefileSnapshot("{}").accountId(OWN).accountNumber("44000001S").build();
            entities.persist(draft);
            entities.flush();
            return draft.getDraftCasefileId();
        });
    }

    private PublicationQaParty party(long id) {
        return PublicationQaParty.builder().partyId(id).organisation(false).surname("Synthetic Observer")
            .birthDate(LocalDate.of(2000, 1, 2))
            .addressLine1("Synthetic address").countryId(5000000301L).restrictPersonalInformation(false).build();
    }

    private void cleanupFixture(long draftId) {
        write(() -> {
            remove(PublicationQaOrderTerm.class, OWN);
            remove(PublicationQaNote.class, OWN);
            remove(PublicationQaAssociation.class, OWN);
            remove(DraftCasefileEntity.class, draftId);
            remove(PublicationQaRespondent.class, OWN);
            remove(PublicationQaCreditor.class, OWN);
            remove(PublicationQaCreditor.class, UNREFERENCED);
            remove(PublicationQaAlias.class, OWN);
            remove(PublicationQaParty.class, OWN);
            remove(PublicationQaParty.class, SIBLING);
            remove(PublicationQaParty.class, UNREFERENCED);
            remove(PublicationQaDebtor.class, OWN);
            remove(PublicationQaContact.class, OWN);
            remove(PublicationQaReservation.class, OWN);
        });
    }

    private <T> void remove(Class<T> type, long id) {
        T row = entities.find(type, id);
        if (row != null) {
            entities.remove(row);
            entities.flush();
        }
    }

    private void write(Runnable action) {
        new TransactionTemplate(transactions).executeWithoutResult(status -> action.run());
    }
}
