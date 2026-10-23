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
    void completeFixtureRetainsApplicantAndAssociatesTwoIndependentMinors() throws Exception {
        JsonNode valid = OBJECT_MAPPER.readTree(factory.valid(MARKER));
        JsonNode complete = OBJECT_MAPPER.readTree(factory.withMinorCreditors(MARKER));
        JsonNode terms = complete.at("/casefile/respondent_account/order_details/order_terms");
        assertThat(terms.size()).isEqualTo(3);
        assertThat(terms.get(0)).isEqualTo(valid.at("/casefile/respondent_account/order_details/order_terms/0"));
        JsonNode minors = complete.at("/casefile/minor_creditors");
        assertThat(minors.size()).isEqualTo(2);
        for (int index = 0; index < 2; index++) {
            int sequence = index == 0 ? 7 : 23;
            assertThat(minors.get(index).path("creditor_sequence").intValue()).isEqualTo(sequence);
            assertThat(minors.get(index).at("/party_details/individual_details/surname").asText())
                .isEqualTo(index == 0 ? "MinorSeven" : "MinorTwentyThree");
            assertThat(minors.get(index).at("/party_details/address/cjs_code").intValue()).isEqualTo(1);
            assertThat(minors.get(index).at("/bank_account_details/bank_account_type").asText())
                .isEqualTo("None or not applicable");
            assertThat(terms.get(index + 1).path("result_id").asText()).isEqualTo("MAT");
            assertThat(terms.get(index + 1).path("creditor_type").asText()).isEqualTo("Minor Creditor");
            assertThat(terms.get(index + 1).path("minor_creditor_sequence").intValue()).isEqualTo(sequence);
            assertThat(terms.get(index + 1).at("/result_responses/0/response").asText())
                .isEqualTo(index == 0 ? "25.00" : "35.00");
        }
        ((com.fasterxml.jackson.databind.node.ObjectNode) complete.at("/casefile")).remove("minor_creditors");
        ((com.fasterxml.jackson.databind.node.ArrayNode) terms).remove(2);
        ((com.fasterxml.jackson.databind.node.ArrayNode) terms).remove(1);
        assertThat(complete).isEqualTo(valid);
        assertThat(OBJECT_MAPPER.readTree(factory.withMinorCreditors(MARKER)).at("/casefile/minor_creditors").size())
            .isEqualTo(2);
    }

    @Test
    void unpublishableChangesOnlyTheFirstAmount() throws Exception {
        JsonNode expected = OBJECT_MAPPER.readTree(factory.withMinorCreditors(MARKER));
        ((com.fasterxml.jackson.databind.node.ObjectNode) expected.at(
            "/casefile/respondent_account/order_details/order_terms/0/result_responses/0"))
            .put("response", "not-an-amount");
        assertThat(OBJECT_MAPPER.readTree(factory.unpublishable(MARKER))).isEqualTo(expected);
        assertThat(OBJECT_MAPPER.readTree(factory.withMinorCreditors(MARKER)).at(
            "/casefile/respondent_account/order_details/order_terms/0/result_responses/0/response").asText())
            .isEqualTo("100.00");
    }

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
