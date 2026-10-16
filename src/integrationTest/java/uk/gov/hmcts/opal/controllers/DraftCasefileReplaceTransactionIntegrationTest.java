package uk.gov.hmcts.opal.controllers;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionTemplate;
import uk.gov.hmcts.opal.service.DraftCasefileService;
import uk.gov.hmcts.opal.mapper.DraftCasefileGetMapper;
import uk.gov.hmcts.opal.generated.model.DraftCasefileReplaceRequest;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
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
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.logging.integration.dto.PersonalDataProcessingLogDetails;
import uk.gov.hmcts.opal.logging.integration.service.LoggingService;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.support.DraftCasefileHttpFixture;

import java.time.Clock;
import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.test.context.jdbc.Sql.ExecutionPhase.AFTER_TEST_METHOD;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
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
class DraftCasefileReplaceTransactionIntegrationTest extends BaseIntegrationTest {

    private static final JsonMapper JSON = JsonMapper.builder().build();
    private static final String PRIVATE = "SYNTHETIC_PRIVATE_REPLACE_VALUE";
    private static final Instant NOW = Instant.parse("2026-10-09T10:00:00.123456789Z");
    @Autowired
    private MockMvc mockMvc;
    @Autowired
    private JdbcTemplate jdbc;
    @MockitoSpyBean
    private DraftCasefileRepository repository;
    @Autowired
    private DraftCasefileService service;
    @Autowired
    private PlatformTransactionManager transactionManager;
    @MockitoSpyBean
    private DraftCasefileGetMapper getMapper;
    @MockitoBean
    private Clock clock;
    @MockitoBean
    private LoggingService logging;

    @BeforeEach
    void setUp() {
        when(clock.instant()).thenReturn(NOW);
        when(logging.personalDataAccessLogAsync(any())).thenReturn(true);
    }

    @Test
    void onlyOneOfTwoWritersCanCommitTheSameRejectedVersion() throws Exception {
        final long id = rejectedDraft();
        final var body = replacement();
        var request = new DraftCasefileReplaceRequest().businessUnitId((short) 1).casefile(body.get("casefile"));
        CountDownLatch reads = new CountDownLatch(2);
        AtomicInteger intercepted = new AtomicInteger();
        doAnswer(invocation -> {
            Object result = org.mockito.Mockito.mockingDetails(repository).getMockCreationSettings()
                .getDefaultAnswer().answer(invocation);
            if (intercepted.incrementAndGet() <= 2) {
                reads.countDown();
                assertThat(reads.await(10, TimeUnit.SECONDS)).isTrue();
            }
            return result;
        }).when(repository).findById(id);
        ExecutorService executor = Executors.newFixedThreadPool(2);
        try {
            Callable<RuntimeException> writer = () -> {
                SecurityContextHolder.getContext().setAuthentication(DraftCasefileHttpFixture.token((short) 1));
                try {
                    service.replaceDraftCasefile(id, request, "\"4\"");
                    return null;
                } catch (RuntimeException exception) {
                    return exception;
                } finally {
                    SecurityContextHolder.clearContext();
                }
            };
            var first = executor.submit(writer);
            var second = executor.submit(writer);
            RuntimeException firstResult = first.get(20, TimeUnit.SECONDS);
            RuntimeException secondResult = second.get(20, TimeUnit.SECONDS);
            assertThat(java.util.Arrays.asList(firstResult, secondResult))
                .filteredOn(value -> value == null).hasSize(1);
            assertThat(firstResult == null ? secondResult : firstResult)
                .isInstanceOf(org.springframework.orm.ObjectOptimisticLockingFailureException.class);
        } finally {
            executor.shutdownNow();
            assertThat(executor.awaitTermination(10, TimeUnit.SECONDS)).isTrue();
        }
        Map<String, Object> saved = row(id);
        assertThat(saved.get("version_number")).isEqualTo(5L);
        assertThat(((JsonNode) saved.get("timeline_data")).size()).isEqualTo(3);
        verify(logging, times(2)).personalDataAccessLogAsync(any());
        clearInvocations(logging);
        mockMvc.perform(request(id, body).with(authentication(DraftCasefileHttpFixture.token((short) 1))))
            .andExpect(status().isConflict());
        assertThat(row(id)).isEqualTo(saved);
        verifyNoInteractions(logging);
    }

    @Test
    void mapperFailureAfterRealFlushRollsBackEveryColumnAndEmitsNoAudit() throws Exception {
        long id = rejectedDraft();
        final Map<String, Object> before = row(id);
        AtomicInteger flushes = new AtomicInteger();
        doAnswer(invocation -> {
            Object saved = org.mockito.Mockito.mockingDetails(repository).getMockCreationSettings()
                .getDefaultAnswer().answer(invocation);
            flushes.incrementAndGet();
            return saved;
        }).when(repository).saveAndFlush(any());
        doThrow(new IllegalStateException(PRIVATE)).when(getMapper).toResponse(any());
        mockMvc.perform(request(id, replacement()).with(authentication(DraftCasefileHttpFixture.token((short) 1))))
            .andExpect(status().isInternalServerError());
        assertThat(flushes).hasValue(1);
        assertThat(row(id)).isEqualTo(before);
        verifyNoInteractions(logging);
    }

    @Test
    void enclosingRollbackDiscardsTheSuccessfulReplacementAndItsAuditEvent() throws Exception {
        final long id = rejectedDraft();
        final Map<String, Object> before = row(id);
        ObjectNode body = replacement();
        var request = new DraftCasefileReplaceRequest().businessUnitId((short) 1).casefile(body.get("casefile"));
        SecurityContextHolder.getContext().setAuthentication(DraftCasefileHttpFixture.token((short) 1));
        try {
            new TransactionTemplate(transactionManager).executeWithoutResult(transaction -> {
                assertThat(service.replaceDraftCasefile(id, request, "\"4\"").version()).isEqualTo(5L);
                verifyNoInteractions(logging);
                transaction.setRollbackOnly();
            });
        } finally {
            SecurityContextHolder.clearContext();
        }
        assertThat(row(id)).isEqualTo(before);
        verifyNoInteractions(logging);
    }

    @ParameterizedTest
    @ValueSource(booleans = {false, true})
    void loggingFailurePreservesHttpSuccessAndSeesCommittedReplacement(boolean throwsException, CapturedOutput output)
        throws Exception {
        final long id = rejectedDraft();
        final int outputStart = output.getAll().length();
        AtomicInteger committedReads = new AtomicInteger();
        when(logging.personalDataAccessLogAsync(any())).thenAnswer(invocation -> {
            PersonalDataProcessingLogDetails payload = invocation.getArgument(0);
            TransactionTemplate read = new TransactionTemplate(transactionManager);
            read.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
            read.executeWithoutResult(transaction -> {
                var saved = repository.findById(id).orElseThrow();
                assertThat(saved.getCasefileStatus()).isEqualTo(DraftCasefileStatus.RESUBMITTED);
                assertThat(saved.getVersionNumber()).isEqualTo(5L);
                assertThat(payload.getIndividuals().getFirst().getIdentifier()).isEqualTo(Long.toString(id));
                committedReads.incrementAndGet();
            });
            assertThat(JSON.writeValueAsString(payload))
                .doesNotContain(PRIVATE, "Synthetic address", "Synthetic", "SYNTH_BANK", "12345678", "654321");
            if (throwsException) {
                throw new IllegalStateException(PRIVATE);
            }
            return false;
        });
        ObjectNode body = replacement();
        ((ObjectNode) body.at("/casefile/respondent_account/respondent/party_details/individual_details"))
            .put("surname", PRIVATE);
        ((ObjectNode) body.at("/casefile/applicant/party_details/address")).put("address_line_1", PRIVATE);
        ((ObjectNode) body.at("/casefile/respondent_account/respondent/party_details"))
            .putObject("contact_details").put("main_telephone_number", PRIVATE);
        ObjectNode debtor = ((ObjectNode) body.at("/casefile/respondent_account/respondent"))
            .putObject("debtor_details").put("employer_name", PRIVATE);
        debtor.set("employer_address", body.at("/casefile/applicant/party_details/address").deepCopy());
        ((ObjectNode) body.at("/casefile/applicant")).set("bank_account_details", JSON.readTree("""
            {"bank_account_type":"UK Bank","uk_bank_details":{"account_name":"SYNTH_BANK",
             "sort_code":"654321","account_number":"12345678","payment_reference":"SYNTH_BANK"}}
            """));
        mockMvc.perform(request(id, body).with(authentication(DraftCasefileHttpFixture.token((short) 1))))
            .andExpect(status().isOk()).andExpect(header().string("ETag", "\"5\""));
        assertThat(committedReads).hasValue(3);
        assertThat(row(id).get("version_number")).isEqualTo(5L);
        assertThat(output.getAll().substring(outputStart))
            .doesNotContain(PRIVATE, "Synthetic address", "SYNTH_BANK", "12345678", "654321");
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

}
