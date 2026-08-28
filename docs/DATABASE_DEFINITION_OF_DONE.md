# Agent Definition of Done – Database Supplement

## Applicability

Every change must satisfy the
[Common Definition of Done](COMMON_DEFINITION_OF_DONE.md). This supplement also
applies when a change affects database concerns. A change that also affects
backend or application concerns must also satisfy the
[Backend Definition of Done](BACKEND_DEFINITION_OF_DONE.md).

Use [Database Migrations](DATABASE_MIGRATIONS.md) for detailed implementation,
connection-safety, validation, and release guidance. Checked-in executable
configuration and the migration tree remain authoritative when documentation
disagrees with them.

## Migration and data integrity

Detailed requirements are defined in [Migration locations],
[Naming and version allocation], [Immutability and forward fixes],
[Safe schema changes], [Data migration scope], [Connection configuration],
[Flyway commands], and [Release and recovery evidence].

- [ ] Every applicable implementation, connection-safety, command-safety,
  release, and recovery requirement in those sections is satisfied.
- [ ] The final schema, data, and routine behaviour matches the intended domain
  and application contracts, including types, nullability, keys, defaults, and
  routine signatures.
- [ ] SQL identifiers and database object, routine, parameter, and test names
  follow repository conventions; each migration has an accurate description
  and is traceable through the contribution record to its ticket or documented
  non-ticket maintenance context.
- [ ] Constraints and indexes support the intended integrity and access paths
  without unjustified duplication.

[Migration locations]: DATABASE_MIGRATIONS.md#migration-locations
[Naming and version allocation]: DATABASE_MIGRATIONS.md#naming-and-version-allocation
[Immutability and forward fixes]: DATABASE_MIGRATIONS.md#immutability-and-forward-fixes
[Safe schema changes]: DATABASE_MIGRATIONS.md#safe-schema-changes
[Data migration scope]: DATABASE_MIGRATIONS.md#data-migrations-and-environment-scope
[Connection configuration]: DATABASE_MIGRATIONS.md#connection-configuration
[Flyway commands]: DATABASE_MIGRATIONS.md#flyway-commands
[Release and recovery evidence]: DATABASE_MIGRATIONS.md#release-and-recovery-evidence

## Functions and stored procedures

- [ ] Each changed function or procedure has one clear, modular responsibility
  and reuses established common routines where appropriate.
- [ ] Routine parameters, return values, SQLSTATE values, and affected
  application callers remain compatible or have an explicit delivery sequence.
- [ ] Reads, writes, locks, and dynamic SQL are restricted to the intended rows
  and safely handle identifiers and untrusted values.
- [ ] Repeat invocation is idempotent or otherwise safe where the business
  contract, retry behaviour, or recovery process requires it.
- [ ] Expected failures raise explicit exceptions and preserve useful
  diagnostic context; failures are not swallowed or converted into successful
  outcomes.
- [ ] Stored procedures perform database work and raise exceptions; backend
  services own transaction boundaries and run-status updates. Procedures do
  not commit or roll back backend-owned transactions.

## Validation and SQL testing

Detailed evidence requirements are defined in
[Database validation and testing](DATABASE_MIGRATIONS.md#validation-and-testing)
and [Testing](TESTING.md#evidence-and-skipped-checks).

- [ ] Every applicable database validation and testing requirement in those
  sections passes against the final change.
- [ ] Migration and SQL validation uses a disposable PostgreSQL environment,
  never a shared environment, and the disposable environment is destroyed
  afterwards.
- [ ] Applicable SQL unit-test harnesses explain their scenarios and are stored
  under `src/dbUnitTest` or the repository's designated database-test folder
  for reference and reuse.
- [ ] SQL tests cover applicable success, empty, validation, failure, boundary,
  repeat, concurrency, and row-scope outcomes.
- [ ] SQL harness timings are enabled and captured, and a failed assertion makes
  the validation command fail; printed `Passed` or `Failed` messages alone are
  not accepted as evidence.
- [ ] Test setup and cleanup are deterministic, order-independent, and limited
  to the test-owned records.

## Release readiness

- [ ] Applicable monitoring, health, and operational verification are defined,
  including the signals and expected results.

## Documentation

- [ ] Applicable database LLDs, data models, object definitions, flow or
  interaction documentation, object comments, reference output, and ownership,
  dependency, compatibility, and recovery information reflect the final
  change.

## Review readiness

- [ ] The review covers every changed migration and SQL unit-test harness,
  including Flyway ordering, environment scope, data integrity, transaction
  ownership, locking, performance, and failure behaviour.
- [ ] Required human SQL peer review and QA review are identified as pending
  unless direct evidence confirms they are complete.

## Database handoff

- [ ] Changed database objects and scripts, migration versions and locations,
  target environments, dependencies, and deployment sequence are provided.
- [ ] Exact validation commands, PostgreSQL version and target, selected
  locations, timings, results, and reasons for skipped checks are provided.
- [ ] Expected affected rows, post-migration queries, locking, duration,
  compatibility, downtime, monitoring, and recovery implications are provided
  where applicable.
