package uk.gov.hmcts.opal.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.JdbcTemplate;
import uk.gov.hmcts.opal.authorisation.MaintenanceUserService;
import uk.gov.hmcts.opal.controllers.TestingSupportDraftCasefileController;
import uk.gov.hmcts.opal.repository.DraftCasefileRepository;
import uk.gov.hmcts.opal.repository.PublicationEvidenceRepository;
import uk.gov.hmcts.opal.service.DraftCasefileCleanupService;
import uk.gov.hmcts.opal.service.DraftCasefileTestEligibility;
import uk.gov.hmcts.opal.service.DraftCasefileTestScope;
import uk.gov.hmcts.opal.service.PublicationEvidenceService;
import uk.gov.hmcts.opal.service.messaging.DraftCasefileQueuePublisher;
import uk.gov.hmcts.opal.service.messaging.DraftCasefileQueuePublisherImpl;
import uk.gov.hmcts.opal.service.messaging.ObservedDraftCasefileQueuePublisher;
import uk.gov.hmcts.opal.service.messaging.PublicationEvidenceWriter;

import java.time.Clock;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

class DraftCasefileCleanupAvailabilityTest {

    private final ApplicationContextRunner runner = new ApplicationContextRunner()
        .withUserConfiguration(TestConfiguration.class)
        .withBean(MaintenanceUserService.class, () -> mock(MaintenanceUserService.class))
        .withBean(DraftCasefileRepository.class, () -> mock(DraftCasefileRepository.class))
        .withBean(ObjectMapper.class, ObjectMapper::new)
        .withBean(JdbcTemplate.class, () -> mock(JdbcTemplate.class))
        .withBean(Clock.class, Clock::systemUTC)
        .withBean(DraftCasefileQueuePublisherImpl.class, () -> mock(DraftCasefileQueuePublisherImpl.class));

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
                assertThat(context.getBeansOfType(PublicationEvidenceService.class)).hasSize(enabled ? 1 : 0);
                assertThat(context.getBeansOfType(PublicationEvidenceRepository.class)).hasSize(enabled ? 1 : 0);
                assertThat(context.getBeansOfType(PublicationEvidenceWriter.class)).hasSize(enabled ? 1 : 0);
                assertThat(context.getBeansOfType(ObservedDraftCasefileQueuePublisher.class)).hasSize(enabled ? 1 : 0);
                assertThat(context.getBean(DraftCasefileQueuePublisher.class))
                    .isInstanceOf(enabled ? ObservedDraftCasefileQueuePublisher.class
                        : DraftCasefileQueuePublisherImpl.class);
            });
    }

    @Test
    void disabledWhenSharedFlagIsAbsent() {
        runner.run(context -> {
            assertThat(context).hasNotFailed();
            assertThat(context).doesNotHaveBean(TestingSupportDraftCasefileController.class);
            assertThat(context).doesNotHaveBean(DraftCasefileCleanupService.class);
            assertThat(context).doesNotHaveBean(DraftCasefileTestScope.class);
            assertThat(context).doesNotHaveBean(PublicationEvidenceService.class);
            assertThat(context).doesNotHaveBean(PublicationEvidenceRepository.class);
            assertThat(context).doesNotHaveBean(PublicationEvidenceWriter.class);
            assertThat(context).doesNotHaveBean(ObservedDraftCasefileQueuePublisher.class);
        });
    }

    @Configuration(proxyBeanMethods = false)
    @Import({TestingSupportDraftCasefileController.class, DraftCasefileCleanupService.class,
        DraftCasefileTestScope.class, DraftCasefileTestEligibility.class, PublicationEvidenceService.class,
        PublicationEvidenceRepository.class, PublicationEvidenceWriter.class,
        ObservedDraftCasefileQueuePublisher.class})
    static class TestConfiguration {
    }
}
