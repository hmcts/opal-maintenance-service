# Local development with shared infrastructure

This setup runs PostgreSQL, Redis, User Service and the other Opal dependencies
in Docker. Maintenance Service runs in IntelliJ so that code changes and
breakpoints work normally.

## Prerequisites

- JDK 21
- Docker Desktop with Docker Compose
- Azure CLI and `jq`
- Access to the `opal-stg` Key Vault and HMCTS container registry
- The following repositories cloned under the same parent directory:
  - `opal-shared-infrastructure`
  - `opal-maintenance-service`
  - `opal-user-service`
  - `opal-fines-service`
  - `opal-logging-service`
  - `opal-file-handler-service`
  - `opal-legacy-db-stub`

After cloning `opal-shared-infrastructure`, run `./bin/pull_all_repos.sh` from
that repository to clone any missing repositories into the same parent
directory.

Install Azure CLI and `jq` if needed:

```bash
brew install azure-cli jq
```

## Create the shared environment file

Sign in to Azure using your HMCTS account:

```bash
az login
```

Select `DTS-SHAREDSERVICES-STG` when prompted. From
`opal-shared-infrastructure`, create the environment file:

```bash
./bin/create_env.sh
```

This writes secrets to `docker-files/.env.shared`. The file is ignored by Git.
Do not copy its contents into tracked files or messages.

## Start the shared stack

Make sure each repository is on the branch you intend to run and is up to date.
Then run this from `opal-shared-infrastructure`:

```bash
./docker-files/scripts/opalBuild.sh -c
```

`-c` builds the current checkouts without pulling or switching branches. The
script signs Docker into the HMCTS container registry, builds the services and
starts the `opal-stack` Docker Compose project.

## Stop Maintenance Service in Docker

The Docker instance of Maintenance Service uses port `4551`, so stop it before
running the service from IntelliJ. In Docker Desktop, expand `opal-stack` and
stop `opal-maintenance-service`. Leave the other containers running.

To identify and stop it from a terminal:

```bash
docker ps \
  --filter label=com.docker.compose.project=opal-stack \
  --filter label=com.docker.compose.service=opal-maintenance-service \
  --format '{{.Names}}'

docker stop <container-name>
```

## Add the IntelliJ run configuration

In IntelliJ, open **Run → Edit Configurations**, add a **Gradle** configuration
and set:

| Setting | Value |
| --- | --- |
| Name | `Maintenance Service (local)` |
| Gradle project | `opal-maintenance-service` |
| Tasks and arguments | `run` |
| Gradle JVM | Java 21 |

Add these environment variables:

```text
OPAL_MAINTENANCE_DB_HOST=localhost
OPAL_MAINTENANCE_DB_PORT=5432
OPAL_MAINTENANCE_DB_NAME=opal-maintenance-db
OPAL_MAINTENANCE_DB_USERNAME=opal-db-user
OPAL_MAINTENANCE_DB_PASSWORD=opal-db-password
OPAL_REDIS_ENABLED=true
REDIS_CONNECTION_STRING=redis://localhost:6379
OPAL_USER_SERVICE_API_URL=http://localhost:4555
LAUNCH_DARKLY_ENABLED=false
LAUNCH_DARKLY_OFFLINE_MODE=true
```

Also copy the current values of `AAD_CLIENT_ID`, `AAD_CLIENT_SECRET` and
`AAD_TENANT_ID` from
`opal-shared-infrastructure/docker-files/.env.shared` into the run
configuration. IntelliJ does not automatically load that file.

Keep the configuration private because it contains secrets. This repository
ignores `.run` and IntelliJ workspace files.

Use the `run` task for this setup. `bootTestRun` starts separate Testcontainers
for PostgreSQL and Redis and can conflict with the shared stack on ports `5432`
and `6379`.

## Run and verify

Start or debug **Maintenance Service (local)** in IntelliJ. Flyway checks the
shared `opal-maintenance-db` database and applies any pending migrations.

Verify startup:

```bash
curl http://localhost:4551/health
```

The response should have status `UP`. The service API is available at
`http://localhost:4551`, and User Service remains available from Docker at
`http://localhost:4555`.

## Draft publication queue

Approval uses the Service Bus emulator started by the shared infrastructure stack.
Use the current shared `ServiceBus_Emulator_config.json`, which includes
`rm-publish-draft-casefile-queue`. The application defaults to that queue over
AMQP on localhost. `SERVICEBUS_RM_PUBLISH_DRAFT_CASEFILE_QUEUE_NAME` overrides the
destination; the existing `SERVICEBUS_CONNECTION_STRING`, `SERVICEBUS_PROTOCOL`,
`SERVICEBUS_SEND_TIMEOUT_MS` and `SERVICEBUS_IDLE_TIMEOUT_MS` settings control the
connection. PR deployments provision a release-prefixed queue automatically.

The base publisher sends the four-field publication message: `draft_casefile_id`,
`checker_user_id`, `originating_ip_address` and `approval_timestamp`. Approval remains
`PUBLISHING_PENDING` until the existing consumer processes it. Testing support does
not decorate the publisher, observe sends or change the consumer/transaction boundary.
Browser request count, producer invocation, broker acceptance/redelivery and a
published account are separate observations.

## Debug logging

Logging defaults to INFO. To enable DEBUG for a particular logger, use these
tasks and arguments in the IntelliJ Gradle run configuration:

```text
run --args='--logging.level.<logger-name>=DEBUG'
```

Replace `<logger-name>` with the logger name used by the class you are debugging.
Lombok's `@Slf4j(topic = ...)` sets an explicit name; otherwise it uses the fully
qualified class name. Other loggers keep their configured levels.

## Optional testing-support endpoints

For an IntelliJ or Gradle service run, enable all testing-support endpoints with:

```text
TESTING_SUPPORT_ENDPOINTS_ENABLED=true
```

The application and base Helm default is false; keep it false in production.
The same flag controls diagnostics and the dedicated draft cleanup DELETE. Normal
`./gradlew build`, `test` and `integration` commands need no new settings because
the tests supply their own configuration.

Standalone `docker compose up --build` enables testing support by default (override
with `TESTING_SUPPORT_ENDPOINTS_ENABLED=false`). The shared-stack Compose file
inherits the flag from
`opal-shared-infrastructure/docker-files/.env.shared` without overriding it.

No extra RM environment file or endpoint-specific owner variables are needed.
Cleanup uses the logged-in user's normal User Service identity, requires permission
21 in the stored draft's BU, checks the latest persisted submitter and compares the
exact stored REMO marker to `Test-Run-Reference` (`^E2E-[0-9a-f]{16}$`). Capture ID,
owning inputter and marker before UI assertions. Complete normal GET/re-entry,
version, lifecycle, snapshot and timeline assertions before after-hook DELETE.
Owned unlinked lifecycle states, approved pending drafts and eligible exclusive
published graphs are supported; shared/inconsistent/active graphs are refused.

Before enabling published cleanup in an agreed non-live environment, accept its
whole-table blocking and exclude direct polymorphic writes that bypass the baseline
helpers' same-transaction target validation. Inside the cleanup transaction,
`ACCESS EXCLUSIVE ... NOWAIT` locks cover exactly `public.respondent_accounts`,
`public.creditor_accounts` and `public.parties`, blocking unrelated reads and writes
until commit/rollback. NOWAIT bounds acquisition of those locks only, not total
request duration. Verify the actual deployed DB role can acquire them and perform
the graph reads/deletes; disposable owner-role tests do not prove those privileges.
See the [published operating contract](PUBLISHED_DRAFT_CASEFILE_CLEANUP.md).

Retain failed cleanup entries until 204. Contention/persistence unavailability can
return 503 with rollback; use bounded client retry/backoff. A 409 requires scope or
graph investigation. No publisher evidence routes, evidence schema, pool admission
aspect, automatic retry or generic SQL endpoint is supplied.

This new support lineage has no migration/procedure differences from its approved
PO-10629 base. On 28 October 2026 the user explicitly confirmed that V1_67–V1_69
were never applied to any shared or retained database; this is attestation, not a
direct database audit. The existing support branch will be updated and PR #318
retained. Shared history replacement requires separate explicit approval and a
guarded force-with-lease update. Preserve the original history; if contrary
applied-version evidence emerges, stop for an approved forward-recovery plan.
See [deployment and recovery](DRAFT_CASEFILE_TEST_CLEANUP.md#deployment-and-recovery).
Local shared-stack startup may apply Flyway migrations; it is not disposable
verification and must not be used to test history repair or cleanup against shared
data.

There is no application-level environment allowlist or deployment-environment
variable for testing support. Keep the shared flag disabled in production deployment
configuration, following Fines. Gradle/IntelliJ do not automatically load
`.env.shared`; set the shared enablement flag in your shell/private run configuration.
See the [cleanup guide](DRAFT_CASEFILE_TEST_CLEANUP.md) for the full contract.

See the Draft Casefile
[functional prerequisites](TESTING.md#draft-casefile-deployed-api-journeys-po-10287)
for the required users, reference data, marker and cleanup header.

## Common problems

- **Port 4551 is already in use:** stop the Docker Maintenance Service container
  or another local Maintenance process.
- **Ports 5432 or 6379 are already in use:** stop any standalone or
  Testcontainers PostgreSQL and Redis instances before starting the shared
  stack.
- **Container registry login fails:** confirm Azure CLI is signed in. You may
  need to pause Zscaler Internet Security while the script connects to
  `hmctsprod.azurecr.io`; re-enable it after the build.
- **Authentication returns 401:** regenerate `.env.shared`, update the three
  `AAD_*` values in IntelliJ and restart Maintenance Service.

When returning to the fully containerised stack, stop Maintenance Service in
IntelliJ and restart its container in Docker Desktop.
