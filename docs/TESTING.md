# Testing

This document defines the test levels, test-selection rules, authoring
standards, and verification evidence expected in this repository. Functional
and smoke tests exercise a running service and have additional guidance in
[End-to-end Testing](E2E_TESTING.md).

## Test levels

Choose the lowest test level that proves the behaviour without replacing a
necessary higher-level check.

| Level | Location | Use it for | Command | Runtime needs |
| --- | --- | --- | --- | --- |
| Unit | `src/test/java` | Isolated class behaviour, validation, mapping, and configuration logic | `./gradlew test` | No network or container dependency |
| Integration | `src/integrationTest/java` | Spring wiring, controllers, security, persistence, migrations, and cross-layer behaviour | `./gradlew integration` | Docker for Testcontainers PostgreSQL |
| Functional | `src/functionalTest/java` | Endpoint behaviour or a business journey through a running service | `./gradlew functional` | A suitable service at `TEST_URL` |
| Smoke | `src/smokeTest/java` | A small set of deployment-critical happy paths | `./gradlew smoke` | A suitable service at `TEST_URL` |

## Database migration validation

Normal Docker Compose use is a persistent local-development workflow.
`docker compose down` removes its containers and network but intentionally
preserves the named PostgreSQL volume, so a later start can reuse an already
migrated database. That behaviour is not fresh-database validation.

> **Destructive:** `docker compose down --volumes` deletes the developer-owned
> named volume and its local database data. Do not use it as a routine database
> validation step.

### Planned DB-01 suite semantics

The future canonical entry point is `./gradlew dbTest`. It is not
implemented in this checkout and must be recorded as unavailable until its
`src/dbUnitTest` SQL-test directory and task exist.

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

Do not put a Spring slice test using `MockMvc` or `@WebMvcTest` in the
functional source set. It belongs in unit or integration coverage. Do not use
an end-to-end test to prove behaviour that can be covered reliably at unit or
integration level.

## Coverage expectations

For every changed behaviour, cover the applicable paths rather than only the
happy path:

- success and expected response content;
- request validation and malformed input;
- empty or not-found results;
- downstream and internal failure behaviour;
- authentication and authorisation;
- persistence side effects and concurrency controls;
- configuration defaults and environment overrides; and
- startup, health, or migration behaviour when affected.

Tests must assert observable behaviour. Avoid assertions that merely repeat an
implementation detail or only prove that a mock was called when the response
or state change is the real contract.

## Naming and structure

- Mirror the production package under the corresponding test source set.
- Name unit test classes `*Test`, integration classes `*IntegrationTest`,
  functional classes `*FunctionalTest`, and smoke classes `*SmokeTest`.
- Use behaviour-led method names such as `returnsNotFoundForUnknownId` or
  `rejectsExpiredToken`; avoid generic names such as `testEndpoint` and avoid
  numbering tests.
- Use a concise `@DisplayName` where it improves report readability. Preserve a
  Jira reference when the surrounding suite already uses one; do not invent
  unsupported annotation or tag conventions.
- Keep each test focused on one behaviour. Use parameterised tests when the
  setup and assertion are genuinely the same for several inputs.
- Reuse an existing fixture, helper, or test foundation before introducing a
  parallel abstraction. Keep feature-specific helpers close to the feature.

## Unit tests

Unit tests must be deterministic and isolated. They must not start Spring,
containers, a real database, or an HTTP service unless the framework behaviour
itself is what the test covers. Prefer direct construction and narrow mocks.
Use Spring test support only when it provides behaviour the test needs to
prove, such as configuration binding.

## Integration tests

Mirror the Fines service's controller-focused integration style where it fits
this service:

- Extend `BaseIntegrationTest` by default when the test needs the application
  context or PostgreSQL Testcontainer.
- Use `MockMvc` for controller-facing integration behaviour. Use the random
  live-server port only when the real HTTP boundary is itself under test.
- Use `@MockitoBean` for a narrow external collaborator override; do not mock
  broad portions of the application wiring.
- Assert status first, JSON content type where applicable, and contract-relevant
  payload fields. Validate an existing response schema or OpenAPI contract when
  the endpoint has one and the suite provides a validator.
- Prefer small SQL fixtures for stable database state. For data-changing
  behaviour, assert the persisted result as well as the HTTP response.
- Keep Opal and legacy-mode behaviours separate when their contracts differ.
  Do not mix modes in one test unless that comparison is the behaviour under
  test.

Authentication integration tests must generate their own JWTs at runtime and
stub external identity or User Service responses. They must not require a real
Azure AD tenant, a shared user, or a committed bearer token. Use real security
configuration only when authentication or token processing is the behaviour
under test; otherwise use the narrowest test configuration that proves the
business behaviour.

## Data and isolation

- Use the smallest fixture that proves the scenario and reuse existing fixture
  data when its meaning matches.
- Keep tests independent of execution order and clean up state that is not
  naturally disposable with the test context or container.
- Never copy production data, secrets, credentials, tokens, or PII into test
  code, fixtures, logs, reports, or evidence.
- Make container, network, clock, and environment dependencies explicit. Do
  not hide a network dependency behind a helper and describe the test as a
  unit test.

## Commands and baseline verification

Run the narrowest relevant command while developing:

```bash
./gradlew test --tests 'fully.qualified.TestClass'
./gradlew integration --tests 'fully.qualified.IntegrationTestClass'
```

Run `./gradlew build` as the repository baseline for executable source, build,
dependency, or runtime-configuration changes. In this repository, `check`
depends on `integration`, so Docker is required. Use these focused quality
commands when relevant:

```bash
./gradlew checkstyleMain
./gradlew pmdMain
./gradlew jacocoTestReport
```

For a documentation-only or similarly non-executable change, run checks
appropriate to the changed artefacts and record why the baseline build was not
run. For Flyway or SQL changes, also follow the fresh-database, upgrade-path,
database-boundary, and evidence requirements in
[Database Migrations](DATABASE_MIGRATIONS.md).

## Evidence and skipped checks

Record:

- the exact command or manual scenario;
- whether it passed or failed;
- the environment or target URL for external checks; and
- any relevant report path.

For every relevant check not run, record the reason, the setup needed to run
it, the scenario it would prove, and the expected result. A successful pipeline
is not evidence that every changed scenario ran.

The Bruno collection is an optional manual diagnostic aid, not a replacement
for automated coverage. Enable testing-support endpoints explicitly with
`TESTING_SUPPORT_ENDPOINTS_ENABLED=true`, keep credentials in ignored local
environment files, and never place a bearer value in a tracked Bruno file.
