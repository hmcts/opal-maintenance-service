# OpenAPI Guidelines

This document defines how OpenAPI source files and component names are organised
in `opal-maintenance-service`. Follow it before adding, moving, or renaming an
endpoint or schema.

## Source and generated artefacts

The source contracts are the YAML files under `src/main/resources/openapi`.
`OpenApiBundler` combines them into `build/openapi-bundled.yaml`, and OpenAPI
Generator creates Spring interfaces and models under `build/generated/openapi`.

Treat both build locations as generated output. Do not edit or commit them.

Use relative component references between source files, for example:

```yaml
$ref: './CommonObjects.yaml#/components/schemas/PartyDetails'
```

## File ownership

Use the narrowest current ownership that accurately represents the schema.
Do not extract a schema solely because it might be reused in the future.

| File | Purpose |
| --- | --- |
| `common.yaml` | Service-wide technical API components, such as `ProblemDetail` and shared headers. |
| `types.yaml` | Reusable primitive, monetary, identifier, and domain value types. |
| `CommonObjects.yaml` | Canonical RM business objects that have the same meaning and shape across API resources. |
| `<Resource>.yaml` | A resource aggregate and resource-owned lifecycle or projection schemas. It may be a component-only OpenAPI document. |
| `<EndpointResource>.yaml` | Paths and operation-specific request and response wrappers for that API resource. |

Keep an operation-specific object in the endpoint file until actual reuse or a
canonical domain definition justifies moving it. Similar names are not enough:
objects with different meanings, required fields, ownership, or lifecycle
should remain separate and be named explicitly.

The current Draft Casefile split illustrates the convention:

- `CommonObjects.yaml` owns reusable objects such as `PartyDetails`, `Address`,
  `ContactDetails`, and bank details.
- `Casefile.yaml` owns the `Casefile` aggregate, casefile roles, order objects,
  `CasefileSnapshot`, and `TimelineEntry`.
- `DraftCasefile.yaml` owns the endpoint and its `CreateRequest` and
  `CreateResponse` schemas.

`CasefileSnapshot` and timeline entries are created by the backend and are not
part of the Add Draft Casefile request from the frontend. They are nevertheless
OpenAPI components because the Java layer constructs them and later Draft
Casefile response contracts reuse them.

## Bundled and generated names

The bundler gives components from ordinary files a prefix based on their
filename. Use singular PascalCase filenames and concise schema names; do not
repeat the resource name inside every schema.

For example:

| Source | Declared schema | Bundled/generated name |
| --- | --- | --- |
| `DraftCasefile.yaml` | `CreateRequest` | `DraftCasefileCreateRequest` |
| `Casefile.yaml` | `Respondent` | `CasefileRespondent` |
| `Casefile.yaml` | `CasefileSnapshot` | `CasefileSnapshot` |
| `CommonObjects.yaml` | `PartyDetails` | `PartyDetails` |

The bundler does not add the prefix when the schema is already qualified by the
filename. This prevents names such as `CasefileCasefileSnapshot`.

`common.yaml`, `CommonObjects.yaml`, and `types.yaml` use the shared component
namespace and retain their declared names. A shared name must therefore be
globally unique across the bundled contract. The bundler fails on a collision;
do not resolve one by silently overwriting or merging semantically different
schemas.

Changing the shared-file list in `OpenApiBundler` is a compatibility-sensitive
change. Review the complete bundled component namespace and generated Java
names when doing so.

## Request and response ownership

Referencing a component from a response is sufficient for OpenAPI Generator to
create its Java model. A component does not need to appear in a request.

Do not expose server-generated identifiers, timestamps, snapshots, timelines,
status history, or authenticated-user data in a request merely to reuse a
response schema. For an isolated response-only property, consider `readOnly`.
Create separate request and response schemas when their shapes or validation
rules become materially different.

Operation-specific requiredness or conditional rules belong in the operation
contract or an explicitly named operation-specific schema. Keep the canonical
common object neutral enough for every API that legitimately shares it.

## Verification

After changing OpenAPI source files or bundler behaviour, run:

```bash
./gradlew bundleOpenApi
./gradlew openApiGenerate compileJava --no-daemon
./gradlew build --no-daemon
```

Review `build/openapi-bundled.yaml` to confirm that all references are internal,
component names are unique, and the expected paths remain present. Inspect the
generated model filenames when adding or moving schemas to catch duplicated or
misleading prefixes before application code depends on them.

Do not treat successful YAML parsing alone as sufficient: generation,
compilation, tests, and repository checks must all pass in proportion to the
change.
