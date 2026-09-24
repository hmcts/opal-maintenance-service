package uk.gov.hmcts.opal.controllers;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.annotation.DirtiesContext.ClassMode.AFTER_CLASS;
import static org.springframework.test.context.jdbc.Sql.ExecutionPhase.AFTER_TEST_METHOD;
import static org.springframework.test.context.jdbc.Sql.ExecutionPhase.BEFORE_TEST_METHOD;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.cache.Cache;
import org.springframework.cache.CacheManager;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.jdbc.Sql;
import org.springframework.test.web.servlet.MockMvc;
import uk.gov.hmcts.opal.BaseIntegrationTest;

@AutoConfigureMockMvc
@TestPropertySource(properties = {
    "spring.flyway.locations=classpath:db/migration/ddl",
    "management.health.redis.enabled=false",
    "opal.redis.enabled=false",
    "spring.jpa.open-in-view=false",
    "opal.test.result-detail=true"
})
@DirtiesContext(classMode = AFTER_CLASS)
@Sql(scripts = "/db/results-controller-fixtures.sql", executionPhase = BEFORE_TEST_METHOD)
@Sql(scripts = "/db/results-controller-cleanup.sql", executionPhase = AFTER_TEST_METHOD)
@DisplayName("PO-10255 GET /results/{id} database integration")
class ResultDatabaseIntegrationTest extends BaseIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private CacheManager cacheManager;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @BeforeEach
    @AfterEach
    void clearCaches() {
        for (String name : new String[] {"resultReferenceDataCache", "resultDetailCache"}) {
            Cache cache = cacheManager.getCache(name);
            if (cache != null) {
                cache.clear();
            }
        }
    }

    @ParameterizedTest
    @ValueSource(strings = {"OTAT01", "OTAF01", "NOAT01", "NOAF01"})
    void returnsResultRegardlessOfActiveOrOrderTerm(String id) throws Exception {
        JsonNode json = getResult(id);
        assertThat(json.size()).isEqualTo(3);
        assertThat(json.path("result_id").asText()).isEqualTo(id);
        assertThat(json.path("result_title").asText()).isEqualTo(jdbcTemplate.queryForObject(
            "SELECT result_title FROM public.results WHERE result_id = ?", String.class, id));
    }

    @Test
    void includesExplicitSqlNullMetadata() throws Exception {
        JsonNode json = getResult("NOAT01");
        assertThat(json.has("result_parameters")).isTrue();
        assertThat(json.get("result_parameters").isNull()).isTrue();
        assertThat(json.size()).isEqualTo(3);
    }

    @ParameterizedTest
    @ValueSource(strings = {"[]", "[{\"name\":\"reason\"}]", "{\"x\":1}", "true", "null",
        "{ \"spaced\": [1, 2], \"escaped\": \"a\\n\" }"})
    void returnsJsonAsAnUnchangedString(String metadata) throws Exception {
        jdbcTemplate.update("UPDATE public.results SET result_parameters = ?::json WHERE result_id = ?",
            metadata, "NOAF01");
        JsonNode json = getResult("NOAF01");
        assertThat(json.path("result_parameters").isTextual()).isTrue();
        assertThat(json.path("result_parameters").asText()).isEqualTo(metadata);
    }

    @Test
    void returnsNotFoundForMissingId() throws Exception {
        mockMvc.perform(get("/results/ABSENT").with(user("test-user")))
            .andExpect(status().isNotFound())
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON));
    }

    private JsonNode getResult(String id) throws Exception {
        String body = mockMvc.perform(get("/results/{id}", id).with(user("test-user")))
            .andExpect(status().isOk())
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
            .andReturn().getResponse().getContentAsString();
        return objectMapper.readTree(body);
    }
}
