package uk.gov.hmcts.opal.service.messaging;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.postgresql.util.PSQLException;
import org.postgresql.util.PSQLState;
import org.postgresql.util.ServerErrorMessage;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.dao.QueryTimeoutException;

import java.net.ConnectException;

import static org.assertj.core.api.Assertions.assertThat;

class TransientFailureHelperTest {
    private final TransientFailureHelper helper = new TransientFailureHelper();

    @ParameterizedTest
    @CsvSource({"40001,true", "40P01,true", "55P03,true", "P0001,false", "08006,false", "57014,false"})
    void matchesFinesSqlStates(String state, boolean retry) {
        var sql = new PSQLException(new ServerErrorMessage("SERROR\0C" + state + "\0MSynthetic SQL failure\0"));
        assertThat(helper.isTransientFailure(new IllegalStateException(sql))).isEqualTo(retry);
    }

    @Test
    void matchesResourceTimeoutAndConnectionFailuresButNotUnknownFailures() {
        assertThat(helper.isTransientFailure(new QueryTimeoutException("Synthetic timeout"))).isTrue();
        assertThat(helper.isTransientFailure(new DataAccessResourceFailureException("Synthetic resource"))).isTrue();
        assertThat(helper.isTransientFailure(new IllegalStateException("Synthetic failure"))).isFalse();
        assertThat(helper.isTransientFailure(new IllegalStateException(new PSQLException("Synthetic connection",
            PSQLState.CONNECTION_FAILURE, new ConnectException())))).isTrue();
    }
}
