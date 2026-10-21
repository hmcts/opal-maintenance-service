# Major Creditor DEV seed boundary contract

## Current non-live scope and verification boundary

The requester expanded the synthetic T901/T902/T903 seed to every non-live
environment on 21 October 2026, following the Fines common-NLE pattern.
`data/nle/V1_34__insert_major_creditors_nle_data.sql` now supplies the same
BU 44 records where the common NLE location is selected. The saved PO-10297
ticket draft's original test-owned-data wording was superseded by the approved
seeded-data, read-only functional approach; the expanded environment scope is
an additional amendment to record in the PR. Neither amendment is a claim that
Jira or a shared deployment has been updated. The DEV V1_33 migration and the
historical evidence below remain intact.

The normal `dbUnitTest` run now uses two fresh disposable PostgreSQL 17
profiles: `non-live-dev` selects `ddl`, `allEnvs`, `nle`, `dev`, while
`non-live` selects `ddl`, `allEnvs`, `nle` without DEV. Both discover the
existing DEV boundary suite and the owning flat NLE pgTAP suite. The latter
checks the empty-key insert, exact-set no-op, and partial/conflicting-set
failure with atomicity and ID preservation. Fresh-profile success does not
verify predecessor upgrade history, deployment or live HTTP behavior.

For rollout, inspect the effective locations, deployed image and Flyway
history by script name, including earlier V1_15, V1_17 and V1_31 seed names
and V1_33. Apply V1_34 through normal Flyway deployment only after confirming
the target's compatible history. An incompatible history requires a separate
approved database-owner recovery decision, never automatic repair. Refresh
affected BU 44 Major Creditor cache entries through the approved administration
route using the actual cache prefix, then rerun live PO-10297 scenarios on an
agreed non-live target. See `docs/TESTING.md` for environment settings and cache
keys. Production excludes `data/nle`.

PO-10297 adds `data/dev/V1_33__insert_major_creditors_dev_data.sql` after
predecessor V1_32. This synthetic data belongs only to environments that
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

Assertions apply to both fresh DB-01 and V1_32-to-V1_33 DB-03 upgrades. Run
`./gradlew dbUnitTest` for the supported disposable fresh PostgreSQL 17 path.
The maintained DB-03 predecessor phase is not yet available in this branch;
upgrade verification remains unmet until its supported framework is delivered.
Do not replace it with an ad hoc Python or shell database runner. Tests never
modify a developer-owned database.

Flyway applies V1_33 once and its normal second migrate is a no-op. A direct
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

## Current V1_33 allocation and deployment history

On 20 October 2026 the full migration tree and current master
`2aae8cb091670fde1a0e569eb460381c2e02212b` were checked. Master now owns
V1_31 for `f_get_check_letter` and V1_32 for `f_get_account_number`.
The unapplied PO-10297 DEV seed is therefore allocated V1_33, immediately
after V1_32. The existing function migrations are preserved byte for byte.
The seed's executable SQL, three-row contract and nine assertions are unchanged.

The requester confirmed on 20 October 2026 that the V1_31 DEV seed has only
run in disposable databases and has not been deployed to a shared database.
This is requester-provided deployment-history evidence, not an agent query.
The correction belongs to PO-10297 and is inherited by PO-10298 and PO-10301.

Before rollout to another target, inspect Flyway history by script name for
all earlier seed filenames (V1_15, V1_17 and V1_31). A version number alone
may now identify unrelated DDL. If an earlier seed was applied there, stop
and agree a database-owner recovery plan; do not rename applied history,
repair it, reinsert duplicate creditors or delete records to force a pass.

## Current verification and required framework dependency

Run `bash bin/ci/flyway-dupe-checker.sh --mode=check-only` and
`./gradlew build` on the resolved tree. The fresh `dbUnitTest` gate checks
all 33 selected migrations and the existing direct PostgreSQL contracts.
The verifier uses Flyway 13.10.0 to match the application and Gradle plugin.
Exact execution results are recorded in the current implementation handoff.

The V1_32-to-V1_33 predecessor path is applicable and remains unmet in the
current fresh-only framework. The independently reviewable framework package
is [PO-10643 framework PR #271](https://github.com/hmcts/opal-maintenance-service/pull/271).
Delivery role: database test-framework maintainer; assignment and integration
into this branch are not confirmed. The current task accepts no predecessor
target. PR #271 proposes the `OPAL-DB-UPGRADE` registration and
`dbUnitTestComparisonRef`/`dbUnitTestUpgradeMode` selection interface; it must
be integrated and reviewed here before this consumer can use it. The inspected
framework head is `ed3c9dc913855cea362e72ceb7acc0ea97ec2ada`.

Required consumer integration, after that package is available: use its
reviewed predecessor declaration to migrate an owned disposable database
through V1_32, establish the normal seeded prerequisites and absent T901/T902/T903
keys, apply V1_33, then execute this suite's nine assertions through `dbUnitTest`.
Record preservation of predecessor history and existing creditors, Flyway
validation, a no-op rerun, command-failing assertion behavior and owned cleanup.
The database framework package must land before this verification can be
claimed complete. The seed's fresh verification and stack reconciliation can
proceed independently, but full DB-03 readiness remains blocked on that package
and its executed consumer evidence.

## Historical V1_31 allocation and verification (12 October 2026)

The unmerged PO-10297 seed is allocated V1_31 after checking the complete
migration tree, current master (`187618e`) and the stacked PR base
(`e8e6107`) on 12 October 2026. The base allocates versions through V1_30,
including `ddl/V1_17__create_associated_record_type_enum.sql`; the seed's
previous V1_17 allocation collides with that DDL. All base migrations remain
unchanged. Recheck the complete tree and current PR base before merge if
either advances.

On 12 October 2026 the requester confirmed that neither earlier PR seed,
`V1_15__insert_major_creditors_dev_data.sql` nor
`V1_17__insert_major_creditors_dev_data.sql`, has been applied in shared DEV.
This is requester-provided deployment-history evidence; the agent did not
query the shared database. The filename and MODULE header change only;
the seed's executable SQL and three-row contract are unchanged.

Before rollout to any other target, inspect Flyway history by script name
for both earlier seed filenames; version 1.17 alone may identify the new DDL.
Renumbering is suitable only where neither earlier seed has been applied. If
either seed is recorded as applied, stop rollout and agree an environment-specific
recovery plan with the database owner; do not rename an applied migration,
repair or manually edit history, rerun the seed, or delete existing creditors
to accommodate the new version. Local disposable validation does not establish
shared DEV deployment history.

## Verification of V1_31 allocation

On 12 October 2026, `bash bin/ci/flyway-dupe-checker.sh --mode=check-only`
passed against the full migration tree. The `dbUnitTest` task in
`./gradlew --offline --no-daemon dbUnitTest build` passed on PostgreSQL 17.11
and Flyway 13.5.0: 31 migrations, 26 suites and 1,356 assertions, successful
validation, a no-op second migrate and confirmed cleanup (15.66 seconds).
A separate disposable V1_30-to-V1_31 Flyway upgrade passed all nine seed
assertions, preserved existing creditor rows and predecessor history, validated,
confirmed a no-op second migrate and cleaned up (12.01 seconds).

The full build remains unverified: online attempts failed resolving Gradle
plugin/Cucumber dependencies; offline execution stopped at `compileOpenapiJava`
because required artifacts were not cached. Restore dependency resolution and
rerun `./gradlew build` before claiming Agent Complete. Live functional tests,
shared DEV startup, CI and SQL/QA peer review were not verified by this run.
