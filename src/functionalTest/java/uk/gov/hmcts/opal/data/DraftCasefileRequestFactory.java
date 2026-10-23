package uk.gov.hmcts.opal.data;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;

public final class DraftCasefileRequestFactory {

    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();

    public String withMinorCreditors(String marker) {
        try {
            ObjectNode root = (ObjectNode) OBJECT_MAPPER.readTree(valid(marker));
            ArrayNode creditors = ((ObjectNode) root.path("casefile")).putArray("minor_creditors");
            ArrayNode terms = (ArrayNode) root.at("/casefile/respondent_account/order_details/order_terms");
            addMinor(root, creditors, terms, 7, "MinorSeven", "25.00");
            addMinor(root, creditors, terms, 23, "MinorTwentyThree", "35.00");
            return OBJECT_MAPPER.writeValueAsString(root);
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("Unable to build the synthetic Draft Casefile request");
        }
    }

    public String unpublishable(String marker) {
        try {
            ObjectNode root = (ObjectNode) OBJECT_MAPPER.readTree(withMinorCreditors(marker));
            ((ObjectNode) root.at("/casefile/respondent_account/order_details/order_terms/0/result_responses/0"))
                .put("response", "not-an-amount");
            return OBJECT_MAPPER.writeValueAsString(root);
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("Unable to build the synthetic Draft Casefile request");
        }
    }

    private static void addMinor(ObjectNode root, ArrayNode creditors, ArrayNode terms, int sequence,
                                 String surname, String amount) {
        ObjectNode creditor = root.path("casefile").path("applicant").deepCopy();
        creditor.put("creditor_sequence", sequence);
        ((ObjectNode) creditor.at("/party_details/individual_details")).put("surname", surname);
        creditors.add(creditor);
        ObjectNode term = terms.get(0).deepCopy();
        term.put("creditor_type", "Minor Creditor").put("minor_creditor_sequence", sequence);
        ((ObjectNode) term.at("/result_responses/0")).put("response", amount);
        terms.add(term);
    }

    public String valid(String marker) {
        try {
            ObjectNode root = (ObjectNode) OBJECT_MAPPER.readTree("""
                {"business_unit_id":44,"casefile_type":"REMO In","casefile":{
                  "respondent_account":{"business_unit_id":44,"application_code":"AP00001",
                    "casefile_type":"REMO In","remo_reference":"MARKER",
                    "respondent":{"party_details":{"organisation":false,
                      "individual_details":{"forenames":"Synthetic","surname":"Respondent"},
                      "address":{"address_line_1":"Synthetic address","cjs_code":1}}},
                    "order_details":{"date_ordered":"2026-09-01",
                      "date_arrears_last_updated":"2026-09-01","interest_flag":false,
                      "indexation":"None","payment_arrangement":"Court","payment_period":"Monthly",
                      "order_terms":[{"result_id":"MAT","creditor_type":"Applicant",
                        "result_responses":[{"parameter_name":"Amount","response":"100.00"}]}]}},
                  "applicant":{"party_details":{"organisation":false,
                    "individual_details":{"forenames":"Synthetic","surname":"Applicant"},
                    "address":{"address_line_1":"Synthetic address","cjs_code":1}},
                    "bank_account_details":{"bank_account_type":"None or not applicable"}}}}
                """);
            ((ObjectNode) root.at("/casefile/respondent_account")).put("remo_reference", marker);
            return OBJECT_MAPPER.writeValueAsString(root);
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("Unable to build the synthetic Draft Casefile request", exception);
        }
    }

    public String withInvalidReference(String marker, InvalidDraftReference reference) {
        try {
            ObjectNode root = (ObjectNode) OBJECT_MAPPER.readTree(valid(marker));
            ObjectNode account = (ObjectNode) root.at("/casefile/respondent_account");
            ObjectNode address = (ObjectNode) root.at(
                "/casefile/respondent_account/respondent/party_details/address");
            switch (reference) {
                case UNKNOWN_APPLICATION -> account.put("application_code", "ZZ99999");
                case INACTIVE_COUNTRY -> address.put("cjs_code", 0);
                case HISTORICAL_COUNTRY -> address.put("cjs_code", 2);
            }
            return OBJECT_MAPPER.writeValueAsString(root);
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("Unable to build the synthetic Draft Casefile request", exception);
        }
    }
}
