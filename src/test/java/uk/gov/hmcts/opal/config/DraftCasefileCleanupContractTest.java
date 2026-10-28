package uk.gov.hmcts.opal.config;

import org.junit.jupiter.api.Test;
import org.springframework.core.io.support.PathMatchingResourcePatternResolver;
import org.yaml.snakeyaml.Yaml;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

class DraftCasefileCleanupContractTest {
    @Test
    @SuppressWarnings("unchecked")
    void generatedBundlesExposeOnlyDeleteForDedicatedCleanup() throws Exception {
        var bundles = new PathMatchingResourcePatternResolver().getResources("classpath*:openapi-bundled.yaml");
        assertThat(bundles).isNotEmpty();
        boolean foundCleanup = false;
        for (var bundle : bundles) {
            try (var source = bundle.getInputStream()) {
                Map<String, Object> document = new Yaml().load(source);
                Map<String, Object> paths = (Map<String, Object>) document.get("paths");
                assertThat(paths.keySet()).noneMatch(path -> path.contains("publication-evidence"));
                var cleanup = (Map<String, Object>) paths.get(
                    "/testing-support/draft-casefiles/{draft_casefile_id}");
                if (cleanup != null) {
                    foundCleanup = true;
                    assertThat(cleanup.keySet()).containsExactly("delete");
                    var operation = (Map<String, Object>) cleanup.get("delete");
                    assertThat(operation.get("operationId")).isEqualTo("cleanupDraftCasefile");
                    assertThat(operation.get("security")).isNotNull();
                    assertThat((Map<String, Object>) operation.get("responses"))
                        .containsKeys("204", "400", "401", "403", "404", "409", "500", "503");
                }
                assertThat(document.toString()).doesNotContain("PublicationEvidence", "PublicationObservation");
            }
        }
        assertThat(foundCleanup).isTrue();
    }
}
