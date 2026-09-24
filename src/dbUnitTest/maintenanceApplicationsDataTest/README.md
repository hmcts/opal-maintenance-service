# Maintenance Applications reference-data contract — PO-10293

The authoritative delivery input is
rm/common/reference-data/maintenance-applications.csv in opal-rm-agent-context
at revision 2c0a847d265495df63bc1e3ba3ac4d88478437d3.
Its last content change is 899d2e287839c0d12a3f3302e1568360fe769481.
SHA-256: f197658f2394fbe07c9c372e01b217f33f04465f5a3c6326588da9c6541ab2fd.

The adjacent CSV is retained byte-for-byte and is independent of migration SQL.
There are 35 unique application codes. All supplied scalar, text and JSON values
are preserved. Blank application_id values are omitted from the INSERT and use
application_id_seq; blank date_used_to values become SQL NULL.
All records are active, in Create Casefile, effective from 2026-08-26.
Codes remain text, including their zeros; JSON is compared as text without normalization.
No country, creditor or court identifier mapping is performed.

The seed is V1_12__insert_maintenance_applications_reference_data.sql in data/allEnvs,
after the PO-10285 table migration V1_11. The prerequisite schema uses public.
This all-environment reference data does not depend on dev fixtures.
The deployment SQL embeds approved values and does not read CSV at runtime.

Any pre-existing source application_code rejects the whole insert, even if identical.
Unrelated rows and their IDs are preserved. Direct SQL replay therefore fails;
a second Flyway migrate is a no-op because the version is already recorded.
Flyway owns the transaction. Failed row changes roll back, but sequence values
can be consumed and skipped. Do not reset a production sequence to close gaps.
A collision or exhausted sequence fails rather than automatically repairing state.
Deploy serially without concurrent writes to this dataset.

Run ./gradlew --no-daemon dbUnitTest with Java 21 and Docker available.
The discoverable suite is maintenance_applications_data_pgtap_tests.sql.
This follows the current repository naming convention instead of the ticket's
older maintenance_applications_data_unit_tests.sql filename.
The schema suite remains maintenanceApplicationsTest/maintenance_applications_pgtap_tests.sql.

Data tests reconcile all ten supplied columns, test generated IDs independently,
preserve unrelated row snapshots and execute the actual migration for failure checks.
They cover identical and differing overlaps, direct replay, late-row rejection,
primary-key collision and sequence exhaustion, using rolled-back test fixtures.
The schema suite keeps its existing physical/boundary contract with fixture-scoped assertions.

The standard Gradle runner covers fresh ddl/allEnvs/dev migration, Flyway validation,
repeat migration and pgTAP. It does not orchestrate a predecessor upgrade.
Separate recorded disposable validation is required for ddl/allEnvs without dev,
the actual immediate predecessor, unrelated-row preservation, candidate-failure rollback,
history state, and complete row/sequence snapshots around a second migrate.
Detailed commands, measured results and cleanup evidence belong in the delivery record;
this README alone is not evidence that validation passed.

Expected production impact is 35 inserted rows with normal INSERT/index locking.
No schema rewrite, API change or downtime is planned. Measure migration duration.
Monitor migration success/history and independent reconciliation; active/group-wide
counts alone are insufficient because unrelated application definitions are permitted.

After a successful deployment, corrections use a new approved forward migration.
Application rollback does not remove these reference rows. Do not modify applied
migrations, truncate the table, repair Flyway history or delete conflicting production
records automatically. On a failed deployment, preserve diagnostics and investigate
the conflicting source keys or sequence condition before an authorised retry.

The Maintenance Database LLD must record seed scope, provenance, conflict/ID rules,
validation and recovery. Workbook source-lineage notes must be reconciled to this input.
Those external changes require review, publication and verified readback separately.
Long-term ownership and strategic synchronisation remain outside this tactical seed.
