package uk.gov.hmcts.reform.opal.controllers;

import static org.hamcrest.Matchers.nullValue;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.context.jdbc.Sql.ExecutionPhase.BEFORE_TEST_METHOD;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.jdbc.Sql;
import org.springframework.test.web.servlet.MockMvc;
import uk.gov.hmcts.reform.opal.BaseIntegrationTest;

@AutoConfigureMockMvc
@TestPropertySource(properties = {
    "spring.flyway.locations=classpath:db/migration/ddl",
    "management.health.redis.enabled=false"
})
@Sql(scripts = "/db/country-controller-fixtures.sql", executionPhase = BEFORE_TEST_METHOD)
@DisplayName("PO-10251 GET /countries integration")
class CountryControllerIntegrationTest extends BaseIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Test
    @DisplayName("PO-10251 rejects an unauthenticated request with correlated Problem Details")
    void rejectsUnauthenticatedRequest() throws Exception {
        mockMvc.perform(get("/countries"))
            .andExpect(status().isUnauthorized())
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
            .andExpect(jsonPath("$.title").value("Unauthorized"))
            .andExpect(jsonPath("$.status").value(401))
            .andExpect(jsonPath("$.instance").isNotEmpty())
            .andExpect(jsonPath("$.properties.operation_id").isNotEmpty());
    }

    @Test
    @DisplayName("PO-10251 returns active and inactive countries when active is omitted")
    void returnsAllCountriesWhenFilterIsOmitted() throws Exception {
        mockMvc.perform(get("/countries").with(user("test-user")))
            .andExpect(status().isOk())
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
            .andExpect(jsonPath("$.count").value(4))
            .andExpect(jsonPath("$.refData[0].country_name").value("United Kingdom"))
            .andExpect(jsonPath("$.refData[1].country_name").value("Atlantis"))
            .andExpect(jsonPath("$.refData[2].country_name").value("France"))
            .andExpect(jsonPath("$.refData[3].country_name").value("Germany"));
    }

    @Test
    @DisplayName("PO-10251 filters active countries and keeps GBR first")
    void returnsActiveCountries() throws Exception {
        mockMvc.perform(get("/countries").param("active", "true").with(user("test-user")))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.count").value(2))
            .andExpect(jsonPath("$.refData[0].country_name").value("United Kingdom"))
            .andExpect(jsonPath("$.refData[1].country_name").value("France"))
            .andExpect(jsonPath("$.refData[0].active").value(true))
            .andExpect(jsonPath("$.refData[1].active").value(true));
    }

    @Test
    @DisplayName("PO-10251 filters inactive countries alphabetically")
    void returnsInactiveCountries() throws Exception {
        mockMvc.perform(get("/countries").param("active", "false").with(user("test-user")))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.count").value(2))
            .andExpect(jsonPath("$.refData[0].country_name").value("Atlantis"))
            .andExpect(jsonPath("$.refData[1].country_name").value("Germany"))
            .andExpect(jsonPath("$.refData[0].active").value(false))
            .andExpect(jsonPath("$.refData[1].active").value(false));
    }

    @Test
    @DisplayName("PO-10251 orders duplicate non-GBR country names by country ID")
    void ordersDuplicateNonGbrCountryNamesByCountryId() throws Exception {
        jdbcTemplate.update(
            """
                INSERT INTO public.countries (
                    country_id, cjs_code, international_code, gov_code, country_name,
                    demonym, date_used_from, date_used_to, active
                ) VALUES
                    (202, 2202, 'ZZ2', 'Z2', 'Zealand', 'Zealander', DATE '2002-02-02', NULL, TRUE),
                    (201, 2201, 'ZZ1', 'Z1', 'Zealand', 'Zealander', DATE '2001-01-01', NULL, TRUE)
                """
        );

        mockMvc.perform(get("/countries").with(user("test-user")))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.count").value(6))
            .andExpect(jsonPath("$.refData[4].country_id").value(201))
            .andExpect(jsonPath("$.refData[5].country_id").value(202));
    }

    @Test
    @DisplayName("PO-10251 maps all current OpenAPI fields and nullable values")
    void mapsAllOpenApiFields() throws Exception {
        mockMvc.perform(get("/countries").with(user("test-user")))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.refData[2].country_id").value(101))
            .andExpect(jsonPath("$.refData[2].cjs_code").value(2001))
            .andExpect(jsonPath("$.refData[2].international_code").value("FRA"))
            .andExpect(jsonPath("$.refData[2].gov_code").value("FR"))
            .andExpect(jsonPath("$.refData[2].country_name").value("France"))
            .andExpect(jsonPath("$.refData[2].demonym").value("French"))
            .andExpect(jsonPath("$.refData[2].date_used_from").value("2000-01-01"))
            .andExpect(jsonPath("$.refData[2].date_used_to").value(nullValue()))
            .andExpect(jsonPath("$.refData[2].active").value(true))
            .andExpect(jsonPath("$.refData[1].international_code").value(nullValue()))
            .andExpect(jsonPath("$.refData[1].gov_code").value(nullValue()))
            .andExpect(jsonPath("$.refData[1].demonym").value(nullValue()))
            .andExpect(jsonPath("$.refData[3].date_used_to").value("2025-12-31"));
    }

    @Test
    @DisplayName("PO-10251 returns count zero and an empty refData array")
    void returnsEmptyResponse() throws Exception {
        jdbcTemplate.update("DELETE FROM public.countries");

        mockMvc.perform(get("/countries").with(user("test-user")))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.count").value(0))
            .andExpect(jsonPath("$.refData").isArray())
            .andExpect(jsonPath("$.refData").isEmpty());
    }

    @Test
    @DisplayName("PO-10251 rejects a malformed active filter with correlated Problem Details")
    void rejectsMalformedActiveFilter() throws Exception {
        mockMvc.perform(
            get("/countries")
                .param("active", "not-a-boolean")
                .with(user("test-user"))
        )
            .andExpect(status().isNotAcceptable())
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
            .andExpect(jsonPath("$.type").value("https://hmcts.gov.uk/problems/type-mismatch"))
            .andExpect(jsonPath("$.title").value("Not Acceptable"))
            .andExpect(jsonPath("$.detail").value("Invalid parameter value format"))
            .andExpect(jsonPath("$.status").value(406))
            .andExpect(jsonPath("$.instance").isNotEmpty())
            .andExpect(jsonPath("$.operation_id").isNotEmpty())
            .andExpect(jsonPath("$.retriable").value(false))
            .andExpect(jsonPath("$.reason").isNotEmpty());
    }
}
