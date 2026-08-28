package uk.gov.hmcts.reform.opal.database;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
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
    private static final Path COUNTRIES_PGTAP_TEST =
        Path.of("src/dbUnitTest/countriesTest/countries_pgtap_tests.sql");
    private static final LocalDate DEV_APPLICABILITY_DATE = LocalDate.of(2025, 1, 1);
    private static final List<CountryFixture> EXPECTED_DEV_COUNTRIES = List.of(
        fixture((short) 32001, "GBR", "United Kingdom"),
        fixture((short) 32002, "IRL", "Ireland"),
        fixture((short) 32003, "FRA", "France"),
        fixture((short) 32004, "DEU", "Germany"),
        fixture((short) 32005, "ESP", "Spain"),
        fixture((short) 32006, "ITA", "Italy"),
        fixture((short) 32007, "POL", "Poland"),
        fixture((short) 32008, "USA", "United States"),
        fixture((short) 32009, "IND", "India"),
        fixture((short) 32010, "PAK", "Pakistan")
    );

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

    @Test
    void countriesPgTapContractIsValid() throws Exception {
        assertMigrationApplied("create countries table");

        PgTapTestRunner.run(databaseContainer, COUNTRIES_PGTAP_TEST);
    }

    @Test
    void devCountryFixturesAreAvailable() throws SQLException {
        assertMigrationApplied("insert countries dev data");

        assertThat(readDevCountries()).containsExactlyElementsOf(EXPECTED_DEV_COUNTRIES);
    }

    private List<CountryFixture> readDevCountries() throws SQLException {
        String sql = """
            SELECT cjs_code,
                   international_code,
                   gov_code,
                   country_name,
                   demonym,
                   date_used_from,
                   date_used_to,
                   active
            FROM public.countries
            WHERE cjs_code BETWEEN ? AND ?
            ORDER BY cjs_code
            """;
        List<CountryFixture> fixtures = new ArrayList<>();

        DataSource dataSource = flyway.getConfiguration().getDataSource();
        try (Connection connection = dataSource.getConnection();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setShort(1, (short) 32001);
            statement.setShort(2, (short) 32010);
            try (ResultSet resultSet = statement.executeQuery()) {
                while (resultSet.next()) {
                    fixtures.add(new CountryFixture(
                        resultSet.getShort("cjs_code"),
                        resultSet.getString("international_code"),
                        resultSet.getString("gov_code"),
                        resultSet.getString("country_name"),
                        resultSet.getString("demonym"),
                        resultSet.getObject("date_used_from", LocalDate.class),
                        resultSet.getObject("date_used_to", LocalDate.class),
                        resultSet.getBoolean("active")
                    ));
                }
            }
        }

        return fixtures;
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

    private static CountryFixture fixture(short cjsCode, String internationalCode, String countryName) {
        return new CountryFixture(
            cjsCode,
            internationalCode,
            null,
            countryName,
            null,
            DEV_APPLICABILITY_DATE,
            null,
            true
        );
    }

    private record CountryFixture(
        short cjsCode,
        String internationalCode,
        String govCode,
        String countryName,
        String demonym,
        LocalDate dateUsedFrom,
        LocalDate dateUsedTo,
        boolean active
    ) {
    }
}
