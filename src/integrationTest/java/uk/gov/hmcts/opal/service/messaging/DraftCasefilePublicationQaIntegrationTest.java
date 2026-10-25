package uk.gov.hmcts.opal.service.messaging;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestReporter;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.webmvc.test.autoconfigure.MockMvcPrint;
import org.springframework.context.annotation.Import;
import org.springframework.dao.QueryTimeoutException;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.springframework.test.context.jdbc.Sql;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.PlatformTransactionManager;
import tools.jackson.databind.ObjectMapper;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.logging.integration.dto.PersonalDataProcessingCategory;
import uk.gov.hmcts.opal.logging.integration.dto.PersonalDataProcessingLogDetails;
import uk.gov.hmcts.opal.logging.integration.service.LoggingService;
import uk.gov.hmcts.opal.mapper.DraftCasefilePublicationMapper;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.repository.MajorCreditorRepository;
import uk.gov.hmcts.opal.repository.extensions.DraftCasefilePublicationRepository;
import uk.gov.hmcts.opal.service.DraftCasefilePublicationFailureService;
import uk.gov.hmcts.opal.support.publication.PublicationQaFixture;
import uk.gov.hmcts.opal.support.publication.PublicationQaFixture.OwnedDraft;
import uk.gov.hmcts.opal.support.publication.PublicationQaGraph;
import uk.gov.hmcts.opal.support.publication.PublicationQaGraphConfiguration;
import uk.gov.hmcts.opal.support.publication.PublicationQaTransactions;
import uk.gov.hmcts.opal.validator.OpenApiSchemaValidator;
import uk.gov.hmcts.opal.validator.DraftCasefilePublicationValidator;

import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.context.jdbc.Sql.ExecutionPhase.AFTER_TEST_METHOD;

/** Backend orchestration evidence; the provider and its graph are real, the broker transport is external. */
@AutoConfigureMockMvc(print = MockMvcPrint.NONE)
@Import(PublicationQaGraphConfiguration.class)
@TestPropertySource(properties = {"spring.flyway.locations=classpath:db/migration/ddl", "opal.redis.enabled=false",
    "management.health.redis.enabled=false", "spring.jpa.open-in-view=false"})
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@Sql({"/draft-casefile/reference-fixtures.sql", "/draft-casefile/cleanup-scope-fixtures.sql"})
@Sql(scripts = "/draft-casefile/cleanup-scope-cleanup.sql", executionPhase = AFTER_TEST_METHOD)
class DraftCasefilePublicationQaIntegrationTest extends BaseIntegrationTest {

    @Autowired
    private MockMvc mvc;
    @Autowired
    private ObjectMapper json;
    @Autowired
    private PlatformTransactionManager transactionManager;
    @Autowired
    private DraftCasefileRepository drafts;
    @Autowired
    private MajorCreditorRepository majorCreditors;
    @Autowired
    private PublicationQaGraph graph;
    @Autowired
    private DraftCasefileQueueConsumerService consumer;
    @Autowired
    private OpenApiSchemaValidator schemas;
    @Autowired
    private DraftCasefilePublicationValidator validator;
    @MockitoBean
    private DraftCasefileQueuePublisherImpl delegate;
    @MockitoBean
    private LoggingService logging;
    @MockitoSpyBean
    private DraftCasefilePublicationRepository publication;
    @MockitoSpyBean
    private DraftCasefilePublicationMapper mapper;
    @MockitoSpyBean
    private DraftCasefilePublicationFailureService failures;

    private PublicationQaFixture fixture;
    private PublicationQaTransactions transactions;
    private OwnedDraft owned;
    private DraftCasefileEntity pending;
    private final AtomicInteger providerAttempts = new AtomicInteger();
    private final AtomicInteger providerReturns = new AtomicInteger();
    private final AtomicInteger faultHooks = new AtomicInteger();
    private final List<PersonalDataProcessingLogDetails> publicationLogs = new ArrayList<>();

    @BeforeEach
    void setUp() {
        fixture = new PublicationQaFixture(mvc, json, drafts, majorCreditors, transactionManager, graph,
            delegate, schemas);
        transactions = new PublicationQaTransactions();
        when(logging.personalDataAccessLogAsync(any())).thenReturn(true);
        doAnswer(invocation -> {
            transactions.observe("processing");
            providerAttempts.incrementAndGet();
            Object result = invocation.callRealMethod();
            providerReturns.incrementAndGet();
            return result;
        }).when(publication).publish(any());
        doAnswer(invocation -> {
            transactions.observe("failure");
            return invocation.callRealMethod();
        }).when(failures).markFailed(any(), any());
    }

    @AfterEach
    void cleanup(TestReporter reporter) {
        reporter.publishEntry("publication-qa-processing", "provider_attempts=" + providerAttempts.get()
            + "; successful_returns=" + providerReturns.get() + "; post_provider_hooks=" + faultHooks.get());
        if (fixture != null) {
            try {
                fixture.cleanupCaptured();
                reporter.publishEntry("publication-qa-cleanup", "Owned draft, Major Creditor and graph removed; "
                    + "baseline preserved");
            } catch (RuntimeException | AssertionError failure) {
                reporter.publishEntry("publication-qa-cleanup", "Owned cleanup failed; manual investigation required");
                throw failure;
            }
        }
    }

    @ParameterizedTest(name = "publication with minors={0}")
    @ValueSource(booleans = {false, true})
    void publishesCompleteGraph(boolean withMinors) {
        approve(withMinors);
        RuntimeException observed = deliver();
        requireProviderReturn(1, false);
        assertTrue(observed == null, "Successful publication must return normally");
        assertPublished();
    }

    @Test
    void terminalFailureCommitsAfterProcessingRollback() {
        approve(true);
        injectFault(false);
        RuntimeException observed = deliver();
        requireProviderReturn(1, true);
        assertTrue(observed == null, "Terminal failure must settle after its failure transaction commits");
        assertFailed();
        transactions.assertRollbackBeforeFailureCommit();
    }

    @Test
    void transientFailureRetriesThenDuplicateIsNoOp() {
        approve(true);
        injectFault(true);
        RuntimeException observed = deliver();
        requireProviderReturn(1, true);
        assertRetry(observed);
        assertPending();
        verifyNoInteractions(failures, logging);
        transactions.assertRolledBack("processing");
        assertTrue(deliver() == null, "Redelivery must complete publication");
        requireProviderReturn(2, true);
        assertPublished();
        assertDuplicate(2);
    }

    @Test
    void separatePublishedDeliveryIsIdempotent() {
        approve(false);
        RuntimeException observed = deliver();
        requireProviderReturn(1, false);
        assertTrue(observed == null, "Initial publication must complete");
        assertPublished();
        assertDuplicate(1);
    }

    @Test
    void failureRecordingOutageRetriesUntilTerminalCommit() {
        approve(true);
        injectFault(false);
        AtomicInteger failureAttempts = new AtomicInteger();
        doAnswer(invocation -> {
            transactions.observe("failure");
            if (failureAttempts.incrementAndGet() == 1) {
                throw new IllegalStateException("Synthetic failure recording outage");
            }
            return invocation.callRealMethod();
        }).when(failures).markFailed(any(), any());
        RuntimeException first = deliver();
        requireProviderReturn(1, true);
        assertRetry(first);
        assertPending();
        verifyNoInteractions(logging);
        transactions.assertRolledBack("failure");
        RuntimeException second = deliver();
        requireProviderReturn(2, true);
        assertTrue(second == null, "Later terminal failure must settle after committed failure recording");
        assertEquals(2, failureAttempts.get(), "Failure recording must be retried");
        assertFailed();
        transactions.assertRollbackBeforeFailureCommit();
    }

    private void approve(boolean withMinors) {
        owned = fixture.approve(withMinors);
        pending = fixture.committed(owned.id());
        validator.validate(pending);
        mapper.validatePendingSnapshot(pending.getCasefileSnapshot(), owned.approved().get("casefile"));
        clearInvocations(logging, failures, publication);
        when(logging.personalDataAccessLogAsync(any())).thenAnswer(invocation -> {
            PersonalDataProcessingLogDetails details = invocation.getArgument(0);
            if (!details.getBusinessIdentifier().startsWith("Publish Approved Casefile - ")) {
                return true;
            }
            transactions.assertCommitted("processing");
            assertEquals(DraftCasefileStatus.PUBLISHED, fixture.committed(owned.id()).getCasefileStatus(),
                "Publication PDPL must follow independently visible commit");
            graph.assertPublished(owned.graphBefore(), fixture.committed(owned.id()),
                owned.approved().get("casefile"));
            publicationLogs.add(details);
            return true;
        });
    }

    private RuntimeException deliver() {
        try {
            consumer.consume(owned.payload());
            return null;
        } catch (RuntimeException failure) {
            // Report only fixed prerequisite/outcome assertions, never provider diagnostics or saved data.
            return failure;
        }
    }

    private void injectFault(boolean transientOnce) {
        doAnswer(invocation -> {
            transactions.observe("processing");
            faultHooks.incrementAndGet();
            if (transientOnce && faultHooks.get() > 1) {
                return invocation.callRealMethod();
            }
            if (transientOnce) {
                throw new QueryTimeoutException("Synthetic post-provider timeout");
            }
            throw new IllegalStateException("Synthetic post-provider mapping failure");
        }).when(mapper).mergePublishedAccounts(any(), any(), any());
    }

    private void requireProviderReturn(int expected, boolean faultRequired) {
        assertEquals(expected, providerAttempts.get(), "Real provider attempt prerequisite not reached");
        assertEquals(expected, providerReturns.get(), "Real provider successful-return prerequisite not reached");
        if (faultRequired) {
            assertEquals(expected, faultHooks.get(), "Post-provider fault hook prerequisite not reached");
        }
    }

    private void assertPublished() {
        DraftCasefileEntity published = fixture.committed(owned.id());
        assertEquals(DraftCasefileStatus.PUBLISHED, published.getCasefileStatus());
        assertApprovalPreserved(published);
        assertTrue(published.getAccountId() != null && published.getAccountId() > 0,
            "Published draft must retain the respondent identity");
        assertTrue(published.getAccountNumber() != null && !published.getAccountNumber().isBlank(),
            "Published draft must retain the respondent account number");
        assertTrue(published.getVersionNumber() > pending.getVersionNumber(), "Publication advances the version");
        assertTrue(!published.getCasefileStatusDate().isBefore(pending.getCasefileStatusDate()),
            "Publication status date follows approval");
        assertTrue(published.getStatusMessage() == null, "Successful publication has no failure message");
        graph.assertPublished(owned.graphBefore(), published, owned.approved().get("casefile"));
        transactions.assertCommitted("processing");
        assertPublicationLogs(published);
        clearInvocations(logging);
        when(logging.personalDataAccessLogAsync(any())).thenReturn(true);
        fixture.assertHttpState(owned.id(), published, "Published");
        verifyNoInteractions(failures);
    }

    private void assertFailed() {
        DraftCasefileEntity failed = fixture.committed(owned.id());
        assertEquals(DraftCasefileStatus.PUBLISHING_FAILED, failed.getCasefileStatus());
        assertApprovalPreserved(failed);
        assertTrue(Objects.equals(pending.getCasefileSnapshot(), failed.getCasefileSnapshot()),
            "Failure must preserve the complete approval snapshot");
        assertTrue(failed.getAccountId() == null && failed.getAccountNumber() == null,
            "Failure must not retain account identities");
        assertTrue(failed.getVersionNumber() > pending.getVersionNumber(), "Failure advances the version");
        assertTrue(!failed.getCasefileStatusDate().isBefore(pending.getCasefileStatusDate()),
            "Failure status date follows approval");
        assertEquals("Publication failed; contact support", failed.getStatusMessage());
        graph.assertUnchanged(owned.graphBefore());
        verifyNoInteractions(logging);
        when(logging.personalDataAccessLogAsync(any())).thenReturn(true);
        fixture.assertHttpState(owned.id(), failed, "Publishing failed");
    }

    private void assertPending() {
        fixture.assertSameDraft(pending, fixture.committed(owned.id()));
        graph.assertUnchanged(owned.graphBefore());
    }

    private void assertRetry(RuntimeException observed) {
        assertTrue(observed instanceof IllegalStateException, "Transient/outage delivery must request retry");
        assertEquals("Publication delivery requires retry", observed.getMessage());
        assertTrue(observed.getCause() == null, "Retry must omit private failure details");
    }

    private void assertDuplicate(int expectedProviderCalls) {
        DraftCasefileEntity before = fixture.committed(owned.id());
        final PublicationQaGraph.Snapshot graphBefore = graph.snapshot();
        final String etag = fixture.assertHttpState(owned.id(), before, "Published");
        final int logsBefore = publicationLogs.size();
        clearInvocations(logging);
        assertTrue(deliver() == null, "Published duplicate must settle normally");
        fixture.assertSameDraft(before, fixture.committed(owned.id()));
        graph.assertUnchanged(graphBefore);
        requireProviderReturn(expectedProviderCalls, false);
        verify(publication, times(expectedProviderCalls)).publish(any());
        verifyNoInteractions(logging);
        assertEquals(logsBefore, publicationLogs.size(), "Duplicate must emit no additional PDPL");
        assertEquals(etag, fixture.assertHttpState(owned.id(), before, "Published"));
    }

    private void assertApprovalPreserved(DraftCasefileEntity actual) {
        assertTrue(Objects.equals(pending.getCasefile(), actual.getCasefile())
            && Objects.equals(pending.getCreatedDate(), actual.getCreatedDate())
            && Objects.equals(pending.getSubmittedBy(), actual.getSubmittedBy())
            && Objects.equals(pending.getSubmittedByName(), actual.getSubmittedByName())
            && Objects.equals(pending.getValidatedBy(), actual.getValidatedBy())
            && Objects.equals(pending.getValidatedByName(), actual.getValidatedByName())
            && Objects.equals(pending.getValidatedDate(), actual.getValidatedDate())
            && Objects.equals(pending.getTimelineData(), actual.getTimelineData())
            && Objects.equals(pending.getBusinessUnitId(), actual.getBusinessUnitId())
            && Objects.equals(pending.getCasefileType(), actual.getCasefileType()),
            "Publication must preserve input, ownership, approval metadata and exact history");
    }

    private void assertPublicationLogs(DraftCasefileEntity published) {
        int expected = owned.approved().at("/casefile/minor_creditors").isEmpty() ? 3 : 4;
        assertEquals(expected, publicationLogs.size(), "Publication must log each actual participant category");
        List<String> expectedNames = new ArrayList<>(List.of("Publish Approved Casefile - Respondent",
            "Publish Approved Casefile - Applicant / Beneficiary", "Publish Approved Casefile - Related parties"));
        if (expected == 4) {
            expectedNames.add("Publish Approved Casefile - Minor Creditor");
        }
        assertTrue(publicationLogs.stream().map(PersonalDataProcessingLogDetails::getBusinessIdentifier).toList()
            .equals(expectedNames), "Publication PDPL categories differ");
        for (PersonalDataProcessingLogDetails details : publicationLogs) {
            assertEquals(PersonalDataProcessingCategory.ALTERATION, details.getCategory());
            assertEquals("124", details.getCreatedBy().getIdentifier());
            assertEquals("OPAL_USER_ID", details.getCreatedBy().getType().getType());
            assertEquals("192.0.2.1", details.getIpAddress());
            assertEquals(published.getCasefileStatusDate().toInstant(ZoneOffset.UTC),
                details.getCreatedAt().toInstant());
            assertTrue(details.getIndividuals().size() == 1
                && Long.toString(owned.id()).equals(details.getIndividuals().get(0).getIdentifier())
                && "RM_DRAFT_CASEFILE".equals(details.getIndividuals().get(0).getType().getType()),
                "Publication PDPL must identify the owned draft");
        }
    }
}
