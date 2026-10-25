package uk.gov.hmcts.opal.support.publication;

import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertTrue;

/** Synchronizations registered inside real transactional service/provider invocations, without SQL identity probes. */
public final class PublicationQaTransactions {
    private final List<Event> events = new ArrayList<>();

    public void observe(String operation) {
        assertTrue(TransactionSynchronizationManager.isActualTransactionActive()
            && TransactionSynchronizationManager.isSynchronizationActive(),
            "Publication observation requires the real Spring transaction");
        Probe existing = TransactionSynchronizationManager.getSynchronizations().stream()
            .filter(Probe.class::isInstance).map(Probe.class::cast).findFirst().orElse(null);
        if (existing != null) {
            assertTrue(existing.operation.equals(operation), "Processing and failure recording must use distinct TXs");
            return;
        }
        Probe probe = new Probe(operation);
        events.add(new Event(probe, "entered"));
        TransactionSynchronizationManager.registerSynchronization(probe);
    }

    public void assertCommitted(String operation) {
        assertTrue(events.stream().anyMatch(event -> event.probe.operation.equals(operation)
            && event.phase.equals("committed")), "Required publication transaction has not committed");
    }

    public void assertRolledBack(String operation) {
        assertTrue(events.stream().anyMatch(event -> event.probe.operation.equals(operation)
            && event.phase.equals("rolled back")), "Required publication transaction has not rolled back");
    }

    public void assertRollbackBeforeFailureCommit() {
        int committed = -1;
        for (int index = 0; index < events.size(); index++) {
            Event event = events.get(index);
            if (event.probe.operation.equals("failure") && event.phase.equals("committed")) {
                committed = index;
            }
        }
        assertTrue(committed >= 0, "Failure recording must commit before consumer return");
        Probe failed = events.get(committed).probe;
        int entered = -1;
        for (int index = 0; index < committed; index++) {
            if (events.get(index).probe == failed && events.get(index).phase.equals("entered")) {
                entered = index;
            }
        }
        assertTrue(entered > 0, "Failure transaction must be entered independently");
        Event previous = events.get(entered - 1);
        assertTrue(previous.probe != failed && previous.probe.operation.equals("processing")
            && previous.phase.equals("rolled back"),
            "Processing afterCompletion(ROLLED_BACK) must precede a distinct failure TX and afterCommit");
    }

    private final class Probe implements TransactionSynchronization {
        private final String operation;

        private Probe(String operation) {
            this.operation = operation;
        }

        @Override
        public void afterCommit() {
            events.add(new Event(this, "committed"));
        }

        @Override
        public void afterCompletion(int status) {
            events.add(new Event(this, status == STATUS_ROLLED_BACK ? "rolled back" : "completed"));
        }
    }

    private record Event(Probe probe, String phase) { }
}
