package uk.gov.hmcts.opal.controllers;

import static org.hamcrest.Matchers.nullValue;
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.LocalDate;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.cache.CacheManager;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.entity.CountryEntity;
import uk.gov.hmcts.opal.entity.MajorCreditorEntity;
import uk.gov.hmcts.opal.repository.MajorCreditorRepository;

@AutoConfigureMockMvc
@TestPropertySource(properties = {
    "spring.flyway.locations=classpath:db/migration/ddl",
    "management.health.redis.enabled=false"
})
@DisplayName("PO-10254 GET /major-creditors HTTP integration")
class MajorCreditorControllerIntegrationTest extends BaseIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private CacheManager cacheManager;

    @MockitoBean
    private MajorCreditorRepository repository;

    @BeforeEach
    void clearMajorCreditorCacheAndRepositoryInvocations() {
        cacheManager.getCache("majorCreditorReferenceDataCache").clear();
        clearInvocations(repository);
    }

    @Test
    void rejectsUnauthenticatedRequests() throws Exception {
        mockMvc.perform(get("/major-creditors").param("business_unit_id", "77"))
            .andExpect(status().isUnauthorized())
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
            .andExpect(jsonPath("$.title").value("Unauthorized"))
            .andExpect(jsonPath("$.status").value(401));
    }

    @Test
    void requiresBusinessUnitId() throws Exception {
        mockMvc.perform(get("/major-creditors").with(user("test-user")))
            .andExpect(status().isBadRequest())
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
            .andExpect(jsonPath("$.type").value("https://hmcts.gov.uk/problems/missing-required-parameter"))
            .andExpect(jsonPath("$.title").value("Bad Request"))
            .andExpect(jsonPath("$.detail").value("A required request parameter is missing"))
            .andExpect(jsonPath("$.status").value(400))
            .andExpect(jsonPath("$.instance").isNotEmpty())
            .andExpect(jsonPath("$.operation_id").isNotEmpty())
            .andExpect(jsonPath("$.retriable").value(false));
    }

    @Test
    void rejectsBusinessUnitIdBelowItsMinimum() throws Exception {
        mockMvc.perform(get("/major-creditors")
                .param("business_unit_id", "0")
                .with(user("test-user")))
            .andExpect(status().isBadRequest())
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
            .andExpect(jsonPath("$.type").value("https://hmcts.gov.uk/problems/constraint-violation"))
            .andExpect(jsonPath("$.title").value("Bad Request"))
            .andExpect(jsonPath("$.detail").value("A request parameter value violates its constraints"))
            .andExpect(jsonPath("$.status").value(400))
            .andExpect(jsonPath("$.instance").isNotEmpty())
            .andExpect(jsonPath("$.operation_id").isNotEmpty())
            .andExpect(jsonPath("$.retriable").value(false));
    }

    @Test
    void rejectsBusinessUnitIdOutsideTheShortRangeWithTypeMismatchProblemDetails() throws Exception {
        mockMvc.perform(get("/major-creditors")
                .param("business_unit_id", "32768")
                .with(user("test-user")))
            .andExpect(status().isNotAcceptable())
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
            .andExpect(jsonPath("$.type").value("https://hmcts.gov.uk/problems/type-mismatch"))
            .andExpect(jsonPath("$.title").value("Not Acceptable"))
            .andExpect(jsonPath("$.status").value(406));
    }

    @Test
    void rejectsMalformedBusinessUnitId() throws Exception {
        mockMvc.perform(get("/major-creditors")
                .param("business_unit_id", "abc")
                .with(user("test-user")))
            .andExpect(status().isNotAcceptable())
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
            .andExpect(jsonPath("$.type").value("https://hmcts.gov.uk/problems/type-mismatch"))
            .andExpect(jsonPath("$.title").value("Not Acceptable"))
            .andExpect(jsonPath("$.status").value(406));
    }

    @ParameterizedTest
    @ValueSource(strings = {"central_authority", "active"})
    void rejectsMalformedBooleanParameters(String parameterName) throws Exception {
        mockMvc.perform(get("/major-creditors")
                .param("business_unit_id", "77")
                .param(parameterName, "not-a-boolean")
                .with(user("test-user")))
            .andExpect(status().isNotAcceptable())
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
            .andExpect(jsonPath("$.type").value("https://hmcts.gov.uk/problems/type-mismatch"))
            .andExpect(jsonPath("$.title").value("Not Acceptable"))
            .andExpect(jsonPath("$.status").value(406));
    }

    @Test
    void rejectsUnsupportedAcceptType() throws Exception {
        mockMvc.perform(get("/major-creditors")
                .param("business_unit_id", "77")
                .accept(MediaType.APPLICATION_XML)
                .with(user("test-user")))
            .andExpect(status().isNotAcceptable())
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON));
    }

    @Test
    void returnsAllPropertiesAndMapsInactiveCountryWithoutDateFiltering() throws Exception {
        CountryEntity inactiveCountry = CountryEntity.builder()
            .countryId(101L)
            .countryName("France")
            .dateUsedFrom(LocalDate.of(2099, 1, 1))
            .dateUsedTo(LocalDate.of(2000, 1, 1))
            .active(false)
            .build();
        MajorCreditorEntity creditor = MajorCreditorEntity.builder()
            .majorCreditorId(901L)
            .businessUnitId((short) 77)
            .majorCreditorCode("0123")
            .name("Example Creditor")
            .addressLine1("1 Example Street")
            .country(inactiveCountry)
            .active(true)
            .centralAuthority(false)
            .build();
        when(repository.findMajorCreditors((short) 77, false, true))
            .thenReturn(List.of(creditor));

        mockMvc.perform(get("/major-creditors")
                .param("business_unit_id", "77")
                .param("central_authority", "false")
                .param("active", "true")
                .with(user("test-user")))
            .andExpect(status().isOk())
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
            .andExpect(jsonPath("$.count").value(1))
            .andExpect(jsonPath("$.refData[0].major_creditor_id").value(901))
            .andExpect(jsonPath("$.refData[0].business_unit_id").value(77))
            .andExpect(jsonPath("$.refData[0].major_creditor_code").value("0123"))
            .andExpect(jsonPath("$.refData[0].name").value("Example Creditor"))
            .andExpect(jsonPath("$.refData[0].address_line_1").value("1 Example Street"))
            .andExpect(jsonPath("$.refData[0].address_line_2").value(nullValue()))
            .andExpect(jsonPath("$.refData[0].address_line_3").value(nullValue()))
            .andExpect(jsonPath("$.refData[0].address_line_4").value(nullValue()))
            .andExpect(jsonPath("$.refData[0].address_line_5").value(nullValue()))
            .andExpect(jsonPath("$.refData[0].postcode").value(nullValue()))
            .andExpect(jsonPath("$.refData[0].country_id").value(101))
            .andExpect(jsonPath("$.refData[0].country_name").value("France"))
            .andExpect(jsonPath("$.refData[0].contact_name").value(nullValue()))
            .andExpect(jsonPath("$.refData[0].contact_email").value(nullValue()))
            .andExpect(jsonPath("$.refData[0].active").value(true))
            .andExpect(jsonPath("$.refData[0].central_authority").value(false));

        verify(repository).findMajorCreditors((short) 77, false, true);
    }

    @Test
    void emitsBothCountryPropertiesAsNullWhenNoCountryExists() throws Exception {
        MajorCreditorEntity creditor = MajorCreditorEntity.builder()
            .majorCreditorId(902L)
            .businessUnitId((short) 77)
            .majorCreditorCode("0124")
            .name("No Country")
            .addressLine1("2 Example Street")
            .active(true)
            .centralAuthority(false)
            .build();
        when(repository.findMajorCreditors((short) 77, null, null))
            .thenReturn(List.of(creditor));

        mockMvc.perform(get("/major-creditors")
                .param("business_unit_id", "77")
                .with(user("test-user")))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.refData[0].country_id").value(nullValue()))
            .andExpect(jsonPath("$.refData[0].country_name").value(nullValue()));
    }

    @Test
    void returnsZeroCountAndEmptyArray() throws Exception {
        when(repository.findMajorCreditors((short) 77, null, null)).thenReturn(List.of());

        mockMvc.perform(get("/major-creditors")
                .param("business_unit_id", "77")
                .with(user("test-user")))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.count").value(0))
            .andExpect(jsonPath("$.refData").isArray())
            .andExpect(jsonPath("$.refData").isEmpty());
    }
}
