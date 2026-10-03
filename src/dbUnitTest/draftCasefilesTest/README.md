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
validation and fail-closed pgTAP reporting. For the historical PO-10299 scope, the immediate-predecessor upgrade
from 1.13 to 1.14 was a separate validation obligation; the standard task does
not implement upgrade mode. Preserve both sets of evidence in the delivery
record, including PostgreSQL version and verified container cleanup.

The original PO-10299 assertions were specified for both fresh and
immediate-predecessor upgrade paths. This describes that ticket’s scope,
not upgrade evidence for the subsequent foreign-key migration.

Coverage includes exact columns, types, nullability, comments, enums, sequence,
constraints, indexes, valid minimal and complete inserts, VARCHAR boundaries,
invalid NULL/enum/JSON/length values, duplicate keys, Business Unit referential
integrity, multiple NULL account references and caller-owned rollback. Fixtures
are synthetic and wrapped in a rolled-back transaction. Sequence values can
advance despite rollback; the suite does not require a pristine sequence value.

At the PO-10299 delivery point, only `dcf_account_id_fk` was deferred to
Check and Validate. Nullable account_id and its unique constraint were
implemented in V1_14. Backend services own submission
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

## Check & Validate publication link — PO-10659

`ddl/V1_28__add_draft_casefiles_account_id_foreign_key.sql` adds
`dcf_account_id_fk` to `respondent_accounts.respondent_account_id`. It retains
nullable BIGINT `account_id`, `draft_casefiles_account_id_uk`, and the existing
three indexes. Only the separate Respondent Accounts hearing-court FK remains
deferred to a future Courts delivery.

`draft_casefiles_publication_link_pgtap_tests.sql` covers the FK endpoint and
immediate NO ACTION behavior, NULL/valid links, missing parents (23503),
duplicate valid links (23505), multiple NULLs, parent-delete protection and
failed-statement preservation. The original suite now uses its own generated
Respondent Account parent while retaining the previous schema/input coverage.
Both suites use synthetic transaction-local fixtures and roll back.

Use the unchanged `./gradlew dbUnitTest` for fresh PostgreSQL 17 installation,
Flyway validation, repeat-migrate no-op, pgTAP fail-closed behavior and confirmed
cleanup. Separate existing-state validation is **Not run — user-approved
initial-schema scope exception** for this delivery. This assumes the affected
account workflow and populated account-link state are not yet established;
it does not claim any deployed database was inspected. If release information
contradicts that assumption, reconsider the validation scope before release.
No predecessor fixtures, runner extension or new test framework are introduced.

One PR is not an atomic migration transaction: earlier successful files remain
if a later file fails. An unexpected orphan-link failure requires an explicit
data/forward-fix decision; do not delete drafts, null links, invent accounts or
repair history automatically. LLD/model reconciliation, human SQL review, QA,
publication, merge and deployment remain separately recorded delivery states.
