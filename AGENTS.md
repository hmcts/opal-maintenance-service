# Repository instructions

Opal Maintenance Service is a Java 21 Spring Boot service that runs Flyway migrations against PostgreSQL and exposes health and Prometheus endpoints.

The default local port is `4551`; configured endpoints are `/health` and `/prometheus`.

## Before making changes

- Read the ticket and Acceptance Criteria when present.
- Inspect `git status` and preserve unrelated work.
- When branch creation is part of the workflow, use a dedicated branch as described in [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md).
- Route implementation to
  [docs/REPO_GUIDELINES.md](docs/REPO_GUIDELINES.md), testing to
  [docs/TESTING.md](docs/TESTING.md), external functional and smoke testing to
  [docs/E2E_TESTING.md](docs/E2E_TESTING.md), database and Flyway work to
  [docs/DATABASE_MIGRATIONS.md](docs/DATABASE_MIGRATIONS.md), contribution work
  to [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md), and review work to
  [docs/CODE_REVIEW_GUIDELINES.md](docs/CODE_REVIEW_GUIDELINES.md).

## Always

- Keep changes focused, preserve behaviour, follow nearby maintained patterns, and avoid speculative abstractions and unrelated refactors.
- Never add secrets, credentials, tokens, or PII to code, configuration, logs, comments, fixtures, evidence, or tests.
- Treat applied Flyway migrations as immutable.
- Add or update relevant tests and documentation.
- Do not change dependencies unless required.
- Do not force-add ignored files with `git add -f` or `git add --force` unless the user explicitly approves adding that specific file.
- Treat Superpowers design and implementation-plan artifacts as local-only. Keep them under ignored `docs/superpowers/` paths. Never stage, force-add, commit, or relocate them into a tracked path to bypass ignore rules unless the user explicitly requests it.

## Commands

- `./gradlew test`
- `./gradlew integration`
- `./gradlew build`
- `./gradlew functional`
- `./gradlew smoke`
- `./gradlew jacocoTestReport`
- `docker compose up --build`

See [docs/TESTING.md](docs/TESTING.md) for test selection and general standards,
and [docs/E2E_TESTING.md](docs/E2E_TESTING.md) for functional and smoke suite
semantics.

## Code review rules

Use both [docs/CODE_REVIEW_GUIDELINES.md](docs/CODE_REVIEW_GUIDELINES.md) and [docs/REPO_GUIDELINES.md](docs/REPO_GUIDELINES.md). Report concrete changed-code defects using the smallest useful ranges and impact-based severity. Treat preferences as advisory feedback rather than findings.

## Task-specific workflows

Use an available task-specific skill when its description matches the requested work.

Supporting repository documents remain authoritative when a relevant skill is unavailable.

## Verification and handoff

- Review the final diff and run proportionate checks.
- Report exact commands and results, and list checks not run with reasons.
- Record configuration or migration implications.
- Do not claim unverified external steps.

## Definition of Done

Before handoff, use the repository's authoritative
[Backend Definition of Done](docs/BACKEND_DEFINITION_OF_DONE.md). Every
applicable agent-executable criterion must pass, and every item marked **Not
applicable** must have a recorded reason. If an applicable criterion remains
unmet, report **Not Agent Complete** with the unmet criterion and required
remediation; do not claim the work is ready for human review.
