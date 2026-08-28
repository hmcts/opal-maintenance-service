# Testing

## Test levels

- **Unit:** `src/test/java`; run `./gradlew test`. A well-isolated unit test needs no external service.
- **Integration:** `src/integrationTest/java`; run `./gradlew integration`. These tests use a Spring context and Testcontainers PostgreSQL 17, so Docker is required for container-backed tests.
- **Functional:** `src/functionalTest/java`; run `./gradlew functional`. External HTTP checks use `TEST_URL`, defaulting to `http://localhost:4551`; they require a suitable running service.
- **Smoke:** `src/smokeTest/java`; run `./gradlew smoke`. External HTTP checks use the same `TEST_URL` default and require a running service.

## Database migration validation

Normal Docker Compose use is a persistent local-development workflow.
`docker compose down` removes its containers and network but intentionally
preserves the named PostgreSQL volume, so a later start can reuse an already
migrated database. That behaviour is not fresh-database validation.

> **Destructive:** `docker compose down --volumes` deletes the developer-owned
> named volume and its local database data. Do not use it as a routine database
> validation step.

### Planned DB-01 suite semantics

The future canonical entry point is `./gradlew dbTest`. The task is not
implemented in this checkout and must be recorded as unavailable. SQL contract
suites already live under `src/dbUnitTest`, but they are currently invoked by
focused integration tests rather than a standalone database-owned Gradle task.

The planned suite is database-owned and independent of Spring and backend
integration-test fixtures. Docker is a prerequisite because the suite will own
the lifecycle of a disposable PostgreSQL 17 Testcontainer. The target,
migration, assertion, and cleanup rules belong to the
[DB-01 migration-safety contract](DATABASE_MIGRATIONS.md#planned-db-01-fresh-database-contract).

Existing backend integration tests may incidentally apply migrations while
starting Spring Boot, but they are not database migration validation. When
DB-01 is implemented, the normal `check` lifecycle should run
`dbTest` and `integration` once each as peer suites; neither task
should invoke or own the other.

Any migration, validation, assertion, safety, or cleanup failure must fail the
`dbTest` task and its dedicated report. Capture non-sensitive evidence
for the PostgreSQL and Flyway versions, selected migration locations, initial
and final state, migrations applied, assertions executed, timings, and
confirmed cleanup. Evidence must not contain production data, PII, secrets,
credentials, or reusable connection details.

### Planned DB-04 test placement

DB-04 migration-specific checks will live under `src/dbUnitTest`, grouped by
the maintained database object or feature and run by the
[planned DB-01 database-owned suite](#planned-db-01-suite-semantics). Keep the
migration and ticket association in the test metadata or handoff rather than
using a ticket-specific directory. The checks must use direct PostgreSQL
boundary evidence rather than Spring, backend repositories, or backend
integration-test fixtures. Existing backend integration tests and their
ownership remain unchanged.

Each migration-focused specification must state whether its assertions run on
the fresh DB-01 path, the DB-03 upgrade path, or both. Run every applicable
path; when a path is not applicable, record the reason. Representative upgrade
setup and synthetic data rules remain owned by the
[planned DB-03 guidance](DATABASE_MIGRATIONS.md#planned-db-03-upgrade-path-validation).

Select assertions from the migration-specific categories in the
[DB-04 database contract](DATABASE_MIGRATIONS.md#planned-db-04-migration-specific-boundary-contract)
without copying that catalogue here. Future DB-10 guidance will own reusable
assertion mechanics and patterns, command-failing output, and the common
evidence format; DB-04 does not define those mechanics.

### Planned DB-06 procedure-side testing

Stored-procedure checks will live under `src/dbUnitTest`, grouped by the
maintained procedure or feature and run by the
[planned DB-01 database-owned suite](#planned-db-01-suite-semantics). Keep the
migration and ticket association in the test metadata or handoff. Call the
procedure directly through PostgreSQL rather than through Spring, a backend
repository, or a backend integration-test fixture. Use the DB-03 path for
applicable predecessor state and approved row-dependent scenarios, and align
the checks with the migration's DB-04 assertion declaration.

For each applicable procedure contract, prove the relevant procedure-side
outcomes:

- Successful results and declared database side effects.
- Exception propagation, including the expected SQLSTATE or error behaviour.
- The declared affected-row scope.
- Repeat-call and idempotency behaviour where applicable.
- Participation in caller-controlled rollback and atomicity at the declared
  boundary.
- When run-status behaviour is relevant, that the procedure does not
  independently create or update run-status records.

The database procedure/backend ownership contract is defined in
[Database Migrations](DATABASE_MIGRATIONS.md#planned-db-06-stored-procedure-responsibility-contract).
Backend transaction and run-status orchestration tests remain outside
`dbTest` and must be tracked separately when required; backend test
ownership is unchanged. DB-10 will own reusable assertion mechanics,
command-failing output, and evidence formatting rather than DB-06 duplicating
them here.

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

## Current database SQL test execution

This is interim coverage for SQL contracts while the planned DB-01
database-owned `dbTest` task remains unavailable. It does not replace the
fresh-database, upgrade-path, evidence, or cleanup requirements of DB-01.

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
