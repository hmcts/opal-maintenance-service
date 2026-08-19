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

## Safe schema changes

When an application and schema cannot change atomically, prefer expand, backfill, and contract sequencing. Preserve compatibility with the currently deployed application until the rollout no longer needs it.

Before writing a migration, assess lock duration, table rewrites, index creation, constraint validation, statement duration, and the volume of affected rows. Backfill and verify existing rows before making a column non-null or adding a restrictive constraint. Use explicit constraint and index names consistent with nearby maintained migrations. Keep each migration focused and avoid unrelated schema cleanup.

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

Collect evidence proportionate to the change:

- Apply the selected locations to a fresh PostgreSQL database.
- Upgrade a representative existing schema when prior data or objects affect the change.
- Run `flywayValidate` against the intended target configuration.
- Assert affected schema objects and data outcomes, including error and empty paths where relevant.
- Test changed functions, procedures, views, constraints, indexes, reference data, and backfills at the database boundary.
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
