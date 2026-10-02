package uk.gov.hmcts.opal.fixtures;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/** Scenario-owned rows in a dedicated disposable local database. */
public final class MajorCreditorsFixture implements AutoCloseable {
    private static final String DATABASE = "opal_major_creditors_functional";
    private static final short UNIT = 31010;
    private static final short OTHER_UNIT = 31011;
    private static final long COUNTRY = 9000101L;
    private static final String COUNTRY_NAME = "Synthetic Functional Country";
    private final Connection connection;
    private final List<ExpectedCreditor> creditors;
    private final List<ExpectedCreditor> expected;
    private boolean closed;

    private MajorCreditorsFixture(Connection connection, List<ExpectedCreditor> creditors) {
        this.connection = connection;
        this.creditors = List.copyOf(creditors);
        this.expected = List.copyOf(creditors.subList(0, 2));
    }

    public record ExpectedCreditor(long id, short businessUnitId, String code, String name, String addressLine1,
                                   String contactName, String contactEmail, Long countryId, String countryName) { }

    public short businessUnitId() {
        return UNIT;
    }

    public List<ExpectedCreditor> expectedCreditors() {
        return expected;
    }

    static String validatedJdbcUrl(Map<String, String> environment) {
        if (!"true".equals(environment.get("FUNCTIONAL_FIXTURE_DB_DISPOSABLE"))) {
            throw new IllegalArgumentException("FUNCTIONAL_FIXTURE_DB_DISPOSABLE must be true");
        }
        String host = setting(environment, "HOST");
        if (!"localhost".equals(host) && !"127.0.0.1".equals(host)) {
            throw new IllegalArgumentException("FUNCTIONAL_FIXTURE_DB_HOST must be loopback");
        }
        if (!DATABASE.equals(setting(environment, "NAME"))) {
            throw new IllegalArgumentException("FUNCTIONAL_FIXTURE_DB_NAME must be the dedicated fixture database");
        }
        int port;
        try {
            port = Integer.parseInt(setting(environment, "PORT"));
        } catch (NumberFormatException exception) {
            throw new IllegalArgumentException("FUNCTIONAL_FIXTURE_DB_PORT must be a valid port");
        }
        if (port < 1 || port > 65535) {
            throw new IllegalArgumentException("FUNCTIONAL_FIXTURE_DB_PORT must be a valid port");
        }
        setting(environment, "USERNAME");
        setting(environment, "PASSWORD");
        return "jdbc:postgresql://" + host + ":" + port + "/" + DATABASE;
    }

    private static String setting(Map<String, String> environment, String name) {
        String value = environment.get("FUNCTIONAL_FIXTURE_DB_" + name);
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException("FUNCTIONAL_FIXTURE_DB_" + name + " is required");
        }
        return value;
    }

    public static MajorCreditorsFixture create(Map<String, String> environment) throws SQLException {
        String url = validatedJdbcUrl(environment);
        Connection connection = DriverManager.getConnection(url, setting(environment, "USERNAME"),
            setting(environment, "PASSWORD"));
        try {
            connection.setAutoCommit(false);
            try (PreparedStatement query = connection.prepareStatement("SELECT current_database()");
                 ResultSet result = query.executeQuery()) {
                if (!result.next() || !DATABASE.equals(result.getString(1))) {
                    throw new SQLException("Fixture connection is not the dedicated database");
                }
            }
            insertUnit(connection, UNIT, "ZF10", "Synthetic Functional Creditor Unit");
            insertUnit(connection, OTHER_UNIT, "ZF11", "Other Unit");
            try (PreparedStatement insert = connection.prepareStatement("""
                INSERT INTO public.countries (country_id, cjs_code, country_name, date_used_from, active)
                VALUES (?, ?, ?, DATE '2000-01-01', true)
                """)) {
                insert.setLong(1, COUNTRY);
                insert.setShort(2, UNIT);
                insert.setString(3, COUNTRY_NAME);
                insert.executeUpdate();
            }
            List<ExpectedCreditor> creditors = new ArrayList<>();
            creditors.add(insertCreditor(connection, UNIT, "F001", "Synthetic Creditor Alpha",
                "Synthetic address Alpha", COUNTRY, "Synthetic Contact Alpha", "alpha@example.invalid", true, false));
            creditors.add(insertCreditor(connection, UNIT, "F002", "Synthetic Creditor Beta",
                "Synthetic address Beta", null, null, null, true, false));
            creditors.add(insertCreditor(connection, UNIT, "F003", "Synthetic Inactive Creditor",
                "Synthetic address Inactive", null, null, null, false, false));
            creditors.add(insertCreditor(connection, UNIT, "F004", "Synthetic Central Authority",
                "Synthetic address Authority", null, null, null, true, true));
            creditors.add(insertCreditor(connection, OTHER_UNIT, "F005", "Synthetic Other Unit Creditor",
                "Synthetic address Other", null, null, null, true, false));
            connection.commit();
            return new MajorCreditorsFixture(connection, creditors);
        } catch (SQLException | RuntimeException exception) {
            rollback(connection, exception);
            try {
                connection.close();
            } catch (SQLException cleanup) {
                exception.addSuppressed(cleanup);
            }
            throw exception;
        }
    }

    private static void insertUnit(Connection connection, short id, String code, String name) throws SQLException {
        try (PreparedStatement insert = connection.prepareStatement("""
            INSERT INTO public.business_units
                (business_unit_id, business_unit_code, business_unit_name, business_unit_type, welsh_language)
            VALUES (?, ?, ?, 'Area', false)
            """)) {
            insert.setShort(1, id);
            insert.setString(2, code);
            insert.setString(3, name);
            insert.executeUpdate();
        }
    }

    private static ExpectedCreditor insertCreditor(Connection connection, short unit, String code, String name,
                                                   String address, Long country, String contact, String email,
                                                   boolean active, boolean authority) throws SQLException {
        try (PreparedStatement insert = connection.prepareStatement("""
            INSERT INTO public.major_creditors
                (business_unit_id, major_creditor_code, name, address_line_1,
                 country_id, contact_name, contact_email, active, central_authority)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING major_creditor_id
            """)) {
            insert.setShort(1, unit);
            insert.setString(2, code);
            insert.setString(3, name);
            insert.setString(4, address);
            if (country == null) {
                insert.setNull(5, Types.BIGINT);
            } else {
                insert.setLong(5, country);
            }
            insert.setString(6, contact);
            insert.setString(7, email);
            insert.setBoolean(8, active);
            insert.setBoolean(9, authority);
            try (ResultSet result = insert.executeQuery()) {
                if (!result.next()) {
                    throw new SQLException("Fixture creditor insert returned no identifier");
                }
                return new ExpectedCreditor(result.getLong(1), unit, code, name, address, contact, email,
                    country, country == null ? null : COUNTRY_NAME);
            }
        }
    }

    @Override
    public void close() throws SQLException {
        if (closed) {
            return;
        }
        SQLException failure = null;
        try {
            for (ExpectedCreditor creditor : creditors) {
                try (PreparedStatement delete = connection.prepareStatement("""
                    DELETE FROM public.major_creditors WHERE major_creditor_id = ? AND business_unit_id = ?
                    """)) {
                    delete.setLong(1, creditor.id());
                    delete.setShort(2, creditor.businessUnitId());
                    requireOne(delete.executeUpdate());
                }
            }
            deleteParent("DELETE FROM public.countries WHERE country_id = ?", COUNTRY);
            deleteParent("DELETE FROM public.business_units WHERE business_unit_id = ?", UNIT);
            deleteParent("DELETE FROM public.business_units WHERE business_unit_id = ?", OTHER_UNIT);
            connection.commit();
        } catch (SQLException exception) {
            failure = exception;
            rollback(connection, exception);
            throw exception;
        } finally {
            try {
                connection.close();
                closed = true;
            } catch (SQLException exception) {
                if (failure == null) {
                    throw exception;
                }
                failure.addSuppressed(exception);
            }
        }
    }

    private void deleteParent(String sql, long id) throws SQLException {
        try (PreparedStatement delete = connection.prepareStatement(sql)) {
            delete.setLong(1, id);
            requireOne(delete.executeUpdate());
        }
    }

    private static void requireOne(int affected) throws SQLException {
        if (affected != 1) {
            throw new SQLException("Fixture cleanup did not remove exactly one owned row");
        }
    }

    private static void rollback(Connection connection, Throwable failure) {
        try {
            connection.rollback();
        } catch (SQLException cleanup) {
            failure.addSuppressed(cleanup);
        }
    }
}
