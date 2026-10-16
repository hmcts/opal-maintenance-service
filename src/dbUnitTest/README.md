# PO-10642 account-number contracts

The two self-contained SQL suites live directly under `src/dbUnitTest` and are
found by `./gradlew dbUnitTest`. Fixtures, temporary observation helpers,
range tests and multi-session coordination stay inside the owning suite.
No test subdirectory, support SQL, SQL include or shell test runner is added.
Existing suites retain their established paths.

## Contracts and dependencies

The public schema is the physical RM schema in Maintenance Service.

| Function | Parameters | Result | Database records and callers |
| --- | --- | --- | --- |
| `public.f_get_check_letter` | Required `pi_account_number VARCHAR` | `VARCHAR` check letter, or NULL for NULL input | No record reads/writes. Called by the allocator. |
| `public.f_get_account_number` | Required `pi_business_unit_id SMALLINT`, `pi_associated_record_type public.t_associated_record_type_enum` | Complete nine-character `VARCHAR` account number | Reads the BU's ledger and inserts one matching `public.account_number_index` row on success. Intended consumer: `p_process_draft_casefiles`, once per required account. |

The allocator's `%TYPE` signature resolves against the prerequisite table.
Both functions retain PostgreSQL defaults: VOLATILE, called on NULL input,
and security invoker. No argument defaults or transaction/status operations
are introduced. Backend services own transaction boundaries, run-status
changes and whole-transaction retries. The caller procedure and live-account
creation are outside this ticket.

Delivery order is the existing shared enum (V1_17), allocation ledger and its
owned sequence/default (V1_23), remaining parent migrations through V1_30,
then V1_31 checksum helper and V1_32 allocator. These are additive DDL migrations;
creating the functions changes zero application records.

The delivery is stacked on parent PR [#244](https://github.com/hmcts/opal-maintenance-service/pull/244),
branch `codex/PO-10635_Check_and_Validate_tables_types_and_configuration_data`,
pinned commit `e00be30ba6497998bdb0266761326f624efd2230`. The ticket-only diff uses
that commit, not master, as its boundary. Merge the parent first. Following a
squash merge, the child needs separately authorised stack recovery, version
checks and revalidation before targeting master; retargeting alone may retain
parent changes. Do not rebase, reset, rewrite, renumber or push automatically.

## Checksum and allocation

The helper takes the first eight characters, ignoring any suffix, and applies
positional weights `5, 1, 4, 2, 7, 5, 1, 4`. It sums the products, complements
the remainder modulo 23, maps a complement of 23 to zero, and adds 65 to obtain
an uppercase letter A through W. `26000001` has weighted total 20, index 3 and
letter D. NULL propagates. Empty, short or nonnumeric prefixes raise native
`22P02`; no stricter input contract is invented.

The helper suite contains 37 literal expected letters, independently established
by dot-product and modulo arithmetic, including all 23 outcomes and positional
weights. Examples include `26000001D`, `26000002W`, `00000000A` and `12345678H`.
The allocator suite uses a separate SQL oracle based on a row-wise dot product
and alphabet lookup, first checked against those four fixed examples. Production
helper output never supplies expected test values.

Allocation starts at sequence `000001` for the transaction-start year
(`TO_CHAR(NOW(),'YY')`). Existing allocations in a later year continue that year.
The selected sequence advances through `999999`; only then is the lowest
available gap reused. Minimum and interior gaps are scoped to the selected year,
including when an earlier year has allocations. A full range rolls into the
following year; a fully exhausted year 99 raises an exception instead of creating
a three-digit year. The returned format is `YYNNNNNNA`: two year digits, six
sequence digits and one calculated letter.

Every defined RM enum label (`respondent_accounts`, `creditor_accounts`,
`creditor_transactions`, `suspense_transactions`) and explicit NULL is stored
unchanged. There is no narrower account-only enum filter. A BU identifier is
accepted if its foreign key is valid, including an existing negative identifier.
A successful call inserts exactly one allocation, using the existing surrogate
ID default, and returns that row's complete account number. Repeated successful
calls allocate consecutive distinct values; the allocator is deliberately not
idempotent. Caller rollback removes the reservation and makes the account number
reusable; sequence values consumed by failed/rolled-back INSERTs are not rewound.

## Errors, locking and operations

| Cause | SQLSTATE / outcome |
| --- | --- |
| Helper malformed numeric prefix, invalid enum cast | `22P02` |
| NULL BU / missing BU | `23502` / `23503` |
| Omitted required argument / SMALLINT overflow | `42883` / `22003` |
| INSERT uniqueness violation | `23505` is caught; recalculate and retry, at most five total attempts |
| Fifth uniqueness failure | Default `P0001`; message identifies routine, operation, complete candidate, BU, original SQLSTATE/message; structured constraint name retained |
| Completely full year 99 | Default `P0001`, `Account number range exhausted for year 99` |
| Serialization failure / deadlock | `40001` / `40P01` propagate unchanged; no routine-level retry |

The existing immediate `(business_unit_id, account_number)` unique constraint
arbitrates competing callers. No new advisory/global lock or index is added.
READ COMMITTED permits a waiting loser to recompute after the winner commits;
if the winner rolls back, its candidate can be used. A different BU can complete
while the first transaction remains open. These three behaviours are tested with
separate real sessions and observed lock blockers, not inferred from elapsed time.

Higher isolation levels may retain an older snapshot or fail with serialization
errors; the backend must retry the whole transaction where appropriate. Five
collisions can still exhaust the bounded allocator retry. Extreme range
exhaustion requires a selected-year scan/sort; the suite genuinely fills all
999999 positions for both rollover and terminal failure, with a 180-second
statement bound. This is correctness evidence, not a production workload SLA.
Operational checks should confirm installed signatures, Flyway validation and
history, absence of duplicate BU/number pairs, and monitor allocator failures,
unique contention, serialization/deadlock errors and range-scan duration.

## Acceptance criteria and discoverable checks

[PO-10642](https://hmcts.atlassian.net/browse/PO-10642) and promoted TDIA revision
169 define the source contract. The approved later flat-layout decision
supersedes the source ticket's older `accountNumberTest/` directory reference;
the allocator suite filename and all coverage are retained. Jira path housekeeping
is a follow-up, not an external edit performed by this delivery.

| AC | Implementation / checks | Expected result |
| --- | --- | --- |
| AC1 signatures | V1_31, V1_32; helper H01, allocator A01 | Exact required arguments, return types, names and effective attributes |
| AC2 BU-scoped allocation | V1_32; A02-A07, B01-B02 | Complete independently expected number; exactly one matching BU/type allocation per success |
| AC3 collision protection | Existing parent unique rule; A03, A10-A11, C01-C03 | Duplicate pair rejected; bounded retry; concurrent correct numbers/rows |
| AC4 side effects | Both routine bodies; H04, A08-A12 | Pure helper; only allocation rows change; caller owns rollback; no status/live-account changes |
| AC5 Flyway delivery | V1_31/V1_32 after parent V1_30 | Helper precedes allocator; fresh and predecessor upgrade history valid |
| AC6 SQL suites | `f_get_check_letter_pgtap_tests.sql`, `f_get_account_number_pgtap_tests.sql` | 51 helper and 90 allocator assertions pass through existing discovery |
| AC7 PostgreSQL validation | Both suites; fresh, upgrade, failure recovery and rerun | PostgreSQL 17 complete numbers/rows/errors/uniqueness, unchanged history on rerun, cleanup |
| AC8 LLD | Maintenance Database LLD publication after validation | Separate publication and readback required; local draft does not satisfy published AC8 |

Helper assertion manifest: H01 4, H02 37, H03 8, H04 2 = 51.
Allocator manifest: oracle 4, C01-C03 3, A01 2, A02 9, A03 4, A04 11,
A05-A07 9, A08 5, A09 9, A10 5, A11 9, A12 2, B01 9, B02 5, B03 4 = 90.
A11 includes an additional structured-constraint assertion for the approved
error-diagnostics contract.

## Validation, cleanup and recovery

Run `./gradlew --no-daemon dbUnitTest` for the complete fresh stack and
`./gradlew --no-daemon build` for unit, database, integration, static-analysis
and packaging regression checks. Evidence belongs in `build/reports/dbUnitTest`
and the local ignored execution report. The fresh runner is not an upgrade
runner. An explicit disposable predecessor-upgrade run applies through V1_30,
then helper V1_31, validates helper answers, forces allocator failure only in a
temporary migration copy, and confirms helper committed/allocator absent with
history ending at V1_31. It retries the unchanged real V1_32, validates, runs
both suites, compares all application-row digests and preserved predecessor
history, then confirms a no-op migration rerun. No history repair/clean is used.

Unit fixtures use IDs 31901-31906 and -31901, with collision guards. Remote
concurrency fixtures reserve 31891/31892 and are explicitly removed after worker
connections close; a cleanup guard fails outside pgTAP exception capture if
ownership is uncertain. The helper caller role and test dblink extension are
transactional. Tests run only in harness-owned disposable PostgreSQL; temporary
containers are destroyed, with cleanup verified. Never use the developer stack
or a shared environment. `dblink` is test-only; no production extension or
application dependency is introduced. Missing extension files fail explicitly.

If a later migration fails, earlier successful migrations remain applied.
Confirm actual catalogue/history state before recovery. Retry unchanged bytes
only after the cause is resolved; defects in committed/applied migrations need
an approved recovery/forward-fix strategy. Do not edit immutable history, repair,
baseline, clean or drop functions automatically. Application rollback may stop
calling these additive routines; removing them requires dependency assessment.

The workbook fingerprint is
`d374b1005cb017bd0aecc820e7b33feb17041741678320caec2ffc1250c72d74`.
Its Baseline Target Model rows 2-5 match the predecessor ledger's four columns,
types, nullability and keys. No workbook structural change is required for this
routine-only delivery; prerequisite table/type documentation remains with its
owning tickets. The nine-character format retains the agreed documentation-error
assumption pending BA confirmation. Fixed 98/99/past-year test fixtures fail with
a maintenance message outside years 01-97. Runtime years 00-09 cannot currently
be selected without changing the approved clock contract; leading-zero helper
vectors and source padding review cover that limitation without a test parameter.
HTTP functional/smoke additions are not applicable: no HTTP, configuration,
authentication or application caller behaviour is changed.
