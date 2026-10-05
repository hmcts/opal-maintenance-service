# Get Draft Casefiles

`GET /draft-casefiles` returns all matching dashboard summaries and their count.
The authenticated user needs **21 – Create and Manage Draft Casefiles** or
**22 – Check and validate draft Casefiles** in the requested Maintenance Business
Unit. Permission in another Business Unit does not grant access.

## Queries and responses

| Parameter | Meaning |
| --- | --- |
| `business_unit_id` | Required positive SMALLINT Business Unit ID. |
| `submitted_by` | Include drafts submitted by this captured Business Unit User ID (maximum 20 characters). |
| `not_submitted_by` | Exclude drafts submitted by this captured Business Unit User ID. |
| `casefile_status` | Comma-separated persisted lifecycle codes; any selected status matches. |
| `casefile_status_from_date` | Inclusive UTC calendar day lower bound on `casefile_status_date`. |
| `casefile_status_to_date` | Inclusive UTC calendar day upper bound on `casefile_status_date`. |
| `restrict` | Only `counts` is supported; omit for summaries. |

Supplied filters are combined with AND. Omitted filters add no restriction,
including no implicit seven-day range. Equal include/exclude submitters return
zero results. The server orders summaries by draft ID; the frontend sorts and
paginates locally. Submitter IDs are filter values, with no User Service lookup.

Normal responses contain `count` and `summaries`, including
`{"count":0,"summaries":[]}` for no matches. Normal count equals the returned list
size. `restrict=counts` returns only `{"count":N}`; it loads no snapshot or summary,
and works without parsing personal-data columns. Both modes use the same SQL
filter clause and return 200 for no matches. There is no collection ETag or
Location header.

Each summary contains draft and BU IDs, `casefile_snapshot`, case type, lifecycle
code and display name, `created_date`, `casefile_status_date`, nullable
`validated_date`, and submitter ID/name. It excludes full casefile, timeline,
status messages, validator identity and row version. Original creation remains
separate from resubmission; `validated_date` is approval, distinct from the
publication status timestamp. Timestamps use UTC and retain stored precision.
Whole-day filters use inclusive start and exclusive next-day start, including
summer dates; they do not filter by approval date.

The canonical stored snapshot supplies respondent, applicant and all minor
creditor account IDs/numbers, names and minor sequences in stored order. Links
may be null before publication. Retrieval does not rebuild snapshots, repair
journey data or modify any draft column. Selecting a draft uses the existing
`GET /draft-casefiles/{id}` for full details and the current ETag.

## Consultation logging (operation LLD)

After a nonempty normal list is mapped successfully, an immutable metadata event
is published within the read-only transaction. The existing listener sends one
asynchronous payload per populated snapshot category after commit. It deduplicates
draft IDs within each category across the complete result; a draft may appear in
several category calls. Count, empty, validation, authentication, authorisation,
query/mapping failure, rollback and outside-transaction paths send no payload.

| Logging field | Mapping |
| --- | --- |
| category | `CONSULTATION` |
| businessIdentifier | `View Draft Casefiles - Respondent`, `View Draft Casefiles - Applicant / Beneficiary`, or `View Draft Casefiles - Minor Creditor` |
| createdBy.identifier / type | Authenticated Opal user ID / `OPAL_USER_ID` |
| individuals | Relevant unique draft IDs as strings / `DRAFT_CASEFILE` |
| createdAt | Captured successful-list instant in UTC |
| ipAddress | Existing MaintenanceUser IP from the shared logging utility |
| recipient | Absent/null |

Respondent and applicant are represented in every canonical snapshot. Minor
Creditor is included when the returned minor array is populated. This maps AC4's
returned-personal-data requirement: associated-contact and bank details are not
returned, so list logging does not inspect the full casefile or add Related
parties. Add and single GET retain their existing wider category resolver.

Events and logging payloads contain only contract identifiers and metadata,
never names, snapshot values, account numbers, addresses, contact, employment,
bank data or status messages. Publisher failure preserves the successful result
and attempts later categories; application diagnostics identify only the category
and omit exception payloads.

## Errors, verification and rollout

Shared Problem Details include `operation_id`: invalid filters return 400,
missing/invalid authentication 401, denied BU access 403, unsupported Accept 406,
unavailable persistence 503 and unreadable stored data 500. Stored values and
invalid private inputs are not disclosed. Empty results are 200.

Unit and PostgreSQL 17/MockMvc integration tests cover both modes, filters,
UTC edges, published links/audit, unchanged rows, native projection types,
count-only SQL, same-BU permission isolation, signed JWT/User Service lookup,
exact grouped metadata, after-commit timing and safe failures. Existing Add and
single GET tests cover those contracts and public `/`, `/health`, `/prometheus`.
Bruno requests are `get-draft-casefiles.bru` and `count-draft-casefiles.bru`.

DB-04: the new application-owned SELECTs create or change no database-owned
object, schema, constraint, view or routine contract. Their behaviour is covered
by PostgreSQL integration. The existing
`src/dbUnitTest/draftCasefilesTest/draft_casefiles_pgtap_tests.sql` remains
sufficient for the unchanged table; `dbUnitTest` validates the existing schema.

The endpoint is additive. There are no new Flyway, dependency, configuration,
secret or deployment-order changes beyond the existing parent stack and its
User Service permissions. Standard service rollback removes the new endpoint;
listing and counting mutate no business data.

Human FE/Bruno verification requires a compatible environment, completed
dashboard consumer and synthetic creator/checker with scoped permissions. Verify
summary columns, all account links, count badges with identical filters and draft
selection through single GET; denied users must see no draft values. External
functional/smoke checks require a running service at `TEST_URL` and compatible
User Service. These external checks remain separate from the automated tests.
