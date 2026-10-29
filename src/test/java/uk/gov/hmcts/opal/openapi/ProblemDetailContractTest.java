package uk.gov.hmcts.opal.openapi;

import static org.assertj.core.api.Assertions.assertThat;

import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.core.io.support.PathMatchingResourcePatternResolver;
import tools.jackson.databind.json.JsonMapper;
import uk.gov.hmcts.opal.generated.model.ProblemDetail;
import uk.gov.hmcts.opal.validator.OpenApiSchemaValidator;

@DisplayName("PO-10251 shared ProblemDetail OpenAPI contract")
class ProblemDetailContractTest {

    @ParameterizedTest
    @ValueSource(strings = {"23e626552a324ac3ab9bc02588fd4fec", "synthetic-correlation-id"})
    @DisplayName("PO-10251 exposes OPAL correlation fields at the top level")
    void exposesTopLevelOpalCorrelationFields(String operationId) throws Exception {
        URI instance = URI.create("https://hmcts.gov.uk/problems/instance/" + operationId);

        ProblemDetail problem = ProblemDetail.builder()
            .type(URI.create("https://hmcts.gov.uk/problems/type-mismatch"))
            .title("Not Acceptable")
            .status(406)
            .detail("Invalid parameter value format")
            .operationId(operationId)
            .instance(instance)
            .retriable(false)
            .properties(Map.of())
            .build();

        assertThat(problem.getOperationId()).isEqualTo(operationId);
        assertThat(problem.getRetriable()).isFalse();

        JsonMapper mapper = JsonMapper.builder().build();
        String json = mapper.writeValueAsString(problem);
        OpenApiSchemaValidator validator = new OpenApiSchemaValidator(new PathMatchingResourcePatternResolver()
            .getResources("classpath*:openapi-bundled.yaml"));
        validator.validate("ProblemDetail", json.getBytes(StandardCharsets.UTF_8));
        ProblemDetail restored = mapper.readValue(json, ProblemDetail.class);
        assertThat(restored.getOperationId()).isEqualTo(operationId);
        assertThat(restored.getInstance()).isEqualTo(instance);
    }
}
