package uk.gov.hmcts.opal.controllers;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.context.jdbc.Sql;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;
import tools.jackson.databind.node.ObjectNode;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.logging.integration.service.LoggingService;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.support.DraftCasefileHttpFixture;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.test.context.jdbc.Sql.ExecutionPhase.AFTER_TEST_METHOD;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static uk.gov.hmcts.opal.authorisation.MaintenancePermission.CHECK_VALIDATE_DRAFT_CASEFILES;
import static uk.gov.hmcts.opal.entity.DraftCasefileStatus.PUBLISHED;
import static uk.gov.hmcts.opal.entity.DraftCasefileStatus.REJECTED;
import static uk.gov.hmcts.opal.entity.DraftCasefileStatus.SUBMITTED;

/** Controlled persistence fixtures prove HTTP list behaviour, independently of deployed publisher journeys. */
@AutoConfigureMockMvc
@TestPropertySource(properties = {
    "spring.flyway.locations=classpath:db/migration/ddl",
    "opal.redis.enabled=false",
    "management.health.redis.enabled=false",
    "spring.jpa.open-in-view=false"
})
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@Sql("/draft-casefile/list-fixtures.sql")
@Sql(scripts = "/draft-casefile/list-cleanup.sql", executionPhase = AFTER_TEST_METHOD)
class DraftCasefileListQaIntegrationTest extends BaseIntegrationTest {

    private static final JsonMapper JSON = JsonMapper.builder().build();
    private static final short LOCAL_UNIT = 31021;
    private static final short FOREIGN_UNIT = 31022;
    private static final String INPUTTER_A = "BUU-QA-A";
    private static final String INPUTTER_B = "BUU-QA-B";
    private static final LocalDateTime CREATED_AT = LocalDateTime.parse("2024-12-01T10:00:00");
    private static final LocalDateTime INSIDE_RANGE = LocalDateTime.parse("2026-10-04T12:00:00");
    private static final LocalDateTime VALIDATED_AT = LocalDateTime.parse("2026-10-02T12:00:00");
    private static final String CASEFILE = """
        {"respondent_account":{"respondent":{}},"applicant":{},
         "minor_creditors":[{"creditor_sequence":7},{"creditor_sequence":23}]}
        """;
    private static final String SNAPSHOT = """
        {"respondent_account":{"account_id":null,"account_number":null,"respondent_name":"Synthetic R"},
         "applicant_account":{"account_id":null,"account_number":null,"applicant_name":"Synthetic A"},
         "minor_creditor_accounts":[
          {"creditor_sequence":7,"account_id":null,"account_number":null,"name":"Synthetic M1"},
          {"creditor_sequence":23,"account_id":null,"account_number":null,"name":"Synthetic M2"}]}
        """;
    private static final String SUBMISSION_TIMELINE = """
        [{"username":"Synthetic Submitter","status":"Submitted","status_date":"2024-12-01T10:00:00Z"}]
        """;
    private static final String APPROVAL_TIMELINE = """
        [{"username":"Synthetic Submitter","status":"Submitted","status_date":"2024-12-01T10:00:00Z"},
         {"username":"Synthetic Checker","status":"Approved","status_date":"2026-10-02T12:00:00Z"}]
        """;
    private static final List<String> SUMMARY_FIELDS = List.of(
        "draft_casefile_id", "business_unit_id", "created_date", "submitted_by", "submitted_by_name",
        "validated_date", "casefile_snapshot", "casefile_type", "casefile_status", "casefile_status_name",
        "casefile_status_date");

    @Autowired
    private MockMvc mockMvc;
    @Autowired
    private DraftCasefileRepository repository;
    @MockitoBean
    private LoggingService logging;
    @MockitoBean
    private Clock clock;

    @BeforeEach
    void setUp() {
        when(clock.instant()).thenReturn(Instant.parse("2026-10-08T12:00:00Z"));
        when(logging.personalDataAccessLogAsync(any())).thenReturn(true);
        // Replace only the seven drafts owned by list-fixtures.sql; retain its BU and parent-account fixtures.
        repository.deleteAllByIdInBatch(List.of(910201L, 910202L, 910203L, 910204L, 910205L, 910206L, 910207L));
    }

    @Test
    void sevenCalendarDaysIncludeBothEdgesAndUnboundedRejectedHasNoAgeLimit() throws Exception {
        DraftCasefileEntity before = save(REJECTED, INPUTTER_A, "2026-09-30T23:59:59.999999");
        DraftCasefileEntity lower = save(REJECTED, INPUTTER_A, "2026-10-01T00:00:00");
        DraftCasefileEntity inside = save(REJECTED, INPUTTER_A, "2026-10-04T12:00:00");
        DraftCasefileEntity upper = save(REJECTED, INPUTTER_A, "2026-10-07T23:59:59.999999");
        DraftCasefileEntity nextDay = save(REJECTED, INPUTTER_A, "2026-10-08T00:00:00");
        DraftCasefileEntity old = save(REJECTED, INPUTTER_A, "2025-01-01T00:00:00");

        JsonNode bounded = performList(inSevenDays(listRequest(false)).param("casefile_status", "REJECTED"));
        assertIds(bounded, lower, inside, upper);
        assertCountOnly(performList(inSevenDays(listRequest(true)).param("casefile_status", "REJECTED")), 3);
        JsonNode unbounded = performList(listRequest(false).param("casefile_status", "REJECTED"));
        assertIds(unbounded, before, lower, inside, upper, nextDay, old);
    }

    @Test
    void rejectedListIncludesBothInputtersAndExcludesOtherStatusAndBusinessUnit() throws Exception {
        DraftCasefileEntity rejectedA = repository.saveAndFlush(fixture(REJECTED, INPUTTER_A).build());
        DraftCasefileEntity rejectedB = repository.saveAndFlush(fixture(REJECTED, INPUTTER_B).build());
        repository.saveAndFlush(fixture(SUBMITTED, INPUTTER_A).build());
        final DraftCasefileEntity foreign = repository.saveAndFlush(fixture(REJECTED, INPUTTER_B)
            .businessUnitId(FOREIGN_UNIT).build());

        JsonNode body = performList(listRequest(false).param("casefile_status", "REJECTED"));
        assertIds(body, rejectedA, rejectedB);
        assertThat(body.get("summaries")).extracting(row -> row.get("submitted_by").asString())
            .containsExactlyInAnyOrder(INPUTTER_A, INPUTTER_B);
        assertThat(body.get("summaries")).allSatisfy(row ->
            assertThat(row.get("business_unit_id").intValue()).isEqualTo(LOCAL_UNIT));
        assertThat(body.get("summaries")).extracting(row -> row.get("draft_casefile_id").longValue())
            .doesNotContain(foreign.getDraftCasefileId());
        assertCountOnly(performList(listRequest(true).param("casefile_status", "REJECTED")), 2);
    }

    @ParameterizedTest
    @EnumSource(value = DraftCasefileStatus.class, names = {"REJECTED", "PUBLISHING_FAILED"})
    void filteredCountsDoNotCallThePersonalDataLoggingBoundary(DraftCasefileStatus lifecycle) throws Exception {
        repository.saveAndFlush(fixture(lifecycle, INPUTTER_A).build());
        repository.saveAndFlush(fixture(lifecycle, INPUTTER_A)
            .casefileStatusDate(LocalDateTime.parse("2026-10-07T23:59:59.999999")).build());
        repository.saveAndFlush(fixture(SUBMITTED, INPUTTER_A).build());
        repository.saveAndFlush(fixture(lifecycle, INPUTTER_A).businessUnitId(FOREIGN_UNIT).build());
        repository.saveAndFlush(fixture(lifecycle, INPUTTER_B).build());
        save(lifecycle, INPUTTER_A, "2026-10-08T00:00:00");

        clearInvocations(logging);
        JsonNode body = performList(inSevenDays(listRequest(true))
            .param("casefile_status", lifecycle.name()).param("submitted_by", INPUTTER_A));
        assertCountOnly(body, 2);
        // MockMvc has completed the transaction; this observes boundary calls, not a deployed downstream sink.
        verifyNoInteractions(logging);
    }

    @ParameterizedTest
    @EnumSource(value = DraftCasefileStatus.class, names = {"PUBLISHED", "PUBLISHING_FAILED"})
    void storedPublicationStatesRetainProjectionAndApprovalHistory(DraftCasefileStatus lifecycle) throws Exception {
        boolean published = lifecycle == PUBLISHED;
        String snapshot = publicationSnapshot(published);
        DraftCasefileEntity stored = repository.saveAndFlush(fixture(lifecycle, INPUTTER_A)
            .validatedDate(VALIDATED_AT).validatedBy("BUU-QA-CHECKER").validatedByName("Synthetic Checker")
            .casefileSnapshot(snapshot).timelineData(APPROVAL_TIMELINE)
            .accountId(published ? 101L : null).accountNumber(published ? "R101" : null)
            .statusMessage(published ? null : "Synthetic publication failure").build());
        long id = stored.getDraftCasefileId();
        final DraftCasefileEntity before = repository.findById(id).orElseThrow();
        JsonNode detailBefore = retrieve(id);

        JsonNode body = performList(listRequest(false).param("casefile_status", lifecycle.name()));
        assertIds(body, stored);
        JsonNode summary = body.get("summaries").get(0);
        assertThat(summary.propertyNames()).containsExactlyInAnyOrderElementsOf(SUMMARY_FIELDS);
        for (String field : SUMMARY_FIELDS) {
            assertThat(summary.get(field)).as("shared field %s", field).isEqualTo(detailBefore.get(field));
        }
        assertThat(summary.get("casefile_status").asString()).isEqualTo(lifecycle.name());
        assertThat(summary.get("casefile_status_name").asString()).isEqualTo(lifecycle.getDisplayName());
        assertThat(summary.get("validated_date").asString()).isEqualTo("2026-10-02T12:00:00Z");
        assertThat(summary.get("casefile_snapshot")).isEqualTo(JSON.readTree(snapshot));
        assertSnapshotIdentities(summary.get("casefile_snapshot"), published);
        assertThat(detailBefore.at("/casefile/minor_creditors/0/creditor_sequence").intValue()).isEqualTo(7);
        assertThat(detailBefore.at("/casefile/minor_creditors/1/creditor_sequence").intValue()).isEqualTo(23);
        assertThat(detailBefore.get("timeline_data")).isEqualTo(JSON.readTree(APPROVAL_TIMELINE));
        assertThat(detailBefore.at("/timeline_data/1/status").asString()).isEqualTo("Approved");
        assertThat(detailBefore.at("/timeline_data/1/status_date").asString()).isEqualTo("2026-10-02T12:00:00Z");
        assertThat(retrieve(id)).isEqualTo(detailBefore);
        DraftCasefileEntity after = repository.findById(id).orElseThrow();
        assertThat(after).usingRecursiveComparison().isEqualTo(before);
        assertThat(after.getAccountId()).isEqualTo(published ? 101L : null);
        assertThat(after.getAccountNumber()).isEqualTo(published ? "R101" : null);
        assertThat(after.getTimelineData()).isEqualTo(APPROVAL_TIMELINE);
    }

    private DraftCasefileEntity.DraftCasefileEntityBuilder fixture(DraftCasefileStatus lifecycle, String submitter) {
        return DraftCasefileEntity.builder().businessUnitId(LOCAL_UNIT).createdDate(CREATED_AT)
            .submittedBy(submitter).submittedByName("Synthetic Submitter")
            .casefile(CASEFILE).casefileSnapshot(SNAPSHOT).casefileType("REMO In")
            .casefileStatus(lifecycle).casefileStatusDate(INSIDE_RANGE).timelineData(SUBMISSION_TIMELINE)
            .versionNumber(0L);
    }

    private DraftCasefileEntity save(DraftCasefileStatus lifecycle, String submitter, String statusDate) {
        return repository.saveAndFlush(fixture(lifecycle, submitter)
            .casefileStatusDate(LocalDateTime.parse(statusDate)).build());
    }

    private MockHttpServletRequestBuilder listRequest(boolean counts) {
        MockHttpServletRequestBuilder request = get("/draft-casefiles").param("business_unit_id", "31021")
            .with(authentication(DraftCasefileHttpFixture.token(LOCAL_UNIT, CHECK_VALIDATE_DRAFT_CASEFILES)))
            .header("X-User-IP", "192.0.2.1");
        return counts ? request.param("restrict", "counts") : request;
    }

    private MockHttpServletRequestBuilder inSevenDays(MockHttpServletRequestBuilder request) {
        return request.param("casefile_status_from_date", "2026-10-01")
            .param("casefile_status_to_date", "2026-10-07");
    }

    private JsonNode performList(MockHttpServletRequestBuilder request) throws Exception {
        return JSON.readTree(mockMvc.perform(request).andExpect(status().isOk())
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
            .andExpect(header().doesNotExist("ETag")).andExpect(header().doesNotExist("Location"))
            .andReturn().getResponse().getContentAsString());
    }

    private JsonNode retrieve(long id) throws Exception {
        return JSON.readTree(mockMvc.perform(get("/draft-casefiles/{id}", id)
            .with(authentication(DraftCasefileHttpFixture.token(LOCAL_UNIT, CHECK_VALIDATE_DRAFT_CASEFILES)))
            .header("X-User-IP", "192.0.2.1"))
            .andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
    }

    private void assertIds(JsonNode body, DraftCasefileEntity... expected) {
        assertThat(body.get("count").longValue()).isEqualTo(expected.length);
        assertThat(body.get("summaries")).extracting(row -> row.get("draft_casefile_id").longValue())
            .containsExactlyInAnyOrder(Arrays.stream(expected)
                .map(DraftCasefileEntity::getDraftCasefileId).toArray(Long[]::new));
    }

    private void assertCountOnly(JsonNode body, long expected) {
        assertThat(body.propertyNames()).containsExactly("count");
        assertThat(body.get("count").longValue()).isEqualTo(expected);
    }

    private String publicationSnapshot(boolean published) {
        ObjectNode snapshot = (ObjectNode) JSON.readTree(SNAPSHOT);
        if (published) {
            setIdentity((ObjectNode) snapshot.get("respondent_account"), 101L, "R101");
            setIdentity((ObjectNode) snapshot.get("applicant_account"), 201L, "A201");
            setIdentity((ObjectNode) snapshot.at("/minor_creditor_accounts/0"), 301L, "M301");
            setIdentity((ObjectNode) snapshot.at("/minor_creditor_accounts/1"), 302L, "M302");
        }
        return JSON.writeValueAsString(snapshot);
    }

    private void setIdentity(ObjectNode account, long id, String number) {
        account.put("account_id", id).put("account_number", number);
    }

    private void assertSnapshotIdentities(JsonNode snapshot, boolean published) {
        assertThat(snapshot.get("minor_creditor_accounts")).hasSize(2);
        assertThat(snapshot.at("/minor_creditor_accounts/0/creditor_sequence").intValue()).isEqualTo(7);
        assertThat(snapshot.at("/minor_creditor_accounts/1/creditor_sequence").intValue()).isEqualTo(23);
        for (String path : List.of("/respondent_account", "/applicant_account",
            "/minor_creditor_accounts/0", "/minor_creditor_accounts/1")) {
            JsonNode account = snapshot.at(path);
            assertThat(account.has("account_id")).isTrue();
            assertThat(account.has("account_number")).isTrue();
            if (published) {
                assertThat(account.get("account_id").longValue()).isPositive();
                assertThat(account.get("account_number").asString()).isNotBlank();
            } else {
                assertThat(account.get("account_id").isNull()).isTrue();
                assertThat(account.get("account_number").isNull()).isTrue();
            }
        }
    }
}
