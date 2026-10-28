package uk.gov.hmcts.opal.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.security.access.AccessDeniedException;
import uk.gov.hmcts.opal.authorisation.MaintenanceUser;
import uk.gov.hmcts.opal.authorisation.MaintenanceUserService;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static uk.gov.hmcts.opal.authorisation.MaintenancePermission.CREATE_MANAGE_DRAFT_CASEFILES;

class DraftCasefileTestScopeTest {

    private static final String RUN = "E2E-0123456789abcdef";
    private final MaintenanceUserService users = mock(MaintenanceUserService.class);
    private final DraftCasefileTestScope scope = new DraftCasefileTestScope(users, new ObjectMapper());

    @BeforeEach
    void authoriseSubmitter() {
        when(users.requireAuthorisedUser((short) 1, CREATE_MANAGE_DRAFT_CASEFILES))
            .thenReturn(new MaintenanceUser(123L, "BUU-1", "Synthetic Submitter", "192.0.2.1"));
    }

    @Test
    void acceptsLatestOwnerWithExactMarker() {
        scope.requireOwnedRun(ownedDraft(), RUN);
        verify(users).requireAuthorisedUser((short) 1, CREATE_MANAGE_DRAFT_CASEFILES);
    }

    @Test
    void rejectsDifferentStoredSubmitter() {
        assertDenied(ownedDraft().toBuilder().submittedBy("BUU-OTHER").build());
    }

    @Test
    void missingPermissionRejectsScope() {
        AccessDeniedException failure = new AccessDeniedException("Permission is required");
        when(users.requireAuthorisedUser((short) 1, CREATE_MANAGE_DRAFT_CASEFILES)).thenThrow(failure);
        assertThatThrownBy(() -> scope.requireOwnedRun(ownedDraft(), RUN)).isSameAs(failure);
    }

    @Test
    void checksPermissionInTheStoredBusinessUnit() {
        AccessDeniedException failure = new AccessDeniedException("No identity for requested Business Unit");
        when(users.requireAuthorisedUser((short) 2, CREATE_MANAGE_DRAFT_CASEFILES)).thenThrow(failure);
        DraftCasefileEntity draft = ownedDraft().toBuilder().businessUnitId((short) 2).build();
        assertThatThrownBy(() -> scope.requireOwnedRun(draft, RUN)).isSameAs(failure);
        verify(users, never()).requireAuthorisedUser((short) 1, CREATE_MANAGE_DRAFT_CASEFILES);
    }

    @Test
    void anotherUserCanCleanTheirOwnDraftInAnotherBusinessUnit() {
        DraftCasefileEntity draft = ownedDraft().toBuilder().businessUnitId((short) 2).submittedBy("BUU-2").build();
        when(users.requireAuthorisedUser((short) 2, CREATE_MANAGE_DRAFT_CASEFILES))
            .thenReturn(new MaintenanceUser(124L, "BUU-2", "Synthetic Submitter", "192.0.2.1"));
        scope.requireOwnedRun(draft, RUN);
        verify(users).requireAuthorisedUser((short) 2, CREATE_MANAGE_DRAFT_CASEFILES);
    }

    @ParameterizedTest
    @ValueSource(strings = {
        "{\"respondent_account\":{\"remo_reference\":\"E2E-other\"}}",
        "{\"respondent_account\":{}}", "{}", "null", "[]", "",
        "{\"respondent_account\":{\"remo_reference\":null}}",
        "{\"respondent_account\":{\"remo_reference\":123}}",
        "{\"respondent_account\":{\"remo_reference\":true}}",
        "{\"respondent_account\":{\"remo_reference\":[]}}",
        "{\"respondent_account\":{\"remo_reference\":{}}}", "{malformed"
    })
    void rejectsMissingDifferentNonTextOrMalformedRunMarker(String casefile) {
        assertDenied(ownedDraft().toBuilder().casefile(casefile).build());
    }

    private void assertDenied(DraftCasefileEntity draft) {
        assertThatThrownBy(() -> scope.requireOwnedRun(draft, RUN)).isInstanceOf(AccessDeniedException.class)
            .hasMessage("Draft Casefile test cleanup is not permitted");
    }

    private static DraftCasefileEntity ownedDraft() {
        return DraftCasefileEntity.builder().businessUnitId((short) 1).submittedBy("BUU-1")
            .casefile("{\"respondent_account\":{\"remo_reference\":\"" + RUN + "\"}}")
            .build();
    }
}
