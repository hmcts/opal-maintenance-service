package uk.gov.hmcts.reform.opal.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

import static org.assertj.core.api.Assertions.assertThat;

class JacksonCompatibilityConfigurationTest {

    private final ApplicationContextRunner contextRunner = new ApplicationContextRunner()
        .withUserConfiguration(JacksonCompatibilityConfiguration.class);

    @Test
    void shouldCreateMapperWhenApplicationHasNone() {
        contextRunner.run(context -> assertThat(context).hasSingleBean(ObjectMapper.class));
    }

    @Test
    void shouldBackOffWhenApplicationOwnsMapper() {
        ObjectMapper applicationMapper = new ObjectMapper();

        contextRunner
            .withBean(ObjectMapper.class, () -> applicationMapper)
            .run(context -> assertThat(context.getBean(ObjectMapper.class)).isSameAs(applicationMapper));
    }
}
