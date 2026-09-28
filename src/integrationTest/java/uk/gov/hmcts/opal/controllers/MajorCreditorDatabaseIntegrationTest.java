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
import java.util.ArrayList;
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
import uk.gov.hmcts.opal.repository.MajorCreditorRepository;

@AutoConfigureMockMvc
@TestPropertySource(properties = {
    "spring.flyway.locations=classpath:db/migration/ddl",
    "management.health.redis.enabled=false",
    "opal.redis.enabled=false",
    "spring.jpa.open-in-view=false"
})
@DirtiesContext(classMode = AFTER_CLASS)
@Sql(scripts = "/db/major-creditor-controller-fixtures.sql", executionPhase = BEFORE_TEST_METHOD)
@Sql(scripts = "/db/major-creditor-controller-cleanup.sql", executionPhase = AFTER_TEST_METHOD)
@DisplayName("PO-10254 GET /major-creditors database integration")
class MajorCreditorDatabaseIntegrationTest extends BaseIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private CacheManager cacheManager;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private MajorCreditorRepository repository;

    @BeforeEach
    @AfterEach
    void clearMajorCreditorCache() {
        Cache cache = cacheManager.getCache("majorCreditorReferenceDataCache");
        if (cache != null) {
            cache.clear();
        }
    }

    static Stream<Arguments> filterCases() {
        return Stream.of(
            Arguments.of(null, null, List.of(5000000001L, 5000000002L, 5000000003L, 5000000004L, 5000000005L)),
            Arguments.of(null, true, List.of(5000000001L, 5000000002L, 5000000004L)),
            Arguments.of(null, false, List.of(5000000003L, 5000000005L)),
            Arguments.of(true, null, List.of(5000000001L, 5000000002L, 5000000003L)),
            Arguments.of(true, true, List.of(5000000001L, 5000000002L)),
            Arguments.of(true, false, List.of(5000000003L)),
            Arguments.of(false, null, List.of(5000000004L, 5000000005L)),
            Arguments.of(false, true, List.of(5000000004L)),
            Arguments.of(false, false, List.of(5000000005L))
        );
    }

    @ParameterizedTest(name = "central_authority={0}, active={1}")
    @MethodSource("filterCases")
    void filtersWithinBusinessUnitAndOrdersByNameThenId(
        Boolean centralAuthority, Boolean active, List<Long> expectedIds
    ) throws Exception {
        JsonNode response = performRequest(31001, centralAuthority, active);

        assertThat(response.size()).isEqualTo(2);
        assertThat(response.path("count").intValue()).isEqualTo(expectedIds.size());
        assertThat(response.path("refData").isArray()).isTrue();
        List<Long> ids = new ArrayList<>();
        for (JsonNode item : response.path("refData")) {
            ids.add(item.path("major_creditor_id").longValue());
            assertThat(item.path("business_unit_id").intValue()).isEqualTo(31001);
            assertThat(item.size()).isEqualTo(16);
        }
        assertThat(ids).containsExactlyElementsOf(expectedIds);
    }

    @Test
    void returnsAllFieldsIncludingInactiveCountryWithoutOpenSessionInView() throws Exception {
        JsonNode item = performRequest(31001, true, true).path("refData").get(0);

        assertThat(item).isEqualTo(objectMapper.readTree("""
            {
              "major_creditor_id": 5000000001,
              "business_unit_id": 31001,
              "major_creditor_code": "T001",
              "name": "Alpha Shared",
              "address_line_1": "Synthetic address 1",
              "address_line_2": "Synthetic line 2",
              "address_line_3": "Synthetic line 3",
              "address_line_4": "Synthetic line 4",
              "address_line_5": "Synthetic line 5",
              "postcode": "ZZ1 1ZZ",
              "country_id": 5000000101,
              "country_name": "Synthetic Country",
              "contact_name": "Synthetic Contact",
              "contact_email": "synthetic@example.invalid",
              "active": true,
              "central_authority": true
            }
            """));
    }

    @Test
    void keepsCreditorWithoutCountryAndEmitsExplicitNullProperties() throws Exception {
        JsonNode item = performRequest(31001, true, true).path("refData").get(1);

        assertThat(item.path("major_creditor_id").longValue()).isEqualTo(5000000002L);
        for (String property : List.of("address_line_2", "address_line_3", "address_line_4", "address_line_5",
                                      "postcode", "country_id", "country_name", "contact_name", "contact_email")) {
            assertThat(item.has(property)).as(property + " is present").isTrue();
            assertThat(item.get(property).isNull()).as(property + " is null").isTrue();
        }
    }

    @Test
    void mapsBigintSmallintAndHundredCharacterNameWithoutTruncation() throws Exception {
        var creditor = repository.findById(5000000005L).orElseThrow();
        assertThat(creditor.getMajorCreditorId()).isEqualTo(5000000005L);
        assertThat(creditor.getBusinessUnitId()).isEqualTo((short) 31001);
        assertThat(creditor.getName()).isEqualTo("Z".repeat(100));
        assertThat(creditor.getActive()).isFalse();
        assertThat(creditor.getCentralAuthority()).isFalse();
        JsonNode item = performRequest(31001, false, false).path("refData").get(0);
        assertThat(item.path("name").textValue()).isEqualTo("Z".repeat(100));
    }

    @Test
    void cacheDoesNotLeakRowsBetweenBusinessUnits() throws Exception {
        performRequest(31001, true, true);
        JsonNode response = performRequest(31002, true, true);
        assertThat(response.path("count").intValue()).isEqualTo(1);
        assertThat(response.path("refData").get(0).path("major_creditor_id").longValue()).isEqualTo(5000000006L);
        assertThat(response.path("refData").get(0).path("business_unit_id").intValue()).isEqualTo(31002);
    }

    @Test
    void returnsEmptyResponseForExistingUnitWithoutCreditors() throws Exception {
        assertEmptyResponse(performRequest(31003, null, null));
    }

    @Test
    void returnsEmptyResponseForUnknownUnit() throws Exception {
        assertEmptyResponse(performRequest(31004, null, null));
    }

    @Test
    void returnsEmptyResponseForFiltersWithoutMatches() throws Exception {
        assertEmptyResponse(performRequest(31002, false, false));
    }

    @Test
    void returnsEmptyResponseWhenCreditorTableIsEmpty() throws Exception {
        jdbcTemplate.update("DELETE FROM public.major_creditors WHERE major_creditor_id BETWEEN ? AND ?",
            5000000001L, 5000000006L);
        assertThat(jdbcTemplate.queryForObject("SELECT COUNT(*) FROM public.major_creditors", Integer.class)).isZero();
        assertEmptyResponse(performRequest(31001, null, null));
    }

    private JsonNode performRequest(int businessUnitId, Boolean centralAuthority, Boolean active) throws Exception {
        MockHttpServletRequestBuilder request = get("/major-creditors")
            .param("business_unit_id", Integer.toString(businessUnitId)).with(user("test-user"));
        if (centralAuthority != null) {
            request.param("central_authority", centralAuthority.toString());
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
        assertThat(response).isEqualTo(objectMapper.createObjectNode()
            .put("count", 0).set("refData", objectMapper.createArrayNode()));
    }
}
