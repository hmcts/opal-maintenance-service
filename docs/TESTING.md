# Testing

## Test levels

- **Unit:** `src/test/java`; run `./gradlew test`. A well-isolated unit test needs no external service.
- **Integration:** `src/integrationTest/java`; run `./gradlew integration`. These tests use a Spring context and Testcontainers PostgreSQL 17, so Docker is required for container-backed tests.
- **Functional:** `src/functionalTest/java`; run `./gradlew functional`. External HTTP checks use `TEST_URL`, defaulting to `http://localhost:4551`; they require a suitable running service.
- **Smoke:** `src/smokeTest/java`; run `./gradlew smoke`. External HTTP checks use the same `TEST_URL` default and require a running service.

## Baseline and focused commands

`./gradlew build` is the baseline validation. In this repository, `check` depends on `integration`. Run focused tests with `./gradlew test --tests 'fully.qualified.Pattern'` or `./gradlew integration --tests 'fully.qualified.Pattern'`. Focused quality commands are `./gradlew checkstyleMain`, `./gradlew pmdMain`, and `./gradlew jacocoTestReport`.

## Test design

Mirror production packages, use `*Test`, and assert observable behaviour. Cover validation, error, empty, and configuration paths affected by a change. Keep Testcontainers and network boundaries explicit; do not make unit tests depend on them.

Authentication integration tests generate their own JWTs at runtime and use
WireMock for User Service responses. They do not require a real AAD tenant or
User Service. The Bruno collection is a separate, optional manual check for a
real AAD/User Service setup; enable testing-support endpoints explicitly with
`TESTING_SUPPORT_ENDPOINTS_ENABLED=true` before using its ping or authenticated
diagnostic requests. Never place a bearer value in a tracked Bruno file.

## Infrastructure and evidence

Integration tests need Docker for Testcontainers. HTTP functional and smoke checks need a running service. Record exact commands, results, manual scenarios, and reasons for skipped checks. A successful pipeline is not evidence that every changed scenario ran.

For Flyway or SQL changes, follow the fresh-database, upgrade-path, database-boundary, and evidence requirements in [Database Migrations](DATABASE_MIGRATIONS.md).
