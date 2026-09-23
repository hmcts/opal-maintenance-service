# Major Creditors Central Authority data contract — PO-10296

The CSV is retained byte-for-byte from opal-rm-agent-context commit
`d5383489779b9aefbf6313fb0b9cebca516d1573`, file
`rm/common/reference-data/major-creditors.csv`.
SHA-256: `8f2ac26256df6df8c72fd8ce40c876844d35f155d33c108ade900a8c61b83ccc`.
The country mapping fixture is transcribed independently from that revision's
`rm/common/reference-data/major-creditors.md`; it is not extracted from migration SQL.

Expected data: ten exact records, codes 0001–0010, Business Unit 44, both flags
true, original text/leading zeros preserved, optional blanks represented by NULL.
New Major Creditor IDs are generated. Country IDs come from exactly one row
matching each documented country name. No Business Unit name validation is used.

The migration embeds its input; CSV access is required only for independent tests.
The pgTAP suite compares every supplied field and relationship, checks generated
IDs separately, reruns the actual migration, preserves unrelated records and
surviving IDs, and restores a missing row. It rolls back its fixtures.
Run `./gradlew dbUnitTest --no-daemon` with the repository Java/Gradle runtime
and Docker available. The normal task discovers pgTAP tests and mandatorily
runs the Gradle-owned candidate checks; neither phase requires an opt-in flag.
There is no Python test script or Python runtime requirement for these tests.

The entire standalone SQL script requires one caller-managed transaction.
A SHARE ROW EXCLUSIVE target lock protects conflict checking and insertion.
Conflicting existing values fail, including NULL differences; identical rows
remain unchanged. Explicit staging cleanup is part of successful execution.

V1.10 must follow the real integrated
`V1_9__create_major_creditors_table.sql`. Preserve that ordering in deployment
without outOfOrder. The Gradle-owned candidate checks cover V1.9-to-V1.10 upgrade, missing and ambiguous
countries, missing Business Unit, conflicting values including NULL differences,
late constraint failure, actual Flyway rollback, and two-session writer blocking,
conflict detection and lock release. Every failure or unconfirmed container
cleanup fails dbUnitTest. Logs are generated under
`build/reports/dbUnitTest/major-creditors-candidate.log` and remain ignored;
the Gradle helper, SQL tests and fixtures are committed. The helper reuses the
normal task's disposable container and its final cleanup. These checks do not
claim to implement a generic repository-wide upgrade framework.

Business Unit 44 is interim pending MBEC consolidation. If the identifier changes
before delivery, revise approved source mappings. After application, corrections
require a new forward-only migration. Applied migrations remain immutable.
