package uk.gov.hmcts.opal.service;

import com.zaxxer.hikari.HikariDataSource;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.util.concurrent.Semaphore;

/**
 * Reserves shared-pool capacity for independent publication evidence transactions.
 * Supported entry points start outside a transaction; admission surrounds transaction advice,
 * including commit/rollback and connection cleanup, rather than only the service method body.
 */
@Aspect
@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 10)
@ConditionalOnProperty(prefix = "opal.testing-support-endpoints", name = "enabled", havingValue = "true")
public class DraftCasefileAdmission {

    private final Semaphore permits;

    public DraftCasefileAdmission(HikariDataSource dataSource) {
        int maximum = dataSource.getMaximumPoolSize();
        if (maximum < 2) {
            throw new IllegalStateException("Testing support requires a Hikari maximum pool size of at least 2");
        }
        permits = new Semaphore(maximum - 1, true);
    }

    @Around("execution(public * uk.gov.hmcts.opal.service.DraftCasefileService.*(..))"
        + " || execution(public * uk.gov.hmcts.opal.service.DraftCasefileCleanupService.*(..))"
        + " || execution(public * uk.gov.hmcts.opal.service.PublicationEvidenceService.*(..))")
    public Object admit(ProceedingJoinPoint operation) throws Throwable {
        // Reject ambient/nested transactions before waiting: they may already own a pool connection.
        if (TransactionSynchronizationManager.isActualTransactionActive()
            || TransactionSynchronizationManager.isSynchronizationActive()) {
            throw new IllegalStateException("Testing-support draft operations must enter outside a transaction");
        }
        try {
            permits.acquire();
        } catch (InterruptedException interrupted) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Interrupted while waiting for draft operation admission", interrupted);
        }
        try {
            return operation.proceed();
        } finally {
            permits.release();
        }
    }
}
