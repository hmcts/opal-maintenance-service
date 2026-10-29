# Exclusive published Draft Casefile cleanup

The default-off dedicated [synthetic cleanup DELETE](DRAFT_CASEFILE_TEST_CLEANUP.md)
can remove an owned `PUBLISHED` RM draft and its initial, exclusive publication
graph in one transaction. It is restricted to agreed non-live synthetic tests.
Permission 21 in the stored BU, latest submitter identity, exact persisted marker
and valid distinct-checker approval are checked before acquiring published target
locks or traversing the graph. Normal business publication is unchanged.

## Graph inventory and eligibility

Cleanup verifies the saved publication identities against live rows. In addition
to the request/scope checks, the graph must satisfy these guards:

| Graph area | Required condition |
| --- | --- |
| Draft/snapshot | `PUBLISHED`, positive populated respondent/applicant/minor identities, matching draft respondent ID/number, valid minor sequences and valid approval metadata. |
| Respondent account | Exactly one matching ID, stored BU, account number and exact REMO marker; initial `version_number=1` and zero `account_balance`. |
| Associations | Exactly one Respondent party and one Applicant creditor account; at most one Central Authority association; no extra association types. Applicant matches the snapshot. |
| Order terms and creditors | Nonempty saved terms match live term count; snapshot applicant/minor accounts exist with matching numbers and `MN` type, unique minor parties and no major-creditor ID. Other term creditors are `MJ` accounts matching the saved major-creditor codes in the BU. Every graph creditor belongs to the BU and has its initial null version. |
| Parties | All expected parties exist with the required Respondent/Minor Creditor types and distinct identities. |
| Exclusive dependants | No other draft points to the respondent; no other respondent's order terms or typed Applicant/Respondent associations share graph creditors/parties; no other creditor uses a graph minor party. Optional debtor detail and contacts exist and are not used by outside accounts. |
| Account-number reservations | Every respondent/creditor number is distinct, has exactly one correctly typed reservation in the BU and is not reused by outside accounts. |

These checks refuse shared, inconsistent or financially active graphs with 409;
cleanup does not attempt to repair them. The initial-version and zero-balance
requirements constrain eligibility; they do not establish a general financial
reversal capability. Snapshot, typed association and reservation checks are all
required; a marker alone never authorises traversal/deletion.

After validation, the service deletes/flushes the draft before deleting graph
rows, all within the same transaction. The inventory is:

| Removed when exclusively owned and validated | Retained |
| --- | --- |
| The addressed `draft_casefiles` row with embedded casefile, snapshot, draft notes and timeline. | All sibling drafts and unrelated graphs. |
| `notes` whose canonical typed target is the graph respondent or graph creditor accounts. | Notes for unrelated targets. |
| The respondent's `order_terms` and `respondent_account_parties`, including its Central Authority association. | Shared Central Authority/major-creditor reference records. |
| The respondent account and all graph creditor accounts, including graph `MJ` creditor-account rows. | Referenced `major_creditors`, business units and other reference data. |
| Graph party aliases and Respondent/Minor Creditor parties. | Unrelated parties/aliases. |
| Exclusive optional `third_party_contact` and `debtor_detail` rows. | Outside contacts/debtor records; a shared dependency prevents cleanup. |
| Graph `account_number_index` reservations in the stored BU. | Other reservations and every sequence's current value; cleanup never resets sequences. |
| No external record. | External PDPL/personal-data processing records, queue messages and broker state. |

Any failed guard or later delete/flush error rolls back **all** draft and graph
changes. The null-version legacy draft deletion path is retained. Capture normal
GET/snapshot/timeline assertions before DELETE, because cleanup removes them.

## Locking and accepted concurrency risk

On 28 October 2026 the user explicitly chose to remove the additional table-wide
locks and accept the risk of published cleanup overlapping concurrent writers in
non-live tests. This supersedes the earlier whole-table locking proposal. No
`LOCK TABLE` statement, table-lock privilege requirement or cleanup-specific
lock-contention translation remains.

The existing pessimistic draft-row lock, graph-row locks, foreign keys and one
Spring-managed cleanup transaction remain. They still serialize operations on
the same draft with the normal publication/failure paths and preserve rollback.
They do not provide a complete concurrency guarantee for the published graph.
Normal row-level or foreign-key contention can still occur; removing explicit
table-wide locks does not promise that all other activity is unaffected.

In particular, `notes` and `respondent_account_parties` have polymorphic targets.
A concurrent writer can validate a target before cleanup deletes it and insert a
note or association afterwards. Prior regression experiments reproduced dangling
references in that ordering. Existing ownership/sharing checks inspect the state
visible to cleanup; they do not prevent a subsequent write from changing it. The
remaining row locks do not close this gap, even for the unchanged target-validating
helpers. Arbitrary direct writers are not protected either.

This is an explicitly accepted test-cleanup limitation, not a guarantee provided
by Fines or by an `afterEach` hook. Run cleanup after the test's state/timeline
assertions and avoid overlapping writes where practical. Completion of browser
assertions does not prove that asynchronous processing has finished. The user has
accepted this risk without requiring a new isolated-environment prerequisite;
any later change in that decision must be reconciled before changing the design.
Production support remains disabled by default. No production helper, trigger or
stored procedure is changed by this support lineage.

## Privileges, failures and operating prerequisites

Verify the actual deployed service role can perform the existing graph SELECT
and DELETE operations. No additional explicit table-lock permission is required
by this cleanup implementation. Disposable owner-role tests do not verify the
deployed role; this change adds no grants or migrations and does not authorize
shared grant changes as test setup.

The after hook retains every failed cleanup ledger entry until 204. Persistence
unavailability can produce the existing safe 503. No special PostgreSQL lock
contention-to-503 contract is added; other failures retain the normal service
mapping and rollback behavior. Use bounded retries for transient storage/network
failures, and retain/report an entry when retries are exhausted. A 409 requires
eligibility investigation rather than retries that broaden scope.

Enable only for agreed synthetic non-live tests with the retained identity,
marker and lifecycle checks and the [consumer cutover requirements](DRAFT_CASEFILE_TEST_CLEANUP.md#deployment-and-recovery).
The previous requirements to accept table-wide blocking and acquire explicit
table locks have been removed. Deployed read/delete capability, frontend cutover
and recovery/broker verification remain separate requirements.

## Verification boundaries

Backend Spring/PostgreSQL integration tests cover graph scope, rollback, legacy
versions, siblings/references and same-draft publication/cleanup transaction
ordering. A published-cleanup regression holds ordinary reader transactions open
on the three target tables while cleanup completes on another connection. It
failed with the previous table-wide locks and verifies the requested removal.

The nine former helper/cleanup race-prevention tests and the four unit cases for
the removed lock-error translator are retired with that protection. No passing
result is claimed for preventing the accepted polymorphic-writer race. Retained
consumer and failure-recording races still exercise the existing draft-row lock.
These local tests do not establish deployed role privileges, browser recovery or
broker behavior. See [Testing](TESTING.md#synthetic-draft-casefile-cleanup) for
commands and evidence ownership.

## Verification record — lock removal, 28 October 2026

The ordinary-reader regression first failed against `bc1ae57` because the prior
explicit table locks rejected cleanup. After removal, the changed source passed:

```sh
./gradlew integration --tests '*DraftCasefilePublishedCleanupIntegrationTest' --tests '*DraftCasefileCleanupConsumerIntegrationTest' test --tests '*DraftCasefileCleanup*' --tests '*DraftCasefileTestScope*' checkstyleMain checkstyleTest checkstyleIntegrationTest --offline --no-daemon
```

Result: **25 integration tests and 216 focused unit tests passed**, with zero
failures/errors/skips; Main, Test and Integration Checkstyle passed. The full unit
run subsequently passed **669 tests** with zero failures/errors/skips. The lower
counts reflect retirement of the nine explicit-lock race-prevention cases and
four translator unit cases, plus one new reader/cleanup regression.

The broader command below was still running at this update; its integration,
database, build and coverage outcome is **not claimed complete**:

```sh
./gradlew test integration build jacocoTestReport --offline --no-daemon
```

The earlier complete `bc1ae57` database/build verification is historical. Schema,
stored procedures and database-owned pgTAP remain unchanged, but old results are
not presented as a completed rerun of the revised application. Deployed graph
read/delete privileges, frontend evidence-route cutover, real recovery/accessibility
and dedicated-broker verification remain separate delivery requirements. Explicit
table-lock privileges and acceptance of table-wide blocking are no longer required.
