package uk.gov.hmcts.reform.opal.database;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import javax.sql.DataSource;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.context.TestPropertySource;
import uk.gov.hmcts.reform.opal.BaseIntegrationTest;

@TestPropertySource(properties = {
    "spring.flyway.locations=classpath:db/migration/ddl,classpath:db/migration/data/dev"
})
class CountriesDatabaseIntegrationTest extends BaseIntegrationTest {

    private static final Path COUNTRIES_SQL_TEST =
        Path.of("src/dbUnitTest/countriesTest/countries_unit_tests.sql");

    @Autowired
    private Flyway flyway;

    @Test
    void countriesDatabaseContractIsValid() throws Exception {
        assertMigrationApplied("create countries table");
        String contractSql = Files.readString(COUNTRIES_SQL_TEST);

        try (Connection connection = flyway.getConfiguration().getDataSource().getConnection()) {
            connection.setAutoCommit(false);
            try (Statement statement = connection.createStatement()) {
                statement.execute(contractSql);
            } catch (SQLException exception) {
                throw new AssertionError(
                    "Failed SQL contract: " + COUNTRIES_SQL_TEST,
                    exception
                );
            } finally {
                connection.rollback();
            }
        }
    }

    private void assertMigrationApplied(String description) throws SQLException {
        String sql = """
            SELECT count(*) AS migration_count
            FROM flyway_schema_history
            WHERE success = TRUE
              AND description = ?
            """;

        DataSource dataSource = flyway.getConfiguration().getDataSource();
        try (Connection connection = dataSource.getConnection();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, description);
            try (ResultSet resultSet = statement.executeQuery()) {
                assertThat(resultSet.next()).isTrue();
                assertThat(resultSet.getInt("migration_count")).isOne();
            }
        }
    }
}
