# Testing

## Test levels

- **Unit:** `src/test/java`; run `./gradlew test`. A well-isolated unit test needs no external service.
- **Integration:** `src/integrationTest/java`; run `./gradlew integration`. These tests use a Spring context and Testcontainers PostgreSQL 17, so Docker is required for container-backed tests.
- **Functional:** `src/functionalTest/java`; run `./gradlew functional`. External HTTP checks use `TEST_URL`, defaulting to `http://localhost:4551`; they require a suitable running service.
- **Smoke:** `src/smokeTest/java`; run `./gradlew smoke`. External HTTP checks use the same `TEST_URL` default and require a running service.

## Baseline and focused commands

`./gradlew build` is the baseline validation for source, build, and runtime
configuration changes. In this repository, `check` depends on `integration`.
Run focused tests with `./gradlew test --tests 'fully.qualified.Pattern'` or
`./gradlew integration --tests 'fully.qualified.Pattern'`. Focused quality
commands are `./gradlew checkstyleMain`, `./gradlew pmdMain`, and
`./gradlew jacocoTestReport`. For documentation-only or similarly
non-executable changes, run checks appropriate to the changed artefacts and
record why the baseline build was not run.

## Test design

Mirror production packages, use `*Test`, and assert observable behaviour. Cover validation, error, empty, and configuration paths affected by a change. Keep Testcontainers and network boundaries explicit; do not make unit tests depend on them.

Authentication integration tests generate their own JWTs at runtime and use
WireMock for User Service responses. They do not require a real AAD tenant or
User Service. The Bruno collection is a separate, optional manual check for a
real AAD/User Service setup; enable testing-support endpoints explicitly with
`TESTING_SUPPORT_ENDPOINTS_ENABLED=true` before using its ping or authenticated
diagnostic requests. Never place a bearer value in a tracked Bruno file.

## Database SQL tests

Database-contract SQL scripts live under `src/dbUnitTest` and run against the
repository's disposable PostgreSQL 17 Testcontainer. Do not run these scripts
against a shared database.

Two complementary styles are supported:

- Native PL/pgSQL contract suites use PostgreSQL `ASSERT`. A failed assertion
  or unexpected SQL exception must fail the associated JUnit integration test.
- Supplementary pgTAP suites use pgTAP assertions and are executed by JUnit
  through `pg_prove`. A non-zero `pg_prove` exit code must fail the integration
  test and include TAP diagnostics in the test failure.

Keep both styles inside rollback-only transactions so test rows and test-local
extension creation do not persist. A pgTAP suite must start a transaction,
create the `pgtap` extension if required, declare an exact `plan`, call
`finish()`, and end with `ROLLBACK`.

The integration-test PostgreSQL image contains pgTAP and `pg_prove` solely for
this disposable test workflow. Do not add pgTAP to production Flyway
migrations, application dependencies, or shared databases.

Name native suites `<object>_unit_tests.sql` and supplementary pgTAP suites
`<object>_pgtap_tests.sql` beneath an object-focused directory. Each suite
must be invoked by a focused `*DatabaseIntegrationTest`; merely adding an SQL
file does not make it part of Gradle or CI.

Run all database integration tests with:

```bash
./gradlew integration --tests '*DatabaseIntegrationTest'
```

Run pgTAP infrastructure and database suites with:

```bash
./gradlew integration --tests '*PgTap*' --tests '*DatabaseIntegrationTest'
```

Run an individual database integration test by its class name, for example:

```bash
./gradlew integration --tests '*CountriesDatabaseIntegrationTest'
```

Docker is required. The current Countries contracts are defined in
`src/dbUnitTest/countriesTest/countries_unit_tests.sql` and
`src/dbUnitTest/countriesTest/countries_pgtap_tests.sql`.

## Infrastructure and evidence

Integration tests need Docker for Testcontainers. HTTP functional and smoke
checks need a running service. Record exact commands, results, environments,
and manual scenarios. For every relevant skipped check, record the reason, the
scenario, the setup needed to execute it, and the expected result. A successful
pipeline is not evidence that every changed scenario ran.

For Flyway or SQL changes, follow the fresh-database, upgrade-path, database-boundary, and evidence requirements in [Database Migrations](DATABASE_MIGRATIONS.md).
