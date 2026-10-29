package uk.gov.hmcts.opal.mapper;

import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;
import uk.gov.hmcts.opal.repository.extensions.DraftCasefilePublicationRepository.PublicationResult;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DraftCasefilePublicationMapperTest {
    private static final JsonMapper JSON = JsonMapper.builder().build();
    private final DraftCasefilePublicationMapper mapper = new DraftCasefilePublicationMapper();
    private final String snapshot = """
        {"respondent_account":{"account_id":null,"account_number":null,"respondent_name":"Synthetic respondent"},
         "applicant_account":{"account_id":null,"account_number":null,"applicant_name":"Synthetic applicant"},
         "minor_creditor_accounts":[
           {"creditor_sequence":7,"account_id":null,"account_number":null,"name":"Seven"},
           {"creditor_sequence":3,"account_id":null,"account_number":null,"name":"Three"}],"retained":"value"}
        """;
    private final String output = """
        {"respondent_account":{"account_id":9007199254740993,"account_number":"00001A"},
         "applicant_account":{"account_id":9007199254740994,"account_number":"00002B"},
         "minor_creditor_accounts":[{"creditor_sequence":3,"account_id":9007199254740995,"account_number":"00003C"},
           {"creditor_sequence":7,"account_id":9007199254740996,"account_number":"00004D"}]}
        """;

    @Test
    void mergesMinorIdentitiesBySequenceWithoutLosingNames() {
        var saved = JSON.readTree("{\"minor_creditors\":[{\"creditor_sequence\":7},{\"creditor_sequence\":3}]}");
        var result = JSON.readTree(mapper.mergePublishedAccounts(snapshot, saved,
            new PublicationResult(9007199254740993L, "00001A", output)));
        assertThat(result.at("/minor_creditor_accounts/0/account_id").longValue()).isEqualTo(9007199254740996L);
        assertThat(result.at("/minor_creditor_accounts/0/name").asString()).isEqualTo("Seven");
        assertThat(result.at("/respondent_account/respondent_name").asString()).isEqualTo("Synthetic respondent");
        assertThat(result.get("retained").asString()).isEqualTo("value");
    }

    @Test
    void rejectsMismatchedOrIncompleteProcedureOutputs() {
        var saved = JSON.readTree("{\"minor_creditors\":[{\"creditor_sequence\":7},{\"creditor_sequence\":3}]}");
        for (String invalid : new String[]{"{}", output.replace("9007199254740993", "9007199254740992"),
            output.replace("\"creditor_sequence\":3", "\"creditor_sequence\":7"),
            output.replace("\"creditor_sequence\":3", "\"creditor_sequence\":4"),
            output.replace("\"account_number\":\"00002B\"", "\"account_number\":null")}) {
            assertThatThrownBy(() -> mapper.mergePublishedAccounts(snapshot, saved,
                new PublicationResult(9007199254740993L, "00001A", invalid)))
                .isInstanceOf(IllegalStateException.class).hasNoCause();
        }
    }

    @Test
    void rejectsAlreadyLinkedPendingSnapshot() {
        var saved = JSON.readTree("{\"minor_creditors\":[{\"creditor_sequence\":7},{\"creditor_sequence\":3}]}");
        assertThatThrownBy(() -> mapper.validatePendingSnapshot(snapshot.replace("\"account_id\":null",
            "\"account_id\":1"), saved)).isInstanceOf(IllegalStateException.class);
    }
}
