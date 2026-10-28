package uk.gov.hmcts.opal.repository;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.jdbc.UncategorizedSQLException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import uk.gov.hmcts.opal.mapper.DraftCasefilePublicationMapper;

import java.sql.SQLException;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class DraftCasefileCleanupRepositoryTest {
    private final JdbcTemplate jdbc = mock(JdbcTemplate.class);
    private final NamedParameterJdbcTemplate named = mock(NamedParameterJdbcTemplate.class);
    private final DraftCasefileCleanupRepository repository = new DraftCasefileCleanupRepository(
        named, mock(DraftCasefilePublicationMapper.class));

    @ParameterizedTest
    @ValueSource(strings = {"42501", "42601", "23503"})
    void doesNotMisclassifyOtherSqlFailuresAsRetryable(String sqlState) {
        when(named.getJdbcTemplate()).thenReturn(jdbc);
        var failure = new UncategorizedSQLException("Synthetic operation", "Synthetic SQL",
            new SQLException("Synthetic failure", sqlState));
        doThrow(failure).when(jdbc).execute(anyString());
        assertThatThrownBy(repository::lockPublicationTargetsForCleanup).isSameAs(failure);
    }

    @Test
    void preservesFailuresWithoutSqlCause() {
        when(named.getJdbcTemplate()).thenReturn(jdbc);
        var failure = new DataAccessResourceFailureException("Synthetic unavailable database");
        doThrow(failure).when(jdbc).execute(anyString());
        assertThatThrownBy(repository::lockPublicationTargetsForCleanup).isSameAs(failure);
    }
}
