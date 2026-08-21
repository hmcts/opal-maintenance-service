# Contributing

This document is the canonical contribution workflow for this repository. Use
the [Backend Definition of Done](BACKEND_DEFINITION_OF_DONE.md) before handing
work over for human review.

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
- [ ] Testing evidence is complete, including relevant checks not run.
- [ ] Human-only verification, limitations, assumptions, and follow-up work are disclosed.
- [ ] Agent review is complete, blocking findings are resolved, and affected checks were repeated.
- [ ] A security assessment is included.
- [ ] Breaking changes are described.
- [ ] Flyway, configuration, deployment, or operational impact is described.
- [ ] Sensitive-data handling has been reviewed.
