# Repository Guidelines

## Authority and scope

This document is authoritative for implementation in `opal-maintenance-service`. When executable configuration disagrees with a documented fact, executable configuration wins; correct the contradiction in the documentation.

## Project structure

- `src/main/java` contains application code; `src/main/resources` contains runtime configuration and resources.
- `src/main/resources/db/migration/ddl` contains schema migrations. Environment data is under `src/main/resources/db/migration/data/{allEnvs,demo,dev,ithc,nle,perfTest,stg}`.
- Test source sets are `src/test/java`, `src/integrationTest/java`, `src/functionalTest/java`, and `src/smokeTest/java`.
- `charts/` contains Helm chart configuration; `config/` contains quality and security-tool configuration; `lib/` contains bundled supporting assets; `bin/` contains local and container helper scripts.

## Toolchain and commands

Use Java 21 and the Gradle wrapper. Common commands are `./gradlew test`, `./gradlew integration`, `./gradlew build`, `./gradlew functional`, `./gradlew smoke`, `./gradlew jacocoTestReport`, and `docker compose up --build`. See [Testing](TESTING.md) for detailed test behaviour.

## Java and Spring Boot

Follow the versions declared in `build.gradle`. Keep controllers focused on HTTP translation; move business or persistence logic into focused collaborators when introduced. Prefer constructor injection, explicit types, immutable inputs where practical, and precise exception handling. Follow configured Checkstyle and PMD rather than duplicating formatting rules.

## Persistence and transactions

When persistence is introduced, put transaction boundaries around service operations and use read-only transactions for read flows where appropriate. Do not expose persistence entities directly as external API contracts. Default new JPA associations to lazy loading and fetch explicitly for use cases that need richer graphs.

## Flyway migrations

Treat committed or deployed migrations as immutable; add a new versioned migration for later schema changes. Keep schema changes in `ddl` and use the established environment data locations intentionally. Make migration ordering, rollback implications, and environment scope explicit in PR evidence.

## Configuration and operations

Keep secrets in environment or platform secret stores, never source control or logs. Preserve environment-variable overrides and safe local defaults. Use `/health` and `/prometheus` for configured operational endpoints. Do not log credentials, connection strings, tokens, or personal data.

## Security and dependencies

Validate untrusted input at boundaries. Do not weaken security controls or suppress vulnerabilities without ticket scope, rationale, and mitigating controls. Do not change dependency or lock state unless required by the task.

## Maintainability and documentation

Keep changes tied to Acceptance Criteria and preserve behaviour unless the ticket requires a change. Avoid unrelated refactors, speculative abstractions, and unnecessary dependencies. Update the README or supporting documents when configuration, behaviour, integrations, or workflows change.
