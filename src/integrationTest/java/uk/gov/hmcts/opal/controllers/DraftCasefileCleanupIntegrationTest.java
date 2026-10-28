package uk.gov.hmcts.opal.controllers;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.junit.jupiter.api.BeforeEach;
import org.mockito.stubbing.Answer;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.EnumSource;
import org.junit.jupiter.params.provider.MethodSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.springframework.test.context.jdbc.Sql;
import org.springframework.test.context.jdbc.SqlMergeMode;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.transaction.support.TransactionTemplate;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.common.spring.security.OpalJwtAuthenticationToken;
import uk.gov.hmcts.opal.common.user.authorisation.model.Permission;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.logging.integration.service.LoggingService;
import uk.gov.hmcts.opal.repository.CountryRepository;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.repository.MaintenanceApplicationRepository;
import uk.gov.hmcts.opal.repository.ResultRepository;
import uk.gov.hmcts.opal.support.DraftCasefileHttpFixture;

import java.sql.PreparedStatement;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Set;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.stream.Stream;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.mockingDetails;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.test.context.jdbc.Sql.ExecutionPhase.AFTER_TEST_METHOD;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
@TestPropertySource(properties = {
    "spring.flyway.locations=classpath:db/migration/ddl",
    "opal.redis.enabled=false", "management.health.redis.enabled=false",
    "opal.testing-support-endpoints.enabled=true",
})
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@Sql({"/draft-casefile/reference-fixtures.sql", "/draft-casefile/cleanup-scope-fixtures.sql"})
@Sql(scripts = "/draft-casefile/cleanup-scope-cleanup.sql", executionPhase = AFTER_TEST_METHOD)
class DraftCasefileCleanupIntegrationTest extends BaseIntegrationTest {

    private static final String RUN = "E2E-0123456789abcdef";
    private static final String CLEANUP = "/testing-support/draft-casefiles/{id}";
    @Autowired
    private ObjectMapper objectMapper;
    @Autowired
    private MockMvc mockMvc;
    @Autowired
    private JdbcTemplate jdbc;
    @Autowired
    private CountryRepository countries;
    @Autowired
    private MaintenanceApplicationRepository applications;
    @Autowired
    private ResultRepository results;
    @Autowired
    private PlatformTransactionManager transactionManager;
    @MockitoSpyBean
    private DraftCasefileRepository repository;
    @MockitoBean
    private LoggingService logging;

    private Answer<?> repositoryDelegate;

    @BeforeEach
    void setUp() {
        when(logging.personalDataAccessLogAsync(any())).thenReturn(true);
        // Spring Data exposes abstract proxy methods; preserve the spy's real repository delegate.
        repositoryDelegate = mockingDetails(repository).getMockCreationSettings().getDefaultAnswer();
    }

    @ParameterizedTest
    @EnumSource(value = DraftCasefileStatus.class,
        names = {"SUBMITTED", "REJECTED", "RESUBMITTED", "DELETED", "PUBLISHING_FAILED"})
    void realSubmissionIsDeletedWithEmbeddedDataAndRepeatSucceeds(DraftCasefileStatus lifecycle) throws Exception {
        long id = lifecycleDraft(lifecycle);
        long otherId = submit("E2E-fedcba9876543210");
        DraftCasefileEntity before = repository.findById(id).orElseThrow();
        assertThat(before.getCasefile()).contains("Synthetic cleanup note", "Synthetic cleanup comment");
        assertThat(before.getCasefileSnapshot()).contains("respondent_account", "applicant_account");
        assertThat(before.getTimelineData()).contains("Submitted");
        cleanup(id, RUN).andExpect(status().isNoContent()).andExpect(content().string(""));
        cleanup(id, RUN).andExpect(status().isNoContent());
        assertThat(repository.findById(id)).isEmpty();
        assertThat(repository.findById(otherId)).isPresent();
        assertThat(countries.findById(5000000301L)).isPresent();
        assertThat(applications.findById((short) 31020)).isPresent();
        assertThat(results.findById("MAT")).isPresent();
    }

    @Test
    void minorCreditorEmbeddedSnapshotIsDeleted() throws Exception {
        long id = submit(RUN, true);
        JsonNode minor = objectMapper.readTree(repository.findById(id).orElseThrow().getCasefileSnapshot())
            .at("/minor_creditor_accounts/0");
        assertThat(minor.isObject()).isTrue();
        assertThat(minor.get("account_id").isNull()).isTrue();
        assertThat(minor.get("account_number").isNull()).isTrue();
        cleanup(id, RUN).andExpect(status().isNoContent());
        assertThat(repository.findById(id)).isEmpty();
    }

    @ParameterizedTest
    @EnumSource(value = DraftCasefileStatus.class,
        names = {"SUBMITTED", "REJECTED", "RESUBMITTED", "DELETED", "PUBLISHING_FAILED"})
    void postFlushFailureRestoresWholeDraftAndAllowsRetry(DraftCasefileStatus lifecycle) throws Exception {
        long id = lifecycleDraft(lifecycle);
        DraftCasefileEntity before = repository.findById(id).orElseThrow();
        submit("E2E-fedcba9876543210");
        List<DraftCasefileEntity> beforeRows = repository.findAll();
        doAnswer(invocation -> {
            repositoryDelegate.answer(invocation);
            throw new DataAccessResourceFailureException("Synthetic failure");
        }).when(repository).flush();
        try {
            cleanup(id, RUN).andExpect(status().isServiceUnavailable());
            assertUnchanged(before);
            assertRowsUnchanged(beforeRows);
        } finally {
            doAnswer(repositoryDelegate).when(repository).flush();
        }
        cleanup(id, RUN).andExpect(status().isNoContent());
        assertThat(repository.findById(id)).isEmpty();
    }

    @ParameterizedTest
    @ValueSource(strings = {"0", "-1", "not-a-number", "9223372036854775808"})
    void rejectsInvalidId(String id) throws Exception {
        DraftCasefileEntity before = repository.findById(submit(RUN)).orElseThrow();
        mockMvc.perform(delete("/testing-support/draft-casefiles/" + id)
                .with(authentication(DraftCasefileHttpFixture.token((short) 1)))
                .header("Test-Run-Reference", RUN))
            .andExpect(status().isBadRequest())
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
            .andExpect(jsonPath("$.status").value(400));
        assertUnchanged(before);
    }

    @ParameterizedTest
    @ValueSource(strings = {"MISSING", "", "E2E-0123456789ABCDEF", "e2e-0123456789abcdef",
        "E2E-0123456789abcde", "E2E-0123456789abcdef0"})
    void rejectsInvalidHeader(String marker) throws Exception {
        DraftCasefileEntity before = repository.findById(submit(RUN)).orElseThrow();
        var request = delete(CLEANUP, before.getDraftCasefileId())
            .with(authentication(DraftCasefileHttpFixture.token((short) 1)));
        if (!marker.equals("MISSING")) {
            request.header("Test-Run-Reference", marker);
        }
        mockMvc.perform(request).andExpect(status().isBadRequest())
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
            .andExpect(jsonPath("$.status").value(400));
        assertUnchanged(before);
    }

    @ParameterizedTest
    @EnumSource(value = DraftCasefileStatus.class,
        names = {"SUBMITTED", "REJECTED", "RESUBMITTED", "DELETED", "PUBLISHING_FAILED"})
    void rejectsDifferentRunWithoutChangingDraft(DraftCasefileStatus lifecycle) throws Exception {
        DraftCasefileEntity before = repository.findById(lifecycleDraft(lifecycle)).orElseThrow();
        submit("E2E-fedcba9876543210");
        List<DraftCasefileEntity> beforeRows = repository.findAll();
        cleanup(before.getDraftCasefileId(), "E2E-fedcba9876543210").andExpect(status().isForbidden());
        assertRowsUnchanged(beforeRows);
        assertUnchanged(before);
    }

    @ParameterizedTest
    @ValueSource(strings = {"missing-permission", "checker", "wrong-bu", "wrong-user", "wrong-buu"})
    void rejectsUnauthorisedIdentityForExistingDraft(String variant) throws Exception {
        DraftCasefileEntity before = repository.findById(submit(RUN)).orElseThrow();
        Set<Permission> permissions = switch (variant) {
            case "missing-permission" -> Set.of();
            case "checker" -> Set.of(new Permission(22L, "Check and validate draft Casefiles"));
            default -> Set.of(new Permission(21L, "Create and Manage Draft Casefiles"));
        };
        OpalJwtAuthenticationToken caller = DraftCasefileHttpFixture.token(
            (short) (variant.equals("wrong-bu") ? 2 : 1), variant.equals("wrong-user") ? 124L : 123L,
            (variant.equals("wrong-buu") || variant.equals("wrong-user")) ? "BUU-OTHER" : "BUU-1", permissions);
        mockMvc.perform(delete(CLEANUP, before.getDraftCasefileId()).with(authentication(caller))
                .header("Test-Run-Reference", RUN)).andExpect(status().isForbidden());
        assertUnchanged(before);
    }

    @Test
    void authenticatedRepeatSucceedsWithoutBusinessUnitPermissions() throws Exception {
        var caller = DraftCasefileHttpFixture.token((short) 1, 124L, "BUU-OTHER", Set.of());
        mockMvc.perform(delete(CLEANUP, Long.MAX_VALUE).with(authentication(caller))
                .header("Test-Run-Reference", RUN)).andExpect(status().isNoContent());
    }

    @Test
    void anotherOwnerCanCleanTheirOwnDraftInAnotherBusinessUnit() throws Exception {
        DraftCasefileEntity original = repository.findById(submit(RUN)).orElseThrow();
        var other = repository.saveAndFlush(original.toBuilder()
            .businessUnitId((short) 2).submittedBy("BUU-2").build());
        var caller = DraftCasefileHttpFixture.token((short) 2, 124L, "BUU-2",
            Set.of(new Permission(21L, "Create and Manage Draft Casefiles")));
        mockMvc.perform(delete(CLEANUP, other.getDraftCasefileId()).with(authentication(caller))
                .header("Test-Run-Reference", RUN)).andExpect(status().isNoContent());
        assertThat(repository.findById(other.getDraftCasefileId())).isEmpty();
    }

    @ParameterizedTest
    @ValueSource(strings = {"bu", "submitter", "missing-marker", "wrong-marker", "numeric-marker", "scalar"})
    void rejectsStoredOwnershipMismatch(String variant) throws Exception {
        DraftCasefileEntity original = repository.findById(submit(RUN)).orElseThrow();
        ObjectNode payload = (ObjectNode) objectMapper.readTree(original.getCasefile());
        ObjectNode account = (ObjectNode) payload.get("respondent_account");
        switch (variant) {
            case "missing-marker" -> account.remove("remo_reference");
            case "wrong-marker" -> account.put("remo_reference", "E2E-fedcba9876543210");
            case "numeric-marker" -> account.put("remo_reference", 123);
            default -> { }
        }
        DraftCasefileEntity before = repository.saveAndFlush(original.toBuilder()
            .businessUnitId((short) (variant.equals("bu") ? 2 : 1))
            .submittedBy(variant.equals("submitter") ? "BUU-OTHER" : "BUU-1")
            .casefile(variant.equals("scalar") ? "\"synthetic\"" : objectMapper.writeValueAsString(payload)).build());
        submit("E2E-fedcba9876543210");
        List<DraftCasefileEntity> beforeRows = repository.findAll();
        cleanup(before.getDraftCasefileId(), RUN).andExpect(status().isForbidden());
        assertRowsUnchanged(beforeRows);
        assertUnchanged(before);
    }

    @ParameterizedTest
    @EnumSource(value = DraftCasefileStatus.class, names = {"PUBLISHING_PENDING", "PUBLISHED"})
    void rejectsPublicationLifecycle(DraftCasefileStatus lifecycle) throws Exception {
        DraftCasefileEntity original = repository.findById(submit(RUN)).orElseThrow();
        DraftCasefileEntity before = repository.saveAndFlush(original.toBuilder().casefileStatus(lifecycle).build());
        submit("E2E-fedcba9876543210");
        List<DraftCasefileEntity> beforeRows = repository.findAll();
        cleanup(before.getDraftCasefileId(), RUN).andExpect(status().isConflict());
        assertRowsUnchanged(beforeRows);
        assertUnchanged(before);
    }

    @ParameterizedTest
    @ValueSource(strings = {"validated-date", "validated-by", "validated-name"})
    void rejectsValidationOrPublicationMetadata(String variant) throws Exception {
        DraftCasefileEntity original = repository.findById(submit(RUN)).orElseThrow();
        var builder = original.toBuilder();
        switch (variant) {
            case "validated-date" -> builder.validatedDate(LocalDateTime.of(2026, 10, 1, 12, 0));
            case "validated-by" -> builder.validatedBy("BUU-1");
            case "validated-name" -> builder.validatedByName("Synthetic validator");
            default -> throw new IllegalArgumentException(variant);
        }
        DraftCasefileEntity before = repository.saveAndFlush(builder.build());
        submit("E2E-fedcba9876543210");
        List<DraftCasefileEntity> beforeRows = repository.findAll();
        cleanup(before.getDraftCasefileId(), RUN).andExpect(status().isConflict());
        assertRowsUnchanged(beforeRows);
        assertUnchanged(before);
    }

    @ParameterizedTest
    @EnumSource(value = DraftCasefileStatus.class,
        names = {"SUBMITTED", "REJECTED", "RESUBMITTED", "DELETED", "PUBLISHING_FAILED"})
    @SqlMergeMode(SqlMergeMode.MergeMode.MERGE)
    @Sql("/draft-casefile/cleanup-account-link-fixture.sql")
    void rejectsPublishedAccountIdAndPreservesLinkedAccount(DraftCasefileStatus lifecycle) throws Exception {
        DraftCasefileEntity original = repository.findById(lifecycleDraft(lifecycle)).orElseThrow();
        DraftCasefileEntity before = repository.saveAndFlush(original.toBuilder().accountId(9000000301L).build());
        submit("E2E-fedcba9876543210");
        List<DraftCasefileEntity> beforeRows = repository.findAll();
        cleanup(before.getDraftCasefileId(), RUN).andExpect(status().isConflict());
        assertRowsUnchanged(beforeRows);
        assertUnchanged(before);
        assertThat(linkedAccountCount()).isEqualTo(1);
    }

    @ParameterizedTest
    @EnumSource(value = DraftCasefileStatus.class,
        names = {"SUBMITTED", "REJECTED", "RESUBMITTED", "DELETED", "PUBLISHING_FAILED"})
    void rejectsRowAccountNumber(DraftCasefileStatus lifecycle) throws Exception {
        DraftCasefileEntity original = repository.findById(lifecycleDraft(lifecycle)).orElseThrow();
        DraftCasefileEntity before = repository.saveAndFlush(original.toBuilder().accountNumber("SYNTHETIC-1").build());
        submit("E2E-fedcba9876543210");
        List<DraftCasefileEntity> beforeRows = repository.findAll();
        cleanup(before.getDraftCasefileId(), RUN).andExpect(status().isConflict());
        assertRowsUnchanged(beforeRows);
        assertUnchanged(before);
    }

    @ParameterizedTest
    @ValueSource(strings = {"REJECTED", "DELETED"})
    void actualCheckerDecisionCanBeCleanedWithoutChangingSibling(String decision) throws Exception {
        long id = submit(RUN);
        final DraftCasefileEntity sibling = repository.findById(submit("E2E-fedcba9876543210")).orElseThrow();
        Long version = repository.findById(id).orElseThrow().getVersionNumber();
        var checker = DraftCasefileHttpFixture.token((short) 1, 124L, "BUU-CHECKER",
            Set.of(new Permission(22L, "Check and validate draft Casefiles")));
        mockMvc.perform(patch("/draft-casefiles/{id}", id).with(authentication(checker))
                .header("If-Match", "\"" + version + "\"").contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.createObjectNode().put("business_unit_id", 1)
                    .put("casefile_status", decision).put("status_message", "Synthetic cleanup decision").toString()))
            .andExpect(status().isOk()).andExpect(jsonPath("$.casefile_status").value(decision));
        cleanup(id, RUN).andExpect(status().isNoContent());
        assertThat(repository.findById(id)).isEmpty();
        assertUnchanged(sibling);
    }

    // No account repository exists; this bounded query verifies the database-facing fixture is untouched.
    private int linkedAccountCount() {
        return jdbc.queryForObject("SELECT count(*) FROM respondent_accounts WHERE respondent_account_id = ?",
            Integer.class, 9000000301L);
    }

    @ParameterizedTest
    @MethodSource("snapshotLinkCases")
    void rejectsEverySnapshotAccountLink(DraftCasefileStatus lifecycle, String path) throws Exception {
        long id = submit(RUN, true);
        setLifecycle(id, lifecycle);
        for (String field : new String[] {"account_id", "account_number"}) {
            DraftCasefileEntity original = repository.findById(id).orElseThrow();
            ObjectNode snapshot = (ObjectNode) objectMapper.readTree(original.getCasefileSnapshot());
            ObjectNode account = (ObjectNode) snapshot.at("/" + path
                + (path.equals("minor_creditor_accounts") ? "/0" : ""));
            if (field.equals("account_id")) {
                account.put(field, 1L);
            } else {
                account.putNull("account_id");
                account.put(field, "SYNTHETIC-1");
            }
            final DraftCasefileEntity before = repository.saveAndFlush(original.toBuilder()
                .casefileSnapshot(objectMapper.writeValueAsString(snapshot)).build());
            submit("E2E-fedcba9876543210");
            List<DraftCasefileEntity> beforeRows = repository.findAll();
            cleanup(id, RUN).andExpect(status().isConflict());
            assertRowsUnchanged(beforeRows);
            assertUnchanged(before);
        }
    }

    @ParameterizedTest
    @ValueSource(strings = {"\"synthetic\"", "{}", "{\"minor_creditor_accounts\":{}}"})
    void rejectsMalformedSnapshot(String snapshot) throws Exception {
        DraftCasefileEntity original = repository.findById(submit(RUN)).orElseThrow();
        DraftCasefileEntity before = repository.saveAndFlush(original.toBuilder().casefileSnapshot(snapshot).build());
        submit("E2E-fedcba9876543210");
        List<DraftCasefileEntity> beforeRows = repository.findAll();
        cleanup(before.getDraftCasefileId(), RUN).andExpect(status().isConflict());
        assertRowsUnchanged(beforeRows);
        assertUnchanged(before);
    }

    @Test
    void missingDraftSucceedsForValidCaller() throws Exception {
        cleanup(Long.MAX_VALUE, RUN).andExpect(status().isNoContent());
    }

    @Test
    void anonymousCallerCannotDeleteDraft() throws Exception {
        DraftCasefileEntity before = repository.findById(submit(RUN)).orElseThrow();
        mockMvc.perform(delete(CLEANUP, before.getDraftCasefileId()).header("Test-Run-Reference", RUN))
            .andExpect(status().isUnauthorized());
        assertUnchanged(before);
    }

    @Test
    void authenticatedPublicationEvidenceRoutesAreAbsent() throws Exception {
        for (var request : new MockHttpServletRequestBuilder[]{
            post("/testing-support/draft-casefiles/1/publication-evidence"),
            get("/testing-support/draft-casefiles/1/publication-evidence")}) {
            mockMvc.perform(request.with(authentication(DraftCasefileHttpFixture.token((short) 1)))
                    .header("Test-Run-Reference", RUN))
                .andExpect(status().isNotFound());
        }
    }

    @Test
    void runtimeDocumentationIncludesConditionalDeleteContract() throws Exception {
        String body = mockMvc.perform(get("/v3/api-docs")).andExpect(status().isOk())
            .andReturn().getResponse().getContentAsString();
        assertThat(objectMapper.readTree(body).path("paths")
            .has("/testing-support/draft-casefiles/{draft_casefile_id}/publication-evidence")).isFalse();
        JsonNode operation = objectMapper.readTree(body)
            .at("/paths/~1testing-support~1draft-casefiles~1{draft_casefile_id}/delete");
        assertThat(operation.isObject()).isTrue();
        assertThat(operation.get("responses").has("204")).isTrue();
        assertThat(operation.get("security").isArray()).isTrue();
        assertThat(operation.get("security").isEmpty()).isFalse();
        JsonNode marker = null;
        for (JsonNode parameter : operation.get("parameters")) {
            if (parameter.path("name").asText().equals("Test-Run-Reference")) {
                marker = parameter;
            }
        }
        assertThat(marker).isNotNull();
        assertThat(marker.path("required").asBoolean()).isTrue();
        assertThat(marker.at("/schema/pattern").asText()).isEqualTo("^E2E-[0-9a-f]{16}$");
    }

    @Test
    void simultaneousRepeatsBothSucceed() throws Exception {
        long id = submit(RUN);
        ExecutorService executor = Executors.newFixedThreadPool(2);
        CountDownLatch start = new CountDownLatch(1);
        try {
            Future<Integer> first = executor.submit(() -> concurrentCleanup(id, start));
            Future<Integer> second = executor.submit(() -> concurrentCleanup(id, start));
            start.countDown();
            assertThat(first.get(10, TimeUnit.SECONDS)).isEqualTo(204);
            assertThat(second.get(10, TimeUnit.SECONDS)).isEqualTo(204);
            assertThat(repository.findById(id)).isEmpty();
        } finally {
            start.countDown();
            executor.shutdownNow();
        }
    }

    @ParameterizedTest
    @EnumSource(value = DraftCasefileStatus.class, names = {"PUBLISHING_PENDING", "PUBLISHED"})
    void cleanupWaitsForLockedLifecycleUpdateAndRejectsCommittedState(DraftCasefileStatus lifecycle) throws Exception {
        long id = submit(RUN);
        ExecutorService executor = Executors.newFixedThreadPool(2);
        CountDownLatch locked = new CountDownLatch(1);
        CountDownLatch release = new CountDownLatch(1);
        CountDownLatch cleanupLookup = new CountDownLatch(1);
        final AtomicInteger writerPid = new AtomicInteger();
        final AtomicInteger cleanupPid = new AtomicInteger();
        doAnswer(invocation -> {
            if (Thread.currentThread().getName().equals("synthetic-cleanup-reader")) {
                cleanupPid.set(transactionBackendPid());
                cleanupLookup.countDown();
            }
            return repositoryDelegate.answer(invocation);
        }).when(repository).findForCleanupById(id);
        try {
            final Future<?> writer = executor.submit(() -> new TransactionTemplate(transactionManager)
                .executeWithoutResult(transaction -> {
                    writerPid.set(transactionBackendPid());
                    DraftCasefileEntity draft = repository.findForCleanupById(id).orElseThrow();
                    repository.saveAndFlush(draft.toBuilder().casefileStatus(lifecycle).build());
                    locked.countDown();
                    await(release);
                }));
            assertThat(locked.await(5, TimeUnit.SECONDS)).isTrue();
            final Future<Integer> reader = executor.submit(() -> {
                Thread.currentThread().setName("synthetic-cleanup-reader");
                return cleanup(id, RUN).andReturn().getResponse().getStatus();
            });
            assertThat(cleanupLookup.await(5, TimeUnit.SECONDS)).isTrue();
            awaitBlockedCleanupSelect(cleanupPid.get(), writerPid.get());
            release.countDown();
            writer.get(10, TimeUnit.SECONDS);
            assertThat(reader.get(10, TimeUnit.SECONDS)).isEqualTo(409);
            assertThat(repository.findById(id).orElseThrow().getCasefileStatus())
                .isEqualTo(lifecycle);
        } finally {
            release.countDown();
            executor.shutdown();
            try {
                if (!executor.awaitTermination(10, TimeUnit.SECONDS)) {
                    executor.shutdownNow();
                    assertThat(executor.awaitTermination(5, TimeUnit.SECONDS)).isTrue();
                }
            } finally {
                doAnswer(repositoryDelegate).when(repository).findForCleanupById(id);
            }
        }
    }

    // These bounded diagnostics inspect actual PostgreSQL contention, independently of request scheduling.
    private int transactionBackendPid() {
        assertThat(TransactionSynchronizationManager.isActualTransactionActive()).isTrue();
        return jdbc.query(connection -> {
            PreparedStatement statement = connection.prepareStatement("SELECT pg_backend_pid()");
            statement.setQueryTimeout(1);
            return statement;
        }, result -> {
            assertThat(result.next()).isTrue();
            return result.getInt(1);
        });
    }

    private void awaitBlockedCleanupSelect(int cleanupPid, int writerPid) throws InterruptedException {
        assertThat(TransactionSynchronizationManager.isActualTransactionActive()).isFalse();
        assertThat(cleanupPid).isPositive().isNotEqualTo(writerPid);
        assertThat(writerPid).isPositive();
        long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(5);
        LockObservation last;
        do {
            // The test thread has no ambient transaction, so this uses an independent observer connection.
            last = jdbc.query(connection -> {
                PreparedStatement statement = connection.prepareStatement("""
                    SELECT state, wait_event_type, ? = ANY(pg_blocking_pids(pid)) AS blocked_by_writer, query
                    FROM pg_stat_activity WHERE pid = ?
                    """);
                statement.setQueryTimeout(1);
                statement.setInt(1, writerPid);
                statement.setInt(2, cleanupPid);
                return statement;
            }, result -> result.next()
                ? new LockObservation(result.getString("state"), result.getString("wait_event_type"),
                    result.getBoolean("blocked_by_writer"), result.getString("query"))
                : new LockObservation("missing", "", false, ""));
            if (last.isBlockedCleanupSelect()) {
                return;
            }
            Thread.sleep(25);
        } while (System.nanoTime() < deadline);
        assertThat(last.isBlockedCleanupSelect())
            .as("Cleanup must wait on writer in its locking SELECT, not a later DELETE; last observation: %s", last)
            .isTrue();
    }

    private record LockObservation(String state, String waitEventType, boolean blockedByWriter, String query) {
        private boolean isBlockedCleanupSelect() {
            return "active".equals(state) && "Lock".equals(waitEventType) && blockedByWriter
                && query.matches("(?is)^\\s*select\\b.*\\bfrom\\s+(?:public\\.)?draft_casefiles\\b.*"
                    + "\\bfor\\s+(?:no\\s+key\\s+)?update\\b.*");
        }
    }

    private static void await(CountDownLatch latch) {
        try {
            assertThat(latch.await(15, TimeUnit.SECONDS)).isTrue();
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Synthetic lock test interrupted", exception);
        }
    }

    private int concurrentCleanup(long id, CountDownLatch start) throws Exception {
        assertThat(start.await(5, TimeUnit.SECONDS)).isTrue();
        return cleanup(id, RUN).andReturn().getResponse().getStatus();
    }

    private static Stream<Arguments> snapshotLinkCases() {
        return Stream.of(DraftCasefileStatus.SUBMITTED, DraftCasefileStatus.REJECTED,
            DraftCasefileStatus.RESUBMITTED, DraftCasefileStatus.DELETED, DraftCasefileStatus.PUBLISHING_FAILED)
            .flatMap(lifecycle -> Stream.of("respondent_account", "applicant_account", "minor_creditor_accounts")
                .map(path -> Arguments.of(lifecycle, path)));
    }

    private long lifecycleDraft(DraftCasefileStatus lifecycle) throws Exception {
        long id = submit(RUN);
        setLifecycle(id, lifecycle);
        return id;
    }

    private void setLifecycle(long id, DraftCasefileStatus lifecycle) {
        DraftCasefileEntity original = repository.findById(id).orElseThrow();
        var builder = original.toBuilder().casefileStatus(lifecycle);
        if (lifecycle != DraftCasefileStatus.SUBMITTED) {
            builder.validatedBy("BUU-CHECKER").validatedByName("Synthetic Checker")
                .validatedDate(LocalDateTime.of(2026, 10, 22, 10, 0));
        }
        repository.saveAndFlush(builder.build());
    }

    private long submit(String marker) throws Exception {
        return submit(marker, false);
    }

    private long submit(String marker, boolean withMinor) throws Exception {
        ObjectNode request = (ObjectNode) objectMapper.readTree(DraftCasefileHttpFixture.requestBody());
        ObjectNode account = (ObjectNode) request.at("/casefile/respondent_account");
        account.put("remo_reference", marker);
        account.put("account_comment", "Synthetic cleanup comment");
        account.putObject("notes").put("note_text", "Synthetic cleanup note");
        if (withMinor) {
            ObjectNode casefile = (ObjectNode) request.get("casefile");
            ObjectNode minor = ((ObjectNode) casefile.get("applicant")).deepCopy();
            minor.put("creditor_sequence", 1);
            casefile.putArray("minor_creditors").add(minor);
            ObjectNode term = (ObjectNode) account.at("/order_details/order_terms/0");
            term.put("creditor_type", "Minor Creditor");
            term.put("minor_creditor_sequence", 1);
        }
        String response = mockMvc.perform(post("/draft-casefiles")
                .with(authentication(DraftCasefileHttpFixture.token((short) 1)))
                .contentType(MediaType.APPLICATION_JSON).content(objectMapper.writeValueAsBytes(request)))
            .andExpect(status().isCreated()).andExpect(jsonPath("$.casefile_status").value("SUBMITTED"))
            .andReturn().getResponse().getContentAsString();
        return objectMapper.readTree(response).get("draft_casefile_id").longValue();
    }

    private ResultActions cleanup(long id, String marker) throws Exception {
        return mockMvc.perform(delete(CLEANUP, id)
            .with(authentication(DraftCasefileHttpFixture.token((short) 1))).header("Test-Run-Reference", marker));
    }

    private void assertRowsUnchanged(List<DraftCasefileEntity> before) {
        assertThat(repository.findAll()).usingRecursiveFieldByFieldElementComparator()
            .containsExactlyInAnyOrderElementsOf(before);
    }

    private void assertUnchanged(DraftCasefileEntity before) {
        DraftCasefileEntity after = repository.findById(before.getDraftCasefileId()).orElseThrow();
        assertThat(after).usingRecursiveComparison().isEqualTo(before);
    }
}
