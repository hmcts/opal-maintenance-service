package uk.gov.hmcts.opal.support.publication;

import jakarta.jms.JMSException;
import jakarta.jms.Message;
import jakarta.jms.Session;
import org.jspecify.annotations.Nullable;
import org.springframework.jms.listener.DefaultMessageListenerContainer;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;

/** Observes actual local JMS settlement for one owned correlation; never retains private failure causes. */
public final class PublicationQaSettlementContainer extends DefaultMessageListenerContainer {
    private final String correlation;
    private final Runnable beforeCommit;
    private final AtomicInteger settlements = new AtomicInteger();
    private final AtomicInteger rollbacks = new AtomicInteger();
    private final AtomicReference<Failure> failure = new AtomicReference<>();
    private final ThreadLocal<Boolean> ownedDelivery = ThreadLocal.withInitial(() -> false);

    public PublicationQaSettlementContainer(String correlation, Runnable beforeCommit) {
        this.correlation = correlation;
        this.beforeCommit = beforeCommit;
    }

    @Override
    protected void doExecuteListener(Session session, Message message) throws JMSException {
        ownedDelivery.set(owns(message));
        try {
            super.doExecuteListener(session, message);
        } finally {
            ownedDelivery.remove();
        }
    }

    @Override
    protected void commitIfNecessary(Session session, @Nullable Message message) throws JMSException {
        boolean owned = owns(message);
        if (owned) {
            try {
                if (!isSessionTransacted() || !session.getTransacted() || !isSessionLocallyTransacted(session)
                    || TransactionSynchronizationManager.isActualTransactionActive()
                    || TransactionSynchronizationManager.isSynchronizationActive()) {
                    throw new IllegalStateException("Publication settlement requires a local JMS transaction");
                }
                beforeCommit.run();
            } catch (JMSException | RuntimeException | AssertionError observationFailure) {
                recordFailure(Failure.OBSERVATION);
                // Spring's commit hook is outside its listener rollback catch: explicitly preserve real rollback.
                rollbackOnExceptionIfNecessary(session, new IllegalStateException("Publication observation failed"));
                throw new IllegalStateException("Publication observation failed");
            }
        }
        try {
            super.commitIfNecessary(session, message);
        } catch (JMSException commitFailure) {
            recordFailure(Failure.COMMIT);
            throw new JMSException("Publication JMS commit failed");
        } catch (RuntimeException commitFailure) {
            recordFailure(Failure.COMMIT);
            throw new IllegalStateException("Publication JMS commit failed");
        }
        if (owned) {
            settlements.incrementAndGet();
        }
    }

    @Override
    protected void rollbackOnExceptionIfNecessary(Session session, Throwable exception) throws JMSException {
        try {
            boolean local = session.getTransacted() && isSessionLocallyTransacted(session);
            // Pass a safe diagnostic to Spring; its transaction/recover behaviour is unchanged.
            super.rollbackOnExceptionIfNecessary(session,
                new IllegalStateException("Publication delivery rolled back"));
            if (local && ownedDelivery.get()) {
                rollbacks.incrementAndGet();
            }
        } catch (JMSException rollbackFailure) {
            recordFailure(Failure.ROLLBACK);
            throw new JMSException("Publication JMS rollback failed");
        } catch (RuntimeException rollbackFailure) {
            recordFailure(Failure.ROLLBACK);
            throw new IllegalStateException("Publication JMS rollback failed");
        }
    }

    @Override
    protected void handleListenerException(Throwable exception) {
        if (!(exception instanceof Retry)) {
            recordFailure(Failure.LISTENER);
        }
        super.handleListenerException(safe(exception));
    }

    @Override
    protected void handleListenerSetupFailure(Throwable exception, boolean alreadyHandled) {
        recordFailure(Failure.SETUP);
        super.handleListenerSetupFailure(safe(exception), alreadyHandled);
    }

    private Throwable safe(Throwable exception) {
        return exception instanceof JMSException ? new JMSException("Publication JMS transport failed")
            : new IllegalStateException("Publication listener outcome captured");
    }

    private boolean owns(@Nullable Message message) throws JMSException {
        try {
            return message != null && correlation.equals(message.getJMSCorrelationID());
        } catch (JMSException correlationFailure) {
            recordFailure(Failure.CORRELATION);
            throw new JMSException("Publication correlation could not be read");
        }
    }

    public void recordFailure(Failure category) {
        failure.compareAndSet(null, category);
    }

    public int settled() {
        return settlements.get();
    }

    public int rolledBack() {
        return rollbacks.get();
    }

    public void assertHealthy() {
        Failure category = failure.get();
        if (category != null) {
            throw new AssertionError("Publication listener failed: " + category.name());
        }
    }

    public enum Failure { OBSERVATION, COMMIT, ROLLBACK, LISTENER, SETUP, CORRELATION, CALLBACK }

    /** Only constructed after the callback independently verifies the expected retry stage. */
    public static final class Retry extends IllegalStateException {
        public Retry() {
            super("Expected publication retry");
        }
    }
}
