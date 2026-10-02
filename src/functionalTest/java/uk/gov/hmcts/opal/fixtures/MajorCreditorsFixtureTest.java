package uk.gov.hmcts.opal.fixtures;

import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.testcontainers.postgresql.PostgreSQLContainer;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class MajorCreditorsFixtureTest {
    @Test
    void refusesMissingDisposableOptIn() {
        assertThrows(IllegalArgumentException.class, () -> MajorCreditorsFixture.validatedJdbcUrl(Map.of()));
    }

    @Test
    void validatesEverySettingBeforeConnecting() {
        Map<String, String> environment = environment();
        Map<String, String> invalid = Map.of(
            "DISPOSABLE", "false", "HOST", "localhost?user=unsafe", "NAME", "other;DROP DATABASE x",
            "PORT", "65536", "USERNAME", " ", "PASSWORD", " ");
        invalid.forEach((setting, value) -> {
            Map<String, String> changed = new HashMap<>(environment);
            changed.put("FUNCTIONAL_FIXTURE_DB_" + setting, value);
            IllegalArgumentException error = assertThrows(IllegalArgumentException.class,
                () -> MajorCreditorsFixture.validatedJdbcUrl(changed));
            if (!value.isBlank()) {
                assertFalse(error.getMessage().contains(value));
            }
        });
        for (String port : new String[]{"0", "-1", "abc", "2147483648"}) {
            Map<String, String> changed = new HashMap<>(environment);
            changed.put("FUNCTIONAL_FIXTURE_DB_PORT", port);
            assertThrows(IllegalArgumentException.class, () -> MajorCreditorsFixture.validatedJdbcUrl(changed));
        }
        environment.keySet().forEach(key -> {
            Map<String, String> changed = new HashMap<>(environment);
            changed.remove(key);
            assertThrows(IllegalArgumentException.class, () -> MajorCreditorsFixture.validatedJdbcUrl(changed));
        });
    }

    @Test
    void urlContainsOnlyTheValidatedTarget() {
        Map<String, String> environment = environment();
        assertEquals("jdbc:postgresql://localhost:55432/opal_major_creditors_functional",
            MajorCreditorsFixture.validatedJdbcUrl(environment));
        environment.put("FUNCTIONAL_FIXTURE_DB_HOST", "127.0.0.1");
        assertEquals("jdbc:postgresql://127.0.0.1:55432/opal_major_creditors_functional",
            MajorCreditorsFixture.validatedJdbcUrl(environment));
    }

    @Test
    void commitsExactDatasetAndCleansOnlyOwnedRows() throws SQLException {
        try (PostgreSQLContainer database = database()) {
            database.start();
            migrate(database);
            try (Connection observer = connect(database)) {
                sentinel(observer);
                MajorCreditorsFixture fixture = MajorCreditorsFixture.create(environment(database));
                try (fixture) {
                    assertEquals(31010, fixture.businessUnitId());
                    assertEquals(2, fixture.expectedCreditors().size());
                    try (Statement query = observer.createStatement();
                         ResultSet rows = query.executeQuery("""
                             SELECT major_creditor_id, business_unit_id, major_creditor_code, name,
                                 address_line_1, country_id, contact_name, contact_email, active, central_authority
                             FROM public.major_creditors WHERE business_unit_id IN (31010, 31011)
                             ORDER BY major_creditor_code
                             """)) {
                        for (int index = 0; index < 5; index++) {
                            assertTrue(rows.next());
                            assertEquals("F00" + (index + 1), rows.getString("major_creditor_code"));
                            assertEquals(index == 4 ? 31011 : 31010, rows.getShort("business_unit_id"));
                            assertEquals(index != 2, rows.getBoolean("active"));
                            assertEquals(index == 3, rows.getBoolean("central_authority"));
                            if (index < 2) {
                                MajorCreditorsFixture.ExpectedCreditor expected =
                                    fixture.expectedCreditors().get(index);
                                assertEquals(expected.id(), rows.getLong("major_creditor_id"));
                                assertEquals(expected.name(), rows.getString("name"));
                                assertEquals(expected.addressLine1(), rows.getString("address_line_1"));
                                assertEquals(expected.countryId(), rows.getObject("country_id", Long.class));
                                assertEquals(expected.contactName(), rows.getString("contact_name"));
                                assertEquals(expected.contactEmail(), rows.getString("contact_email"));
                            }
                        }
                        assertFalse(rows.next());
                    }
                    assertEquals(1, count(observer, "countries WHERE country_id = 9000101 AND cjs_code = 31010"
                        + " AND country_name = 'Synthetic Functional Country' AND active"
                        + " AND date_used_from = DATE '2000-01-01'"));
                    assertEquals(2, count(observer, "business_units WHERE business_unit_id IN (31010, 31011)"
                        + " AND business_unit_code IN ('ZF10', 'ZF11') AND business_unit_type = 'Area'"
                        + " AND NOT welsh_language"));
                }
                fixture.close();
                assertEquals(0, count(observer, "major_creditors WHERE business_unit_id IN (31010, 31011)"));
                assertEquals(0, count(observer, "countries WHERE country_id = 9000101"));
                assertEquals(0, count(observer, "business_units WHERE business_unit_id IN (31010, 31011)"));
                assertSentinel(observer);
            }
            database.stop();
            assertFalse(database.isRunning());
        }
    }

    @Test
    void occupiedParentRollsBackAllSetupWithoutChangingSentinel() throws SQLException {
        try (PostgreSQLContainer database = database()) {
            database.start();
            migrate(database);
            try (Connection observer = connect(database); Statement insert = observer.createStatement()) {
                sentinel(observer);
                insert.executeUpdate("""
                    INSERT INTO public.countries (country_id, cjs_code, country_name, date_used_from, active)
                    VALUES (9000101, 31009, 'Synthetic occupied country', DATE '2000-01-01', true)
                    """);
                assertThrows(SQLException.class, () -> MajorCreditorsFixture.create(environment(database)));
                assertEquals(0, count(observer, "business_units WHERE business_unit_id IN (31010, 31011)"));
                assertEquals(0, count(observer, "major_creditors WHERE business_unit_id IN (31010, 31011)"));
                assertEquals(1, count(observer, "countries WHERE country_id = 9000101 AND cjs_code = 31009"));
                assertSentinel(observer);
            }
            database.stop();
            assertFalse(database.isRunning());
        }
    }

    @Test
    void cleanupMismatchRollsBackOtherOwnedDeletes() throws SQLException {
        try (PostgreSQLContainer database = database()) {
            database.start();
            migrate(database);
            try (Connection observer = connect(database); Statement delete = observer.createStatement()) {
                MajorCreditorsFixture fixture = MajorCreditorsFixture.create(environment(database));
                delete.executeUpdate("DELETE FROM public.major_creditors WHERE business_unit_id = 31010"
                    + " AND major_creditor_code = 'F002'");
                assertThrows(SQLException.class, fixture::close);
                assertEquals(4, count(observer, "major_creditors WHERE business_unit_id IN (31010, 31011)"));
                assertEquals(2, count(observer, "business_units WHERE business_unit_id IN (31010, 31011)"));
                assertEquals(1, count(observer, "countries WHERE country_id = 9000101"));
            }
            database.stop();
            assertFalse(database.isRunning());
        }
    }

    private static PostgreSQLContainer database() {
        return new PostgreSQLContainer("postgres:17.7")
            .withDatabaseName("opal_major_creditors_functional")
            .withUsername(UUID.randomUUID().toString()).withPassword(UUID.randomUUID().toString());
    }

    private static void migrate(PostgreSQLContainer database) {
        Flyway.configure().dataSource(database.getJdbcUrl(), database.getUsername(), database.getPassword())
            .locations("classpath:db/migration/ddl", "classpath:db/migration/data/allEnvs")
            .baselineOnMigrate(false).load().migrate();
    }

    private static Connection connect(PostgreSQLContainer database) throws SQLException {
        return DriverManager.getConnection(database.getJdbcUrl(), database.getUsername(), database.getPassword());
    }

    private static Map<String, String> environment() {
        Map<String, String> environment = new HashMap<>();
        environment.put("FUNCTIONAL_FIXTURE_DB_DISPOSABLE", "true");
        environment.put("FUNCTIONAL_FIXTURE_DB_HOST", "localhost");
        environment.put("FUNCTIONAL_FIXTURE_DB_PORT", "55432");
        environment.put("FUNCTIONAL_FIXTURE_DB_NAME", "opal_major_creditors_functional");
        environment.put("FUNCTIONAL_FIXTURE_DB_USERNAME", UUID.randomUUID().toString());
        environment.put("FUNCTIONAL_FIXTURE_DB_PASSWORD", UUID.randomUUID().toString());
        return environment;
    }

    private static Map<String, String> environment(PostgreSQLContainer database) {
        Map<String, String> environment = environment();
        environment.put("FUNCTIONAL_FIXTURE_DB_PORT", database.getMappedPort(5432).toString());
        environment.put("FUNCTIONAL_FIXTURE_DB_USERNAME", database.getUsername());
        environment.put("FUNCTIONAL_FIXTURE_DB_PASSWORD", database.getPassword());
        return environment;
    }

    private static int count(Connection connection, String relation) throws SQLException {
        try (Statement query = connection.createStatement();
             ResultSet result = query.executeQuery("SELECT count(*) FROM public." + relation)) {
            result.next();
            return result.getInt(1);
        }
    }

    private static void sentinel(Connection connection) throws SQLException {
        try (Statement insert = connection.createStatement()) {
            insert.executeUpdate("""
                INSERT INTO public.business_units
                    (business_unit_id, business_unit_code, business_unit_name, business_unit_type, welsh_language)
                VALUES (31009, 'ZF09', 'Synthetic sentinel unit', 'Area', false)
                """);
            insert.executeUpdate("""
                INSERT INTO public.countries (country_id, cjs_code, country_name, date_used_from, active)
                VALUES (9000100, 31009, 'Synthetic sentinel country', DATE '2000-01-01', true)
                """);
            insert.executeUpdate("""
                INSERT INTO public.major_creditors
                    (business_unit_id, major_creditor_code, name, address_line_1, country_id, active, central_authority)
                VALUES (31009, 'F000', 'Synthetic sentinel creditor',
                    'Synthetic sentinel address', 9000100, true, false)
                """);
        }
    }

    private static void assertSentinel(Connection connection) throws SQLException {
        assertEquals(1, count(connection, "business_units WHERE business_unit_id = 31009"));
        assertEquals(1, count(connection, "countries WHERE country_id = 9000100"));
        assertEquals(1, count(connection, "major_creditors WHERE business_unit_id = 31009"
            + " AND major_creditor_code = 'F000'"));
    }


}
