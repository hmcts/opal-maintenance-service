# Database Migrations

## Authority and ownership

This repository owns the Flyway migrations and schema evolution for the Opal Maintenance Service database. Shared cloud PostgreSQL servers and logical databases are provisioned outside this repository by `opal-shared-infrastructure`; local development and integration tests use separate PostgreSQL instances.

`opal-maintenance-db` is the default logical database name, not one central physical database. Checked-in executable configuration and the migration tree take precedence over this guide when they disagree; correct the documentation in the same change.

The conventions follow established Opal backend practice, but this guide is self-contained. Work in this repository must not require another service checkout.

## Migration locations

The migration tree is organised by purpose and intended environment scope:

- `ddl` contains tables, columns, types, sequences, constraints, indexes, views, functions, procedures, and subsequent schema changes.
- `data/allEnvs` contains reference or configuration data required wherever that location is selected.
- `data/dev`, `data/nle`, `data/stg`, `data/demo`, `data/ithc`, and `data/perfTest` contain only data intended for their named environment scope.

`FLYWAY_LOCATIONS` selects active locations. Inspect `src/main/resources/application.yaml` and the Helm values before choosing a directory; do not assume every directory is active everywhere. Do not place environment-specific records, development fixtures, or production-derived personal data in `allEnvs`.

## Naming and version allocation

Use the filename form `V1_<number>__lower_snake_case_description.sql`. Allocate a version across the complete `src/main/resources/db/migration` tree, not separately per directory. Search the complete tree and recheck the target branch before finalising a version, because another change may have allocated it since the branch was created.

Use this safe discovery command when allocating a version:

```bash
find src/main/resources/db/migration -type f -name 'V*__*.sql' -print | awk -F/ '{ print $NF "\t" $0 }' | sort -V -k1,1 | cut -f2-
```

The existing first migration is `V1_1__db_description.sql`; a future version must still be checked against the target branch rather than assumed to be `V1_2`.

## Immutability and forward fixes

Applied migrations are never edited, renamed, deleted, or renumbered. Correct a mistake in an applied migration with a later forward migration. Do not normalise existing version gaps or historical naming anomalies as incidental cleanup.

## Migration headers

### Selecting the applicable header

Every new Flyway migration, other than a generated baseline migration, must use the applicable header:

- An ordinary schema or data migration uses one file-level header at the start of the migration.
- A routine-only migration uses an embedded header immediately after `AS $$` for each stored procedure or function.
- A mixed migration uses one file-level header and an embedded header immediately after `AS $$` for each stored procedure or function.

Historical view migrations use inconsistent header formats and history. The rules in this section apply prospectively; do not edit earlier migrations solely to align them.

### Required header fields

Every file-level and embedded header must contain:

- `OPAL Program`.
- `MODULE`, identifying the migration file for a file-level header or the stored procedure or function for an embedded header.
- `DESCRIPTION`, stating the purpose and scope of the migration or routine.
- `CHANGE HISTORY`, with `Date`, `Author`, `Ticket`, and `Nature of Change` columns.

Do not add a manual `Version` field; the Flyway filename is the migration version. An embedded stored procedure or function header must also contain `PARAMETERS`, documenting every `IN`, `OUT`, and `INOUT` parameter in signature order. Update the parameter documentation whenever a parameter's signature or meaning changes. File-level headers, including headers for view migrations, do not contain `PARAMETERS`.

### Carry-forward history rules

For tables, columns, constraints, types and enums, indexes, sequences, and data changes, record only the current migration in `CHANGE HISTORY`; do not carry forward earlier object history. A newly created object starts with one current change row.

When a view, stored procedure, or function is replaced or recreated, carry forward its trustworthy object history from the latest authoritative migration or consolidated baseline and append one row for the new change. A new view, stored procedure, or function starts with one current change row.

Earlier Flyway migrations remain immutable. Never invent, reconstruct, renumber, or silently normalise missing or ambiguous history. Raise any history gap for review before finalising the new migration.

### Standard migration and view template

```sql
/**
 * OPAL Program
 *
 * MODULE      : <migration_filename.sql>
 *
 * DESCRIPTION : <concise purpose and scope>
 *
 * CHANGE HISTORY:
 *
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * DD/MM/YYYY  <author>      <ticket>      <change summary>
 */
```

For a replaced or recreated view, place any trustworthy carried-forward rows above the new current change row.

### Stored procedure and function template

Place this embedded header immediately after the routine's `AS $$`:

```sql
AS $$
/**
 * OPAL Program
 *
 * MODULE      : <procedure_or_function_name>
 *
 * DESCRIPTION : <purpose and behaviour>
 *
 * PARAMETERS  : IN    <parameter_name>  - <meaning>
 *             : OUT   <parameter_name>  - <meaning>
 *             : INOUT <parameter_name>  - <meaning>
 *
 * CHANGE HISTORY:
 *
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * DD/MM/YYYY  <author>      <ticket>      <change summary>
 */
```

Replace the sample parameter rows with one row for every parameter in the routine signature, retaining signature order. For a replaced or recreated routine, place any trustworthy carried-forward change rows above the new current change row.

## Safe schema changes

When an application and schema cannot change atomically, prefer expand, backfill, and contract sequencing. Preserve compatibility with the currently deployed application until the rollout no longer needs it.

Before writing a migration, assess lock duration, table rewrites, index creation, constraint validation, statement duration, and the volume of affected rows. Backfill and verify existing rows before making a column non-null or adding a restrictive constraint. Use explicit constraint and index names consistent with nearby maintained migrations. Keep each migration focused and avoid unrelated schema cleanup.

Every Flyway migration that creates a persistent table must include, in the same migration, a descriptive `COMMENT ON COLUMN` statement for every column in that table. A `COMMENT ON TABLE` statement is not required. This requirement applies prospectively; do not edit historical migrations or generated baseline migrations solely to add missing column comments.

## Data migrations and environment scope

Use deterministic inserts and updates with precise predicates. For backfills or destructive data changes, define expected row counts and post-migration queries. Review sequences after inserting explicit identifiers or large seed sets.

Do not put secrets, credentials, tokens, PII, or production-derived records in migrations, fixtures, comments, logs, or evidence. Explain clearly why data belongs in `allEnvs` or in a named environment directory.

## Connection configuration

Application and Docker execution use `OPAL_MAINTENANCE_DB_HOST`, `OPAL_MAINTENANCE_DB_PORT`, `OPAL_MAINTENANCE_DB_NAME`, `OPAL_MAINTENANCE_DB_USERNAME`, `OPAL_MAINTENANCE_DB_PASSWORD`, `OPAL_MAINTENANCE_DB_OPTIONS`, `RUN_DB_MIGRATION_ON_STARTUP`, and `FLYWAY_LOCATIONS`.

Direct Gradle Flyway tasks use `FLYWAY_URL`, `FLYWAY_USER`, `FLYWAY_PASSWORD`, and `FLYWAY_LOCATIONS`. `migratePostgresDatabase` can additionally use `-Pdburl`.

Connection values for shared environments come from platform-managed secrets and must not be copied into source control, shell history, logs, or review evidence.

## Flyway commands

```bash
./gradlew flywayInfo
./gradlew flywayValidate
./gradlew flywayMigrate
./gradlew migratePostgresDatabase
```

`flywayInfo` and `flywayValidate` inspect or validate the configured target. `flywayMigrate` and `migratePostgresDatabase` modify it. Before any modifying command, resolve and confirm the exact host, port, database, environment, and credentials.

`flywayClean`, `flywayRepair`, `flywayBaseline`, direct edits to `flyway_schema_history`, and ad hoc SQL against a shared database are recovery or administrative actions requiring explicit authority and an approved runbook. They are not normal development steps.

## Validation and testing

### Local Compose and fresh-database validation

Normal Docker Compose use intentionally retains the named PostgreSQL volume
after `docker compose down`. This preserves local development data, but neither
restarting that database nor running the backend integration suite is evidence
of a dedicated fresh-database migration check.

The planned fresh and disposable path is the
[DB-01 contract below](#planned-db-01-fresh-database-contract); Testing owns its
suite entry point and availability status. The direct Flyway tasks above
operate against a configured target and do not create or clean up a disposable
database. Do not substitute persistent Compose, backend tests, or a configured
database target for the planned workflow.

> **Destructive:** `docker compose down --volumes` deletes the developer-owned
> named volume and its local database data. It is not part of routine migration
> validation.

### Planned DB-01 fresh-database contract

DB-01 defines the migration-safety and database-outcome contract for the future
`dbTest` task. Its suite ownership, lifecycle integration, reporting,
and current availability are documented in
[Testing](TESTING.md#planned-db-01-suite-semantics).

The fresh-database workflow must:

1. Start a disposable PostgreSQL 17 Testcontainer and create a test-owned
   logical database with test-owned connection details.
2. Confirm the logical database has the expected empty start state and no
   Flyway history or application-owned objects.
3. Configure Flyway programmatically with an explicit list of repository
   migration locations. Do not inherit application or environment location
   defaults. Each required location must exist.
4. Configure baseline behaviour explicitly. Automatic baselining is disabled
   for the empty-start scenario so every selected migration is applied.
5. Migrate and assert the expected applied migration count and versions, final
   Flyway state, and required schema, object, and reference-data outcomes.
6. Run Flyway validation, then migrate a second time and assert that no
   migration is applied on the second run.
7. Clean up the logical database and container automatically and confirm that
   cleanup completed.

Fail closed before migration if an external JDBC URL, credential, or target
override is present, the resolved target is not test-owned and disposable, a
required migration location is missing, or the starting state is invalid. Also
fail on a migration, validation, or assertion error and when cleanup cannot be
confirmed. Never fall back to a developer-owned or shared database.

Return only non-sensitive results to the evidence report defined in Testing.
Do not expose production data, PII, secrets, credentials, or reusable
connection details.

Representative predecessor-based upgrades remain owned by the
[DB-03 guidance below](#planned-db-03-upgrade-path-validation). The
[DB-04 contract below](#planned-db-04-migration-specific-boundary-contract)
owns migration-specific boundary assertions; DB-01 requires their relevant
outcomes without redefining that contract here.

### Planned DB-03 upgrade-path validation

DB-03 extends the planned DB-01 database-owned `dbTest` framework. It
does not create a second framework and must not use Spring or backend
integration-test fixtures. Testing owns the suite's availability status; the
following requirements describe the planned workflow only.

For a candidate migration with an immediate predecessor, use this
Flyway-native sequence:

1. Start a disposable PostgreSQL instance.
2. Apply the selected migration locations only through the candidate's
   immediate predecessor, allowing existing migrations to establish the prior
   schema and normal reference data.
3. Add no further rows when the candidate does not depend on existing data. If
   it does, require an approved data-scenario contract that defines the
   pre-change conditions, business and edge cases, and expected outcomes. The
   process and owner for producing and approving that contract remain to be
   decided. Translate only its approved cases into the smallest deterministic
   synthetic dataset.
4. Apply the candidate migration.
5. Assert the relevant schema, reference-data, and affected-row outcomes.

An initial migration with no predecessor uses the fresh-database path from an
empty disposable database. Record its predecessor and upgrade setup as not
applicable rather than manufacturing a prior schema.

Never source non-reference test data from staging, NLE, production, or another
environment. If a real incident identifies an important data shape, manually
reduce and recreate it as synthetic test data; never copy the original row.
Exercise volume, locking, or performance behaviour with generated synthetic
data under a separately scoped test. Environment-derived fixtures and database
snapshots are prohibited by default, and this guide provides no generic
snapshot exception.

If the approved data-scenario contract is absent or ambiguous, the
implementation agent must fail closed: do not invent or extract non-reference
data, and pause until an approved scenario is provided.

### Planned DB-04 migration-specific boundary contract

Every migration must declare the database contract it affects and the direct
PostgreSQL assertions needed to prove that contract. The declaration belongs
with the migration-focused test or specification described in
[Testing](TESTING.md#planned-db-04-test-placement).

Select only the categories relevant to the actual migration:

- Flyway state or version when the migration needs a migration-specific check.
- Schemas and database objects.
- Columns, types, defaults, and nullability.
- Primary, unique, foreign, and check constraints and their keys.
- Indexes.
- Views.
- Database comments.
- Privileges and ownership.
- Routines and their direct SQL outcomes, including the
  [DB-06 contract below](#planned-db-06-stored-procedure-responsibility-contract)
  for stored procedures.
- Affected reference or business data, including expected row outcomes.

Do not require every category for every migration or add assertions for
unaffected behaviour. If no direct boundary assertion is required, state
`No migration-specific boundary assertions required` and justify why.

For each selected assertion, state whether it applies to the fresh DB-01 path,
the DB-03 upgrade path, or both. A non-applicable path requires a documented
reason. Execute assertions directly against PostgreSQL rather than through
Spring, backend repositories, or backend integration-test fixtures.

Future DB-10 guidance will own reusable assertion mechanics and patterns, how
assertion failures surface in command output, and the common evidence format.
DB-04 defines the required migration-specific contract and outcomes without
duplicating those future mechanics.

### Planned DB-06 stored-procedure responsibility contract

DB-06 owns the responsibility boundary for stored procedures introduced or
changed by migrations. A stored procedure performs its declared database work
and raises a PostgreSQL exception when that work cannot complete. It must not
commit, roll back, or otherwise own a transaction boundary, and it must not
create or update run-status records. The calling backend service owns the
transaction boundary and the run-status lifecycle; this guide does not
prescribe the backend implementation mechanics. Record any required backend or
status-persistence change as separate work outside this database workstream.

The contract for each introduced or changed procedure must document:

- Inputs and input validation.
- Outputs or result shape.
- Affected-row scope and other database side effects.
- SQLSTATE and error behaviour.
- Locking and concurrency expectations.
- Retry and idempotency expectations.

The migration ticket must identify the impact on each relevant part of this
contract and map it to the applicable DB-04 migration-specific assertions.
Planned direct PostgreSQL checks for the procedure-side outcomes are described
in [Testing](TESTING.md#planned-db-06-procedure-side-testing). DB-01 owns that
suite's lifecycle, DB-03 owns approved predecessor and row-dependent scenarios,
and DB-10 will own reusable assertion mechanics and evidence formatting.

Collect evidence proportionate to the change:

- Apply the selected locations to a fresh PostgreSQL database.
- Upgrade a representative existing schema when prior data or objects affect the change.
- Run `flywayValidate` against the intended target configuration.
- Execute the applicable DB-04 direct PostgreSQL assertion declaration,
  including error and empty outcomes where relevant.
- Record exact commands, target type, selected locations, results, and reasons for skipped checks.
- Never claim a shared environment or deployment was validated unless it actually was.

## Release and recovery evidence

Record target environments and selected locations, deployment order, and compatibility with the current and incoming application versions. Include expected affected rows, duration, locking, downtime, and post-migration checks.

Distinguish rolling back application code from recovering database state. After an applied migration, use a forward-fix migration unless an approved restore or recovery plan is required for possible data loss.

## Agent and reviewer checklist

- Confirm ownership and environment scope are understood.
- Confirm the version is unique across the complete tree and has been rechecked against the target branch.
- Confirm no applied migration was modified.
- Confirm compatibility, locking, duration, data volume, and sensitive-data concerns were assessed.
- Confirm fresh-database and upgrade-path validation were considered.
- Confirm exact evidence, skipped checks, and recovery implications were recorded.
