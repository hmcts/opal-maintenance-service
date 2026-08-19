# Code Review Guidelines

## Review objective

Review the changed code and affected behavior. Report only concrete
correctness, security, data, operational, or delivery risks introduced or
worsened by the change. Ignore deterministic formatting and unsupported
implementation preferences.

## Severity

- **P0 critical:** widespread or irreversible harm, sensitive-data exposure,
  or critical compromise.
- **P1 high:** supported behavior, security, data integrity, migration safety,
  or deployment is materially broken.
- **P2 medium:** a reproducible material defect with limited impact.

Optional improvements are not findings unless advisory feedback was requested.

## Backend review checks

- Request and response correctness, validation, exception mapping, and HTTP
  semantics.
- Transaction boundaries, persistence fetch behavior, query count, locking,
  and data integrity.
- Flyway ordering, immutability, environment scope, deployment compatibility,
  and the safety checks in [Database Migrations](DATABASE_MIGRATIONS.md).
- Secret handling, log safety, configuration defaults, operational endpoints,
  and dependency suppressions.
- Test coverage for likely regressions and evidence for required checks.

## Acceptable exceptions

Do not report existing legacy structure outside the change, justified patterns
required by integrations, mechanical documentation changes without behavior
risk, or maintainability preferences without a concrete defect.

## Review output

Order findings by severity. Each finding must include its severity, concise
title, smallest useful line range, triggering scenario, impact, and practical
correction. Explicitly state when no qualifying findings exist, and separate
unverified assumptions from findings.
