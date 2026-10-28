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

## Locking and supported writers

After the draft row is locked and authenticated ownership/approval checks pass,
`PUBLISHED` cleanup acquires this fixed lock in its existing transaction, immediately
before graph traversal:

```sql
LOCK TABLE public.respondent_accounts, public.creditor_accounts, public.parties
IN ACCESS EXCLUSIVE MODE NOWAIT
```

These are **whole-table** locks on exactly those three tables. While held, they
block unrelated reads **and** writes on those tables, including ordinary readers
and publication work. They are not scoped to a BU, marker or account. Conflicting
already-held locks make acquisition fail immediately; the support transaction
rolls back and exposes safe 503 for this PostgreSQL lock contention. A later
bounded client retry may succeed after contention clears, or return 409 if the
committed writer made the graph shared/ineligible.

`NOWAIT` bounds **acquisition of these table locks only**, not total cleanup
transaction/HTTP duration. The draft row lock, other row locks and graph work can
still wait or take time. Locks remain held until commit/rollback. There is no pool
admission aspect, pool-minus-one guarantee, endpoint-wide deadline or automatic
retry. Accept the availability cost before enabling; monitor ordinary service
health and time spent by cleanup/blocked work in the agreed environment.

The supported concurrent polymorphic writers are the unchanged baseline
`p_insert_notes` and `p_insert_respondent_account_parties` helpers and callers that
perform equivalent target validation/read **in the same transaction as the write**,
using the baseline READ COMMITTED transaction behavior rather than cached target
existence. The note helper reads `respondent_accounts`; Respondent associations validate
`parties`; Applicant associations validate `creditor_accounts`/`parties`. The locks
therefore prevent validation reads while cleanup holds its graph locks, or refuse
cleanup while a validating writer holds its target read lock. Existing foreign
keys protect the remaining typed relationships.

**Exclude direct INSERT/UPDATE into `notes` or `respondent_account_parties` that
bypasses same-transaction target validation.** Their polymorphic targets lack
foreign keys: table locks on the targets cannot protect an arbitrary writer that
never accesses a target. No production helper, trigger or procedure is changed
by this support lineage. The test/operations contract must exclude unsupported
direct writers; if that cannot be accepted, obtain an explicit quiescence or
cleanup-eligibility scope decision before enablement.

## Privileges, failures and operating prerequisites

Verify the **actual deployed service role** can acquire ACCESS EXCLUSIVE locks on
all three tables and perform the existing graph SELECT/DELETE operations. Disposable
owner-role Testcontainers success does not establish deployed privileges. This
change adds no grants or migrations; do not infer privileges from an HTTP 503 or
change shared grants as a test setup step. Permission/syntax/constraint failures
are not reclassified as retryable table-lock contention.

Enable only after operational acceptance of table-wide blocking, verified role
capability, exclusion of bypass writers, and the
[migration/consumer cutover checks](DRAFT_CASEFILE_TEST_CLEANUP.md#deployment-and-recovery).
The actual-role checks and environment acceptance remain deployment prerequisites,
not facts established by this candidate.

The after hook retains every failed cleanup ledger entry until 204. Use a finite
retry budget/backoff for transient 503 or uncertain network outcomes; retain and
report the entry when exhausted. Treat 409 as an eligibility investigation. After
a successful or failed cleanup, the transaction releases its locks. No client retry
may broaden the scope, edit the marker or delete rows directly to force success.

## Verification boundaries

Backend Spring/PostgreSQL integration tests cover graph scope, rollback, legacy
versions, siblings/references and both helper/cleanup transaction orderings.
Cleanup-first tests observe blocked real target reads and verify commit versus
rollback outcomes; writer-first tests verify refusal and safe retry/shared-graph
conflict. These are disposable database observations, not deployed workload,
actual-role or browser/broker proof. See [Testing](TESTING.md#synthetic-draft-casefile-cleanup)
for commands and evidence ownership. Final run results belong in the current
verification handoff; historical passing counts are not evidence for a new run.
