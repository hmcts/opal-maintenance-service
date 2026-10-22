package uk.gov.hmcts.opal.config;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Import;
import uk.gov.hmcts.opal.authorisation.MaintenanceUserService;
import uk.gov.hmcts.opal.controllers.TestingSupportDraftCasefileController;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.service.DraftCasefileCleanupService;
import uk.gov.hmcts.opal.service.DraftCasefileTestScope;

class DraftCasefileCleanupAvailabilityTest {

    private final ApplicationContextRunner runner = new ApplicationContextRunner()
        .withUserConfiguration(TestConfiguration.class)
        .withBean(MaintenanceUserService.class, () -> mock(MaintenanceUserService.class))
        .withBean(DraftCasefileRepository.class, () -> mock(DraftCasefileRepository.class))
        .withBean(ObjectMapper.class, ObjectMapper::new);

    @ParameterizedTest
    @ValueSource(booleans = {false, true})
    void followsSharedTestingSupportFlag(boolean enabled) {
        runner.withPropertyValues("opal.testing-support-endpoints.enabled=" + enabled)
            .run(context -> {
                assertThat(context).hasNotFailed();
                assertThat(context.getBeansOfType(TestingSupportDraftCasefileController.class))
                    .hasSize(enabled ? 1 : 0);
                assertThat(context.getBeansOfType(DraftCasefileCleanupService.class)).hasSize(enabled ? 1 : 0);
                assertThat(context.getBeansOfType(DraftCasefileTestScope.class)).hasSize(enabled ? 1 : 0);
            });
    }

    @Test
    void disabledWhenSharedFlagIsAbsent() {
        runner.run(context -> {
            assertThat(context).hasNotFailed();
            assertThat(context).doesNotHaveBean(TestingSupportDraftCasefileController.class);
            assertThat(context).doesNotHaveBean(DraftCasefileCleanupService.class);
            assertThat(context).doesNotHaveBean(DraftCasefileTestScope.class);
        });
    }

    @Configuration(proxyBeanMethods = false)
    @Import({TestingSupportDraftCasefileController.class, DraftCasefileCleanupService.class, DraftCasefileTestScope.class})
    static class TestConfiguration {
    }
}
