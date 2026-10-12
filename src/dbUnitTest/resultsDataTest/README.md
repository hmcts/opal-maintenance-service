# Results reference data

## Delivery contract

PO-10893 and PO-10894 are delivered together, in this order:

1. The immutable original `data/allEnvs/V1_13__insert_results_reference_data.sql` supplies the 22 keys.
2. `ddl/V1_15__allow_null_results_permitted_actions.sql` drops only NOT NULL from `public.results.enf_next_permitted_actions`. VARCHAR(100), stored values and other schema properties remain unchanged.
3. `data/allEnvs/V1_16__refresh_results_reference_data.sql` uses 22 plain UPDATE statements, changing only `order_term`, `result_parameters` and `enf_next_permitted_actions`.

The refresh preserves all other columns and unrelated rows. Blank permitted actions become SQL NULL. JSON text, types and array order are retained exactly; there is no trimming, reserialization, generated ID, numeric conversion of keys, inferred transformation, insert, delete or upsert. The three formerly true order terms MNSTD, MPAY and MTEMP become false; MWDN retains `[]`.

The approved deployment starts with a clean database and applies the seed and updates together. On 1 October 2026 the ticket owner explicitly removed the earlier missing-key guard and missing-key failure tests from the delivery design. The source ticket's old AC2/AC3 wording has not been republished: this is an approved deviation, not a claim that plain UPDATE raises on zero matches. Exact final-data validation still detects missing expected keys. Reassess the contract if deployment changes to standing data.

## Authority

Specs, relative to the configured RM context workspace:

- `rm/create-case-file/tickets/approved/db/db-rm-results-nullability-po-10893.md`
- `rm/create-case-file/tickets/approved/db/db-rm-results-reference-data-refresh-po-10894.md`

The accepted design revision is `d9e54b334ce89143ae93bf88420a40cd1e6c72d6` in [the context merge request](https://gitlab.clouddev.online/opal-rm/opal-rm-agent-context/-/merge_requests/130). TDIA and workbook permit NULL and the entity's NOT NULL wording was removed. The ticket owner confirmed LLD completion; no further design publication is part of this delivery.

Current independent fixture: `rm/common/reference-data/results.csv`, source revision `814003f9e65ae5416953d2a0fb07a1bef2315b5e`, SHA-256 `4e1cd867f87ebbe8476fbc51ab224add195cf2d5b71640605202d6ee8a552fce`. The retained `results.csv` is byte-identical: 22 unique keys, 20 columns and 86 parameters. It is copied from that input, never generated from the migration. Production SQL contains literals and does not read the fixture.

The original seed's input fingerprint was `72537e13e31cb59dc93f54353308e33587207180ee409e325834d3e8d8486993`. That history remains immutable; the single current fixture describes the refreshed state and must not be used as an expectation for the original seed's old values.

Execution base: Maintenance master `5a6ce62aa02c9fcbd4c1908fd93d6fce55197376`. Versions were allocated after checking the complete migration tree and live target. Check the target again before integration.

## Maintained tests

Run `./gradlew --no-daemon dbUnitTest` with Java 21 and Docker. The existing Gradle runner starts disposable PostgreSQL 17, applies `ddl`, `data/allEnvs` and `data/dev`, validates Flyway, proves repeat migration is a no-op, runs the suites and removes the container.

- `../resultsTest/results_pgtap_tests.sql`: 93 schema and behaviour assertions, including NULL insert/update, retained VARCHAR(100), 100-character acceptance and 101-character rejection.
- `results_data_pgtap_tests.sql`: 11 assertions covering independent source keys/count, 86 parameters, all 20 final fields with exact JSON text, SQL NULL, non-target/unrelated-row preservation, replay, late constraint-failure rollback, three historical seed duplicate-key cases and fixture restoration.

Tests use rollback-only transactions. The refresh failure test deliberately rejects the last UPDATE after earlier updates changed a synthetic value, and verifies complete restoration. Only test-local helpers catch exceptions; production exceptions propagate to Flyway. Historical duplicate checks invoke the unchanged original seed, not the refresh. Synthetic keys are test-owned; no environment-derived records are used.

These are the two maintained Results suites and one current CSV. Future data changes update this fixture and the applicable assertions. No permanent suite or fixture is added per refresh. Normal dbUnitTest checks the final state after all migrations; it does not prove intermediate predecessor behavior.

## Historical disposable predecessor validation

The earlier PO-10893/PO-10894 delivery record reports one-off disposable validation through predecessor 1.14,
preservation of all original values and one unrelated synthetic row at 1.15, and refreshed data with unchanged
non-target columns/rows at 1.16. Its historical acceptance criteria were 111 passing assertions (4
intermediate, 93 schema, 3 final preservation and 11 data), Flyway validation, repeat/no-op behavior, the
upgrade PASS message and confirmed cleanup. These historical results are not current verification.

Historical evidence references are `build/reports/resultsUpgrade/run.log`, the earlier delivery record and its
PR prose with the per-ticket AC mapping. Raw reports remain ignored under `build/reports/`; retain the
recorded commands/results as evidence. Recovery of an interrupted historical run must target only the uniquely
named container recorded in its log, never broad Docker cleanup.

The maintained Gradle framework currently implements only the fresh DB-01 path and has no predecessor target.
Maintained predecessor-upgrade testing remains unavailable; a standalone executable recipe does not establish
framework support. Under [Routine suites and framework
gaps](../../../docs/TESTING.md#routine-suites-and-framework-gaps), required new upgrade coverage must record
the specific scenario, tooling gap, responsible owner and agreed separately scoped framework remediation, and
remain unmet until supported execution evidence exists. The historical evidence does not satisfy a new upgrade
requirement.

## Operations and recovery

This schema and reference data apply wherever the `ddl` and `data/allEnvs` locations are selected. No environment-specific rows, privileges, defaults, indexes, comments, enums or sequences are added or changed. The ALTER acquires a table lock and can wait behind active transactions; it does not intentionally rewrite stored values. The refresh locks the 22 matching rows. Exclude concurrent operational writers during migration; disposable timings are not a production downtime guarantee.

Flyway owns each migration transaction. If 1.15 succeeds but 1.16 fails with a SQL error, the schema may remain nullable while the refresh leaves no partial changes. Diagnose the error and validate recovery in a disposable instance. Applied migrations remain immutable: corrections are forward-only. Do not add rows to conceal a final-data mismatch, or run clean/repair/manual history edits as routine recovery.

Post-migration signals: Flyway validate succeeds, no migrations remain pending, all 22 approved keys reconcile exactly, permitted actions are NULL for those keys, and unrelated rows/columns retain their values. Existing startup/health and backend regression tests remain part of the project build. Runtime consumers must be checked before rollout for nullable actions and the revised JSON types/metadata, read-only Frequency, date flags and ChildDOB identifier. This is a rollout obligation, not an implementation blocker or an established consumer defect.

Human SQL peer review, at least two reviewers, QA, CI, merge and deployment need separate evidence. The change introduces no dependencies, CVE suppressions, secrets, PII or persistent routines. For the earlier delivery, database contract assertions covered fresh and controlled predecessor paths; its raw execution reports and PR prose provide the historical per-ticket AC mapping.
