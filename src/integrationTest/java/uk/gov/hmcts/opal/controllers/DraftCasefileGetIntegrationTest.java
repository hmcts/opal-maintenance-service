package uk.gov.hmcts.opal.controllers;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
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
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionTemplate;
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
import uk.gov.hmcts.opal.logging.integration.dto.PersonalDataProcessingCategory;
import uk.gov.hmcts.opal.logging.integration.dto.PersonalDataProcessingLogDetails;
import uk.gov.hmcts.opal.logging.integration.service.LoggingService;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.support.DraftCasefileHttpFixture;

import java.time.Clock;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.test.context.jdbc.Sql.ExecutionPhase.AFTER_TEST_METHOD;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
@ExtendWith(OutputCaptureExtension.class)
@TestPropertySource(properties = {
    "spring.flyway.locations=classpath:db/migration/ddl",
    "opal.redis.enabled=false",
    "management.health.redis.enabled=false",
    "spring.jpa.open-in-view=false"
})
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@Sql("/draft-casefile/reference-fixtures.sql")
@Sql(scripts = "/draft-casefile/reference-cleanup.sql", executionPhase = AFTER_TEST_METHOD)
class DraftCasefileGetIntegrationTest extends BaseIntegrationTest {

    private static final JsonMapper JSON = JsonMapper.builder().build();
    private static final Instant VIEWED_AT = Instant.parse("2026-10-03T15:00:00.123456Z");
    private static final String PRIVATE = "SYNTHETIC_PRIVATE_GET_VALUE";
    private static final String SNAPSHOT = """
        {"respondent_account":{"account_id":101,"account_number":"R101","respondent_name":"Synthetic R"},
         "applicant_account":{"account_id":201,"account_number":"A201","applicant_name":"Synthetic A"},
         "minor_creditor_accounts":[
          {"creditor_sequence":7,"account_id":301,"account_number":"M301","name":"Synthetic M1"},
          {"creditor_sequence":2,"account_id":302,"account_number":"M302","name":"Synthetic M2"}]}
        """;
    private static final String TIMELINE = """
        [{"username":"Synthetic Submitter","status":"Submitted","status_date":"2026-10-01T12:00:00Z"},
         {"username":"Synthetic Checker","status":"Rejected","status_date":"2026-10-01T13:00:00Z",
          "reason_text":"Synthetic rejection reason"},
         {"username":"Synthetic Submitter","status":"Resubmitted","status_date":"2026-10-01T14:00:00Z"},
         {"username":"Synthetic Checker","status":"Approved","status_date":"2026-10-02T12:00:00Z"}]
        """;

    @Autowired
    private MockMvc mockMvc;
    @Autowired
    private JdbcTemplate jdbc;
    @Autowired
    private PlatformTransactionManager transactionManager;
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
    }

    @ParameterizedTest
    @EnumSource(value = MaintenancePermission.class,
        names = {"CREATE_MANAGE_DRAFT_CASEFILES", "CHECK_VALIDATE_DRAFT_CASEFILES"})
    void retrievesTheCommittedDraftWithoutChangingAnyPersistedColumn(MaintenancePermission permission)
        throws Exception {
        long id = submitDraft();
        final Map<String, Object> before = completeRow(id);
        doAnswer(invocation -> {
            TransactionTemplate committedRead = new TransactionTemplate(transactionManager);
            committedRead.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
            committedRead.executeWithoutResult(transaction -> assertThat(completeRow(id)).isEqualTo(before));
            return true;
        }).when(logging).personalDataAccessLogAsync(any());
        JsonNode response = retrieve(id, permission, 0);
        assertThat(response.get("casefile_status").asString()).isEqualTo("SUBMITTED");
        assertThat(response.get("casefile_status_name").asString()).isEqualTo("Submitted");
        assertStoredResponseAndUnchangedRow(id, response, before);
        assertConsultationMetadata(id, 2);
    }

    @Test
    void returnsCompletePublishedLinksAndAuditDataWithFourPrivateCategoryLogs(CapturedOutput output) throws Exception {
        final int outputStart = output.getAll().length();
        long id = submitDraft();
        seedLifecycle(id, "PUBLISHED");
        final Map<String, Object> before = completeRow(id);
        JsonNode response = retrieve(id, MaintenancePermission.CHECK_VALIDATE_DRAFT_CASEFILES, 4);
        assertThat(response.get("casefile_status_name").asString()).isEqualTo("Published");
        assertThat(response.get("casefile_snapshot")).isEqualTo(JSON.readTree(SNAPSHOT));
        assertThat(response.at("/casefile_snapshot/minor_creditor_accounts/0/creditor_sequence").intValue())
            .isEqualTo(7);
        assertThat(response.at("/casefile_snapshot/minor_creditor_accounts/1/creditor_sequence").intValue())
            .isEqualTo(2);
        assertThat(response.at("/casefile/minor_creditors/0/creditor_sequence").intValue()).isEqualTo(7);
        assertThat(response.at("/casefile/minor_creditors/1/creditor_sequence").intValue()).isEqualTo(2);
        assertThat(before.get("account_id")).isEqualTo(101L);
        assertThat(before.get("account_number")).isEqualTo("R101");
        assertLifecycleAudit(response);
        assertStoredResponseAndUnchangedRow(id, response, before);
        assertConsultationMetadata(id, 4);
        assertThat(output.getAll().substring(outputStart))
            .doesNotContain(PRIVATE, "Synthetic rejection reason", "Synthetic M1", "Synthetic M2");
    }

    @ParameterizedTest
    @ValueSource(strings = {"REJECTED", "RESUBMITTED", "DELETED", "PUBLISHING_FAILED"})
    void preservesStoredLifecycleReasonsAndValidationWithoutAppendingEvents(String lifecycle, CapturedOutput output)
        throws Exception {
        final int outputStart = output.getAll().length();
        long id = submitDraft();
        seedLifecycle(id, lifecycle);
        final Map<String, Object> before = completeRow(id);
        JsonNode response = retrieve(id, MaintenancePermission.CREATE_MANAGE_DRAFT_CASEFILES, 4);
        assertThat(response.get("casefile_status").asString()).isEqualTo(lifecycle);
        assertThat(response.get("status_message").asString()).isEqualTo(PRIVATE);
        assertLifecycleAudit(response);
        assertStoredResponseAndUnchangedRow(id, response, before);
        assertConsultationMetadata(id, 4);
        assertThat(output.getAll().substring(outputStart)).doesNotContain(PRIVATE, "Synthetic rejection reason");
    }

    @ParameterizedTest
    @ValueSource(booleans = {false, true})
    void publisherFailurePreservesSuccessfulResponseAndAttemptsAllCategories(boolean throwsException,
                                                                            CapturedOutput output)
        throws Exception {
        final int outputStart = output.getAll().length();
        long id = submitDraft();
        seedLifecycle(id, "PUBLISHED");
        final Map<String, Object> before = completeRow(id);
        JsonNode expected = retrieve(id, MaintenancePermission.CREATE_MANAGE_DRAFT_CASEFILES, 4);
        clearInvocations(logging);
        if (throwsException) {
            when(logging.personalDataAccessLogAsync(any())).thenThrow(new IllegalStateException(PRIVATE));
        } else {
            when(logging.personalDataAccessLogAsync(any())).thenReturn(false);
        }
        JsonNode response = retrieve(id, MaintenancePermission.CREATE_MANAGE_DRAFT_CASEFILES, 4);
        assertThat(response).isEqualTo(expected);
        assertStoredResponseAndUnchangedRow(id, response, before);
        assertConsultationMetadata(id, 4);
        assertThat(output.getAll().substring(outputStart)).doesNotContain(PRIVATE);
    }

    @ParameterizedTest
    @ValueSource(strings = {"missing", "unauthenticated", "empty", "other-unit", "missing-identity",
        "malformed", "zero", "negative", "overflow", "unavailable", "timeline", "snapshot", "null-version", "accept"})
    void unsuccessfulRequestsDiscloseNoPrivateValuesAndProduceNoPdpo(String failure, CapturedOutput output)
        throws Exception {
        final int outputStart = output.getAll().length();
        long id = submitDraft();
        seedLifecycle(id, "PUBLISHING_FAILED");
        MockHttpServletRequestBuilder request = get("/draft-casefiles/{id}", id)
            .with(authentication(DraftCasefileHttpFixture.token((short) 1)));
        int expectedStatus = 403;
        switch (failure) {
            case "missing" -> {
                request = get("/draft-casefiles/{id}", Long.MAX_VALUE)
                    .with(authentication(DraftCasefileHttpFixture.token((short) 1)));
                expectedStatus = 404;
            }
            case "unauthenticated" -> {
                request = get("/draft-casefiles/{id}", id);
                expectedStatus = 401;
            }
            case "empty" -> request.with(authentication(DraftCasefileHttpFixture.token((short) 1,
                new MaintenancePermission[0])));
            case "other-unit" -> request.with(authentication(permissionOnlyInOtherUnit()));
            case "missing-identity" -> request.with(authentication(DraftCasefileHttpFixture.token((short) 2)));
            case "malformed", "zero", "negative", "overflow" -> {
                String invalid = switch (failure) {
                    case "malformed" -> "not-an-id";
                    case "zero" -> "0";
                    case "negative" -> "-1";
                    default -> "9223372036854775808";
                };
                request = get("/draft-casefiles/{id}", invalid)
                    .with(authentication(DraftCasefileHttpFixture.token((short) 1)));
                expectedStatus = 400;
            }
            case "accept" -> {
                request.accept(MediaType.TEXT_PLAIN);
                expectedStatus = 406;
            }
            case "unavailable" -> {
                doThrow(new DataAccessResourceFailureException(PRIVATE)).when(repository).findById(id);
                expectedStatus = 503;
            }
            case "timeline", "snapshot" -> {
                String column = failure.equals("timeline") ? "timeline_data" : "casefile_snapshot";
                jdbc.update("UPDATE draft_casefiles SET " + column + " = ?::json WHERE draft_casefile_id = ?",
                    JSON.writeValueAsString(PRIVATE), id);
                expectedStatus = 500;
            }
            case "null-version" -> {
                jdbc.update("UPDATE draft_casefiles SET version_number = NULL WHERE draft_casefile_id = ?", id);
                expectedStatus = 500;
            }
            default -> throw new IllegalArgumentException("Unexpected failure case");
        }
        final Map<String, Object> before = completeRow(id);
        String response = mockMvc.perform(request).andExpect(status().is(expectedStatus))
            .andExpect(header().doesNotExist("ETag"))
            .andExpect(jsonPath("$.operation_id").isNotEmpty())
            .andReturn().getResponse().getContentAsString();
        assertThat(response).doesNotContain(PRIVATE, "Synthetic rejection reason", "Synthetic address");
        assertThat(output.getAll().substring(outputStart))
            .doesNotContain(PRIVATE, "Synthetic rejection reason", "Synthetic address");
        assertThat(completeRow(id)).isEqualTo(before);
        verifyNoInteractions(logging);
    }

    @Test
    void operationalEndpointsRemainPublicInTheSameDatabaseBackedContext() throws Exception {
        mockMvc.perform(get("/")).andExpect(status().isOk());
        mockMvc.perform(get("/health")).andExpect(status().isOk()).andExpect(jsonPath("$.status").value("UP"));
        mockMvc.perform(get("/prometheus")).andExpect(status().isOk());
        verifyNoInteractions(logging);
    }

    private long submitDraft() throws Exception {
        String body = mockMvc.perform(post("/draft-casefiles")
                .contentType(MediaType.APPLICATION_JSON).content(DraftCasefileHttpFixture.requestBody())
                .with(authentication(DraftCasefileHttpFixture.token((short) 1))))
            .andExpect(status().isCreated()).andExpect(header().string("ETag", "\"0\""))
            .andReturn().getResponse().getContentAsString();
        clearInvocations(logging);
        return JSON.readTree(body).get("draft_casefile_id").longValue();
    }

    private JsonNode retrieve(long id, MaintenancePermission permission, long version) throws Exception {
        String body = mockMvc.perform(get("/draft-casefiles/{id}", id)
                .with(authentication(DraftCasefileHttpFixture.token((short) 1, permission)))
                .header("X-User-IP", "192.0.2.1"))
            .andExpect(status().isOk()).andExpect(header().string("ETag", "\"" + version + "\""))
            .andExpect(jsonPath("$.version_number").doesNotExist())
            .andExpect(jsonPath("$.account_id").doesNotExist())
            .andExpect(jsonPath("$.account_number").doesNotExist())
            .andReturn().getResponse().getContentAsString();
        return JSON.readTree(body);
    }

    private void seedLifecycle(long id, String lifecycle) {
        ObjectNode casefile = (ObjectNode) JSON.readTree(completeRow(id).get("casefile").toString());
        ObjectNode firstMinor = ((ObjectNode) casefile.get("applicant")).deepCopy();
        firstMinor.put("creditor_sequence", 7);
        ((ObjectNode) firstMinor.at("/party_details/individual_details")).put("surname", "Synthetic M1");
        ObjectNode secondMinor = firstMinor.deepCopy();
        secondMinor.put("creditor_sequence", 2);
        ((ObjectNode) secondMinor.at("/party_details/individual_details")).put("surname", "Synthetic M2");
        casefile.set("minor_creditors", JSON.createArrayNode().add(firstMinor).add(secondMinor));
        ((ObjectNode) casefile.at("/respondent_account/respondent")).set("third_party_details", JSON.readTree("""
            {"name":"Synthetic Third Party","relationship":"Synthetic relation",
             "reference":"%s","address":{"address_line_1":"Synthetic address","cjs_code":1}}
            """.formatted(PRIVATE)));
        jdbc.update("""
            UPDATE draft_casefiles SET casefile = ?::json, casefile_snapshot = ?::json, timeline_data = ?::json,
                casefile_status = ?::public.t_draft_casefile_status_enum, version_number = ?,
                validated_by = ?, validated_by_name = ?, validated_date = ?::timestamp,
                created_date = ?::timestamp, casefile_status_date = ?::timestamp, status_message = ?,
                account_id = ?, account_number = ?
            WHERE draft_casefile_id = ?
            """, casefile.toString(), SNAPSHOT, TIMELINE, lifecycle, 4L, "BUU-2", "Synthetic Checker",
            "2026-10-02T12:00:00", "2026-10-01T12:00:00", "2026-10-03T12:00:00", PRIVATE, 101L, "R101", id);
    }

    private Map<String, Object> completeRow(long id) {
        Map<String, Object> row = new HashMap<>(jdbc.queryForMap(
            "SELECT * FROM draft_casefiles WHERE draft_casefile_id = ?", id));
        for (String column : List.of("casefile", "casefile_snapshot", "timeline_data")) {
            row.computeIfPresent(column, (key, value) -> JSON.readTree(value.toString()));
        }
        return row;
    }

    private void assertStoredResponseAndUnchangedRow(long id, JsonNode response, Map<String, Object> before) {
        for (String column : List.of("casefile", "casefile_snapshot", "timeline_data")) {
            assertThat(response.get(column)).isEqualTo(before.get(column));
        }
        assertThat(completeRow(id)).isEqualTo(before);
    }

    private void assertLifecycleAudit(JsonNode response) {
        assertThat(response.get("validated_by").asString()).isEqualTo("BUU-2");
        assertThat(response.get("validated_by_name").asString()).isEqualTo("Synthetic Checker");
        for (String path : List.of("/created_date", "/casefile_status_date", "/validated_date")) {
            assertThat(OffsetDateTime.parse(response.at(path).asString()).getOffset()).isEqualTo(ZoneOffset.UTC);
        }
        assertThat(OffsetDateTime.parse(response.get("created_date").asString()).toInstant())
            .isEqualTo(Instant.parse("2026-10-01T12:00:00Z"));
        assertThat(OffsetDateTime.parse(response.get("validated_date").asString()).toInstant())
            .isEqualTo(Instant.parse("2026-10-02T12:00:00Z"));
        assertThat(OffsetDateTime.parse(response.get("casefile_status_date").asString()).toInstant())
            .isEqualTo(Instant.parse("2026-10-03T12:00:00Z"));
        assertThat(response.get("timeline_data")).isEqualTo(JSON.readTree(TIMELINE));
        assertThat(response.at("/timeline_data/1/reason_text").asString()).isEqualTo("Synthetic rejection reason");
    }

    private void assertConsultationMetadata(long id, int categories) {
        ArgumentCaptor<PersonalDataProcessingLogDetails> details =
            ArgumentCaptor.forClass(PersonalDataProcessingLogDetails.class);
        verify(logging, times(categories)).personalDataAccessLogAsync(details.capture());
        List<String> identifiers = List.of("View Draft Casefile - Respondent",
            "View Draft Casefile - Applicant / Beneficiary", "View Draft Casefile - Related parties",
            "View Draft Casefile - Minor Creditor");
        assertThat(details.getAllValues()).extracting(PersonalDataProcessingLogDetails::getBusinessIdentifier)
            .containsExactlyElementsOf(identifiers.subList(0, categories));
        assertThat(details.getAllValues()).allSatisfy(entry -> {
            assertThat(entry.getCategory()).isEqualTo(PersonalDataProcessingCategory.CONSULTATION);
            assertThat(entry.getCreatedAt()).isEqualTo(VIEWED_AT.atOffset(ZoneOffset.UTC));
            assertThat(entry.getCreatedBy().getIdentifier()).isEqualTo("123");
            assertThat(entry.getCreatedBy().getType().getType()).isEqualTo("OPAL_USER_ID");
            assertThat(entry.getIpAddress()).isEqualTo("192.0.2.1");
            assertThat(entry.getRecipient()).isNull();
            assertThat(entry.getIndividuals()).singleElement().satisfies(individual -> {
                assertThat(individual.getIdentifier()).isEqualTo(Long.toString(id));
                assertThat(individual.getType().getType()).isEqualTo("DRAFT_CASEFILE");
            });
            assertThat(JSON.writeValueAsString(entry)).doesNotContain(PRIVATE, "Synthetic", "R101", "M301", "M302");
        });
    }

    private OpalJwtAuthenticationToken permissionOnlyInOtherUnit() {
        OpalJwtAuthenticationToken original = DraftCasefileHttpFixture.token((short) 1);
        UserStateV2 state = UserStateV2.builder().userId(123L).name("Synthetic Submitter")
            .domains(Map.of(Domain.MAINTENANCE, new DomainBusinessUnitUsers(List.of(
                new BusinessUnitUser("BUU-1", (short) 1, Set.of()),
                new BusinessUnitUser("BUU-2", (short) 2, Set.of(new Permission(22L, "Synthetic Checker"))))))).build();
        return new OpalJwtAuthenticationToken(state, Domain.MAINTENANCE, original.getToken(), List.of(), null);
    }
}
