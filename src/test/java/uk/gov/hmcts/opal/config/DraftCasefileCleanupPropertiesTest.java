package uk.gov.hmcts.opal.config;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.boot.context.properties.bind.validation.BindValidationException;
import org.springframework.boot.test.context.assertj.AssertableApplicationContext;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.env.MapPropertySource;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

class DraftCasefileCleanupPropertiesTest {

    private static final String PREFIX = "opal.testing-support-endpoints.draft-casefile-cleanup.";
    private static final String VALIDATION_MESSAGE =
        "Draft Casefile cleanup requires an allowed test environment and automation owner";

    private final ApplicationContextRunner runner = new ApplicationContextRunner()
        .withUserConfiguration(TestConfiguration.class);

    @Test
    void disabledNeedsNoOwnerConfiguration() {
        runner.run(context -> {
            assertThat(context).hasNotFailed();
            assertThat(context.getBean(DraftCasefileCleanupProperties.class).enabled()).isFalse();
        });
    }

    @ParameterizedTest
    @ValueSource(strings = {"local", "integration", "dev", "stg", "staging"})
    void acceptsExplicitTestEnvironment(String environment) {
        enabled(environment).run(context -> assertThat(context).hasNotFailed());
    }

    @ParameterizedTest
    @ValueSource(strings = {"", "prod", "production", "PROD", "preview", "dev-prod"})
    void rejectsUnsafeOrUnknownEnvironment(String environment) {
        enabled(environment).run(this::assertValidationFailure);
    }

    @ParameterizedTest
    @ValueSource(strings = {
        "business-unit-id=", "business-unit-id=0", "user-id=", "user-id=0",
        "business-unit-user-id=", "business-unit-user-id=   ", "business-unit-user-id=123456789012345678901"
    })
    void rejectsInvalidOwner(String override) {
        enabled("local").withPropertyValues(PREFIX + override).run(this::assertValidationFailure);
    }

    @ParameterizedTest
    @ValueSource(strings = {" BUU-1", "BUU-1 ", "\tBUU-1", "BUU-1\t"})
    void rejectsOwnerWithSurroundingWhitespace(String owner) {
        enabled("local").withInitializer(context -> context.getEnvironment().getPropertySources()
            .addFirst(new MapPropertySource("owner", Map.of(PREFIX + "business-unit-user-id", owner))))
            .run(this::assertValidationFailure);
    }

    @Test
    void rejectsMissingEnvironment() {
        runner.withPropertyValues(PREFIX + "enabled=true", PREFIX + "business-unit-id=1",
            PREFIX + "user-id=123", PREFIX + "business-unit-user-id=BUU-1").run(this::assertValidationFailure);
    }

    @Test
    void rejectsProductionWhenDiagnosticsAreDisabled() {
        enabled("production").withPropertyValues("opal.testing-support-endpoints.enabled=false")
            .run(this::assertValidationFailure);
    }

    @Test
    void emptyNumericOverridesBindToNullWhenDisabled() {
        runner.withPropertyValues(PREFIX + "business-unit-id=", PREFIX + "user-id=").run(context -> {
            assertThat(context).hasNotFailed();
            DraftCasefileCleanupProperties properties = context.getBean(DraftCasefileCleanupProperties.class);
            assertThat(properties.businessUnitId()).isNull();
            assertThat(properties.userId()).isNull();
        });
    }

    @Test
    void acceptsMaximumOwnerLength() {
        enabled("local").withPropertyValues(PREFIX + "business-unit-user-id=12345678901234567890")
            .run(context -> assertThat(context).hasNotFailed());
    }

    private ApplicationContextRunner enabled(String environment) {
        return runner.withPropertyValues(PREFIX + "enabled=true", PREFIX + "environment=" + environment,
            PREFIX + "business-unit-id=1", PREFIX + "user-id=123", PREFIX + "business-unit-user-id=BUU-1");
    }

    private void assertValidationFailure(AssertableApplicationContext context) {
        assertThat(context).hasFailed();
        assertThat(context.getStartupFailure()).hasRootCauseInstanceOf(BindValidationException.class)
            .hasStackTraceContaining(VALIDATION_MESSAGE);
    }

    @Configuration(proxyBeanMethods = false)
    @EnableConfigurationProperties(DraftCasefileCleanupProperties.class)
    static class TestConfiguration {
    }
}
