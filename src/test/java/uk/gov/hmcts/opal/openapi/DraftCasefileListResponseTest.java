package uk.gov.hmcts.opal.openapi;

import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;
import uk.gov.hmcts.opal.config.JacksonCompatibilityConfiguration;
import uk.gov.hmcts.opal.generated.model.DraftCasefileListResponse;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class DraftCasefileListResponseTest {
    @Test
    void countsOnlyOmitsSummariesAndEmptyNormalIncludesAnArray() throws Exception {
        var compatible = new JacksonCompatibilityConfiguration().objectMapper();
        var runtime = JsonMapper.builder().build();
        var countOnly = new DraftCasefileListResponse().count(0L);
        var normal = new DraftCasefileListResponse().count(0L).summaries(List.of());
        assertThat(compatible.readTree(compatible.writeValueAsString(countOnly)).size()).isEqualTo(1);
        assertThat(compatible.readTree(compatible.writeValueAsString(countOnly)).has("summaries")).isFalse();
        assertThat(runtime.readTree(runtime.writeValueAsString(countOnly)).propertyNames()).containsExactly("count");
        assertThat(runtime.readTree(runtime.writeValueAsString(normal)).get("summaries").isArray()).isTrue();
        assertThat(compatible.readTree(compatible.writeValueAsString(normal)).get("summaries").size()).isZero();
    }
}
