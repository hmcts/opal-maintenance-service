package uk.gov.hmcts.opal.controllers;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.hasSize;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.test.context.jdbc.Sql.ExecutionPhase.AFTER_TEST_METHOD;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.context.jdbc.Sql;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.RequestPostProcessor;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.common.user.authorisation.client.service.UserStateClientService;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.support.DraftCasefileHttpFixture;

import java.time.LocalDateTime;

@AutoConfigureMockMvc
@ExtendWith(OutputCaptureExtension.class)
@TestPropertySource(properties = {
    "spring.flyway.locations=classpath:db/migration/ddl",
    "opal.redis.enabled=false",
    "opal.testing-support-endpoints.enabled=true",
    "management.health.redis.enabled=false",
    "spring.jpa.open-in-view=false"
})
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@Sql("/draft-casefile/reference-fixtures.sql")
@Sql(scripts = "/draft-casefile/reference-cleanup.sql", executionPhase = AFTER_TEST_METHOD)
class TestingSupportControllerIntegrationTest extends BaseIntegrationTest {

    private static final String MARKER = "PO10287-550e8400-e29b-41d4-a716-446655440000";
    private static final String OTHER_MARKER = "PO10287-550e8400-e29b-41d4-a716-446655440001";

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private DraftCasefileRepository repository;

    @MockitoBean
    private UserStateClientService userStateClientService;

    @Test
    void exposesPingWhenTestingSupportEndpointsAreEnabled() throws Exception {
        mockMvc.perform(get("/testing-support/ping"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.status").value("ok"));
    }

    @Test
    void excludesDraftDiagnosticsFromPublicApiDocs() throws Exception {
        mockMvc.perform(get("/v3/api-docs"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.paths['/testing-support/ping'].get").exists())
            .andExpect(jsonPath("$.paths['/testing-support/draft-casefiles/{id}'].get").doesNotExist())
            .andExpect(jsonPath("$.paths['/testing-support/draft-casefiles/{id}'].delete").doesNotExist())
            .andExpect(jsonPath("$.paths['/testing-support/draft-casefiles/markers/{marker}'].get")
                .doesNotExist());
    }

    @Test
    void rejectsUnauthenticatedAuthCheckWhenTestingSupportEndpointsAreEnabled() throws Exception {
        mockMvc.perform(get("/testing-support/auth/check"))
            .andExpect(status().isUnauthorized());
    }

    @Test
    void rejectsUnauthenticatedTestingSupportSibling() throws Exception {
        mockMvc.perform(get("/testing-support/future-resource"))
            .andExpect(status().isUnauthorized());
    }

    @Test
    void ownerCanInspectAndFindOnlyOwnMarkedDrafts() throws Exception {
        final Long owned = save((short) 44, "L044JG", MARKER);
        save((short) 44, "L044JG", "ordinary");
        save((short) 44, "OTHER", MARKER);
        save((short) 1, "L044JG", MARKER);
        save((short) 44, "L044JG", OTHER_MARKER);

        mockMvc.perform(get("/testing-support/draft-casefiles/{id}", owned).with(allowedUser()))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.*", hasSize(10)))
            .andExpect(jsonPath("$.draft_casefile_id").value(owned))
            .andExpect(jsonPath("$.business_unit_id").value(44))
            .andExpect(jsonPath("$.submitted_by").value("L044JG"))
            .andExpect(jsonPath("$.created_date").isNotEmpty())
            .andExpect(jsonPath("$.casefile_status").value("SUBMITTED"))
            .andExpect(jsonPath("$.casefile_status_date").isNotEmpty())
            .andExpect(jsonPath("$.version_number").value(0))
            .andExpect(jsonPath("$.snapshot_present").value(true))
            .andExpect(jsonPath("$.timeline_entry_count").value(1))
            .andExpect(jsonPath("$.timeline_statuses[0]").value("Submitted"))
            .andExpect(jsonPath("$.casefile").doesNotExist())
            .andExpect(jsonPath("$.casefile_snapshot").doesNotExist())
            .andExpect(jsonPath("$.timeline_data").doesNotExist())
            .andExpect(jsonPath("$.submitted_by_name").doesNotExist());

        mockMvc.perform(get("/testing-support/draft-casefiles/markers/{marker}", MARKER).with(allowedUser()))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.*", hasSize(2)))
            .andExpect(jsonPath("$.count").value(1))
            .andExpect(jsonPath("$.draft_casefile_ids[0]").value(owned));
    }

    @Test
    void markerLookupAcceptsEscapedNullOutsideMarkerWithoutExposingContent(CapturedOutput output) throws Exception {
        String casefile = """
            {"respondent_account":{"account_comment":"%s","other":"SYNTHETIC_PRIVATE_VALUE\\u0000"},
             "other":"SYNTHETIC_PRIVATE_VALUE\\u0000"}
            """.formatted(MARKER);
        Long owned = saveCasefile((short) 44, "L044JG", casefile);
        saveCasefile((short) 44, "L044JG", casefile.replace(MARKER, MARKER + "\\u0000"));

        String response = mockMvc.perform(get("/testing-support/draft-casefiles/markers/{marker}", MARKER)
                .with(allowedUser()))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.*", hasSize(2)))
            .andExpect(jsonPath("$.count").value(1))
            .andExpect(jsonPath("$.draft_casefile_ids", hasSize(1)))
            .andExpect(jsonPath("$.draft_casefile_ids[0]").value(owned))
            .andReturn().getResponse().getContentAsString();
        mockMvc.perform(get("/testing-support/draft-casefiles/markers/{marker}", OTHER_MARKER).with(allowedUser()))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.count").value(0))
            .andExpect(jsonPath("$.draft_casefile_ids").isEmpty());

        assertThat(repository.findById(owned).orElseThrow().getCasefile()).isEqualTo(casefile);
        assertThat(response).doesNotContain(MARKER, "SYNTHETIC_PRIVATE_VALUE", "\"casefile\"", "account_comment");
        assertThat(output).doesNotContain("SYNTHETIC_PRIVATE_VALUE");
    }

    @Test
    void ownerCanDeleteMarkedDraftWithoutRemovingOtherRows() throws Exception {
        Long owned = save((short) 44, "L044JG", MARKER);
        Long other = save((short) 44, "OTHER", MARKER);

        mockMvc.perform(delete("/testing-support/draft-casefiles/{id}", owned).with(allowedUser()))
            .andExpect(status().isNoContent());

        assertThat(repository.findById(owned)).isEmpty();
        assertThat(repository.findById(other)).isPresent();
    }

    @Test
    void ineligibleDraftsAreConcealedAndPreserved() throws Exception {
        Long unmarked = save((short) 44, "L044JG", "ordinary");
        Long otherOwner = save((short) 44, "OTHER", MARKER);
        Long otherUnit = save((short) 1, "L044JG", MARKER);

        for (Long id : new Long[] {unmarked, otherOwner, otherUnit}) {
            mockMvc.perform(get("/testing-support/draft-casefiles/{id}", id).with(allowedUser()))
                .andExpect(status().isNotFound());
            mockMvc.perform(delete("/testing-support/draft-casefiles/{id}", id).with(allowedUser()))
                .andExpect(status().isNotFound());
            assertThat(repository.findById(id)).isPresent();
        }
    }

    @Test
    void allDraftRoutesRequireAuthenticationAndPermission() throws Exception {
        Long owned = save((short) 44, "L044JG", MARKER);

        mockMvc.perform(get("/testing-support/draft-casefiles/{id}", owned))
            .andExpect(status().isUnauthorized());
        mockMvc.perform(get("/testing-support/draft-casefiles/markers/{marker}", MARKER))
            .andExpect(status().isUnauthorized());
        mockMvc.perform(delete("/testing-support/draft-casefiles/{id}", owned))
            .andExpect(status().isUnauthorized());

        var denied = authentication(DraftCasefileHttpFixture.token((short) 44, "L044JG", false));
        mockMvc.perform(get("/testing-support/draft-casefiles/{id}", owned).with(denied))
            .andExpect(status().isForbidden());
        mockMvc.perform(get("/testing-support/draft-casefiles/markers/{marker}", MARKER).with(denied))
            .andExpect(status().isForbidden());
        mockMvc.perform(delete("/testing-support/draft-casefiles/{id}", owned).with(denied))
            .andExpect(status().isForbidden());
        assertThat(repository.findById(owned)).isPresent();
    }

    private static RequestPostProcessor allowedUser() {
        return authentication(DraftCasefileHttpFixture.token((short) 44, "L044JG", true));
    }

    private Long save(short businessUnitId, String owner, String marker) {
        return saveCasefile(businessUnitId, owner,
            "{\"respondent_account\":{\"account_comment\":\"" + marker + "\"}}");
    }

    private Long saveCasefile(short businessUnitId, String owner, String casefile) {
        LocalDateTime created = LocalDateTime.of(2026, 10, 16, 10, 11);
        DraftCasefileEntity entity = DraftCasefileEntity.builder()
            .businessUnitId(businessUnitId).submittedBy(owner).submittedByName("Synthetic Submitter")
            .createdDate(created).casefileStatus(DraftCasefileStatus.SUBMITTED).casefileStatusDate(created)
            .casefileType("REMO In")
            .casefile(casefile)
            .casefileSnapshot("{}").timelineData("[{\"status\":\"Submitted\"}]").build();
        return repository.saveAndFlush(entity).getDraftCasefileId();
    }
}
