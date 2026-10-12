# Contributing

This document is the canonical contribution workflow for this repository. Use
the [Common Definition of Done](COMMON_DEFINITION_OF_DONE.md) before handing
work over for human review, together with each applicable
[Backend](BACKEND_DEFINITION_OF_DONE.md) and
[Database](DATABASE_DEFINITION_OF_DONE.md) supplement.

## Design and planning evidence

Repository standards apply before a design or implementation plan is approved,
and again before execution. Read the applicable implementation, testing,
database, OpenAPI, review, and Definition of Done guidance for the affected
scope. Generic skill templates do not replace these requirements.

Reconcile the selected ticket and Acceptance Criteria, confirmed decisions,
context source revisions, and intended implementation baseline. Record the
inspected revisions and relevant dirty state, distinguish the current checkout
from any separately inspected foundation, and identify material changes since
the preceding context, design, or plan. Read-only context collection retains
its own evidence boundaries; current application-code drift is assessed during
design and planning.

Carry requirements and unresolved conflicts into each subsequent artifact.
Record the old and current requirement, its source, and the agreed resolution
or outstanding decision. An earlier readiness result, approved design, legacy
test suffix, or maintained example does not establish current compliance or
authorize an exception to repository standards. Reconcile conflicting ticket
requirements explicitly before implementing the affected work.

For each Acceptance Criterion and material repository requirement, identify
the design decision, implementation task, planned verification, and delivery
evidence. Confirm that the maintained framework can execute the proposed
checks. Follow [routine testing and framework-gap handling](TESTING.md#routine-suites-and-framework-gaps)
for database coverage; unsupported required checks remain explicit unmet
requirements.

Identify the agreed scope and delivery owner for API or backend work discovered
during database planning. Track separately owned dependencies and consumer
alignment without silently expanding the database ticket or assuming upstream
validation exists. A comparable service provides precedent, not authority for
different domain behaviour.

Design and plan self-review must check current source evidence and applicable
repository standards as well as internal consistency and spec coverage. Carry
the same evidence and constraints into delegated review and implementation
briefs, including when work moves to another worktree.

## Branches

Use the Jira key as the branch identifier for ticketed work, for example
`PO-1234`. An execution environment may require a namespace, such as
`codex/PO-1234`. Use short kebab-case names for non-ticket maintenance.

## Commits

Use Conventional Commits:
`<type>(<optional-scope>): <imperative summary>`.

Accepted types are `feat`, `fix`, `test`, `docs`, `refactor`, `chore`, and
`ci`. Keep the subject to a maximum of 72 characters and never include
sensitive information in a commit message.

## Pull requests

Keep pull requests focused on the agreed scope. For ticketed work, include a
Jira link and map each delivered Acceptance Criterion to its implementation and
verification evidence. Include testing evidence and a security assessment,
along with any breaking, migration, configuration, compatibility, deployment,
or operational impact.

## Testing evidence

Record the exact commands and results, the environment used, and manual
scenarios exercised. For every relevant check not run, record the reason, the
scenario, the setup needed to execute it, and the expected result. Include
operational evidence where it is relevant to the change.

## Review and QA

Complete the repository-required agent review before handoff. Technically
validate agent and human feedback, resolve validated blocking findings, and
repeat verification affected by review changes. At least two reviewers must
approve before merge. Obtain QA sign-off where the ticket or release process
requires it.

## Pull request template

Use the following headings and checklist when preparing a pull request; they
match [the GitHub pull request template](../.github/PULL_REQUEST_TEMPLATE.md).

### Jira link

Provide the Jira key and link.

### Change description

Describe the change and map each applicable Acceptance Criterion to its
implementation and verification evidence.

### Testing done

List exact commands and results, manual scenarios, environment, and checks not
run with their reasons.

### Human verification and limitations

For each check requiring a human or unavailable environment, account,
permission, or specialist tool, list the scenario, required setup, and expected
result. Disclose known limitations, assumptions, and non-blocking follow-up
work.

### Breaking change

State any breaking, migration, configuration, compatibility, deployment-order,
rollout, rollback, or operational impact.

### Security Vulnerability Assessment

Describe the security assessment and any CVE suppressions with their rationale.

### Checklist

- [ ] Acceptance Criteria are addressed and mapped to evidence.
- [ ] Commits follow the contribution convention.
- [ ] Documentation is updated where needed.
- [ ] Tests cover the affected behaviour where needed.
- [ ] Applicable database changes identify created, updated, or sufficient
  unchanged pgTAP coverage, or a justified DB-04 no-assertion decision, and
  include `./gradlew dbUnitTest` evidence.
- [ ] Testing evidence is complete, including relevant checks not run.
- [ ] Human-only verification, limitations, assumptions, and follow-up work are disclosed.
- [ ] Agent review is complete, blocking findings are resolved, and affected checks were repeated.
- [ ] A security assessment is included.
- [ ] Breaking changes are described.
- [ ] Flyway, configuration, deployment, or operational impact is described.
- [ ] Sensitive-data handling has been reviewed.
