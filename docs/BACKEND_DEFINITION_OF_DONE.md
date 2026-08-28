# Agent Definition of Done – Backend Supplement

## Applicability

Every change must satisfy the
[Common Definition of Done](COMMON_DEFINITION_OF_DONE.md). This supplement also
applies when a change affects backend or application concerns. A change that
also affects database concerns must also satisfy the
[Database Definition of Done](DATABASE_DEFINITION_OF_DONE.md).

## Scope and correctness

- [ ] Applicable success, validation, empty, error, authentication,
  authorisation, and startup paths are handled.

## Verification

- [ ] Applicable integration, functional, and smoke scenarios have automated or
  manual verification evidence.

## HTTP, configuration, and operations

- [ ] Applicable request, response, validation, error, authentication,
  authorisation, and OpenAPI behaviour is verified.
- [ ] Applicable `/`, `/health`, and `/prometheus` behaviour is preserved and
  verified.
- [ ] Logging is useful and does not expose secrets, credentials, tokens,
  personal data, or sensitive payloads.
