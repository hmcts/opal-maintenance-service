package uk.gov.hmcts.opal.config;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Import;
import uk.gov.hmcts.opal.authorisation.MaintenanceUserService;
import uk.gov.hmcts.opal.controllers.TestingSupportDraftCasefileController;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.service.DraftCasefileCleanupService;

class DraftCasefileCleanupAvailabilityTest {

    private final ApplicationContextRunner runner = new ApplicationContextRunner()
        .withUserConfiguration(TestConfiguration.class)
        .withBean(MaintenanceUserService.class, () -> mock(MaintenanceUserService.class))
        .withBean(DraftCasefileRepository.class, () -> mock(DraftCasefileRepository.class))
        .withBean(ObjectMapper.class, ObjectMapper::new);

    @ParameterizedTest
    @CsvSource({"false,false,false", "true,false,false", "false,true,false", "true,true,true"})
    void requiresBothFlags(boolean diagnostics, boolean cleanup, boolean expected) {
        runner.withPropertyValues(
            "opal.testing-support-endpoints.enabled=" + diagnostics,
            "opal.testing-support-endpoints.draft-casefile-cleanup.enabled=" + cleanup,
            "opal.testing-support-endpoints.draft-casefile-cleanup.environment=integration",
            "opal.testing-support-endpoints.draft-casefile-cleanup.business-unit-id=1",
            "opal.testing-support-endpoints.draft-casefile-cleanup.user-id=123",
            "opal.testing-support-endpoints.draft-casefile-cleanup.business-unit-user-id=BUU-1")
            .run(context -> {
                assertThat(context).hasNotFailed();
                assertThat(context.getBeansOfType(TestingSupportDraftCasefileController.class))
                    .hasSize(expected ? 1 : 0);
                assertThat(context.getBeansOfType(DraftCasefileCleanupService.class)).hasSize(expected ? 1 : 0);
            });
    }

    @Configuration(proxyBeanMethods = false)
    @Import({TestingSupportDraftCasefileController.class, DraftCasefileCleanupService.class})
    @EnableConfigurationProperties(DraftCasefileCleanupProperties.class)
    static class TestConfiguration {
    }
}
