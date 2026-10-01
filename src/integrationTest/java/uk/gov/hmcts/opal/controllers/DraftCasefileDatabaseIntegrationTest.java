package uk.gov.hmcts.opal.controllers;

import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.dao.InvalidDataAccessResourceUsageException;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.springframework.test.context.jdbc.Sql;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionTemplate;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.logging.integration.dto.PersonalDataProcessingLogDetails;
import uk.gov.hmcts.opal.logging.integration.service.LoggingService;
import uk.gov.hmcts.opal.mapper.DraftCasefileMapper;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.support.DraftCasefileHttpFixture;

import java.time.Clock;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.matchesPattern;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.test.context.jdbc.Sql.ExecutionPhase.AFTER_TEST_METHOD;
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
class DraftCasefileDatabaseIntegrationTest extends BaseIntegrationTest {

    private static final JsonMapper JSON = JsonMapper.builder().build();
    private static final Instant EXPECTED = Instant.parse("2026-10-01T12:00:00.123456Z");
    @Autowired
    private MockMvc mockMvc;
    @Autowired
    private EntityManager entityManager;
    @Autowired
    private PlatformTransactionManager transactionManager;
    @Autowired
    private JdbcTemplate jdbc;
    @MockitoSpyBean
    private DraftCasefileRepository repository;
    @MockitoSpyBean
    private DraftCasefileMapper mapper;
    @MockitoBean
    private LoggingService logging;
    @MockitoBean
    private Clock clock;
    private String validBody;

    @BeforeEach
    void setUp() throws Exception {
        validBody = DraftCasefileHttpFixture.requestBody();
        when(clock.instant()).thenReturn(Instant.parse("2026-10-01T12:00:00.123456789Z"));
        when(logging.personalDataAccessLogAsync(any())).thenReturn(true);
    }

    @Test
    void createsCommittedDraftWithUnchangedJsonDerivedDataAndAfterCommitLogs() throws Exception {
        AtomicInteger committedReads = new AtomicInteger();
        when(logging.personalDataAccessLogAsync(any())).thenAnswer(invocation -> {
            PersonalDataProcessingLogDetails details = invocation.getArgument(0);
            TransactionTemplate read = new TransactionTemplate(transactionManager);
            read.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
            read.executeWithoutResult(transaction -> {
                Long id = Long.valueOf(details.getIndividuals().getFirst().getIdentifier());
                assertThat(repository.findById(id)).isPresent();
                assertThat(details.getCreatedAt().toInstant()).isEqualTo(EXPECTED);
                assertThat(details.getCreatedBy().getIdentifier()).isEqualTo("123");
                committedReads.incrementAndGet();
            });
            return true;
        });
        // Explicit flush proves PostgreSQL mappings/constraints inside the actual service transaction.
        doAnswer(invocation -> {
            entityManager.flush();
            return invocation.callRealMethod();
        }).when(mapper).toResponse(any());
        JsonNode response = submit(validBody.replace("100.00", "arbitrary named string"));
        assertThat(committedReads).hasValue(2);
        verify(logging, times(2)).personalDataAccessLogAsync(any());
        verify(clock).instant();
        Long id = response.get("draft_casefile_id").longValue();
        DraftCasefileEntity row = repository.findById(id).orElseThrow();
        assertThat(JSON.readTree(row.getCasefile()))
            .isEqualTo(JSON.readTree(validBody.replace("100.00", "arbitrary named string")).get("casefile"));
        assertThat(row.getSubmittedBy()).isEqualTo("BUU-1");
        assertThat(row.getSubmittedByName()).isEqualTo("Synthetic Submitter");
        assertThat(row.getBusinessUnitId()).isEqualTo((short) 1);
        assertThat(row.getCasefileType()).isEqualTo("REMO In");
        assertThat(row.getCreatedDate().toInstant(ZoneOffset.UTC)).isEqualTo(EXPECTED);
        assertThat(row.getCasefileStatusDate()).isEqualTo(row.getCreatedDate());
        assertThat(row.getValidatedDate()).isNull();
        assertThat(row.getValidatedBy()).isNull();
        assertThat(row.getAccountId()).isNull();
        assertThat(row.getAccountNumber()).isNull();
        assertThat(JSON.readTree(row.getTimelineData())).isEqualTo(response.get("timeline_data"));
        assertThat(JSON.readTree(row.getCasefileSnapshot())).isEqualTo(response.get("casefile_snapshot"));
        assertThat(response.get("submitted_by").stringValue()).isEqualTo("BUU-1");
        for (String path : new String[] {"/created_date", "/casefile_status_date", "/timeline_data/0/status_date"}) {
            assertThat(OffsetDateTime.parse(response.at(path).stringValue()).toInstant()).isEqualTo(EXPECTED);
        }
        for (String account : new String[] {"respondent_account", "applicant_account"}) {
            JsonNode snapshot = response.at("/casefile_snapshot/" + account);
            assertThat(snapshot.has("account_id")).isTrue();
            assertThat(snapshot.get("account_id").isNull()).isTrue();
            assertThat(snapshot.has("account_number")).isTrue();
            assertThat(snapshot.get("account_number").isNull()).isTrue();
        }
        assertThat(response.at("/casefile_snapshot/respondent_account/respondent_name").stringValue())
            .isEqualTo("EXAMPLE");
        assertThat(response.get("casefile_snapshot").toString())
            .doesNotContain("status", "timeline", "submitted", "created");
    }

    @Test
    void deniesMissingBusinessUnitIdentityWithoutRowOrLog() throws Exception {
        mockMvc.perform(post("/draft-casefiles").with(authentication(DraftCasefileHttpFixture.token((short) 2)))
            .contentType(MediaType.APPLICATION_JSON).content(validBody)).andExpect(status().isForbidden());
        assertNoDraftOrLog();
    }

    @Test
    void rejectsBadReferenceWithoutRowOrLog(CapturedOutput output) throws Exception {
        String response = mockMvc.perform(post("/draft-casefiles")
                .with(authentication(DraftCasefileHttpFixture.token((short) 1)))
                .contentType(MediaType.APPLICATION_JSON).content(validBody.replace("TEST", "PRIVATE")))
            .andExpect(status().isBadRequest()).andExpect(jsonPath("$.title").value("Bad Request"))
            .andReturn().getResponse().getContentAsString();
        assertNoDraftOrLog();
        assertThat(response).doesNotContain("PRIVATE", "Synthetic address");
        assertThat(output).doesNotContain("PRIVATE", "Synthetic address");
    }

    @ParameterizedTest
    @ValueSource(booleans = {false, true})
    void rollsBackSavedRowWhenPersistenceFails(boolean unavailable) throws Exception {
        doAnswer(invocation -> {
            repository.saveAndFlush(invocation.getArgument(0));
            assertThat(jdbc.queryForObject(
                "SELECT count(*) FROM draft_casefiles WHERE business_unit_id=1", Integer.class))
                .isEqualTo(1);
            if (unavailable) {
                throw new DataAccessResourceFailureException("Synthetic unavailable database");
            }
            throw new InvalidDataAccessResourceUsageException("Synthetic persistence failure");
        }).when(repository).save(any());
        mockMvc.perform(post("/draft-casefiles").with(authentication(DraftCasefileHttpFixture.token((short) 1)))
                .contentType(MediaType.APPLICATION_JSON).content(validBody))
            .andExpect(status().is(unavailable ? 503 : 500));
        assertNoDraftOrLog();
    }

    @Test
    void commitConstraintFailureRollsBackAndSuppressesAfterCommitLogging() throws Exception {
        String body = validBody.replace("\"business_unit_id\":1", "\"business_unit_id\":2");
        mockMvc.perform(post("/draft-casefiles").with(authentication(DraftCasefileHttpFixture.token((short) 2)))
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isConflict());
        assertNoDraftOrLog();
    }

    @ParameterizedTest
    @ValueSource(booleans = {false, true})
    void loggingFailureStillReturnsCreatedWithCommittedRow(boolean throwsException, CapturedOutput output)
        throws Exception {
        if (throwsException) {
            when(logging.personalDataAccessLogAsync(any()))
                .thenThrow(new IllegalStateException("SYNTHETIC_PRIVATE_PUBLISHER_VALUE"));
        } else {
            when(logging.personalDataAccessLogAsync(any())).thenReturn(false);
        }
        JsonNode response = submit(validBody);
        assertThat(repository.findById(response.get("draft_casefile_id").longValue())).isPresent();
        verify(logging, times(2)).personalDataAccessLogAsync(any());
        assertThat(output).doesNotContain("SYNTHETIC_PRIVATE_PUBLISHER_VALUE", "Synthetic address");
    }

    private JsonNode submit(String body) throws Exception {
        String response = mockMvc.perform(post("/draft-casefiles")
                .with(authentication(DraftCasefileHttpFixture.token((short) 1)))
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isCreated())
            .andExpect(header().string("Location", matchesPattern("/draft-casefiles/[0-9]+")))
            .andExpect(jsonPath("$.casefile_status").value("SUBMITTED"))
            .andExpect(jsonPath("$.timeline_data.length()").value(1))
            .andExpect(jsonPath("$.casefile").doesNotExist())
            .andReturn().getResponse().getContentAsString();
        return JSON.readTree(response);
    }

    private void assertNoDraftOrLog() {
        assertThat(repository.count()).isZero();
        verifyNoInteractions(logging);
    }
}
