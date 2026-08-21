package uk.gov.hmcts.reform.opal.authentication.config.internal;

import org.junit.jupiter.api.Test;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.boot.context.properties.bind.validation.BindValidationException;
import org.springframework.boot.test.context.assertj.AssertableApplicationContext;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.context.annotation.Configuration;

import static org.assertj.core.api.Assertions.assertThat;

class InternalAuthConfigurationPropertiesTest {

    private static final String CLIENT_ID_PROPERTY =
        "spring.security.oauth2.client.registration.internal-azure-ad.client-id";
    private static final String VALIDATION_MESSAGE = "Internal AAD client ID must be configured";

    private final ApplicationContextRunner contextRunner = new ApplicationContextRunner()
        .withUserConfiguration(TestConfiguration.class);

    @Test
    void rejectsMissingClientId() {
        contextRunner.run(this::assertClientIdValidationFailure);
    }

    @Test
    void rejectsBlankClientId() {
        contextRunner
            .withPropertyValues(CLIENT_ID_PROPERTY + "=")
            .run(this::assertClientIdValidationFailure);
    }

    @Test
    void rejectsWhitespaceClientId() {
        contextRunner
            .withPropertyValues(CLIENT_ID_PROPERTY + "=   ")
            .run(this::assertClientIdValidationFailure);
    }

    @Test
    void preservesNonBlankClientId() {
        contextRunner
            .withPropertyValues(CLIENT_ID_PROPERTY + "=test-client-id")
            .run(context -> {
                assertThat(context).hasNotFailed();
                assertThat(context.getBean(InternalAuthConfigurationProperties.class).getClientId())
                    .isEqualTo("test-client-id");
            });
    }

    private void assertClientIdValidationFailure(AssertableApplicationContext context) {
        assertThat(context).hasFailed();
        assertThat(context.getStartupFailure())
            .hasRootCauseInstanceOf(BindValidationException.class)
            .hasStackTraceContaining(VALIDATION_MESSAGE);
    }

    @Configuration(proxyBeanMethods = false)
    @EnableConfigurationProperties(InternalAuthConfigurationProperties.class)
    static class TestConfiguration {
    }
}
