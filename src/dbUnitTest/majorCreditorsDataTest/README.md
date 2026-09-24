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
and Docker available. The shared Gradle task discovers SQL tests and CSV fixtures,
copies migrations into its disposable container and reports pgTAP results.
Ticket-specific assertions remain in SQL; no separate script or runtime is required.

The entire standalone SQL script requires one caller-managed transaction.
Conflicting existing values fail, including NULL differences; identical rows
remain unchanged. Explicit staging cleanup is part of successful execution.

V1.10 must follow the real integrated
`V1_9__create_major_creditors_table.sql`. Preserve that ordering in deployment
without outOfOrder. SQL tests cover missing and ambiguous countries, missing
Business Unit, conflicting values including NULL differences and late insert
failure. They execute the real migration inside rolled-back subtransactions,
checking the SQLSTATE, diagnostic, unchanged rows and staging cleanup.

Deployment is expected to run migrations serially without concurrent writes to
the seed records. There is no explicit table lock or multi-session test harness.
Database constraints and transaction rollback remain in force. The earlier implementation validation exercised the
V1.9-to-V1.10 Flyway upgrade and rollback; the simplified routine suite covers
fresh migration, repeat migration and SQL failure atomicity, not a dedicated
predecessor-upgrade orchestration. Reports remain under `build/reports/dbUnitTest`.

Business Unit 44 is interim pending MBEC consolidation. If the identifier changes
before delivery, revise approved source mappings. After application, corrections
require a new forward-only migration. Applied migrations remain immutable.
