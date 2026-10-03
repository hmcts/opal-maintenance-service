# Get Draft Casefile

`GET /draft-casefiles/{id}` returns a stored Draft Casefile to an authenticated
Maintenance user with **21 – Create and Manage Draft Casefiles** or
**22 – Check and validate draft Casefiles** in the record's owning Business Unit.
Permission in another Business Unit does not grant access. Add still requires 21.

The response contains the complete stored `casefile`, `casefile_snapshot`,
`timeline_data`, submission and validation audit fields, status and status message.
The snapshot carries respondent, applicant and minor-creditor account IDs and
numbers; each minor creditor retains its source `creditor_sequence`. The legacy
respondent link columns are not separate top-level response fields. GET maps the
persisted data after authorisation and does not rebuild the snapshot, validate the
payload again, append timeline entries, clear validation, or update any row column.

A successful response has a quoted numeric `ETag` containing the current JPA
version, for example `"0"` after Add. The version is absent from the JSON body and
GET never increments it. Add-created rows have numeric versions. Nullable legacy
versions require a deliberate backfill before use; GET fails safely instead of
writing a version during retrieval.

Under TD.44, `casefile_status` is the persisted uppercase code, such as
`PUBLISHING_PENDING`, and `casefile_status_name` is its display label, such as
`Publishing pending`. Timeline statuses use their canonical display values and
preserve their stored order and optional `reason_text`. Audit and timeline
timestamps are returned in UTC, including fractional precision where stored.
A publishing failure's stored `status_message` is visible to the authorised user.

The endpoint uses the shared Problem Details handling and `operation_id`
correlation: 400 for invalid IDs, 401 for missing or invalid authentication, 403
for denied own-BU access, 404 for a missing draft, 406 for unsupported Accept,
503 for an unavailable database, and safe 500 for unreadable stored metadata or
an unavailable legacy version. Failed retrievals do not publish PDPO events.

## Personal Data Processing Operations (PDPO)

One metadata-only `CONSULTATION` call is attempted for each populated participant
category after the read-only service transaction commits. Related parties include
respondent debtor/third-party details, applicant third-party details and populated
UK/non-UK bank details on the applicant or minor creditors. Two minor creditors
produce one Minor Creditor call. The exact implementation mapping is:

| DTO field | Implemented value |
| --- | --- |
| `category` | `CONSULTATION` |
| `businessIdentifier` | `View Draft Casefile - Respondent` |
| `businessIdentifier` | `View Draft Casefile - Applicant / Beneficiary` |
| `businessIdentifier` when related parties are present | `View Draft Casefile - Related parties` |
| `businessIdentifier` when minor creditors are present | `View Draft Casefile - Minor Creditor` |
| `createdAt` | UTC instant captured for the authorised successful view |
| `createdBy.identifier` | Authenticated Opal user ID as a string |
| `createdBy.type` | `OPAL_USER_ID` |
| `ipAddress` | Request IP from the existing common logging utility |
| `individuals` | Exactly one entry with draft ID as a string and type `DRAFT_CASEFILE` |
| `recipient` | Absent/null |

Names, addresses, casefile/snapshot/timeline content, account numbers, bank data,
reasons and status messages are excluded. Publisher false returns and exceptions
leave the successful response and ETag unchanged and do not stop attempts for
other categories. Failure diagnostics contain only the participant category.
Uses the existing asynchronous publisher, with no new retries.

## Contract and manual verification

The implemented YAML contract is
[`DraftCasefile.yaml`](../src/main/resources/openapi/DraftCasefile.yaml), with shared
canonical objects in `Casefile.yaml` and `CommonObjects.yaml`. The
[logical API page](https://hmcts.atlassian.net/wiki/spaces/PO/pages/271484595/Get+Draft+Casefile)
is a separate documentation alignment task; this document records implemented
behaviour and does not claim that external page has been updated.

The optional Bruno request is
[`get-draft-casefile.bru`](../bruno/collections/maintenance/get-draft-casefile.bru).
Set `draftCasefileId` to the ID returned by Add in a local Bruno environment.
Keep `BEARER_TOKEN` local. No new testing-support endpoint is needed.

Bruno verification needs a compatible HTTP service, User Service, synthetic draft
and authenticated creator/checker with owning-BU permissions. Expect 200, the
complete stored response and current ETag for 21 and 22, and denied access with
no disclosed draft values for empty or other-BU permissions. Functional and smoke
checks use `TEST_URL` (default `http://localhost:4551`) and need that running service.
Implementation validation had no compatible service there, so these external
checks have not run.
The current FE has no completed GET consumer; FE verification remains pending in
an environment with that consumer. It must show complete editable/viewable fields,
preserve account links and timeline/reasons, and handle permission denial.

There is no new migration, dependency, configuration, deployment order, or Add
breaking change. Existing operational endpoints `/`, `/health` and `/prometheus`
remain public and are exercised in the same database-backed GET integration
context. No production SQL/schema contract changes require new pgTAP assertions.
