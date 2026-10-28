# Fresh database profiles and PO-10297 non-live seed

`./gradlew dbUnitTest --no-daemon` and the normal `./gradlew build` lifecycle run
two repository-owned disposable PostgreSQL 17 profiles, each with the complete
fresh suite set and its applicable selected registered upgrades:

| Profile | Flyway locations | Major Creditor outcome |
| --- | --- | --- |
| `non-live-dev` | `ddl`, `data/allEnvs`, `data/nle`, `data/dev` | Historical V1_33 supplies T901/T902/T903; V1_34 verifies the exact existing set without rewriting rows or consuming IDs. |
| `non-live` | `ddl`, `data/allEnvs`, `data/nle` | V1_34 inserts the same three synthetic BU 44 rows without DEV SQL. |

Both profiles discover and run the full existing SQL suite set, including the
historical V1_33 suite and the flat
`major_creditors_nle_data_pgtap_tests.sql`. The NLE fresh phase has 23 assertions:
the exact fourteen non-ID fields and generated IDs, selection, no-op rerun,
empty-set insertion and rollback, partial/mismatching data, missing or
ambiguous Country, Business Unit scope and mid-insert atomicity. It reads the
actual V1_34 migration in rolled-back test-only subtransactions. Expected
values are independently specified in the suite, and sequence gaps from failed
inserts are permitted. Reports and verified cleanup outcomes are written per
profile in unique `build/reports/dbUnitTest/<profile>/runs/<run-id>/` directories,
with latest summary/TAP entry points under each profile directory. The root
`build/reports/dbUnitTest/summary.txt` gives the aggregate result and cleanup
status for both profiles. Once global preflight and image preparation succeed,
the second profile is still attempted after the first fails.

The V1_33 registration is eligible only in `non-live-dev`; V1_34 is eligible in
both profiles, using each one's actual numerical predecessor. Both fresh
profiles still execute the DEV owning suite, including its direct historical SQL
check when DEV is absent from the common NLE Flyway inventory. Retain separate
upgrade results; fresh execution alone does not establish those boundaries.

The 21 October 2026 approval expands the earlier DEV-only PO-10297 seed to all
non-live environments. The old V1_33 migration and its historical documentation
remain unchanged. Production excludes `data/nle`; staging selects NLE without
DEV, and currently has no additional SQL in `data/stg`. Fresh checks alone do
not prove predecessor upgrade, shared-environment rollout, or the live read-only
functional scenario. Neither fixed profile proves future staging-specific SQL
or effective deployed locations. On rollout, resolve exactly one existing Czech
Republic, confirm BU 44 and the three fixture keys, and refresh affected Major Creditor
reference cache entries when caching is enabled. A partial or conflicting key
set fails migration and needs a reviewed data correction or forward-fix plan;
do not repair Flyway history or modify applied migrations.

# PO-10642 account-number contracts

The two self-contained SQL suites live directly under `src/dbUnitTest` and are
found by `./gradlew dbUnitTest`. Fixtures, temporary observation helpers,
range tests and multi-session coordination stay inside the owning suite.
This historical allocator delivery added no test subdirectory, support SQL,
SQL include or shell test runner. The maintained shared declaration and dispatch
contract below applies to subsequent upgrade integration.
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
and the local ignored execution report. In this historical allocator validation,
the then-fresh runner was not an upgrade runner. An explicit disposable
predecessor-upgrade run applies through V1_30,
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

# Maintained Flyway upgrade framework

Use the [maintained predecessor contract](../../docs/TESTING.md#maintained-predecessor-upgrade-contract)
and [SQL suite ownership](../../docs/TESTING.md#pgtap-suite-layout):

- `./gradlew dbUnitTest --no-daemon -PdbUnitTestComparisonRef=origin/codex/parent` runs every fresh suite and affected upgrades against a locally available immediate base.
- `./gradlew dbUnitTest --no-daemon -PdbUnitTestUpgradeMode=full` replays every applicable historical registration in both fixed profiles; use it after shared infrastructure changes.
- `./gradlew dbUnitTestProfileTest --no-daemon` checks fixed profiles, failure aggregation and resolved runtime agreement without Docker.
- `./gradlew dbUnitTestSelectionTest --no-daemon` checks selection regressions.
- `./gradlew dbUnitTestContractTest --no-daemon` checks compact declarations and shared support manifests.
- `./gradlew dbUnitTestFrameworkTest --no-daemon` checks disposable orchestration regressions, including the parent framework matrix.
- `./gradlew dbUnitTestParentTransitionTest --no-daemon -PdbUnitTestComparisonRef=<exact-full-SHA>` additionally checks both retained actual-parent transitions.
- `./gradlew dbUnitTestParentTransitionFrameworkTest --no-daemon` runs fixed parent controls directly.
- `./gradlew build --no-daemon` runs the repository baseline with the same affected/full selection contract.

Every normal build retains the complete fresh suite set in both fixed profiles.
A trustworthy comparison selects new applicable migrations and affected registered
boundaries against the actual immediate PR base. Missing, shallow or ambiguous
comparison context falls back to full replay of candidates eligible in each
profile. Outside-profile registrations remain Not selected, and outside-profile
migrations remain Unverified in that profile's report. They cannot become PASS
or upgrade N/A through another profile's success. Shared
runner/support/configuration changes also require full replay and automatically execute the native framework regression matrix;
uncertain comparison evidence requires that matrix too. Reports distinguish Not
selected from verified scenarios. The historical allocator evidence above remains
as recorded; framework availability does not retrospectively verify a standalone
recipe.

Before creating targets, the runner validates the complete-tree numerical
inventory, adoption and registrations globally. Registration ownership and
declared dependencies stay global; replay eligibility and numerical predecessor
selection use each profile's exact locations. Committed HEAD migration bytes
cannot be modified locally; comparison history also preserves existing paths and bytes.
New selected migrations extend that history. Modification, removal, rename,
lower-version insertion and duplicate versions fail rather than becoming a full
fallback success. Added migrations outside the exercised locations are reported
as Unverified; selected-location success does not prove their deployment coverage.

Every new upgrade contract requires a compact `OPAL-DB-UPGRADE` declaration and
shared dispatch, including a new registration in an existing suite. Keep required
`id`, `candidate`, `scope` and `data` fields and the mandatory `contract` object
identifying changed objects, exact preservation scope and a compatible assertion
group. Functional assertions stay in the one owning SQL suite.
Optional `inputs` declares additional canonical repository-relative dependencies;
the owner and candidate are implicit inputs. Follow the supported field shapes
in [Compact contract and shared dispatch](../../docs/TESTING.md#compact-contract-and-shared-dispatch)
rather than maintaining a second migration registry.

Shared support owns declared-scope capture/comparison, phase guards, positive
exact TAP plans, committed observation storage and independent cleanup readback.
The fixed `support/manifest.json` controls helper loading and fingerprints;
support files are never discovered as standalone fresh suites. The owner retains
functional assertions, independent expected results, fixtures and real-session
coordination. It receives the declared `opal_assertion_group` for compatible
rolled-back candidate assertions, while all current functional assertions run
on the complete fresh schema. Preserve focused historical expectations when
later behaviour or dependencies differ; never execute future-dependent assertions
at an earlier boundary. New contracts do not duplicate shared preparation,
capture, committed transport or cleanup in the owner.

For a data contract, optional `observe` has exactly `rows` and `sequences` arrays.
Require canonical qualified identities, no duplicates, at least one nonempty
array and no overlap with the corresponding `preserve` array. Observed rows may
still have exact table metadata preservation. Shared preparation captures the
bounded observation as `saved.observed`, separate from the unchanged exact
preservation snapshot. Other contract types cannot use `observe`. Data contracts
require a custom verifier and forbid declared object creations/replacements.
Observation supplies predecessor evidence for explicit outcomes; it never weakens
`preserve` equality. Compare original row-text strings, multiplicity and IDs even
when a copy is parsed for classification.

Optional declared SQL under `upgradeCases/` is reserved for risk-specific
transitions or approved synthetic preparation and is invoked explicitly through
`pg_prove`, never discovered as a fresh suite. Custom prepare retains its canonical
path and approved-synthetic requirements. Business predecessor fixtures still
require an approved data-scenario contract; custom preparation does not grant
approval.

Only `custom.verify` may instead use the reserved string `owner`. The runner
validates and resolves the registration's declaring regular, canonical SQL file
beneath `src/dbUnitTest`; missing/symlink files fail and the token cannot choose
another owner. The owner is already an implicit dependency: neither the token
nor a duplicated owner path belongs in `inputs`. Ordinary custom paths remain
classified dependencies and fingerprinted inputs.

After shared exact-preservation verification, custom verification runs with
`opal_phase=verify`, followed by ordinary owning assertions with `opal_phase=fresh`.
Both use positive exact plans and rollback. A custom owner verifier loads the
guarded shared payload through `pg_temp.opal_contract_load` with exact contract,
scenario, candidate and predecessor identities. It checks intended outcomes from
`saved.observed`; shared support alone owns committed capture and cleanup, which
remain required after verifier failure. Native Flyway validation, zero-applied
repeat and exact history equality, precise data outcomes and UUID-owned
target/volume destruction remain mandatory.

Genuine earlier four-field registrations retain their legacy phase API during
independently reviewed consumer adaptation. Keep their existing functional,
preservation and real-session coverage until an adapter replaces lifecycle
boilerplate with the compact declaration and passes its own checks. An existing
suite does not exempt a newly registered contract from compact/shared dispatch.
Framework compatibility alone does not prove consumer adoption.

The adopted legacy inventory is fixed at the 32 historical migrations on
`847739c9ee40ca1c09687756212f7f0dcbb56e7d`. All 32 paths and bytes are checked
globally, even when a profile omits adopted DEV files. Every later migration in
the union of supported locations requires registration; do not extend the
inventory to exempt it. The generic SQL suite owns complete native history
boundaries and repeat equality. Fixed SQL-only fixtures under `framework/`
exercise orchestration failures, including continuation to the second profile
after the first fails.

The Flyway image is derived from the actual resolved application `flyway-core`
and `flyway-database-postgresql` runtime modules. Exactly one of each must resolve
to the same numerical release version, and every native JSON response must report
that version. No profile or Flyway image override is supported.

Source fingerprints and per-target evidence remain under
`build/reports/dbUnitTest/<profile>/runs/<run-id>/`, with shared preparation and
framework reports under `preparation/` and `framework/`. Per-profile latest
summary/TAP entry points and the root aggregate summary identify the completed
runs. Container removal, container absence and every known owned anonymous
volume's absence are attempted independently. Any cleanup failure fails the
command; original primary errors and all cleanup diagnostics remain available.
Resources are limited to the exact task-owned target and volumes, never global
Docker resources or developer-owned named volumes.

Normal comparison refs select impact; registered replay recreates each selected
numerical predecessor. The explicit additional
[actual-parent task](../../docs/TESTING.md#actual-comparison-parent-batch-verification)
retains each fixed profile's independently derived comparison inventory and
applies all additions on that target. Supply an exact full local SHA equal to
HEAD or its sole immediate parent; no missing/base/CI fallback is allowed.
Comparison equal to HEAD may be a merge (`comparisonKind=head-inventory`); a
different candidate must have exactly that comparison as its one parent
(`comparisonKind=sole-immediate-parent`). Reports include `parentProvenance`,
`candidateMode`, `overlayPaths`, `testedHeadTree` and `testedParents`. Clean source
is labelled `committed HEAD`; dirty source is labelled `HEAD plus index/worktree
overlay`. Working evidence does not prove a committed parent relationship;
retain a clean-child rerun against its sole immediate parent for that claim.

Both profiles verify original row text/multiplicity, enumerated public catalogue,
ACL/routine/enum/sequence state, complete original/final history, native
validation and zero-applied repeat/history around final owning assertions.
Equality and empty delta are fully verified, not skipped. Delta derives only
from additions, with bounded routine/Aliases-name/Order-Term-response changes.
Unsupported incoming data/structure fails closed; compact `observe` grants no
implicit exemption. Historical seeds retain full registered replay and are not
incoming additions. No synthetic preparation is borrowed. Only the three fixed
framework self-suites requiring absent observations are excluded from retained
owners; all application owners remain and all 41 fresh suites run. Shared
committed observation cleanup, distinct-backend absence and an independent
no-other-client-sessions probe on the test-owned target, plus owned container/
every-volume absence, remain mandatory after failure. Both profiles are attempted
after preflight/preparation and failures aggregate.

Parent receipts live separately under
`build/reports/dbUnitTest/parent-transition/summary.txt`,
`parent-transition/<profile>/summary.txt` and each profile's `runs/<run-id>/`.
The parent matrix uses `parent-framework/summary.txt`, retains its original 24
controls and adds no-op, provenance, SQL/TAP/plan and preservation/cleanup failure
checks. It participates in the existing framework graph. Normal fresh/registered
report entry points are unchanged. The public parent task is explicitly invoked
with a comparison ref; it is not a default build requirement without that ref.

Each consumer must execute all current assertions on the fresh schema and its
applicable compatible assertion groups at every required candidate boundary.
Retain its actual interface and source revision, predecessor/candidate identities,
comparison provenance, selected/attempted/passed results and cleanup evidence. Framework
acceptance does not establish consumer verification or satisfy separately owned
application, service-role or documentation requirements. The one-owner
`dbUnitTestUpgradeSuite` diagnostic selector cannot be used under `check`/`build`
or replace required affected/full evidence.

The [procedure-side testing contract](../../docs/TESTING.md#planned-db-06-procedure-side-testing)
keeps target integrity, mapping, error propagation and atomicity in pgTAP.
Moved request-input validation and propagated-error response/log handling require
identified backend tests before the helper call; UI checks alone are insufficient.
Keep that dependency visible when its actual caller path or coverage is absent,
and do not claim the common unchanged rethrow sanitises native diagnostics.
