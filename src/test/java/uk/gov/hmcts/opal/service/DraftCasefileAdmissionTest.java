package uk.gov.hmcts.opal.service;

import com.zaxxer.hikari.HikariDataSource;
import org.aspectj.lang.ProceedingJoinPoint;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class DraftCasefileAdmissionTest {

    @ParameterizedTest
    @ValueSource(booleans = {false, true})
    void insufficientPoolFailsStartupOnlyWhenSupportEnabled(boolean enabled) {
        new ApplicationContextRunner().withUserConfiguration(DraftCasefileAdmission.class)
            .withBean(HikariDataSource.class, () -> pool(1))
            .withPropertyValues("opal.testing-support-endpoints.enabled=" + enabled).run(context -> {
                if (enabled) {
                    assertThat(context).hasFailed();
                    assertThat(context.getStartupFailure()).hasRootCauseInstanceOf(IllegalStateException.class)
                        .hasRootCauseMessage("Testing support requires a Hikari maximum pool size of at least 2");
                } else {
                    assertThat(context).hasNotFailed().doesNotHaveBean(DraftCasefileAdmission.class);
                }
            });
    }

    @Test
    void absentFlagDoesNotRequirePoolOrGuard() {
        new ApplicationContextRunner().withUserConfiguration(DraftCasefileAdmission.class).run(context ->
            assertThat(context).hasNotFailed().doesNotHaveBean(DraftCasefileAdmission.class));
    }

    @ParameterizedTest
    @ValueSource(booleans = {false, true})
    void completionAndFailureReleaseOnlyPermit(boolean fail) throws Throwable {
        try (HikariDataSource pool = pool(2)) {
            DraftCasefileAdmission admission = new DraftCasefileAdmission(pool);
            ProceedingJoinPoint operation = mock(ProceedingJoinPoint.class);
            if (fail) {
                when(operation.proceed()).thenThrow(new IllegalArgumentException("Synthetic operation failure"));
                assertThatThrownBy(() -> admission.admit(operation)).isInstanceOf(IllegalArgumentException.class);
            } else {
                when(operation.proceed()).thenReturn("completed");
                assertThat(admission.admit(operation)).isEqualTo("completed");
            }
            assertNextCallCompletes(admission);
        }
    }

    @Test
    void interruptedAdmissionDoesNotProceedAndRestoresInterrupt() throws Throwable {
        try (HikariDataSource pool = pool(2)) {
            DraftCasefileAdmission admission = new DraftCasefileAdmission(pool);
            ProceedingJoinPoint operation = mock(ProceedingJoinPoint.class);
            Thread.currentThread().interrupt();
            try {
                assertThatThrownBy(() -> admission.admit(operation)).isInstanceOf(IllegalStateException.class)
                    .hasCauseInstanceOf(InterruptedException.class);
                assertThat(Thread.currentThread().isInterrupted()).isTrue();
                verifyNoInteractions(operation);
            } finally {
                Thread.interrupted();
            }
            assertNextCallCompletes(admission);
        }
    }

    @Test
    void synchronizationWithoutActualTransactionAlsoFailsBeforeAdmission() {
        try (HikariDataSource pool = pool(2)) {
            DraftCasefileAdmission admission = new DraftCasefileAdmission(pool);
            ProceedingJoinPoint operation = mock(ProceedingJoinPoint.class);
            TransactionSynchronizationManager.initSynchronization();
            try {
                assertThatThrownBy(() -> admission.admit(operation)).isInstanceOf(IllegalStateException.class)
                    .hasMessage("Testing-support draft operations must enter outside a transaction");
                verifyNoInteractions(operation);
            } finally {
                TransactionSynchronizationManager.clearSynchronization();
            }
        }
    }

    private void assertNextCallCompletes(DraftCasefileAdmission admission) throws Throwable {
        ProceedingJoinPoint next = mock(ProceedingJoinPoint.class);
        when(next.proceed()).thenReturn("next");
        var executor = Executors.newSingleThreadExecutor();
        try {
            var result = executor.submit(() -> {
                try {
                    return admission.admit(next);
                } catch (Throwable failure) {
                    throw new AssertionError(failure);
                }
            });
            assertThat(result.get(5, TimeUnit.SECONDS)).isEqualTo("next");
        } finally {
            executor.shutdownNow();
            assertThat(executor.awaitTermination(5, TimeUnit.SECONDS)).isTrue();
        }
    }

    private HikariDataSource pool(int maximum) {
        HikariDataSource pool = new HikariDataSource();
        pool.setMaximumPoolSize(maximum);
        return pool;
    }
}
