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

### Approved casefile publication journeys (PO-10621)

`draftCasefiles/publish/PublishDraftCasefile.feature` contains exactly three live
journey instances tagged `@Opal`, `@PO10621` and `@JIRA-STORY:PO-10621`. Each
creates a fresh synthetic draft, obtains a real independent checker approval,
polls the ordinary owner GET for the real consumer outcome, applies the strict
`DraftCasefilePublicationAssertions` contract and repeats GET with the exact
terminal JSON body and ETag. The success examples use zero minor creditors and
minor creditor sequences 7 and 23. The failure example uses the existing
`unpublishable` fixture: a nonnumeric Amount accepted by POST but rejected by
publication validation. Live glue never sends a JMS message, invokes a fake
provider, or registers a publication-evidence observation. Ordinary GET does
not require publication-journal registration.

| Acceptance criterion | Live HTTP journeys (3 instances) | Real-provider orchestration integration (6 instances) | Opt-in real broker (5 instances) |
| --- | --- | --- | --- |
| AC1: publish all account identities and preserve approval details | Two success examples assert complete snapshot identities, independent account-number checksum, exact minor sequences, immutable input/approval/history, advanced strong ETag and stable read | `publishesCompleteGraph` with zero/two minors verifies the complete committed graph, typed children and reservations | `fullGraphIsCommittedBeforeActualJmsCommit` reads committed graph before the real session commit |
| AC2: terminal failure preserves approval without partial publication | One failure example asserts the exact original null-identity snapshot, safe fixed message, top-level `validated_date`, immutable input/history and stable read | `terminalFailureCommitsAfterProcessingRollback` and `failureRecordingOutageRetriesUntilTerminalCommit` require a real provider return before injected failure, no partial graph and a separately committed failed draft | `terminalRollbackAndDistinctFailureCommitPrecedeJmsCommit` verifies rollback and committed failure before settlement |
| AC3: transient failures retry and duplicate delivery is idempotent | No live failure injection or broker-delivery assertion | `transientFailureRetriesThenDuplicateIsNoOp` and `separatePublishedDeliveryIsIdempotent` verify rollback/retry and one committed graph | `onePostProviderTransientRollsBackThenHigherDeliveryCountPublishes`, `databaseCommitBeforeCallbackFaultRollsBackJmsAndDuplicateCreatesOneGraph` and `repeatedPostProviderTransientReachesExactDeadLetterLimitWithNoGraph` verify real rollback/redelivery, the DB-committed/JMS-uncommitted duplicate window and exact configured dead-letter limit |

The six controlled instances are in `DraftCasefilePublicationQaIntegrationTest`;
the five actual-broker cases are in
`DraftCasefilePublicationBrokerQaIntegrationTest`. Helper JUnit tests prove glue,
assertion, graph-observation or settlement-container boundaries only. They do
not count as deployed functional, database-provider or broker acceptance
passes. An API `PUBLISHING_FAILED` outcome from the nonnumeric fixture does not
prove the real procedure ran or that a partially created graph rolled back.
Full graph, rollback and delivery-count claims require the corresponding
integration/broker evidence.

Use compatible existing non-live Maintenance and User Service deployments via
`TEST_URL` and `OPAL_USER_SERVICE_API_URL`, real publication producer/consumer
connectivity, and enabled scoped testing-support cleanup. Existing reference
data must include Business Unit 44, active application `AP00001`, active country
CJS code `1` and result `MAT`. The default inputter is
`opal-test@dev.platform.hmcts.net`; the independent checker is
`opal-test-10@dev.platform.hmcts.net`. Overrides are
`RM_DRAFT_CASEFILE_INPUTTER_USER` and `RM_DRAFT_CASEFILE_CHECKER_USER`. Tests
resolve the actual User Service name and unique owning Business Unit user ID.
The inputter requires permission 21; the checker requires permission 22. Equal
display names are allowed. Configured inputter/checker users must differ
case-insensitively before any token/state request; equal resolved identities
also fail setup even when configured emails differ. Missing/malformed user state, duplicate owning-unit
entries, invalid/duplicate positive integer permission IDs and missing role
permissions fail setup. Tests never provision or change users or reference data.

The provider prerequisite remains PO-10655. Align its delivered routine with
the existing consumer call `public.p_process_draft_casefiles` using four
arguments: draft ID input, respondent ID output, respondent account-number
output and published-accounts JSON output (including sequence-mapped creditor
identities). The actual message has `draft_casefile_id`, `checker_user_id`,
`originating_ip_address` and `approval_timestamp`; earlier ID-only/two-output
TDIA wording does not establish this consumed contract. Pin the delivered
provider revision and execute its owning pgTAP plus these consumer checks.
Missing-provider and post-provider-hook failures remain strict failures; never
invert or skip them to produce a pass. This QA work supplies no SQL, procedure,
runtime fix or deployment. Earlier design text describes a third-party country
as text; actual `third_party_contact` uses a numeric country foreign key. The
typed graph checks follow the actual schema. The agreed API `validated_date`
remains top-level and unchanged from approval.

The broker suite requires an existing otherwise unused dedicated
`TEST_SERVICEBUS_QUEUE` matching `test-[A-Za-z0-9._-]+`, an explicit positive
`TEST_SERVICEBUS_MAX_DELIVERIES` matching that queue's actual configured limit,
and normal secret-managed `SERVICEBUS_CONNECTION_STRING`/`SERVICEBUS_PROTOCOL`
settings. Optional `TEST_SERVICEBUS_AMQP_URI` is a credential-free AMQP endpoint
without query/fragment options. `RUN_SERVICE_BUS_TESTS=true` opts in; when absent,
all five cases are unverified skips. Invalid opt-in configuration fails setup.
The test's normal application listener stays stopped; only an owned listener
with the scenario correlation selector may consume. Correlation-scoped main
queue and DLQ checks follow stop/join. Queue provisioning, application-queue
consumption and queue purge are outside this work. Do not print credentials,
message bodies, User Service state, PDPL or encrypted/PII dumps in evidence.

Cleanup uses one DELETE with the original creator token, captured positive Long
ID and fresh `E2E-` plus 16 lowercase hex marker, even after later POST metadata,
approval, polling or assertion failures. There is no GET or ETag prerequisite.
Only HTTP 204 succeeds. Pending/published lifecycle 409s remain an external
PO-10626 cleanup prerequisite: a 409 fails an otherwise passing scenario; a
primary failure retains a separate safe ID/marker/numeric-status ledger.
Transport errors retain a fixed request-error category. Ambiguous POSTs
(transport/null/5xx/malformed 201/no recoverable ID) are never replayed or found
through guessed IDs/search. The marker-only ledger explicitly records no
captured ID, no replay and required manual recovery; non-201 outcomes are
conservatively retained as unknown ownership. Attachment failures fall back to
a safe assertion containing the complete ledger. Scenario credentials and
state clear in `finally`; repeated after hooks do nothing. No deployed DB
cleanup, graph deletion or lifecycle bypass is authorised.

Run Java boundary tests without a Cucumber tag property: the build restricts
tag-filtered execution to `OpalTestRunner`. Dry-run suppresses HTTP scenario
actions while JUnit helpers run normally. Preserve helper XML from
`build/test-results/functional/opal` before the discovery run replaces it:

```bash
./gradlew --offline functionalOpal --tests 'uk.gov.hmcts.opal.steps.PublishDraftCasefileStepDefTest' -Dcucumber.execution.dry-run=true
./gradlew --offline checkstyleFunctionalTest
./gradlew --offline functionalOpal -Dcucumber.filter.tags=@PO10621 -Dcucumber.execution.dry-run=true
```

Discovery must find exactly three instances without undefined/ambiguous steps;
a dry run is not live acceptance evidence. Once the existing runtime and cleanup
prerequisites are available, execute the real journeys separately:

```bash
TEST_URL=http://localhost:4551 OPAL_USER_SERVICE_API_URL=http://localhost:4555 ./gradlew --offline functionalOpal -Dcucumber.filter.tags=@PO10621
./gradlew --offline integration --tests 'uk.gov.hmcts.opal.service.messaging.DraftCasefilePublicationQaIntegrationTest'
RUN_SERVICE_BUS_TESTS=true ./gradlew --offline integration --tests 'uk.gov.hmcts.opal.service.messaging.DraftCasefilePublicationBrokerQaIntegrationTest'
```

Supply the dedicated queue, actual delivery limit and managed connection
settings through the environment before the broker command. Offline controls
dependency resolution, not HTTP or broker execution. Record exact helper counts,
three live results, six provider results and five broker results separately,
including failed stages, skips, safe retained cleanup ledger and prerequisites.
Common and Backend Definition of Done remain **Not Agent Complete** until all
applicable required checks actually pass. Authored tests, dry discovery and
unavailable-provider failures do not establish acceptance completion.

### Rejected casefile resubmission journeys (PO-10622)

`draftCasefiles/replace/ResubmitRejectedCasefile.feature` contains exactly five
journeys tagged `@Opal`, `@PO10622` and `@JIRA-STORY:PO-10622`. Dedicated
`ResubmitRejectedCasefileStepDef` glue preserves the legacy replace feature and
bindings. All five create their own complete synthetic casefile, including
minor creditor sequences 7 and 23 and a fresh `E2E-` plus 16 hex character
marker. They compare the full original POST request with an authoritative
version-zero GET, verify the actual creator and derived snapshot/history, then
perform a real independent checker rejection and complete persisted readback.

| Acceptance criterion | Live journey | Supporting controlled integration |
| --- | --- | --- |
| AC1: correct a rejected casefile and resubmit | Original inputter changes respondent, applicant and minor 7 names while preserving minor 23; HTTP 200, full corrected content/snapshot/history, advanced ETag, persisted RESUBMITTED and zero publication | `DraftCasefileResubmissionQaIntegrationTest` verifies the complete transaction and original submitter |
| AC2: another authorised inputter can resubmit and becomes latest submitter | Different owning-unit inputter takes ownership; the same latest submitter with check permission then receives 403 for self-check, preserving full state/version and zero publication | Integration verifies handover and latest-submitter self-check denial |
| AC3: invalid or unauthorised corrections preserve the rejected draft | Unknown application `ZZ99999` gives 400; caller without owning-unit create authority gives 403; supplied Business Unit 45 with nested owner 44 gives resource-conflict 409. Each verifies whole unchanged GET, ETag and zero publication | Integration also controls obsolete ETag against eligible REJECTED state, non-REJECTED lifecycle and a caller authorised only in another Business Unit |

Use normal `TEST_URL` and `OPAL_USER_SERVICE_API_URL` pointing to compatible
non-live Maintenance and User Service deployments. Existing reference data must
include Business Unit 44, active application `AP00001`, active country CJS code
`1` and result `MAT`. The application must provide enabled scoped cleanup and
publication-evidence routes with compatible producer instrumentation. Tests
never change reference data, identities or permissions.

The default creator is `opal-test@dev.platform.hmcts.net`, independent checker
and resubmitter is `opal-test-10@dev.platform.hmcts.net`, and denied caller is
`opal-test-2@dev.platform.hmcts.net`. Overrides are
`RM_DRAFT_CASEFILE_INPUTTER_USER`, `RM_DRAFT_CASEFILE_CHECKER_USER` and
`RM_DRAFT_CASEFILE_DENIED_USER`. Each scenario resolves actual User Service
`name` and Business Unit identity. Creator requires owning-unit permission 21;
checker/resubmitter requires 21 and 22 with a different owning-unit user ID.
Equal display names do not establish equal identities. Denied callers must
lack owning-unit 21; valid `domains: {}` is supported. Missing/malformed domains,
present malformed maintenance/units/permissions, duplicate owning-unit entries
and duplicate permission IDs fail setup. Actor details and tokens stay in
memory and never enter retained evidence.

After setup rejection and immediately before the tested PUT, the original
owner registers a fresh observation. HTTP 201, canonical UUID, registration
time and complete `0/0/0/0` counts are mandatory. Registration failures retain
only safe numeric HTTP status, never payloads. A full GET must show unchanged
baseline and ETag after registration. PUT contains only `business_unit_id` and
the complete corrected `casefile`, preserving marker and nested owning unit.
Each mutation is dispatched once. HTTP 200 immediately changes evidence and
cleanup authority to the acting resubmitter before detailed response assertions.
The latest owner must retrieve the complete persisted casefile and the same
observation UUID/time with complete attempt/acknowledged/uncertain/unfinished
counts `0/0/0/0`. Failed PUTs retain original ownership. Negative whole-state and
journal checks execute before final strict problem-format assertions. Self-check
uses a rejection with a valid reason/current ETag, avoiding publication setup.
This scoped producer evidence does not establish broker durability or global
absence of unrelated messages.

Cleanup is bounded to the captured owned ID and marker; only HTTP 204 succeeds.
Confirmed handover uses the latest owner even if a later success assertion
fails. Ambiguous PUTs are never replayed. An ordinary authorised GET can
recognize the owned ID/marker, expected state/version and known owner. An old
REJECTED read cannot rule out a later commit: both original and intended
resubmitter remain cleanup candidates for an ambiguous handover, each tried at
most once until 204. A 403 or request error can permit the second known actor.
No denied/foreign identity, guessed identity/ID, marker search, old record,
lifecycle rewrite, graph deletion or direct database cleanup is used. Unknown
POST IDs retain marker-only follow-up evidence. Unresolved cleanup fails an
otherwise passing scenario; a primary failure retains only safe ID/marker and
status/error-category evidence. Credentials and state are cleared in `finally`,
including attachment failures.

Known runtime gaps must remain visible: publication registration has returned a
non-201 status and owned GET has returned 404 on an existing local deployment;
these are setup failures and do not prove tested PUT coverage. Runtime image
source revision and database-provider compatibility require separate evidence.
The physical `common.yaml` problem contract requires canonical UUID
`operation_id`, while installed common-lib 0.3.37 `LogUtil` strips hyphens.
Strict assertions retain that physical contract; do not relax them or classify
UUID failures as missing-provider failures. Existing scoped cleanup 409s remain
unresolved runtime dependencies and must be reported separately. No result in
this section claims live passes.

Run actual Java regressions without a Cucumber tag property and preserve the
Java XML counts from `build/test-results/functional/opal` before discovery
replaces reports:

```bash
./gradlew --offline functionalOpal --tests 'uk.gov.hmcts.opal.*.DraftCasefile*Test' --tests 'uk.gov.hmcts.opal.assertions.PublicationEvidenceAssertionsTest' --tests 'uk.gov.hmcts.opal.steps.GetDraftCasefileStepDefTest' --tests 'uk.gov.hmcts.opal.steps.ListDraftCasefilesStepDefTest' --tests 'uk.gov.hmcts.opal.steps.RecordCheckerDecisionsStepDefTest' --tests 'uk.gov.hmcts.opal.steps.ResubmitRejectedCasefileStepDefTest' -Dcucumber.execution.dry-run=true
./gradlew --offline checkstyleFunctionalTest
./gradlew --offline integration --tests 'uk.gov.hmcts.opal.controllers.DraftCasefileResubmissionQaIntegrationTest'
```

Validate exactly five discovered scenarios with no undefined/ambiguous steps,
then run live only with the above prerequisites:

```bash
./gradlew --offline functionalOpal -Dcucumber.filter.tags=@PO10622 -Dcucumber.execution.dry-run=true
./gradlew --offline functionalOpal -Dcucumber.filter.tags=@PO10622
```

Record Java boundary regressions, five-scenario discovery, controlled
integration and actual live execution separately, with exact commands, elapsed
time and test/failure/error/skipped counts. Discovery, mocks, unavailable checks
and failure before PUT are not live acceptance evidence. Preserve only safe
IDs, markers, numeric statuses, timings and error categories.

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
to the fresh DB-01 path, the DB-03 upgrade path, or both. The `dbUnitTest` task
executes the complete fresh DB-01 path and selected
DB-03 predecessor upgrades under the [maintained selection contract](#maintained-predecessor-upgrade-contract).
Missing required registration or execution evidence remains unmet and must not
be claimed as verified; unchanged excluded scenarios are not verified by that run.
Representative upgrade setup and synthetic data
rules remain owned by the
[DB-03 guidance](DATABASE_MIGRATIONS.md#planned-db-03-upgrade-path-validation).

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
- The [common explicit procedure handler](DATABASE_MIGRATIONS.md#exception-messages-and-defaults),
  including deliberate integrity errors and native failures retaining their
  original SQLSTATE and applicable diagnostic fields. Neither may become a
  successful return. An agreed translation has its own explicit expectations.
- The declared affected-row scope.
- Repeat-call and idempotency behaviour where applicable.
- Participation in caller-controlled rollback and atomicity at the declared
  boundary.
- Cancellation and assertion-failure propagation where applicable. The common
  `WHEN OTHERS` handler does not intercept either condition. Distinguish rollback
  of writes in the exception block from ownership of the caller's transaction;
  sequence consumption can still leave gaps.
- When run-status behaviour is relevant, that the procedure does not
  independently create or update run-status records.

The database procedure/backend ownership contract is defined in
[Database Migrations](DATABASE_MIGRATIONS.md#planned-db-06-stored-procedure-responsibility-contract).
Backend transaction and run-status orchestration tests remain outside
`dbUnitTest` and must be tracked separately when required; backend test
ownership is unchanged. For Notes, retain respondent-account target checks,
standard-note mapping, author mapping, single-row insertion, and atomicity in
the database suite. Verify original author lengths against 20 characters for
`posted_by` and 100 for `posted_by_name`, including multibyte characters and excess
trailing spaces, using unbounded arguments. Rejection must retain target-check
precedence, return SQLSTATE `22001` with a fixed, value-free field message, and
leave rows and the Note sequence unchanged. Accepted null, empty, whitespace and
boundary values must be preserved exactly. Keep historical predecessor contracts
separate from this forward correction. Required/non-null request values, JSON
shape and types, blank/whitespace rules, and other request-format checks remain
backend-owned. Identify the actual request-to-persisted-casefile-to-helper
path and its validation tests before claiming that moved coverage exists; UI
checks alone are insufficient. Until that evidence exists, record the backend
dependency rather than treating removal of database assertions as coverage.

Unchanged rethrow preserves original messages, details, hints, and context; it
does not sanitise them. Verify caller response and log handling separately with
synthetic markers before claiming protection against diagnostic disclosure.
The common handler emits no additional routine-level log. Any backend context
must use only agreed non-sensitive fields and have its own assertions; native
server logging and pre-entry binding failures are separate concerns.

DB-10 owns reusable assertion mechanics,
command-failing output, and evidence formatting rather than DB-06 duplicating
them here.

## Baseline and focused commands

`./gradlew build` is the baseline validation for source, build, and runtime
configuration changes. In this repository, `check` depends on `dbUnitTest`
and `integration` as peer suites. Fixed-profile/runtime, selection and
compact-contract regressions also run under `check`; shared
runner/support/configuration changes require the native framework failure matrix
as well as full registered replay in both supported profiles.
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

The maintained `gradle/db-unit-test.gradle` implements fresh DB-01 and registered
DB-03 predecessor targets. Use the shared declaration and dispatch contract below. The same owning SQL
suite supplies fresh and compatible candidate assertions. A standalone upgrade
recipe is not maintained verification.

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

The delivered phase contract below defines the narrow preparation/cleanup
transaction exception for durable test observations. Production routines retain
backend-owned transaction boundaries.

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

The task runs two fixed PostgreSQL 17 profiles with pgTAP:

| Profile | Flyway migration locations |
| --- | --- |
| `non-live-dev` | `ddl`, `data/allEnvs`, `data/nle`, `data/dev` |
| `non-live` | `ddl`, `data/allEnvs`, `data/nle` |

Each profile runs the complete discovered fresh suite set against its own empty
disposable database, followed by its applicable selected registered upgrades in
separate targets. Each target has native Flyway validation, no-op repeat checks
and independently confirmed container/volume cleanup. After global preflight
and shared image preparation succeed, both profiles are attempted in order even
if the first fails; either profile failure fails the aggregate `dbUnitTest`
result. A global preflight or preparation failure reports profiles as not
started. Normal `./gradlew dbUnitTest` and `./gradlew build` use both profiles;
there is no profile override.

The runner resolves `org.flywaydb:flyway-core` and
`org.flywaydb:flyway-database-postgresql` from the application's actual
`runtimeClasspath`. It requires exactly one of each with the same numerical
`x.y.z` release version, derives `flyway/flyway:<version>` from that agreement,
and checks every native Flyway JSON response's `flywayVersion` against it. Missing,
duplicate, mismatched or unsupported versions fail closed. Reports retain the
resolved runtime version and selected image; no image override is supported.
Native `validate` also requires JSON `validationSuccessful: true`; a zero process
exit cannot hide a reported validation failure. The original JSON and diagnostic
remain in the target receipts.

The common NLE profile proves its seed without applying DEV migrations. Staging
currently adds no SQL under `data/stg`; these profiles do not claim validation of
future staging-specific migrations or live deployment settings. The task fails
closed when application or external Flyway target settings are present, so it
cannot fall back to a developer-owned or shared database. Failure output lists
setting names only and never their values.

Every fresh and functional verification phase must start a transaction, create
the `pgtap` extension if required, declare a positive exact `plan`, call
`finish()`, and end with `ROLLBACK`. Only upgrade preparation and observation
cleanup commit ordinary test-owned state across connections. The generic
framework also commits its history snapshots at predecessor/candidate (and the
fresh no-op snapshot) boundaries. Each such phase has its own positive exact
plan and `finish()`; no production transaction ownership changes.
The framework also runs a deliberate failing fixture to prove that a non-zero
`pg_prove` result fails closed. pgTAP is test-only: do not add it to production
Flyway migrations, application dependencies, or shared databases.

Run the database unit-test suite with:

```bash
./gradlew dbUnitTest
```

Raw TAP diagnostics and non-sensitive execution summaries are retained in unique
`build/reports/dbUnitTest/<profile>/runs/<run-id>/` directories. Each profile's
`summary.txt`, `pg-prove.log` and `framework-self-test.log` provide its latest
entry points. `build/reports/dbUnitTest/summary.txt` records the aggregate result,
both profile outcomes and their cleanup evidence.
The current Countries contract is
`src/dbUnitTest/countriesTest/countries_pgtap_tests.sql`.

### Maintained predecessor upgrade contract

Normal `./gradlew dbUnitTest` runs the complete latest fresh suite set and then
affected registered upgrades for each fixed profile. Upgrades run in native
numerical order, each in a new disposable target using that profile's locations.
`check` and `build` inherit this selection contract. Registration discovery and
adoption validation use the complete migration tree once; upgrade eligibility
and immediate predecessor selection use each profile's exact inventory.

Every invocation validates complete-tree numerical uniqueness, committed migration
bytes, all fixed adoption checksums and required registrations. A trustworthy
comparison inventories both revisions; existing migration paths and bytes are
immutable, and new selected versions must extend that history. Modification,
removal, rename and lower-version insertion fail before targets are created;
full fallback does not excuse invalid history. No fresh-suite skip or external
target property exists.

A registration whose candidate is absent from the current profile is reported
**Not selected — outside selected profile locations**, never PASS or upgrade
N/A. Its declared dependencies remain part of global impact classification.
Migrations outside that profile are individually **Unverified**, including their
paths and versions. For example, DEV upgrades execute only in `non-live-dev`,
while NLE upgrades execute in both profiles with their respective predecessors.
One profile's success does not prove another profile or an unexercised location;
retain the applicable profile's actual boundary evidence.

```bash
./gradlew dbUnitTest --no-daemon -PdbUnitTestComparisonRef=origin/codex/parent
./gradlew dbUnitTest --no-daemon -PdbUnitTestUpgradeMode=full
./gradlew dbUnitTestProfileTest dbUnitTestSelectionTest dbUnitTestContractTest --no-daemon
```

`dbUnitTestUpgradeMode` accepts `affected` (default) or `full`. Full mode replays
all historical registrations applicable to each fixed profile and is required
after shared runner, lifecycle SQL, framework fixture, database image, or relevant
build/toolchain infrastructure changes. Automatic selection also forces full
replay for these inputs and for unknown relevant database dependencies. Relevant shared inputs
include Gradle/wrapper files, Docker/Compose configuration, charts, workflows,
Jenkinsfile, application Java/configuration, framework SQL, the fixed support
manifest/dependencies, `gradle/db-unit-test-profiles.gradle` and regression fixtures.
`dbUnitTestProfileTest` checks the fixed profiles, failure aggregation and resolved
runtime agreement without Docker; selection and compact-contract checks are also
independent of Docker. `dbUnitTestFrameworkTest` runs automatically after a
successful normal database task for shared changes or uncertain comparison
evidence; direct invocation remains available. Unchanged trusted input can omit the native matrix, while
fixed-profile/runtime, selector and compact-contract metadata regressions still
run in the normal build.
Unclassified paths under `src/main/resources/db/` or `src/dbUnitTest/` also force
full replay; declare object-specific dependencies through `inputs`.

An explicit `dbUnitTestComparisonRef` takes priority over supported CI context.
Use the immediate reviewed PR base, resolving it locally to a commit; the
same-name feature upstream is not an implicit comparison base. Reports record
tested HEAD, resolved base, merge base, context provenance and changed paths.
Selection includes committed differences and actual staged, unstaged and
untracked changes, deletions and both sides of renames. GitHub merge checkouts
require `GITHUB_EVENT_NAME=pull_request`, a readable `GITHUB_EVENT_PATH` with
`pull_request.base.sha` and `head.sha`, and `GITHUB_SHA` equal to tested HEAD.
The tested revision must be that head or its exact two-parent base/head merge
checkout. Jenkins requires `CHANGE_ID`, `CHANGE_TARGET` naming the immediate
PR target, and `GIT_COMMIT` equal to tested HEAD. Its local branch or
`origin` remote-tracking target must resolve to one unambiguous commit. Ensure
checkout history and the immediate base are available locally before invoking
Gradle; otherwise use full mode and retain the fallback evidence.
No implicit fetch occurs. Missing refs, shallow or
insufficient history, ambiguous or contradictory context fail closed to full
replay with the reason recorded. A valid no-impact comparison may select zero
applicable upgrades while every fresh suite still runs. Full mode and absent
comparison evidence select all eligible scenarios; a profile with no eligible registrations
still reports outside-profile scenarios explicitly.

For normal `dbUnitTest`, the comparison ref controls impact selection and
immutable-history checks. Registered replay recreates each selected numerical
predecessor independently. The separate
[actual-parent task](#actual-comparison-parent-batch-verification) verifies a
retained comparison inventory plus the complete incoming batch.

New candidate registrations, changed owning suites/registrations and intersecting
declared dependencies select their scenarios. The owning suite and candidate are
implicit dependency inputs. Keep additional dependency declarations complete;
shared infrastructure changes require full replay even when a consumer itself
is unchanged.

Place the declaration after the human-attributed header in the owning flat SQL
suite. New upgrade contracts require the compact `contract` object and shared
dispatch described below, including when the owning suite already existed.
Existing four-field registrations retain only the compatibility described below.
Example filenames are illustrative; allocate actual migrations globally.
The four required identity string fields are `id`, `candidate`, `scope` (`both` or
`upgrade`), and `data` (`migration-created-only` or `approved-synthetic`). IDs
are globally unique lowercase `[a-z][a-z0-9._-]*`. Candidates are canonical
paths relative to `src/main/resources/db/migration`. The optional `inputs` array
declares additional canonical repository-relative
dependency file paths. Paths must name existing files or tracked deletions,
contain no absolute/dot/parent segments, and must not repeat the implicit owning
suite/candidate paths. Metadata contains constrained values and arrays, never
executable SQL. Unsafe, unknown or duplicate inputs, escaped strings,
unknown/missing/duplicate fields,
duplicate IDs, multiple owners, candidates absent from the complete inventory
and unsupported migration categories fail before target creation. A globally
valid candidate outside one profile is excluded from that profile's replay. Approved synthetic scenarios
also require an `Approved data scenario:` comment naming the approved contract;
the handoff/README must evidence that approval. The marker does not grant it.

The fixed adoption inventory in the runner pins paths, normalized numerical
versions and SHA-256 bytes for the 32 historical migrations at
`847739c9ee40ca1c09687756212f7f0dcbb56e7d`. It is checked globally, including
adopted DEV files omitted from `non-live`. Missing or changed adoption files fail.
Every later migration in the union of supported profile locations requires
exactly one registration; never extend that inventory to exempt a new migration.
Existing registrations can cover historical migrations explicitly, without
claiming historical backfill. Registration alone does not prove execution.

The runner cross-checks native Flyway `info` against the selected files before
migration. It applies/validates P, captures predecessor evidence, applies/validates
only C, checks the declared preservation and candidate outcomes, and repeats at C
with native zero-applied evidence and complete SQL history equality. Compact
contracts use shared preparation and cleanup; genuine earlier registrations
retain the legacy owner phases described below. Later versions remain excluded
until the candidate's assertions finish. Test-state cleanup and exact target
removal remain mandatory. A true initial migration receives explicit upgrade N/A
plus the full fresh run.

#### Actual comparison-parent batch verification

```bash
./gradlew dbUnitTestParentTransitionTest --no-daemon -PdbUnitTestComparisonRef=<exact-full-SHA>
```

This explicit additional task verifies both fixed profiles independently, each on
one retained disposable PostgreSQL 17 target. It supplements fresh execution and
full registered replay. The public task is not a default build requirement
without a comparison ref. Native Flyway uses the same resolved application
modules and JSON runtime checks as ordinary execution (currently 13.10.0), with
no profile or image override.

Use a locally available full comparison SHA for reproducible evidence. Any accepted
ref must resolve unambiguously and must equal
tested HEAD or its sole immediate Git parent. Comparison equal to HEAD accepts
an existing merge commit and reports `comparisonKind=head-inventory`. If it
differs from HEAD, HEAD must have exactly the comparison as its one parent;
`comparisonKind=sole-immediate-parent` records that result. A merge candidate,
distant ancestor, unrelated ref, missing comparison or invalid history fails
closed. There is no CI/base fallback or fallback to registered numerical replay.

Reports retain `parentProvenance`, `comparisonKind`, `candidateMode`, `overlayPaths`,
`testedHeadTree` and `testedParents`, alongside exact comparison/tested identities,
locations, fingerprints, delta and native/TAP results. `candidateMode` is
`committed HEAD` for clean source or `HEAD plus index/worktree overlay` for
actual staged, unstaged and untracked changes. Relevant ignored executable inputs
also count as overlays; unrelated ignored build and evidence files do not. A
working-candidate run does not
prove a committed candidate's parent relationship. Rerun on the clean committed
child against its sole immediate parent to retain that committed-parent evidence.

Complete-tree numerical uniqueness, immutable committed HEAD/comparison paths and
bytes, fixed adoption and registration/support validation still run globally
before target creation. Each profile derives its exact comparison and tested
inventory using its fixed locations. The nonempty comparison must be an exact
numerical prefix, including path and hash. Equality is fully verified, not
skipped. Outside-location migrations remain Unverified. Existing historical seed
registrations are not incoming additions; their boundaries remain covered by
ordinary full registered replay.

For each profile, native Flyway migrates and validates the comparison inventory,
then shared support captures durable original state. One native migrate applies
all additions. Verification checks exact final inventory, every complete original
history row, successful checksummed SQL and exact preservation before final
owning assertions. Owners run ordinary fresh branches with positive exact TAP
plans and rollback. After those assertions, repeat migration must apply zero
files, native validation must pass and every complete final history field must
remain equal. Empty deltas execute all preservation, owner, repeat/history and
cleanup checks.

Only `db_upgrade_contract_pgtap_tests.sql`,
`db_upgrade_framework_pgtap_tests.sql` and `db_upgrade_lifecycle_pgtap_tests.sql`
are excluded from retained owners because they require absent observation state.
All application owners remain selected. Ordinary fresh execution retains all 42
suites in both profiles, including these three fixed framework self-suites.

The bounded delta allows registered routine creation/replacement and explicitly
recognized Aliases-name and Order-Term-response schema contracts. Delta comes
only from actual additions. Unsupported structural or incoming data changes fail
closed; a compact data `observe` declaration grants no implicit batch exemption.
Routine identities are canonicalized in PostgreSQL; a routine created and
replaced inside the batch need not exist at the comparison boundary. Declared
routine definitions may change while existing properties and privileges remain
exact. Other public application relations, columns, defaults, constraints,
indexes, comments, ACLs, trigger definitions/enabled state, RLS policies, enum
labels and sequence state are compared. Extension-owned objects and Flyway's
history table are excluded from application snapshots; complete history is
compared separately. This is an enumerated catalogue contract, not all PostgreSQL
system catalogues; physical statistics and the transient index MVCC check flag
are excluded.

Rows preserve original JSON text, duplicate keys and multiplicity. Only original
columns are projected for the allowed nullable response-column addition.
Migration-created empty business tables stay empty: this task does not borrow
registered synthetic predecessor preparation or its approval. Shared support
owns guarded committed observations and cleanup, with absence checked from a
distinct backend. A separate `parent-session-absence` probe checks that no other
client backends remain on the test-owned target, excluding its own PID, including
after shared cleanup failure. UUID-owned container and every known anonymous
volume absence are checked independently, including after failure. After global preflight and
image preparation, both profiles are attempted even if the first fails. Primary,
nested and cleanup failures are retained and fail the aggregate.

Reports are separate from normal fresh/registered receipts:
`build/reports/dbUnitTest/parent-transition/summary.txt` is the aggregate;
`parent-transition/<profile>/summary.txt` and each profile's `runs/<run-id>/`
retain selection, delta, fingerprints, phase results and cleanup evidence.
Normal root/profile latest entry points remain unchanged.

`./gradlew dbUnitTestParentTransitionFrameworkTest --no-daemon` exercises the same
maintained runner with fixed fixtures. It retains the original 24 batch/failure
controls and adds equal-inventory no-op, provenance, owner SQL/TAP/zero-plan/
wrong-plan failures, observation identity, undeclared routine changes,
enum/sequence-privilege preservation and first-profile-failure/second-profile
continuation controls. It is part of the existing `dbUnitTestFrameworkTest` graph;
its separate report is `build/reports/dbUnitTest/parent-framework/summary.txt`.
Fixtures are never production migrations. Public tasks accept no arbitrary SQL,
target, credentials or fault injection.

#### Compact contract and shared dispatch

Every new upgrade contract supplies ordinary owning pgTAP assertions and an
`OPAL-DB-UPGRADE` declaration with the four identity fields and a mandatory
compact `contract` object. This also applies to a newly registered boundary in
an existing suite. Shared dispatch owns preparation, capture and cleanup; do not
add owner lifecycle boilerplate. For example, with a globally allocated candidate:

```sql
-- OPAL-DB-UPGRADE {"id":"example.create","candidate":"ddl/V2_0__example.sql","scope":"both","data":"migration-created-only","contract":{"type":"additive","objects":{"created":[{"kind":"routine","identity":"public.example(bigint)"}],"replaced":[]},"preserve":{"rows":["public.notes"],"tables":["public.notes"],"routines":[],"enums":[],"sequences":[]},"assertion":"example.current"}}
```

The declaration identifies a `type` (`additive`, `replacement` or `data`),
expected created/replaced objects, exact preservation scope and the applicable
assertion group. Additive contracts require creations and no replacements;
replacement contracts require replaced routines; data contracts require an
explicit custom verifier and no object additions/replacements. Object kinds
are `routine`, `table`, `view`, `enum` or `sequence`; replacement defaults
currently support routine definitions only. Qualified routine identities include input argument types. Created objects
must be absent at P and present at C. A replaced routine retains its identity,
properties, ownership and privileges while its definition changes. All declared
row/catalogue/sequence preservation remains exact. Do not hide unrelated changes
by declaring broad exclusions. Data or other structural changes need a focused
custom verifier and explicit intended outcomes; successful generic installation
is insufficient.

`preserve` supplies arrays for `rows`, `tables`, `routines`, `enums` and
`sequences`, including empty arrays for irrelevant categories. Rows are captured
as sorted `ROW_TO_JSON(row)::TEXT` strings: source JSON text, duplicate keys,
whitespace and row multiplicity are preserved rather than normalised. Catalogue
snapshots and observations exclude framework-owned state. Declare only relevant
scope, keeping every required relationship and predecessor invariant covered.

Data contracts may additionally declare `observe` with exactly two arrays,
`rows` and `sequences`, for example:

```json
{"rows":["public.example_data"],"sequences":["public.example_data_id_seq"]}
```

Only data contracts accept this field. Both keys are required, at least one
array must be nonempty, and identities must be canonical permitted qualified
names without duplicates. An observed row relation cannot also occur in
`preserve.rows`, and an observed sequence cannot also occur in
`preserve.sequences`. Observing a relation's rows may still preserve its table
metadata through `preserve.tables`. Data contracts continue to forbid declared
object creations/replacements and require an explicit custom verifier.

Shared preparation at P saves these bounded observations under `observed`,
alongside the unchanged exact-preservation `snapshot`; without `observe`, the
observation value is `{}`. Observation uses the same exact row-text and sequence
capture machinery. It supplies predecessor evidence for precise custom outcome
checks and does not relax any `preserve` equality assertion. A verifier may parse
a copy of a row string to classify it, but comparisons of retained rows must use
the original strings and preserve multiplicity and IDs. Declare and assert each
intended row or sequence-state delta explicitly.

Catalogue scope includes relation identity/ownership, table and column privileges,
columns/defaults/comments, constraint/index definitions, routine properties and
definitions, enum labels, and sequence definition/state/ownership. Trigger and
RLS policy bodies are outside these generic snapshots; declare explicit custom
assertions when a migration affects them. A scoped snapshot does not establish
universal catalogue preservation.

The fixed `support/manifest.json` lists shared SQL dependencies whose source
fingerprints are recorded by the runner. Helpers are loaded explicitly and are excluded from standalone
suite discovery. Shared `support/upgrade_contract.sql` supplies capture and
comparison; `support/upgrade_dispatch.sql` owns positive exact TAP plans,
prepare/verify/cleanup transactions, guarded observation identity and committed
storage, and cleanup absence readback from a distinct backend. It uses the
existing guarded `framework/upgrade_lifecycle.sql` transport. Owners no longer
repeat those lifecycle phases.

Gradle runs shared preparation at P, applies only C, and verifies exact
preservation before any custom or ordinary functional verifier. Optional custom
verification runs next with `opal_phase=verify`, followed by the ordinary owning
assertion group with `opal_phase=fresh`. Both verification phases use positive
exact TAP plans and rollback. They receive `opal_assertion_group`, scenario ID,
candidate and predecessor versions, and the compact contract. All current
functional assertions still run on the latest fresh schema. At historical
boundaries, owners explicitly select compatible assertions and retain focused
earlier expectations where later dependencies or behaviour differ. Never run
future-dependent assertions at an earlier candidate or silently omit a required
boundary check. The repeat remains native zero-applied plus complete history
equality. Shared cleanup and exact target destruction follow, including after a
custom verifier fails; its native/SQL/TAP diagnostic remains a command failure.

An optional `custom` object names canonical `prepare` and/or `verify` SQL paths
under `src/dbUnitTest/upgradeCases`. The runner invokes those explicitly through
`pg_prove`, never through executable metadata or variable-selected includes.
Custom preparation requires `approved-synthetic` and evidenced approval; custom
verification declares the risk-specific transition outcomes. Custom scripts use
positive exact TAP plans and only test-owned state; fresh/functional work rolls
back, and approved preparation alone may commit. Shared observation storage and
cleanup remain framework-owned.

Alternatively, `custom.verify` may contain the reserved string `owner`. It resolves
only to that registration's declaring regular SQL file beneath `src/dbUnitTest`;
canonical path, existence and symlink checks still apply. It cannot select a
different owner or supply SQL, and `custom.prepare` cannot use this token. The
owner's `opal_phase=verify` branch loads the guarded shared payload through
`pg_temp.opal_contract_load`, using the exact contract, scenario, candidate and
predecessor identities. Bounded data observations are available in `saved.observed`
for explicit transition checks. The subsequent ordinary `opal_phase=fresh`
assertions remain rolled back; the owner does not save, commit or clean up shared
observations.

The owner is already an implicit dependency. The reserved `owner` token is not
classified as a file path and must not be added to `inputs`, nor should the owner
path be duplicated there. Ordinary custom SQL paths remain dependency inputs and
are fingerprinted; declare any further historical assertion dependencies in
`inputs`. Malformed contracts, unsupported categories, missing files, unknown or
duplicate fields, and symlink paths fail before target creation.

#### Existing registration compatibility

Genuine earlier four-field registrations retain the legacy owner phase API
during separately reviewed adaptation. An existing suite does not make a new
upgrade registration legacy; all new upgrade contracts require the compact
shared-dispatch interface above. The retained API is
`opal_phase=fresh|prepare|verify|cleanup`, `opal_scenario_id`,
`opal_candidate_version` and `opal_predecessor_version`. Their fixed
`\ir framework/upgrade_lifecycle.sql` include guards the disposable identity and
exports `pg_temp.opal_upgrade_require_identity`, `opal_upgrade_save`,
`opal_upgrade_load`, `opal_upgrade_remove` and
`opal_upgrade_absent_from_new_backend`. Legacy owner-produced JSONB observations
remain byte-preserving for embedded strings, ownership-checked and committed
between connections. Fresh/verification rollback and independent cleanup readback
remain mandatory. Preserve their functional and real-session concurrency
coverage until an independently reviewed consumer adapter replaces lifecycle
boilerplate with a compact declaration.

Framework capability does not prove consumer adoption. Record each consuming
suite's actual interface, required assertion groups, source revision and passing
fresh plus affected/full boundary execution. For data observation contracts,
retain the exact declared observation scope, shared capture/preservation phases,
custom outcome assertions, ordinary owning assertions and independently checked
shared cleanup. Existing legacy compatibility does not exempt new registrations
or permit duplicated lifecycle machinery.

The generic flat `db_upgrade_framework_pgtap_tests.sql` owns exact expected
history prefixes, successful checksummed SQL, complete predecessor row equality,
exactly one candidate, complete repeat equality and framework-state cleanup.
Its internal phases are `fresh`, `snapshot`, `predecessor`, `candidate`, `repeat`,
`cleanup`; `snapshot` records complete history for fresh repeat verification.
Native `validate` proves source checksum agreement; SHA-256 adoption checks are
not Flyway checksum comparisons.

For diagnosis only:

```bash
./gradlew dbUnitTest --no-daemon -PdbUnitTestUpgradeSuite=object_pgtap_tests.sql
```

The selector still validates all registrations globally and runs every fresh
suite in both profiles; it selects only the named owner's upgrades where that
owner's candidate belongs to the profile. Other profiles report the registration
as outside their selected locations. Unknown owners or owners with no global
registrations fail, and this diagnostic selector with `check`/`build` fails.
Automatic affected selection and explicit full mode are supported under
`check`/`build`. A diagnostic run
does not replace required affected or full replay evidence.

`./gradlew dbUnitTestFrameworkTest --no-daemon` exercises fixed framework-only
SQL/migration fixtures through the same orchestration, including native ordering,
later exclusion, durability, controlled unchanged-byte retry, phase failures,
first-profile failure followed by second-profile execution, and independent
cleanup diagnostics. Fixtures under `framework/` are fixed framework regressions,
never production migrations. Shared support and approved custom cases follow the explicit
manifest/declaration rules above; they are not discovered as fresh suites.

Reports retain unique `build/reports/dbUnitTest/<profile>/runs/<run-id>/`
directories with profile/locations, resolved Flyway runtime/image, source
fingerprints, revision/dirty paths, native command exits/timings, exact TAP
plans/executed counts and per-target phase status. Shared image preparation and
framework regression runs use the `preparation` and `framework` report directories.
Per-profile `summary.txt`, `pg-prove.log` and `framework-self-test.log` remain
latest entry points; the root `summary.txt` records the aggregate profile result.
An earlier completed report survives a later scenario or profile failure.

Target cleanup separately attempts removal, container absence and every known
owned anonymous volume's absence, even after an earlier cleanup command fails.
Unknown volume ownership or any unconfirmed absence fails closed. Cleanup is
limited to exact UUID-owned resources; it must not prune global Docker resources
or developer-owned named volumes. A cleanup error fails an otherwise successful
run. When verification also fails, retain the original primary error and all
cleanup diagnostics, including additional cleanup errors under the aggregate.
Fixed cleanup-injection regressions independently remove their actual resources
and confirm absence without turning the observed failure into PASS.

Reports distinguish discovered, selected, attempted and passed scenarios, with
selection mode, reasons, changed inputs, comparison validity and fallback reason.
Excluded unchanged or outside-profile scenarios are **Not selected**, never PASS
or upgrade N/A. Selected unexecuted phases/scenarios remain **Not run**. Framework
tests use only fixed internal injections; callers cannot inject commands,
targets or failures.

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

- Give each function or procedure one owning `<routine_name>_pgtap_tests.sql`
  suite. Keep its functional assertions, independent expected results, fixtures
  and real-session coordination together. Catalogue and behaviour checks for a
  database object also share one suite; established schema/reference ownership
  remains intact.
- Place new owning suites directly under `src/dbUnitTest`. Existing suites and
  authoritative data fixtures retain their paths unless relocation is in scope.
  Do not create a directory or phase implementation for every migration.
- Shared support lives under `support/`, loaded only through the fixed framework
  manifest; it owns lifecycle, scoped capture/preservation and cleanup. Optional
  `upgradeCases/` SQL is reserved for declared risk-specific transitions or
  approved synthetic preparation. Fixed regressions live under `framework/`.
  None of these paths is independently discovered as a fresh owning suite.
- Supply a small declaration linking each migration to its owning assertions.
  Keep compatible fresh and historical assertion groups explicit. Reuse shared
  dispatch rather than copying phase guards, observations, commits and cleanup.
  Routine fixtures and concurrency remain SQL-owned; close independent sessions
  and remove only owned records. Custom cases must not include another suite or
  take ownership of shared observation machinery.
- Run assertions and coordination through the existing Gradle-owned
  `dbUnitTest` pipeline. Do not add Python or shell database test runners,
  including ignored/generated/temporary scripts or executable runbook recipes.
  SQL suites must not use `\!`, `COPY ... PROGRAM` or equivalent shell execution.
  Unrelated metadata/documentation tooling and existing Gradle orchestration
  remain permitted. Report an unavailable required mechanism as a tooling gap.
- README documentation may sit alongside suites. Preserve existing coverage
  when adapting a consumer; framework acceptance alone does not prove it.

```text
src/dbUnitTest/
├── object_pgtap_tests.sql
├── support/manifest.json
├── support/upgrade_contract.sql
├── support/upgrade_dispatch.sql
├── support/parent_transition.sql
├── upgradeCases/                 # optional declared cases only
├── framework/                    # fixed framework regressions
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
