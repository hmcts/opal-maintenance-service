package uk.gov.hmcts.opal.controllers;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.springframework.test.context.jdbc.Sql;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;
import tools.jackson.databind.node.ObjectNode;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.authorisation.MaintenancePermission;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.common.spring.security.OpalJwtAuthenticationToken;
import uk.gov.hmcts.opal.common.user.authorisation.model.BusinessUnitUser;
import uk.gov.hmcts.opal.common.user.authorisation.model.Domain;
import uk.gov.hmcts.opal.common.user.authorisation.model.DomainBusinessUnitUsers;
import uk.gov.hmcts.opal.common.user.authorisation.model.Permission;
import uk.gov.hmcts.opal.common.user.authorisation.model.UserStateV2;
import uk.gov.hmcts.opal.logging.integration.dto.PersonalDataProcessingCategory;
import uk.gov.hmcts.opal.logging.integration.dto.PersonalDataProcessingLogDetails;
import uk.gov.hmcts.opal.logging.integration.service.LoggingService;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.support.DraftCasefileHttpFixture;

import java.time.Clock;
import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.test.context.jdbc.Sql.ExecutionPhase.AFTER_TEST_METHOD;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
@ExtendWith(OutputCaptureExtension.class)
@TestPropertySource(properties = {
    "spring.flyway.locations=classpath:db/migration/ddl", "opal.redis.enabled=false",
    "management.health.redis.enabled=false", "spring.jpa.open-in-view=false",
    "logging.level.opal.DraftCasefileApiController=DEBUG", "logging.level.opal.DraftCasefileService=DEBUG",
    "opal.openapi.max-request-body-bytes=4096"
})
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@Sql("/draft-casefile/reference-fixtures.sql")
@Sql(scripts = "/draft-casefile/reference-cleanup.sql", executionPhase = AFTER_TEST_METHOD)
class DraftCasefileReplaceIntegrationTest extends BaseIntegrationTest {

    private static final JsonMapper JSON = JsonMapper.builder().build();
    private static final String PRIVATE = "SYNTHETIC_PRIVATE_REPLACE_VALUE";
    private static final Instant NOW = Instant.parse("2026-10-09T10:00:00.123456789Z");
    @Autowired
    private MockMvc mockMvc;
    @Autowired
    private JdbcTemplate jdbc;
    @MockitoSpyBean
    private DraftCasefileRepository repository;
    @MockitoBean
    private Clock clock;
    @MockitoBean
    private LoggingService logging;

    @BeforeEach
    void setUp() {
        when(clock.instant()).thenReturn(NOW);
        when(logging.personalDataAccessLogAsync(any())).thenReturn(true);
    }

    @ParameterizedTest
    @ValueSource(booleans = {false, true})
    void replacesRejectedDraftForOriginalOrDifferentInputter(boolean different, CapturedOutput output)
        throws Exception {
        long id = rejectedDraft();
        Map<String, Object> before = row(id);
        ObjectNode body = replacement();
        final int outputStart = output.getAll().length();
        var result = mockMvc.perform(request(id, body).with(authentication(different ? otherInputter()
                : DraftCasefileHttpFixture.token((short) 1))))
            .andExpect(status().isOk()).andExpect(header().string("ETag", "\"5\""))
            .andExpect(jsonPath("$.casefile_status").value("RESUBMITTED"))
            .andExpect(jsonPath("$.casefile_status_name").value("Resubmitted"))
            .andExpect(jsonPath("$.submitted_by").value(different ? "BUU-2" : "BUU-1"))
            .andExpect(jsonPath("$.version_number").doesNotExist()).andReturn();
        JsonNode response = JSON.readTree(result.getResponse().getContentAsString());
        Map<String, Object> after = row(id);
        assertThat(after.get("version_number")).isEqualTo(5L);
        for (String column : List.of("draft_casefile_id", "business_unit_id", "created_date", "casefile_type",
            "validated_date", "validated_by", "validated_by_name", "status_message", "account_id", "account_number")) {
            assertThat(after.get(column)).as(column).isEqualTo(before.get(column));
        }
        for (String column : List.of("casefile", "casefile_snapshot", "timeline_data")) {
            assertThat(response.get(column)).isEqualTo(after.get(column));
        }
        assertThat(response.get("casefile")).isEqualTo(body.get("casefile"));
        assertThat(response.at("/casefile_snapshot/minor_creditor_accounts").size()).isZero();
        assertThat(response.at("/casefile_snapshot/respondent_account/account_id").isNull()).isTrue();
        assertThat(response.at("/timeline_data/1/reason_text").asString()).isEqualTo(PRIVATE);
        assertThat(response.at("/timeline_data/2/status").asString()).isEqualTo("Resubmitted");
        assertThat(response.at("/timeline_data/2/username").asString())
            .isEqualTo(different ? "Synthetic Resubmitter" : "Synthetic Submitter");
        assertThat(response.at("/timeline_data/2/reason_text").isMissingNode()).isTrue();
        assertThat(Instant.parse(response.get("casefile_status_date").asString()))
            .isEqualTo(Instant.parse("2026-10-09T10:00:00.123456Z"));
        var captured = org.mockito.ArgumentCaptor.forClass(PersonalDataProcessingLogDetails.class);
        verify(logging, times(2)).personalDataAccessLogAsync(captured.capture());
        assertThat(captured.getAllValues()).allSatisfy(details -> {
            assertThat(details.getCategory()).isEqualTo(PersonalDataProcessingCategory.ALTERATION);
            assertThat(details.getCreatedBy().getIdentifier()).isEqualTo("123");
            assertThat(details.getIndividuals()).singleElement().satisfies(identifier ->
                assertThat(identifier.getIdentifier()).isEqualTo(Long.toString(id)));
            assertThat(JSON.writeValueAsString(details)).doesNotContain(PRIVATE, "Synthetic address", "Synthetic");
        });
        assertThat(output.getAll().substring(outputStart)).doesNotContain(PRIVATE, "Synthetic address");
        clearInvocations(logging);
        mockMvc.perform(request(id, body).with(authentication(DraftCasefileHttpFixture.token((short) 1))))
            .andExpect(status().isConflict());
        assertThat(row(id)).isEqualTo(after);
        verifyNoInteractions(logging);
    }

    @ParameterizedTest
    @EnumSource(value = DraftCasefileStatus.class, mode = EnumSource.Mode.EXCLUDE, names = "REJECTED")
    void rejectsEveryOtherLifecycleState(DraftCasefileStatus state) throws Exception {
        long id = rejectedDraft();
        jdbc.update("UPDATE draft_casefiles SET casefile_status = ?::public.t_draft_casefile_status_enum "
            + "WHERE draft_casefile_id = ?", state.name(), id);
        assertFailure(id, request(id, replacement()).with(authentication(DraftCasefileHttpFixture.token((short) 1))),
            409, null);
    }

    @ParameterizedTest
    @ValueSource(strings = {"missing", "unauthenticated", "none", "checker", "foreign", "owner", "owner-denied",
        "stale", "header-missing", "header-private", "header-weak", "header-overflow", "id-zero", "id-overflow",
        "schema", "type", "nested-owner", "reference", "size", "media", "accept", "null-version", "timeline",
        "unavailable", "optimistic"})
    void rejectsInvalidRequestsWithoutChangingAnyColumnOrLogging(String failure, CapturedOutput output)
        throws Exception {
        long id = rejectedDraft();
        ObjectNode body = replacement();
        MockHttpServletRequestBuilder request = request(id, body)
            .with(authentication(DraftCasefileHttpFixture.token((short) 1)));
        int expected = 400;
        switch (failure) {
            case "missing" -> {
                request = request(Long.MAX_VALUE, body)
                    .with(authentication(DraftCasefileHttpFixture.token((short) 1)));
                expected = 404;
            }
            case "unauthenticated" -> {
                request = request(id, body);
                expected = 401;
            }
            case "none", "checker" -> {
                MaintenancePermission[] permissions = failure.equals("checker")
                    ? new MaintenancePermission[] {MaintenancePermission.CHECK_VALIDATE_DRAFT_CASEFILES}
                    : new MaintenancePermission[0];
                request.with(authentication(DraftCasefileHttpFixture.token((short) 1, permissions)));
                expected = 403;
            }
            case "foreign" -> {
                request.with(authentication(DraftCasefileHttpFixture.token((short) 2)));
                expected = 403;
            }
            case "owner", "owner-denied" -> {
                body.put("business_unit_id", 2);
                request.content(body.toString());
                expected = 409;
                if (failure.equals("owner-denied")) {
                    request.with(authentication(DraftCasefileHttpFixture.token((short) 2)));
                    expected = 403;
                }
            }
            case "stale" -> {
                request = put("/draft-casefiles/{id}", id).header("If-Match", "\"3\"")
                    .contentType(MediaType.APPLICATION_JSON).content(body.toString())
                    .with(authentication(DraftCasefileHttpFixture.token((short) 1)));
                expected = 409;
            }
            case "header-missing", "header-private", "header-weak", "header-overflow" -> {
                request = put("/draft-casefiles/{id}", id).contentType(MediaType.APPLICATION_JSON)
                    .content(body.toString()).with(authentication(DraftCasefileHttpFixture.token((short) 1)));
                if (!failure.equals("header-missing")) {
                    String value = switch (failure) {
                        case "header-private" -> PRIVATE;
                        case "header-weak" -> "W/\"4\"";
                        default -> "\"9223372036854775808\"";
                    };
                    request.header("If-Match", value);
                }
            }
            case "id-zero", "id-overflow" -> request = put("/draft-casefiles/{id}",
                failure.equals("id-zero") ? "0" : "9223372036854775808").header("If-Match", "\"4\"")
                .contentType(MediaType.APPLICATION_JSON).content(body.toString())
                .with(authentication(DraftCasefileHttpFixture.token((short) 1)));
            case "schema" -> {
                body.put("version_number", 4);
                request.content(body.toString());
            }
            case "type" -> {
                ((ObjectNode) body.at("/casefile/respondent_account")).put("casefile_type", "REMO Out");
                request.content(body.toString());
            }
            case "nested-owner" -> {
                ((ObjectNode) body.at("/casefile/respondent_account")).put("business_unit_id", 2);
                request.content(body.toString());
            }
            case "reference" -> {
                ((ObjectNode) body.at("/casefile/respondent_account")).put("application_code", "ABSENT");
                request.content(body.toString());
            }
            case "size" -> {
                request.content(" ".repeat(4097));
                expected = 413;
            }
            case "media" -> {
                request.contentType(MediaType.TEXT_PLAIN);
                expected = 415;
            }
            case "accept" -> {
                request.accept(MediaType.TEXT_PLAIN);
                expected = 406;
            }
            case "null-version" -> {
                jdbc.update("UPDATE draft_casefiles SET version_number = NULL WHERE draft_casefile_id = ?", id);
                expected = 500;
            }
            case "timeline" -> {
                jdbc.update("UPDATE draft_casefiles SET timeline_data = ?::json WHERE draft_casefile_id = ?",
                    JSON.writeValueAsString(PRIVATE), id);
                expected = 500;
            }
            case "unavailable" -> {
                doThrow(new org.springframework.dao.DataAccessResourceFailureException(PRIVATE))
                    .when(repository).findById(id);
                expected = 503;
            }
            case "optimistic" -> {
                doThrow(new org.springframework.orm.ObjectOptimisticLockingFailureException(PRIVATE,
                    new IllegalStateException(PRIVATE))).when(repository).saveAndFlush(any());
                expected = 409;
            }
            default -> throw new IllegalArgumentException("Unexpected test case");
        }
        assertFailure(id, request, expected, output);
    }

    private void assertFailure(long id, MockHttpServletRequestBuilder request, int expected, CapturedOutput output)
        throws Exception {
        final int start = output == null ? 0 : output.getAll().length();
        Map<String, Object> before = row(id);
        String response = mockMvc.perform(request).andExpect(status().is(expected))
            .andExpect(header().doesNotExist("ETag")).andExpect(jsonPath("$.operation_id").isNotEmpty())
            .andReturn().getResponse().getContentAsString();
        assertThat(response).doesNotContain(PRIVATE, "Synthetic address");
        assertThat(row(id)).isEqualTo(before);
        verifyNoInteractions(logging);
        if (output != null) {
            assertThat(output.getAll().substring(start)).doesNotContain(PRIVATE, "Synthetic address");
        }
    }

    private MockHttpServletRequestBuilder request(long id, ObjectNode body) {
        return put("/draft-casefiles/{id}", id).header("If-Match", "\"4\"").header("X-User-IP", "192.0.2.1")
            .contentType(MediaType.APPLICATION_JSON).content(body.toString());
    }

    private ObjectNode replacement() throws Exception {
        ObjectNode body = (ObjectNode) JSON.readTree(DraftCasefileHttpFixture.requestBody());
        body.remove("casefile_type");
        ((ObjectNode) body.at("/casefile/respondent_account")).put("account_comment", PRIVATE);
        return body;
    }

    private long rejectedDraft() throws Exception {
        String response = mockMvc.perform(post("/draft-casefiles").contentType(MediaType.APPLICATION_JSON)
                .content(DraftCasefileHttpFixture.requestBody())
                .with(authentication(DraftCasefileHttpFixture.token((short) 1))))
            .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString();
        long id = JSON.readTree(response).get("draft_casefile_id").longValue();
        jdbc.update("""
            UPDATE draft_casefiles SET casefile_status = 'REJECTED', version_number = 4,
                validated_by = 'BUU-3', validated_by_name = 'Synthetic Checker', validated_date = created_date,
                status_message = ?, account_id = 101, account_number = 'SYNTHETIC-101', timeline_data = ?::json
            WHERE draft_casefile_id = ?
            """, PRIVATE, """
                [{"username":"Synthetic Submitter","status":"Submitted","status_date":"2026-10-01T12:00:00Z"},
                 {"username":"Synthetic Checker","status":"Rejected","status_date":"2026-10-02T12:00:00Z",
                  "reason_text":"%s"}]
                """.formatted(PRIVATE), id);
        clearInvocations(logging);
        return id;
    }

    private Map<String, Object> row(long id) {
        Map<String, Object> row = new HashMap<>(jdbc.queryForMap(
            "SELECT * FROM draft_casefiles WHERE draft_casefile_id = ?", id));
        for (String column : List.of("casefile", "casefile_snapshot", "timeline_data")) {
            row.computeIfPresent(column, (key, value) -> JSON.readTree(value.toString()));
        }
        return row;
    }

    private OpalJwtAuthenticationToken otherInputter() {
        var original = DraftCasefileHttpFixture.token((short) 1);
        var state = UserStateV2.builder().userId(123L).name("Synthetic Resubmitter")
            .domains(Map.of(Domain.MAINTENANCE, new DomainBusinessUnitUsers(List.of(new BusinessUnitUser("BUU-2",
                (short) 1, Set.of(new Permission(21L, "Synthetic Creator"))))))).build();
        return new OpalJwtAuthenticationToken(state, Domain.MAINTENANCE, original.getToken(), List.of(), null);
    }
}
