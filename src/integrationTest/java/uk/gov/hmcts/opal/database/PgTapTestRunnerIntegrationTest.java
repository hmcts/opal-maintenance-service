package uk.gov.hmcts.opal.database;

import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import uk.gov.hmcts.opal.BaseIntegrationTest;

class PgTapTestRunnerIntegrationTest extends BaseIntegrationTest {

    private static final Path FAILING_PGTAP_TEST =
        Path.of("src/integrationTest/resources/db/pgtap/failing_pgtap_test.sql");

    @Test
    void failedPgTapAssertionFailsTheRunner() {
        assertThatThrownBy(() -> PgTapTestRunner.run(databaseContainer, FAILING_PGTAP_TEST))
            .isInstanceOf(AssertionError.class)
            .hasMessageContaining("pg_prove failed for")
            .hasMessageContaining("deliberate pgTAP failure used to verify the Java runner");
    }
}
