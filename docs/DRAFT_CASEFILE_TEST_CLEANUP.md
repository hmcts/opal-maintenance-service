# Synthetic Draft Casefile test cleanup

The dedicated `DELETE /testing-support/draft-casefiles/{draft_casefile_id}` removes
an authenticated inputter's eligible synthetic RM draft and, when safe, its exclusive
published graph. Create data through normal APIs/UI and capture the returned ID.
Normal Draft Casefile GET/list/re-entry APIs supply authoritative state; this support
contract adds no state-read, publication-evidence or generic SQL endpoint. Complete
all response, recovery, snapshot and timeline assertions **before DELETE**.

## Request and responses

This HTTP example uses placeholders, never a real token:

```http
DELETE /testing-support/draft-casefiles/<draft_casefile_id>
Authorization: Bearer <inputter-token>
Test-Run-Reference: <E2E-followed-by-16-lowercase-hex-characters>
```

The ID is a positive signed 64-bit integer. The required header is exactly 20
characters matching `^E2E-[0-9a-f]{16}$`. There is no request body or `If-Match`
requirement. A preceding GET is needed for test assertions/recovery, not for DELETE
itself. See the [OpenAPI contract](../src/main/resources/openapi/TestingSupport.yaml).

| Status | Meaning and cleanup-ledger action |
| --- | --- |
| 204 | Deleted, or already absent after authentication. Remove only this entry from the outstanding ledger. |
| 400 | Invalid ID or missing/invalid marker. Retain the entry and correct the request. |
| 401 | Missing/invalid bearer authentication. Retain the entry and resolve authentication. |
| 403 | Permission, latest submitter or exact persisted marker mismatch. Retain the entry and report the scope failure. |
| 404 | Route is not registered when disabled. Retain the entry and resolve enablement with the operator. |
| 409 | Ineligible lifecycle or shared, inconsistent or financially active published graph. Retain the entry and investigate; retries cannot make an unsafe graph eligible. |
| 500 | Unexpected failure; the cleanup transaction rolls back. Retain the entry and investigate; any retry must be bounded. |
| 503 | Persistence temporarily unavailable or cleanup lock contention; the cleanup transaction rolls back. Retain the entry and use bounded backoff after contention resolves. |

Errors use the existing safe OPAL Problem Details where specified. When disabled,
an authenticated request gets 404 and runtime OpenAPI omits the route; an anonymous
request still gets 401 under normal security. A repeated DELETE of an absent ID
returns 204 after authentication. With no stored row, there is no BU or submitter
against which to check permission/ownership and no data is deleted. A network timeout
can hide a committed DELETE: retain the ledger entry and retry the same scoped
request within the retry budget until 204 confirms absence.

## Enablement, identity and scope

`TESTING_SUPPORT_ENDPOINTS_ENABLED` is the existing single switch for diagnostics
and cleanup. The application and base Helm default is **false**; keep it false in
production. Standalone Compose and existing dev/staging overlays enable it, while
the shared stack inherits its `.env.shared` value. Verify the resolved deployment
values, including frontend-owned Maintenance subcharts: there is no application
allowlist based on an environment name.

Enable only for agreed non-live synthetic tests after accepting the
[published cleanup operating contract](PUBLISHED_DRAFT_CASEFILE_CLEANUP.md#locking-and-supported-writers).
There is no endpoint-specific owner variable, credential, token-minting API or
frontend source switch. Use existing bearer validation and User Service identity;
keep tokens out of source, command arguments, logs and ledgers.

For each existing locked draft, cleanup requires all of:

- Permission **21** (`CREATE_MANAGE_DRAFT_CASEFILES`) in the **stored** business unit.
- The caller's Business Unit User ID in that BU equals persisted `submitted_by`,
  which represents the latest inputter after replacement/resubmission.
- The supplied marker equals saved `casefile.respondent_account.remo_reference`
  exactly. Missing, malformed or different stored markers fail scope checks.

A checker who approved a draft does not thereby own its cleanup. Retain the owning
inputter as well as ID and marker, and authenticate as that inputter for cleanup.
The marker is visible run context, neither a secret nor independent proof of
synthetic data. Do not make existing unmarked or real records eligible by editing
stored data.

## Lifecycle and transaction rules

| Stored lifecycle | Eligibility in addition to scope checks |
| --- | --- |
| `SUBMITTED` | Unlinked; validation date, validator ID and validator name are null. |
| `REJECTED`, `RESUBMITTED`, `DELETED`, `PUBLISHING_FAILED` | Unlinked with a structurally valid unlinked snapshot. |
| `PUBLISHING_PENDING` | Unlinked with valid approval metadata: date, nonblank validator ID/name and validator different from the latest submitter. |
| `PUBLISHED` | Valid approval metadata plus the complete exclusive graph checks in the [published guide](PUBLISHED_DRAFT_CASEFILE_CLEANUP.md). |
| Missing/unknown lifecycle or inconsistent metadata | Refused with 409. |

Unlinked means the draft's `account_id` and `account_number` are null, and snapshot
respondent/applicant objects and every member of the minor-creditor array contain
explicitly null `account_id`/`account_number`. Malformed snapshots or linked account
identities fail eligibility. Rejected or resubmitted drafts need not have null
validation history; the extra null-validation rule applies to `SUBMITTED`.

The service locks the addressed draft and checks/deletes/flushes in one transaction.
The legacy null-version draft path is retained. Deleting the draft removes its
embedded casefile, snapshot, draft notes and timeline. An eligible published draft
also removes its checked exclusive graph in the same transaction. Any failure rolls
back both draft and graph changes; no partial cleanup is committed. Published locks
release at commit/rollback. External PDPL/personal-data processing records, shared
reference records, siblings and sequences are retained.

Pending cleanup serializes with the existing consumer through the draft row lock.
If delivery wins, cleanup re-evaluates the resulting lifecycle/graph; if cleanup
wins, the existing consumer's absent-draft handling applies. DELETE does not purge a
queue message, prove broker settlement or undo an external side effect.

## FE/QA handoff and cleanup ledger

The concurrency journey must use this sequence:

1. Create fresh synthetic data through normal UI/APIs with a new exact marker.
   Capture a successful real POST's ID **before** confirmation/UI assertions can
   fail. Persist ID, owning inputter, marker, environment and scenario/run key in a
   durable cleanup ledger containing no tokens or participant payloads.
2. Record the normal GET baseline: ID, ETag/version, lifecycle, saved casefile,
   snapshot and timeline. Trigger one normal PATCH decision (approve/reject/delete)
   or rejected-case PUT resubmission through the UI. Forward the real request and
   let the real backend commit; drop **only its response** for the ambiguous case.
   Never replace the mutation with a stubbed successful response.
3. Count browser PATCH/PUT attempts through completed recovery and accessibility
   assertions. Recover through normal GET/re-entry, retaining local context while
   reconciling the authoritative ID, version, lifecycle and snapshot. Assert exactly
   one corresponding decision/resubmission timeline event and the retained prior
   timeline. Account for the separate asynchronous publication lifecycle when
   observing approval; do not equate its events with another decision.
4. Keep approve, reject, delete, resubmit, definite pre-commit failure, stale-version
   conflict and accessibility scenarios distinct. Definite failure retains edits
   for explicit retry; stale conflict changes no stale data and allows reload.
   A deliberate retry has a different expected request count from automatic replay.
5. After all assertions, including on assertion failure, use the existing scoped
   DELETE in the after hook as the owning inputter with the exact marker. Remove an
   entry only on 204. Retain every failed/unknown result, report it and use a finite
   retry budget/backoff for transient/network failures; the service does not retry
   automatically. Never hide cleanup failure behind a successful scenario result.
6. Retain failed entries across browser/process crashes for a separately authorised
   retry. Hooks cannot guarantee execution. A lost creation response can leave an
   unknown committed ID: this endpoint cannot discover it, so report that gap rather
   than inventing an ID or broad deletion.

Consumer work must remove all publication-evidence registration/read calls,
interfaces, schema dependencies and their assertions before adopting this backend.
The [testing handoff](TESTING.md#synthetic-draft-casefile-cleanup) identifies the
current RM consumer files and evidence allocation. This backend support does not
complete the deployed UI E2E ticket or demonstrate exactly-once broker delivery.

## Deployment and recovery

This candidate introduces no schema/procedure migration relative to the approved
PO-10629 base. The original `codex/PO-10626-publication-support` branch and PR #318
are preserved. Its committed V1_67–V1_69 migrations remain immutable; their applied
status in retained environments is **unknown**. A zero migration diff on this new
lineage does not prove rollout compatibility with a database that applied them.

Before release, obtain the environment/version/checksum/applied-status inventory.
If a retained environment applied any of V1_67–V1_69, stop a rollout premised on their
absence and obtain a separately approved forward-recovery plan covering
compatibility/retention, consumer cutover, deployment order and rollback/roll-forward.
Do not edit/delete applied migrations, repair shared history, or treat retained
inert tables as zero schema difference. No shared database action is authorised by
this guide.

Before enablement, verify the actual deployed DB role and accept table blocking
and supported-writer restrictions. To disable support, set the flag false and
redeploy normally; retain outstanding ledger entries for authorised retry.
Disabling cannot restore deleted data. Use existing `/health` and `/prometheus`
monitoring and non-sensitive CI cleanup outcomes; no publication monitor is added.
