package uk.gov.hmcts.opal.support.publication;

import jakarta.jms.ConnectionFactory;
import jakarta.jms.JMSException;
import jakarta.jms.Message;
import jakarta.jms.Session;
import org.junit.jupiter.api.Test;

import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** Mock JMS boundaries verify instrumentation only; these are not actual broker settlement evidence. */
class PublicationQaSettlementContainerTest {
    @Test
    void idleCommitDoesNotObserveOrCountOwnedSettlement() throws Exception {
        AtomicInteger observations = new AtomicInteger();
        var container = container(observations::incrementAndGet);
        Session session = session();
        container.commitIfNecessary(session, null);
        assertEquals(0, observations.get());
        assertEquals(0, container.settled());
        verify(session).commit();
    }

    @Test
    void mismatchedCommitDoesNotObserveOrCountOwnedSettlement() throws Exception {
        AtomicInteger observations = new AtomicInteger();
        var container = container(observations::incrementAndGet);
        Session session = session();
        Message message = message("someone-else");
        container.commitIfNecessary(session, message);
        assertEquals(0, observations.get());
        assertEquals(0, container.settled());
        verify(session).commit();
    }

    @Test
    void observesBeforeActualCommitAndCountsOnlyAfterItReturns() throws Exception {
        AtomicInteger observations = new AtomicInteger();
        var container = container(observations::incrementAndGet);
        Session session = session();
        doAnswer(invocation -> {
            assertEquals(1, observations.get());
            assertEquals(0, container.settled());
            return null;
        }).when(session).commit();
        container.commitIfNecessary(session, message("owned"));
        assertEquals(1, observations.get());
        assertEquals(1, container.settled());
        container.assertHealthy();
    }

    @Test
    void commitFailureIsNotCountedAndSurfacesSafely() throws Exception {
        var container = container(() -> { });
        Session session = session();
        doThrow(new JMSException("Private transport diagnostic")).when(session).commit();
        assertThrows(JMSException.class, () -> container.commitIfNecessary(session, message("owned")));
        assertEquals(0, container.settled());
        assertSafeFailure(container, "COMMIT");
    }

    @Test
    void oracleFailureCapturesCategoryAndActuallyRollsBack() throws Exception {
        var container = container(() -> {
            throw new AssertionError("Private oracle values");
        });
        Session session = session();
        AtomicReference<Throwable> propagated = new AtomicReference<>();
        Thread listener = new Thread(() -> {
            try {
                container.commitIfNecessary(session, message("owned"));
            } catch (JMSException | RuntimeException failure) {
                propagated.set(failure);
            }
        });
        listener.start();
        listener.join(5_000);
        assertTrue(!listener.isAlive(), "Instrumentation worker must terminate");
        assertTrue(propagated.get() instanceof IllegalStateException);
        assertEquals("Publication observation failed", propagated.get().getMessage());
        assertTrue(propagated.get().getCause() == null);
        verify(session).rollback();
        verify(session, never()).commit();
        assertEquals(0, container.settled());
        assertSafeFailure(container, "OBSERVATION");
    }

    @Test
    void callbackFailureDelegatesActualRollbackWithoutCountingSettlement() throws Exception {
        var container = container(() -> { });
        container.setMessageListener((jakarta.jms.MessageListener) message -> {
            throw new PublicationQaSettlementContainer.Retry();
        });
        Session session = session();
        assertThrows(PublicationQaSettlementContainer.Retry.class,
            () -> container.doExecuteListener(session, message("owned")));
        verify(session).rollback();
        verify(session, never()).commit();
        assertEquals(1, container.rolledBack());
        assertEquals(0, container.settled());
        container.assertHealthy();
    }

    @Test
    void callbackReturnAloneIsNotSettlement() throws Exception {
        AtomicInteger callbacks = new AtomicInteger();
        var container = container(() -> {
            throw new AssertionError("Oracle disagrees");
        });
        container.setMessageListener((jakarta.jms.MessageListener) message -> callbacks.incrementAndGet());
        Session session = session();
        assertThrows(IllegalStateException.class,
            () -> container.doExecuteListener(session, message("owned")));
        assertEquals(1, callbacks.get());
        assertEquals(0, container.settled());
        verify(session).rollback();
        assertSafeFailure(container, "OBSERVATION");
    }

    @Test
    void nonLocalSessionCannotBecomeSettlementEvidence() throws Exception {
        var container = container(() -> { });
        container.setSessionTransacted(false);
        Session session = session();
        assertThrows(IllegalStateException.class,
            () -> container.commitIfNecessary(session, message("owned")));
        assertEquals(0, container.settled());
        verify(session, never()).commit();
        assertSafeFailure(container, "OBSERVATION");
    }

    private PublicationQaSettlementContainer container(Runnable beforeCommit) {
        var container = new PublicationQaSettlementContainer("owned", beforeCommit);
        container.setConnectionFactory(mock(ConnectionFactory.class));
        container.setSessionTransacted(true);
        container.setAcceptMessagesWhileStopping(true);
        return container;
    }

    private Session session() throws JMSException {
        Session session = mock(Session.class);
        when(session.getTransacted()).thenReturn(true);
        return session;
    }

    private Message message(String correlation) throws JMSException {
        Message message = mock(Message.class);
        when(message.getJMSCorrelationID()).thenReturn(correlation);
        return message;
    }

    private void assertSafeFailure(PublicationQaSettlementContainer container, String category) {
        AssertionError failure = assertThrows(AssertionError.class, container::assertHealthy);
        assertEquals("Publication listener failed: " + category, failure.getMessage());
        assertTrue(failure.getCause() == null);
    }
}
