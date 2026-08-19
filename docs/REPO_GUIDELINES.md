# Repository Guidelines

This document is the authoritative source for implementation standards in
`opal-maintenance-service`. When executable configuration disagrees with a
documented fact, executable configuration wins; correct the documentation in
the same change.

## Project structure

- Keep production Java under `src/main/java`. Follow the repository's existing
  package structure and mirror production packages in the applicable test
  source set.
- Keep HTTP controllers under `controllers`, Spring configuration under
  `config`, and Flyway startup behaviour under `config/db/migration`. Place new
  code with the feature or responsibility that owns it rather than creating a
  broad utility package.
- Keep runtime configuration and bundled resources under `src/main/resources`.
- Keep schema migrations in `src/main/resources/db/migration/ddl` and
  environment data in `src/main/resources/db/migration/data/{allEnvs,demo,dev,ithc,nle,perfTest,stg}`.
- Use `src/test/java` for unit tests, `src/integrationTest/java` for
  Spring/database integration tests, `src/functionalTest/java` for functional
  HTTP tests, and `src/smokeTest/java` for smoke tests.
- Keep Helm deployment configuration under `charts/`, quality and security-tool
  configuration under `config/`, supporting assets under `lib/`, and local or
  container helpers under `bin/`.
- Match nearby maintained package, class, method, configuration-property,
  migration, and test naming. Do not introduce an abbreviation without an
  established repository or domain precedent.

## Toolchain and commands

Use Java 21 and the checked-in Gradle wrapper. Treat `build.gradle` and the
wrapper configuration as authoritative for tool and dependency versions.

- Run unit tests: `./gradlew test`
- Run integration tests: `./gradlew integration`
- Run baseline validation: `./gradlew build`
- Run functional tests: `./gradlew functional`
- Run smoke tests: `./gradlew smoke`
- Produce coverage: `./gradlew jacocoTestReport`
- Run focused static analysis: `./gradlew checkstyleMain` and `./gradlew pmdMain`
- Start the local service and PostgreSQL: `docker compose up --build`

`build` includes the configured unit, integration, static-analysis, and
packaging checks; Docker must be available for Testcontainers-backed integration
tests. Functional and smoke tests require a suitable running service. Follow
[Testing](TESTING.md) for suite semantics, prerequisites, focused commands, and
evidence requirements. Do not treat compilation, task configuration, or a
command that did not exercise changed behaviour as sufficient validation.

## Formatting and naming

- Follow `.editorconfig` and the Checkstyle and PMD rules under `config/`.
- Use four-space Java indentation and the configured 120-character line limit.
- Do not use wildcard imports. Keep imports in the configured third-party,
  standard Java, and static groups.
- Keep one top-level Java type per file and use descriptive UpperCamelCase type
  names and lowerCamelCase member, parameter, and local-variable names.
- Keep production and test packages aligned, and name JUnit classes `*Test`.
- Do not suppress compiler, Checkstyle, PMD, test, or coverage findings merely
  to make a check pass. Scope an unavoidable suppression to the smallest useful
  target and document why it is safe.

## Java and Spring Boot

- Use the Java and Spring Boot versions installed by the repository; do not
  target unavailable or unreleased framework features.
- Prefer constructor injection for required collaborators and method-parameter
  injection in configuration classes. Avoid field injection in production code.
- Keep the standard application flow from controller to service to repository.
  Controllers own HTTP translation, services own orchestration and transaction
  boundaries, and repositories own persistence.
- Keep controller-facing request and response models separate from persistence,
  legacy, and downstream-client models. Map deliberately when data crosses a
  layer or integration boundary.
- Keep Spring configuration explicit and narrowly scoped. Preserve conditional
  behaviour and environment-variable overrides when changing beans or
  properties.
- Prefer explicit, compile-time-safe types and immutable inputs where practical.
  Do not introduce deprecated API usage as normal implementation practice.
  Handle expected failures precisely; do not catch or convert exceptions
  without preserving useful context and the intended HTTP or startup behaviour.
- Keep public behaviour observable and deterministic. Avoid static mutable state,
  hidden network calls, and work performed as a side effect of object creation.

## HTTP and OpenAPI

- Preserve the root `GET /` endpoint unless deployment configuration changes
  with it; Azure App Service uses it for Always On requests.
- Keep `/`, `/health`, `/prometheus`, Swagger UI, and OpenAPI endpoints public.
  All other application endpoints must require authentication by default.
  When testing-support diagnostics are explicitly enabled, keep ping public and
  require authentication for the auth-check endpoint.
- Use Spring MVC response types and status codes that accurately describe the
  outcome. Validate untrusted request data at the HTTP boundary.
- Keep externally visible contracts explicit and do not expose persistence
  entities as API models.
- Update OpenAPI metadata or contract coverage when an HTTP contract changes.
  Keep `springdoc.packagesToScan` aligned with the packages that own controllers.

## Persistence and transactions

- Use the configured datasource and transaction manager rather than creating
  independent connections or transaction infrastructure.
- Put transaction boundaries around complete service operations and use
  read-only transactions for read flows where appropriate.
- Keep database access out of controllers. Make query, locking, and failure
  behaviour explicit at the persistence boundary.
- Default new JPA associations to lazy loading and fetch the graph required by
  each use case deliberately. Avoid unbounded reads and accidental per-row query
  patterns.
- Preserve PostgreSQL numeric widths through entities, DTOs, API contracts, and
  tests: `smallint` normally maps to `Short`, `integer` to `Integer`, and
  `bigint` to `Long`. Verify a genuine boundary or compatibility requirement
  before adding numeric or string conversion glue.

## Flyway migrations

- Treat every committed or deployed migration as immutable. Correct an applied
  migration with a later forward migration; never edit, rename, delete, or
  renumber it.
- Allocate migration versions across the complete migration tree, not separately
  within each environment directory.
- Keep schema changes in `ddl`. Put data only in `allEnvs` or the named
  environment directory whose deployment scope requires it.
- Preserve the `RUN_DB_MIGRATION_ON_STARTUP` contract: when enabled, startup
  applies migrations; when disabled, startup must fail if a migration is
  pending.
- Assess compatibility, locks, table rewrites, data volume, environment scope,
  and recovery before authoring a migration.
- Follow [Database Migrations](DATABASE_MIGRATIONS.md) for naming, version
  discovery, connection safety, validation, and release evidence.

## Configuration and operations

- Keep safe local defaults in `application.yaml` and preserve environment or
  mounted-secret overrides for deployed values. Do not hard-code an
  environment-specific hostname, credential, or secret.
- Keep the service port configurable; the local default is `4551`.
- Preserve the configured `/health` and `/prometheus` management endpoints and
  verify operational behaviour when changing Actuator or server configuration.
- Keep Helm values and application configuration aligned. Document new or
  changed environment variables, defaults, secret requirements, and rollout
  implications.
- Use structured, useful logging at appropriate levels. Never log credentials,
  connection strings, access tokens, personal data, or complete sensitive
  payloads.

## Testing

- Add or update tests for changed logic, validation, configuration, error paths,
  migration behaviour, and regression-prone boundaries.
- Use the most focused level that proves the behaviour: unit, integration,
  functional, or smoke. Do not replace focused coverage with a broader test that
  cannot isolate the expected outcome.
- Keep unit tests independent of Docker, PostgreSQL, and external services.
- Use the existing PostgreSQL 17 Testcontainers setup for database-backed
  integration behaviour; do not assume a developer-owned database state.
- Functional and smoke tests use `TEST_URL`, defaulting to
  `http://localhost:4551`, and require a suitable running service.
- Assert observable behaviour rather than implementation details. Use real DTOs,
  value objects, and other simple data carriers in tests; reserve mocks for
  collaborators and external boundaries.
- Record manual scenarios when automated checks do not execute the changed
  behaviour, and state every skipped relevant check with its reason.

## Security and dependencies

- Never add secrets, credentials, tokens, personal data, or production-derived
  records to code, configuration, migrations, logs, comments, fixtures, tests,
  screenshots, or validation evidence.
- Validate untrusted input before using it in SQL, paths, URLs, logs, or other
  sensitive sinks. Prefer parameterised persistence APIs.
- Do not weaken authentication, authorisation, transport, dependency, static
  analysis, or platform security controls without explicit ticket scope and
  review evidence.
- Do not change dependencies or generated dependency state unless the task
  requires it. Reuse the versions and libraries already managed by the build.
- When adding or revising a CVE suppression, include its identifier, rationale,
  narrow scope, explicit expiry date, and mitigating controls.

## Maintainability

- Keep changes focused on the ticket and its Acceptance Criteria. Preserve
  existing behaviour unless the ticket requires a change.
- Follow nearby maintained patterns before introducing a new abstraction.
- Avoid unrelated refactoring, speculative generalisation, duplicated logic,
  broad shared state, and unnecessary dependencies.
- Keep classes and methods focused on one clear responsibility. Explain any
  unavoidable increase in complexity, dependency footprint, configuration
  surface, or public API in the pull request.

## Documentation and delivery

- Update the README or supporting documentation when behaviour, configuration,
  commands, integrations, migrations, or workflows change.
- Follow [Contributing](CONTRIBUTING.md) for branches, commits, pull requests,
  approvals, and testing evidence.
- Identify migration, configuration, secret, deployment-order, compatibility,
  and operational implications in the implementation handoff and pull request.
- Report exact verification commands and results. List relevant checks not run
  and explain why; do not claim an external environment or deployment was
  validated unless it actually was.
