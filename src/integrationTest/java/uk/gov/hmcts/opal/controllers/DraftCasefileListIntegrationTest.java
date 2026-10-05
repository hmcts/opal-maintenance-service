package uk.gov.hmcts.opal.controllers;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.EnumSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.dao.DataAccessResourceFailureException;
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
import uk.gov.hmcts.opal.common.spring.security.OpalJwtAuthenticationToken;
import uk.gov.hmcts.opal.common.user.authorisation.model.BusinessUnitUser;
import uk.gov.hmcts.opal.common.user.authorisation.model.Domain;
import uk.gov.hmcts.opal.common.user.authorisation.model.DomainBusinessUnitUsers;
import uk.gov.hmcts.opal.common.user.authorisation.model.Permission;
import uk.gov.hmcts.opal.common.user.authorisation.model.UserStateV2;
import uk.gov.hmcts.opal.config.JacksonCompatibilityConfiguration;
import uk.gov.hmcts.opal.dto.DraftCasefileFilter;
import uk.gov.hmcts.opal.logging.integration.dto.ParticipantIdentifier;
import uk.gov.hmcts.opal.logging.integration.dto.PersonalDataProcessingCategory;
import uk.gov.hmcts.opal.logging.integration.dto.PersonalDataProcessingLogDetails;
import uk.gov.hmcts.opal.logging.integration.service.LoggingService;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.support.DraftCasefileHttpFixture;
import uk.gov.hmcts.opal.support.DraftCasefileSqlCaptureConfiguration.StatementCapture;
import uk.gov.hmcts.opal.support.DraftCasefileSqlCaptureConfiguration;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.test.context.jdbc.Sql.ExecutionPhase.AFTER_TEST_METHOD;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static uk.gov.hmcts.opal.authorisation.MaintenancePermission.CHECK_VALIDATE_DRAFT_CASEFILES;
import static uk.gov.hmcts.opal.authorisation.MaintenancePermission.CREATE_MANAGE_DRAFT_CASEFILES;

@AutoConfigureMockMvc
@ExtendWith(OutputCaptureExtension.class)
@TestPropertySource(properties = {
    "spring.flyway.locations=classpath:db/migration/ddl",
    "opal.redis.enabled=false",
    "management.health.redis.enabled=false",
    "spring.jpa.open-in-view=false"
})
@Import(DraftCasefileSqlCaptureConfiguration.class)
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@Sql("/draft-casefile/list-fixtures.sql")
@Sql(scripts = "/draft-casefile/list-cleanup.sql", executionPhase = AFTER_TEST_METHOD)
class DraftCasefileListIntegrationTest extends BaseIntegrationTest {
    private static final JsonMapper JSON = JsonMapper.builder().build();
    private static final Instant VIEWED_AT = Instant.parse("2026-10-05T12:00:00.123456Z");

    @Autowired
    private MockMvc mockMvc;
    @Autowired
    private JdbcTemplate jdbc;
    @Autowired
    private StatementCapture capture;
    @MockitoSpyBean
    private DraftCasefileRepository repository;
    @MockitoBean
    private LoggingService logging;
    @MockitoBean
    private Clock clock;

    @BeforeEach
    void setUp() {
        when(clock.instant()).thenReturn(VIEWED_AT);
        when(logging.personalDataAccessLogAsync(any())).thenReturn(true);
        capture.clear();
    }

    private MockHttpServletRequestBuilder listRequest(boolean counts, MaintenancePermission permission) {
        MockHttpServletRequestBuilder request = get("/draft-casefiles")
            .param("business_unit_id", "31021")
            .with(authentication(DraftCasefileHttpFixture.token((short) 31021, permission)))
            .header("X-User-IP", "192.0.2.1");
        return counts ? request.param("restrict", "counts") : request;
    }

    private JsonNode perform(MockHttpServletRequestBuilder request) throws Exception {
        return JSON.readTree(mockMvc.perform(request).andExpect(status().isOk())
            .andExpect(header().doesNotExist("ETag")).andExpect(header().doesNotExist("Location"))
            .andReturn().getResponse().getContentAsString());
    }

    private Map<String, Object> storedRow(long id) {
        return jdbc.queryForMap("SELECT * FROM draft_casefiles WHERE draft_casefile_id = ?", id);
    }

    @ParameterizedTest
    @EnumSource(value = MaintenancePermission.class,
        names = {"CREATE_MANAGE_DRAFT_CASEFILES", "CHECK_VALIDATE_DRAFT_CASEFILES"})
    void eitherPermissionCanReadSummariesAndCountsInTheRequestedUnit(MaintenancePermission permission)
        throws Exception {
        var normal = perform(listRequest(false, permission));
        assertThat(normal.get("count").longValue()).isEqualTo(6);
        assertThat(normal.get("summaries").size()).isEqualTo(6);
        assertThat(normal.get("summaries")).allSatisfy(summary -> {
            assertThat(summary.get("business_unit_id").intValue()).isEqualTo(31021);
            assertThat(summary.has("casefile")).isFalse();
            assertThat(summary.has("timeline_data")).isFalse();
            assertThat(summary.has("status_message")).isFalse();
            assertThat(summary.has("version_number")).isFalse();
        });
        clearInvocations(logging, repository);
        capture.clear();
        var counts = perform(listRequest(true, permission));
        assertThat(counts.propertyNames()).containsExactly("count");
        assertThat(counts.get("count").longValue()).isEqualTo(6);
        verify(repository, never()).findSummaries(any(DraftCasefileFilter.class));
        verifyNoInteractions(logging);
        assertThat(capture.draftSelects()).singleElement().satisfies(sql ->
            assertThat(sql.toLowerCase(Locale.ROOT)).startsWith("select count(*)"));
    }

    @ParameterizedTest
    @CsvSource(delimiter = '|', value = {
        "submitted_by|BUU-1|3",
        "not_submitted_by|BUU-1|3",
        "casefile_status|SUBMITTED,RESUBMITTED|3",
        "casefile_status_from_date|2026-10-02|2",
        "casefile_status_to_date|2026-10-01|4",
        "submitted_by|UNKNOWN|0"
    })
    void eachFilterAppliesInBothModes(String name, String value, long expected) throws Exception {
        for (boolean counts : List.of(false, true)) {
            clearInvocations(logging, repository);
            capture.clear();
            var body = perform(listRequest(counts, CREATE_MANAGE_DRAFT_CASEFILES).param(name, value));
            assertThat(body.get("count").longValue()).isEqualTo(expected);
            if (counts) {
                assertThat(body.propertyNames()).containsExactly("count");
                verifyNoInteractions(logging);
            } else {
                assertThat(body.get("summaries").size()).isEqualTo((int) expected);
                if (expected == 0) {
                    verifyNoInteractions(logging);
                }
            }
        }
    }

    @Test
    void combinedFiltersIncludeBothUtcDayEdgesAndExcludeTheNextMidnight() throws Exception {
        for (boolean counts : List.of(false, true)) {
            clearInvocations(logging);
            var response = perform(listRequest(counts, CREATE_MANAGE_DRAFT_CASEFILES)
                .param("casefile_status", "SUBMITTED,RESUBMITTED")
                .param("casefile_status_from_date", "2026-10-01")
                .param("casefile_status_to_date", "2026-10-01"));
            assertThat(response.get("count").longValue()).isEqualTo(2);
            if (!counts) {
                assertThat(response.get("summaries")).extracting(row -> row.get("draft_casefile_id").longValue())
                    .containsExactly(910201L, 910202L);
            } else {
                verifyNoInteractions(logging);
            }
        }
    }

    @Test
    void publishedSummaryPreservesLinksAndApprovalDateAndDoesNotChangeAnyColumn() throws Exception {
        String snapshot = """
            {"respondent_account":{"account_id":101,"account_number":"R101","respondent_name":"Synthetic R"},
             "applicant_account":{"account_id":201,"account_number":"A201","applicant_name":"Synthetic A"},
             "minor_creditor_accounts":[
              {"creditor_sequence":7,"account_id":301,"account_number":"M301","name":"Synthetic M1"},
              {"creditor_sequence":2,"account_id":302,"account_number":"M302","name":"Synthetic M2"}]}
            """;
        String casefile = """
            {"respondent_account":{"respondent":{}},"applicant":{},
             "minor_creditors":[{"creditor_sequence":7},{"creditor_sequence":2}]}
            """;
        jdbc.update("""
            UPDATE draft_casefiles
            SET casefile_snapshot = ?::json, casefile = ?::json,
                validated_date = TIMESTAMP '2026-10-02 12:00:00',
                validated_by = 'BUU-CHECKER', validated_by_name = 'Synthetic Checker',
                account_id = 101, account_number = 'R101'
            WHERE draft_casefile_id = 910206
            """, snapshot, casefile);
        var before = storedRow(910206);
        var body = perform(listRequest(false, CHECK_VALIDATE_DRAFT_CASEFILES).param("casefile_status", "PUBLISHED"));
        var summary = body.get("summaries").get(0);
        assertThat(summary.get("casefile_snapshot")).isEqualTo(JSON.readTree(snapshot));
        assertThat(summary.get("created_date").asString()).isEqualTo("2026-09-01T10:00:00Z");
        assertThat(summary.get("validated_date").asString()).isEqualTo("2026-10-02T12:00:00Z");
        assertThat(summary.get("casefile_status_date").asString()).isEqualTo("2026-10-03T12:00:00Z");
        assertThat(summary.get("casefile_status_name").asString()).isEqualTo("Published");
        assertThat(summary.has("account_id")).isFalse();
        assertThat(summary.has("account_number")).isFalse();
        assertThat(summary.has("validated_by")).isFalse();
        assertThat(storedRow(910206)).isEqualTo(before);
    }

    @Test
    void listLoggingGroupsTheFilteredResultAndContainsOnlyContractMetadata(CapturedOutput output) throws Exception {
        final int start = output.getAll().length();
        perform(listRequest(false, CREATE_MANAGE_DRAFT_CASEFILES)
            .param("casefile_status", "SUBMITTED,RESUBMITTED")
            .param("casefile_status_from_date", "2026-10-01")
            .param("casefile_status_to_date", "2026-10-01"));
        var details = ArgumentCaptor.forClass(PersonalDataProcessingLogDetails.class);
        verify(logging, times(3)).personalDataAccessLogAsync(details.capture());
        assertThat(details.getAllValues()).extracting(PersonalDataProcessingLogDetails::getBusinessIdentifier)
            .containsExactly("View Draft Casefiles - Respondent", "View Draft Casefiles - Applicant / Beneficiary",
                "View Draft Casefiles - Minor Creditor");
        assertThat(details.getAllValues().get(0).getIndividuals())
            .extracting(ParticipantIdentifier::getIdentifier).containsExactly("910201", "910202");
        assertThat(details.getAllValues().get(1).getIndividuals())
            .extracting(ParticipantIdentifier::getIdentifier).containsExactly("910201", "910202");
        assertThat(details.getAllValues().get(2).getIndividuals())
            .extracting(ParticipantIdentifier::getIdentifier).containsExactly("910202");
        assertThat(details.getAllValues()).allSatisfy(entry -> {
            assertThat(entry.getCategory()).isEqualTo(PersonalDataProcessingCategory.CONSULTATION);
            assertThat(entry.getCreatedBy().getIdentifier()).isEqualTo("123");
            assertThat(entry.getCreatedBy().getType().getType()).isEqualTo("OPAL_USER_ID");
            assertThat(entry.getCreatedAt()).isEqualTo(VIEWED_AT.atOffset(ZoneOffset.UTC));
            assertThat(entry.getIpAddress()).isEqualTo("192.0.2.1");
            assertThat(entry.getRecipient()).isNull();
            assertThat(entry.getIndividuals()).allSatisfy(id ->
                assertThat(id.getType().getType()).isEqualTo("DRAFT_CASEFILE"));
        });
        String serialised = new JacksonCompatibilityConfiguration().objectMapper()
            .writeValueAsString(details.getAllValues());
        assertThat(serialised).doesNotContain("casefile_snapshot", "respondent_name", "Synthetic R",
            "Synthetic A", "bank_account_details", "timeline_data", "status_message");
        assertThat(output.getAll().substring(start)).doesNotContain("Synthetic R", "Synthetic A");
    }

    @Test
    void unreadableSnapshotReturnsCorrelatedProblemWithoutLoggingPrivateValues(CapturedOutput output)
        throws Exception {
        String privateMarker = "SYNTHETIC_PRIVATE_LIST_VALUE";
        jdbc.update("UPDATE draft_casefiles SET casefile_snapshot = ?::json WHERE draft_casefile_id = ?",
            JSON.writeValueAsString(privateMarker), 910201L);
        int start = output.getAll().length();
        String response = mockMvc.perform(listRequest(false, CREATE_MANAGE_DRAFT_CASEFILES))
            .andExpect(status().isInternalServerError())
            .andExpect(jsonPath("$.operation_id").isNotEmpty())
            .andReturn().getResponse().getContentAsString();
        assertThat(response).doesNotContain(privateMarker, "Synthetic R", "Synthetic A");
        assertThat(output.getAll().substring(start)).doesNotContain(privateMarker, "Synthetic R", "Synthetic A");
        verifyNoInteractions(logging);
    }

    @Test
    void combinedIncludeExcludeFiltersSelectOneRowAndIdenticalSubmittersSelectNone() throws Exception {
        for (boolean counts : List.of(false, true)) {
            clearInvocations(logging);
            var response = perform(listRequest(counts, CREATE_MANAGE_DRAFT_CASEFILES)
                .param("submitted_by", "BUU-2").param("not_submitted_by", "BUU-1")
                .param("casefile_status", "SUBMITTED,RESUBMITTED")
                .param("casefile_status_from_date", "2026-10-01")
                .param("casefile_status_to_date", "2026-10-01"));
            assertThat(response.get("count").longValue()).isEqualTo(1);
            if (!counts) {
                assertThat(response.get("summaries").get(0).get("draft_casefile_id").longValue()).isEqualTo(910202L);
            } else {
                verifyNoInteractions(logging);
            }
            clearInvocations(logging);
            var empty = perform(listRequest(counts, CREATE_MANAGE_DRAFT_CASEFILES)
                .param("submitted_by", "BUU-1").param("not_submitted_by", "BUU-1"));
            assertThat(empty.get("count").longValue()).isZero();
            if (!counts) {
                assertThat(empty.get("summaries").isEmpty()).isTrue();
            }
            verifyNoInteractions(logging);
        }
    }

    @Test
    void summerFiltersStillUseUtcRatherThanBst() throws Exception {
        jdbc.update("UPDATE draft_casefiles SET casefile_status_date = TIMESTAMP '2026-07-01 23:30:00' "
            + "WHERE draft_casefile_id = 910201");
        jdbc.update("UPDATE draft_casefiles SET casefile_status_date = TIMESTAMP '2026-07-02 00:00:00' "
            + "WHERE draft_casefile_id = 910202");
        jdbc.update("UPDATE draft_casefiles SET casefile_status_date = TIMESTAMP '2026-06-30 23:30:00' "
            + "WHERE draft_casefile_id = 910203");
        for (boolean counts : List.of(false, true)) {
            var response = perform(listRequest(counts, CREATE_MANAGE_DRAFT_CASEFILES)
                .param("casefile_status_from_date", "2026-07-01")
                .param("casefile_status_to_date", "2026-07-01"));
            assertThat(response.get("count").longValue()).isEqualTo(1);
            if (!counts) {
                assertThat(response.get("summaries").get(0).get("draft_casefile_id").longValue()).isEqualTo(910201L);
            }
        }
    }

    @Test
    void bothModesLeaveStoredDraftsUnchangedAndNormalUsesOnlyOneProjectionQuery() throws Exception {
        final var before = storedRow(910201);
        capture.clear();
        perform(listRequest(false, CREATE_MANAGE_DRAFT_CASEFILES));
        assertThat(capture.draftSelects()).singleElement().satisfies(sql -> {
            assertThat(sql).contains("casefile_snapshot");
            assertThat(sql).doesNotContain("count(*)", "d.casefile,", "timeline_data");
        });
        assertThat(storedRow(910201)).isEqualTo(before);
        clearInvocations(logging);
        perform(listRequest(true, CREATE_MANAGE_DRAFT_CASEFILES));
        assertThat(storedRow(910201)).isEqualTo(before);
        verifyNoInteractions(logging);
    }

    @Test
    void countsDoNotParseMalformedSnapshots() throws Exception {
        jdbc.update("UPDATE draft_casefiles SET casefile_snapshot = ?::json WHERE draft_casefile_id = ?",
            JSON.writeValueAsString("SYNTHETIC_PRIVATE_LIST_VALUE"), 910201L);
        capture.clear();
        var response = perform(listRequest(true, CREATE_MANAGE_DRAFT_CASEFILES));
        assertThat(response.propertyNames()).containsExactly("count");
        assertThat(response.get("count").longValue()).isEqualTo(6);
        verify(repository, never()).findSummaries(any(DraftCasefileFilter.class));
        verifyNoInteractions(logging);
        assertThat(capture.draftSelects()).singleElement().satisfies(sql ->
            assertThat(sql.toLowerCase(Locale.ROOT)).doesNotContain("casefile_snapshot", "json_"));
    }

    @Test
    void acceptedEscapedZeroSnapshotNameIsReturnedUnchanged() throws Exception {
        String stored = jdbc.queryForObject(
            "SELECT casefile_snapshot::text FROM draft_casefiles WHERE draft_casefile_id = 910201", String.class);
        ObjectNode snapshot = (ObjectNode) JSON.readTree(stored);
        String name = "Synthetic " + (char) 0;
        ((ObjectNode) snapshot.get("respondent_account")).put("respondent_name", name);
        jdbc.update("UPDATE draft_casefiles SET casefile_snapshot = ?::json WHERE draft_casefile_id = 910201",
            JSON.writeValueAsString(snapshot));
        var body = perform(listRequest(false, CREATE_MANAGE_DRAFT_CASEFILES));
        assertThat(body.get("summaries").get(0).at("/casefile_snapshot/respondent_account/respondent_name").asString())
            .isEqualTo(name);
    }

    @ParameterizedTest
    @ValueSource(booleans = {false, true})
    void failedPublisherStillReturnsSummariesAndAttemptsEveryCategory(boolean throwsException, CapturedOutput output)
        throws Exception {
        if (throwsException) {
            when(logging.personalDataAccessLogAsync(any()))
                .thenThrow(new IllegalStateException("SYNTHETIC_PRIVATE_LIST_VALUE"));
        } else {
            when(logging.personalDataAccessLogAsync(any())).thenReturn(false);
        }
        int start = output.getAll().length();
        var response = perform(listRequest(false, CREATE_MANAGE_DRAFT_CASEFILES));
        assertThat(response.get("count").longValue()).isEqualTo(6);
        verify(logging, times(3)).personalDataAccessLogAsync(any());
        assertThat(output.getAll().substring(start)).doesNotContain("SYNTHETIC_PRIVATE_LIST_VALUE", "Synthetic R");
    }

    @ParameterizedTest
    @CsvSource(delimiter = '|', value = {
        "business_unit_id|0", "business_unit_id|-1", "business_unit_id|nonnumeric", "business_unit_id|32768",
        "casefile_status|UNKNOWN", "casefile_status_from_date|nondatetime", "casefile_status_to_date|nondatetime",
        "restrict|unsupported", "submitted_by|SYNTHETIC_PRIVATE_QUERY", "not_submitted_by|SYNTHETIC_PRIVATE_QUERY"
    })
    void invalidFiltersReturnCorrelatedProblemsWithoutLogging(String name, String value) throws Exception {
        for (boolean counts : List.of(false, true)) {
            var request = listRequest(counts, CREATE_MANAGE_DRAFT_CASEFILES);
            request.param(name, value);
            if (name.equals("business_unit_id")) {
                request = get("/draft-casefiles").param(name, value)
                    .with(authentication(DraftCasefileHttpFixture.token((short) 31021)));
                if (counts) {
                    request.param("restrict", "counts");
                }
            }
            assertProblem(request, 400);
        }
    }

    @Test
    void missingBlankEmptyAndReversedFiltersReturnBadRequest() throws Exception {
        assertProblem(get("/draft-casefiles").with(authentication(DraftCasefileHttpFixture.token((short) 31021))), 400);
        assertProblem(listRequest(false, CREATE_MANAGE_DRAFT_CASEFILES).param("restrict", ""), 400);
        assertProblem(listRequest(false, CREATE_MANAGE_DRAFT_CASEFILES).param("submitted_by", " "), 400);
        assertProblem(listRequest(false, CREATE_MANAGE_DRAFT_CASEFILES).param("casefile_status", ""), 400);
        assertProblem(listRequest(false, CREATE_MANAGE_DRAFT_CASEFILES)
            .param("casefile_status_from_date", "2026-10-02").param("casefile_status_to_date", "2026-10-01"), 400);
    }

    @Test
    void missingAuthenticationAndScopedPermissionsProduceNoQueryOrLogging() throws Exception {
        for (boolean counts : List.of(false, true)) {
            var unauthenticated = get("/draft-casefiles").param("business_unit_id", "31021");
            if (counts) {
                unauthenticated.param("restrict", "counts");
            }
            assertProblem(unauthenticated, 401);
            assertProblem(listRequest(counts, CREATE_MANAGE_DRAFT_CASEFILES)
                .with(authentication(DraftCasefileHttpFixture.token(
                    (short) 31021, new MaintenancePermission[0]))), 403);
            assertProblem(listRequest(counts, CREATE_MANAGE_DRAFT_CASEFILES)
                .with(authentication(DraftCasefileHttpFixture.token((short) 31022))), 403);
            assertProblem(listRequest(counts, CREATE_MANAGE_DRAFT_CASEFILES)
                .with(authentication(permissionOnlyInOtherUnit())), 403);
        }
        verifyNoInteractions(repository, logging);
    }

    @Test
    void unsupportedAcceptReturnsCommonProblemBeforeQuery() throws Exception {
        assertProblem(listRequest(false, CREATE_MANAGE_DRAFT_CASEFILES).accept(MediaType.TEXT_PLAIN), 406);
        verifyNoInteractions(repository, logging);
    }

    @ParameterizedTest
    @ValueSource(booleans = {false, true})
    void unavailableRepositoryReturnsSafeServiceUnavailable(boolean counts) throws Exception {
        var failure = new DataAccessResourceFailureException("SYNTHETIC_PRIVATE_LIST_VALUE");
        if (counts) {
            doThrow(failure).when(repository).countMatching(any(DraftCasefileFilter.class));
        } else {
            doThrow(failure).when(repository).findSummaries(any(DraftCasefileFilter.class));
        }
        assertProblem(listRequest(counts, CREATE_MANAGE_DRAFT_CASEFILES), 503);
    }

    private void assertProblem(MockHttpServletRequestBuilder request, int expectedStatus) throws Exception {
        String response = mockMvc.perform(request).andExpect(status().is(expectedStatus))
            .andExpect(jsonPath("$.operation_id").isNotEmpty())
            .andExpect(header().doesNotExist("ETag")).andExpect(header().doesNotExist("Location"))
            .andReturn().getResponse().getContentAsString();
        assertThat(response).doesNotContain("SYNTHETIC_PRIVATE", "Synthetic R", "Synthetic A");
        verifyNoInteractions(logging);
    }

    private OpalJwtAuthenticationToken permissionOnlyInOtherUnit() {
        var original = DraftCasefileHttpFixture.token((short) 31021);
        UserStateV2 state = UserStateV2.builder().userId(123L).name("Synthetic Submitter")
            .domains(Map.of(Domain.MAINTENANCE, new DomainBusinessUnitUsers(List.of(
                new BusinessUnitUser("BUU-1", (short) 31021, Set.of()),
                new BusinessUnitUser("BUU-2", (short) 31022,
                    Set.of(new Permission(22L, "Synthetic Checker"))))))).build();
        return new OpalJwtAuthenticationToken(state, Domain.MAINTENANCE, original.getToken(), List.of(), null);
    }
}
