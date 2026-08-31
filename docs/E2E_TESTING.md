# End-to-end Testing

This document covers the environment-dependent functional and smoke suites.
The general naming, coverage, security, and evidence rules in
[Testing](TESTING.md) also apply.

## Suite boundary

The intended boundary for both suites is a running service over HTTP:

- **Functional tests** prove endpoint behaviour or a meaningful business
  journey across the deployed application boundary.
- **Smoke tests** prove only the small set of deployment-critical happy paths
  needed to decide whether an environment is usable.

A smoke scenario may overlap a functional scenario when the same path is both
business-critical and an appropriate release health signal. Do not move broad
validation, edge-case, or failure coverage into smoke merely to make it run in
another pipeline stage.

Spring slice and `MockMvc` tests are not end-to-end tests. Put them under
`src/test/java` or `src/integrationTest/java`, even if they exercise a
controller.

## Locations and commands

| Suite | Java tests | Command | Packaged report path |
| --- | --- | --- | --- |
| Functional | `src/functionalTest/java` | `./gradlew functional` | `functional-output/report/index.html` |
| Smoke | `src/smokeTest/java` | `./gradlew smoke` | `smoke-test-report/index.html` |

Set `TEST_URL` to the target service base URL. It defaults to
`http://localhost:4551`:

```bash
TEST_URL=http://localhost:4551 ./gradlew functional
TEST_URL=http://localhost:4551 ./gradlew smoke
```

Callers and shared helpers must handle a base URL with or without a trailing
slash consistently. Do not hardcode environment-specific hostnames in test
classes.

## Local execution

Start the service and its required dependencies before running an external
suite. Confirm the target explicitly before running tests that can create or
change data. Use isolated, non-production test data and make any required
feature flags, users, permissions, or downstream stubs part of the recorded
setup.

A typical local health check is to start the service in one terminal:

```bash
./gradlew bootRun
```

Then run the smoke suite in another:

```bash
TEST_URL=http://localhost:4551 ./gradlew smoke
```

If the service is started another way, record that command and any material
configuration overrides with the result.

## Authoring standards

- Name functional classes `*FunctionalTest` and smoke classes `*SmokeTest`.
- Use behaviour-led class and method names that remain clear in JUnit and HTML
  reports.
- Keep one scenario focused on one endpoint behaviour or business-journey
  outcome.
- Assert the status, content type where applicable, and contract-relevant body
  or headers. A status-only assertion is sufficient only when status is the
  complete contract being tested.
- Reuse existing request setup and response assertions before adding a
  duplicate helper.
- Keep tests deterministic and independent. Do not depend on another scenario
  having run first.
- Do not log tokens, credentials, PII, or complete sensitive response bodies.
- If required users or environment state cannot be established from maintained
  repository guidance, record the gap rather than inventing setup values.

## Suite selection

Add a functional test when the risk lies at the running-service boundary, such
as routing, serialisation, filters, deployed configuration, downstream
integration, or a cross-component journey.

Add a smoke test only when failure means the deployment should not be treated
as usable. Prefer a shallow, read-only happy path. Keep slower setup, exhaustive
validation, destructive flows, and rare error cases in functional coverage.

Do not duplicate unit and integration assertions wholesale. End-to-end tests
should cover the smaller set of risks that lower levels cannot prove.

## Current runner model

The functional source set currently contains plain JUnit tests and an
`OpalTestRunner` that selects Cucumber features from `features/opalMode`.
However, the `functionalOpal` Gradle task excludes that runner and there is no
corresponding feature directory, so `./gradlew functional` currently executes
the plain JUnit classes. The smoke source set also contains a plain JUnit test.

There is no `functionalLegacy` task or active Cucumber tag filtering. Do not
rely on `@Opal`, `@Legacy`, `@Smoke`, or `@Ignore` tags to select maintenance
scenarios in the current build.

If this repository deliberately adopts the Fines Serenity/Cucumber model in
future, make the runner, folder, and tag semantics agree:

- keep functional features and Java step definitions in the functional source
  set;
- separate Opal, legacy, and smoke feature locations;
- give `@Opal`, `@Legacy`, `@Smoke`, and `@Ignore` explicit runner meaning;
- keep step definitions narrow and reuse shared URL/request helpers; and
- publish stable Serenity and JUnit outputs from the Gradle tasks.

That migration must update the build and pipeline together; adding tags or
feature files alone does not create reliable suite selection.

## Known current gaps

- `src/functionalTest/java/uk/gov/hmcts/opal/controllers/GetWelcomeTest.java`
  is a `@WebMvcTest`, so it does not exercise a running service and should move
  to the unit or integration source set when that test area is next changed.
- `OpalTestRunner` is excluded from `functionalOpal`, and its selected
  `features/opalMode` directory does not exist. Until the runner, feature files,
  and Gradle task are enabled together, it provides no Cucumber coverage.

## Evidence

For each run, record the exact command, resolved target environment, result,
and report path. If a suite cannot run, state the missing service, dependency,
account, permission, or environment state, along with the scenario and expected
result. Never describe a skipped external suite as passing.
