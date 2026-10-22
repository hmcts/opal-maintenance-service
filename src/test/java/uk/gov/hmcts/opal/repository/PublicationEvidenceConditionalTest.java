package uk.gov.hmcts.opal.repository;

import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import uk.gov.hmcts.opal.service.messaging.PublicationEvidenceWriter;

import static org.assertj.core.api.Assertions.assertThat;

class PublicationEvidenceConditionalTest {

    @ParameterizedTest
    @ValueSource(strings = {"", "opal.testing-support-endpoints.enabled=false"})
    void journalBeansAreAbsentUnlessExplicitlyEnabled(String property) {
        ApplicationContextRunner context = new ApplicationContextRunner()
            .withUserConfiguration(PublicationEvidenceRepository.class, PublicationEvidenceWriter.class);
        if (!property.isEmpty()) {
            context = context.withPropertyValues(property);
        }
        context.run(application -> {
            assertThat(application).doesNotHaveBean(PublicationEvidenceRepository.class);
            assertThat(application).doesNotHaveBean(PublicationEvidenceWriter.class);
        });
    }
}
