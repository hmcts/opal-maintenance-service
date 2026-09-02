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

### DB-01 suite semantics

The canonical database-owned entry point is `./gradlew dbUnitTest`. It is
independent of Spring, JUnit, and backend integration-test fixtures. Docker is
a prerequisite because the task owns the lifecycle of disposable PostgreSQL
17 and Flyway containers. The target, migration, assertion, and cleanup rules
belong to the
[DB-01 migration-safety contract](DATABASE_MIGRATIONS.md#db-01-fresh-database-contract).

Existing backend integration tests may incidentally apply migrations while
starting Spring Boot, but they are not database migration validation. The
normal `check` lifecycle runs `dbUnitTest` and `integration` as peer suites;
neither task invokes or owns the other.

Any migration, validation, assertion, safety, or cleanup failure must fail the
`dbUnitTest` task and its dedicated report. Capture non-sensitive evidence
for the PostgreSQL and Flyway versions, selected migration locations, initial
and final state, migrations applied, assertions executed, timings, and
confirmed cleanup. Evidence must not contain production data, PII, secrets,
credentials, or reusable connection details.

### DB-04 pgTAP test placement

DB-04 migration-specific checks live under `src/dbUnitTest`, grouped by
the maintained database object or feature and run by the
[DB-01 database-owned suite](#db-01-suite-semantics). Keep the
migration and ticket association in the test metadata or handoff rather than
using a ticket-specific directory. The checks must use direct PostgreSQL
boundary evidence rather than Spring, backend repositories, or backend
integration-test fixtures. Existing backend integration tests and their
ownership remain unchanged.

Every migration that creates or changes an observable database contract must
create or update a pgTAP suite named `<object>_pgtap_tests.sql`. If an existing
suite already covers the changed contract without modification, identify that
suite and explain why its assertions remain sufficient. If no direct boundary
assertion is required, use the DB-04 exception wording and record its reason.

Each migration-focused specification must state whether its assertions apply
to the fresh DB-01 path, the DB-03 upgrade path, or both. The current
`dbUnitTest` task executes the fresh DB-01 path. Until DB-03 is implemented, an
applicable upgrade-path requirement remains unmet and must be reported rather
than claimed as verified. Representative upgrade setup and synthetic data
rules remain owned by the
[planned DB-03 guidance](DATABASE_MIGRATIONS.md#planned-db-03-upgrade-path-validation).

Select assertions from the migration-specific categories in the
[DB-04 database contract](DATABASE_MIGRATIONS.md#db-04-migration-specific-boundary-contract)
without copying that catalogue here. Follow the current
[DB-10 pgTAP execution contract](#db-10-pgtap-execution) for reusable assertion
mechanics and patterns, command-failing output, and the common evidence format.

### Planned DB-06 procedure-side testing

Stored-procedure checks live under `src/dbUnitTest`, grouped by the
maintained procedure or feature and run by the
[DB-01 database-owned suite](#db-01-suite-semantics). Keep the
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
`dbUnitTest` and must be tracked separately when required; backend test
ownership is unchanged. DB-10 owns reusable assertion mechanics,
command-failing output, and evidence formatting rather than DB-06 duplicating
them here.

## Baseline and focused commands

`./gradlew build` is the baseline validation for source, build, and runtime
configuration changes. In this repository, `check` depends on `dbUnitTest`
and `integration` as peer suites.
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

## DB-10 pgTAP execution

Database contracts live under `src/dbUnitTest` as pgTAP suites named
`<object>_pgtap_tests.sql`. `dbUnitTest` discovers those files recursively and
runs them through `pg_prove`; adding a matching suite makes it part of Gradle
and the normal `check` lifecycle.

The task starts a fresh PostgreSQL 17 container with pgTAP, confirms the empty
start state, and applies the explicit `ddl`, `data/allEnvs`, and `data/dev`
locations through the version-matched Flyway container. It validates Flyway,
confirms a second migration is a no-op, runs the pgTAP contracts, and confirms
container cleanup. It fails closed when application or external Flyway target
settings are present, so it cannot fall back to a developer-owned or shared
database. Failure output lists setting names only and never their values.

Each pgTAP suite must start a transaction, create the `pgtap` extension if
required, declare an exact `plan`, call `finish()`, and end with `ROLLBACK`.
The framework also runs a deliberate failing fixture to prove that a non-zero
`pg_prove` result fails closed. pgTAP is test-only: do not add it to production
Flyway migrations, application dependencies, or shared databases.

Run the database unit-test suite with:

```bash
./gradlew dbUnitTest
```

Raw TAP diagnostics and a non-sensitive execution summary are written under
`build/reports/dbUnitTest`. The current Countries contract is
`src/dbUnitTest/countriesTest/countries_pgtap_tests.sql`.

## Infrastructure and evidence

Integration tests need Docker for Testcontainers. HTTP functional and smoke
checks need a running service. Record exact commands, results, environments,
and manual scenarios. For every relevant skipped check, record the reason, the
scenario, the setup needed to execute it, and the expected result. A successful
pipeline is not evidence that every changed scenario ran.

For Flyway or SQL changes, follow the fresh-database, upgrade-path, database-boundary, and evidence requirements in [Database Migrations](DATABASE_MIGRATIONS.md).
