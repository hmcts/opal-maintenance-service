package uk.gov.hmcts.opal.controllers;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.annotation.DirtiesContext.ClassMode.AFTER_CLASS;
import static org.springframework.test.context.jdbc.Sql.ExecutionPhase.AFTER_TEST_METHOD;
import static org.springframework.test.context.jdbc.Sql.ExecutionPhase.BEFORE_TEST_METHOD;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Stream;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
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
import uk.gov.hmcts.opal.BaseIntegrationTest;

@AutoConfigureMockMvc
@TestPropertySource(properties = {
    "spring.flyway.locations=classpath:db/migration/ddl",
    "opal.redis.enabled=false",
    "management.health.redis.enabled=false",
    "spring.jpa.open-in-view=false",
    "opal.test.maintenance-application-db=true"
})
@DirtiesContext(classMode = AFTER_CLASS)
@Sql(scripts = "/db/maintenance-application-controller-fixtures.sql", executionPhase = BEFORE_TEST_METHOD)
@Sql(scripts = "/db/maintenance-application-controller-cleanup.sql", executionPhase = AFTER_TEST_METHOD)
class MaintenanceApplicationDatabaseIntegrationTest extends BaseIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private CacheManager cacheManager;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @BeforeEach
    @AfterEach
    void clearCache() {
        Cache cache = cacheManager.getCache("maintenanceApplicationReferenceDataCache");
        if (cache != null) {
            cache.clear();
        }
    }

    static Stream<Arguments> filterCases() {
        return Stream.of(
            Arguments.of("Create Casefile", null, List.of(32001, 32002, 32003)),
            Arguments.of("Create Casefile", true, List.of(32001, 32003)),
            Arguments.of("Create Casefile", false, List.of(32002)),
            Arguments.of("Other", null, List.of(32004, 32005)),
            Arguments.of("Other", true, List.of(32004)),
            Arguments.of("Other", false, List.of(32005)),
            Arguments.of("Unknown", null, List.of()),
            Arguments.of("create casefile", null, List.of()),
            Arguments.of(" Create Casefile ", null, List.of())
        );
    }

    @ParameterizedTest
    @MethodSource("filterCases")
    void filtersAndOrdersRows(String group, Boolean active, List<Integer> expectedIds) throws Exception {
        var request = get("/maintenance-applications").param("application_group", group).with(user("test-user"));
        if (active != null) {
            request.param("active", active.toString());
        }
        String body = mockMvc.perform(request).andExpect(status().isOk())
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
            .andReturn().getResponse().getContentAsString();
        JsonNode json = objectMapper.readTree(body);
        assertThat(json.size()).isEqualTo(2);
        assertThat(json.path("count").intValue()).isEqualTo(expectedIds.size());
        assertThat(json.path("refData").isArray()).isTrue();
        List<Integer> actualIds = new ArrayList<>();
        for (JsonNode item : json.path("refData")) {
            assertThat(item.size()).isEqualTo(5);
            assertThat(item.has("application_id")).isTrue();
            assertThat(item.has("application_code")).isTrue();
            assertThat(item.has("application_title")).isTrue();
            assertThat(item.path("application_group").textValue()).isEqualTo(group);
            assertThat(item.path("active").isBoolean()).isTrue();
            if (active != null) {
                assertThat(item.path("active").booleanValue()).isEqualTo(active);
            }
            actualIds.add(item.path("application_id").intValue());
        }
        assertThat(actualIds).containsExactlyElementsOf(expectedIds);
    }

    @Test
    void mapsAllFiveFieldsWithoutExposingMetadata() throws Exception {
        mockMvc.perform(get("/maintenance-applications").param("application_group", "Create Casefile")
                .with(user("test-user")))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.refData[0].application_id").value(32001))
            .andExpect(jsonPath("$.refData[0].application_code").value("APP00001"))
            .andExpect(jsonPath("$.refData[0].application_title").value("Alpha"))
            .andExpect(jsonPath("$.refData[0].application_group").value("Create Casefile"))
            .andExpect(jsonPath("$.refData[0].active").value(true));
    }

    @Test
    void preservesDatabaseStringBoundaries() throws Exception {
        jdbcTemplate.update("""
            UPDATE public.maintenance_applications
            SET application_code = ?, application_title = ?, application_group = ?
            WHERE application_id = ?
            """, "ABCDEFGH", "Z".repeat(255), "G".repeat(20), (short) 32003);
        mockMvc.perform(get("/maintenance-applications").param("application_group", "G".repeat(20))
                .with(user("test-user")))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.count").value(1))
            .andExpect(jsonPath("$.refData[0].application_code").value("ABCDEFGH"))
            .andExpect(jsonPath("$.refData[0].application_title").value("Z".repeat(255)));
    }
}
