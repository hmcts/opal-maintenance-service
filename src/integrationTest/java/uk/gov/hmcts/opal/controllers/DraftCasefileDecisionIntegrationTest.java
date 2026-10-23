package uk.gov.hmcts.opal.controllers;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.ValueSource;
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
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.logging.integration.service.LoggingService;
import uk.gov.hmcts.opal.service.messaging.DraftCasefileQueuePublisher;
import uk.gov.hmcts.opal.support.DraftCasefileHttpFixture;

import java.time.Clock;
import java.time.Instant;
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

    @ParameterizedTest
    @CsvSource({"SUBMITTED,PUBLISHING_PENDING,Approved", "SUBMITTED,REJECTED,Rejected", "SUBMITTED,DELETED,Deleted",
        "RESUBMITTED,PUBLISHING_PENDING,Approved", "RESUBMITTED,REJECTED,Rejected", "RESUBMITTED,DELETED,Deleted"})
    void recordsDecisionWithNewVersionAndPreservedContent(String source, String target, String history)
        throws Exception {
        long id = draft(source);
        Map<String, Object> before = row(id);
        var result = mockMvc.perform(request(id, body(target)))
            .andExpect(status().isOk()).andExpect(header().string("ETag", "\"5\""))
            .andExpect(jsonPath("$.casefile_status").value(target))
            .andExpect(jsonPath("$.timeline_data[1].status").value(history))
            .andReturn().getResponse();
        var response = JSON.readTree(result.getContentAsString());
        assertThat(response.get("timeline_data").size()).isEqualTo(2);
        assertThat(response.at("/timeline_data/1/username").asString()).isEqualTo("Synthetic Submitter");
        Map<String, Object> after = row(id);
        for (String column : new String[]{"created_date", "submitted_by", "casefile", "casefile_snapshot",
            "submitted_by_name", "account_id", "account_number", "casefile_type"}) {
            assertThat(after.get(column)).as(column).isEqualTo(before.get(column));
        }
        if (target.equals("PUBLISHING_PENDING")) {
            verify(publisher).publish(argThat(message -> message.draftCasefileId().equals(id)));
            assertThat(after.get("status_message")).isNull();
            assertThat(after.get("validated_by")).isEqualTo("BUU-1");
        } else {
            verifyNoInteractions(publisher);
            assertThat(after.get("status_message")).isEqualTo(PRIVATE);
            for (String column : new String[]{"validated_by", "validated_by_name", "validated_date"}) {
                assertThat(after.get(column)).isEqualTo(before.get(column));
            }
        }
        verify(logging, times(2)).personalDataAccessLogAsync(any());
    }

    @ParameterizedTest
    @ValueSource(strings = {"{}", "{\"business_unit_id\":1,\"casefile_status\":\"REJECTED\"}",
        "{\"business_unit_id\":1,\"casefile_status\":\"DELETED\",\"status_message\":\"  \"}",
        "{\"business_unit_id\":1,\"casefile_status\":\"PUBLISHING_PENDING\",\"status_message\":null}",
        "{\"business_unit_id\":1,\"casefile_status\":\"PUBLISHING_PENDING\",\"casefile\":{}}",
        "{\"business_unit_id\":null,\"casefile_status\":\"REJECTED\"}",
        "{\"business_unit_id\":1,\"casefile_status\":\"PUBLISHED\"}"})
    void invalidBodiesAreRejectedBeforeSideEffects(String body) throws Exception {
        mockMvc.perform(request(99999L, body)).andExpect(status().isBadRequest());
        verifyNoInteractions(publisher, logging);
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
    void reasonLengthBoundary(int length) throws Exception {
        long id = draft("SUBMITTED");
        String body = body("REJECTED").replace(PRIVATE, "a".repeat(length));
        mockMvc.perform(request(id, body)).andExpect(status().is(length == 250 ? 200 : 400));
        verifyNoInteractions(publisher);
    }

    @ParameterizedTest
    @ValueSource(strings = {"", "4", "W/\"4\"", "\"-1\"", "\"9223372036854775808\"", "\"4\",\"5\""})
    void invalidVersionHeader(String value) throws Exception {
        var request = request(99999L, body("PUBLISHING_PENDING"));
        request.headers(headers -> headers.remove("If-Match"));
        if (!value.isEmpty()) {
            request.header("If-Match", value);
        }
        mockMvc.perform(request).andExpect(status().isBadRequest());
        verifyNoInteractions(publisher, logging);
    }

    @Test
    void staleVersionAndOwnerMismatchAreConflicts() throws Exception {
        long id = draft("SUBMITTED");
        var stale = request(id, body("PUBLISHING_PENDING"));
        stale.headers(headers -> headers.set("If-Match", "\"3\""));
        mockMvc.perform(stale).andExpect(status().isConflict());
        String wrongOwner = body("PUBLISHING_PENDING").replace("\"business_unit_id\":1", "\"business_unit_id\":2");
        mockMvc.perform(request(id, wrongOwner))
            .andExpect(status().isConflict());
        verifyNoInteractions(publisher, logging);
    }

    @Test
    void authenticationPermissionSelfCheckAndMissingRecord() throws Exception {
        long id = draft("SUBMITTED");
        mockMvc.perform(patch("/draft-casefiles/{id}", id).contentType(MediaType.APPLICATION_JSON)
            .content(body("PUBLISHING_PENDING")).header("If-Match", "\"4\""))
            .andExpect(status().isUnauthorized());
        mockMvc.perform(request(id, body("PUBLISHING_PENDING"))
            .with(authentication(DraftCasefileHttpFixture.token((short) 1))))
            .andExpect(status().isForbidden());
        jdbc.update("UPDATE draft_casefiles SET submitted_by = 'BUU-1' WHERE draft_casefile_id = ?", id);
        mockMvc.perform(request(id, body("REJECTED"))).andExpect(status().isForbidden());
        mockMvc.perform(request(Long.MAX_VALUE, body("REJECTED"))).andExpect(status().isNotFound());
        verifyNoInteractions(publisher, logging);
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
            .andExpect(status().isServiceUnavailable()).andReturn().getResponse().getContentAsString();
        assertThat(response).contains("messaging-unavailable").doesNotContain(PRIVATE);
        assertThat(output.getAll().substring(start)).doesNotContain(PRIVATE);
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

    private MockHttpServletRequestBuilder request(long id, String body) {
        return patch("/draft-casefiles/{id}", id).header("If-Match", "\"4\"")
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
        String response = mockMvc.perform(post("/draft-casefiles").contentType(MediaType.APPLICATION_JSON)
            .content(DraftCasefileHttpFixture.requestBody().replace("Example", "Synthetic\\u0000"))
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
