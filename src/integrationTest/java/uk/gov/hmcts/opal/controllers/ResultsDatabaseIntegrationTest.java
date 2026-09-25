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
import java.util.List;
import java.util.stream.Stream;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;
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
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.repository.ResultRepository;

@AutoConfigureMockMvc
@TestPropertySource(properties = {
    "spring.flyway.locations=classpath:db/migration/ddl",
    "management.health.redis.enabled=false",
    "opal.redis.enabled=false"
})
@DirtiesContext(classMode = AFTER_CLASS)
@Sql(scripts = "/db/results-controller-fixtures.sql", executionPhase = BEFORE_TEST_METHOD)
@Sql(scripts = "/db/results-controller-cleanup.sql", executionPhase = AFTER_TEST_METHOD)
@DisplayName("PO-10256 GET /results database integration")
class ResultsDatabaseIntegrationTest extends BaseIntegrationTest {

    private static final String SIXTY_CHARACTER_TITLE = "Z".repeat(60);

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private CacheManager cacheManager;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private ResultRepository repository;

    @BeforeEach
    @AfterEach
    void clearResultCache() {
        Cache cache = cacheManager.getCache("resultReferenceDataCache");
        if (cache != null) {
            cache.clear();
        }
    }

    static Stream<Arguments> filterCases() {
        return Stream.of(
            Arguments.of(null, null, List.of(
                result("OTAF01", "Alpha Order Inactive"),
                result("NOAT01", "Bravo Non Order Active"),
                result("NOAF01", "Charlie Non Order Inactive"),
                result("OTAT01", "Delta Shared Active Order"),
                result("OTAT02", "Delta Shared Active Order"),
                result("NOAT02", "Echo Non Order Active"),
                result("OTAF02", "Foxtrot Order Inactive"),
                result("NOAF02", SIXTY_CHARACTER_TITLE)
            )),
            Arguments.of(null, true, List.of(
                result("NOAT01", "Bravo Non Order Active"),
                result("OTAT01", "Delta Shared Active Order"),
                result("OTAT02", "Delta Shared Active Order"),
                result("NOAT02", "Echo Non Order Active")
            )),
            Arguments.of(null, false, List.of(
                result("OTAF01", "Alpha Order Inactive"),
                result("NOAF01", "Charlie Non Order Inactive"),
                result("OTAF02", "Foxtrot Order Inactive"),
                result("NOAF02", SIXTY_CHARACTER_TITLE)
            )),
            Arguments.of(true, null, List.of(
                result("OTAF01", "Alpha Order Inactive"),
                result("OTAT01", "Delta Shared Active Order"),
                result("OTAT02", "Delta Shared Active Order"),
                result("OTAF02", "Foxtrot Order Inactive")
            )),
            Arguments.of(true, true, List.of(
                result("OTAT01", "Delta Shared Active Order"),
                result("OTAT02", "Delta Shared Active Order")
            )),
            Arguments.of(true, false, List.of(
                result("OTAF01", "Alpha Order Inactive"),
                result("OTAF02", "Foxtrot Order Inactive")
            )),
            Arguments.of(false, null, List.of(
                result("NOAT01", "Bravo Non Order Active"),
                result("NOAF01", "Charlie Non Order Inactive"),
                result("NOAT02", "Echo Non Order Active"),
                result("NOAF02", SIXTY_CHARACTER_TITLE)
            )),
            Arguments.of(false, true, List.of(
                result("NOAT01", "Bravo Non Order Active"),
                result("NOAT02", "Echo Non Order Active")
            )),
            Arguments.of(false, false, List.of(
                result("NOAF01", "Charlie Non Order Inactive"),
                result("NOAF02", SIXTY_CHARACTER_TITLE)
            ))
        );
    }

    @ParameterizedTest(name = "order_term={0}, active={1}")
    @MethodSource("filterCases")
    void filtersAndProjectsRowsFromPostgresql(
        Boolean orderTerm, Boolean active, List<ExpectedResult> expectedResults
    ) throws Exception {
        JsonNode response = performRequest(orderTerm, active);

        assertThat(response.size()).isEqualTo(2);
        assertThat(response.path("count").isInt()).isTrue();
        assertThat(response.path("count").intValue()).isEqualTo(expectedResults.size());
        assertThat(response.path("refData").isArray()).isTrue();
        assertThat(response.path("refData")).hasSize(expectedResults.size());

        for (int index = 0; index < expectedResults.size(); index++) {
            JsonNode item = response.path("refData").get(index);
            ExpectedResult expected = expectedResults.get(index);
            assertThat(item.size()).isEqualTo(2);
            assertThat(item.path("result_id").textValue()).isEqualTo(expected.id());
            assertThat(item.path("result_title").textValue()).isEqualTo(expected.title());
        }
    }

    @Test
    void mapsAssignedStringIdTitleAndBooleanColumns() {
        var result = repository.findById("NOAF02").orElseThrow();

        assertThat(result.getResultId()).isEqualTo("NOAF02");
        assertThat(result.getResultTitle()).isEqualTo(SIXTY_CHARACTER_TITLE);
        assertThat(result.getOrderTerm()).isFalse();
        assertThat(result.getActive()).isFalse();
    }

    @Test
    void returnsEmptyResponseForValidFiltersWithNoMatchingRows() throws Exception {
        jdbcTemplate.update("DELETE FROM public.results WHERE result_id IN ('OTAF01', 'OTAF02')");

        assertEmptyResponse(performRequest(true, false));
    }

    @Test
    void returnsEmptyResponseWhenResultsTableIsEmpty() throws Exception {
        jdbcTemplate.update("""
            DELETE FROM public.results
            WHERE result_id IN ('OTAF01', 'NOAT01', 'NOAF01', 'OTAT02', 'OTAT01', 'NOAT02', 'OTAF02', 'NOAF02')
            """);
        assertThat(jdbcTemplate.queryForObject("SELECT COUNT(*) FROM public.results", Integer.class)).isZero();

        assertEmptyResponse(performRequest(null, null));
    }

    private JsonNode performRequest(Boolean orderTerm, Boolean active) throws Exception {
        MockHttpServletRequestBuilder request = get("/results").with(user("test-user"));
        if (orderTerm != null) {
            request.param("order_term", orderTerm.toString());
        }
        if (active != null) {
            request.param("active", active.toString());
        }

        String responseBody = mockMvc.perform(request)
            .andExpect(status().isOk())
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
            .andReturn().getResponse().getContentAsString();
        return objectMapper.readTree(responseBody);
    }

    private void assertEmptyResponse(JsonNode response) {
        assertThat(response.size()).isEqualTo(2);
        assertThat(response.path("count").isInt()).isTrue();
        assertThat(response.path("count").intValue()).isZero();
        assertThat(response.path("refData").isArray()).isTrue();
        assertThat(response.path("refData")).isEmpty();
    }

    private static ExpectedResult result(String id, String title) {
        return new ExpectedResult(id, title);
    }

    private record ExpectedResult(String id, String title) {
    }
}
