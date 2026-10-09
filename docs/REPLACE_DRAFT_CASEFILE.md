# Replace Draft Casefile — PO-10630

## Authority and delivery foundation

The approved implementation follows the captured Re-submit Casefile function
version 7 and Check & Validate TDIA version 169 from `opal-rm-agent-context`
commit `63b215e3bf075d636d7a9ca55cec84966c5cbece`. The user selected the latest
functional specification and If-Match/ETag concurrency over the older ticket's
body `version_number`. Existing logical API exports were excluded as authority;
this document and the endpoint-owned OpenAPI describe the implemented contract.

Stacked foundation: #233 (PO-10831), #235 (PO-10252), #241 (PO-10616), then #243
(PO-10620), at `1913f3edf77c59d5e64d4caa865cbefc6316b4ba`. Replacement retains
their thin controller, shared authorization, MapStruct response mapping,
`VersionedResponse<T>`, JPA versioning and after-commit logging conventions.
Deploy the predecessors first. Feature gating belongs to the separate deployment
package follow-up agreed with the user; this change adds no flag or production
configuration, dependency or migration.

## Logical model and HTTP contract

`PUT /draft-casefiles/{id}` accepts application/json with exactly two top-level
properties: positive int16 `business_unit_id` and a complete canonical `casefile`.
The body replaces the entire casefile; omitted optional content is removed.
The canonical nested Casefile schemas and existing country, application, result
and creditor reference rules apply. The stored type and owner govern validation.
Top-level type, version, snapshot, timeline, lifecycle and audit fields are rejected.

Example envelope (replace the illustrative casefile placeholder with the complete
Casefile defined in `src/main/resources/openapi/Casefile.yaml`):

```text
PUT /draft-casefiles/123
Content-Type: application/json
If-Match: "4"

{"business_unit_id":1,"casefile":<complete corrected Casefile>}
```

The positive int64 path ID and required single `If-Match` header identify the draft
and current version. The header contains quoted ASCII decimal digits in the
non-negative signed Long range, including zero and leading zeroes. Weak tags,
wildcards, multiple tags, signs, whitespace, missing quotes and overflow return
400; supplied values are not echoed. The response is the existing complete
`DraftCasefileGetResponse`, HTTP 200 and a quoted numeric ETag for the flushed,
updated version. The version is absent from the response body.

| Condition | HTTP response |
| --- | --- |
| Complete valid replacement of an authorized rejected draft | 200 and new ETag |
| Invalid ID, header, structure, nested owner/type or reference | 400 |
| Missing or invalid authentication | 401 |
| Missing stored-owner identity or create/manage permission 21 | 403 |
| Draft absent | 404 |
| Unsupported response/request media type | 406 / 415 |
| Top-level owner differs, lifecycle is not REJECTED, or stale/racing version | 409 |
| Body exceeds existing configured limit | 413 |
| Corrupt stored metadata or unexpected processing failure | 500 |
| Database unavailable | 503 |

Errors use correlated ProblemDetail responses and contain no ETag. Ownership,
lifecycle and version conflicts use `DRAFT_CASEFILE_CONFLICT` 001, 002 and 003;
a racing JPA write uses the safe `draft-casefile-version-conflict` problem type.
Authorization uses the stored Business Unit before reporting business conflicts.
Checker-only permission is insufficient. Another authorized inputter may replace
the draft; the latest submitting BU user becomes the inputter for later separation
of duties. Publication and checker approval are separate operations.

## Physical model

The existing `draft_casefiles` entity/table and V1_14 migration are unchanged.
All timestamps are UTC; the operation clock is truncated once to microseconds.

| Columns | Replacement rule |
| --- | --- |
| draft_casefile_id, business_unit_id, casefile_type, created_date | Preserve |
| casefile | Store complete corrected Casefile as PostgreSQL json |
| casefile_snapshot | Rebuild backend-owned snapshot as PostgreSQL json |
| submitted_by, submitted_by_name | Authenticated owning-BU user ID and captured display name |
| casefile_status | Existing enum value RESUBMITTED |
| casefile_status_date | Captured UTC operation time |
| timeline_data | Preserve old events and append one Resubmitted event; PostgreSQL json |
| validated_date, validated_by, validated_by_name, status_message | Preserve |
| account_id, account_number | Preserve existing linked-account fields |
| version_number | Match supplied version; JPA @Version increments on flush |

The rebuilt snapshot contains respondent and applicant display names and each
submitted Minor Creditor's name and `creditor_sequence`, in submitted array order.
Individual names use uppercase surname plus forenames when populated;
organization names remain as supplied. All snapshot account IDs/numbers are null
before publication. Minor Creditor accounts are always an array, including `[]`;
removed entries and stale names are not retained. These snapshot account fields
are distinct from the preserved table-level linked-account fields.

The timeline retains prior usernames, statuses, timestamps and rejection reasons.
The appended event uses `status=Resubmitted`, the authenticated display name and
the same captured UTC timestamp as `casefile_status_date`, with no new reason.
Unreadable stored history is a safe server failure, never a history reset.

## Transaction and logging LLD

One service-owned transaction parses the version, loads the row, authorizes its
stored owner, checks owner/state/version, validates corrected content, captures
time, maps the replacement, saves and flushes, maps the complete response, then
publishes a metadata event. The returned entity from `saveAndFlush` supplies the
new version. JPA optimistic locking protects against competing writes after the
initial comparison. Any processing or enclosing-transaction rollback restores
all fields and discards the event. The listener runs AFTER_COMMIT with fallback
execution disabled; it never runs for failure, rollback or no transaction.

The existing participant-category resolver identifies populated categories from
the corrected casefile. Employment, third-party or supplied bank details add
Related parties; any Minor Creditor adds Minor Creditor. One asynchronous
`LoggingService.personalDataAccessLogAsync` call occurs per populated category.

| PDPL field | Exact value/source |
| --- | --- |
| category | ALTERATION |
| businessIdentifier | Resubmit Draft Casefile - Respondent |
| businessIdentifier | Resubmit Draft Casefile - Applicant / Beneficiary |
| businessIdentifier | Resubmit Draft Casefile - Related parties |
| businessIdentifier | Resubmit Draft Casefile - Minor Creditor |
| createdBy | Global authenticated user ID; identifier type OPAL_USER_ID |
| individuals | Draft Casefile ID exactly once; identifier type DRAFT_CASEFILE |
| createdAt | Captured operation instant with UTC offset |
| ipAddress | Existing authenticated MaintenanceUser request-IP source |
| recipient | null |

No casefile, snapshot, timeline, names, addresses, contact, employment, bank or
status-message values enter PDPL. Listener false results/exceptions preserve the
committed response and continue subsequent category attempts. Diagnostics contain
only a fixed message and category, excluding raw publisher exception/cause values.

## Acceptance Criteria evidence

| AC | Implementation and named verification |
| --- | --- |
| AC1 corrected resubmission | `replacesRejectedDraftForOriginalOrDifferentInputter`; `resubmitsWithRegeneratedSnapshotAndPreservedHistory` |
| AC2 server-owned/immutable state | `rejectsServerOwnedReplacementProperties`; mapper preservation test; complete-row assertions in HTTP tests |
| AC3 ownership/state/version | `rejectsInvalidRequestsWithoutChangingAnyColumnOrLogging`; `rejectsEveryOtherLifecycleState`; `rejectedReplacementDoesNotPersistOrPublish` |
| AC4 Alteration PDPL | `sendsOneAlterationPerCategoryWithIdentifiersAndExactResubmissionInstant`; `resubmissionPublishesOnlyAfterCommit`; success HTTP captures |
| AC5 failure/rollback emits nothing | `mapperFailureAfterRealFlushRollsBackEveryColumnAndEmitsNoAudit`; `enclosingRollbackDiscardsTheSuccessfulReplacementAndItsAuditEvent`; HTTP negative tests |
| AC6 privacy | listener false/exception diagnostics tests; `loggingFailurePreservesHttpSuccessAndSeesCommittedReplacement` with synthetic payload/name/contact/employment/bank/history markers |
| AC7 common API handling | replacement HTTP media/header/schema/error/correlation tests and inherited POST/GET/list regression classes |
| AC8 tech decisions | real competing writers test; microsecond clock and UTC assertions; shared mappings, coded display names, correlation and after-commit PDPL |
| AC9 unit/integration tests | version/schema/validator/mapper/service/listener unit tests; replacement and transaction PostgreSQL integration classes |

Existing `draft_casefiles_pgtap_tests.sql` remains sufficient: no new table,
column, enum, constraint, routine or migration contract. Replacement behavior is
application-owned and verified against PostgreSQL by the integration tests.
No predecessor-upgrade validation is needed for an unchanged migration.

## Functional fixtures and operations

`ReplaceDraftCasefile.feature` is opt-in with `@PO10630`; `@Ignore` excludes it
from default suites requiring no prepared draft. Provide a running compatible
service (`TEST_URL`), reachable User Service (`OPAL_USER_SERVICE_API_URL`), an
approved synthetic user (`RM_DRAFT_CASEFILE_FUNCTIONAL_USER`) with permission 21
in the fixture's owning BU, and an approved synthetic rejected draft ID
(`RM_REJECTED_DRAFT_CASEFILE_ID`). These are test inputs, not production settings.
The scenarios obtain tokens through the existing helper and use bounded HTTP
timeouts; authorization headers are redacted. Never use personal customer data.

The success scenario modifies the prepared row. Its owner must reset that specific
fixture to REJECTED before a rerun; tests do not seed/reset arbitrary shared rows.
Expect current ETag → PUT 200 → GET RESUBMITTED/preserved history/new ETag →
reuse old ETag 409/unchanged draft. The unauthenticated scenario expects PUT 401.

```bash
./gradlew functionalOpal -Dcucumber.filter.tags='@PO10630' -Dcucumber.execution.dry-run=true --no-daemon
./gradlew functionalOpal -Dcucumber.filter.tags='@PO10630' --no-daemon
./gradlew functional --no-daemon
./gradlew smoke --no-daemon
```

Monitor existing health and Prometheus endpoints, replacement error rates and
safe PDPL failure messages. Replacement writes one identified row and acquires
its normal PostgreSQL update lock until transaction completion; no DDL or downtime
is introduced. Rollback the application deployment through the authorized release
process if necessary; do not undo committed drafts or alter applied migrations.
Two human approvals, applicable SQL/QA review, environment verification and release
remain separate from local agent verification. See the local delivery evidence
for executed commands and unavailable external checks.

## Local baseline verification

On 9 October 2026, Java 21.0.11 and the checked-in Gradle 9.7.1 wrapper completed
`./gradlew build --no-daemon` in 2m33s: 344 unit tests and 351 integration tests,
zero failures, errors or skips, with style and packaging checks passing.
The included disposable PostgreSQL 17.11 pgTAP run passed all 11 suites in
6410ms and confirmed cleanup. The bundled PUT contract and generated request
(Short/JsonNode) and shared GetResponse were inspected. The @PO10630 Cucumber
dry run discovered both scenarios and passed style verification; it does not
constitute live HTTP functional execution. Live functional/smoke prerequisites
were unavailable during that run. Security scan and final review evidence are
maintained in the local delivery record, not inferred from this baseline.
