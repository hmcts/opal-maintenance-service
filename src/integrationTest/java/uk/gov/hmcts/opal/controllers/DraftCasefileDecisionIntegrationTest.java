package uk.gov.hmcts.opal.controllers;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jms.UncategorizedJmsException;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.context.jdbc.Sql;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import tools.jackson.databind.json.JsonMapper;
import tools.jackson.databind.node.ObjectNode;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.authorisation.MaintenancePermission;
import uk.gov.hmcts.opal.logging.integration.dto.PersonalDataProcessingCategory;
import uk.gov.hmcts.opal.logging.integration.dto.PersonalDataProcessingLogDetails;
import uk.gov.hmcts.opal.logging.integration.service.LoggingService;
import uk.gov.hmcts.opal.service.messaging.DraftCasefileQueuePublisher;
import uk.gov.hmcts.opal.support.DraftCasefileHttpFixture;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.Mockito.when;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.times;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.test.context.jdbc.Sql.ExecutionPhase.AFTER_TEST_METHOD;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static uk.gov.hmcts.opal.authorisation.MaintenancePermission.CHECK_VALIDATE_DRAFT_CASEFILES;

@AutoConfigureMockMvc
@ExtendWith(OutputCaptureExtension.class)
@TestPropertySource(properties = {"spring.flyway.locations=classpath:db/migration/ddl", "opal.redis.enabled=false",
    "management.health.redis.enabled=false", "spring.jpa.open-in-view=false",
    "opal.openapi.max-request-body-bytes=4096",
    "logging.level.opal.DraftCasefileApiController=DEBUG", "logging.level.opal.DraftCasefileService=DEBUG"})
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@Sql("/draft-casefile/reference-fixtures.sql")
@Sql(scripts = "/draft-casefile/reference-cleanup.sql", executionPhase = AFTER_TEST_METHOD)
class DraftCasefileDecisionIntegrationTest extends BaseIntegrationTest {
    private static final JsonMapper JSON = JsonMapper.builder().build();
    private static final String PRIVATE = "SYNTHETIC_PRIVATE_DECISION";
    private static final Instant DECIDED_AT = Instant.parse("2026-10-19T10:00:00.123456Z");
    private static final String REQUEST_IP = "192.0.2.1";
    @Autowired
    private MockMvc mockMvc;
    @Autowired
    private JdbcTemplate jdbc;
    @MockitoBean
    private DraftCasefileQueuePublisher publisher;
    @MockitoBean
    private Clock clock;
    @MockitoBean
    private LoggingService logging;

    @BeforeEach
    void setUp() {
        when(clock.instant()).thenReturn(Instant.parse("2026-10-19T10:00:00.123456789Z"));
        when(logging.personalDataAccessLogAsync(any())).thenReturn(true);
    }

    // Function expectations: Approve v25, Reject v18 and Delete v16, refreshed 1 October 2026.
    @ParameterizedTest
    @CsvSource({"SUBMITTED,PUBLISHING_PENDING,Approved,0", "SUBMITTED,REJECTED,Rejected,0",
        "SUBMITTED,DELETED,Deleted,0", "RESUBMITTED,PUBLISHING_PENDING,Approved,0",
        "RESUBMITTED,REJECTED,Rejected,0", "RESUBMITTED,DELETED,Deleted,0",
        "SUBMITTED,PUBLISHING_PENDING,Approved,2", "SUBMITTED,REJECTED,Rejected,2",
        "SUBMITTED,DELETED,Deleted,2", "RESUBMITTED,PUBLISHING_PENDING,Approved,2",
        "RESUBMITTED,REJECTED,Rejected,2", "RESUBMITTED,DELETED,Deleted,2"})
    void recordsDecisionWithNewVersionAndPreservedContent(String source, String target, String history,
                                                         int minorCreditors, CapturedOutput output) throws Exception {
        long id = draft(source, privacyRequest(minorCreditors));
        Map<String, Object> before = row(id);
        final int outputStart = output.getAll().length();
        var result = mockMvc.perform(request(id, body(target)))
            .andExpect(status().isOk()).andExpect(header().string("ETag", "\"5\""))
            .andExpect(jsonPath("$.casefile_status").value(target))
            .andExpect(jsonPath("$.timeline_data[1].status").value(history))
            .andReturn().getResponse();
        var response = JSON.readTree(result.getContentAsString());
        assertThat(response.get("timeline_data").size()).isEqualTo(2);
        assertThat(response.at("/timeline_data/0"))
            .isEqualTo(JSON.readTree(before.get("timeline_data").toString()).get(0));
        assertThat(response.at("/timeline_data/1/username").asString()).isEqualTo("Synthetic Submitter");
        assertThat(Instant.parse(response.at("/timeline_data/1/status_date").asString())).isEqualTo(DECIDED_AT);
        assertThat(Instant.parse(response.get("casefile_status_date").asString())).isEqualTo(DECIDED_AT);
        Map<String, Object> after = row(id);
        for (String column : List.of("casefile", "casefile_snapshot", "timeline_data")) {
            assertThat(response.get(column)).isEqualTo(JSON.readTree(after.get(column).toString()));
        }
        assertThat(after.get("casefile_status_date")).isEqualTo(java.sql.Timestamp.valueOf(
            LocalDateTime.ofInstant(DECIDED_AT, ZoneOffset.UTC)));
        for (String column : new String[]{"created_date", "submitted_by", "casefile", "casefile_snapshot",
            "submitted_by_name", "account_id", "account_number", "casefile_type"}) {
            assertThat(after.get(column)).as(column).isEqualTo(before.get(column));
        }
        if (target.equals("PUBLISHING_PENDING")) {
            verify(publisher).publish(argThat(message -> message.draftCasefileId().equals(id)));
            assertThat(after.get("status_message")).isNull();
            assertThat(after.get("validated_by")).isEqualTo("BUU-1");
            assertThat(after.get("validated_by_name")).isEqualTo("Synthetic Submitter");
            assertThat(after.get("validated_date")).isEqualTo(after.get("casefile_status_date"));
            assertThat(response.at("/timeline_data/1/reason_text").isMissingNode()).isTrue();
        } else {
            verifyNoInteractions(publisher);
            assertThat(after.get("status_message")).isEqualTo(PRIVATE);
            assertThat(response.at("/timeline_data/1/reason_text").asString()).isEqualTo(PRIVATE);
            for (String column : new String[]{"validated_by", "validated_by_name", "validated_date"}) {
                assertThat(after.get(column)).isEqualTo(before.get(column));
            }
        }
        assertDecisionLogs(id, target, minorCreditors > 0);
        assertPrivateValuesAbsent(output.getAll().substring(outputStart));
    }

    @ParameterizedTest
    @ValueSource(strings = {"{}", "{\"business_unit_id\":1,\"casefile_status\":\"REJECTED\"}",
        "{\"business_unit_id\":1,\"casefile_status\":\"DELETED\",\"status_message\":\"  \"}",
        "{\"business_unit_id\":1,\"casefile_status\":\"PUBLISHING_PENDING\",\"status_message\":null}",
        "{\"business_unit_id\":1,\"casefile_status\":\"PUBLISHING_PENDING\",\"casefile\":{}}",
        "{\"business_unit_id\":null,\"casefile_status\":\"REJECTED\"}",
        "{\"business_unit_id\":1,\"casefile_status\":\"PUBLISHED\"}"})
    void invalidBodiesAreRejectedBeforeSideEffects(String body, CapturedOutput output) throws Exception {
        long id = draft("SUBMITTED");
        assertRefusedDecision(id, request(id, body), 400, output);
    }

    @Test
    void acceptsMultilineReasonWithNonblankText() throws Exception {
        long id = draft("SUBMITTED");
        String reason = "  Synthetic reason\nSecond line  ";
        String body = JSON.createObjectNode().put("business_unit_id", 1).put("casefile_status", "REJECTED")
            .put("status_message", reason).toString();
        mockMvc.perform(request(id, body)).andExpect(status().isOk())
            .andExpect(jsonPath("$.status_message").value(reason));
    }

    @ParameterizedTest
    @ValueSource(ints = {250, 251})
    void reasonLengthBoundary(int length, CapturedOutput output) throws Exception {
        long id = draft("SUBMITTED");
        String body = body("REJECTED").replace(PRIVATE, "a".repeat(length));
        if (length == 250) {
            mockMvc.perform(request(id, body)).andExpect(status().isOk());
        } else {
            assertRefusedDecision(id, request(id, body), 400, output);
        }
        verifyNoInteractions(publisher);
    }

    @ParameterizedTest
    @ValueSource(strings = {"", "4", "W/\"4\"", "\"-1\"", "\"9223372036854775808\"", "\"4\",\"5\""})
    void invalidVersionHeader(String value, CapturedOutput output) throws Exception {
        long id = draft("SUBMITTED");
        var request = request(id, body("PUBLISHING_PENDING"));
        request.headers(headers -> headers.remove("If-Match"));
        if (!value.isEmpty()) {
            request.header("If-Match", value);
        }
        assertRefusedDecision(id, request, 400, output);
    }

    @ParameterizedTest
    @ValueSource(strings = {"PUBLISHING_PENDING", "REJECTED", "DELETED"})
    void staleVersionAndOwnerMismatchAreConflicts(String target, CapturedOutput output) throws Exception {
        long id = draft("SUBMITTED");
        var stale = request(id, body(target));
        stale.headers(headers -> headers.set("If-Match", "\"3\""));
        assertRefusedDecision(id, stale, 409, output);
        String wrongOwner = body(target).replace("\"business_unit_id\":1", "\"business_unit_id\":2");
        assertRefusedDecision(id, request(id, wrongOwner), 409, output);
    }

    @ParameterizedTest
    @ValueSource(strings = {"PUBLISHING_PENDING", "REJECTED", "DELETED"})
    void authenticationPermissionSelfCheckAndMissingRecord(String target, CapturedOutput output) throws Exception {
        long id = draft("SUBMITTED");
        assertRefusedDecision(id, patch("/draft-casefiles/{id}", id).contentType(MediaType.APPLICATION_JSON)
            .content(body(target)).header("If-Match", "\"4\""), 401, output);
        assertRefusedDecision(id, request(id, body(target))
            .with(authentication(DraftCasefileHttpFixture.token((short) 1))), 403, output);
        assertRefusedDecision(id, request(id, body(target)).with(authentication(
            DraftCasefileHttpFixture.token((short) 1, new MaintenancePermission[0]))), 403, output);
        assertRefusedDecision(id, request(id, body(target)).with(authentication(
            DraftCasefileHttpFixture.token((short) 2, CHECK_VALIDATE_DRAFT_CASEFILES))), 403, output);
        jdbc.update("UPDATE draft_casefiles SET submitted_by = 'BUU-1' WHERE draft_casefile_id = ?", id);
        assertRefusedDecision(id, request(id, body(target)), 403, output);
        assertRefusedDecision(id, request(Long.MAX_VALUE, body(target)), 404, output);
    }

    @ParameterizedTest
    @ValueSource(strings = {"REJECTED", "DELETED", "PUBLISHING_PENDING", "PUBLISHED", "PUBLISHING_FAILED"})
    void unsupportedCurrentStatesRemainUnchanged(String source, CapturedOutput output) throws Exception {
        long id = draft(source);
        for (String target : List.of("PUBLISHING_PENDING", "REJECTED", "DELETED")) {
            assertRefusedDecision(id, request(id, body(target)), 409, output);
        }
    }

    @Test
    void unsupportedMediaAndOversizedRequest() throws Exception {
        mockMvc.perform(request(99999L, body("REJECTED")).contentType(MediaType.TEXT_PLAIN))
            .andExpect(status().isUnsupportedMediaType());
        mockMvc.perform(request(99999L, body("REJECTED")).accept(MediaType.APPLICATION_XML))
            .andExpect(status().isNotAcceptable());
        mockMvc.perform(request(99999L, body("REJECTED").replace(PRIVATE, "a".repeat(5000))))
            .andExpect(status().isContentTooLarge());
        verifyNoInteractions(publisher, logging);
    }

    @Test
    void failedSendRollsBackAndReturnsSafe503(CapturedOutput output) throws Exception {
        long id = draft("SUBMITTED");
        Map<String, Object> before = row(id);
        doThrow(new UncategorizedJmsException(PRIVATE)).when(publisher)
            .publish(argThat(message -> message.draftCasefileId().equals(id)));
        int start = output.getAll().length();
        String response = mockMvc.perform(request(id, body("PUBLISHING_PENDING")))
            .andExpect(status().isServiceUnavailable()).andExpect(jsonPath("$.operation_id").isNotEmpty())
            .andReturn().getResponse().getContentAsString();
        assertThat(response).contains("messaging-unavailable").doesNotContain(PRIVATE);
        assertThat(output.getAll().substring(start))
            .contains(JSON.readTree(response).path("operation_id").asString()).doesNotContain(PRIVATE);
        assertThat(row(id)).isEqualTo(before);
        verifyNoInteractions(logging);
    }

    @Test
    void loggingFailureDoesNotChangeCommittedDecision(CapturedOutput output) throws Exception {
        long id = draft("SUBMITTED");
        when(logging.personalDataAccessLogAsync(any())).thenThrow(new IllegalStateException(PRIVATE));
        int start = output.getAll().length();
        mockMvc.perform(request(id, body("REJECTED"))).andExpect(status().isOk());
        assertThat(row(id).get("casefile_status")).isEqualTo("REJECTED");
        assertThat(output.getAll().substring(start)).doesNotContain(PRIVATE);
    }

    private void assertRefusedDecision(long id, MockHttpServletRequestBuilder request, int expected,
                                       CapturedOutput output) throws Exception {
        Map<String, Object> before = row(id);
        final int outputStart = output.getAll().length();
        String response = mockMvc.perform(request).andExpect(status().is(expected))
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
            .andExpect(header().doesNotExist("ETag")).andExpect(jsonPath("$.operation_id").isNotEmpty())
            .andReturn().getResponse().getContentAsString();
        assertThat(row(id)).isEqualTo(before);
        verifyNoInteractions(publisher, logging);
        assertPrivateValuesAbsent(response);
        assertPrivateValuesAbsent(output.getAll().substring(outputStart));
    }

    private void assertDecisionLogs(long id, String target, boolean hasMinorCreditors) {
        String action = switch (target) {
            case "PUBLISHING_PENDING" -> "Approve";
            case "REJECTED" -> "Reject";
            case "DELETED" -> "Delete";
            default -> throw new IllegalArgumentException("Unexpected decision in test");
        };
        List<String> identifiers = new ArrayList<>(List.of(action + " Draft Casefile - Respondent",
            action + " Draft Casefile - Applicant / Beneficiary"));
        if (hasMinorCreditors) {
            identifiers.add(action + " Draft Casefile - Minor Creditor");
        }
        ArgumentCaptor<PersonalDataProcessingLogDetails> payloads =
            ArgumentCaptor.forClass(PersonalDataProcessingLogDetails.class);
        verify(logging, times(identifiers.size())).personalDataAccessLogAsync(payloads.capture());
        assertThat(payloads.getAllValues()).extracting(PersonalDataProcessingLogDetails::getBusinessIdentifier)
            .containsExactlyElementsOf(identifiers);
        assertThat(payloads.getAllValues()).allSatisfy(payload -> {
            assertThat(payload.getCategory()).isEqualTo(PersonalDataProcessingCategory.ALTERATION);
            assertThat(payload.getCreatedBy().getIdentifier()).isEqualTo("123");
            assertThat(payload.getCreatedBy().getType().getType()).isEqualTo("OPAL_USER_ID");
            assertThat(payload.getCreatedAt()).isEqualTo(DECIDED_AT.atOffset(ZoneOffset.UTC));
            assertThat(payload.getIpAddress()).isEqualTo(REQUEST_IP);
            assertThat(payload.getRecipient()).isNull();
            assertThat(payload.getIndividuals()).singleElement().satisfies(identifier -> {
                assertThat(identifier.getIdentifier()).isEqualTo(Long.toString(id));
                assertThat(identifier.getType().getType()).isEqualTo("RM_DRAFT_CASEFILE");
            });
            assertPrivateValuesAbsent(JSON.writeValueAsString(payload));
        });
    }

    private void assertPrivateValuesAbsent(String text) {
        assertThat(text).doesNotContain("SYNTHETIC", "Synthetic", "synthetic-contact@example.com",
            "000000", "11111111", "Old reason", "\"casefile\"", "\"casefile_snapshot\"", "\"timeline_data\"",
            "\"status_message\"", "\"reason_text\"");
    }

    private String privacyRequest(int minorCreditors) throws Exception {
        ObjectNode body = (ObjectNode) JSON.readTree(DraftCasefileHttpFixture.requestBody());
        ObjectNode casefile = (ObjectNode) body.get("casefile");
        ObjectNode respondent = (ObjectNode) casefile.at("/respondent_account/respondent");
        ObjectNode party = (ObjectNode) respondent.get("party_details");
        ((ObjectNode) party.get("individual_details")).put("surname", "SYNTHETIC_NAME");
        ((ObjectNode) party.get("address")).put("address_line_1", "SYNTHETIC_ADDRESS");
        party.putObject("contact_details").put("primary_email_address", "synthetic-contact@example.com");
        ObjectNode employer = respondent.putObject("debtor_details").put("employer_name", "SYNTHETIC_EMPLOYER")
            .put("employee_reference", "SYNTHETIC_EMPLOYMENT");
        employer.set("employer_address", party.get("address").deepCopy());
        ObjectNode applicant = (ObjectNode) casefile.get("applicant");
        applicant.set("party_details", party.deepCopy());
        ObjectNode bank = applicant.putObject("bank_account_details").put("bank_account_type", "UK Bank");
        bank.putObject("uk_bank_details").put("account_name", "SYNTHETIC_BANK")
            .put("sort_code", "000000").put("account_number", "11111111")
            .put("payment_reference", "SYNTHETIC_PAYMENT");
        var minors = casefile.putArray("minor_creditors");
        for (int sequence = 1; sequence <= minorCreditors; sequence++) {
            ObjectNode minor = applicant.deepCopy().put("creditor_sequence", sequence);
            ((ObjectNode) minor.at("/party_details/individual_details"))
                .put("surname", "SYNTHETIC_MINOR_" + sequence);
            minors.add(minor);
        }
        return body.toString();
    }

    private MockHttpServletRequestBuilder request(long id, String body) {
        return patch("/draft-casefiles/{id}", id).header("If-Match", "\"4\"")
            .header("X-User-IP", REQUEST_IP)
            .contentType(MediaType.APPLICATION_JSON).content(body)
            .with(authentication(DraftCasefileHttpFixture.token((short) 1, CHECK_VALIDATE_DRAFT_CASEFILES)));
    }

    private String body(String status) {
        var body = JSON.createObjectNode().put("business_unit_id", 1).put("casefile_status", status);
        if (!status.equals("PUBLISHING_PENDING")) {
            body.put("status_message", PRIVATE);
        }
        return body.toString();
    }

    private long draft(String status) throws Exception {
        return draft(status, DraftCasefileHttpFixture.requestBody().replace("Example", "Synthetic\\u0000"));
    }

    private long draft(String status, String body) throws Exception {
        String response = mockMvc.perform(post("/draft-casefiles").contentType(MediaType.APPLICATION_JSON)
            .content(body)
            .with(authentication(DraftCasefileHttpFixture.token((short) 1))))
            .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString();
        long id = JSON.readTree(response).get("draft_casefile_id").longValue();
        jdbc.update("""
            UPDATE draft_casefiles SET casefile_status = ?::t_draft_casefile_status_enum, version_number = 4,
                submitted_by = 'BUU-INPUTTER',
                validated_by = 'BUU-OLD', validated_by_name = 'Synthetic Earlier Checker',
                validated_date = created_date,
                status_message = 'Old reason' WHERE draft_casefile_id = ?
            """, status, id);
        clearInvocations(logging);
        return id;
    }

    private Map<String, Object> row(long id) {
        return jdbc.queryForMap("SELECT * FROM draft_casefiles WHERE draft_casefile_id = ?", id);
    }
}
