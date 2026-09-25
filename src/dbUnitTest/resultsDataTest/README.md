# Results reference data — PO-10295

`V1_13__insert_results_reference_data.sql` loads the 22 delivery-approved Results
definitions into `public.results`. The seed belongs to `data/allEnvs`, wherever
that location is selected, and has no development-data dependency.

## Source and authority

The approved Spec is
`rm/create-case-file/tickets/approved/db/db-rm-create-results-data-change-v5.md`.
The promoted `rm/create-case-file/TDIA - RM - Create Case File.md` remains the
design authority. The supplied `rm/common/reference-data/results.csv` is the
delivery input. Paths are relative to the RM context workspace.

Verified on 25 September 2026:

| Evidence | Revision / SHA-256 |
| --- | --- |
| Context checkout | `2c0a847d265495df63bc1e3ba3ac4d88478437d3` |
| Dataset last change | `899d2e287839c0d12a3f3302e1568360fe769481` |
| Dataset SHA-256 | `72537e13e31cb59dc93f54353308e33587207180ee409e325834d3e8d8486993` |
| Spec last change | `c50874bb8273f0041621ec13d9158ef6c9867f00` |
| Spec SHA-256 | `eca8a84cfea928e57de9b2696bbaa8c9b7e036fc33c6f87a9d3b6fbc2d037c37` |
| TDIA last change | `5aef99e309cfa90f71efdc745f7b71996c79f477` |
| TDIA SHA-256 | `85890de8dcd19ff1879130cee341afeb7544a957df9e415908a8889296bf4238` |
| Approved execution base | `origin/master`, `7b4ae80a6bd3a412cb79e71bf498271b5d0624a6` |

The retained `results.csv` is byte-identical to the supplied input and is read
independently by the SQL tests. It is not generated from the migration. The
selected source files were clean at verification. The runtime migration contains
static literals and does not read this fixture or the context workspace.

PO-10293 merged in PR #223 before implementation. The user approved moving this
change's base from `codex/PO-10293` to `master`; the complete predecessor remains
Flyway 1.12. The functional prerequisite is V1_8's Results table and enum.

## Mapping and accepted decisions

All 20 CSV columns map directly, by name and header order:

| Columns | Storage and comparison |
| --- | --- |
| `result_id` | Supplied `VARCHAR(6)` business key, compared as text |
| `result_title` | Exact `VARCHAR(60)` text |
| `case_result_type` | Existing `Ancillary`, `Interim`, `Final` enum |
| `result_parameters` | PostgreSQL `JSON`; compare its text exactly |
| `enf_next_permitted_actions` | Exact `VARCHAR(100)` text, including `TBC` |
| `order_term`, `enforcement_result`, `case_result`, `active`, `order_accruing`, `requires_creditor`, `enforcement_hold`, `requires_enforcer`, `generates_hearing`, `generates_warrant`, `lists_monies`, `requires_employment_data`, `allow_additional_action`, `manual_enforcement`, `auto_enforcement` | Direct BOOLEAN values |

No field is trimmed, derived, defaulted, or looked up. All supplied fields are
nonblank, so no NULL conversion is needed. IDs are never converted to numbers;
this input contains no leading-zero IDs. There are no generated IDs, sequences,
identity values, or foreign keys. The schema suite separately verifies those
properties. JSON is never converted to JSONB, reordered, or reserialized;
`MWDN` retains `[]`. JSON option strings such as `Courts-API` are opaque metadata,
not database relationships.

All 22 rows are active case results; six are Order Terms. The classifications
are one Ancillary, twelve Interim and nine Final. All enforcement-result,
manual-enforcement and auto-enforcement flags are false.

- GAP-001/002: the supplied CSV and its retained independent expected fixture
  resolve delivery-input gaps. The user explicitly accepted all 22 `TBC` values
  as intentional interim literals. Final action values are a later forward fix.
- Frontend interpretation of dynamic-field JSON is deferred by the user and
  remains unverified. Valid JSON storage does not establish consumer compatibility.
- GAP-003: TDIA authority is settled; no supporting template correction is needed.
- GAP-004: the stale workbook source-precedence/front-page correction belongs to
  a separate queued RM context task; its completion is unverified. No physical
  model change is needed for this seed.
- Historical provenance and strategic go-live sourcing are distinct. Future
  sourcing remains undecided and does not change this delivery input.

## Existing rows, transactions and recovery

The migration is a single explicit INSERT with 22 literal rows. Every supplied
key must be absent before execution; any duplicate key, even with identical
values, fails with PostgreSQL SQLSTATE `23505` on `results_pk`. There is no
staging table, custom conflict validator, target UPDATE/DELETE, or upsert.
A successful application inserts exactly 22 rows and preserves unrelated rows.

Flyway owns the transaction and skips the recorded version on subsequent runs.
Direct SQL replay is deliberately not idempotent: duplicate keys fail and the
whole INSERT rolls back, including when only a late source key already exists.
The user explicitly chose this simpler one-time-load contract during implementation
review, superseding the design's earlier identical/partial-row acceptance.

Deploy serially without concurrent application writes to these definitions.
Ordinary INSERT/index locks apply; no persistent schema rewrite or planned
downtime is required. Concurrent uniqueness collisions fail and roll back, rather
than being silently ignored. Concurrency stress testing is outside this approved
22-row serial seed. Measured candidate runtime is recorded in the local validation evidence; it is
an observation, not a production latency guarantee.

Deploy after the complete 1.12 predecessor. The schema and existing rows remain
compatible; new values' frontend interpretation remains the accepted limitation
above. Post-migration monitoring should show one successful 1.13 history entry,
no migration error, and exactly the supplied keys with their exact values.
Read-only summary checks, only against separately authorised targets:

```sql
SELECT version, script, success FROM public.flyway_schema_history
WHERE script = 'V1_13__insert_results_reference_data.sql';

SELECT result_id, result_title, order_term, active, enf_next_permitted_actions
FROM public.results
WHERE result_id IN ('MAT','MCHILD','MLUMP','MNSTD','MSUMM','MNENF','MADJ',
 'MPAY','MTEMP','MAEO','MWDN','MREMT','MBAIL','MCMTP','MTPDA','MTPDO',
 'MCOO','MCON','MWOC','MWCN','MWOA','MWAN')
ORDER BY result_id;
```

Expect one successful history entry, 22 supplied keys, all active, six Order
Terms, and all `TBC`. These summaries do not replace full-field reconciliation.
On failure, retain the diagnostic and investigate the duplicate key or rejected value.
Do not automatically overwrite rows, delete data, repair history, or reset a
database. An applied migration is immutable; corrections require a separately
approved forward migration. Rolling back application code does not remove data.

## Validation

The 12-assertion `results_data_pgtap_tests.sql` is discovered by the existing
runner. It implements AC4's historical `results_data_unit_tests.sql` requirement
using the repository's current naming convention. The existing 91-assertion
schema suite permits seeded/unrelated rows and guards only its synthetic keys;
its types, constraints, malformed JSON and invalid enum checks remain intact.

Both suites apply to fresh and predecessor-upgrade paths. The data suite checks
all supplied values, exact JSON text, fresh insertion and unrelated-row preservation.
Failure scenarios execute the actual migration: identical existing keys, differing
existing keys, a late duplicate in an otherwise empty seed scope, and a late target
CHECK rejection. Each requires the intended SQLSTATE and constraint name plus an
unchanged pre-attempt full-row snapshot. Fixture changes also roll back.

Commands executed with Java 21, repository Gradle 9.7.1, PostgreSQL 17.11 and
Flyway 13.5.0 in disposable containers:

```bash
./gradlew --no-daemon dbUnitTest
./gradlew --no-daemon build
```

- Fresh-cache preflight resolved pinned PostgreSQL JDBC 42.7.13 successfully;
  temporary project/cache cleanup was confirmed after network remediation.
- Unchanged baseline passed. The original missing-seed test failed as expected.
  Following review, three new duplicate-rejection assertions failed against the
  old staging implementation before the migration was simplified.
- Revised full build passed in 1 minute 15 seconds: 415 assertions across ten SQL
  suites, 21 unit tests, 28 integration tests, Checkstyle and packaging. Database
  execution took 8.837 seconds; cleanup was confirmed.
- Revised fresh and complete-1.12 upgrade checks using only ddl + allEnvs each
  passed 103 focused assertions, exact migration-set checks and unchanged
  data/history after Flyway rerun. Unrelated rows were preserved. The matrix took
  15 seconds, with a 6 ms candidate upgrade; container cleanup was confirmed.

Local evidence and the bounded `validate-upgrade.sh` procedure are under
`build/reports/dbUnitTest/po10295/` (ignored). The predecessor procedure is not a
new Gradle task. No optional failing-Flyway invocation was run: SQL subtransaction
atomicity is narrower evidence and is not represented as that check. No shared
environment or frontend was exercised. Functional/smoke HTTP runs are not needed
for this SQL-only change; endpoints, configuration and backend code are unchanged.

## Acceptance criteria and remaining delivery

| AC | Evidence / status |
| --- | --- |
| AC1 | Existing TDIA/schema, direct mapping and explicitly accepted interim decisions |
| AC2 | Retained fingerprinted CSV, 20-field exact comparison, no transformation/runtime sync |
| AC3 | New allEnvs V1_13, SQL failure atomicity, forward-only recovery |
| AC4 | Discoverable 12 data + 91 schema assertions; see final validation evidence |
| AC5 | Disposable PostgreSQL 17 fresh/predecessor/repeat/failure checks and cleanup |
| AC6 | Maintenance Database LLD publication and saved-page readback remain pending |

The LLD draft is a handoff, not published AC6 evidence. External publication,
two human reviewer approvals, QA, CI, merge and deployment require their own
evidence. The workbook follow-up is separate and must not be claimed complete.
The change contains reference definitions only, with no PII or secrets; no
dependencies, security controls, privileges or persistent schema are changed.
