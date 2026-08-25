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

Create the local environment file from the tracked example before using Docker Compose:

```bash
cp .env.example .env
```

The local `.env` file is ignored by Git. The example sets `SERVER_PORT=4551`, which Docker Compose uses for the service port mapping.

Application configuration can be overridden with the following environment variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `OPAL_MAINTENANCE_DB_HOST` | `localhost` | PostgreSQL host |
| `OPAL_MAINTENANCE_DB_PORT` | `5432` | PostgreSQL port |
| `OPAL_MAINTENANCE_DB_NAME` | `opal-maintenance-db` | Database name |
| `OPAL_MAINTENANCE_DB_USERNAME` | `opal-maintenance` | Database username |
| `OPAL_MAINTENANCE_DB_PASSWORD` | `opal-maintenance` | Database password |
| `OPAL_MAINTENANCE_DB_OPTIONS` | empty | Additional JDBC connection options |
| `RUN_DB_MIGRATION_ON_STARTUP` | `true` | Run Flyway migrations when the service starts |
| `FLYWAY_LOCATIONS` | configured migration locations | Select the Flyway migration locations |
| `AAD_TENANT_ID` | `00000000-0000-0000-0000-000000000000` | Azure Active Directory tenant identifier |
| `AAD_CLIENT_ID` | `00000000-0000-0000-0000-000000000000` | Azure Active Directory application identifier |
| `AAD_CLIENT_SECRET` | empty | Azure Active Directory application secret |
| `OPAL_USER_SERVICE_API_URL` | `http://localhost:4555` | User Service base URL |
| `REDIS_CONNECTION_STRING` | `redis://localhost:6379` | Redis connection URL |
| `OPAL_REDIS_ENABLED` | `false` | Enable Redis-backed health and caching support |
| `TESTING_SUPPORT_ENDPOINTS_ENABLED` | `false` | Enable testing-support diagnostic endpoints |
| `SERVICEBUS_LOGGING_PDPL_PROTOCOL` | `amqp` | PDPL Service Bus transport protocol |
| `SERVICEBUS_CONNECTION_STRING` | empty | PDPL Service Bus connection string |
| `SERVICEBUS_LOGGING_PDPL_QUEUE_NAME` | `logging-pdpl` | PDPL Service Bus queue name |

Do not commit credentials or other secrets. Supply non-local values through environment or platform secret stores.

#### Approach 1: Docker Compose (recommended)

Start the service and PostgreSQL together:

```bash
docker compose up --build
```

To stop the environment, press `Ctrl+C`, then remove the containers with:

```bash
docker compose down
```

#### Approach 2: Run the application on the local JVM

Start PostgreSQL in Docker:

```bash
docker compose up -d opal-maintenance-db
```

The container's PostgreSQL port is published on host port `5435`. Start the application against it with:

```bash
OPAL_MAINTENANCE_DB_PORT=5435 ./gradlew bootRun
```

### Verifying application startup

Check the health and Prometheus endpoints after starting the application:

```bash
curl http://localhost:4551/health
curl http://localhost:4551/prometheus
```

The health response should report an `UP` status.

### Building the application

Build and run the baseline validation with:

```bash
./gradlew build
```

The build includes unit, integration, static-analysis, and packaging checks configured by the project. Docker is required because the integration tests use Testcontainers PostgreSQL.

### Test tasks

Run individual suites when focused feedback is more useful:

```bash
./gradlew test
./gradlew integration
./gradlew functional
./gradlew smoke
```

Functional and smoke tests require a suitable running service and use
`TEST_URL`, which defaults to `http://localhost:4551`. See
[Testing](docs/TESTING.md) for suite selection and general standards, and
[End-to-end Testing](docs/E2E_TESTING.md) for external-suite setup, authoring,
and evidence expectations.

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
