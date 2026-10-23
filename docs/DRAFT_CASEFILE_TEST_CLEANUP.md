# Synthetic Draft Casefile test support

The explicitly enabled testing-support APIs remove an authenticated inputter's
eligible synthetic draft (PO-10273) and record publication send evidence for
response-loss recovery tests (PO-10626). Create drafts through the real
`POST /draft-casefiles` journey and capture the returned `draft_casefile_id`.
The consumer sequence below is guidance for frontend adoption; Cypress response
loss simulation and a durable CI cleanup ledger are not implemented here.

## Enablement and authentication

All testing-support routes share `TESTING_SUPPORT_ENDPOINTS_ENABLED`. The
application and base Helm default it to `false`; local standalone Compose and
existing dev/staging overlays enable it. The shared Docker stack inherits the
flag from its existing `.env.shared` file. Verify resolved deployment values,
including frontend-owned Maintenance subcharts. Production must keep it false.
Setting it true registers the routes regardless of the environment's name;
there is no application-level environment allowlist.

No endpoint-specific identity or enablement variables are required. The previous
cleanup-specific flag, three owner variables and `OPAL_DEPLOYMENT_ENVIRONMENT`
have no effect; remove obsolete overrides during rollout. Fines provides the
shared-flag and transactional service-cleanup precedent. It has no equivalent
publication journal; Maintenance retains its own security and default settings.

Use existing AAD/internal bearer validation and User Service integration. For an
existing draft, the caller needs Maintenance permission **21**
(`CREATE_MANAGE_DRAFT_CASEFILES`) in the draft's persisted Business Unit (BU).
The caller's Business Unit User ID in that BU must match current `submitted_by`.
The stored draft selects the BU; request parameters cannot change that check.
There is no reserved automation identity or token-minting API in this service.

Every request below requires a positive signed 64-bit draft identifier and a
`Test-Run-Reference` header matching `^E2E-[0-9a-f]{16}$`: exactly 20 characters.
The marker must equal the current draft's
`casefile.respondent_account.remo_reference`. A marker is visible scenario
context, not a secret or independent proof that data is synthetic. Use only
synthetic data in agreed non-live environments. Older unmarked drafts are not
retroactively eligible.

Keep bearer values out of source, command arguments, logs and cleanup ledgers.
Journal rows contain identifiers, the run marker, timestamps and send outcomes;
responses contain only the seven fields below. Never persist participant data,
account numbers, names, tokens or request/response payloads in support evidence.

## Register and read publication evidence

These are HTTP examples with placeholders, not commands containing real tokens:

```http
POST /testing-support/draft-casefiles/<draft_casefile_id>/publication-evidence
Authorization: Bearer <current-inputter-token>
Test-Run-Reference: E2E-0123456789abcdef
```

```http
GET /testing-support/draft-casefiles/<draft_casefile_id>/publication-evidence
Authorization: Bearer <current-inputter-token>
Test-Run-Reference: E2E-0123456789abcdef
```

Neither operation has a request body or `If-Match` requirement. First registration
returns **201** and requires an unlinked `SUBMITTED`, `REJECTED` or `RESUBMITTED`
draft with null row/snapshot account IDs and numbers and consistent snapshot
structure. Identical repeat registration returns **200** with the same
`observation_id` and `registered_at` and the current counts, including after
approval. It does not reset counters, start a new interval or send a message.
GET returns **200** for an existing scoped observation and never sends a message.
Its draft scope, observation and counts are read from one PostgreSQL repeatable-read
snapshot. If eligible cleanup commits during that read, GET can return the valid
pre-cleanup snapshot, including uncertain or unfinished attempts. It cannot turn
deleted attempts into a successful zero baseline. Later GETs see the missing
draft and return 404. Capture the evidence before requesting cleanup.

The [OpenAPI source](../src/main/resources/openapi/TestingSupport.yaml) owns the
response-only `PublicationEvidence` schema, generated as
`TestingSupportPublicationEvidence`. Both operations return exactly these fields:

| Field | Type and meaning |
| --- | --- |
| `observation_id` | UUID identifying the observation; retain it to detect accidental replacement. |
| `registered_at` | Offset date-time when the observation was registered. |
| `send_attempt_count` | Nonnegative int64 count of attempts begun at the real publisher boundary. |
| `acknowledged_send_count` | Nonnegative int64 count for which the real publisher returned successfully. |
| `uncertain_send_count` | Nonnegative int64 count for which sending raised a transport/publisher exception and uncertainty was recorded. |
| `unfinished_send_count` | Nonnegative int64 count still recorded as `STARTED`, without a stored terminal outcome. |
| `evidence_complete` | Boolean; true only when uncertain and unfinished counts are both zero. |

A newly registered observation has counts `0/0/0/0` and
`evidence_complete=true`. Counts in this guide are always in the table's order:
attempts / acknowledged / uncertain / unfinished. A successful real approval
send normally produces `1/1/0/0`. A transport exception is not definite proof of
no send; successful broker acceptance may precede a lost acknowledgment. An
unfinished attempt can follow process exit or failure to store the outcome.
The decorator records the start before delegating once and stores the outcome
in independent transactions; evidence can survive rollback of the draft mutation.
It does not automatically retry or replay a send. The existing queue message is
forwarded unchanged, including draft ID, checker user ID, originating IP and
approval timestamp. The journal observes only the draft ID; it does not persist
that audit provenance or the message payload. The consumer compares the approval
timestamp to the saved approval, so a delayed delivery from a rolled-back approval
cannot publish a later approval of the same draft.

| Status | Registration/read meaning and action |
| --- | --- |
| 400 | Invalid identifier or missing/invalid marker; correct the request. |
| 401 | Missing/invalid bearer authentication; resolve authentication. |
| 403 | Permission, current ownership, current draft marker or stored observation marker mismatch; report scope failure. |
| 404 | Draft absent, or route disabled; an orphan observation never authorizes access. |
| 409 | First registration is ineligible, or GET has no registered observation (`DRAFT_CASEFILE003`); the evidence precondition failed. |
| 500 / 503 | Unexpected / temporarily unavailable persistence; retain context and report the failed evidence precondition. |

Both registration and GET check the current persisted draft scope **and** the
observation's stored marker. A real PUT resubmission changes ownership to the
latest inputter. Retain the marker and switch evidence/cleanup credentials to
that inputter. Checker PATCH actions keep the inputter's ownership; the checker's
permission does not grant access to the inputter's evidence or cleanup.

A legitimate PUT may replace the marker. It does not reassign, delete or reset
an existing observation. The old marker then fails the current-draft check and
the new marker fails the stored-observation check, so registration and GET
return 403. Preserve the marker throughout an observed recovery scenario. An
eligible cleanup by the current owner with the current marker can still remove
the attached old-marker observation, as described below.

### Support-enabled concurrency

When support is enabled, all public Draft Casefile service operations and the
cleanup, registration and evidence-read operations share admission with
`DraftCasefileQueueProcessingService.processPendingDraft` and
`DraftCasefilePublicationFailureService.markFailed` before their transactions begin. The per-replica bound is the actual configured Hikari maximum
pool size minus one: the default pool of 10 permits at most 9 active operations.
Further calls wait without an outer transaction or connection. The permit covers
commit or rollback and connection cleanup. The remaining pool capacity allows
the independent journal transactions to run without all connections being retained
by outer draft operations or draft-lock contenders. No separate pool is created.

This contract supports the existing nontransactional controller and queue
consumer entry points. The JMS listener uses a local JMS transaction; it does
not start a Spring database transaction around the callback. Admission wraps
each processing/failure transaction independently, leaving the consumer wrapper
and independent journal writer outside the guard.
A service call with an existing transaction or transaction synchronization fails
immediately, including nested calls; it must never queue while retaining an outer
connection. Callers must enter through these guarded service boundaries before
acquiring draft connections or locks. Support-disabled/default-off operation has
no admission guard and retains the existing transaction behavior.

The bound is fixed from Hikari configuration at startup; support-enabled startup
fails clearly for a maximum below 2. Do not resize the pool while the application
is running. Unrelated short reference reads and health checks share the same
pool and may briefly borrow its remaining capacity, but do not hold draft locks
or require nested journal transactions. This is a bound on guarded draft work,
not reserved physical connections or a guarantee against unrelated slow queries.
All replicas must run the same instrumented revision for the whole observation
interval. Any additional direct repository writers must reconcile their own
connection and locking protocol before this assumption is extended.

## Cleanup request and responses

```http
DELETE /testing-support/draft-casefiles/<draft_casefile_id>
Authorization: Bearer <current-inputter-token>
Test-Run-Reference: E2E-0123456789abcdef
```

There is no body, preceding GET or `If-Match` requirement. Capture recovery and
publication evidence **before DELETE**, because successful cleanup removes it.
The [OpenAPI contract](../src/main/resources/openapi/TestingSupport.yaml) defines:

| Status | Meaning and action |
| --- | --- |
| 204 | Deleted, or already absent after authentication; empty response. Remove only this entry from the outstanding ledger. |
| 400 | Invalid ID or missing/invalid marker; retain ID/marker and correct the request. |
| 401 | Missing/invalid bearer authentication; retain ID/marker and resolve authentication. |
| 403 | Caller permission/identity, persisted ownership or current marker mismatch; retain ID/marker and report scope failure. |
| 404 | Route is not registered when disabled; retain ID/marker and resolve enablement through the operator process. |
| 409 | Lifecycle, validation, publication links or inconsistent snapshot metadata prevent deletion; retain ID/marker and report. |
| 500 | Unexpected failure; transaction rolls back. Retain ID/marker and use bounded retries. |
| 503 | Persistence temporarily unavailable; transaction rolls back. Retain ID/marker and use bounded retries. |

Errors use existing safe OPAL Problem Details where specified. When disabled,
authenticated requests get 404 and runtime OpenAPI omits the routes. Anonymous
requests still get 401 under normal security. An already-absent draft returns
204 after authentication: there is no persisted BU/owner to check, and no orphan
journal rows are deleted.

The current cleanup lifecycle matrix is:

| Stored lifecycle | Eligible when owned, marked and unlinked | Validation metadata |
| --- | --- | --- |
| `SUBMITTED` | Yes | `validated_date`, `validated_by` and `validated_by_name` must all be null |
| `REJECTED`, `RESUBMITTED`, `DELETED`, `PUBLISHING_FAILED` | Yes | Checker metadata may remain |
| `PUBLISHING_PENDING`, `PUBLISHED` | No | Always rejected with 409; draft, account graph and journal remain |

Every eligible state requires null row `account_id` and `account_number`, and null
respondent, applicant and minor-creditor snapshot account IDs/numbers. Malformed
or inconsistent snapshot metadata is rejected. A validation timestamp alone does
not prove publication or make a draft eligible. Published accounts, reference
data and external personal-data processing logs are retained.

The service locks the addressed draft, checks current owner/marker/eligibility,
and deletes/flushes within one transaction. It removes any attached observation
using that observation's persisted marker; its send attempts cascade on deletion.
This also supports a legitimate marker-changing PUT once the current draft's
scope and eligibility have been verified. Failure rolls back draft, observation
and attempts together. A missing draft never permits orphan journal deletion.

Payload, participants, draft notes, snapshot and timeline are JSON within
`draft_casefiles` and are removed with that row. The journal refers to the draft
by ID without a draft foreign key. Generic notes apply to live account types,
and the draft's `account_id` points outward to a published account; cleanup does
not traverse that relationship. Reassess these boundaries if new dependants or
publication paths are introduced.

## Cypress recovery sequence (guidance only)

Use a separate unique synthetic draft for each approval, rejection, deletion or
PUT scenario. The response-loss test must satisfy this sequence:

1. Generate a fresh `E2E-` marker plus 16 lowercase hexadecimal characters and
   enter it through the existing REMO Reference UI field. Observe the real POST
   without substituting its response. Immediately capture the returned draft
   ID, before response/UI assertions, and durably record ID, marker, environment
   and scenario/run key in the CI cleanup ledger.
2. Register publication evidence before the mutation and retain the observation
   ID and registration time with the non-sensitive scenario context. Confirm
   baseline counts `0/0/0/0` and `evidence_complete=true`.
3. Capture every real `PATCH /draft-casefiles/{id}` and
   `PUT /draft-casefiles/{id}` request for this draft, including retries. Preserve
   normal bearer, payload and `If-Match` behaviour without retaining tokens or
   payloads in evidence. Let the real mutation finish server-side, then lose its
   HTTP response in Cypress. Aborting before execution does not test this case;
   the backend provides no fault-injection route.
4. Recover through the existing `GET /draft-casefiles/{id}` user journey. Assert
   one mutation request, the expected persisted state/version and exactly one
   expected new timeline entry. A missing response alone must not trigger a
   second mutation. The state/timeline assertions prove the mutation; send
   counts alone cannot prove it.
5. Read publication evidence with the current inputter and unchanged marker.
   Require the same observation ID/registration time and
   `evidence_complete=true`. Approval requires `1/1/0/0`; rejection, deletion and
   PUT each require `0/0/0/0`. Save this evidence before attempting cleanup.
6. After every scenario, including assertion failure, attempt DELETE for every
   captured ID using its current owner's credentials and exact current marker.
   Only 204 removes a ledger entry. Retain ID/marker and safe failure reason for
   every failed cleanup, including network failures, disabled routes and the
   pending/published 409 while `WP-CONSUMER` is outstanding. Use bounded retries
   for transient failures and report failures without turning them into a
   successful test result.

Unregistered, uncertain or unfinished evidence fails the test's evidence
precondition. So do a service upgrade during the observation interval, a producer
revision without the decorator, disabled support, or a missing broker
prerequisite. `evidence_complete=true` is necessary but cannot detect an
uninstrumented producer. A send count is not a consumer execution count or a
broker-level exactly-once guarantee. An explicit fresh approval after a failed
draft commit can legitimately send again; do not silently retry mutations to
make a response-loss assertion pass.

The journal survives service process restart and the durable CI ledger must
survive browser exit. Browser hooks cannot guarantee cleanup after a crash.
Retain the ledger for a separately authorised retry; never store bearer values
or participant payloads in it. Whole-test response loss after POST with no
captured ID remains outside this feature. There is no marker-search endpoint to
discover that unknown committed draft. Rolling back to an old producer revision
invalidates open observations even though their journal rows survive.

## Deployment, retention and outstanding prerequisites

Apply additive [V1_49](../src/main/resources/db/migration/ddl/V1_49__create_draft_casefile_publication_evidence.sql)
through the normal Flyway rollout before enabling or using the journal. It adds
`draft_casefile_test_observations` and `draft_casefile_test_send_attempts`; no
stored routines change, existing drafts are not backfilled, and the support flag
does not suppress DDL migration. Keep applied migrations immutable and use the
normal forward-fix/recovery process for schema issues.

There is no journal TTL or background sweeper. Authenticated, scoped DELETE of
an eligible draft is the retention mechanism. Monitor outstanding CI ledger
entries and journal accumulation, including unfinished observations and rows
retained by 409. Use existing `/health` and `/prometheus` monitoring without
logging markers, tokens or participant payloads. Turning the shared flag off
through the normal deployment process disables support; preserve outstanding
IDs for an authorised retry. Disabling does not restore deleted data or remove
journal rows.

Pending and published cleanup remain **Not Agent Complete**. The PO-10629 Java
consumer now takes the same pessimistic draft-row lock as cleanup, reloads the
row and no-ops when missing. Its separately transacted failure recording also
reloads and never recreates a removed draft. Consistent non-pending rows no-op;
inconsistent account identities still fail validation. The support tests prove
these Java transaction and PostgreSQL lock behaviors for eligible unlinked
cleanup, including rollback and a controlled publication-repository failure.
They do not prove actual publication SQL or complete account-graph deletion.

The selected migration tree does not define `public.p_process_draft_casefiles`.
Before expanding the 409 policy, pin the real routine/helper revisions and review
every created/read/reused table, FK and polymorphic target, respondent marker,
applicant/minor/major creditor account mapping, snapshot identities, exclusive
versus shared party/contact/debtor rows and financial records. Confirm every
writer's lock protocol for polymorphic references; a target lock plus a snapshot
absence check cannot prevent an unrelated writer inserting an untyped reference.

The complete approved-case cleanup gate still requires all six checks:

1. Pending cleanup commits first; accepted delivery and redelivery settle as
   no-ops without live rows, failure recreation, PDPL or retry/dead-letter loops.
2. Publication locks first and commits a real graph; blocked cleanup reloads and
   removes only that synthetic graph, with no live rows appearing after 204.
3. Publication rolls back while cleanup waits; pending cleanup then succeeds and
   redelivery no-ops against the removed draft.
4. Concurrent separate failure recording cannot recreate a deleted draft.
5. Duplicate and rollback checks preserve the actual four-field message,
   exception behavior and PDPL commit timing.
6. Real applicant/minor/major creditor publication is completely cleaned while
   reference Major Creditors and another case survive.

The new unlinked tests supply bounded evidence for parts of this gate; they do
not replace its pending and real-graph cases. Keep both PUBLISHING_PENDING and
PUBLISHED at 409 and retain failed cleanup ledger entries until the whole gate
passes. Queue purging or guessed graph deletion is not a substitute.

The migration's DB-03 predecessor-upgrade verification also remains unmet. The
current selected predecessor is `1.34`; the maintained task on this branch is
fresh-only. Separately delivered framework
[PR #271](https://github.com/hmcts/opal-maintenance-service/pull/271) uses
`OPAL-DB-UPGRADE` registration and
`dbUnitTestComparisonRef` / `dbUnitTestUpgradeMode`; it is not integrated here.
Database test-framework adoption, owning-suite integration and execution evidence
are required before claiming upgrade coverage. There is no runnable standalone
upgrade recipe or harness in this feature. See
[Testing](TESTING.md#synthetic-draft-casefile-cleanup) for checks and evidence
boundaries.
