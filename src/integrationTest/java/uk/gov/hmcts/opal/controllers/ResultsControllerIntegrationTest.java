package uk.gov.hmcts.opal.controllers;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.reset;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.List;
import java.util.stream.Stream;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.cache.CacheManager;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.web.servlet.mvc.method.annotation.RequestMappingHandlerMapping;
import uk.gov.hmcts.opal.BaseIntegrationTest;
import uk.gov.hmcts.opal.entity.ResultEntity;
import uk.gov.hmcts.opal.repository.ResultRepository;

@AutoConfigureMockMvc
@TestPropertySource(properties = {
    "spring.flyway.locations=classpath:db/migration/ddl",
    "management.health.redis.enabled=false"
})
class ResultsControllerIntegrationTest extends BaseIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private CacheManager cacheManager;

    @Autowired
    @Qualifier("requestMappingHandlerMapping")
    private RequestMappingHandlerMapping handlerMapping;

    @MockitoBean
    private ResultRepository repository;

    @BeforeEach
    void clearResultCacheAndResetRepository() {
        var cache = cacheManager.getCache("resultReferenceDataCache");
        if (cache != null) {
            cache.clear();
        }
        reset(repository);
    }

    static Stream<Arguments> filters() {
        return Stream.of((Boolean) null, Boolean.TRUE, Boolean.FALSE)
            .flatMap(orderTerm -> Stream.of((Boolean) null, Boolean.TRUE, Boolean.FALSE)
                .map(active -> Arguments.of(orderTerm, active)));
    }

    @ParameterizedTest
    @ValueSource(strings = {"order_term", "active"})
    void rejectsMalformedFiltersBeforeRepositoryAccess(String parameter) throws Exception {
        mockMvc.perform(get("/results").param(parameter, "not-a-boolean")
                .with(user("test-user")))
            .andExpect(status().isBadRequest())
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
            .andExpect(jsonPath("$.type").value("https://hmcts.gov.uk/problems/type-mismatch"))
            .andExpect(jsonPath("$.title").value("Bad Request"))
            .andExpect(jsonPath("$.status").value(400))
            .andExpect(jsonPath("$.detail").value("Parameter '" + parameter + "' must be of type Boolean"))
            .andExpect(jsonPath("$.reason").doesNotExist());
        verifyNoInteractions(repository);
    }

    @Test
    void returnsOnlyListFields() throws Exception {
        when(repository.findResults(true, false)).thenReturn(List.of(ResultEntity.builder()
            .resultId("ABC123").resultTitle("Example Result").orderTerm(true).active(false)
            .resultParameters("[]").build()));

        mockMvc.perform(get("/results").param("order_term", "true").param("active", "false")
                .with(user("test-user")))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.count").value(1))
            .andExpect(jsonPath("$.refData[0].result_id").value("ABC123"))
            .andExpect(jsonPath("$.refData[0].result_title").value("Example Result"))
            .andExpect(jsonPath("$.refData[0].order_term").doesNotExist())
            .andExpect(jsonPath("$.refData[0].active").doesNotExist())
            .andExpect(jsonPath("$.refData[0].result_parameters").doesNotExist());
        verify(repository).findResults(true, false);
    }

    @ParameterizedTest
    @MethodSource("filters")
    void preservesOptionalFiltersAtHttpBoundary(Boolean orderTerm, Boolean active) throws Exception {
        when(repository.findResults(orderTerm, active)).thenReturn(List.of());
        var request = get("/results").with(user("test-user"));
        if (orderTerm != null) {
            request.param("order_term", orderTerm.toString());
        }
        if (active != null) {
            request.param("active", active.toString());
        }

        mockMvc.perform(request).andExpect(status().isOk())
            .andExpect(jsonPath("$.count").value(0))
            .andExpect(jsonPath("$.refData").isEmpty());
        verify(repository).findResults(orderTerm, active);
    }

    @Test
    void convertsEmptyBooleanToNull() throws Exception {
        when(repository.findResults(null, null)).thenReturn(List.of());

        mockMvc.perform(get("/results").param("active", "").with(user("test-user")))
            .andExpect(status().isOk());

        verify(repository).findResults(null, null);
    }

    @Test
    void convertsYesBooleanAliasToTrue() throws Exception {
        when(repository.findResults(null, true)).thenReturn(List.of());

        mockMvc.perform(get("/results").param("active", "yes").with(user("test-user")))
            .andExpect(status().isOk());

        verify(repository).findResults(null, true);
    }

    @Test
    void rejectsUnauthenticatedRequests() throws Exception {
        mockMvc.perform(get("/results"))
            .andExpect(status().isUnauthorized())
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
            .andExpect(jsonPath("$.status").value(401));
        verifyNoInteractions(repository);
    }

    @Test
    void preservesNotAcceptableForUnsupportedResponseType() throws Exception {
        mockMvc.perform(get("/results").accept(MediaType.APPLICATION_XML)
                .with(user("test-user")))
            .andExpect(status().isNotAcceptable())
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON));
        verifyNoInteractions(repository);
    }

    @Test
    void registersOnlyTheListOperationOnThisController() {
        var operations = handlerMapping.getHandlerMethods().values().stream()
            .filter(handler -> handler.getBeanType().equals(ResultsApiController.class))
            .map(handler -> handler.getMethod().getName()).toList();

        assertThat(operations).containsExactly("getResults");
    }
}
