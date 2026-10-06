# Major Creditor DEV seed boundary contract

PO-10297 adds `data/dev/V1_17__insert_major_creditors_dev_data.sql` after
predecessor V1_16. This synthetic data belongs only to environments that
explicitly select `data/dev`; it is not approved for production or staging.
The requester explicitly approved these three DEV-only synthetic records on
2 October 2026. This approval covers the data contract; shared-environment
rollout and SQL/QA peer review remain separate pending delivery actions.

Existing `ddl` and `data/allEnvs` prerequisites supply BU 44 and a uniquely
named Czech Republic Country. No new Business Unit or Country is introduced.

The migration inserts exactly three BU 44 business keys with generated IDs:
T901 is an active non-Central Authority with complete synthetic casefile
selection details; T902 is an inactive non-Central Authority; T903 is an
active Central Authority. All three use the existing Czech Republic FK.
Optional comparator contact/address fields are NULL. Existing approved
Central Authority records are not updated or removed.

The suite has nine independent expected-literal assertions covering exact
three-row keys/details/flags/nulls, positive unique IDs, Country relationship,
continued approved Central Authority presence, only T901 qualifying for an
active non-Central Authority query, direct-rerun rejection, middle-key collision
atomicity, and missing/ambiguous Country rejection. Existing schema and
approved allEnvs data suites retain ownership of their contracts. Expected
values are not read from the candidate SQL. Failure cases execute the actual
migration via `pg_read_file` inside rolled-back test-only subtransactions.

Assertions apply to both fresh DB-01 and V1_16-to-V1_17 DB-03 upgrades. Run
`./gradlew dbUnitTest` for the supported disposable fresh PostgreSQL 17 path.
The DB-03 framework is not yet available; record normal Flyway predecessor
upgrade evidence separately. Tests never modify a developer-owned database.

Flyway applies V1_17 once and its normal second migrate is a no-op. A direct
SQL rerun intentionally fails on the unique business key rather than masking
collisions or overwriting data. Atomic inserts can consume sequence values on
failure; contiguous IDs are not a requirement. Missing or ambiguous Country
resolution fails before insert, and any later row collision rolls back all
candidate row inserts. Normal Flyway transaction ownership is preserved.

Rollout adds three rows without table rewrites or schema changes. Apply the DEV
migration before positive HTTP scenarios and refresh affected BU 44 reference
cache entries after deployment when caching is enabled. This is a deployment
step, never a functional-test setup/cleanup hook. No runtime test inserts or
cleanup are allowed. Recovery after an applied migration requires a forward
fix; never edit the deployed migration or delete shared rows to pass a test.

## Version allocation and deployment history

The unmerged PO-10297 seed is allocated V1_17 because the updated base owns
V1_15 for Results nullability and V1_16 for the Results reference-data refresh.
Those base migrations remain unchanged. Recheck the complete migration tree
and current PR base before merge if either advances.

Before rollout, inspect the target's Flyway history for the earlier PR seed
`V1_15__insert_major_creditors_dev_data.sql`. This renumbering is suitable only
where that earlier seed has not been applied. If it is recorded as applied,
stop rollout and agree an environment-specific recovery plan with the database
owner; do not rename an applied migration, repair or manually edit history,
rerun the seed, or delete existing creditors to accommodate the new version.
Local disposable validation does not establish shared DEV deployment history.
