package uk.gov.hmcts.opal.data;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.restassured.builder.ResponseBuilder;
import org.junit.jupiter.api.Test;

class DraftCasefileRequestFactoryTest {

    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();
    private static final String MARKER = "E2E-550e8400e29b41d4";

    private final DraftCasefileRequestFactory factory = new DraftCasefileRequestFactory();

    @Test
    void validRequestUsesApprovedReferencesAndSyntheticData() throws Exception {
        String body = factory.valid(MARKER);
        JsonNode request = OBJECT_MAPPER.readTree(body);

        assertThat(request.at("/business_unit_id").asInt()).isEqualTo(44);
        assertThat(request.at("/casefile/respondent_account/business_unit_id").asInt()).isEqualTo(44);
        assertThat(request.at("/casefile/respondent_account/application_code").asText()).isEqualTo("AP00001");
        assertThat(request.at("/casefile/respondent_account/respondent/party_details/address/cjs_code").asInt())
            .isEqualTo(1);
        assertThat(request.at("/casefile/respondent_account/order_details/order_terms/0/result_id").asText())
            .isEqualTo("MAT");
        assertThat(request.at("/casefile/respondent_account/remo_reference").asText()).isEqualTo(MARKER);
        assertThat(body).contains("Synthetic", "Respondent", "Applicant")
            .doesNotContain("Example", "PRIVATE", "SYNTHETIC_PRIVATE_NAME");
    }

    @Test
    void referenceVariantsChangeExactlyOnePath() throws Exception {
        JsonNode valid = OBJECT_MAPPER.readTree(factory.valid(MARKER));

        assertVariant(valid, InvalidDraftReference.UNKNOWN_APPLICATION,
            "/casefile/respondent_account/application_code", "ZZ99999");
        assertVariant(valid, InvalidDraftReference.INACTIVE_COUNTRY,
            "/casefile/respondent_account/respondent/party_details/address/cjs_code", 0);
        assertVariant(valid, InvalidDraftReference.HISTORICAL_COUNTRY,
            "/casefile/respondent_account/respondent/party_details/address/cjs_code", 2);
    }

    @Test
    void featureLabelsMapExactly() {
        assertThat(InvalidDraftReference.fromFeatureValue("unknown application"))
            .isEqualTo(InvalidDraftReference.UNKNOWN_APPLICATION);
        assertThat(InvalidDraftReference.fromFeatureValue("inactive country"))
            .isEqualTo(InvalidDraftReference.INACTIVE_COUNTRY);
        assertThat(InvalidDraftReference.fromFeatureValue("historical country"))
            .isEqualTo(InvalidDraftReference.HISTORICAL_COUNTRY);
        assertThatThrownBy(() -> InvalidDraftReference.fromFeatureValue("other"))
            .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void scenarioStateResetsMarkerAndClearsCreatedResourcesAfterCleanup() {
        DraftCasefileScenarioState state = new DraftCasefileScenarioState();
        state.reset();
        String firstMarker = state.marker();
        assertThat(firstMarker).matches("E2E-[0-9a-f]{16}");
        state.latestResponse(new ResponseBuilder().setStatusCode(201).build());
        state.createdId(123);
        state.cleanupToken("test-token-placeholder");

        state.clearAfterCleanup();
        assertThat(state.marker()).isEqualTo(firstMarker);
        assertThat(state.latestResponse()).isNull();
        assertThat(state.createdId()).isNull();
        assertThat(state.cleanupToken()).isNull();

        state.reset();
        assertThat(state.marker()).isNotEqualTo(firstMarker);
    }

    private void assertVariant(JsonNode valid, InvalidDraftReference variant, String path, Object expected)
        throws Exception {
        JsonNode changed = OBJECT_MAPPER.readTree(factory.withInvalidReference(MARKER, variant));
        JsonNode original = valid.deepCopy();
        if (expected instanceof String string) {
            assertThat(changed.at(path).asText()).isEqualTo(string);
            ((com.fasterxml.jackson.databind.node.ObjectNode) original.at(path.substring(0, path.lastIndexOf('/'))))
                .put(path.substring(path.lastIndexOf('/') + 1), string);
        } else {
            assertThat(changed.at(path).asInt()).isEqualTo(expected);
            ((com.fasterxml.jackson.databind.node.ObjectNode) original.at(path.substring(0, path.lastIndexOf('/'))))
                .put(path.substring(path.lastIndexOf('/') + 1), (Integer) expected);
        }
        assertThat(changed).isEqualTo(original);
    }
}
