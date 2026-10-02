package uk.gov.hmcts.opal.steps;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;


@Testcontainers
class CentralAuthorityFixturesTest {

    @Container
    private static final PostgreSQLContainer DATABASE = new PostgreSQLContainer("postgres:17")
        .withDatabaseName("po10294_fixture_tests")
        .withUsername(UUID.randomUUID().toString())
        .withPassword(UUID.randomUUID().toString());

    private String runId;

    @BeforeEach
    void prepareDisposableDatabase() throws SQLException {
        Flyway.configure().dataSource(targetUrl(), DATABASE.getUsername(), DATABASE.getPassword())
            .locations("classpath:db/migration/ddl").load().migrate();
        runId = UUID.randomUUID().toString();
        try (Connection connection = connect(); Statement statement = connection.createStatement()) {
            statement.execute("DROP TABLE IF EXISTS public.po10294_cleanup_blocker");
            statement.execute("ALTER TABLE public.major_creditors DROP CONSTRAINT IF EXISTS fixture_setup_failure");
            statement.execute("DELETE FROM public.major_creditors");
            statement.execute("DELETE FROM public.business_units");
            statement.execute("DROP TABLE IF EXISTS public.po10294_fixture_owner");
            statement.execute("CREATE TABLE public.po10294_fixture_owner (run_id UUID PRIMARY KEY)");
            statement.execute("DROP SEQUENCE IF EXISTS public.po10294_fixture_business_unit_id_seq");
            statement.execute("CREATE SEQUENCE public.po10294_fixture_business_unit_id_seq "
                + "MINVALUE 30000 MAXVALUE 32767 START WITH 30000 NO CYCLE");
            try (PreparedStatement owner = connection.prepareStatement(
                "INSERT INTO public.po10294_fixture_owner VALUES (?::uuid)")) {
                owner.setString(1, runId);
                owner.executeUpdate();
            }
        }
    }

    @ParameterizedTest
    @ValueSource(strings = {"PO10294_FIXTURE_JDBC_URL", "PO10294_FIXTURE_DB_USER",
        "PO10294_FIXTURE_DB_PASSWORD", "PO10294_FIXTURE_RUN_ID"})
    void rejectsMissingConfigurationWithoutMutation(String missing) throws SQLException {
        insertUnrelatedUnit();
        Map<String, String> configuration = configuration();
        configuration.remove(missing);
        assertThrows(IllegalArgumentException.class, () -> CentralAuthorityFixtures.create(configuration));
        assertEquals(1, count("business_units"));
        assertEquals(1, count("major_creditors"));
    }

    @ParameterizedTest
    @ValueSource(strings = {"jdbc:postgresql://example.invalid:5432/po10294_tests",
        "jdbc:postgresql://127.0.0.2:5432/po10294_tests", "jdbc:postgresql://localhost:5432/opal",
        "jdbc:postgresql://localhost:5432/po10294_tests?options=-csearch_path=other",
        "jdbc:postgresql://localhost:5432/po10294_tests?host=example.invalid",
        "jdbc:postgresql://localhost:5432/po10294_tests?ssl=false",
        "jdbc:postgresql://localhost:5432,example.invalid:5432/po10294_tests",
        "jdbc:postgresql:po10294_tests", "jdbc:postgresql://localhost:5432/po10294_tests/other"})
    void rejectsUnsafeTargetBeforeConnecting(String url) throws SQLException {
        insertUnrelatedUnit();
        Map<String, String> configuration = configuration();
        configuration.put("PO10294_FIXTURE_JDBC_URL", url);
        assertThrows(IllegalArgumentException.class, () -> CentralAuthorityFixtures.create(configuration));
        assertEquals(1, count("business_units"));
        assertEquals(1, count("major_creditors"));
    }

    @ParameterizedTest
    @ValueSource(strings = {"invalid", "1-1-1-1-1", ""})
    void rejectsMalformedRunIdBeforeConnecting(String invalidRunId) throws SQLException {
        insertUnrelatedUnit();
        Map<String, String> configuration = configuration();
        configuration.put("PO10294_FIXTURE_RUN_ID", invalidRunId);
        assertThrows(IllegalArgumentException.class, () -> CentralAuthorityFixtures.create(configuration));
        assertEquals(1, count("business_units"));
        assertEquals(1, count("major_creditors"));
    }

    @Test
    void rejectsMissingOwnershipMarkerAndClosesConnection() throws SQLException {
        insertUnrelatedUnit();
        try (Connection admin = connect(); Statement statement = admin.createStatement()) {
            statement.execute("DROP TABLE public.po10294_fixture_owner");
        }
        Connection connection = connect();
        assertThrows(SQLException.class, () -> CentralAuthorityFixtures.create(connection, runId));
        assertTrue(connection.isClosed());
        assertEquals(1, count("business_units"));
        assertEquals(1, count("major_creditors"));
    }

    @Test
    void rejectsMismatchedOwnershipAndClosesConnection() throws SQLException {
        insertUnrelatedUnit();
        Connection connection = connect();
        assertThrows(IllegalArgumentException.class,
            () -> CentralAuthorityFixtures.create(connection, UUID.randomUUID().toString()));
        assertTrue(connection.isClosed());
        assertEquals(1, count("business_units"));
        assertEquals(1, count("major_creditors"));
    }

    @ParameterizedTest
    @ValueSource(strings = {"DROP SEQUENCE public.po10294_fixture_business_unit_id_seq",
        "ALTER SEQUENCE public.po10294_fixture_business_unit_id_seq CYCLE",
        "ALTER SEQUENCE public.po10294_fixture_business_unit_id_seq MINVALUE 1"})
    void rejectsUnsafeAllocationBeforeMutation(String alteration) throws SQLException {
        insertUnrelatedUnit();
        try (Connection admin = connect(); Statement statement = admin.createStatement()) {
            statement.execute(alteration);
        }
        Connection connection = connect();
        assertThrows(IllegalArgumentException.class, () -> CentralAuthorityFixtures.create(connection, runId));
        assertTrue(connection.isClosed());
        assertEquals(1, count("business_units"));
        assertEquals(1, count("major_creditors"));
    }

    @Test
    void commitsIncludedAndExcludedRowsThenCleansOnlyOwnedRecords() throws SQLException {
        insertUnrelatedUnit();
        Connection fixtureConnection = connect();
        CentralAuthorityFixtures fixture = CentralAuthorityFixtures.create(fixtureConnection, runId);
        try (Connection observer = connect(); PreparedStatement query = observer.prepareStatement(
            "SELECT major_creditor_code, active, central_authority, country_id, name, address_line_2, "
                + "postcode, contact_email FROM public.major_creditors WHERE business_unit_id = ? "
                + "ORDER BY major_creditor_code")) {
            query.setShort(1, fixture.businessUnitId());
            try (ResultSet rows = query.executeQuery()) {
                assertTrue(rows.next());
                assertEquals("A001", rows.getString(1));
                assertTrue(rows.getBoolean(2));
                assertTrue(rows.getBoolean(3));
                assertEquals(null, rows.getObject(4));
                assertEquals("Synthetic Authority One", rows.getString(5));
                assertEquals("Synthetic line two", rows.getString(6));
                assertEquals("ZZ1 1ZZ", rows.getString(7));
                assertEquals("contact@example.invalid", rows.getString(8));
                assertTrue(rows.next());
                assertEquals("A002", rows.getString(1));
                assertTrue(rows.getBoolean(2));
                assertTrue(rows.getBoolean(3));
                assertEquals(null, rows.getObject(4));
                assertEquals(null, rows.getString(6));
                assertEquals(null, rows.getString(7));
                assertEquals(null, rows.getString(8));
                assertTrue(rows.next());
                assertEquals("I001", rows.getString(1));
                assertFalse(rows.getBoolean(2));
                assertTrue(rows.getBoolean(3));
                assertTrue(rows.next());
                assertEquals("M001", rows.getString(1));
                assertTrue(rows.getBoolean(2));
                assertFalse(rows.getBoolean(3));
                assertFalse(rows.next());
            }
        } finally {
            fixture.close();
        }
        fixture.close();
        assertTrue(fixtureConnection.isClosed());
        assertEquals(1, count("business_units"));
        assertEquals(1, count("major_creditors"));
    }

    @Test
    void rollsBackPartialSetupAndClosesConnection() throws SQLException {
        try (Connection admin = connect(); Statement statement = admin.createStatement()) {
            statement.execute("ALTER TABLE public.major_creditors ADD CONSTRAINT fixture_setup_failure "
                + "CHECK (major_creditor_code <> 'A002')");
        }
        Connection connection = connect();
        assertThrows(SQLException.class, () -> CentralAuthorityFixtures.create(connection, runId));
        assertTrue(connection.isClosed());
        assertEmptyReferenceTables();
        try (Connection admin = connect(); Statement statement = admin.createStatement()) {
            statement.execute("ALTER TABLE public.major_creditors DROP CONSTRAINT fixture_setup_failure");
        }
        try (CentralAuthorityFixtures fixture = CentralAuthorityFixtures.create(connect(), runId)) {
            assertEquals(30001, fixture.businessUnitId());
        }
    }

    @Test
    void neverReusesBusinessUnitAfterCleanup() throws SQLException {
        short first;
        try (CentralAuthorityFixtures fixture = CentralAuthorityFixtures.create(connect(), runId)) {
            first = fixture.businessUnitId();
        }
        try (CentralAuthorityFixtures fixture = CentralAuthorityFixtures.create(connect(), runId)) {
            assertTrue(fixture.businessUnitId() > first);
        }
        assertEmptyReferenceTables();
    }

    @Test
    void skipsOccupiedIdWithoutChangingExistingUnit() throws SQLException {
        try (Connection admin = connect(); Statement statement = admin.createStatement()) {
            statement.execute("INSERT INTO public.business_units "
                + "(business_unit_id, business_unit_code, business_unit_name, business_unit_type, welsh_language) "
                + "VALUES (30000, 'Q295', 'Synthetic occupied unit', 'Area', false)");
        }
        try (CentralAuthorityFixtures fixture = CentralAuthorityFixtures.create(connect(), runId)) {
            assertEquals(30001, fixture.businessUnitId());
        }
        assertEquals(1, count("business_units"));
        assertEquals(0, count("major_creditors"));
    }

    @Test
    void failsWhenSequenceExhaustedWithoutWrappingOrMutation() throws SQLException {
        try (Connection admin = connect(); Statement statement = admin.createStatement()) {
            statement.execute("SELECT setval('public.po10294_fixture_business_unit_id_seq', 32767, true)");
        }
        Connection connection = connect();
        assertThrows(SQLException.class, () -> CentralAuthorityFixtures.create(connection, runId));
        assertTrue(connection.isClosed());
        assertEmptyReferenceTables();
    }

    @Test
    void rollsBackCleanupFailureAndReportsIt() throws SQLException {
        Connection connection = connect();
        CentralAuthorityFixtures fixture = CentralAuthorityFixtures.create(connection, runId);
        try (Connection admin = connect(); Statement statement = admin.createStatement()) {
            statement.execute("CREATE TABLE public.po10294_cleanup_blocker "
                + "(business_unit_id SMALLINT REFERENCES public.business_units)");
            try (PreparedStatement blocker = admin.prepareStatement(
                "INSERT INTO public.po10294_cleanup_blocker VALUES (?)")) {
                blocker.setShort(1, fixture.businessUnitId());
                blocker.executeUpdate();
            }
        }
        assertThrows(SQLException.class, fixture::close);
        assertTrue(connection.isClosed());
        assertEquals(1, count("business_units"));
        assertEquals(4, count("major_creditors"));
    }

    private Map<String, String> configuration() {
        Map<String, String> configuration = new HashMap<>();
        configuration.put("PO10294_FIXTURE_JDBC_URL", targetUrl());
        configuration.put("PO10294_FIXTURE_DB_USER", DATABASE.getUsername());
        configuration.put("PO10294_FIXTURE_DB_PASSWORD", DATABASE.getPassword());
        configuration.put("PO10294_FIXTURE_RUN_ID", runId);
        return configuration;
    }

    private String targetUrl() {
        return "jdbc:postgresql://" + DATABASE.getHost() + ":" + DATABASE.getMappedPort(5432)
            + "/" + DATABASE.getDatabaseName();
    }

    private Connection connect() throws SQLException {
        return DriverManager.getConnection(targetUrl(), DATABASE.getUsername(), DATABASE.getPassword());
    }

    private void insertUnrelatedUnit() throws SQLException {
        try (Connection connection = connect(); Statement statement = connection.createStatement()) {
            statement.execute("INSERT INTO public.business_units "
                + "(business_unit_id, business_unit_code, business_unit_name, business_unit_type, welsh_language) "
                + "VALUES (1, 'Q295', 'Synthetic unrelated unit', 'Area', false)");
            statement.execute("INSERT INTO public.major_creditors "
                + "(business_unit_id, major_creditor_code, name, address_line_1, active, central_authority) "
                + "VALUES (1, 'U001', 'Synthetic unrelated creditor', 'Synthetic address', true, false)");
        }
    }

    private int count(String table) throws SQLException {
        try (Connection connection = connect(); Statement statement = connection.createStatement();
             ResultSet rows = statement.executeQuery("SELECT count(*) FROM public." + table)) {
            rows.next();
            return rows.getInt(1);
        }
    }

    private void assertEmptyReferenceTables() throws SQLException {
        assertEquals(0, count("business_units"));
        assertEquals(0, count("major_creditors"));
    }
}
