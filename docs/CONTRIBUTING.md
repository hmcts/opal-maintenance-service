# Contributing

This document is the canonical contribution workflow for this repository.

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
Jira link and map the delivered work to the Acceptance Criteria. Include
testing evidence and a security assessment, along with any breaking,
migration, configuration, or operational impact.

## Testing evidence

Record the exact commands and results, the environment used, and manual
scenarios exercised. State which checks were omitted and why. Include
operational evidence where it is relevant to the change.

## Review and QA

At least two reviewers must approve before merge. Technically validate Codex
and human feedback, and resolve validated blocking findings. Obtain QA sign-off
where the ticket or release process requires it.

## Pull request template

Use the following headings and checklist when preparing a pull request; they
match [the GitHub pull request template](../.github/PULL_REQUEST_TEMPLATE.md).

### Jira link

Provide the Jira key and link.

### Change description

Describe the change and map it to the Acceptance Criteria.

### Testing done

List exact commands and results, manual scenarios, environment, and checks not
run with their reasons.

### Breaking change

State any migration or configuration impact, including breaking changes.

### Security Vulnerability Assessment

Describe the security assessment and any CVE suppressions with their rationale.

### Checklist

- [ ] Acceptance Criteria are addressed.
- [ ] Commits follow the contribution convention.
- [ ] Documentation is updated where needed.
- [ ] Tests cover the affected behaviour where needed.
- [ ] Testing evidence is included.
- [ ] A security assessment is included.
- [ ] Breaking changes are described.
- [ ] Flyway or operational impact is described.
- [ ] Sensitive-data handling has been reviewed.
