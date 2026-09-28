package uk.gov.hmcts.opal.controllers;

import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.verify;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.context.jdbc.Sql.ExecutionPhase.BEFORE_TEST_METHOD;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.cache.CacheManager;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.springframework.test.context.jdbc.Sql;
import org.springframework.test.web.servlet.MockMvc;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.repository.CountryRepository;

@AutoConfigureMockMvc
@TestPropertySource(properties = {
    "spring.flyway.locations=classpath:db/migration/ddl",
    "management.health.redis.enabled=false"
})
@Sql(scripts = "/db/country-controller-fixtures.sql", executionPhase = BEFORE_TEST_METHOD)
@DisplayName("PO-10251 GET /countries cache integration")
class CountryCacheIntegrationTest extends BaseIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private CacheManager cacheManager;

    @MockitoSpyBean
    private CountryRepository repository;

    @BeforeEach
    void clearCountryCacheAndRepositoryInvocations() {
        cacheManager.getCache("countryReferenceDataCache").clear();
        clearInvocations(repository);
    }

    @Test
    void repeatedIdenticalRequestsUseOneRepositoryQuery() throws Exception {
        mockMvc.perform(get("/countries").with(user("test-user"))).andExpect(status().isOk());
        mockMvc.perform(get("/countries").with(user("test-user"))).andExpect(status().isOk());

        verify(repository).findCountries(null);
    }

    @Test
    void omittedTrueAndFalseRequestsDoNotShareCacheEntries() throws Exception {
        mockMvc.perform(get("/countries").with(user("test-user"))).andExpect(status().isOk());
        mockMvc.perform(get("/countries").param("active", "true").with(user("test-user")))
            .andExpect(status().isOk());
        mockMvc.perform(get("/countries").param("active", "false").with(user("test-user")))
            .andExpect(status().isOk());

        verify(repository).findCountries(null);
        verify(repository).findCountries(true);
        verify(repository).findCountries(false);
    }
}
