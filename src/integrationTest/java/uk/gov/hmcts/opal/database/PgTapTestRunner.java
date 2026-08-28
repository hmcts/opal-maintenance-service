package uk.gov.hmcts.opal.database;

import java.nio.file.Files;
import java.nio.file.Path;
import org.testcontainers.containers.Container.ExecResult;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.MountableFile;

final class PgTapTestRunner {

    private static final String CONTAINER_TEST_DIRECTORY = "/tmp/opal-pgtap";

    private PgTapTestRunner() {
    }

    static void run(PostgreSQLContainer container, Path sqlFile) throws Exception {
        Path absoluteSqlFile = sqlFile.toAbsolutePath().normalize();
        if (!Files.isRegularFile(absoluteSqlFile)) {
            throw new IllegalArgumentException("pgTAP SQL file does not exist: " + absoluteSqlFile);
        }

        String containerSqlFile = CONTAINER_TEST_DIRECTORY + "/" + sqlFile.getFileName();
        ExecResult directoryResult = container.execInContainer(
            "mkdir",
            "-p",
            CONTAINER_TEST_DIRECTORY
        );
        if (directoryResult.getExitCode() != 0) {
            throw new AssertionError(
                "Unable to prepare pgTAP directory:\n"
                    + directoryResult.getStdout()
                    + directoryResult.getStderr()
            );
        }

        container.copyFileToContainer(
            MountableFile.forHostPath(absoluteSqlFile),
            containerSqlFile
        );

        ExecResult result = container.execInContainer(
            "env",
            "PGPASSWORD=" + container.getPassword(),
            "pg_prove",
            "--verbose",
            "-h",
            "localhost",
            "-p",
            PostgreSQLContainer.POSTGRESQL_PORT.toString(),
            "-U",
            container.getUsername(),
            "-d",
            container.getDatabaseName(),
            containerSqlFile
        );

        if (result.getExitCode() != 0) {
            throw new AssertionError(
                "pg_prove failed for " + sqlFile + ":\n"
                    + result.getStdout()
                    + result.getStderr()
            );
        }
    }
}
