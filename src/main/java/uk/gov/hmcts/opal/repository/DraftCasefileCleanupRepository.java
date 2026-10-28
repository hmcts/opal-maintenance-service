package uk.gov.hmcts.opal.repository;

import lombok.RequiredArgsConstructor;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;
import tools.jackson.databind.json.JsonMapper;
import uk.gov.hmcts.opal.common.exception.OpalApiException;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.exception.DraftCasefileError;
import uk.gov.hmcts.opal.mapper.DraftCasefilePublicationMapper;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/** Native graph traversal for test cleanup; all calls belong to the locked draft's transaction. */
@Repository
@RequiredArgsConstructor
@ConditionalOnProperty(prefix = "opal.testing-support-endpoints", name = "enabled", havingValue = "true")
public class DraftCasefileCleanupRepository {
    private final NamedParameterJdbcTemplate jdbc;
    private final DraftCasefilePublicationMapper mapper;

    public void deleteUnversionedDraft(Long draftId) {
        // Spring Data treats a null @Version as new and otherwise silently skips deletion.
        // The service has already locked and scoped this unchanged, managed legacy row.
        require(jdbc.update("""
            DELETE FROM draft_casefiles WHERE draft_casefile_id=:id AND version_number IS NULL
            """, Map.of("id", draftId)) == 1);
    }

    public Graph lockGraph(DraftCasefileEntity draft, String marker) {
        try {
            mapper.validatePublicationState(draft);
        } catch (IllegalStateException invalid) {
            throw conflict();
        }
        var parameters = new MapSqlParameterSource("respondent", draft.getAccountId());
        var respondents = jdbc.queryForList("""
            SELECT respondent_account_id, business_unit_id, account_number, remo_reference,
                   debtor_detail_id, third_party_contact_id, version_number, account_balance
            FROM respondent_accounts WHERE respondent_account_id=:respondent FOR UPDATE
            """, parameters);
        require(respondents.size() == 1);
        var respondent = respondents.getFirst();
        require(draft.getBusinessUnitId().intValue() == ((Number) respondent.get("business_unit_id")).intValue()
            && draft.getAccountNumber().equals(respondent.get("account_number"))
            && marker.equals(respondent.get("remo_reference"))
            && ((Number) respondent.get("version_number")).longValue() == 1
            && ((BigDecimal) respondent.get("account_balance")).signum() == 0);

        var associations = jdbc.queryForList("""
            SELECT association_type::text, associated_account_id FROM respondent_account_parties
            WHERE respondent_account_id=:respondent ORDER BY respondent_account_party_id FOR UPDATE
            """, parameters);
        var respondentParties = associated(associations, "Respondent");
        var applicants = associated(associations, "Applicant");
        require(respondentParties.size() == 1 && applicants.size() == 1
            && associations.size() == 2 + associated(associations, "Central Authority").size()
            && associated(associations, "Central Authority").size() <= 1);

        var snapshot = JsonMapper.builder().build().readTree(draft.getCasefileSnapshot());
        final var saved = JsonMapper.builder().build().readTree(draft.getCasefile());
        Map<Long, String> minorNumbers = new HashMap<>();
        var applicant = snapshot.path("applicant_account");
        minorNumbers.put(applicant.path("account_id").longValue(), applicant.path("account_number").asString());
        require(new HashSet<>(applicants).equals(minorNumbers.keySet()));
        for (var minor : snapshot.path("minor_creditor_accounts")) {
            require(minorNumbers.putIfAbsent(minor.path("account_id").longValue(),
                minor.path("account_number").asString()) == null);
        }
        final Set<Long> creditorIds = new HashSet<>(minorNumbers.keySet());
        var termCreditors = jdbc.queryForList("""
            SELECT creditor_account_id FROM order_terms WHERE respondent_account_id=:respondent
            ORDER BY order_terms_id FOR UPDATE
            """, parameters, Long.class);
        var savedTerms = saved.at("/respondent_account/order_details/order_terms");
        require(savedTerms.isArray() && !savedTerms.isEmpty() && savedTerms.size() == termCreditors.size());
        Set<String> majorCodes = new HashSet<>();
        for (var term : savedTerms) {
            if ("Major Creditor".equals(term.path("creditor_type").asString())) {
                majorCodes.add(term.path("major_creditor_code").asString());
            }
        }
        Set<Long> expectedMajors = majorCodes.isEmpty() ? Set.of() : new HashSet<>(jdbc.queryForList("""
            SELECT major_creditor_id FROM major_creditors WHERE business_unit_id=:unit
                AND major_creditor_code IN (:codes)
            """, Map.of("unit", draft.getBusinessUnitId(), "codes", majorCodes), Long.class));
        require(expectedMajors.size() == majorCodes.size());
        final Set<Long> actualMajors = new HashSet<>();
        creditorIds.addAll(termCreditors);
        parameters.addValue("creditors", creditorIds);
        var creditors = jdbc.queryForList("""
            SELECT creditor_account_id, business_unit_id, account_number, creditor_account_type::text,
                   minor_creditor_party_id, major_creditor_id, third_party_contact_id, version_number
            FROM creditor_accounts WHERE creditor_account_id IN (:creditors)
            ORDER BY creditor_account_id FOR UPDATE
            """, parameters);
        require(creditors.size() == creditorIds.size());
        Map<Long, String> creditorNumbers = new HashMap<>();
        Set<Long> parties = new HashSet<>(respondentParties);
        Set<Long> contacts = new HashSet<>();
        addId(contacts, respondent.get("third_party_contact_id"));
        for (var creditor : creditors) {
            long id = ((Number) creditor.get("creditor_account_id")).longValue();
            String number = (String) creditor.get("account_number");
            require(draft.getBusinessUnitId().intValue() == ((Number) creditor.get("business_unit_id")).intValue());
            require(creditor.get("version_number") == null);
            if (minorNumbers.containsKey(id)) {
                require("MN".equals(creditor.get("creditor_account_type"))
                    && number.equals(minorNumbers.get(id)) && creditor.get("minor_creditor_party_id") != null
                    && creditor.get("major_creditor_id") == null);
                require(parties.add(((Number) creditor.get("minor_creditor_party_id")).longValue()));
            } else {
                require("MJ".equals(creditor.get("creditor_account_type"))
                    && creditor.get("major_creditor_id") != null && creditor.get("minor_creditor_party_id") == null);
                require(actualMajors.add(((Number) creditor.get("major_creditor_id")).longValue()));
            }
            creditorNumbers.put(id, number);
            addId(contacts, creditor.get("third_party_contact_id"));
        }
        require(actualMajors.equals(expectedMajors));
        parameters.addValue("parties", parties).addValue("draft", draft.getDraftCasefileId())
            .addValue("respondentParty", respondentParties.getFirst());
        require(jdbc.queryForList("""
            SELECT party_id FROM parties WHERE party_id IN (:parties)
                AND ((party_id=:respondentParty AND account_type='Respondent')
                    OR (party_id<>:respondentParty AND account_type='Minor Creditor'))
            ORDER BY party_id FOR UPDATE
            """, parameters, Long.class).size() == parties.size());
        lockContacts(contacts);
        Long debtor = respondent.get("debtor_detail_id") == null ? null
            : ((Number) respondent.get("debtor_detail_id")).longValue();
        if (debtor != null) {
            require(jdbc.queryForList("""
                SELECT debtor_detail_id FROM debtor_detail WHERE debtor_detail_id=:id FOR UPDATE
                """, Map.of("id", debtor), Long.class).size() == 1);
        }
        // Recheck all graph references before deleting. Cleanup-only writer protection is added separately.
        require(count("""
            SELECT COUNT(*) FROM draft_casefiles WHERE account_id=:respondent AND draft_casefile_id<>:draft
            """, parameters) == 0);
        require(count("""
            SELECT COUNT(*) FROM order_terms WHERE creditor_account_id IN (:creditors)
                AND respondent_account_id<>:respondent
            """, parameters) == 0);
        require(count("""
            SELECT COUNT(*) FROM respondent_account_parties WHERE respondent_account_id<>:respondent
                AND ((association_type='Applicant' AND associated_account_id IN (:creditors))
                  OR (association_type='Respondent' AND associated_account_id IN (:parties)))
            """, parameters) == 0);
        require(count("""
            SELECT COUNT(*) FROM creditor_accounts WHERE minor_creditor_party_id IN (:parties)
                AND creditor_account_id NOT IN (:creditors)
            """, parameters) == 0);
        requireExclusiveContacts(contacts, parameters);
        if (debtor != null) {
            parameters.addValue("debtor", debtor);
            require(count("""
                SELECT COUNT(*) FROM respondent_accounts WHERE debtor_detail_id=:debtor
                    AND respondent_account_id<>:respondent
                """, parameters) == 0);
        }
        lockReservations(draft, creditorNumbers, parameters);
        return new Graph(draft.getAccountId(), draft.getBusinessUnitId(), draft.getAccountNumber(),
            Map.copyOf(creditorNumbers), Set.copyOf(parties), Set.copyOf(contacts), debtor);
    }

    public void deleteGraph(Graph graph) {
        var parameters = new MapSqlParameterSource("respondent", graph.respondentId())
            .addValue("creditors", graph.creditorNumbers().keySet()).addValue("parties", graph.parties());
        jdbc.update("""
            DELETE FROM notes WHERE (associated_record_type='respondent_accounts'
                AND associated_record_id=CAST(:respondent AS text))
                OR (associated_record_type='creditor_accounts' AND associated_record_id IN (:creditorTextIds))
            """, parameters.addValue("creditorTextIds", graph.creditorNumbers().keySet().stream()
                .map(String::valueOf).toList()));
        jdbc.update("DELETE FROM order_terms WHERE respondent_account_id=:respondent", parameters);
        jdbc.update("DELETE FROM respondent_account_parties WHERE respondent_account_id=:respondent", parameters);
        require(jdbc.update("DELETE FROM respondent_accounts WHERE respondent_account_id=:respondent",
            parameters) == 1);
        require(jdbc.update("DELETE FROM creditor_accounts WHERE creditor_account_id IN (:creditors)", parameters)
            == graph.creditorNumbers().size());
        jdbc.update("DELETE FROM aliases WHERE party_id IN (:parties)", parameters);
        require(jdbc.update("DELETE FROM parties WHERE party_id IN (:parties)", parameters) == graph.parties().size());
        if (!graph.contacts().isEmpty()) {
            jdbc.update("DELETE FROM third_party_contact WHERE third_party_contact_id IN (:contacts)",
                Map.of("contacts", graph.contacts()));
        }
        if (graph.debtorId() != null) {
            jdbc.update("DELETE FROM debtor_detail WHERE debtor_detail_id=:id", Map.of("id", graph.debtorId()));
        }
        var numbers = new HashSet<>(graph.creditorNumbers().values());
        numbers.add(graph.respondentNumber());
        jdbc.update("""
            DELETE FROM account_number_index WHERE business_unit_id=:unit AND account_number IN (:numbers)
            """, Map.of("unit", graph.businessUnitId(), "numbers", numbers));
    }

    private void lockContacts(Set<Long> contacts) {
        if (!contacts.isEmpty()) {
            require(jdbc.queryForList("""
                SELECT third_party_contact_id FROM third_party_contact
                WHERE third_party_contact_id IN (:contacts) ORDER BY third_party_contact_id FOR UPDATE
                """, Map.of("contacts", contacts), Long.class).size() == contacts.size());
        }
    }

    private void requireExclusiveContacts(Set<Long> contacts, MapSqlParameterSource parameters) {
        if (!contacts.isEmpty()) {
            parameters.addValue("contacts", contacts);
            require(count("""
                SELECT COUNT(*) FROM respondent_accounts WHERE third_party_contact_id IN (:contacts)
                    AND respondent_account_id<>:respondent
                """, parameters) == 0);
            require(count("""
                SELECT COUNT(*) FROM creditor_accounts WHERE third_party_contact_id IN (:contacts)
                    AND creditor_account_id NOT IN (:creditors)
                """, parameters) == 0);
        }
    }

    private void lockReservations(DraftCasefileEntity draft, Map<Long, String> creditors,
                                  MapSqlParameterSource parameters) {
        var numbers = new HashSet<>(creditors.values());
        require(numbers.size() == creditors.size() && numbers.add(draft.getAccountNumber()));
        parameters.addValue("unit", draft.getBusinessUnitId()).addValue("numbers", numbers);
        var reservations = jdbc.queryForList("""
            SELECT account_number, associated_record_type::text FROM account_number_index
            WHERE business_unit_id=:unit AND account_number IN (:numbers)
            ORDER BY account_number_index_id FOR UPDATE
            """, parameters);
        require(reservations.size() == numbers.size());
        for (var reservation : reservations) {
            String type = draft.getAccountNumber().equals(reservation.get("account_number"))
                ? "respondent_accounts" : "creditor_accounts";
            require(type.equals(reservation.get("associated_record_type")));
        }
        require(count("""
            SELECT COUNT(*) FROM respondent_accounts WHERE business_unit_id=:unit
                AND account_number IN (:numbers) AND respondent_account_id<>:respondent
            """, parameters) == 0);
        require(count("""
            SELECT COUNT(*) FROM creditor_accounts WHERE business_unit_id=:unit
                AND account_number IN (:numbers) AND creditor_account_id NOT IN (:creditors)
            """, parameters) == 0);
    }

    private long count(String sql, MapSqlParameterSource parameters) {
        return jdbc.queryForObject(sql, parameters, Long.class);
    }

    private static List<Long> associated(List<Map<String, Object>> associations, String type) {
        return associations.stream().filter(row -> type.equals(row.get("association_type")))
            .map(row -> ((Number) row.get("associated_account_id")).longValue()).toList();
    }

    private static void addId(Set<Long> ids, Object value) {
        if (value != null) {
            ids.add(((Number) value).longValue());
        }
    }

    private static void require(boolean condition) {
        if (!condition) {
            throw conflict();
        }
    }

    private static OpalApiException conflict() {
        return new OpalApiException(DraftCasefileError.CLEANUP_NOT_ELIGIBLE,
            "Draft Casefile is not eligible for test cleanup");
    }

    public record Graph(Long respondentId, Short businessUnitId, String respondentNumber,
                        Map<Long, String> creditorNumbers, Set<Long> parties, Set<Long> contacts, Long debtorId) { }
}
