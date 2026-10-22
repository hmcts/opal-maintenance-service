# Draft Casefile publication consumer

PO-10629 consumes approved Draft Casefiles from the queue populated by the
checker PATCH operation. The saved draft is the source of business data.

## Message contract

The persistent text message contains server-derived approval context:

```json
{
  "draft_casefile_id": 42,
  "checker_user_id": 123,
  "originating_ip_address": "192.0.2.1",
  "approval_timestamp": "2026-10-22T12:00:00.123456Z"
}
```

Both identifiers must be positive 64-bit integers. The checker is the approving
Opal user ID, not the Business Unit user ID stored in `validated_by`. The IP is
the approval request's existing PDPO IP. It must be a literal IPv4 or IPv6
address; the consumer does not resolve hostnames or substitute its own address.
Do not include casefile content or account details in messages.
The approval timestamp is the saved `validated_date` as a canonical UTC instant
with microsecond precision. Under the row lock it must match the current approval;
a delayed message from a rolled-back earlier approval cannot supply audit context
for a later approval. A mismatch or missing timestamp fails for recovery.

Deploy the extended producer before enabling consumption. A legacy ID-only
message for a completed draft is a no-op. A pending draft without valid audit
context remains pending and its delivery fails. Malformed messages likewise
fail without modifying the draft. Configure bounded delivery attempts and
monitor dead letters; do not discard these messages or invent missing context.
Replay requires authentic original checker/IP/timestamp context and an authorised
recovery decision. There is no automatic recovery endpoint.

## Transaction and duplicate handling

The JMS listener uses a transacted session. The processing service locks the
draft through JPA before inspecting its state. It waits for an in-progress
approval or another publication to finish. Missing and coherent non-pending
drafts are no-ops. An inconsistent publication identity requires investigation.

An eligible attempt validates the persisted Casefile and snapshot, active
references, approval and independent checker. It then calls:

```sql
CALL public.p_process_draft_casefiles(?, NULL, NULL, NULL);
```

The procedure returns respondent ID, account number and JSON containing
`respondent_account`, `applicant_account` and `minor_creditor_accounts`.
The Java adapter uses JDBC only for this call because PostgreSQL JSON OUT
requires `Types.OTHER`, while standard JPA String registration uses VARCHAR.
JDBC and JPA participate in the same configured database transaction.

The mapper matches Minor Creditors by `creditor_sequence`, validates scalar/JSON
agreement and fills generated account identities into the retained snapshot.
Publication commits the complete graph, account-number reservations, snapshot,
direct respondent links, `PUBLISHED`, UTC status time and incremented version
together. Approval, original Casefile and timeline remain unchanged. Sequence
gaps after rollback are normal.

Legacy null versions are initialised to zero only under the existing row lock,
with pending-state and absent-link guards, then refreshed into the managed
entity before its lifecycle update. This avoids Hibernate's null-version
increment failure. Initialisation rolls back with the transaction.

Database commit precedes JMS acknowledgement. A repeat delivery sees the
published state and does not create another graph or publication PDPO event.
The process provides at-least-once delivery and state-based idempotency.

## Failure policy

Classification follows the applicable Fines `TransientFailureHelper` rules:

| Failure | Outcome |
| --- | --- |
| Top-level resource failure or query timeout | Retry |
| Nested PostgreSQL `40001`, `40P01`, `55P03` | Retry |
| PostgreSQL exception caused by connection refusal or unknown host | Retry |
| Other processing failure with a captured attempt | Guarded terminal failure |
| Invalid message/audit context or inconsistent state | Retry/dead-letter for recovery |
| Commit failure without a trustworthy captured attempt | Retry and inspect durable state |
| Failure to persist the terminal outcome | Retry |

There is no application retry loop. Broker policy bounds repeated deliveries.
Unknown processing errors follow Fines' terminal default. The procedure's
current rejection of creditor-free Results is also terminal, even where the
submission validator permits them; DB owns that policy.

A processing failure rolls back the graph. A separate transaction locks the
draft and checks its original version and approval token before setting
`PUBLISHING_FAILED`, a new UTC status time and `Publication failed; contact
support`. It preserves snapshot, Casefile, approval and timeline. It never
overwrites a published result or a changed pending attempt.

Application diagnostics and status messages omit raw payloads and provider
exception text. The Micrometer counter `opal.draft.casefile.publication` has
bounded `outcome` tags: `published`, `noop`, `failed`, `retry`, `invalid`.
IDs, IPs and personal details are not metric labels. The JMS error handler emits
only a fixed message. Hibernate's raw `org.hibernate.orm.jdbc.error` logger is
disabled because PostgreSQL constraint diagnostics can contain complete saved
rows; application outcome logs and metrics remain enabled.

## Publication PDPO

The existing AFTER_COMMIT listener emits one Alteration event per resolved
participant category, including Related parties where applicable:

| Field | Value |
| --- | --- |
| Category | `ALTERATION` |
| Business identifier | `Publish Approved Casefile - <category>` |
| Created by | Message checker ID, `OPAL_USER_ID` |
| Individuals | Retained draft ID, `RM_DRAFT_CASEFILE` |
| IP | Message originating approval IP |
| Created at | UTC publication-operation instant, microsecond precision |
| Recipient | null |

No publication PDPO is emitted for rollback, terminal failure or a duplicate.
The existing asynchronous logging path is not a durable outbox: a crash after
commit or downstream rejection can lose audit delivery. Logging failure does
not undo publication. Verify actual downstream persistence during deployment,
monitor logging failures and retain draft references under the agreed retention
policy. Dashboard age filtering must not delete those references.

## Configuration and rollout

`SERVICEBUS_RM_PUBLISH_DRAFT_CASEFILE_CONSUMER_ENABLED` defaults to `false` in
application and Helm configuration. `SERVICEBUS_RM_PUBLISH_DRAFT_CASEFILE_QUEUE_NAME`
continues to select the existing queue. Connection credentials use the existing
Service Bus secret configuration. The consumer follows Fines' idle timeout,
transacted-session and default concurrency/prefetch configuration; it adds no
custom query timeout or prefetch tuning.

Before enabling an agreed non-live environment:

1. Resolve the provider migration foundation and deploy PO-10655/#300 with all
   its helpers. The Java and provider heads inspected during implementation
   allocate Flyway `1.33` to different migrations (Java dev reference data and
   the creditor procedure). DB ownership must resolve the combined history;
   do not edit or renumber applied migrations locally.
2. Deploy logging-service #319 so `RM_DRAFT_CASEFILE` can persist.
3. Confirm queue provision/permissions under PO-10627. Record actual maximum
   deliveries, lock duration, TTL, dead-letter access and monitoring from the
   target environment. Local emulator configuration is not cloud evidence.
4. Deploy the extended producer with consumption disabled. Inventory legacy
   pending work and quarantine incompatible messages for authorised recovery.
5. Enable the consumer and submit a synthetic approval. Verify the real account
   graph, snapshot identities, preserved timeline/approval, version and final
   state, then verify persisted PDPO rows in the logging service.
6. Verify `/`, `/health`, `/prometheus`, duplicate delivery, transient recovery,
   terminal failure, dead-letter handling and absence of sensitive diagnostics.

Monitor dead-letter growth, stale `PUBLISHING_PENDING` drafts, retry/failed
outcomes and PDPO send/persistence failures. There is no selected deployment
target or verified cloud queue policy in this implementation's local evidence.

Rollback by disabling consumption and retaining queued work. Do not delete live
account graphs, reverse applied migrations or remove logging enum values.
See [Testing](TESTING.md#publication-consumer-tests) for reproducible verification.
