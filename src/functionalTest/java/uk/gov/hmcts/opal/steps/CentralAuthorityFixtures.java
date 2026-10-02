package uk.gov.hmcts.opal.steps;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.Map;
import java.util.UUID;
import java.util.regex.Pattern;

/** Scenario-owned reference data, restricted to an explicitly provisioned disposable target. */
public final class CentralAuthorityFixtures implements AutoCloseable {

    private static final Pattern TARGET = Pattern.compile(
        "jdbc:postgresql://(?:localhost|127\\.0\\.0\\.1|\\[::1\\]):[0-9]{1,5}/po10294_[A-Za-z0-9_]+");
    private static final String INSERT_UNIT = """
        INSERT INTO public.business_units
          (business_unit_id, business_unit_code, business_unit_name, business_unit_type, welsh_language)
        VALUES (?, 'Q294', 'Synthetic PO10294 Unit', 'Area', false)
        """;
    private static final String INSERT_CREDITORS = """
        INSERT INTO public.major_creditors
          (business_unit_id, major_creditor_code, name, address_line_1, address_line_2,
           postcode, contact_name, contact_email, active, central_authority)
        VALUES
          (?, 'A001', 'Synthetic Authority One', 'Synthetic address one', 'Synthetic line two',
           'ZZ1 1ZZ', 'Synthetic Contact', 'contact@example.invalid', true, true),
          (?, 'A002', 'Synthetic Authority Two', 'Synthetic address two', NULL,
           NULL, NULL, NULL, true, true),
          (?, 'I001', 'Synthetic Inactive Authority', 'Synthetic inactive address', NULL,
           NULL, NULL, NULL, false, true),
          (?, 'M001', 'Synthetic Ordinary Creditor', 'Synthetic creditor address', NULL,
           NULL, NULL, NULL, true, false)
        """;

    private final Connection connection;
    private final short businessUnitId;
    private boolean closed;

    private CentralAuthorityFixtures(Connection connection, short businessUnitId) {
        this.connection = connection;
        this.businessUnitId = businessUnitId;
    }

    public static CentralAuthorityFixtures create() throws SQLException {
        return create(System.getenv());
    }

    static CentralAuthorityFixtures create(Map<String, String> configuration) throws SQLException {
        String url = required(configuration, "PO10294_FIXTURE_JDBC_URL");
        String user = required(configuration, "PO10294_FIXTURE_DB_USER");
        String password = required(configuration, "PO10294_FIXTURE_DB_PASSWORD");
        String runId = required(configuration, "PO10294_FIXTURE_RUN_ID");
        validateTarget(url);
        validateRunId(runId);
        return create(DriverManager.getConnection(url, user, password), runId);
    }

    static CentralAuthorityFixtures create(Connection connection, String runId) throws SQLException {
        try {
            validateTarget(connection.getMetaData().getURL());
            validateRunId(runId);
            if (!connection.getAutoCommit()) {
                throw new IllegalArgumentException("Fixture connection must not contain an existing transaction");
            }
            verifyOwner(connection, runId);
            verifyAllocationSequence(connection);
            connection.setAutoCommit(false);
            while (true) {
                short id = nextBusinessUnitId(connection);
                try (PreparedStatement unit = connection.prepareStatement(INSERT_UNIT)) {
                    unit.setShort(1, id);
                    unit.executeUpdate();
                } catch (SQLException failure) {
                    // Only an occupied ID is retryable. A conflicting Q294 code must fail closed.
                    if ("23505".equals(failure.getSQLState())) {
                        connection.rollback();
                        if (businessUnitExists(connection, id)) {
                            connection.rollback();
                            continue;
                        }
                    }
                    throw failure;
                }
                try (PreparedStatement creditors = connection.prepareStatement(INSERT_CREDITORS)) {
                    for (int parameter = 1; parameter <= 4; parameter++) {
                        creditors.setShort(parameter, id);
                    }
                    creditors.executeUpdate();
                }
                connection.commit();
                return new CentralAuthorityFixtures(connection, id);
            }
        } catch (SQLException | RuntimeException failure) {
            rollbackAndClose(connection, failure);
            throw failure;
        }
    }

    public short businessUnitId() {
        return businessUnitId;
    }

    @Override
    public void close() throws SQLException {
        if (closed) {
            return;
        }
        closed = true;
        try {
            deleteOwned("DELETE FROM public.major_creditors WHERE business_unit_id = ?");
            deleteOwned("DELETE FROM public.business_units WHERE business_unit_id = ?");
            connection.commit();
        } catch (SQLException failure) {
            rollbackAndClose(connection, failure);
            throw failure;
        }
        connection.close();
    }

    private void deleteOwned(String sql) throws SQLException {
        try (PreparedStatement deletion = connection.prepareStatement(sql)) {
            deletion.setShort(1, businessUnitId);
            deletion.executeUpdate();
        }
    }

    private static String required(Map<String, String> configuration, String name) {
        String value = configuration.get(name);
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException("Missing required fixture configuration: " + name);
        }
        return value;
    }

    private static void validateTarget(String url) {
        if (url == null || !TARGET.matcher(url).matches()) {
            throw new IllegalArgumentException("Fixture target must be an explicit loopback po10294_ database "
                + "with a port and no connection options");
        }
    }

    private static void validateRunId(String runId) {
        if (runId == null || !UUID.fromString(runId).toString().equalsIgnoreCase(runId)) {
            throw new IllegalArgumentException("Fixture run ID must be a UUID");
        }
    }

    private static void verifyOwner(Connection connection, String runId) throws SQLException {
        try (PreparedStatement owner = connection.prepareStatement(
            "SELECT count(*) FROM public.po10294_fixture_owner WHERE run_id = ?::uuid")) {
            owner.setString(1, runId);
            try (ResultSet result = owner.executeQuery()) {
                result.next();
                if (result.getInt(1) != 1) {
                    throw new IllegalArgumentException("Disposable fixture ownership could not be verified");
                }
            }
        }
    }

    private static void verifyAllocationSequence(Connection connection) throws SQLException {
        try (PreparedStatement sequence = connection.prepareStatement("""
            SELECT min_value, max_value, increment_by, cycle
            FROM pg_catalog.pg_sequences
            WHERE schemaname = 'public' AND sequencename = 'po10294_fixture_business_unit_id_seq'
            """); ResultSet result = sequence.executeQuery()) {
            if (!result.next() || result.getLong(1) != 30000 || result.getLong(2) != Short.MAX_VALUE
                || result.getLong(3) != 1 || result.getBoolean(4)) {
                throw new IllegalArgumentException("Disposable fixture allocation sequence is missing or unsafe");
            }
        }
    }

    private static short nextBusinessUnitId(Connection connection) throws SQLException {
        // nextval is not rolled back: cleanup and failed setup can never recycle a cached key.
        try (PreparedStatement allocation = connection.prepareStatement(
            "SELECT nextval('public.po10294_fixture_business_unit_id_seq')");
             ResultSet result = allocation.executeQuery()) {
            result.next();
            long id = result.getLong(1);
            if (id < 30000 || id > Short.MAX_VALUE) {
                throw new SQLException("Disposable fixture business-unit range exhausted");
            }
            return (short) id;
        }
    }

    private static boolean businessUnitExists(Connection connection, short id) throws SQLException {
        try (PreparedStatement existing = connection.prepareStatement(
            "SELECT 1 FROM public.business_units WHERE business_unit_id = ?")) {
            existing.setShort(1, id);
            try (ResultSet result = existing.executeQuery()) {
                return result.next();
            }
        }
    }

    private static void rollbackAndClose(Connection connection, Exception original) {
        try {
            if (!connection.getAutoCommit()) {
                connection.rollback();
            }
        } catch (SQLException failure) {
            original.addSuppressed(failure);
        }
        try {
            connection.close();
        } catch (SQLException failure) {
            original.addSuppressed(failure);
        }
    }
}
