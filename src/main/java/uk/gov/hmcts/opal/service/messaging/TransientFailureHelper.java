package uk.gov.hmcts.opal.service.messaging;

import org.postgresql.util.PSQLException;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.dao.QueryTimeoutException;
import org.springframework.stereotype.Component;

import java.net.ConnectException;
import java.net.UnknownHostException;

/** Applicable Fines interface-job classifications; unknown processing failures are terminal. */
@Component
public class TransientFailureHelper {
    public boolean isTransientFailure(RuntimeException failure) {
        if (failure instanceof DataAccessResourceFailureException || failure instanceof QueryTimeoutException) {
            return true;
        }
        Throwable current = failure;
        while (current != null) {
            if (current instanceof PSQLException sql) {
                String state = sql.getSQLState();
                return sql.getCause() instanceof ConnectException || sql.getCause() instanceof UnknownHostException
                    || "40001".equals(state) || "40P01".equals(state) || "55P03".equals(state);
            }
            current = current.getCause();
        }
        return false;
    }
}
