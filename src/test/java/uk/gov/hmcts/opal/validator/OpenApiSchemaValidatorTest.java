package uk.gov.hmcts.opal.validator;

import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.core.io.Resource;
import org.springframework.core.io.support.PathMatchingResourcePatternResolver;
import org.springframework.http.HttpStatus;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;
import tools.jackson.databind.node.ObjectNode;
import uk.gov.hmcts.opal.common.exception.OpalApiException;
import uk.gov.hmcts.opal.exception.RequestValidationError;
import uk.gov.hmcts.opal.generated.model.DraftCasefileAddRequest;
import uk.gov.hmcts.opal.generated.model.DraftCasefileAddResponse;
import uk.gov.hmcts.opal.generated.model.IndividualDetails;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.OffsetDateTime;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.catchThrowableOfType;

class OpenApiSchemaValidatorTest {

    private static final String SCHEMA = "DraftCasefileAddRequest";
    private static final JsonMapper MAPPER = JsonMapper.builder().build();
    private static final String REQUEST = """
        {
          "business_unit_id": 1,
          "casefile_type": "REMO In",
          "casefile": {
            "respondent_account": {
              "business_unit_id": 1,
              "application_code": "SYNTH",
              "casefile_type": "REMO In",
              "respondent": {
                "party_details": {
                  "organisation": false,
                  "individual_details": {"surname": "Synthetic"},
                  "address": {"address_line_1": "Synthetic address", "cjs_code": 1}
                }
              },
              "order_details": {
                "date_ordered": "2026-08-01",
                "date_arrears_last_updated": "2026-08-02",
                "interest_flag": false,
                "indexation": "None",
                "payment_arrangement": "Court",
                "payment_period": "Monthly",
                "order_terms": [{
                  "result_id": "SYNTH",
                  "result_responses": [{"parameter_name": "Arbitrary", "response": "not a number or date"}]
                }]
              }
            },
            "applicant": {
              "party_details": {
                "organisation": false,
                "individual_details": {"surname": "Synthetic"},
                "address": {"address_line_1": "Synthetic address", "cjs_code": 1}
              },
              "bank_account_details": {"bank_account_type": "None or not applicable"}
            }
          }
        }
        """;
    private static OpenApiSchemaValidator validator;

    @BeforeAll
    static void loadGeneratedSchema() throws IOException {
        validator = new OpenApiSchemaValidator(new PathMatchingResourcePatternResolver()
            .getResources("classpath*:openapi-validation/*.json"));
    }

    @Test
    void acceptsMinimalIndividualWithOmittedOptionalFieldsAndArbitraryResultStrings() {
        assertThatCode(() -> validate(REQUEST)).doesNotThrowAnyException();
    }

    @Test
    void preservesJsonTreeWithoutDefaultsAndGeneratesTypedEnvelopeAndDates() throws NoSuchMethodException {
        DraftCasefileAddRequest request = MAPPER.readValue(REQUEST, DraftCasefileAddRequest.class);
        assertThat(request.getCasefile()).isEqualTo(MAPPER.readTree(REQUEST).get("casefile"));
        assertThat(request.getBusinessUnitId()).isEqualTo((short) 1);
        assertThat(request.getCasefileType().getValue()).isEqualTo("REMO In");
        assertThat(DraftCasefileAddRequest.class.getMethod("getCasefile").getReturnType()).isEqualTo(JsonNode.class);
        assertThat(DraftCasefileAddResponse.class.getMethod("getCreatedDate").getReturnType())
            .isEqualTo(OffsetDateTime.class);
        assertThat(IndividualDetails.class.getMethod("getDateOfBirth").getReturnType()).isEqualTo(LocalDate.class);
    }

    @ParameterizedTest
    @ValueSource(strings = {"/business_unit_id", "/casefile_type", "/casefile", "/casefile/applicant",
        "/casefile/respondent_account/application_code", "/casefile/respondent_account/order_details/date_ordered"})
    void rejectsMissingRequiredProperties(String pointer) {
        ObjectNode request = request();
        parent(request, pointer).remove(property(pointer));
        assertInvalid(request.toString());
    }

    @ParameterizedTest
    @CsvSource(delimiter = '|', value = {
        "/business_unit_id|\"1\"", "/business_unit_id|0", "/business_unit_id|32768", "/business_unit_id|1.5",
        "/casefile_type|\"unknown\"", "/casefile/applicant|{}",
        "/casefile/respondent_account/application_code|123",
        "/casefile/respondent_account/application_code|\"123456789\"",
        "/casefile/respondent_account/order_details/date_ordered|\"2026-02-30\"",
        "/casefile/respondent_account/order_details/date_ordered|\"2026-08-01T00:00:00Z\"",
        "/casefile/respondent_account/order_details/interest_flag|\"false\"",
        "/casefile/respondent_account/order_details/payment_period|\"invalid\"",
        "/casefile/respondent_account/order_details/order_terms|[]",
        "/casefile/applicant/party_details/individual_details/surname|\"\"",
        "/casefile/applicant/party_details/individual_details/date_of_birth|\"not-a-date\"",
        "/casefile/applicant/party_details/organisation|true",
        "/casefile/applicant/party_details/organisation_details|{\"organisation_name\":\"Synthetic\"}",
        "/casefile/applicant/party_details/individual_details/restrict_personal_information|true",
        "/casefile/applicant/bank_account_details/bank_account_type|\"UK Bank\"",
        "/casefile/applicant/bank_account_details/bank_account_type|\"Non-UK Bank\"",
        "/casefile/respondent_account/order_details/order_terms/0/creditor_type|\"Minor Creditor\"",
        "/casefile/respondent_account/order_details/order_terms/0/creditor_type|\"Major Creditor\"",
        "/casefile/respondent_account/order_details/order_terms/0/result_responses/0/response|42"
    })
    void rejectsContractConstraintFailures(String pointer, String json) {
        ObjectNode request = request();
        parent(request, pointer).set(property(pointer), MAPPER.readTree(json));
        assertInvalid(request.toString());
    }

    @ParameterizedTest
    @ValueSource(strings = {"/business_unit_id", "/casefile", "/casefile/minor_creditors",
        "/casefile/respondent_account/account_comment",
        "/casefile/applicant/party_details/individual_details/forenames"})
    void rejectsExplicitNullWhereContractDoesNotPermitIt(String pointer) {
        ObjectNode request = request();
        parent(request, pointer).putNull(property(pointer));
        assertInvalid(request.toString());
    }

    @ParameterizedTest
    @ValueSource(strings = {"", "/casefile", "/casefile/applicant", "/casefile/applicant/party_details",
        "/casefile/applicant/party_details/individual_details", "/casefile/applicant/party_details/address",
        "/casefile/applicant/bank_account_details", "/casefile/respondent_account/order_details/order_terms/0",
        "/casefile/respondent_account/order_details/order_terms/0/result_responses/0"})
    void rejectsUnknownPropertiesInClosedObjects(String pointer) {
        ObjectNode request = request();
        ((ObjectNode) request.at(pointer)).put("undeclared_property", "synthetic");
        assertInvalid(request.toString());
    }

    @Test
    void acceptsOrganisationApplicantOnlyWithForeignAuthorityReference() {
        ObjectNode request = request();
        ObjectNode party = (ObjectNode) request.at("/casefile/applicant/party_details");
        party.put("organisation", true);
        party.remove("individual_details");
        party.set("organisation_details", MAPPER.readTree("""
            {"organisation_name": "Synthetic organisation", "foreign_authority_reference": "SYNTH1"}
            """));
        assertThatCode(() -> validate(request.toString())).doesNotThrowAnyException();
        ((ObjectNode) party.get("organisation_details")).remove("foreign_authority_reference");
        assertInvalid(request.toString());
    }

    @ParameterizedTest
    @CsvSource(delimiter = '|', value = {
        "UK Bank|uk_bank_details|{\"account_name\":\"Synthetic\",\"sort_code\":\"000000\","
            + "\"account_number\":\"00000000\",\"payment_reference\":\"Synthetic\"}",
        "Non-UK Bank|non_uk_bank_details|{\"account_name\":\"Synthetic\",\"payment_reference\":\"Synthetic\"}"
    })
    void acceptsSelectedBankWithRequiredDetails(String type, String property, String details) {
        ObjectNode request = request();
        ObjectNode bank = (ObjectNode) request.at("/casefile/applicant/bank_account_details");
        bank.put("bank_account_type", type);
        bank.set(property, MAPPER.readTree(details));
        assertThatCode(() -> validate(request.toString())).doesNotThrowAnyException();
    }

    @ParameterizedTest
    @CsvSource(delimiter = '|', value = {
        "Minor Creditor|minor_creditor_sequence|1", "Major Creditor|major_creditor_code|\"SYN\""
    })
    void acceptsConditionalCreditorSelection(String type, String property, String value) {
        ObjectNode request = request();
        ObjectNode term = (ObjectNode) request.at("/casefile/respondent_account/order_details/order_terms/0");
        term.put("creditor_type", type);
        term.set(property, MAPPER.readTree(value));
        assertThatCode(() -> validate(request.toString())).doesNotThrowAnyException();
    }

    @ParameterizedTest
    @ValueSource(strings = {"{", "{\"sensitive-input\":", "null", "[]", "", "{} {}"})
    void rejectsMalformedOrWrongRootJsonSafely(String json) {
        assertInvalid(json);
    }

    @Test
    void rejectsTrailingJsonAfterOtherwiseValidRequest() {
        assertInvalid(REQUEST + " {}");
    }

    @Test
    void rejectsInputExceedingParserNestingLimitSafely() {
        assertInvalid("[".repeat(1001) + "0" + "]".repeat(1001));
    }

    @Test
    void unknownAnnotationSchemaIsServerConfigurationError() {
        assertThatThrownBy(() -> validator.validate("UnknownSchema", REQUEST.getBytes(StandardCharsets.UTF_8)))
            .isInstanceOf(IllegalStateException.class);
    }

    @Test
    void missingOrDuplicateResourcesFailInitialization() {
        assertThatThrownBy(() -> new OpenApiSchemaValidator(new Resource[0]))
            .isInstanceOf(IllegalStateException.class);
        Resource schema = resource("{\"type\":\"object\"}");
        assertThatThrownBy(() -> new OpenApiSchemaValidator(new Resource[]{schema, schema}))
            .isInstanceOf(IllegalStateException.class);
    }

    @ParameterizedTest
    @ValueSource(strings = {"", "{", "{\"type\":\"invalid\"}",
        "{\"$ref\":\"#/missing\"}", "{\"$ref\":\"https://example.invalid/schema\"}",
        "{\"properties\":{\"nested\":{\"$ref\":\"#/missing\"}}}",
        "{\"components\":{\"schemas\":{\"Broken\":{\"type\":\"invalid\"}}}}"})
    void brokenSchemasFailInitialization(String schema) {
        assertThatThrownBy(() -> new OpenApiSchemaValidator(new Resource[]{resource(schema)}))
            .isInstanceOf(RuntimeException.class);
    }

    private static Resource resource(String schema) {
        return new ByteArrayResource(schema.getBytes(StandardCharsets.UTF_8)) {
            @Override
            public String getFilename() {
                return "Test.json";
            }
        };
    }

    private static ObjectNode request() {
        return (ObjectNode) MAPPER.readTree(REQUEST);
    }

    private static ObjectNode parent(ObjectNode request, String pointer) {
        return (ObjectNode) request.at(pointer.substring(0, pointer.lastIndexOf('/')));
    }

    private static String property(String pointer) {
        return pointer.substring(pointer.lastIndexOf('/') + 1);
    }

    private static void validate(String json) {
        validator.validate(SCHEMA, json.getBytes(StandardCharsets.UTF_8));
    }

    private static void assertInvalid(String json) {
        OpalApiException exception = catchThrowableOfType(OpalApiException.class, () -> validate(json));
        assertThat(exception).isNotNull();
        assertThat(exception.getError()).isEqualTo(RequestValidationError.INVALID_REQUEST);
        assertThat(exception.getError().getHttpStatus()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(exception.getError().getErrorTypePrefix()).isEqualTo("REQUEST_VALIDATION");
        assertThat(exception.getError().getErrorTypeNumeric()).isEqualTo("001");
        assertThat(exception.getError().getTitle()).isEqualTo("Invalid request");
        assertThat(exception.getDetail()).isEqualTo("Request body does not match the API contract");
        assertThat(exception.getCause()).isNull();
    }
}
