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

Add this environment variable only when testing Maintenance Service's
testing-support endpoints:

```text
TESTING_SUPPORT_ENDPOINTS_ENABLED=true
```

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
