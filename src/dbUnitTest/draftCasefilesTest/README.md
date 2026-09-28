# DRAFT_CASEFILES database tests

PO-10299 implements the approved ticket
`rm/create-case-file/tickets/approved/db/db-rm-create-draft-casefiles-table-v5.md`,
relative to the configured OPAL workspace root. The promoted Create Case File
TDIA is the physical authority.

The migration is `ddl/V1_14__create_draft_casefiles_table.sql`. The pgTAP suite
is `draft_casefiles_pgtap_tests.sql`, the filename explicitly approved by the
user in place of the ticket's `draft_casefiles_unit_tests.sql`. The standard
runner discovers this suite; no duplicate test entry point is required.

Run `./gradlew --no-daemon --console=plain dbUnitTest` against its disposable
PostgreSQL 17 container. It verifies fresh migration, repeat migrate, Flyway
validation and fail-closed pgTAP reporting. The immediate-predecessor upgrade
from 1.13 to 1.14 must also be demonstrated separately; the standard task does
not implement upgrade mode. Preserve both sets of evidence in the delivery
record, including PostgreSQL version and verified container cleanup.

All assertions apply to both the fresh and immediate-predecessor upgrade paths.

Coverage includes exact columns, types, nullability, comments, enums, sequence,
constraints, indexes, valid minimal and complete inserts, VARCHAR boundaries,
invalid NULL/enum/JSON/length values, duplicate keys, Business Unit referential
integrity, multiple NULL account references and caller-owned rollback. Fixtures
are synthetic and wrapped in a rolled-back transaction. Sequence values can
advance despite rollback; the suite does not require a pristine sequence value.

Only `dcf_account_id_fk` is deferred to Check and Validate. Nullable account_id
and its unique constraint are implemented now. Backend services own submission
transactions, timestamps, status, snapshot and timeline construction. This
schema migration creates no stored procedure, trigger, seed data or JSON shape
contract. Retention, Originator and consumer contract gaps remain outside scope.

Deploy after PO-10295 and before dependent writers. Expected new casefile rows:
zero. Existing reference data must remain unchanged. The migration creates new
objects; the Business Unit FK can briefly lock the referenced table during DDL.
Validate duration and operational effects in the authorized deployment process.
On failure stop rollout and inspect Flyway history. An applied migration is
immutable: use a reviewed forward fix; do not drop a populated table or run
Flyway clean/repair as routine recovery.

AC5 requires Maintenance Database LLD evidence, and AC6 requires target-model
reconciliation. The workbook describes the intended combined TDIA relationship;
no additional sequencing note is required solely for the approved FK deferral.
Human SQL review, QA, deployment and ticket closure are separate delivery states.
