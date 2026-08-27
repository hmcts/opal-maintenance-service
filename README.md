# Opal Maintenance Service

Opal Maintenance Service is a Java 21 Spring Boot service responsible for Opal maintenance operations and Flyway database migrations.

## Getting Started

### Prerequisites

- [JDK 21](https://java.com)
- [Docker](https://docker.com) with Docker Compose

The repository includes the Gradle wrapper, so a separate Gradle installation is not required.

## Building and deploying the application

### Running the application

#### Environment variables

The following environment variables are required to run the service.

```bash / zsh
AAD_CLIENT_ID= <Ask Team Memebers>
AAD_CLIENT_SECRET=<Ask Team Memebers>
AAD_TENANT_ID=<Ask Team Memebers>
OPAL_TEST_USER_PASSWORD=<Ask Team Memebers>

LAUNCH_DARKLY_SDK_KEY=<Ask Team Memebers>
```

You can also create a shared .env.shred file with these variables you can use the `create_env.sh` script from opal-shared-infrastructure:
But these will only get picked up when running the application with docker.
So for local development, you will need to set these environment variables in your IDE run configuration or terminal session.
```bash / zsh
../opal-shared-infrastructure/bin/create_env.sh
```
#### Caching

When the service runs directly on the JVM from IntelliJ or Gradle, Redis-backed caching is disabled by default and the service uses a no-op cache manager. To use a Redis instance available on the host, set:

```bash / zsh
OPAL_REDIS_ENABLED=true
REDIS_CONNECTION_STRING=redis://localhost:6379
```

The standalone `docker-compose.yml` starts Redis, explicitly enables Redis-backed caching, and configures the service to use `redis://redis:6379` on the Compose network. Start the complete environment with:

```bash / zsh
docker compose up --build
```

To view the cache - when running against local Redis - Intellij has a free plugin called Redis Helper.
However, if you want to view the cache in staging the plugin doesn't support SSL. Instead, install:

```bash
brew install --cask another-redis-desktop-manager
sudo xattr -rd com.apple.quarantine /Applications/Another\ Redis\ Desktop\ Manager.app
```

To run only the standalone Redis container:

```bash / zsh
docker compose up redis
```

**WARNING** - As of 10/02/2026 the recommended docker approach is "Approach 4: Docker with external dependencies"
#### Approach 1: Dev Application (No existing dependencies)

The simplest way to run the application is using the `bootTestRun` Gradle task:

```bash / zsh
  ./gradlew bootTestRun
```

This task has no dependencies and starts up a Postgres database in Docker using [Testcontainers](https://testcontainers.com).
The database is available on `jdbc:postgresql://localhost:5432/opal-maintenance-db` with username and password `opal-maintenance`.

To persist the database between application restarts set the environment variable `TESTCONTAINERS_REUSE_ENABLE` to `true`.
Note this does **not** persist data if the Docker container is manually stopped, or through laptop restarts).

#### Approach 2: Dev Application (With existing dependencies)

Use the standard Spring Boot `run` Gradle task:

```bash / zsh
  ./gradlew run
```

This approach can be used if a database is already running and may be preferred if the lack of long-term data persistence
from the previous approach is an issue for development.

#### Approach 3: Docker

Create the image of the application by executing the following command:

```bash / zsh
  ./gradlew assemble
```

Create docker image:

**Bash**:
```bash
  docker-compose build
```
**Zsh**:
```zsh
  docker compose build
```

The assembled application boot jar is created in `build/libs`. Run it through
Docker Compose by executing the following command:

**Bash**:
```bash
  docker-compose up
```
**Zsh**:
```zsh
  docker compose up
```

To assemble the current application jar, rebuild the image, and start Docker Compose in one command, run:

```bash / zsh
./bin/run-in-docker.sh
```

For more information:

```bash / zsh
./bin/run-in-docker.sh -h
```
The script always assembles the current jar and invokes `docker compose up --build`, avoiding stale application artifacts. Use `--clean` when a clean Gradle build is required. Whenever any variable is changed or any other script regarding docker image/container build, the suggested way to ensure all is cleaned up properly is by this command:

**Bash**:
```bash
docker-compose rm
```
**Zsh**:
```zsh
docker compose rm
```

It clears stopped containers correctly. Might consider removing clutter of images too, especially the ones fiddled with:

```bash / zsh
docker images

docker image rm <image-id>
```

There is no need to remove postgres and java or similar core images.


#### Approach 4: Docker with external dependencies (e.g. Redis, postgres, azure service bus, user service, logging service, etc) - Recommended approach for development

Ensure you have pulled opal-shared-infrasturcutre as this contains scripts to support docker.

First you will need to ensure you have all repositories downloaded in the same parent direcotry.
To do this automatically you can run the following command from the opal-shared-infrastructure directory:
```bash / zsh
../opal-shared-infrastructure/bin/pull_all_repos.sh
```

Secondly you will need to ensure you have the required environment variables set up in a .env.shared file in the opal-shared-infrastructure/docker-files/ directory. You can use the following command to create this file with the required variables:
```bash / zsh
../opal-shared-infrastructure/bin/create_env.sh
```

Finally to run the application with all external dependencies using docker you can run the following command from the opal-shared-infrastructure directory:
```bash / zsh
../opal-shared-infrastructure/docker-files/scripts/opalBuild.sh -lb
```
Full details of this script and the arguments can be found within the opal-shared-infrastructure repository

* [Link to file on Github](https://github.com/hmcts/opal-shared-infrastructure/blob/master/docker-files/scripts/scripts-readme.md)
* [Link to file locally](../opal-shared-infrastructure/docker-files/scripts/scripts-readme.md)

### Verifying application startup

Check the health and Prometheus endpoints after starting the application:

```bash
curl http://localhost:4551/health
curl http://localhost:4551/prometheus
```


You should get a response similar to this:

```
  {"status":"UP","diskSpace":{"status":"UP","total":249644974080,"free":137188298752,"threshold":10485760}}
```

### Building the application

The project uses [Gradle](https://gradle.org) as a build tool. It already contains
`./gradlew` wrapper script, so there's no need to install gradle.

To build the project execute the following command:

```bash
./gradlew build
```

### Test tasks

Run individual suites when focused feedback is more useful:

```bash
./gradlew test
./gradlew integration
./gradlew functional
./gradlew smoke
```

Functional and smoke tests require a suitable running service and use `TEST_URL`, which defaults to `http://localhost:4551`. See [Testing](docs/TESTING.md) for suite details, focused commands, and evidence expectations.

### Optional Bruno diagnostic checks

The tracked [Bruno collection](bruno) provides manual health, testing-support,
and User Service requests without committing local credentials. Testing-support
endpoints are disabled by default. To enable them for a local manual check,
start the service with:

```bash
TESTING_SUPPORT_ENDPOINTS_ENABLED=true ./gradlew bootRun
```

Then create a local Bruno environment using repository-relative paths:

```bash
cd bruno
cp environments/env.bru.template environments/local.bru
```

Open `bruno` in Bruno, run health and ping, and use the User Service request
to obtain an access token only when performing the optional authenticated
diagnostic check. Keep the token in the ignored local environment file.

## Database migrations

Schema migrations are stored in `src/main/resources/db/migration/ddl`. Environment data migrations are stored under `src/main/resources/db/migration/data`.

`RUN_DB_MIGRATION_ON_STARTUP` controls whether Flyway applies migrations when the application starts. When disabled, the application verifies that all migrations have already been applied. `FLYWAY_LOCATIONS` selects which migration locations are used.

Treat committed or deployed migrations as immutable. Add a new versioned migration for subsequent database changes.

See [Database Migrations](docs/DATABASE_MIGRATIONS.md) for ownership, naming, environment scope, safe authoring, validation, and recovery guidance.

## OpenAPI

Endpoint contracts are stored under `src/main/resources/openapi`. The build bundles those documents and generates
Spring API interfaces and models before compiling the application:

Resource-specific component names are prefixed with their OpenAPI filename when bundled. For example,
`ReferenceDataItem` in `Result.yaml` becomes `ResultReferenceDataItem`. Components in `common.yaml` and `types.yaml`
retain their declared names.

```bash
./gradlew bundleOpenApi
./gradlew openApiGenerate
./gradlew compileJava
```

When the application is running, its OpenAPI documentation is available at:

- [Swagger UI](http://localhost:4551/swagger-ui/index.html)
- [OpenAPI JSON](http://localhost:4551/v3/api-docs)

## Development guidance

Follow [AGENTS.md](AGENTS.md) for repository routing and safeguards. Detailed guidance is in [Repository Guidelines](docs/REPO_GUIDELINES.md), [Testing](docs/TESTING.md), [Contributing](docs/CONTRIBUTING.md), and [Code Review Guidelines](docs/CODE_REVIEW_GUIDELINES.md).

Shared Opal Codex skills can be installed from the sibling `opal-dev-agent-skills` repository with `opal-skills install backend`. The checked-in repository documentation remains the authority for this service.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
