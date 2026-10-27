# Testing

## Test levels

- **Unit:** `src/test/java`; run `./gradlew test`. A well-isolated unit test needs no external service.
- **Integration:** `src/integrationTest/java`; run `./gradlew integration`. These tests use a Spring context and Testcontainers PostgreSQL 17, so Docker is required for container-backed tests.
- **Functional:** `src/functionalTest/java`; run `./gradlew functional`. External HTTP checks use `TEST_URL`, defaulting to `http://localhost:4551`; they require a suitable running service.
- **Smoke:** `src/smokeTest/java`; run `./gradlew smoke`. External HTTP checks use the same `TEST_URL` default and require a running service.

## Cucumber functional tests

Cucumber and Serenity scenarios run through `functionalOpal`. Use a Cucumber
tag expression to run a focused set of scenarios:

```bash
./gradlew functionalOpal -Dcucumber.filter.tags='<tag-expression>'
```

Add `-Dcucumber.execution.dry-run=true` to validate feature and step discovery
without executing scenario actions.

External scenarios use `TEST_URL`, defaulting to `http://localhost:4551`.
Authenticated scenarios that obtain a token from User Service use
`OPAL_USER_SERVICE_API_URL`, defaulting to `http://localhost:4555`. Ensure all
required services are compatible and the target environment contains
representative data for the behavior under test.

Never put a bearer token in a tracked file or command-line argument.

### User Service access

Draft Casefile functional tests use existing test users and their assigned
Maintenance permissions. Jenkins defaults `OPAL_USER_SERVICE_API_URL` to the
shared staging User Service. These tests do not require an
`enable_opal_user_service` label, a separate User Service deployment, user or role
provisioning, or changes to User Service configuration.

The token helper calls `/testing-support/token/user` on the configured User
Service. The authorised scenario submits a synthetic casefile, captures its ID,
asserts the response and deletes it through Maintenance testing support using
the same user and run marker. Rejection scenarios use existing users and
reference data; the prerequisites below must already be satisfied.

Local runs continue to use `OPAL_USER_SERVICE_API_URL`, defaulting to
`http://localhost:4555`. A passing local run does not verify the shared staging
users, permissions or Jenkins connectivity; CI must exercise those prerequisites.
Testing support must remain disabled in production deployments.

### Draft Casefile deployed API journeys (PO-10287)

The five `@PO10287` scenario examples cover authorised creation, permission
denial, unknown application, inactive country and historical country. They
exercise the deployed Maintenance and User services in an agreed non-live
environment. Set both `TEST_URL` (Maintenance Service) and
`OPAL_USER_SERVICE_API_URL` (User Service) to the intended environment before
running either command; their localhost defaults are not suitable for deployed
verification. Do not put account passwords or bearer values in the command or
tracked files.

```bash
./gradlew functionalOpal -Dcucumber.filter.tags='@PO10287' -Dcucumber.execution.dry-run=true
./gradlew functionalOpal -Dcucumber.filter.tags='@PO10287'
```

The environment must already contain the authorised account
`opal-test@dev.platform.hmcts.net`, the account without Draft Casefile create
permission `opal-test-2@dev.platform.hmcts.net`, Business Unit 44, the
authorised user's Business Unit User ID `L044JG`, and Create and Manage Draft
Casefiles permission 21. The live reference set must include active Maintenance
Application `AP00001`, active country CJS code `1`, and result `MAT`. The
rejection cases use unknown application `ZZ99999`, inactive country CJS code
`0`, and historical country CJS code `2`. The tests never provision users or
reference data; missing or changed prerequisites are an environment-readiness
failure, not a reason to substitute mocks or create shared records.

The historical country example uses an inactive retired record, matching the
current active-flag validation.

Enable `TESTING_SUPPORT_ENDPOINTS_ENABLED=true` only in the agreed non-live
environment. A successful create is cleaned up with the merged
`DELETE /testing-support/draft-casefiles/{id}` API. Each scenario generates an
`E2E-` marker followed by 16 lowercase hexadecimal characters and sets
`casefile.respondent_account.remo_reference` to that value. Cleanup sends the
same marker in the required `Test-Run-Reference` header, accepts
`application/problem+json` as declared by the generated cleanup route, and uses the bearer token
captured when that draft was created. The ID is captured before response
assertions, so the after hook still attempts cleanup when an assertion fails.
An HTTP 204 confirms cleanup; a failed cleanup fails an otherwise passing scenario,
or attaches the ID, marker and safe failure reason to an already failed scenario.
No bearer values or response payloads are included in cleanup failure evidence.
See the [cleanup guide](DRAFT_CASEFILE_TEST_CLEANUP.md) for ownership, lifecycle,
enablement and retry requirements.

The support API also provides scoped publication-evidence registration and reads
for PO-10626; see the [support checks](#synthetic-draft-casefile-cleanup). There
is no marker-search route. These PO-10287 functional assertions check the real
POST response, including snapshot, timeline, ETag and correlated
permission/reference errors. Persistence,
rejected-request row absence and rollback are verified by `DraftCasefileDatabaseIntegrationTest` and
`DraftCasefileAuthenticationIntegrationTest`; cleanup isolation and actual row
removal are verified by `DraftCasefileCleanupIntegrationTest`. These database
assertions are integration coverage, not deployed functional evidence.

Server-error mapping and transaction rollback are verified by the controller and
database integration suites using persistence failures. The deployed functional
scenarios do not inject server failures or claim deployed rollback coverage.

The ticket's acceptance criteria are covered as follows:

| Acceptance criterion | Deployed functional coverage | Supporting integration coverage |
| --- | --- | --- |
| Create a submitted Draft Casefile with backend identity, submitter, snapshot and timeline | Authorised create example checks the POST response | `createsCommittedDraftWithUnchangedJsonDerivedDataAndAfterCommitLogs` verifies the committed row and derived JSON |
| Reject creation without Business Unit permission | Permission-denied example | `DraftCasefileAuthenticationIntegrationTest` verifies denied creation leaves no row |
| Reject unknown, inactive or out-of-date references | Unknown application, inactive country and historical country examples | `rejectsBadReferenceWithoutRowOrLog` verifies rejected validation leaves no row; validator tests cover reference rules |
| Return a correlated failure without retaining a partial Draft Casefile, snapshot or timeline | No deployed failure injection | `rollsBackSavedRowWhenPersistenceFails` verifies correlated 500/503 problems, absent success fields, row rollback and no publication in the same request |

Snapshot and timeline data are stored in the draft row, so verifying that no draft
row remains also verifies that no partial snapshot or timeline was retained.
The failure criterion is integration evidence, not a sixth deployed functional
example.

Run the functional helper regression tests without a Cucumber tag property.
Cucumber also discovers its suite during filtered runs, so use dry-run mode to
disable scenario actions while the JUnit helper tests execute normally:

```bash
./gradlew functionalOpal --tests 'uk.gov.hmcts.opal.*.DraftCasefile*Test' -Dcucumber.execution.dry-run=true
```

### Draft Casefile retrieval journeys (PO-10618)

`GetDraftCasefile.feature` contains exactly five journeys, tagged `@Opal`,
`@PO10618` and `@JIRA-STORY:PO-10618`:

| Acceptance criterion | Scenario and observable evidence |
| --- | --- |
| Retrieve a complete authorised Draft Casefile | Complete submitted casefile matches the POST baseline and submitted JSON, with backend metadata, explicit null account identities, snapshot names, timeline and strong ETag |
| Retrieve generated account identities after publication | Real `PUBLISHED` state retains approval history and top-level `validated_date`; respondent, applicant and minor creditors 7 and 23 have identities, with distinct creditor IDs and numbers |
| Retrieve failed publication without invented identities | Real `PUBLISHING_FAILED` state preserves validation and approval history, retains explicit null identities, and has a nonblank status message |
| Protect a missing Draft Casefile | Owner deletes its newly created draft before GET of the same ID returns a safe, correlated 404 problem |
| Protect a draft outside the reader's Business Units | Existing reader without either owning Business Unit permission gets a safe, correlated 403 problem, rather than 401 |

Each scenario POSTs its own synthetic draft with a fresh `E2E-` marker. No draft
ID is supplied through environment configuration, SQL setup or shared records.
The creator token and positive numeric Long ID are captured before later setup
or response assertions. Every captured ID is deleted in the `@PO10618` after
hook using the creator's token and marker, including after failed setup,
approval, polling or assertions. The missing-resource scenario repeats the
scoped DELETE safely. A 204 confirms cleanup. Any other status, including 409,
or a transport error fails a passing scenario; an already failed scenario keeps
its primary failure and receives separate safe cleanup evidence. An ambiguous
create with no recoverable ID reports an unknown-owned-create limitation and
marker for operator follow-up, without guessing an ID or replaying the POST.
A POST that returns any non-201 status retains unknown ownership and its
submitted marker until operator follow-up. HTTP error status alone does not
prove that no creation committed. Setup still fails; no POST is replayed and no
DELETE is attempted without a captured ID.

Before either publication setup approves a draft, its authoritative submitted
GET must match the complete original request and POST metadata. The helper
regressions reject consistent loss of either or both submitted minor creditors
before any checker PATCH; valid successful and failed publication setup remains
covered separately.

The standard existing identities are `opal-test@dev.platform.hmcts.net`
(inputter), `opal-test-10@dev.platform.hmcts.net` (different checker), and
`opal-test-2@dev.platform.hmcts.net` (denied reader). Optional overrides are
`RM_DRAFT_CASEFILE_INPUTTER_USER`, `RM_DRAFT_CASEFILE_CHECKER_USER` and
`RM_DRAFT_CASEFILE_DENIED_USER`. These users must already exist. The inputter
needs permission 21 in Business Unit 44; the different checker needs permission
22 there (the standard checker also has 21). The denied reader must have
neither permission 21 nor 22 for that Business Unit. Tests obtain real tokens
from User Service, require distinct submitter and validator identities, and
assert actual HTTP outcomes; they never provision accounts or roles. Missing
users or incompatible permissions fail the journey rather than skip it.

Use a compatible Maintenance deployment and User Service, the active
`AP00001` application, active country CJS code `1`, and result `MAT` baseline.
Enable testing support only in the agreed non-live environment. Publication
requires the real broker, running consumer and database provider
`public.p_process_draft_casefiles`. The failed-publication fixture supplies a
nonnumeric `Amount` (`not-an-amount`) accepted by draft creation, then requires
the real failed publication state. The successful-publication scenario requires
`PUBLISHED`: `PUBLISHING_FAILED` and deadline expiry remain failures. Missing
provider delivery is expected to leave these checks red; there are no skipped,
inverted or placeholder assertions. Cleanup of `PUBLISHED` and
`PUBLISHING_PENDING` drafts currently returning 409 is a separate unmet
support-API dependency and is not automatically fixed by merging the database
provider. These tests do not bypass that lifecycle restriction.

Polling allows 60 seconds with 500 ms intervals, blocks new reads and late
acceptance after the deadline, and fails on an unexpected lifecycle state. An
in-flight HTTP GET still uses the existing 10-second connection and 30-second
socket timeouts; this is not a cancellable hard 60-second wall-clock limit.

Run helper/glue regressions without a Cucumber tag property (a tag property
selects only the Cucumber runner). JUnit checks execute normally while Cucumber
actions are disabled:

```bash
./gradlew functionalOpal --tests 'uk.gov.hmcts.opal.*.DraftCasefile*Test' --tests 'uk.gov.hmcts.opal.steps.GetDraftCasefileStepDefTest' -Dcucumber.execution.dry-run=true
./gradlew checkstyleFunctionalTest
```

Discovery must find exactly five PO-10618 scenarios without undefined or
ambiguous steps. It does not prove live API behavior:

```bash
./gradlew functionalOpal -Dcucumber.filter.tags=@PO10618 -Dcucumber.execution.dry-run=true
```

For live verification, set `TEST_URL` and `OPAL_USER_SERVICE_API_URL` to the
intended non-live environment, confirm the prerequisites above, then run:

```bash
./gradlew functionalOpal -Dcucumber.filter.tags=@PO10618
```

Record helper JUnit counts separately from five-scenario discovery and live
results. Preserve non-sensitive retained draft IDs, markers, cleanup statuses
and timings from reports before the next Gradle invocation clears functional
reports. Never retain bearer tokens, request/response bodies or participant data
in error messages, report attachments or handoff evidence. A local runtime of
unknown source revision does not establish live verification of the branch.

### Draft Casefile list journeys (PO-10619)

`draftCasefiles/list/GetDraftCasefiles.feature` contains exactly seven independent
journeys tagged `@Opal`, `@PO10619` and `@JIRA-STORY:PO-10619`:

1. Filter summaries by owning Business Unit, submitter inclusion and exclusion,
   reviewable lifecycle and inclusive UTC status dates, with owned positives and negatives.
2. Count rejected work with the same normal-list filters and no summaries in the counts response.
3. Count real failed-publication work with the same filters and no summaries in the counts response.
4. Let the checker review another user's submission while excluding their own.
5. Return count zero and an empty array for an authorised contradictory filter.
6. Pair a real published summary with full GET, including respondent, applicant
   and two minor-creditor identities, validation and unchanged approval history.
7. Independently pair a real failed summary with full GET, explicit null identities,
   validation and unchanged approval history.

The split follows the Fines approach: deployed HTTP journeys demonstrate user
workflows; database integration checks prove boundaries, logging and controlled
edge cases. Synthetic HTTP glue regressions prove scenario wiring and assertions,
not deployment behaviour. The counts logging evidence is zero calls to a mocked
`LoggingService` after the completed HTTP transaction; it does not observe a
deployed downstream logging sink. Historical dates, foreign Business Units and
two rejected submitters are controlled integration-fixture proof, not deployed
setup or authority. Coverage is mapped explicitly:

| Acceptance criterion | Live journey evidence | Supporting integration evidence |
| --- | --- | --- |
| AC1: owning unit and combined filters | Journey 1 checks every returned row and owned positive/negative IDs | Foreign Business Unit isolation |
| AC2: counts restriction | Journeys 2 and 3 compare counts with matching normal-list totals and require count-only responses | Counts path performs no personal-data-access logging |
| AC3: checker review work | Journey 4 excludes the actual checker submitter identity | Submitter exclusion filtering |
| AC4: rejected work visibility | Rejected owned fixture supports journeys 1 and 2 | Two rejected submissions and foreign-unit isolation |
| AC5: authorised empty collection | Journey 5 uses contradictory filters for an actual owned submitter | Empty envelope contract |
| AC6: date boundaries | Journey 1 uses a UTC day derived from the POST timestamp | Both inclusive seven-day boundaries, immediately before/after them, and an old rejected draft with unbounded listing |
| AC7: publication summaries | Journeys 6 and 7 pair terminal lists with complete GET assertions | Supporting projection and snapshot coverage |

Each run owns every fixture it creates; the two failed-publication journeys use
separate new drafts. Each POST receives its own fresh `E2E-` marker, and positive
Long IDs are captured before later metadata assertions. Filters derive Business
Unit User IDs from actual POST `submitted_by`, rather than guessing seeded IDs.
The default inputter is `opal-test@dev.platform.hmcts.net`; the different checker
and second creator is `opal-test-10@dev.platform.hmcts.net`. Optional overrides
are `RM_DRAFT_CASEFILE_INPUTTER_USER` and `RM_DRAFT_CASEFILE_CHECKER_USER`.
Both need create permission 21 for Business Unit 44, and the checker also needs
check/validate permission 22. Distinct configured users and, where both POSTs
are available, distinct Business Unit User IDs are required. No users or roles
are provisioned by these tests.

Use the PO-10618 reference-data prerequisites, compatible Maintenance and User
services, and non-live testing support. Real approval requires a working broker,
consumer and database provider `public.p_process_draft_casefiles`. The complete
fixture has two minor creditors; the failed fixture uses `not-an-amount` and must
actually reach `PUBLISHING_FAILED`. Polling uses the same strict 60-second deadline
and 500 ms interval as PO-10618. Unexpected states, missing provider delivery and
deadline expiry fail; no alternative state, integration fixture or skip substitutes
for a real terminal outcome. An unknown local image source revision does not
establish live verification of the branch.

Cleanup attempts every captured draft using its original creator token and marker,
even after earlier 409 responses or request exceptions. Only 204 confirms cleanup.
A passing journey fails when cleanup fails; an already failed journey keeps its
primary failure and receives a safe retained-resource ledger of IDs, markers and
statuses. Ambiguous POSTs retain a marker for operator follow-up, never retry or
guess an ID. Credentials are cleared after the hook, including attachment failure.
Every non-201 create response retains that fixture's unknown ownership and marker
for operator follow-up. The after hook still attempts all other captured drafts.
No POST is replayed and unknown IDs are never guessed for cleanup.
Known support-API restrictions return 409 for `PUBLISHED` and `PUBLISHING_PENDING`;
these are unresolved cleanup dependencies, not permission to bypass guards, delete
database rows, rewrite lifecycle or purge queues. Shared pending drafts are never
reused or altered. Preserve the safe ledger before another functional invocation
clears its reports; never retain tokens, request/response payloads or participant data.

Run actual helper/glue JUnit checks without a Cucumber tag property:

```bash
./gradlew functionalOpal --tests 'uk.gov.hmcts.opal.*.DraftCasefile*Test' --tests 'uk.gov.hmcts.opal.steps.GetDraftCasefileStepDefTest' --tests 'uk.gov.hmcts.opal.steps.ListDraftCasefilesStepDefTest' -Dcucumber.execution.dry-run=true
./gradlew checkstyleFunctionalTest
```

Discovery must find exactly seven PO-10619 scenarios, with no undefined or
ambiguous steps. Discovery does not execute scenario actions:

```bash
./gradlew functionalOpal -Dcucumber.filter.tags=@PO10619 -Dcucumber.execution.dry-run=true
```

For actual live verification, set `TEST_URL` and `OPAL_USER_SERVICE_API_URL` to the
intended non-live environment and satisfy the prerequisites above:

```bash
./gradlew functionalOpal -Dcucumber.filter.tags=@PO10619
```

Record actual JUnit counts, seven-scenario discovery and live results separately.
Normal lists can contain other legitimate matching drafts in the shared unit:
assert owned inclusion/exclusion and every row's filters, with count equal to
summary length, rather than asserting that the total equals owned fixture count.

### Independent checker decision journeys (PO-10617)

`draftCasefiles/update/UpdateDraftCasefile.feature` contains exactly ten journeys,
tagged `@Opal`, `@PO10617` and `@JIRA-STORY:PO-10617`. Dedicated
`RecordCheckerDecisionsStepDef` glue preserves the older PO-10631 fixture-based
feature and its bindings.

| Journey | Source and decision | Expected evidence |
| --- | --- | --- |
| 1 | SUBMITTED / Approve | HTTP 200 approval, server-owned validation and history, persisted GET, one acknowledged producer send |
| 2 | SUBMITTED / Reject | HTTP 200 rejection with exact reason and history, identical persisted GET, complete zero producer sends |
| 3 | SUBMITTED / Delete | HTTP 200 logical deletion with exact reason and history, identical persisted GET, complete zero producer sends |
| 4 | RESUBMITTED / Approve | Corrected full baseline, approval and persisted metadata/history, one acknowledged producer send |
| 5 | RESUBMITTED / Reject | Corrected full baseline, rejection and persisted history, complete zero producer sends |
| 6 | RESUBMITTED / Delete | Corrected full baseline, logical deletion and persisted history, complete zero producer sends |
| 7 | Checker approves their own submission | Safe correlated 403, entire draft and ETag unchanged, complete zero producer sends |
| 8 | Caller lacks owning Business Unit permission 22 | Safe correlated 403, entire draft and ETag unchanged, complete zero producer sends |
| 9 | Independent checker uses obsolete original version 0 against eligible RESUBMITTED version 2 | Safe optimistic-locking 409, entire corrected draft and ETag unchanged, complete zero producer sends |
| 10 | Independent checker approves current REJECTED version 1 | Safe resource-conflict 409, entire rejected draft and ETag unchanged, complete zero producer sends |

Each scenario creates a complete synthetic draft with its own fresh `E2E-`
marker followed by 16 lowercase hexadecimal characters, including minor
creditors 7 and 23. The original POST request and response are checked against
an authoritative version-zero GET before any setup decision. This catches
consistent POST/GET content loss. RESUBMITTED setup performs a real checker
rejection with exact actor/history and persisted readback, followed by the
original owner's PUT using the current ETag. That PUT contains exactly
`business_unit_id` and the full corrected `casefile`, retaining the marker and
both minor creditors and changing respondent `forenames` to
`SyntheticCorrected`. Its response and authoritative version-two GET must
retain the corrected content, snapshot, metadata and complete history. These
journeys never reuse previous-ticket IDs or assume that a RESUBMITTED draft
still matches its original submitted content.

Configure `TEST_URL` and `OPAL_USER_SERVICE_API_URL` for the intended non-live
Maintenance and User Service deployments. Use the active `AP00001` application,
active country CJS code `1`, result `MAT`, Business Unit 44, enabled scoped
cleanup and publication-evidence support, and a configured real publisher.
The service must include the PO-10626 publication-evidence routes and compatible
synchronous producer instrumentation. Missing routes, unavailable dependencies,
non-JSON responses, incomplete observations and unknown runtime compatibility
fail strictly; an HTTP 200 alone is insufficient.

The existing default users are `opal-test@dev.platform.hmcts.net` (inputter),
`opal-test-10@dev.platform.hmcts.net` (checker), and
`opal-test-2@dev.platform.hmcts.net` (denied caller). Optional overrides are
`RM_DRAFT_CASEFILE_INPUTTER_USER`, `RM_DRAFT_CASEFILE_CHECKER_USER` and
`RM_DRAFT_CASEFILE_DENIED_USER`. Inputters need owning-unit permission 21;
checkers need 22, and the self-check creator needs both 21 and 22. Every scenario
resolves the actual checker through User Service `/v2/users/0/state`: a nonblank
`name`, exactly one numeric Business Unit 44 entry in
`domains.maintenance.business_unit_users`, a nonblank `business_unit_user_id`,
and numeric `permissions[].permission_id` establish the expected actor.
Independence is checked against actual POST `submitted_by`; different display
names are not required. The denied caller's state must lack owning-unit
permission 22. A valid `domains` object with no `maintenance` property establishes
that absence for the denied caller, including the standard denied user's
`domains: {}` state. Missing or malformed `domains`, present null or malformed
`maintenance`, malformed permissions and ambiguous owning-unit entries fail
setup; a checker still requires its owning-unit array and permissions. Tests do
not create users or alter permissions, and actor data, tokens and user-state
bodies must not enter retained evidence.

All `DraftCasefileActions` requests use configured plain RestAssured transport,
preventing Serenity from retaining response or error payloads containing actual
actor identities or User Service state. Existing connection/read timeouts,
authentication/header safeguards and request contracts are preserved. Assertions
and the safe cleanup ledger still establish outcomes; unrelated tests retain
their existing reporting behavior.

After all setup and actor preconditions, the original owner registers a scoped
publication observation with the draft ID and marker. Registration requires
HTTP 201, UUID/time identity and complete zero counts, then a full GET proves
that registration preserved the baseline and ETag. The tested PATCH executes
once with its explicit actor, ETag and Business Unit 44 decision body. Reject
and Delete require the exact synthetic reason. Approval requires a strong ETag
that numerically advances and a full persisted readback. That readback may be
`PUBLISHING_PENDING`, or valid fast `PUBLISHED` / `PUBLISHING_FAILED` retaining
approval metadata/history. No consumer stop, polling or sleep window is
required. Producer and journal completion are synchronous with the decision.
The original owner then reads the same observation: approval requires exact
attempt/acknowledged/uncertain/unfinished counts `1/1/0/0`; all other paths
require `0/0/0/0`, always complete. Journal identity and registration time must
match. A producer acknowledgement is not durable broker proof, exactly-once
delivery or global absence of unrelated messages.

| Acceptance criterion | Live journeys | Supporting evidence |
| --- | --- | --- |
| AC1: independent approval and publication | Journeys 1 and 4 verify response, persisted metadata/history and scoped producer acknowledgement | `DraftCasefileCheckerQaIntegrationTest` covers HTTP/persistence and controlled failures; opt-in `DraftCasefileQueueIntegrationTest` supplies real persistent broker acceptance proof |
| AC2: reject and delete without publication | Journeys 2, 3, 5 and 6 verify exact decision/history/readback and scoped zero evidence | Checker integration coverage verifies no publisher call and persisted state |
| AC3: protect invalid decisions and preserve the draft | Journeys 7–10 verify safe 403/409, complete unchanged bodies/ETags and scoped zero evidence | Checker integration coverage includes actual local AMQP failure, whole-transaction rollback and uncertain producer evidence |

The maintained integration selection has eighty checks: eleven in
`DraftCasefileCheckerQaIntegrationTest`, twenty-seven in
`DraftCasefileDecisionIntegrationTest`, and forty-two in
`PublicationEvidenceIntegrationTest`. Local controlled AMQP failure and
transaction rollback are integration evidence, without deployed fault injection. The actual publication message has four fields (draft ID,
checker user ID, originating IP and approval timestamp); the older ID-only
physical description has drifted. This journey change does not edit the API
specification.

Durable broker proof remains the existing opt-in dedicated-queue suite described
below. It requires an otherwise unused `test-` queue, `RUN_SERVICE_BUS_TESTS=true`,
`TEST_SERVICEBUS_QUEUE`, and normal Service Bus connection environment settings.
Consumer tests additionally require `TEST_SERVICEBUS_MAX_DELIVERIES` matching
the provisioned queue. No safely configured queue is currently available, so
these checks must not be reported as passed or replaced by the producer journal.

Cleanup always uses the original creator token, owned positive ID and marker,
including after setup, evidence or assertion failures. Only HTTP 204 confirms
cleanup. Unknown or malformed create outcomes retain a safe marker ledger;
ambiguous POST/PUT/PATCH operations are never replayed. Cleanup failure fails an
otherwise green scenario or attaches separate safe evidence when a primary
failure already exists. Attachment failure is surfaced safely, and all scenario
credentials/state are cleared in `finally`. Existing deployed cleanup 409s for
`REJECTED` / `PUBLISHING_PENDING` remain unresolved runtime dependencies with an
unproven outside cause; no direct database deletion, lifecycle rewrite, shared
queue purge or service restart bypasses them. Retain only safe IDs, markers,
statuses and timings before the next functional invocation replaces reports.

Run actual Java helper/glue regressions without a Cucumber tag property:

```bash
./gradlew functionalOpal --tests 'uk.gov.hmcts.opal.*.DraftCasefile*Test' --tests 'uk.gov.hmcts.opal.assertions.PublicationEvidenceAssertionsTest' --tests 'uk.gov.hmcts.opal.steps.GetDraftCasefileStepDefTest' --tests 'uk.gov.hmcts.opal.steps.ListDraftCasefilesStepDefTest' --tests 'uk.gov.hmcts.opal.steps.RecordCheckerDecisionsStepDefTest' -Dcucumber.execution.dry-run=true
./gradlew checkstyleFunctionalTest
```

Count only Java `uk.gov.hmcts.opal` JUnit XML in
`build/test-results/functional/opal`, and preserve those counts before discovery
replaces reports. Selected discovery must find exactly ten scenarios with no
undefined or ambiguous steps:

```bash
./gradlew functionalOpal -Dcucumber.filter.tags=@PO10617 -Dcucumber.execution.dry-run=true
```

With all prerequisites satisfied, run the ten actual live journeys:

```bash
./gradlew functionalOpal -Dcucumber.filter.tags=@PO10617
```

Record actual Java JUnit, ten-scenario discovery and live results separately.
Compilation, dry-run discovery, skipped checks and mocked action-boundary glue
regressions do not establish live functional coverage. A local runtime of
unknown source revision does not verify this branch.

## Draft Casefile publication tests

The normal integration suite tests HTTP decisions and PostgreSQL transaction
boundaries with a controlled publisher. To test real broker acceptance, provision
an otherwise unused queue with a `test-` prefix and set `RUN_SERVICE_BUS_TESTS=true`
and `TEST_SERVICEBUS_QUEUE` to that queue's name. Supply the normal Service Bus
connection settings. For a disposable emulator exposed on a mapped port,
`TEST_SERVICEBUS_AMQP_URI` overrides the test connection URI (no credentials in the URI).

```bash
./gradlew integration --tests '*DraftCasefileQueueIntegrationTest'
```

These tests stop the application listener and consume their synthetic messages
from the dedicated queue. `DraftCasefileQueueConsumerIntegrationTest` starts its
own correlation-filtered listener and also requires
`TEST_SERVICEBUS_MAX_DELIVERIES` to match the provisioned dead-letter limit.
Its missing-draft test runs with support enabled and verifies that the real JMS
callback has no ambient Spring database transaction or synchronization before
entering guarded processing. They prove
persistent four-field publication (draft ID, checker user ID, originating IP and approval timestamp), bounded connection failure, and that an accepted
message survives a later database rollback without successful-decision logging.
Do not point them at an application queue. Remove the test queue or disposable
emulator after the run; keep credentials out of files and command arguments.

The opt-in `@PO10631` functional scenarios require `RM_DRAFT_CASEFILE_CHECKER_USER`
and separate submitted synthetic drafts identified by
`RM_CHECKER_DRAFT_ID_PUBLISHING_PENDING`, `RM_CHECKER_DRAFT_ID_REJECTED`,
`RM_CHECKER_DRAFT_ID_DELETED` and `RM_CHECKER_SELF_DRAFT_ID`. The first three must
have a different submitter; the last must belong to the checker. Run against a
configured service with a broker and with the publication consumer stopped, then
reset the synthetic fixtures before rerunning. Do not use personal or live data.

## Database migration validation

Normal Docker Compose use is a persistent local-development workflow.
`docker compose down` removes its containers and network but intentionally
preserves the named PostgreSQL volume, so a later start can reuse an already
migrated database. That behaviour is not fresh-database validation.

> **Destructive:** `docker compose down --volumes` deletes the developer-owned
> named volume and its local database data. Do not use it as a routine database
> validation step.

### DB-01 suite semantics

The canonical database-owned entry point is `./gradlew dbUnitTest`. It is
independent of Spring, JUnit, and backend integration-test fixtures. Docker is
a prerequisite because the task owns the lifecycle of disposable PostgreSQL
17 and Flyway containers. The target, migration, assertion, and cleanup rules
belong to the
[DB-01 migration-safety contract](DATABASE_MIGRATIONS.md#db-01-fresh-database-contract).

Existing backend integration tests may incidentally apply migrations while
starting Spring Boot, but they are not database migration validation. The
normal `check` lifecycle runs `dbUnitTest` and `integration` as peer suites;
neither task invokes or owns the other.

Any migration, validation, assertion, safety, or cleanup failure must fail the
`dbUnitTest` task and its dedicated report. Capture non-sensitive evidence
for the PostgreSQL and Flyway versions, selected migration locations, initial
and final state, migrations applied, assertions executed, timings, and
confirmed cleanup. Evidence must not contain production data, PII, secrets,
credentials, or reusable connection details.

### DB-04 pgTAP test placement

New DB-04 migration-specific suites live directly under `src/dbUnitTest`,
named for the maintained database object and run by the
[DB-01 database-owned suite](#db-01-suite-semantics). Keep the
migration and ticket association in the test metadata or handoff rather than
using a ticket-specific directory. The checks must use direct PostgreSQL
boundary evidence rather than Spring, backend repositories, or backend
integration-test fixtures. Existing backend integration tests and their
ownership remain unchanged.

Every migration that creates or changes an observable database contract must
create or update a pgTAP suite named `<object>_pgtap_tests.sql`. If an existing
suite already covers the changed contract without modification, identify that
suite and explain why its assertions remain sufficient. If no direct boundary
assertion is required, use the DB-04 exception wording and record its reason.

Each migration-focused specification must state whether its assertions apply
to the fresh DB-01 path, the DB-03 upgrade path, or both. The current
`dbUnitTest` task executes the fresh DB-01 path. The separate
[DB-03 framework PR #271](https://github.com/hmcts/opal-maintenance-service/pull/271)
is not integrated into this branch. It uses `OPAL-DB-UPGRADE` registration and
`dbUnitTestComparisonRef` / `dbUnitTestUpgradeMode`; these are not currently
executable interfaces here. Framework adoption, integration into each owning
suite and executed consumer evidence must precede an upgrade-coverage claim.
Until then, an applicable upgrade-path requirement remains unmet and must be
reported rather than claimed as verified. Representative upgrade setup and
synthetic data rules remain owned by the
[planned DB-03 guidance](DATABASE_MIGRATIONS.md#planned-db-03-upgrade-path-validation).

Select assertions from the migration-specific categories in the
[DB-04 database contract](DATABASE_MIGRATIONS.md#db-04-migration-specific-boundary-contract)
without copying that catalogue here. Follow the current
[DB-10 pgTAP execution contract](#db-10-pgtap-execution) for reusable assertion
mechanics and patterns, command-failing output, and the common evidence format.

### Planned DB-06 procedure-side testing

New stored-procedure suites live directly under `src/dbUnitTest`, named for
the maintained procedure and run by the
[DB-01 database-owned suite](#db-01-suite-semantics). Keep the
migration and ticket association in the test metadata or handoff. Call the
procedure directly through PostgreSQL rather than through Spring, a backend
repository, or a backend integration-test fixture. Use the DB-03 path for
applicable predecessor state and approved row-dependent scenarios, and align
the checks with the migration's DB-04 assertion declaration.

For each applicable procedure contract, prove the relevant procedure-side
outcomes:

- Successful results and declared database side effects.
- Exception propagation, including the expected SQLSTATE or error behaviour.
- The declared affected-row scope.
- Repeat-call and idempotency behaviour where applicable.
- Participation in caller-controlled rollback and atomicity at the declared
  boundary.
- When run-status behaviour is relevant, that the procedure does not
  independently create or update run-status records.

The database procedure/backend ownership contract is defined in
[Database Migrations](DATABASE_MIGRATIONS.md#planned-db-06-stored-procedure-responsibility-contract).
Backend transaction and run-status orchestration tests remain outside
`dbUnitTest` and must be tracked separately when required; backend test
ownership is unchanged. DB-10 owns reusable assertion mechanics,
command-failing output, and evidence formatting rather than DB-06 duplicating
them here.

## Baseline and focused commands

`./gradlew build` is the baseline validation for source, build, and runtime
configuration changes. In this repository, `check` depends on `dbUnitTest`
and `integration` as peer suites.
Run focused tests with `./gradlew test --tests 'fully.qualified.Pattern'` or
`./gradlew integration --tests 'fully.qualified.Pattern'`. Focused quality
commands are `./gradlew checkstyleMain` and `./gradlew jacocoTestReport`.
PMD is not configured in the current build. For documentation-only or similarly
non-executable changes, run checks appropriate to the changed artefacts and
record why the baseline build was not run.

## Synthetic Draft Casefile cleanup

The [support guide](DRAFT_CASEFILE_TEST_CLEANUP.md) defines the shared default-off
flag, permission 21/current-inputter/exact-marker scope, HTTP contracts, and the
Cypress response-loss/CI-ledger sequence. All evidence must be captured before
DELETE removes the journal. Service checks use synthetic data in disposable
PostgreSQL 17 and signed JWT/local WireMock fixtures; no shared service or real
account is required for those automated checks. Real broker checks require the
isolated queue prerequisites [above](#draft-casefile-publication-tests).

```bash
./gradlew test --tests '*DraftCasefileAdmission*' --tests '*DraftCasefileCleanup*' --tests '*PublicationEvidence*' --tests '*ObservedDraftCasefileQueuePublisherTest'
./gradlew integration --tests '*DraftCasefileCleanup*' --tests '*DisabledDraftCasefileCleanup*' --tests '*PublicationEvidence*'
./gradlew processResources openApiGenerate compileJava --no-daemon
./gradlew test --tests '*OpenApiSchemaValidatorTest' --tests '*OpenApiRequestBodyAdviceTest'
./gradlew build --no-daemon
./gradlew jacocoTestReport
```

The response-only `PublicationEvidence` schema in `TestingSupport.yaml` generates
one `TestingSupportPublicationEvidence` model. Verify UUID `observation_id`,
offset date-time `registered_at`, nonnegative int64 counts (generated `Long`)
and boolean `evidence_complete`, with exactly seven response fields. Follow
[OpenAPI verification](OPENAPI_GUIDELINES.md#verification): inspect internal refs
and unique component names in `build/openapi-bundled.yaml`, generated getters and
types, and byte equality with `build/resources/main/openapi-bundled.yaml`.
Validation uses the packaged bundle; no separate validation-schema generation
task is required. Runtime OpenAPI tests must expose both authenticated evidence
operations only when support is enabled. Generation/compilation alone does not
prove runtime validation or security.

| Requirement | Automated service/database evidence | Consumer/deployed evidence still required |
| --- | --- | --- |
| Register once and read stable evidence without sending | `PublicationEvidenceIntegrationTest` checks 201 first/200 repeat, same observation/time, seven fields, lifecycle eligibility and no reset after approval | Frontend registers before the real mutation and retains the observation ID |
| Current BU permission 21, latest inputter and both draft/observation markers | `PublicationEvidenceAuthenticationIntegrationTest` uses signed JWT/User Service fixtures; `PublicationEvidenceIntegrationTest` covers scope denial and actual PUT handover | Environment credentials must resolve the current inputter; checker actions retain inputter ownership |
| Observe exactly one real producer invocation | `ObservedDraftCasefileQueuePublisherTest` checks delegation/ordering/failure; `PublicationEvidenceIntegrationTest` checks actual approval, non-approval, outer rollback and no automatic replay; `DraftCasefileQueueIntegrationTest` checks a dedicated real broker | Cypress captures every PATCH/PUT, loses the response after server-side completion, recovers with the existing GET journey, and asserts one mutation/one expected timeline entry |
| Complete, correctly scoped response-loss evidence | API tests cover acknowledged, uncertain and unfinished outcomes; `PublicationEvidenceRepositoryIntegrationTest` and `PublicationEvidenceWriterIntegrationTest` cover durable counters and independent transactions | Same observation, `evidence_complete=true`, approval counts `1/1/0/0` or reject/delete/PUT `0/0/0/0`; no service upgrade or undecorated producer during the interval |
| Consistent evidence during cleanup | `PublicationEvidenceConcurrencyIntegrationTest` pauses GET after the real observation lookup, commits DELETE, then verifies the original uncertain/unfinished snapshot | Capture and retain evidence before initiating cleanup |
| Bounded support-enabled approval concurrency | The same suite holds 9 real outer transactions in the configured pool of 10, proves an additional approval, processing and failure-recording caller all wait before transaction/connection acquisition, and checks scoped durable outcomes after success or failure; it repeats the queue check during transaction completion and verifies advice order and ambient-transaction rejection | Every replica uses the instrumented revision and fixed configured pool size; processing and failure-recording callers share the same admission; additional direct writers must reconcile their protocol |
| Atomic eligible cleanup and safe retries | `DraftCasefileCleanupIntegrationTest` covers POST-ID-to-DELETE, scope, lifecycle, embedded-data deletion, sibling/reference retention, rollback, repeats and PostgreSQL lock contention; `PublicationEvidenceIntegrationTest` covers journal/attempt rollback, old-marker cleanup after current-owner PUT, and orphan retention | Durable ID/marker/environment/scenario ledger; remove entries only after 204 and retain every failed cleanup |
| Default-off/disabled security and operational endpoints | Cleanup availability and disabled HTTP/runtime-doc suites check default-off, authenticated 404/anonymous 401; publication/API and operational suites cover `/`, `/health`, `/prometheus` | Verify resolved non-live flag and production-disabled values through normal deployment controls |
| Journal schema and fresh migration path | `draft_casefile_test_observations_pgtap_tests.sql` and `draft_casefile_test_send_attempts_pgtap_tests.sql` own V1_49 direct PostgreSQL boundaries through `dbUnitTest` | Deploy V1_49 before enabling support; predecessor-upgrade verification remains unmet below |
| Actual consumer and unlinked cleanup races | `DraftCasefileCleanupConsumerIntegrationTest` exercises real processing/failure services, observed PostgreSQL lock waits, cleanup commit/rollback, accepted approval followed by rollback/uncertain send, and a controlled publication-repository timeout | This proves Java orchestration, not publication SQL or real graph deletion |
| Pending/published cleanup | Current integration guards require 409 and preserve draft, graph and journal | The six-check gate in the support guide requires the real provider, graph/writer inventory and complete publication/cleanup races; this requirement is Not Agent Complete |

The admission tests use short test-only connection timeouts and latch/transaction
coordination, with the existing PostgreSQL Testcontainers infrastructure. They
exercise real approval service transactions and the real evidence decorator/writer;
the external publisher is controlled. They do not replace the isolated real broker
checks. `DraftCasefileAdmissionTest` checks insufficient-capacity startup,
default-off behavior, interruption and permit release. Existing default-off
decision transaction tests retain their enclosing-transaction behavior. See the
[support concurrency contract](DRAFT_CASEFILE_TEST_CLEANUP.md#support-enabled-concurrency)
for the pool-derived per-replica bound and supported caller/deployment assumptions.

Counts above are attempts / acknowledged / uncertain / unfinished. Unregistered,
uncertain or unfinished evidence fails the recovery test's precondition, as do
disabled support, a missing broker prerequisite, a service upgrade during the
interval or a producer without the decorator. A send count is not a consumer
execution count or broker-level exactly-once proof; a transport exception does
not prove non-delivery. The service suites do not implement Cypress response
loss, a durable browser-independent ledger or deployed frontend GET assertions.

Additive V1_49 creates the journal tables without changing stored routines.
The existing `draft_casefiles_pgtap_tests.sql` and
`draft_casefiles_publication_link_pgtap_tests.sql` remain draft-schema coverage;
the new owning suites cover journal constraints, indexes and cascade behavior.
Endpoint deletion and transaction rollback remain application integration
coverage. Run the full build's `dbUnitTest` baseline and inspect timings,
PostgreSQL version and owned cleanup evidence in `build/reports/dbUnitTest`;
do not infer execution from compilation or task presence.

The journal's DB-03 upgrade check remains unmet with selected predecessor
`1.34`. Integrate the separately delivered framework PR #271 and the journal's
owning suites through the reviewed `OPAL-DB-UPGRADE` and
`dbUnitTestComparisonRef` / `dbUnitTestUpgradeMode` interfaces before executing
and recording predecessor preservation, candidate migration, assertions,
validation, repeat/no-op and owned cleanup. No standalone upgrade recipe or
harness is provided. Fresh migration and integration-test success do not close
this requirement.

Pending/published cleanup also remains **Not Agent Complete**. The PO-10629 Java
consumer and separate failure transaction now share cleanup's row lock and
missing-row no-op protocol. The current migration tree does not supply
`public.p_process_draft_casefiles`; positive real-provider integration tests
require separately delivered, pinned SQL. A test-only provider or controlled
repository failure is not real graph-publication evidence. Do not blanket-skip
these upstream checks or treat a focused support run as a passing whole baseline.
Preserve both 409 responses and outstanding IDs/markers until the reviewed graph
and writer inventory and all six [cleanup gate checks](DRAFT_CASEFILE_TEST_CLEANUP.md#deployment-retention-and-outstanding-prerequisites)
have passed. There is no journal TTL or background sweeper; scoped eligible DELETE
is the retention mechanism.

Functional/smoke suites require a separately running agreed non-live service,
User Service permission 21 inputter, a distinct checker with its normal decision
permission, compatible migrations, enabled support and a dedicated broker queue.
Expected evidence includes registration 201/repeat 200, current-owner reads,
unchanged observation, one approval acknowledgment, scope 403 and disabled 404.
Document omitted external checks with that setup and expected result. Do not
enable support or exercise cleanup against shared data during routine local
verification. Human QA, deployment and frontend adoption remain separate from
these service checks.

## Test design

Mirror production packages, use `*Test`, and assert observable behaviour. Cover validation, error, empty, and configuration paths affected by a change. Keep Testcontainers and network boundaries explicit; do not make unit tests depend on them.

Authentication integration tests generate their own JWTs at runtime and use
WireMock for User Service responses. They do not require a real AAD tenant or
User Service. The Bruno collection is a separate, optional manual check for a
real AAD/User Service setup; enable testing-support endpoints explicitly with
`TESTING_SUPPORT_ENDPOINTS_ENABLED=true` before using its ping or authenticated
diagnostic requests. Never place a bearer value in a tracked Bruno file.

## Routine suites and framework gaps

Follow the authoritative [pgTAP suite layout](#pgtap-suite-layout) for placement,
single-suite ownership, SQL/pgTAP assertions and coordination, runner
restrictions, and existing-path exceptions. This section adds verification and
tooling-gap requirements to that layout contract.

For a required multiple-session concurrency scenario, identify the actual
SQL/pgTAP mechanism in the owning suite, its disposable-harness prerequisites,
independent sessions, bounded coordination, command-failing assertions, and
verified cleanup. In-suite test-only `dblink` coordination, as used by the
account-number allocator suite, can execute through `dbUnitTest` without a
separate Gradle orchestration hook. Confirm the mechanism's availability and
execution evidence for the scenario; neither a missing shared hook nor test
source alone establishes whether the required coverage is verified.

The current `gradle/db-unit-test.gradle` implements the fresh DB-01 path and
has no maintained predecessor target. A standalone upgrade recipe does not
establish a maintained DB-03 framework capability.

If mandatory coverage requires an unavailable mechanism, include a concrete
enabling task or linked, independently reviewable work package under
[Required prerequisite delivery](CONTRIBUTING.md#required-prerequisite-delivery).
Record the scenario and tooling gap, and make the package's owner or assignment
status, deliverable and current versus proposed interface, consuming-suite
integration, sequence and acceptance evidence explicit. An owner or future
framework reference alone is insufficient. The full delivery plan is blocked
while that package or a required decision is absent; bounded routine work that
does not depend on it can still progress. Keep the required coverage visible
and unmet until the supported SQL/pgTAP mechanism can execute it through the
maintained framework and execution evidence proves it. Do not omit coverage or
claim availability based on a proposed hook. The existing
[DB-03 unmet upgrade requirement policy](#db-04-pgtap-test-placement) still
applies.

Any future framework phases that carry test observations across connections
must define their state lifetime, ownership and cleanup, with a coordinated,
narrowly scoped amendment to the transaction guidance when the framework is
delivered. A proposed phase interface grants no transaction exception: the
current pgTAP suite requirement to end with `ROLLBACK` remains in force.

## DB-10 pgTAP execution

Database contracts live under `src/dbUnitTest`. `dbUnitTest` discovers both
`*_pgtap_tests.sql` and `*_unit_tests.sql` recursively and executes them through
`pg_prove`. New database contracts use `*_pgtap_tests.sql` for DB-04;
the `*_unit_tests.sql` suffix remains supported for existing suites.
For a database object's schema contract, combine catalogue and behavioral
assertions in one `*_pgtap_tests.sql` suite rather than splitting them by test
type.
Follow the [pgTAP suite layout](#pgtap-suite-layout) for all new or updated
database-owned tests.
The existing Maintenance Applications suite combines these checks in
`maintenanceApplicationsTest/maintenance_applications_pgtap_tests.sql`.
Introduced or changed routines use the owning suite and framework-gap rules in
[Routine suites and framework gaps](#routine-suites-and-framework-gaps).
Discovered suites are part of Gradle and the normal `check` lifecycle.

The task runs two fixed fresh PostgreSQL 17 profiles with pgTAP. `non-live-dev`
applies `ddl`, `data/allEnvs`, `data/nle`, and `data/dev`; `non-live` applies
`ddl`, `data/allEnvs`, and `data/nle`, proving the common NLE seed without DEV.
Each profile has its own empty disposable database, Flyway validation and
no-op second migration, the complete discovered pgTAP suite set, report, and
verified container cleanup. Both profiles run even if one fails; either failure
fails `dbUnitTest`. Normal `./gradlew dbUnitTest` and `./gradlew build` run both
profiles. Staging currently adds no SQL under `data/stg`; this common NLE check
does not claim validation of future staging-specific migrations. The task fails
closed when application or external Flyway target settings are present, so it
cannot fall back to a developer-owned or shared database. Failure output lists
setting names only and never their values.

Each pgTAP suite must start a transaction, create the `pgtap` extension if
required, declare an exact `plan`, call `finish()`, and end with `ROLLBACK`.
The framework also runs a deliberate failing fixture to prove that a non-zero
`pg_prove` result fails closed. pgTAP is test-only: do not add it to production
Flyway migrations, application dependencies, or shared databases.

Run the database unit-test suite with:

```bash
./gradlew dbUnitTest
```

Raw TAP diagnostics and a non-sensitive execution summary are written under
`build/reports/dbUnitTest/non-live-dev` and `build/reports/dbUnitTest/non-live`.
`build/reports/dbUnitTest/summary.txt` records the current aggregate result
and each profile's cleanup outcome.
The current Countries contract is
`src/dbUnitTest/countriesTest/countries_pgtap_tests.sql`.

### pgTAP file headers

Every new or amended pgTAP suite must start with a file-level header containing
`OPAL Program`, `MODULE`, `DESCRIPTION`, and `CHANGE HISTORY`. Use the filename
for `MODULE` and describe the suite's purpose and scope in `DESCRIPTION`.
Change history must record the date, responsible human contributor, Jira ticket,
and change summary. Never use `Codex` or another agent name as the author; ask
if the responsible contributor is unknown. Preserve trustworthy existing history
and append the current change; do not invent historical entries or add a manual
version number.

For a new suite, the initial entry describes its introduction (for example,
`Initial pgTAP test suite.`) and uses the evidenced creation date. Later entries
describe the test coverage added or changed for the relevant table or routine;
an existing suite receives an update entry, not a new initial-suite entry.

When an existing suite lacks a header, recover its initial entry and relevant
subsequent coverage changes from verified Git or ticket evidence, then append
the current change. Report missing historical details rather than guessing
them. Adding the header must not change executable SQL, fixtures, assertions,
or the pgTAP plan count.

```sql
/**
 * OPAL Program
 *
 * MODULE      : <test_filename.sql>
 *
 * DESCRIPTION : <suite purpose and scope>
 *
 * CHANGE HISTORY:
 *
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * DD/MM/YYYY  <contributor> <JIRA-KEY>    <change summary>
 */
```

These conventions apply to new and amended suites; do not modify unrelated
legacy tests solely to add headers.

### pgTAP suite layout

- Give each function or stored procedure one self-contained pgTAP suite named
  `<routine_name>_pgtap_tests.sql`. Keep all scenarios and assertions for that
  routine in that file. Use the same single-suite approach for a database
  object's schema contract; schema and reference-data contracts retain their
  existing separate ownership.
- Place every new suite directly under `src/dbUnitTest`. Do not create object,
  feature, ticket, `support` or other subdirectories beneath that test root.
  Identify the tested routine or object in the suite filename instead.
- Keep routine-specific setup, synthetic fixtures, independent expected
  results, temporary SQL helpers and cleanup inside the owning suite. Do not
  split them into separate setup, fixture, boundary or concurrency SQL files,
  and do not include another suite or support SQL using `\i` or `\ir`.
- Database assertions, routine test coordination, fixtures, test-only SQL
  helpers and cleanup stay inside self-contained SQL/pgTAP suites. Run the
  suites through the existing Gradle-owned `dbUnitTest` framework. Do not add
  Python or shell database test runners for assertions or test coordination,
  including ignored, generated, or temporary scripts and executable runbook
  recipes, or shell commands inside a suite through `\!`, `COPY ... PROGRAM`
  or an equivalent mechanism. This restriction concerns database testing;
  unrelated metadata or documentation tooling and the existing shared Gradle
  lifecycle orchestration remain permitted.
- Keep interaction checks in the consuming routine's suite. Preserve applicable
  success, boundary/failure, row-scope, repeat, rollback and real concurrency
  coverage within that suite. If required SQL-only tooling is unavailable,
  report the gap rather than silently dropping coverage or adding a shell
  runner.
- README documentation may sit directly alongside the suites. Existing suites,
  authoritative reference-data fixtures and framework self-tests retain their
  current paths unless their relocation is explicitly in scope; their legacy
  folders are not a precedent for new suite layout. Do not add new routine
  support files.

For example, two functions have two independently discoverable suites directly
under the database test root:

```text
src/dbUnitTest/
├── f_get_check_letter_pgtap_tests.sql
├── f_get_account_number_pgtap_tests.sql
└── README.md
```

### pgTAP scenario introductions

Keep a single object-focused suite and retain its existing assertion
descriptions. Every new or amended suite must introduce each meaningful
behavioural scenario with a SQL comment block explaining `Scenario`, `Setup`,
and `Expected`, enclosed by matching separator lines above and below the block.
Related schema assertions may share a header; do not add manually
maintained test numbering. The required pgTAP `plan` remains unchanged for
comment-only edits.

For example, a missing-parent scenario can be introduced with:

```sql
-- -----------------------------------------------------------------------------
-- Scenario: A Business Unit refers to a parent that does not exist.
-- Setup: Insert a child with parent_business_unit_id = 31999, which is absent.
-- Expected: The foreign key rejects the insert with SQLSTATE 23503.
-- -----------------------------------------------------------------------------
```

Keep headers accurate about fixture dependencies and outcomes, rather than
merely repeating the SQL. This example requires parent `31999` to be absent
and all other insert requirements to be satisfied so that the foreign key is
the reason for rejection. Describe the actual setup when a scenario relies on
earlier fixtures. Choose scenario boundaries from the behaviour being tested,
not a target number of headers or assertions. Adding these introductions must
not change coverage or executable SQL, split the suite, or introduce a new
framework.

## Infrastructure and evidence

Integration tests need Docker for Testcontainers. HTTP functional and smoke
checks need a running service. Record exact commands, results, environments,
and manual scenarios. For every relevant skipped check, record the reason, the
scenario, the setup needed to execute it, and the expected result. A successful
pipeline is not evidence that every changed scenario ran.

For Flyway or SQL changes, follow the fresh-database, upgrade-path, database-boundary, and evidence requirements in [Database Migrations](DATABASE_MIGRATIONS.md).

## Major Creditor reference-data prerequisites

PO-10294 and PO-10297 use authenticated HTTP requests against existing
Maintenance reference data, following the Fines seeded-data test pattern.
Use the normal `TEST_URL` and `OPAL_USER_SERVICE_API_URL` configuration
described above. No functional fixture database, JDBC credentials, owner
table, sequence, test inserts or cleanup hooks are required.

The target must contain the approved BU 44 Central Authority seed from
`V1_10__insert_major_creditors_reference_data.sql`, including code `0001`.
Central Authority checks require a nonempty result and verify the seeded
record's casefile details; they do not assume generated identifiers or
exactly ten records.

PO-10297 positive coverage originally required the DEV-only
`data/dev/V1_33__insert_major_creditors_dev_data.sql`, applied through normal
Flyway migration with `ddl`, `data/allEnvs` and `data/dev` selected. It adds
three synthetic BU 44 records: active non-Central Authority `T901`, inactive
non-Central Authority `T902`, and active Central Authority `T903`. The positive
scenario requires T901's exact casefile details, excludes T902/T903, and allows
additional qualifying creditors without assuming generated IDs or an exact
result count. Malformed-filter and authentication scenarios remain covered.

The DEV-only synthetic reference-data contract was approved by the requester
on 2 October 2026; see `src/dbUnitTest/majorCreditorsDevDataTest/README.md`.
The saved PO-10297 ticket draft originally called for test-owned data. The
subsequently approved strategy uses seeded reference data and read-only HTTP
steps. On 21 October 2026 the requester expanded that strategy to every
non-live environment, following the Fines common-NLE pattern. This is a scope
amendment to record in the PR; it does not establish a Jira update or deployed
approval. `data/nle/V1_34__insert_major_creditors_nle_data.sql` supplies the
same three records through the common NLE location. Historical DEV V1_33 and
its approval and verification evidence remain unchanged.

The checked-in local application default and DEV Helm template select
`ddl + allEnvs + nle + dev`; the staging Helm template selects
`ddl + allEnvs + nle`. The production base Helm values select only
`ddl + allEnvs`, excluding both synthetic-data locations. These files do not
prove the effective settings of a running deployment. Separately managed
`FLYWAY_LOCATIONS` overrides, the image contents and migration history must be
checked per target. The repository has migration directories for demo, ITHC
and performance, but no checked-in deployment overlay for those targets; if
any is deployed, inventory its effective locations and include `data/nle` for
this approved non-live scope before running positive scenarios. Do not infer
coverage from an environment name or add an unconfigured overlay.

V1_34 inserts exactly three rows when none of the BU 44 T901/T902/T903 keys
exists. If all three rows exactly match the approved fields and Country, it
makes no change, preserving DEV V1_33's generated IDs. A partial set or any
conflicting field fails the migration atomically and needs investigation;
neither case is silently repaired or skipped. The migration resolves the
existing Czech Republic uniquely and leaves unrelated creditors intact.
The owning flat pgTAP suite checks both fresh profiles, including direct rerun,
all fields, rollback and failure atomicity. The existing DEV suite remains in
the discovered suite set for both profiles and verifies the historical V1_33
contract without requiring that migration in common NLE Flyway history.
Local disposable verification does not establish shared-environment deployment
or QA sign-off. Positive coverage requires both approved data and a passing
live scenario; an empty response cannot satisfy the positive acceptance
criterion. Apply the appropriate non-live migration locations before executing
positive functional tests.
Before rollout, confirm the target's effective `FLYWAY_LOCATIONS`, deployed
image and `flyway_schema_history` script names. Inspect the earlier seed names
V1_15, V1_17 and V1_31 as well as V1_33; a version number alone may refer to
another migration. Apply V1_34 through normal Flyway deployment after `ddl`
and `allEnvs`. If history is incompatible, stop and obtain a separate approved
database-owner recovery decision; never automatically repair history or edit an
applied migration. After deployment, refresh affected BU 44
`majorCreditorReferenceDataCache` entries through the approved administration
route, using the actual environment/cache prefix. Include
`44_noFilter_noFilter`, `44_false_true` and any other cached BU 44 filter
combinations in use. Do not flush Redis globally. Redis TTL defaults to eight
hours, and restarting a pod does not clear Redis. Then rerun the live positive,
malformed-filter and authentication scenarios against an agreed compatible
non-live Maintenance and User Service target. Cache refresh and migration are
rollout actions, never functional-test setup or cleanup hooks.
Targets that select `allEnvs` without `dev` require the approved `nle` location
when non-live functional coverage runs. Do not enable DEV or NLE data in
production. Tests make read-only HTTP requests and never insert, update or
clean up reference data. V1_33 remains historically one-shot, while V1_34
accepts an exact direct rerun and rejects partial or mismatching data.
See `src/dbUnitTest/majorCreditorsDevDataTest/README.md` for fresh/upgrade scope
and historical database-boundary assertions. Fresh checks do not establish
deployment, positive functional execution, or predecessor upgrade readiness.


## Results reference-data functional prerequisites

PO-10298 follows the Fines seeded-data pattern: all four scenarios use normal
TEST_URL and the existing OPAL_USER_SERVICE_API_URL. The all-environment Results
baseline contains MAT / Matrimonial Order for Adult, MCHILD / Maintenance Order
for child(ren), and MLUMP / Lump sum order as the three active Order Terms.
There are no inactive Order Terms. Normal service startup applies the configured
Flyway locations; functional tests do not insert, delete or alter reference data.

The empty live scenario requests order_term=true&active=false and asserts count
0 with refData []. It is named for that inactive precondition. The original
no-active-Order-Term condition is covered in ResultsDatabaseIntegrationTest with
owned per-test rows and the exact order_term=true&active=true request. These are
separate coverage statements. No special Results target URL or fixture database
is required. Incompatible baseline data is a test failure, not a skip.

Run the live parent scenarios:

    ./gradlew functionalOpal -Dcucumber.filter.tags=@JIRA-STORY:PO-10298

Validate discovery separately:

    ./gradlew functionalOpal -Dcucumber.filter.tags=@JIRA-STORY:PO-10298 -Dcucumber.execution.dry-run=true

Run assertion checks without a Cucumber tag property:

    ./gradlew functionalOpal --tests 'uk.gov.hmcts.opal.steps.ResultsStepDefTest'

Preserve scenario names, test/failure/error/skipped counts, exact command,
elapsed time and non-sensitive setup notes before the next functionalOpal run
clears reports. Discovery and HTTP mocks are not live API evidence. Review raw
reports before sharing; never archive bearer headers, tokens or reusable
connection credentials. A normal full functional/smoke run also needs the other
journeys' documented data and compatible authentication service.

## Result detail functional coverage

PO-10301 uses the same normal TEST_URL and OPAL_USER_SERVICE_API_URL as the list
scenarios. MLUMP / Lump sum order is supplied by the maintained all-environment
baseline; ZZZZZZ is an explicitly unallocated identifier. Functional requests
are read-only and need no synthetic inserts, fixture database or special detail
URL. Existing authentication remains enabled.

The three live scenarios verify selected seeded details and meaningful Amount
metadata, correlated 404 for an absent identifier, and 401 without Result data
for an unauthenticated request. MLUMP's Amount uses decimal-2dp, prompt “Amount
of order”, mandatory true, minimum 0 and maximum 9999999999.99.

Inactive retrieval (200), unfamiliar metadata passthrough (200), explicit SQL
null and encoded [] are covered in ResultDatabaseIntegrationTest using owned
per-test data and cache reset. The original active-empty list condition is
separately covered in ResultsDatabaseIntegrationTest. These integration cases
are not counted as live functional scenarios; this is the requester-approved
coverage/data-strategy amendment to the original ticket requirements.

Validate discovery:

    ./gradlew functionalOpal '-Dcucumber.filter.tags=@JIRA-STORY:PO-10298 or @JIRA-STORY:PO-10301' -Dcucumber.execution.dry-run=true

Run both stories live against the normal seeded service:

    ./gradlew functionalOpal '-Dcucumber.filter.tags=@JIRA-STORY:PO-10298 or @JIRA-STORY:PO-10301'

Expect seven Results scenarios: four list and three detail. Missing baseline
records, an allocated absent identifier or incompatible authentication is a
setup/test failure, never a skip or a reason to mutate reference data. Preserve
non-sensitive reports before later invocations clear them. The full functional
suite also needs all other documented reference-data prerequisites.
