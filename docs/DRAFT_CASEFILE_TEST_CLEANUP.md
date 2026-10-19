# Synthetic Draft Casefile test cleanup

For PO-10273, an explicitly enabled test-support endpoint removes an automation-owned
synthetic draft created through the real `POST /draft-casefiles` journey. Capture the
returned `draft_casefile_id`; retrieval through a GET/search API is separate backend
work. This guide does not implement Cypress or change the submission contract.

## Request and responses

This is an HTTP example with placeholders, not a command containing a real token:

```http
DELETE /testing-support/draft-casefiles/<draft_casefile_id>
Authorization: Bearer <automation-user-token>
Test-Run-Reference: <E2E-followed-by-16-lowercase-hex-characters>
```

The identifier must be a positive signed 64-bit integer. The required header is
exactly 20 characters matching `^E2E-[0-9a-f]{16}$`. There is no body or `If-Match`
requirement. The [OpenAPI contract](../src/main/resources/openapi/TestingSupport.yaml)
defines these outcomes:

| Status | Meaning and action |
| --- | --- |
| 204 | Deleted, or already absent after caller authorisation; empty response. Remove this ID from the outstanding ledger. |
| 400 | Invalid ID or missing/invalid marker; retain ID and correct the request. |
| 401 | Missing/invalid bearer authentication; retain ID and resolve authentication. |
| 403 | Caller permission/identity, persisted ownership or exact marker mismatch; retain ID and report scope failure. |
| 404 | Route is not registered when disabled; retain ID and resolve enablement through the operator process. |
| 409 | Lifecycle, validation, publication links or inconsistent snapshot metadata prevent deletion; retain ID and report. |
| 500 | Unexpected failure; transaction rolls back. Retain ID and use bounded retries. |
| 503 | Persistence temporarily unavailable; transaction rolls back. Retain ID and use bounded retries. |

Errors use existing safe OPAL Problem Details where specified by the contract.
When disabled, an authenticated request gets 404 and runtime OpenAPI omits the route.
An unauthenticated request still gets 401 under normal security. An already-absent
row is successful only after the caller has passed authentication and authorisation.

## Enablement and authentication

Cleanup defaults disabled, including in checked-in dev/staging Helm overlays. An
operator must establish the dedicated account prerequisite before enabling it.

| Variable | Default / requirement |
| --- | --- |
| `TESTING_SUPPORT_ENDPOINTS_ENABLED` | `false`; must be `true` together with the cleanup flag. |
| `DRAFT_CASEFILE_CLEANUP_ENABLED` | `false`; explicit operator opt-in only. |
| `OPAL_DEPLOYMENT_ENVIRONMENT` | Empty locally; Helm supplies deployment `global.environment`. Must be exactly `local`, `integration`, `dev`, `stg` or `staging`. |
| `DRAFT_CASEFILE_CLEANUP_BUSINESS_UNIT_ID` | Unset; positive PostgreSQL `smallint` owning Maintenance BU (1–32767). |
| `DRAFT_CASEFILE_CLEANUP_USER_ID` | Unset; positive global User Service ID reserved for synthetic automation. |
| `DRAFT_CASEFILE_CLEANUP_BUSINESS_UNIT_USER_ID` | Unset; exact BU User ID, nonblank, at most 20 characters without surrounding whitespace, matching authenticated and persisted identity. |

Requesting cleanup with empty, unknown, `prod` or `production` environment identity,
or invalid/missing owner configuration, fails startup. Environment configuration
must reflect the real deployment and is operator controlled; callers cannot select
it. Both flags must be true for controller/service registration.

Use the existing AAD/internal bearer validation and User Service integration. The
caller needs Maintenance permission **21** (`CREATE_MANAGE_DRAFT_CASEFILES`) in
the configured BU. Its authenticated global user ID and BU User ID must equal the
configured tuple before any row lookup. This feature adds no token-minting API,
credential, privilege or frontend source switch. Obtain credentials through the
existing approved authentication process and keep bearer values out of source,
command arguments, logs and cleanup ledgers.

**Required operating prerequisite:** reserve one dedicated identity exclusively
for synthetic automation and require synthetic participant data for all its
submissions. No stored field independently proves that a casefile is synthetic.
The visible run marker corroborates run scope; it is neither a secret nor proof of
synthetic content. If identity exclusivity and this policy cannot be established,
keep cleanup disabled. Provisioning and shared-environment changes require the
normal separately authorised operator process.

## Ownership, deletion and recovery

An existing draft must match the configured BU and persisted `submitted_by`, and
its `respondent_account.remo_reference` must equal the supplied marker exactly.
The marker never permits deleting a different owner's row. Older unmarked drafts
are not retroactively eligible.

Only unvalidated `SUBMITTED` drafts qualify. `account_id`, `account_number`,
`validated_date`, `validated_by` and `validated_by_name` must be null. Respondent,
applicant and minor-creditor snapshot account IDs/numbers must also be null;
malformed or inconsistent snapshot metadata is rejected. Published accounts and
reference data are retained. External personal-data processing logs are retained.

The service locks the explicitly addressed row and checks/deletes/flushes inside
one transaction. Failure rolls back; a retry of an already deleted ID returns 204
after caller checks. In the current schema, payload, participants, draft notes,
snapshot and timeline are JSON within `draft_casefiles`; deleting that row removes
them together. No table references the draft. Generic notes apply to live account
types, and the draft's `account_id` points outward to a published account. Cleanup
does not traverse that relationship. Reassess these boundaries if the schema gains
inbound draft dependants or a new publication path.

No migration, schema/routine change or deployment ordering dependency is introduced.
To disable, turn `DRAFT_CASEFILE_CLEANUP_ENABLED` off and redeploy through the normal
operator process; preserve outstanding cleanup IDs for a separately authorised
retry. Disabling does not restore data already deleted. Monitor service health and
Prometheus through the existing `/health` and `/prometheus` endpoints, and retain
non-sensitive cleanup outcomes in CI. Do not log tokens or participant payloads.

## Cypress handoff (guidance only)

When frontend work is undertaken, move the current post-assertion alias assignment
earlier: capture the real POST response ID before response or confirmation/UI
assertions can fail. Observe the real request without replacing its response.

```text
Before scenario:
  create a fresh E2E- plus 16 lowercase hexadecimal marker
  enter the marker through the existing REMO Reference UI field
  observe the real POST /draft-casefiles without substituting its response
On a successful POST response:
  capture the returned identifier immediately, before response or UI assertions
  append identifier + marker + environment + scenario/run key to a durable CI cleanup ledger
  then perform response and confirmation assertions
After scenario, including assertion failure:
  attempt DELETE for every captured identifier using the automation user's bearer and exact marker
  on 204, remove only that entry from the outstanding-cleanup ledger
  on network failure or server error, retain entry and use bounded retries
  on 400/401/403/409, retain entry and report configuration, ownership or lifecycle failure
  on 404, retain entry and report disabled/unavailable route
  never discard a failed-cleanup ID or turn cleanup failure into a false successful test run
On process crash or browser exit:
  retain the durable ledger for a separately authorised retry; browser hooks cannot guarantee execution
```

The durable ledger contains IDs and run context only, never tokens or participant
payloads. A future Node-side Cypress task/CI artifact can persist it; neither is
implemented here. A lost POST response can leave an unknown committed ID. This
endpoint cannot discover it; recovery needs a separately agreed mechanism. GET,
search and their E2E assertions remain outside this scope.

See [Testing](TESTING.md#synthetic-draft-casefile-cleanup) for focused service checks.
