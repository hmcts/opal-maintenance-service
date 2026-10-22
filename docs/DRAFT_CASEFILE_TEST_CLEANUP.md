# Synthetic Draft Casefile test cleanup

For PO-10273, an explicitly enabled test-support endpoint removes the authenticated submitter's
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
| 204 | Deleted, or already absent after authentication; empty response. Remove this ID from the outstanding ledger. |
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
row returns 204 after authentication. With no stored row, there is no business unit
or submitter against which to check permission or ownership; no data is deleted.

## Enablement and authentication

All testing-support routes use the single `TESTING_SUPPORT_ENDPOINTS_ENABLED` switch.
The application and base Helm default it to false; local standalone Compose and
existing dev/staging overlays enable it. The shared Docker stack inherits the flag
from its existing `.env.shared` file.

| Variable | Default / requirement |
| --- | --- |
| `TESTING_SUPPORT_ENDPOINTS_ENABLED` | `false` application/base Helm default; the single switch for all testing-support routes. |

Availability is controlled by the shared flag, following Fines. There is no
application-level environment allowlist. Production deployment configuration must
keep `TESTING_SUPPORT_ENDPOINTS_ENABLED=false`; the application and base Helm default
are false, while dev/staging explicitly enable it. Verify the resolved values for
each deployment, including frontend-owned Maintenance subcharts. Setting the flag
true registers test-support routes regardless of the environment's name.

No endpoint-specific identity or enablement variables are required. The previous
cleanup-specific flag, three owner variables and `OPAL_DEPLOYMENT_ENVIRONMENT` have
no effect; remove obsolete overrides during rollout.

Use the existing AAD/internal bearer validation and User Service integration. For
an existing draft, the caller needs Maintenance permission **21**
(`CREATE_MANAGE_DRAFT_CASEFILES`) in the draft's stored BU. The caller's Business
Unit User ID in that BU must match persisted `submitted_by`. The stored draft
selects the BU; a caller-supplied query parameter cannot change the check.

Tests should use synthetic data and retain their own submitted IDs and run markers.
Any appropriately authorised submitter can clean their own eligible marked draft;
there is no separately configured or reserved automation identity. The visible
run marker corroborates scenario scope, but is neither a secret nor independent
proof that data is synthetic. Use only synthetic data in test environments.

This feature adds no token-minting API, credential or frontend source switch.
Obtain credentials through the existing authentication process and keep bearer
values out of source, command arguments, logs and cleanup ledgers.

## Ownership, deletion and recovery

An existing draft's `submitted_by` must match the caller's identity in its stored BU,
and its `respondent_account.remo_reference` must equal the supplied marker exactly.
The marker never permits deleting a different owner's row. Older unmarked drafts
are not retroactively eligible.

Only unvalidated `SUBMITTED` drafts qualify. `account_id`, `account_number`,
`validated_date`, `validated_by` and `validated_by_name` must be null. Respondent,
applicant and minor-creditor snapshot account IDs/numbers must also be null;
malformed or inconsistent snapshot metadata is rejected. Published accounts and
reference data are retained. External personal-data processing logs are retained.

The service locks the explicitly addressed row and checks/deletes/flushes inside
one transaction. Failure rolls back; a retry of an already deleted ID returns 204
after authentication. In the current schema, payload, participants, draft notes,
snapshot and timeline are JSON within `draft_casefiles`; deleting that row removes
them together. No table references the draft. Generic notes apply to live account
types, and the draft's `account_id` points outward to a published account. Cleanup
does not traverse that relationship. Reassess these boundaries if the schema gains
inbound draft dependants or a new publication path.

No migration, schema/routine change or deployment ordering dependency is introduced.
To disable testing support, turn `TESTING_SUPPORT_ENDPOINTS_ENABLED` off.
Redeploy through the normal operator process; preserve outstanding cleanup IDs for
a separately authorised retry. Disabling does not restore data already deleted. Monitor service health and
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
