package uk.gov.hmcts.opal.logging;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;
import uk.gov.hmcts.opal.event.DraftCasefileListPersonalDataEvent;
import uk.gov.hmcts.opal.event.DraftCasefilePersonalDataEvent.Operation;
import uk.gov.hmcts.opal.event.DraftCasefilePersonalDataEvent.ParticipantCategory;
import uk.gov.hmcts.opal.event.DraftCasefilePersonalDataEvent;
import uk.gov.hmcts.opal.generated.model.CasefileSnapshot;
import uk.gov.hmcts.opal.generated.model.CasefileSnapshotMinorCreditorAccount;

import java.time.Instant;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.EnumSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DraftCasefileParticipantCategoryResolverTest {

    private final JsonMapper json = JsonMapper.builder().build();
    private final DraftCasefileParticipantCategoryResolver resolver = new DraftCasefileParticipantCategoryResolver();

    @ParameterizedTest
    @ValueSource(booleans = {false, true})
    void includesRespondentAndApplicantEvenForOrganisation(boolean organisation) {
        JsonNode casefile = json.readTree("""
            {"respondent_account":{"respondent":{"party_details":{"organisation":false}}},
             "applicant":{"party_details":{"organisation":%s},
               "bank_account_details":{"bank_account_type":"None or not applicable"}}}
            """.formatted(organisation));
        assertThat(resolver.resolve(casefile)).containsExactlyInAnyOrder(
            ParticipantCategory.RESPONDENT, ParticipantCategory.APPLICANT_BENEFICIARY);
    }

    @ParameterizedTest
    @ValueSource(strings = {
        "{\"respondent_account\":{\"respondent\":{\"debtor_details\":{\"marker\":\"Synthetic\"}}}}",
        "{\"respondent_account\":{\"respondent\":{\"third_party_details\":{\"marker\":\"Synthetic\"}}}}",
        "{\"applicant\":{\"third_party_details\":{\"marker\":\"Synthetic\"}}}",
        "{\"applicant\":{\"bank_account_details\":{\"uk_bank_details\":{\"marker\":\"Synthetic\"}}}}",
        "{\"applicant\":{\"bank_account_details\":{\"non_uk_bank_details\":{\"marker\":\"Synthetic\"}}}}",
        "{\"minor_creditors\":[{\"bank_account_details\":{\"uk_bank_details\":{\"marker\":\"Synthetic\"}}}]}",
        "{\"minor_creditors\":[{\"bank_account_details\":{\"non_uk_bank_details\":{\"marker\":\"Synthetic\"}}}]}"
    })
    void selectsRelatedPartiesWithoutMutatingInput(String source) {
        JsonNode casefile = json.readTree(source);
        JsonNode before = casefile.deepCopy();
        assertThat(resolver.resolve(casefile)).contains(ParticipantCategory.RELATED_PARTIES);
        assertThat(casefile).isEqualTo(before);
    }

    @Test
    void groupsMultipleMinorCreditorsWithoutInferringRelatedPartiesFromNames() {
        JsonNode casefile = json.readTree("""
            {"minor_creditors":[{"party_details":{"surname":"Synthetic Name"},
              "bank_account_details":{"bank_account_type":"None or not applicable"}},
              {"party_details":{"surname":"Synthetic Other"}}]}
            """);
        assertThat(resolver.resolve(casefile)).containsExactlyInAnyOrder(ParticipantCategory.RESPONDENT,
            ParticipantCategory.APPLICANT_BENEFICIARY, ParticipantCategory.MINOR_CREDITOR);
        assertThat(resolver.resolve(json.readTree("{\"minor_creditors\":[]}")))
            .doesNotContain(ParticipantCategory.MINOR_CREDITOR, ParticipantCategory.RELATED_PARTIES);
    }

    @Test
    void eventCopiesCategoriesAndRetainsNoCasefileOrPartyDetails() {
        JsonNode casefile = json.readTree("""
            {"applicant":{"party_details":{"surname":"SYNTHETIC_NAME_MARKER",
              "address":"SYNTHETIC_ADDRESS_MARKER"},"bank_account_details":{
              "uk_bank_details":{"account_name":"SYNTHETIC_BANK_MARKER"}}}}
            """);
        Set<ParticipantCategory> categories = EnumSet.copyOf(resolver.resolve(casefile));
        DraftCasefilePersonalDataEvent event = new DraftCasefilePersonalDataEvent(Operation.SUBMISSION,
            123L, 99L, "192.0.2.1",
            Instant.parse("2026-10-01T12:00:00.123456Z"), categories);
        categories.clear();
        assertThat(event.participantCategories()).hasSize(3);
        assertThatThrownBy(() -> event.participantCategories().clear())
            .isInstanceOf(UnsupportedOperationException.class);
        assertThat(DraftCasefilePersonalDataEvent.class.getRecordComponents()).extracting("name")
            .containsExactly("operation", "draftId", "userId", "ipAddress", "occurredAt", "participantCategories");
        assertThat(event.toString()).doesNotContain("SYNTHETIC_NAME_MARKER", "SYNTHETIC_ADDRESS_MARKER",
            "SYNTHETIC_BANK_MARKER");
    }

    @Test
    void summaryRolesComeOnlyFromReturnedSnapshot() {
        var snapshot = new CasefileSnapshot().minorCreditorAccounts(List.of());
        assertThat(resolver.resolveSummary(snapshot)).containsExactlyInAnyOrder(
            ParticipantCategory.RESPONDENT, ParticipantCategory.APPLICANT_BENEFICIARY);
        snapshot.minorCreditorAccounts(List.of(new CasefileSnapshotMinorCreditorAccount()));
        assertThat(resolver.resolveSummary(snapshot)).containsExactlyInAnyOrder(
            ParticipantCategory.RESPONDENT, ParticipantCategory.APPLICANT_BENEFICIARY,
            ParticipantCategory.MINOR_CREDITOR);
        assertThat(resolver.resolveSummary(snapshot)).doesNotContain(ParticipantCategory.RELATED_PARTIES);
    }

    @Test
    void listEventCopiesAndDeduplicatesCategoryIdsAndDropsEmptyGroups() {
        List<Long> ids = new ArrayList<>(List.of(123L, 123L, 456L));
        Map<ParticipantCategory, List<Long>> groups = new EnumMap<>(ParticipantCategory.class);
        groups.put(ParticipantCategory.RESPONDENT, ids);
        groups.put(ParticipantCategory.MINOR_CREDITOR, List.of());
        var event = new DraftCasefileListPersonalDataEvent(99L, "192.0.2.1", Instant.EPOCH, groups);
        ids.clear();
        groups.clear();
        assertThat(event.draftIdsByCategory()).containsExactlyEntriesOf(
            Map.of(ParticipantCategory.RESPONDENT, List.of(123L, 456L)));
        assertThatThrownBy(() -> event.draftIdsByCategory().clear())
            .isInstanceOf(UnsupportedOperationException.class);
        assertThatThrownBy(() -> event.draftIdsByCategory().get(ParticipantCategory.RESPONDENT).clear())
            .isInstanceOf(UnsupportedOperationException.class);
    }
}
