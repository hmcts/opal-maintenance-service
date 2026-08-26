# Agent Definition of Done – Common

## Authority and applicability

This Definition of Done applies to every change in this repository.

Apply the relevant supplement as well when a change affects
[backend/application concerns](BACKEND_DEFINITION_OF_DONE.md),
[database concerns](DATABASE_DEFINITION_OF_DONE.md), or both.

A change may use this document on its own only when it affects neither
backend/application nor database concerns. File category must not be used to
exclude a supplement. If a change affects either area, every relevant
supplement is mandatory, including for documentation, build or dependency
management, CI/CD, Docker, Helm, and repository-tooling changes.

A change is **Ready for human review** when every applicable criterion below
and in every applicable supplement is satisfied.

## Scope and correctness

- [ ] Every applicable ticket Acceptance Criterion is implemented.
- [ ] Every Acceptance Criterion is mapped to its implementation and
  verification evidence.
- [ ] The implemented behaviour matches the approved ticket scope.
- [ ] No known blocking functional or operational defect remains.

## Code and supporting artefacts

- [ ] The final change contains only intended, ticket-related modifications.
- [ ] Unrelated pre-existing work has been preserved.
- [ ] Required automated tests are present and updated for the changed
  behaviour.
- [ ] Documentation, OpenAPI metadata, configuration, Helm values, and
  operational guidance affected by the change are current.
- [ ] No temporary code, debugging output, obsolete comments, or unintended
  generated files remain.
- [ ] No dependency or generated dependency state has changed unless the ticket
  requires it.

## Verification

- [ ] All agent-executable checks required by [Testing](TESTING.md) and the
  changed area pass against the final change.
- [ ] Focused tests prove the changed behaviour, and the repository baseline
  validation has been run when proportionate to the change.
- [ ] Verification evidence records the exact commands, environment, and
  results.
- [ ] No failed required check remains unresolved.
- [ ] Checks requiring an unavailable environment, account, permission,
  specialist tool, or human action are listed with the scenario, required
  setup, and expected result.

## Configuration and operations

- [ ] Configuration defaults, environment-variable overrides, mounted secrets,
  and Helm values remain aligned.
- [ ] Deployment order, compatibility, rollout, rollback, and operational
  implications are recorded where relevant.

## Security and privacy

- [ ] The final change contains no exposed secret, credential, token, PII, or
  unintended sensitive information.
- [ ] Authentication, authorisation, input validation, transport, dependency,
  static-analysis, and platform controls have not been weakened without
  explicit scope and evidence.
- [ ] Applicable dependency, vulnerability, and static-analysis checks pass.
- [ ] Every security exception or vulnerability suppression has a narrow scope,
  rationale, expiry date, and mitigating controls.
- [ ] No known blocking security or privacy issue remains.

## Review readiness

- [ ] The final change has completed the repository-required agent review using
  [Code Review Guidelines](CODE_REVIEW_GUIDELINES.md).
- [ ] All blocking review findings are resolved.
- [ ] Verification affected by review changes has been repeated.
- [ ] Remaining non-blocking findings, limitations, assumptions, and follow-up
  work are disclosed.

## Handoff package

- [ ] A concise change summary is provided.
- [ ] Materially changed files and their purposes are identified.
- [ ] Acceptance Criteria-to-evidence mapping is provided.
- [ ] Verification commands, environments, and results are provided.
- [ ] Checks not run are listed with their reasons and expected results.
- [ ] Configuration, migration, compatibility, security, deployment, and
  operational implications are provided.
- [ ] Required human-only verification and known limitations are provided.
- [ ] Draft pull-request content and the Security Vulnerability Assessment are
  prepared in accordance with [Contributing](CONTRIBUTING.md).

## Completion condition

The agent may report **Ready for human review** only when every applicable item
above is satisfied.

An item may be marked **Not applicable** only with a recorded reason. An
agent-executable requirement cannot be deferred to a human.

If any applicable item is unsatisfied, the work is **Not Agent Complete**. The
handoff must identify the unmet criterion and the remediation required. Human
approval, QA sign-off, CI, deployment, environment verification, and ticket
closure remain pending unless direct evidence confirms them.
