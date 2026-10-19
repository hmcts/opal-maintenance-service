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

## Design and implementation-plan review

Use [Design and planning evidence](CONTRIBUTING.md#design-and-planning-evidence)
and [Required prerequisite delivery](CONTRIBUTING.md#required-prerequisite-delivery)
to check every Acceptance Criterion and mandatory repository requirement has
a concrete route to completion, separately from assessing the proposed code.

- Verification uses a currently supported mechanism, or an enabling task or
  linked work package defines the missing capability, ownership, sequencing,
  consumer integration and acceptance evidence.
- Separately owned work retains its agreed scope. Missing prerequisites are
  explicitly identified; independent work and blocked delivery steps are
  distinguished without claiming unsupported execution or completion.
- Review records the remaining prerequisite delivery and consumer evidence.
  A sound routine design or absence of SQL findings does not establish that
  the full delivery plan is executable or that the ticket is complete.

Report an unspecified mandatory completion route as a delivery finding when
reviewing a plan intended to cover the whole delivery. A future check with a
concrete task, dependency and required evidence is not a defect merely because
the implementation has not yet run it.

## Backend review checks

- Request and response correctness, validation, exception mapping, and HTTP
  semantics.
- Transaction boundaries, persistence fetch behavior, query count, locking,
  and data integrity.
- Flyway ordering, immutability, environment scope, deployment compatibility,
  and the safety checks in [Database Migrations](DATABASE_MIGRATIONS.md).
  Check [migration header authors](DATABASE_MIGRATIONS.md#required-header-fields)
  identify the confirmed responsible human contributor rather than an agent.
- Secret handling, log safety, configuration defaults, operational endpoints,
  and dependency suppressions.
- Test coverage for likely regressions and evidence for required checks.
- Check [SQL layout](DATABASE_MIGRATIONS.md#sql-readability),
  [pgTAP file headers](TESTING.md#pgtap-file-headers), and
  [pgTAP scenario introductions](TESTING.md#pgtap-scenario-introductions),
  including responsible human authors, matching scenario separators,
  unchanged definitions, authoritative comment wording, assertion
  descriptions, and accurate fixture dependencies and expected outcomes.
  Formatting alone remains outside defect findings under the review objective.

## Database review checks

For database designs and implementation plans, apply the
[general plan-review checks](#design-and-implementation-plan-review) and verify
the applicable migration, SQL-testing and upgrade requirements. Work affecting
both backend and database concerns must satisfy both sets of relevant review
checks.

Use the [routine responsibility contract](DATABASE_MIGRATIONS.md#planned-db-06-stored-procedure-responsibility-contract),
[routine LLD guidance](DATABASE_MIGRATIONS.md#routine-lld-documentation), and
[Testing](TESTING.md#routine-suites-and-framework-gaps) to check the following
against the changed contract and its delivery evidence:

- The routine implements its ticketed database responsibility, with any
  backend/API or UI work separately identified and owned. Detailed request
  validation has an evidenced owner; moving a rule out of SQL requires verified
  coverage before the relevant database call. A rule in design collateral or a
  precedent from another service alone does not prove its execution layer.
- Database integrity and mapping rules remain enforced, including relationships
  that an existing constraint cannot express. Any explicit check that duplicates
  a constraint or native PostgreSQL failure has a concrete contract reason;
  simplification preserves the required SQLSTATE, diagnostic context, atomicity,
  and caller behaviour. Failures propagate rather than becoming successful
  results.
- Parameters, outputs, affected rows, transaction ownership, run-status
  ownership, locks, retry behaviour, and compatibility match the agreed routine
  scope. Additional guards, locks, or cross-layer changes need evidence of the
  supported scenario and owner, rather than a speculative requirement.
- Each routine has one self-contained owning suite under the authoritative
  [pgTAP suite layout](TESTING.md#pgtap-suite-layout), with catalogue and
  behavioural assertions, fixtures, test-only SQL helpers, and cleanup.
  Database assertions and test coordination stay in SQL/pgTAP and run through
  the existing Gradle-owned `dbUnitTest` framework. New suites are directly
  under `src/dbUnitTest`, with no new subdirectories or separate support SQL;
  existing paths remain unless relocation is explicitly in scope.
  Consolidation retains all applicable coverage and uses existing discovery.
  Do not introduce separate Python or shell database test runners, including
  temporary, ignored, or generated scripts and executable runbook recipes.
- Required upgrade or multiple-session concurrency coverage identifies an
  actual supported mechanism and execution evidence. Concurrency may be
  coordinated inside the owning SQL/pgTAP suite, including test-only `dblink`,
  through `dbUnitTest`; a separate Gradle hook is not inherently required.
  Missing predecessor or SQL session-coordination capability is recorded as a tooling gap
  with its owner and agreed separately scoped remediation; required coverage
  remains unmet until verified.
- Required database LLD, object, interaction, and ownership evidence reflects
  the delivered implementation and points to the actual reviewed source and revision.
  Report completed external publication or approval only with direct evidence.

Apply the impact-based severity rules above. Record a concrete changed-code or
delivery defect when the gap breaks a required contract; keep preferences and
unsupported simplification suggestions advisory.

## Acceptable exceptions

Do not report existing legacy structure outside the change, justified patterns
required by integrations, mechanical documentation changes without behavior
risk, or maintainability preferences without a concrete defect.

## Review output

Order findings by severity. Each finding must include its severity, concise
title, smallest useful line range, triggering scenario, impact, and practical
correction. Explicitly state when no qualifying findings exist, and separate
unverified assumptions from findings.
