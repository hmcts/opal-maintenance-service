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

Committed or deployed migrations are never edited, renamed, deleted, or
renumbered. Correct a mistake with a later forward migration. An open pull
request does not make a committed migration editable. Do not normalise existing
version gaps or historical naming anomalies as incidental cleanup.

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

`Author` must identify the responsible human contributor. For agent-assisted
changes, use the human owner confirmed for the work, never `Codex` or another
agent name. Ask if that owner is unknown. Preserve trustworthy historical
attribution; this rule does not authorise rewriting applied migrations.

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

Retain the blank comment lines shown in the template between `OPAL Program`,
`MODULE`, `DESCRIPTION`, `PARAMETERS` and `CHANGE HISTORY`, and before the
change-history column headings. Keep continuation lines within each section
together.

New Maintenance stored procedures use the common explicit outer exception
block. Preserve the embedded header above; the following separate body example
uses `NULL` only as a placeholder for the routine's declared database work:

```sql
BEGIN
    -- Perform the routine's declared database work.
    NULL;

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
```

Use this shape when amending an existing procedure under an agreed contract,
through a forward migration where its current definition is immutable. This
does not require retrofitting every historical procedure or function. See
[Exception messages and defaults](#exception-messages-and-defaults) for the
error and diagnostic contract.

## Safe schema changes

When an application and schema cannot change atomically, prefer expand, backfill, and contract sequencing. Preserve compatibility with the currently deployed application until the rollout no longer needs it.

Before writing a migration, assess lock duration, table rewrites, index creation, constraint validation, statement duration, and the volume of affected rows. Backfill and verify existing rows before making a column non-null or adding a restrictive constraint. Use explicit constraint and index names consistent with nearby maintained migrations. Keep each migration focused and avoid unrelated schema cleanup.

Every Flyway migration that creates a persistent table must include, in the same migration, a descriptive `COMMENT ON COLUMN` statement for every column in that table. A `COMMENT ON TABLE` statement is not required. This requirement applies prospectively; do not edit historical migrations or generated baseline migrations solely to add missing column comments.

## SQL readability

In `CREATE TABLE` definitions, use spaces to align column names, data types,
and `NOT NULL` clauses across the column block. For example, these column
definitions are an excerpt, not a complete table definition:

```sql
    business_unit_id        SMALLINT                         NOT NULL,
    business_unit_type      public.t_business_unit_type_enum NOT NULL,
```

Keep each `COMMENT ON COLUMN` statement, including its description, on one
physical line. Use spaces to align `IS` and the descriptions across the block:

```sql
COMMENT ON COLUMN public.business_units.business_unit_id   IS 'Primary key supplied by the authoritative Business Unit catalogue';
COMMENT ON COLUMN public.business_units.business_unit_type IS 'Area or Accounting Division';
```

Preserve authoritative comment wording exactly. Readability edits must not
change definitions or quoted text. Apply these conventions to new or safely
editable SQL; never rewrite an already-applied Flyway migration solely for
formatting. The [immutability rules](#immutability-and-forward-fixes) still apply.

Put each `INSERT` column and its corresponding `VALUES` expression on its own
line, in matching order:

```sql
INSERT INTO public.example_table (
    example_id,
    example_text
) VALUES (
    pi_example_id,
    pi_example_text
)
RETURNING example_id INTO po_example_id;
```

Preserve column/value order, literals, casts, mappings and `RETURNING` behaviour.
This convention applies to new or otherwise authorised SQL changes; formatting
alone never justifies rewriting committed migration history.

### Functions and stored procedures

Use the following conventions in new or safely editable routine SQL. Apply
them to both functions and procedures; do not reformat applied migrations.

- Use descriptive names so the code explains ordinary assignments and
  calculations. Follow established naming conventions and choose constant
  names that describe their purpose.
- Write PostgreSQL built-in function names in uppercase, for example
  `NOW()`, `TO_CHAR()`, `MAX()`, `MIN()`, `SUBSTRING()`, `LPAD()` and `CHR()`.
  Preserve the declared spelling of application-defined routines and quoted
  identifiers.
- Declare sequence bounds as named `CONSTANT` values and use those names in
  queries, comparisons and sequence resets. Prefer the same approach for
  other fixed business limits. Choose a type that preserves the value's
  meaning, including leading zeroes where significant; convert explicitly
  for numeric comparisons. Simple arithmetic increments need no artificial
  constants, and independent test expectations must not be derived from the
  production constants.
- Add short purpose comments before significant loops, query blocks and
  non-obvious branches or calculations. State what the block achieves first,
  then explain relevant mechanics or limits. For example, an allocation loop
  comment should describe inserting the allocation before explaining retry
  behaviour. Avoid narrating every statement or retaining commented-out
  debugging code.
- Put one blank line before a purpose comment when it follows executable
  statements. Keep consecutive comment lines together and keep the comment
  attached to the code it describes. No extra blank line is needed immediately
  after an indented block opening such as `BEGIN`, `ELSE` or `THEN`.
- Separate an `IF` block from preceding statements and from subsequent work
  with one blank line. If the block has a purpose comment, place the blank
  line before that comment rather than between the comment and the `IF`.
- Keep consecutive outer `END IF;` statements together. A single blank line
  after an inner block's `END IF;` can distinguish that completed sub-block
  from the remaining outer closures; do not space out every closing statement.
- Put one blank line between declarations and the routine's main `BEGIN`,
  before an `EXCEPTION` handler, and after `GET STACKED DIAGNOSTICS` before
  composing or processing the captured error details.
- Preserve the [routine header template](#stored-procedure-and-function-template)
  and its section spacing. These body-comment conventions supplement the
  required headers and [pgTAP scenario introductions](TESTING.md#pgtap-scenario-introductions).

### Exception messages and defaults

- New Maintenance stored procedures include the explicit outer
  `EXCEPTION WHEN OTHERS THEN RAISE;` block shown in the
  [body example](#stored-procedure-and-function-template). Preserve and rethrow
  existing failures unless a documented routine contract requires a deliberate
  translation. The standard block emits no additional routine-level log and
  does not reconstruct errors or maintain diagnostic-field allowlists.
- A bare `RAISE;` preserves the original SQLSTATE, message and diagnostic fields.
  Including a caught SQLSTATE only in replacement message text does not preserve
  its code: a new `RAISE EXCEPTION` defaults to `P0001`. For an agreed translation
  that retains the original code, set `ERRCODE` explicitly and preserve the
  diagnostic fields required by that contract. Use `GET STACKED DIAGNOSTICS`
  only for a justified additional operation.
- Unchanged rethrow does not sanitise PostgreSQL messages, details, hints or
  context. Replacing a sanitising wrapper with the common block changes the
  diagnostic exposure contract even when the SQLSTATE is unchanged. Record that
  change and verify caller response/log handling separately; do not claim that
  raw diagnostics have been stripped. Native database/server logging and errors
  during pre-entry parameter binding remain separate concerns.
- Backend services own safe contextual logging, transaction boundaries and
  run-status outcomes. Where context is needed, use only an agreed fixed routine
  name, operation label and SQLSTATE; never interpolate payloads, author values,
  free text, `SQLERRM`, details or hints into new contextual logs. Required caller
  response and logging coverage must be evidenced rather than assumed.
- `WHEN OTHERS` excludes cancellation and assertion failures, which propagate
  naturally. Do not replace them with a generic business error. A caught failure
  rolls back database writes within the exception block; this does not transfer
  ownership of the caller's transaction to the procedure. Sequence consumption
  can still leave gaps.
- Build deliberately new business-error messages with `FORMAT()`, using the
  routine name and failed operation plus only contractually required safe
  identifiers. Never turn a failure into a successful return. For a new business
  exception using the default `P0001`, omit `ERRCODE`; specify a condition or code
  when its documented contract requires another SQLSTATE. Keep tests explicit
  about the expected code and distinguish these errors from unchanged rethrows.
- Omit routine declaration clauses that only restate PostgreSQL defaults,
  including `VOLATILE`, `CALLED ON NULL INPUT` and `SECURITY INVOKER`, when
  omission preserves the approved effective behaviour. Preserve required
  non-default settings and verify the effective properties when replacing an
  existing routine.

The following terminal allocation-collision example is a deliberate,
contract-specific `P0001` exhaustion error after retrying a native collision.
It preserves the caught constraint and puts the underlying failure in its
message; it does not preserve the collision SQLSTATE as the returned error code
and is not a template for the common insertion-procedure handler:

```sql
GET STACKED DIAGNOSTICS v_constraint = CONSTRAINT_NAME;

v_error_message := FORMAT(
    'f_get_account_number: allocation failed after five attempts; Account number = %s, BU = %s; %s: %s',
    v_number, pi_business_unit_id, SQLSTATE, SQLERRM);

RAISE EXCEPTION USING
    MESSAGE = v_error_message,
    CONSTRAINT = v_constraint;
```

This excerpt belongs inside the final-attempt exception handler; it does not
replace the retry loop. See PostgreSQL's
[exception diagnostics](https://www.postgresql.org/docs/17/plpgsql-control-structures.html#PLPGSQL-EXCEPTION-DIAGNOSTICS)
and [error-reporting syntax and defaults](https://www.postgresql.org/docs/17/plpgsql-errors-and-messages.html).

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

The fresh and disposable path is the
[DB-01 contract below](#db-01-fresh-database-contract); Testing owns its
suite entry point and availability status. The direct Flyway tasks above
operate against a configured target and do not create or clean up a disposable
database. Do not substitute persistent Compose, backend tests, or a configured
database target for this workflow.

> **Destructive:** `docker compose down --volumes` deletes the developer-owned
> named volume and its local database data. It is not part of routine migration
> validation.

### DB-01 fresh-database contract

DB-01 defines the migration-safety and database-outcome contract for the
database-owned `dbUnitTest` task. Its suite ownership, lifecycle integration,
reporting, and availability are documented in
[Testing](TESTING.md#db-01-suite-semantics).

The task exercises both fixed profiles documented in
[DB-10 execution](TESTING.md#db-10-pgtap-execution): `non-live-dev` selects
`ddl`, `data/allEnvs`, `data/nle`, `data/dev`; `non-live` selects the first three.
Both run all discovered fresh owning suites. The common NLE profile does not
establish future staging-specific migration or production deployment coverage.
Resolve the actual application Flyway core and PostgreSQL runtime module
versions, require equal numerical release versions and use the matching Flyway
image. Every native JSON response must report that same version.

The fresh-database workflow must:

1. Start a disposable PostgreSQL 17 container and create a test-owned
   logical database with test-owned connection details.
2. Confirm the logical database has the expected empty start state and no
   Flyway history or application-owned objects.
3. Configure Flyway with an explicit list of repository
   migration locations. Do not inherit application or environment location
   defaults. Each required location must exist.
4. Configure baseline behaviour explicitly. Automatic baselining is disabled
   for the empty-start scenario so every selected migration is applied.
5. Migrate and assert the expected applied migration count and versions, final
   Flyway state, and required schema, object, and reference-data outcomes.
6. Run Flyway validation, then migrate a second time and assert that no
   migration is applied on the second run.
7. Destroy the owned logical database/container and its owned anonymous volumes
   automatically. Independently attempt container and every known volume absence
   check even after removal or another absence check fails.

Fail closed before migration if an external JDBC URL, credential, or target
override is present, the resolved target is not test-owned and disposable, a
required migration location is missing, or the starting state is invalid. Also
fail on a migration, validation, runtime-version, or assertion error and when
cleanup cannot be confirmed. After global preflight and image preparation,
attempt both profiles even if the first fails, retain each profile's report and
fail their aggregate result. Preserve primary and cleanup diagnostics together.
Never fall back to a developer-owned or shared database.

Return only non-sensitive results to the evidence report defined in Testing.
Do not expose production data, PII, secrets, credentials, or reusable
connection details.

Representative predecessor-based upgrades remain owned by the
[DB-03 guidance below](#planned-db-03-upgrade-path-validation). The
[DB-04 contract below](#db-04-migration-specific-boundary-contract)
owns migration-specific boundary assertions; DB-01 requires their relevant
outcomes without redefining that contract here.

<a id="planned-db-03-upgrade-path-validation"></a>

### DB-03 upgrade-path validation

DB-03 extends the DB-01 database-owned `dbUnitTest` framework. It
does not create a second framework and must not use Spring or backend
integration-test fixtures. The maintained declaration, dispatch, adoption and
report contract is documented in
[Testing](TESTING.md#maintained-predecessor-upgrade-contract). Normal
`./gradlew dbUnitTest` runs every fresh suite and affected registered upgrades
in each fixed profile; `check` and `build` inherit that coverage. Explicit full
replay and conservative full fallback select all registered candidates eligible
for each profile. Globally valid candidates outside a profile's locations are
Not selected — outside selected profile locations, not verified by that profile.
The complete fresh suite set still runs in both profiles. Shared database-test
infrastructure changes require full historical replay and automatically run the
native framework regression matrix; uncertain comparison evidence also requires
that matrix. Framework delivery
alone does not prove a consumer: record its actual registration, predecessor,
candidate, owning-suite assertions and retained passing execution evidence.

Before creating targets, validate the complete-tree numerical inventory,
registrations, adoption checksums and immutable history. Validate the fixed
32-migration adoption foundation globally, including adopted files excluded from
one profile. Every later migration in the union of supported locations needs
one owning registration; do not enlarge the adoption list to exempt it.
Registration/dependency validation is global, while execution eligibility is
profile-specific. Working migration bytes must match their committed HEAD
versions; a trustworthy comparison also checks existing migration paths and bytes
across both revisions. Reject modification,
removal, rename, duplicate versions and a new selected version inserted below
existing history. Missing or uncertain comparison context falls back to full
registered replay, but cannot excuse a history-policy error. Added migrations
outside the exercised locations are reported as Unverified; validate their
applicable disposable configuration separately before claiming coverage.

Resolve the actual candidate and its immediate predecessor separately from each
profile's selected Flyway migration locations at the implementation baseline.
The predecessor is the greatest selected version below the candidate, using
Flyway's numerical version ordering across those locations. Do not infer it from lexical filename
order, the preceding DDL file, or the candidate number minus one. A candidate
can therefore have different predecessors in the two profiles. Normal comparison
refs select affected registrations. The additional
[actual-parent task](TESTING.md#actual-comparison-parent-batch-verification)
retains each profile's independently derived comparison inventory and applies
its complete incoming batch on the same target:
`./gradlew dbUnitTestParentTransitionTest --no-daemon -PdbUnitTestComparisonRef=<exact-full-SHA>`.
The comparison must equal tested HEAD or its sole immediate parent; this task
has no comparison/base fallback. HEAD equal to comparison may itself be a merge;
a different candidate HEAD must have exactly that one parent. Working overlays
are labelled as working-candidate evidence. Verify the clean committed child
separately to claim a committed parent transition.

The parent task keeps global adoption, registration and immutable-history
validation, both fixed profiles and the resolved native runtime contract. Equal
inventories and empty deltas still execute complete history, native validation,
exact row/catalogue/ACL/routine/enum/sequence preservation, final application
owners and zero-applied repeat/history checks. Only the three fixed framework
self-suites requiring absent observations are excluded from retained owners;
all 42 fresh suites remain required. Only explicitly bounded routine,
Aliases-name and Order-Term-response changes are allowed. Unsupported incoming
data or structural changes fail closed; `observe` grants no batch exemption.
Historical seeds are not incoming additions. No business preparation or
synthetic-data approval is borrowed from registered replay. Shared committed
observation cleanup, distinct-backend absence, an independent no-other-client-
sessions probe on the test-owned target and independent owned container/volume
absence remain mandatory after every outcome. Retain separate
`parent-transition` profile/aggregate and `parent-framework` reports without
replacing fresh/full registered evidence.

For a candidate migration with an immediate predecessor, use this
Flyway-native sequence:

1. Start a disposable PostgreSQL 17 instance, retaining DB-01's empty-start,
   explicit-location, external-target refusal, and connection-safety rules.
2. Migrate and validate only through the actual predecessor, allowing existing
   migrations to establish the prior schema and normal reference data. Assert
   the exact successful selected history prefix, with no candidate or later
   migration applied.
3. Add no further business rows when the candidate does not depend on existing
   data. If it does, require an approved data-scenario contract that defines the
   pre-change conditions, business and edge cases, and expected outcomes. The
   process and owner for producing and approving that contract remain to be
   decided. Translate only its approved cases into the smallest deterministic
   synthetic dataset.
4. Capture the relevant scoped predecessor rows and objects through shared
   SQL support using the owning suite's mandatory compact declaration. Keep test
   observation state outside application objects and preserve it across
   connections. Bounded data observations may separately capture declared rows
   and sequences for precise custom outcomes without weakening exact preservation.
   Approved synthetic preparation or risk-specific transitions may use explicitly
   declared custom SQL cases; ordinary routine creation does not need bespoke phases.
5. Apply only the candidate as the next migration and validate at that same
   candidate boundary. No later migration may run before candidate assertions.
6. Compare the exact-preservation rows and objects first. Run any custom outcome
   verifier, then the ordinary owning assertion group, both with positive exact
   TAP plans and rollback. Assert the relevant schema, reference-data and
   affected-row outcomes and applicable database contract. Capture the complete
   candidate Flyway history for the repeat comparison.
7. Migrate and validate again at the same candidate boundary. Require native
   evidence of zero newly applied migrations and complete Flyway history
   equality with the captured candidate history; counts or script names alone
   do not prove this. History equality does not replace row/object preservation
   assertions.
8. Remove and independently verify removal of test-owned observation state, then
   destroy the disposable database/container and owned anonymous volumes.
   Independently attempt every target/volume absence check even if an earlier
   cleanup command fails; retain each failure alongside any primary error.

The maintained DB-03 phases use separate SQL connections, so predecessor
observations have an ordinary, committed lifetime inside the disposable target.
TEMP objects and rolled-back observations cannot carry evidence between those
connections. Follow the [compact contract and shared dispatch](TESTING.md#compact-contract-and-shared-dispatch)
and [SQL ownership contract](TESTING.md#pgtap-suite-layout). The fixed
`support/manifest.json` controls explicitly loaded helpers and fingerprints;
helpers are never discovered as standalone suites. Shared SQL owns declared-scope
capture and comparison, phase plans and transactions, guarded observation
identity, committed storage, and independently checked cleanup. Row/text snapshot
strings remain exact. Every new upgrade contract, including a new registration
in an existing suite, requires compact declaration and shared dispatch. The flat
owning suite retains functional assertions, independent expectations, fixtures
and real-session concurrency. Do not copy phase validation, observation tables,
commits or cleanup into owners of new upgrade contracts.

A data contract may declare optional `observe` with exactly `rows` and `sequences`
arrays of canonical qualified identities. Both keys are mandatory, at least one
array is nonempty, duplicates are rejected, and identities cannot overlap their
corresponding exact-preservation arrays. The same relation may have observed rows
and preserved table metadata. Other contract types cannot declare observations.
Shared preparation stores `observed` separately from the unchanged preservation
`snapshot`; the custom verifier explicitly checks intended data/sequence outcomes.
Observation never relaxes exact row or catalogue preservation. Compare retained
row strings with their original text and multiplicity; parse copies only when
classification is required. Data contracts still require a verifier and forbid
declared object creations/replacements.

Optional `upgradeCases/` scripts are invoked only by an explicit contract for
approved preparation or a risk-specific transition; they do not become another
routine suite or reimplement shared observation machinery. Custom preparation
keeps its canonical path and approved-synthetic requirements. Only custom verify
may instead use the reserved `owner` token, resolving to the declaring regular,
canonical SQL file beneath `src/dbUnitTest`, never another owner or executable
metadata. Missing files and symlinks fail validation. The token is not a dependency
path; the owner is already an implicit input. Ordinary custom paths remain
classified and fingerprinted, and additional dependencies belong in `inputs`.

The custom owner verifier loads the shared payload under exact contract/scenario/
candidate/predecessor identity, checks the bounded observed outcomes with
`opal_phase=verify`, and rolls back. Ordinary compatible owning assertions then
run with `opal_phase=fresh` and rollback. Both follow shared exact-preservation
verification; shared support alone owns committed capture and cleanup. Assertion
groups must be compatible with the candidate schema, including focused historical
expectations when a later migration changes behaviour or dependencies. Genuine
earlier four-field registrations retain their legacy phase API during separately
reviewed adaptation; keep their coverage until that adaptation is verified. This
compatibility does not exempt newly registered contracts in an existing suite.
Framework support alone does not establish consumer adoption.

Exact ownership checks precede loading/removal; removal is committed and absence
is checked from a distinct backend. Only narrowly owned
test observation preparation, history snapshots
and their cleanup commit under the [pgTAP transaction contract](TESTING.md#db-10-pgtap-execution).
Fresh and functional verification retain rollback, and production routines retain
backend-owned transaction boundaries. Every phase requires a positive exact TAP
plan; target destruction remains mandatory after success or failure.

Retain non-sensitive evidence per profile of actual candidate/predecessor paths
and versions, selected locations, resolved runtime/image, phase results and
assertion counts, validation, native repeat results, history equality, scoped
preservation, any bounded observation/custom outcomes, and confirmed shared
state, target and owned-volume cleanup. Keep unique per-profile run reports and the aggregate profile outcome described in
[Testing](TESTING.md#maintained-predecessor-upgrade-contract). Migration,
validation, SQL, assertion, or cleanup failure must fail the maintained command.
Preserve primary and cleanup failures and identify unexecuted phases when a failure stops the workflow; an incomplete run cannot
establish upgrade verification.

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

### DB-04 migration-specific boundary contract

Every migration must declare the database contract it affects and the direct
PostgreSQL assertions needed to prove that contract. The declaration belongs
with the migration-focused test or specification described in
[Testing](TESTING.md#db-04-pgtap-test-placement).

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

Use the current
[DB-10 pgTAP execution contract](TESTING.md#db-10-pgtap-execution) for reusable
assertion mechanics and patterns, command-failing output, and the common
evidence format. DB-04 defines the required migration-specific contract and
outcomes without duplicating those mechanics.
Follow the [pgTAP suite layout](TESTING.md#pgtap-suite-layout): one flat owning
SQL suite per function or procedure, with new suites directly under
`src/dbUnitTest`. A migration normally adds its production SQL, ordinary
assertions and a compact declaration linking its changed objects, preservation
scope and compatible assertion group. Shared `support/` SQL owns lifecycle and
preservation through the fixed manifest; optional `upgradeCases/` SQL covers
explicit risk-specific transitions. Fixed regressions remain under `framework/`.
These paths are explicitly loaded rather than discovered as fresh suites.
Do not create a directory or duplicate phase plumbing for every migration, or
introduce a separate shell/Python database test runner. Preserve existing
functional, fixture and concurrency ownership when adapting a consumer.

### Planned DB-06 stored-procedure responsibility contract

DB-06 owns the responsibility boundary for stored procedures introduced or
changed by migrations. A stored procedure performs its declared database work
and propagates a PostgreSQL exception when that work cannot complete, whether
native or deliberately raised under the error contract below. It must not
commit, roll back, or otherwise own a transaction boundary, and it must not
create or update run-status records. The calling backend service owns the
transaction boundary and the run-status lifecycle; this guide does not
prescribe the backend implementation mechanics. Record any required backend or
status-persistence change as separate work outside this database workstream.

New Maintenance procedures include the
[common explicit exception block](#exception-messages-and-defaults). Existing
procedures adopt it when their contract is amended through the appropriate
forward migration; do not retrofit immutable history. The handler propagates
failure and retains original error codes without taking ownership of backend
transaction or publication outcomes.

Keep a lightweight record-at-a-time insertion helper focused on its declared
mapping, allocation, integrity, insertion, and output contract. Collection
iteration, optional-element selection, and publication-wide orchestration or
completeness checks belong to an identified caller or a separately scoped
orchestration routine. Document that boundary before adding those
responsibilities to a helper. A database orchestration routine still does not
own the backend transaction or run-status lifecycle.

The contract for each introduced or changed procedure must document:

- Inputs and input validation, including the ownership evidence below.
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
and DB-10 owns reusable assertion mechanics and evidence formatting.

Collect evidence proportionate to the change:

- Apply the selected locations to a fresh PostgreSQL database.
- Upgrade a representative existing schema when prior data or objects affect the change.
- Run `flywayValidate` against the intended target configuration.
- Execute the applicable DB-04 direct PostgreSQL assertion declaration,
  including error and empty outcomes where relevant.
- Record exact commands, target type, selected locations, results, and reasons for skipped checks.
- Never claim a shared environment or deployment was validated unless it actually was.

#### Validation ownership and integrity

For each proposed validation rule, record its authoritative requirement source
and revision or confirmed decision, its enforcement owner, and verification
evidence that the owner enforces it at the required point in the workflow.
Distinguish implemented coverage from intended or pending coverage. A rule in
design collateral establishes a requirement; its presence alone does not assign
that rule to the procedure.

Detailed request formatting, completeness, JSON-shape, and whitespace checks
may belong to backend or UI validation, or deliberately form part of the
procedure's contract. Agree that boundary using the actual supported callers.
Do not remove required checks on unverified claims of UI/backend coverage or on
Fines precedent: another service's routine and business rules do not establish
this service's enforcement. Record unresolved ownership or coverage as a gap
and do not claim that the affected contract is complete.

Selector-driven mapping integrity remains database-owned when unused or
conflicting members would otherwise be discarded. Distinguish omission from
a supplied JSON null, empty object or other value, and reject unused groups
before allocation. Detailed selected-group completeness, formatting and field
validation remain upstream-owned; this guard does not establish backend coverage.

For Notes, the agreed split assigns required/non-null input values, JSON shape
and types, blank/whitespace rules, and applicable input lengths to the backend,
with UI checks where appropriate. Retain the respondent-account existence check
in the procedure because the polymorphic Notes association has no foreign key
enforcing it. Keep standard-note assignment, author mapping, timestamp semantics
and one-row insertion in the helper; account comments and optional-note selection
remain caller concerns.

This split is a delivery requirement, not evidence that backend validation has
already been implemented. Identify the actual endpoint/service, the path from
request through the persisted casefile to the helper, and its tests for every
supported caller. Record missing coverage as a separately owned dependency and
the changed validation/error classification contract. UI validation alone cannot
close that dependency. Do not claim end-to-end completion while required
validation or propagated-error response/log coverage remains unverified.

Use existing PostgreSQL type, nullability, primary-key, unique, foreign-key, and
check constraints for integrity they already enforce. Justify any duplicate
existence precheck against the required semantics and error contract. Retain
protection that those constraints do not provide, including:

- Required Party classification and valid pairings of references; separate
  foreign keys do not prove these relationships.
- Supplied-code resolution: a supplied but unresolved code must not silently
  become a nullable identifier merely because the resulting foreign key accepts
  null.
- Polymorphic target integrity, such as a Notes target without a foreign key;
  retain target validation unless an evidenced alternative is agreed.
- Declared row scope, cardinality, allocation, and output guarantees. Do not
  silently discard conflicting or unused supplied data during mapping.

Justify each explicit lock using the caller's actual transaction lifetime,
isolation assumptions, and a supported concurrent deletion, key-change, or
other competing operation. State the interval and outcome it protects and map
that scenario to verification evidence or an explicit framework gap under
[Routine suites and framework gaps](TESTING.md#routine-suites-and-framework-gaps).
A lookup or insertion-window lock does not establish permanent referential
integrity. Apply this validation and locking guidance to functions where
applicable.

#### Native errors and deliberate exceptions

Native PostgreSQL constraint, type, or conversion failures may satisfy the
expected error contract without an additional precheck or replacement error;
the common outer procedure handler rethrows those failures unchanged. For every
deliberate precheck, newly raised exception, or SQLSTATE translation, explain what
required semantic protection, diagnostic, or compatible caller behaviour it
adds beyond existing constraints and native propagation. Consider concurrent
changes when assessing a precheck; it does not replace the constraint.

Record the failure condition, evidenced SQLSTATE and relevant diagnostic
context, including constraint identity where callers rely on it. Preserve
compatible errors and useful diagnostics; do not swallow failures or turn them
into successful results. The mandatory common handler does not require
duplicating table constraints or translating each native failure. Do not
invent a universal error-code scheme. An intentional incompatible error change
needs an explicit contract and delivery sequence, together with direct
PostgreSQL evidence for the
affected outcomes.

## Routine LLD documentation

When the ticket requires a function or procedure LLD, document the delivered
contract from implementation and verified evidence. These requirements are
self-contained; another service or agent-context checkout is not required.
Use a concise purpose-based page title and reuse the matching page under the
selected Functions or Procedures parent. Preserve unrelated content and fresh
user edits; a style preference does not justify a duplicate or relocation.

Start with References containing the delivered ticket and relevant design
collateral, then one Overview and Scope covering purpose, routines, callers,
and ownership. Distinguish design-intended callers from inspected call sites.
Keep implementation revisions, dependency delivery, validation, deployment,
and recovery evidence in the handoff. Closely related routines may share a page;
give each its own named section, placing helpers before callers and linking
existing descriptions rather than duplicating them.

For each routine, include:

| Section | Required evidence |
| --- | --- |
| Input / Output Parameters | Schema-qualified signature in parameter order, defaults, IN/OUT/INOUT modes, and effective PostgreSQL types where declared syntax differs. State accepted inputs, required/optional and null behaviour, and exact outputs or return shape. Describe a procedure's CALL/OUT/INOUT contract without inventing a function RETURNS clause. |
| Database Dependencies | Tables, sequences, types, and called routines, with direct reads/inserts/updates/deletes, affected-row scope and counts where known, and helper/caller relationships. Distinguish indirect constraint/default effects; state explicitly when a pure calculation helper affects no records. |
| Logic and Workflow | Ordered work, calculations, decisions, loops, retry bounds and restart points. A simple calculation helper may use clear logic and an implementation-derived worked example. Record diagram applicability and its reason for every routine in the handoff. |
| Error Handling | Conditions and their results or evidenced SQLSTATEs, distinguishing null results, deliberate exceptions, retries/exhaustion, and unchanged native propagation. Do not invent catches, codes, or retries. |
| Performance Considerations | Evidenced work, record access, scans, locks, and contention. Separate code-based implications from measurements; do not claim latency, index use, scalability, or guarantees without evidence. |

Document backend ownership of transaction boundaries and run-status updates
where relevant. Explain implemented exception-block rollback or retry behaviour
without presenting it as ownership of the caller's transaction. Surface
conflicting design and implementation evidence in the handoff.

Check that the documented common handler, SQLSTATE, diagnostic exposure and
validation owner match the delivered implementation. Distinguish original
error codes from codes appearing only in message text and evidenced backend
validation from a planned dependency. Record the applicable affected/full
predecessor evidence in the handoff rather than treating fresh installation as
proof of every boundary.

Use a workflow diagram when branches, loops/retries, multi-step database work,
or orchestration benefit from it. Keep labels and paths readable and show
relevant native/error exits, retry bounds, and the correct restart point.
Preserve editable logical source alongside the render where practical. For
every diagram used, render and visually inspect the actual output at its
intended reading size for clipping, overlaps, labels, and path destinations.
Separately compare decisions, branches, loops, helper calls, record operations,
returns, and failure exits against the implementation. Record both checks and
their results. If either check is unavailable, retain the draft and identify the
missing evidence; do not claim the diagram is validated or publication-ready.

When the exact LLD Acceptance Criterion requires publication, prepare a
reviewable draft and ensure authorization covers the target pages and change
scope. Reuse approval already given for that scope. Discover existing pages
before creating a missing child, and resolve ambiguous targets or material
evidence conflicts before the affected write. Read fresh page content, title,
parent, and version immediately before editing; apply only scoped changes and
use version checks where available. On conflict, reread and reconcile. After an
uncertain save or create, read back or rediscover before retrying.

Read back persisted content through an approved authenticated route. Verify
the target title/parent, covered routines, references and helper order,
signatures/effective types, outputs, record effects, errors, and preservation of
unrelated content against the reviewed draft. Verify any saved diagram's
attachment/media reference resolves to the intended image and renders legibly,
including editor media identity and collection where applicable. Record saved
URLs, versions when exposed, per-page results, and unavailable checks accurately.
A clicked Save button, API timeout, or local draft is not publication evidence. Assess
the exact ticket LLD Acceptance Criterion against verified saved-page coverage
separately from the wider Definition of Done; do not claim publication complete
while required readback or diagram checks are missing.

## Release and recovery evidence

Record target environments and selected locations, deployment order, and compatibility with the current and incoming application versions. Include expected affected rows, duration, locking, downtime, and post-migration checks.

Distinguish rolling back application code from recovering database state. After an applied migration, use a forward-fix migration unless an approved restore or recovery plan is required for possible data loss.

## Agent and reviewer checklist

- Confirm ownership and environment scope are understood.
- Confirm the version is unique across the complete tree and has been rechecked against the target branch.
- Confirm no applied migration was modified.
- Confirm compatibility, locking, duration, data volume, and sensitive-data concerns were assessed.
- Confirm the common procedure handler, preserved SQLSTATE, diagnostic exposure
  and validation ownership agree with the implementation and caller evidence.
  A code appearing only in replacement message text is not preserved SQLSTATE.
- Confirm fresh-database and upgrade-path validation were considered.
- Confirm required affected/full predecessor evidence records the actual
  selected boundaries; disclose pending backend validation and response/log
  dependencies without claiming those checks have moved successfully.
- Confirm each changed database contract maps to a created or updated
  `*_pgtap_tests.sql` suite, an identified unchanged suite with sufficient
  coverage, or a justified DB-04 no-assertion exception.
- Confirm `./gradlew dbUnitTest` passes and its non-sensitive evidence is
  recorded for every applicable pgTAP change.
- Confirm exact evidence, skipped checks, and recovery implications were recorded.
