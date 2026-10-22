# Testing

## Test levels

- **Unit:** `src/test/java`; run `./gradlew test`. A well-isolated unit test needs no external service.
- **Integration:** `src/integrationTest/java`; run `./gradlew integration`. These tests use a Spring context and Testcontainers PostgreSQL 17, so Docker is required for container-backed tests.
- **Functional:** `src/functionalTest/java`; run `./gradlew functional`. External HTTP checks use `TEST_URL`, defaulting to `http://localhost:4551`; they require a suitable running service.
- **Smoke:** `src/smokeTest/java`; run `./gradlew smoke`. External HTTP checks use the same `TEST_URL` default and require a running service.

## Cucumber functional tests

Cucumber and Serenity scenarios run through `functionalOpal`. Use a Cucumber
tag expression to run a focused set of scenarios:

```bash
./gradlew functionalOpal -Dcucumber.filter.tags='<tag-expression>'
```

Add `-Dcucumber.execution.dry-run=true` to validate feature and step discovery
without executing scenario actions.

External scenarios use `TEST_URL`, defaulting to `http://localhost:4551`.
Authenticated scenarios that obtain a token from User Service use
`OPAL_USER_SERVICE_API_URL`, defaulting to `http://localhost:4555`. Ensure all
required services are compatible and the target environment contains
representative data for the behavior under test.

Never put a bearer token in a tracked file or command-line argument.

### User Service access

Draft Casefile functional tests use existing test users and their assigned
Maintenance permissions. Jenkins defaults `OPAL_USER_SERVICE_API_URL` to the
shared staging User Service. These tests do not require an
`enable_opal_user_service` label, a separate User Service deployment, user or role
provisioning, or changes to User Service configuration.

The token helper calls `/testing-support/token/user` on the configured User
Service. The authorised scenario submits a synthetic casefile, captures its ID,
asserts the response and deletes it through Maintenance testing support using
the same user and run marker. Rejection scenarios use existing users and
reference data; the prerequisites below must already be satisfied.

Local runs continue to use `OPAL_USER_SERVICE_API_URL`, defaulting to
`http://localhost:4555`. A passing local run does not verify the shared staging
users, permissions or Jenkins connectivity; CI must exercise those prerequisites.
Testing support must remain disabled in production deployments.

### Draft Casefile deployed API journeys (PO-10287)

The five `@PO10287` scenario examples cover authorised creation, permission
denial, unknown application, inactive country and historical country. They
exercise the deployed Maintenance and User services in an agreed non-live
environment. Set both `TEST_URL` (Maintenance Service) and
`OPAL_USER_SERVICE_API_URL` (User Service) to the intended environment before
running either command; their localhost defaults are not suitable for deployed
verification. Do not put account passwords or bearer values in the command or
tracked files.

```bash
./gradlew functionalOpal -Dcucumber.filter.tags='@PO10287' -Dcucumber.execution.dry-run=true
./gradlew functionalOpal -Dcucumber.filter.tags='@PO10287'
```

The environment must already contain the authorised account
`opal-test@dev.platform.hmcts.net`, the account without Draft Casefile create
permission `opal-test-2@dev.platform.hmcts.net`, Business Unit 44, the
authorised user's Business Unit User ID `L044JG`, and Create and Manage Draft
Casefiles permission 21. The live reference set must include active Maintenance
Application `AP00001`, active country CJS code `1`, and result `MAT`. The
rejection cases use unknown application `ZZ99999`, inactive country CJS code
`0`, and historical country CJS code `2`. The tests never provision users or
reference data; missing or changed prerequisites are an environment-readiness
failure, not a reason to substitute mocks or create shared records.

The historical country example uses an inactive retired record, matching the
current active-flag validation.

Enable `TESTING_SUPPORT_ENDPOINTS_ENABLED=true` only in the agreed non-live
environment. A successful create is cleaned up with the merged
`DELETE /testing-support/draft-casefiles/{id}` API. Each scenario generates an
`E2E-` marker followed by 16 lowercase hexadecimal characters and sets
`casefile.respondent_account.remo_reference` to that value. Cleanup sends the
same marker in the required `Test-Run-Reference` header, accepts
`application/problem+json` as declared by the generated cleanup route, and uses the bearer token
captured when that draft was created. The ID is captured before response
assertions, so the after hook still attempts cleanup when an assertion fails.
An HTTP 204 confirms cleanup; a failed cleanup fails an otherwise passing scenario,
or attaches the ID, marker and safe failure reason to an already failed scenario.
No bearer values or response payloads are included in cleanup failure evidence.
See the [cleanup guide](DRAFT_CASEFILE_TEST_CLEANUP.md) for ownership, lifecycle,
enablement and retry requirements.

The support API also provides scoped publication-evidence registration and reads
for PO-10626; see the [support checks](#synthetic-draft-casefile-cleanup). There
is no marker-search route. These PO-10287 functional assertions check the real
POST response, including snapshot, timeline, ETag and correlated
permission/reference errors. Persistence,
rejected-request row absence and rollback are verified by `DraftCasefileDatabaseIntegrationTest` and
`DraftCasefileAuthenticationIntegrationTest`; cleanup isolation and actual row
removal are verified by `DraftCasefileCleanupIntegrationTest`. These database
assertions are integration coverage, not deployed functional evidence.

Server-error mapping and transaction rollback are verified by the controller and
database integration suites using persistence failures. The deployed functional
scenarios do not inject server failures or claim deployed rollback coverage.

The ticket's acceptance criteria are covered as follows:

| Acceptance criterion | Deployed functional coverage | Supporting integration coverage |
| --- | --- | --- |
| Create a submitted Draft Casefile with backend identity, submitter, snapshot and timeline | Authorised create example checks the POST response | `createsCommittedDraftWithUnchangedJsonDerivedDataAndAfterCommitLogs` verifies the committed row and derived JSON |
| Reject creation without Business Unit permission | Permission-denied example | `DraftCasefileAuthenticationIntegrationTest` verifies denied creation leaves no row |
| Reject unknown, inactive or out-of-date references | Unknown application, inactive country and historical country examples | `rejectsBadReferenceWithoutRowOrLog` verifies rejected validation leaves no row; validator tests cover reference rules |
| Return a correlated failure without retaining a partial Draft Casefile, snapshot or timeline | No deployed failure injection | `rollsBackSavedRowWhenPersistenceFails` verifies correlated 500/503 problems, absent success fields, row rollback and no publication in the same request |

Snapshot and timeline data are stored in the draft row, so verifying that no draft
row remains also verifies that no partial snapshot or timeline was retained.
The failure criterion is integration evidence, not a sixth deployed functional
example.

Run the functional helper regression tests without a Cucumber tag property.
Cucumber also discovers its suite during filtered runs, so use dry-run mode to
disable scenario actions while the JUnit helper tests execute normally:

```bash
./gradlew functionalOpal --tests 'uk.gov.hmcts.opal.*.DraftCasefile*Test' -Dcucumber.execution.dry-run=true
```

## Draft Casefile publication tests

The normal integration suite tests HTTP decisions and PostgreSQL transaction
boundaries with a controlled publisher. To test real broker acceptance, provision
an otherwise unused queue with a `test-` prefix and set `RUN_SERVICE_BUS_TESTS=true`
and `TEST_SERVICEBUS_QUEUE` to that queue's name. Supply the normal Service Bus
connection settings. For a disposable emulator exposed on a mapped port,
`TEST_SERVICEBUS_AMQP_URI` overrides the test connection URI (no credentials in the URI).

```bash
./gradlew integration --tests '*DraftCasefileQueueIntegrationTest'
```

These tests consume their synthetic messages from the dedicated queue. They prove
persistent ID-only publication, bounded connection failure, and that an accepted
message survives a later database rollback without successful-decision logging.
Do not point them at an application queue. Remove the test queue or disposable
emulator after the run; keep credentials out of files and command arguments.

The opt-in `@PO10631` functional scenarios require `RM_DRAFT_CASEFILE_CHECKER_USER`
and separate submitted synthetic drafts identified by
`RM_CHECKER_DRAFT_ID_PUBLISHING_PENDING`, `RM_CHECKER_DRAFT_ID_REJECTED`,
`RM_CHECKER_DRAFT_ID_DELETED` and `RM_CHECKER_SELF_DRAFT_ID`. The first three must
have a different submitter; the last must belong to the checker. Run against a
configured service with a broker and with the publication consumer stopped, then
reset the synthetic fixtures before rerunning. Do not use personal or live data.

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

New DB-04 migration-specific suites live directly under `src/dbUnitTest`,
named for the maintained database object and run by the
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
`dbUnitTest` task executes the fresh DB-01 path. The separate
[DB-03 framework PR #271](https://github.com/hmcts/opal-maintenance-service/pull/271)
is not integrated into this branch. It uses `OPAL-DB-UPGRADE` registration and
`dbUnitTestComparisonRef` / `dbUnitTestUpgradeMode`; these are not currently
executable interfaces here. Framework adoption, integration into each owning
suite and executed consumer evidence must precede an upgrade-coverage claim.
Until then, an applicable upgrade-path requirement remains unmet and must be
reported rather than claimed as verified. Representative upgrade setup and
synthetic data rules remain owned by the
[planned DB-03 guidance](DATABASE_MIGRATIONS.md#planned-db-03-upgrade-path-validation).

Select assertions from the migration-specific categories in the
[DB-04 database contract](DATABASE_MIGRATIONS.md#db-04-migration-specific-boundary-contract)
without copying that catalogue here. Follow the current
[DB-10 pgTAP execution contract](#db-10-pgtap-execution) for reusable assertion
mechanics and patterns, command-failing output, and the common evidence format.

### Planned DB-06 procedure-side testing

New stored-procedure suites live directly under `src/dbUnitTest`, named for
the maintained procedure and run by the
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
commands are `./gradlew checkstyleMain` and `./gradlew jacocoTestReport`.
PMD is not configured in the current build. For documentation-only or similarly
non-executable changes, run checks appropriate to the changed artefacts and
record why the baseline build was not run.

## Synthetic Draft Casefile cleanup

The [support guide](DRAFT_CASEFILE_TEST_CLEANUP.md) defines the shared default-off
flag, permission 21/current-inputter/exact-marker scope, HTTP contracts, and the
Cypress response-loss/CI-ledger sequence. All evidence must be captured before
DELETE removes the journal. Service checks use synthetic data in disposable
PostgreSQL 17 and signed JWT/local WireMock fixtures; no shared service or real
account is required for those automated checks. Real broker checks require the
isolated queue prerequisites [above](#draft-casefile-publication-tests).

```bash
./gradlew test --tests '*DraftCasefileCleanup*' --tests '*PublicationEvidence*' --tests '*ObservedDraftCasefileQueuePublisherTest'
./gradlew integration --tests '*DraftCasefileCleanup*' --tests '*DisabledDraftCasefileCleanup*' --tests '*PublicationEvidence*'
./gradlew processResources openApiGenerate compileJava --no-daemon
./gradlew test --tests '*OpenApiSchemaValidatorTest' --tests '*OpenApiRequestBodyAdviceTest'
./gradlew build --no-daemon
./gradlew jacocoTestReport
```

The response-only `PublicationEvidence` schema in `TestingSupport.yaml` generates
one `TestingSupportPublicationEvidence` model. Verify UUID `observation_id`,
offset date-time `registered_at`, nonnegative int64 counts (generated `Long`)
and boolean `evidence_complete`, with exactly seven response fields. Follow
[OpenAPI verification](OPENAPI_GUIDELINES.md#verification): inspect internal refs
and unique component names in `build/openapi-bundled.yaml`, generated getters and
types, and byte equality with `build/resources/main/openapi-bundled.yaml`.
Validation uses the packaged bundle; no separate validation-schema generation
task is required. Runtime OpenAPI tests must expose both authenticated evidence
operations only when support is enabled. Generation/compilation alone does not
prove runtime validation or security.

| Requirement | Automated service/database evidence | Consumer/deployed evidence still required |
| --- | --- | --- |
| Register once and read stable evidence without sending | `PublicationEvidenceIntegrationTest` checks 201 first/200 repeat, same observation/time, seven fields, lifecycle eligibility and no reset after approval | Frontend registers before the real mutation and retains the observation ID |
| Current BU permission 21, latest inputter and both draft/observation markers | `PublicationEvidenceAuthenticationIntegrationTest` uses signed JWT/User Service fixtures; `PublicationEvidenceIntegrationTest` covers scope denial and actual PUT handover | Environment credentials must resolve the current inputter; checker actions retain inputter ownership |
| Observe exactly one real producer invocation | `ObservedDraftCasefileQueuePublisherTest` checks delegation/ordering/failure; `PublicationEvidenceIntegrationTest` checks actual approval, non-approval, outer rollback and no automatic replay; `DraftCasefileQueueIntegrationTest` checks a dedicated real broker | Cypress captures every PATCH/PUT, loses the response after server-side completion, recovers with the existing GET journey, and asserts one mutation/one expected timeline entry |
| Complete, correctly scoped response-loss evidence | API tests cover acknowledged, uncertain and unfinished outcomes; `PublicationEvidenceRepositoryIntegrationTest` and `PublicationEvidenceWriterIntegrationTest` cover durable counters and independent transactions | Same observation, `evidence_complete=true`, approval counts `1/1/0/0` or reject/delete/PUT `0/0/0/0`; no service upgrade or undecorated producer during the interval |
| Atomic eligible cleanup and safe retries | `DraftCasefileCleanupIntegrationTest` covers POST-ID-to-DELETE, scope, lifecycle, embedded-data deletion, sibling/reference retention, rollback, repeats and PostgreSQL lock contention; `PublicationEvidenceIntegrationTest` covers journal/attempt rollback, old-marker cleanup after current-owner PUT, and orphan retention | Durable ID/marker/environment/scenario ledger; remove entries only after 204 and retain every failed cleanup |
| Default-off/disabled security and operational endpoints | Cleanup availability and disabled HTTP/runtime-doc suites check default-off, authenticated 404/anonymous 401; publication/API and operational suites cover `/`, `/health`, `/prometheus` | Verify resolved non-live flag and production-disabled values through normal deployment controls |
| Journal schema and fresh migration path | `draft_casefile_test_observations_pgtap_tests.sql` and `draft_casefile_test_send_attempts_pgtap_tests.sql` own V1_49 direct PostgreSQL boundaries through `dbUnitTest` | Deploy V1_49 before enabling support; predecessor-upgrade verification remains unmet below |
| Pending/published cleanup and actual consumer races | Current integration guards require 409 and preserve draft, graph and journal | `WP-CONSUMER` must deliver the actual consumer/writer protocol and verified cleanup/race behavior; this requirement is Not Agent Complete |

Counts above are attempts / acknowledged / uncertain / unfinished. Unregistered,
uncertain or unfinished evidence fails the recovery test's precondition, as do
disabled support, a missing broker prerequisite, a service upgrade during the
interval or a producer without the decorator. A send count is not a consumer
execution count or broker-level exactly-once proof; a transport exception does
not prove non-delivery. The service suites do not implement Cypress response
loss, a durable browser-independent ledger or deployed frontend GET assertions.

Additive V1_49 creates the journal tables without changing stored routines.
The existing `draft_casefiles_pgtap_tests.sql` and
`draft_casefiles_publication_link_pgtap_tests.sql` remain draft-schema coverage;
the new owning suites cover journal constraints, indexes and cascade behavior.
Endpoint deletion and transaction rollback remain application integration
coverage. Run the full build's `dbUnitTest` baseline and inspect timings,
PostgreSQL version and owned cleanup evidence in `build/reports/dbUnitTest`;
do not infer execution from compilation or task presence.

The journal's DB-03 upgrade check remains unmet with selected predecessor
`1.33`. Integrate the separately delivered framework PR #271 and the journal's
owning suites through the reviewed `OPAL-DB-UPGRADE` and
`dbUnitTestComparisonRef` / `dbUnitTestUpgradeMode` interfaces before executing
and recording predecessor preservation, candidate migration, assertions,
validation, repeat/no-op and owned cleanup. No standalone upgrade recipe or
harness is provided. Fresh migration and integration-test success do not close
this requirement.

Pending/published cleanup also remains **Not Agent Complete** under
`WP-CONSUMER`: the actual PO-10629 consumer is absent, and the separate PO-10655
procedure [PR #300](https://github.com/hmcts/opal-maintenance-service/pull/300)
does not establish the consumer protocol. Preserve 409 and retain outstanding
IDs/markers until actual graph ownership, missing/stale-draft handling and real
publication/cleanup races have been verified. There is no journal TTL or
background sweeper; scoped eligible DELETE is the retention mechanism.

Functional/smoke suites require a separately running agreed non-live service,
User Service permission 21 inputter, a distinct checker with its normal decision
permission, compatible migrations, enabled support and a dedicated broker queue.
Expected evidence includes registration 201/repeat 200, current-owner reads,
unchanged observation, one approval acknowledgment, scope 403 and disabled 404.
Document omitted external checks with that setup and expected result. Do not
enable support or exercise cleanup against shared data during routine local
verification. Human QA, deployment and frontend adoption remain separate from
these service checks.

## Test design

Mirror production packages, use `*Test`, and assert observable behaviour. Cover validation, error, empty, and configuration paths affected by a change. Keep Testcontainers and network boundaries explicit; do not make unit tests depend on them.

Authentication integration tests generate their own JWTs at runtime and use
WireMock for User Service responses. They do not require a real AAD tenant or
User Service. The Bruno collection is a separate, optional manual check for a
real AAD/User Service setup; enable testing-support endpoints explicitly with
`TESTING_SUPPORT_ENDPOINTS_ENABLED=true` before using its ping or authenticated
diagnostic requests. Never place a bearer value in a tracked Bruno file.

## Routine suites and framework gaps

Follow the authoritative [pgTAP suite layout](#pgtap-suite-layout) for placement,
single-suite ownership, SQL/pgTAP assertions and coordination, runner
restrictions, and existing-path exceptions. This section adds verification and
tooling-gap requirements to that layout contract.

For a required multiple-session concurrency scenario, identify the actual
SQL/pgTAP mechanism in the owning suite, its disposable-harness prerequisites,
independent sessions, bounded coordination, command-failing assertions, and
verified cleanup. In-suite test-only `dblink` coordination, as used by the
account-number allocator suite, can execute through `dbUnitTest` without a
separate Gradle orchestration hook. Confirm the mechanism's availability and
execution evidence for the scenario; neither a missing shared hook nor test
source alone establishes whether the required coverage is verified.

The current `gradle/db-unit-test.gradle` implements the fresh DB-01 path and
has no maintained predecessor target. A standalone upgrade recipe does not
establish a maintained DB-03 framework capability.

If mandatory coverage requires an unavailable mechanism, include a concrete
enabling task or linked, independently reviewable work package under
[Required prerequisite delivery](CONTRIBUTING.md#required-prerequisite-delivery).
Record the scenario and tooling gap, and make the package's owner or assignment
status, deliverable and current versus proposed interface, consuming-suite
integration, sequence and acceptance evidence explicit. An owner or future
framework reference alone is insufficient. The full delivery plan is blocked
while that package or a required decision is absent; bounded routine work that
does not depend on it can still progress. Keep the required coverage visible
and unmet until the supported SQL/pgTAP mechanism can execute it through the
maintained framework and execution evidence proves it. Do not omit coverage or
claim availability based on a proposed hook. The existing
[DB-03 unmet upgrade requirement policy](#db-04-pgtap-test-placement) still
applies.

Any future framework phases that carry test observations across connections
must define their state lifetime, ownership and cleanup, with a coordinated,
narrowly scoped amendment to the transaction guidance when the framework is
delivered. A proposed phase interface grants no transaction exception: the
current pgTAP suite requirement to end with `ROLLBACK` remains in force.

## DB-10 pgTAP execution

Database contracts live under `src/dbUnitTest`. `dbUnitTest` discovers both
`*_pgtap_tests.sql` and `*_unit_tests.sql` recursively and executes them through
`pg_prove`. New database contracts use `*_pgtap_tests.sql` for DB-04;
the `*_unit_tests.sql` suffix remains supported for existing suites.
For a database object's schema contract, combine catalogue and behavioral
assertions in one `*_pgtap_tests.sql` suite rather than splitting them by test
type.
Follow the [pgTAP suite layout](#pgtap-suite-layout) for all new or updated
database-owned tests.
The existing Maintenance Applications suite combines these checks in
`maintenanceApplicationsTest/maintenance_applications_pgtap_tests.sql`.
Introduced or changed routines use the owning suite and framework-gap rules in
[Routine suites and framework gaps](#routine-suites-and-framework-gaps).
Discovered suites are part of Gradle and the normal `check` lifecycle.

The task runs two fixed fresh PostgreSQL 17 profiles with pgTAP. `non-live-dev`
applies `ddl`, `data/allEnvs`, `data/nle`, and `data/dev`; `non-live` applies
`ddl`, `data/allEnvs`, and `data/nle`, proving the common NLE seed without DEV.
Each profile has its own empty disposable database, Flyway validation and
no-op second migration, the complete discovered pgTAP suite set, report, and
verified container cleanup. Both profiles run even if one fails; either failure
fails `dbUnitTest`. Normal `./gradlew dbUnitTest` and `./gradlew build` run both
profiles. Staging currently adds no SQL under `data/stg`; this common NLE check
does not claim validation of future staging-specific migrations. The task fails
closed when application or external Flyway target settings are present, so it
cannot fall back to a developer-owned or shared database. Failure output lists
setting names only and never their values.

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
`build/reports/dbUnitTest/non-live-dev` and `build/reports/dbUnitTest/non-live`.
`build/reports/dbUnitTest/summary.txt` records the current aggregate result
and each profile's cleanup outcome.
The current Countries contract is
`src/dbUnitTest/countriesTest/countries_pgtap_tests.sql`.

### pgTAP file headers

Every new or amended pgTAP suite must start with a file-level header containing
`OPAL Program`, `MODULE`, `DESCRIPTION`, and `CHANGE HISTORY`. Use the filename
for `MODULE` and describe the suite's purpose and scope in `DESCRIPTION`.
Change history must record the date, responsible human contributor, Jira ticket,
and change summary. Never use `Codex` or another agent name as the author; ask
if the responsible contributor is unknown. Preserve trustworthy existing history
and append the current change; do not invent historical entries or add a manual
version number.

For a new suite, the initial entry describes its introduction (for example,
`Initial pgTAP test suite.`) and uses the evidenced creation date. Later entries
describe the test coverage added or changed for the relevant table or routine;
an existing suite receives an update entry, not a new initial-suite entry.

When an existing suite lacks a header, recover its initial entry and relevant
subsequent coverage changes from verified Git or ticket evidence, then append
the current change. Report missing historical details rather than guessing
them. Adding the header must not change executable SQL, fixtures, assertions,
or the pgTAP plan count.

```sql
/**
 * OPAL Program
 *
 * MODULE      : <test_filename.sql>
 *
 * DESCRIPTION : <suite purpose and scope>
 *
 * CHANGE HISTORY:
 *
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * DD/MM/YYYY  <contributor> <JIRA-KEY>    <change summary>
 */
```

These conventions apply to new and amended suites; do not modify unrelated
legacy tests solely to add headers.

### pgTAP suite layout

- Give each function or stored procedure one self-contained pgTAP suite named
  `<routine_name>_pgtap_tests.sql`. Keep all scenarios and assertions for that
  routine in that file. Use the same single-suite approach for a database
  object's schema contract; schema and reference-data contracts retain their
  existing separate ownership.
- Place every new suite directly under `src/dbUnitTest`. Do not create object,
  feature, ticket, `support` or other subdirectories beneath that test root.
  Identify the tested routine or object in the suite filename instead.
- Keep routine-specific setup, synthetic fixtures, independent expected
  results, temporary SQL helpers and cleanup inside the owning suite. Do not
  split them into separate setup, fixture, boundary or concurrency SQL files,
  and do not include another suite or support SQL using `\i` or `\ir`.
- Database assertions, routine test coordination, fixtures, test-only SQL
  helpers and cleanup stay inside self-contained SQL/pgTAP suites. Run the
  suites through the existing Gradle-owned `dbUnitTest` framework. Do not add
  Python or shell database test runners for assertions or test coordination,
  including ignored, generated, or temporary scripts and executable runbook
  recipes, or shell commands inside a suite through `\!`, `COPY ... PROGRAM`
  or an equivalent mechanism. This restriction concerns database testing;
  unrelated metadata or documentation tooling and the existing shared Gradle
  lifecycle orchestration remain permitted.
- Keep interaction checks in the consuming routine's suite. Preserve applicable
  success, boundary/failure, row-scope, repeat, rollback and real concurrency
  coverage within that suite. If required SQL-only tooling is unavailable,
  report the gap rather than silently dropping coverage or adding a shell
  runner.
- README documentation may sit directly alongside the suites. Existing suites,
  authoritative reference-data fixtures and framework self-tests retain their
  current paths unless their relocation is explicitly in scope; their legacy
  folders are not a precedent for new suite layout. Do not add new routine
  support files.

For example, two functions have two independently discoverable suites directly
under the database test root:

```text
src/dbUnitTest/
├── f_get_check_letter_pgtap_tests.sql
├── f_get_account_number_pgtap_tests.sql
└── README.md
```

### pgTAP scenario introductions

Keep a single object-focused suite and retain its existing assertion
descriptions. Every new or amended suite must introduce each meaningful
behavioural scenario with a SQL comment block explaining `Scenario`, `Setup`,
and `Expected`, enclosed by matching separator lines above and below the block.
Related schema assertions may share a header; do not add manually
maintained test numbering. The required pgTAP `plan` remains unchanged for
comment-only edits.

For example, a missing-parent scenario can be introduced with:

```sql
-- -----------------------------------------------------------------------------
-- Scenario: A Business Unit refers to a parent that does not exist.
-- Setup: Insert a child with parent_business_unit_id = 31999, which is absent.
-- Expected: The foreign key rejects the insert with SQLSTATE 23503.
-- -----------------------------------------------------------------------------
```

Keep headers accurate about fixture dependencies and outcomes, rather than
merely repeating the SQL. This example requires parent `31999` to be absent
and all other insert requirements to be satisfied so that the foreign key is
the reason for rejection. Describe the actual setup when a scenario relies on
earlier fixtures. Choose scenario boundaries from the behaviour being tested,
not a target number of headers or assertions. Adding these introductions must
not change coverage or executable SQL, split the suite, or introduce a new
framework.

## Infrastructure and evidence

Integration tests need Docker for Testcontainers. HTTP functional and smoke
checks need a running service. Record exact commands, results, environments,
and manual scenarios. For every relevant skipped check, record the reason, the
scenario, the setup needed to execute it, and the expected result. A successful
pipeline is not evidence that every changed scenario ran.

For Flyway or SQL changes, follow the fresh-database, upgrade-path, database-boundary, and evidence requirements in [Database Migrations](DATABASE_MIGRATIONS.md).

## Major Creditor reference-data prerequisites

PO-10294 and PO-10297 use authenticated HTTP requests against existing
Maintenance reference data, following the Fines seeded-data test pattern.
Use the normal `TEST_URL` and `OPAL_USER_SERVICE_API_URL` configuration
described above. No functional fixture database, JDBC credentials, owner
table, sequence, test inserts or cleanup hooks are required.

The target must contain the approved BU 44 Central Authority seed from
`V1_10__insert_major_creditors_reference_data.sql`, including code `0001`.
Central Authority checks require a nonempty result and verify the seeded
record's casefile details; they do not assume generated identifiers or
exactly ten records.

PO-10297 positive coverage originally required the DEV-only
`data/dev/V1_33__insert_major_creditors_dev_data.sql`, applied through normal
Flyway migration with `ddl`, `data/allEnvs` and `data/dev` selected. It adds
three synthetic BU 44 records: active non-Central Authority `T901`, inactive
non-Central Authority `T902`, and active Central Authority `T903`. The positive
scenario requires T901's exact casefile details, excludes T902/T903, and allows
additional qualifying creditors without assuming generated IDs or an exact
result count. Malformed-filter and authentication scenarios remain covered.

The DEV-only synthetic reference-data contract was approved by the requester
on 2 October 2026; see `src/dbUnitTest/majorCreditorsDevDataTest/README.md`.
The saved PO-10297 ticket draft originally called for test-owned data. The
subsequently approved strategy uses seeded reference data and read-only HTTP
steps. On 21 October 2026 the requester expanded that strategy to every
non-live environment, following the Fines common-NLE pattern. This is a scope
amendment to record in the PR; it does not establish a Jira update or deployed
approval. `data/nle/V1_34__insert_major_creditors_nle_data.sql` supplies the
same three records through the common NLE location. Historical DEV V1_33 and
its approval and verification evidence remain unchanged.

The checked-in local application default and DEV Helm template select
`ddl + allEnvs + nle + dev`; the staging Helm template selects
`ddl + allEnvs + nle`. The production base Helm values select only
`ddl + allEnvs`, excluding both synthetic-data locations. These files do not
prove the effective settings of a running deployment. Separately managed
`FLYWAY_LOCATIONS` overrides, the image contents and migration history must be
checked per target. The repository has migration directories for demo, ITHC
and performance, but no checked-in deployment overlay for those targets; if
any is deployed, inventory its effective locations and include `data/nle` for
this approved non-live scope before running positive scenarios. Do not infer
coverage from an environment name or add an unconfigured overlay.

V1_34 inserts exactly three rows when none of the BU 44 T901/T902/T903 keys
exists. If all three rows exactly match the approved fields and Country, it
makes no change, preserving DEV V1_33's generated IDs. A partial set or any
conflicting field fails the migration atomically and needs investigation;
neither case is silently repaired or skipped. The migration resolves the
existing Czech Republic uniquely and leaves unrelated creditors intact.
The owning flat pgTAP suite checks both fresh profiles, including direct rerun,
all fields, rollback and failure atomicity. The existing DEV suite remains in
the discovered suite set for both profiles and verifies the historical V1_33
contract without requiring that migration in common NLE Flyway history.
Local disposable verification does not establish shared-environment deployment
or QA sign-off. Positive coverage requires both approved data and a passing
live scenario; an empty response cannot satisfy the positive acceptance
criterion. Apply the appropriate non-live migration locations before executing
positive functional tests.
Before rollout, confirm the target's effective `FLYWAY_LOCATIONS`, deployed
image and `flyway_schema_history` script names. Inspect the earlier seed names
V1_15, V1_17 and V1_31 as well as V1_33; a version number alone may refer to
another migration. Apply V1_34 through normal Flyway deployment after `ddl`
and `allEnvs`. If history is incompatible, stop and obtain a separate approved
database-owner recovery decision; never automatically repair history or edit an
applied migration. After deployment, refresh affected BU 44
`majorCreditorReferenceDataCache` entries through the approved administration
route, using the actual environment/cache prefix. Include
`44_noFilter_noFilter`, `44_false_true` and any other cached BU 44 filter
combinations in use. Do not flush Redis globally. Redis TTL defaults to eight
hours, and restarting a pod does not clear Redis. Then rerun the live positive,
malformed-filter and authentication scenarios against an agreed compatible
non-live Maintenance and User Service target. Cache refresh and migration are
rollout actions, never functional-test setup or cleanup hooks.
Targets that select `allEnvs` without `dev` require the approved `nle` location
when non-live functional coverage runs. Do not enable DEV or NLE data in
production. Tests make read-only HTTP requests and never insert, update or
clean up reference data. V1_33 remains historically one-shot, while V1_34
accepts an exact direct rerun and rejects partial or mismatching data.
See `src/dbUnitTest/majorCreditorsDevDataTest/README.md` for fresh/upgrade scope
and historical database-boundary assertions. Fresh checks do not establish
deployment, positive functional execution, or predecessor upgrade readiness.


## Results reference-data functional prerequisites

PO-10298 follows the Fines seeded-data pattern: all four scenarios use normal
TEST_URL and the existing OPAL_USER_SERVICE_API_URL. The all-environment Results
baseline contains MAT / Matrimonial Order for Adult, MCHILD / Maintenance Order
for child(ren), and MLUMP / Lump sum order as the three active Order Terms.
There are no inactive Order Terms. Normal service startup applies the configured
Flyway locations; functional tests do not insert, delete or alter reference data.

The empty live scenario requests order_term=true&active=false and asserts count
0 with refData []. It is named for that inactive precondition. The original
no-active-Order-Term condition is covered in ResultsDatabaseIntegrationTest with
owned per-test rows and the exact order_term=true&active=true request. These are
separate coverage statements. No special Results target URL or fixture database
is required. Incompatible baseline data is a test failure, not a skip.

Run the live parent scenarios:

    ./gradlew functionalOpal -Dcucumber.filter.tags=@JIRA-STORY:PO-10298

Validate discovery separately:

    ./gradlew functionalOpal -Dcucumber.filter.tags=@JIRA-STORY:PO-10298 -Dcucumber.execution.dry-run=true

Run assertion checks without a Cucumber tag property:

    ./gradlew functionalOpal --tests 'uk.gov.hmcts.opal.steps.ResultsStepDefTest'

Preserve scenario names, test/failure/error/skipped counts, exact command,
elapsed time and non-sensitive setup notes before the next functionalOpal run
clears reports. Discovery and HTTP mocks are not live API evidence. Review raw
reports before sharing; never archive bearer headers, tokens or reusable
connection credentials. A normal full functional/smoke run also needs the other
journeys' documented data and compatible authentication service.

## Result detail functional coverage

PO-10301 uses the same normal TEST_URL and OPAL_USER_SERVICE_API_URL as the list
scenarios. MLUMP / Lump sum order is supplied by the maintained all-environment
baseline; ZZZZZZ is an explicitly unallocated identifier. Functional requests
are read-only and need no synthetic inserts, fixture database or special detail
URL. Existing authentication remains enabled.

The three live scenarios verify selected seeded details and meaningful Amount
metadata, correlated 404 for an absent identifier, and 401 without Result data
for an unauthenticated request. MLUMP's Amount uses decimal-2dp, prompt “Amount
of order”, mandatory true, minimum 0 and maximum 9999999999.99.

Inactive retrieval (200), unfamiliar metadata passthrough (200), explicit SQL
null and encoded [] are covered in ResultDatabaseIntegrationTest using owned
per-test data and cache reset. The original active-empty list condition is
separately covered in ResultsDatabaseIntegrationTest. These integration cases
are not counted as live functional scenarios; this is the requester-approved
coverage/data-strategy amendment to the original ticket requirements.

Validate discovery:

    ./gradlew functionalOpal '-Dcucumber.filter.tags=@JIRA-STORY:PO-10298 or @JIRA-STORY:PO-10301' -Dcucumber.execution.dry-run=true

Run both stories live against the normal seeded service:

    ./gradlew functionalOpal '-Dcucumber.filter.tags=@JIRA-STORY:PO-10298 or @JIRA-STORY:PO-10301'

Expect seven Results scenarios: four list and three detail. Missing baseline
records, an allocated absent identifier or incompatible authentication is a
setup/test failure, never a skip or a reason to mutate reference data. Preserve
non-sensitive reports before later invocations clear them. The full functional
suite also needs all other documented reference-data prerequisites.
