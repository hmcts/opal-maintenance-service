/**
 * OPAL Program
 *
 * MODULE      : draft_casefile_test_send_attempts_pgtap_tests.sql
 *
 * DESCRIPTION : Verify durable publication attempt integrity. Fresh DB-01 and future DB-03 contract assertions.
 *
 * CHANGE HISTORY:
 *
 * Date        Author           Ticket        Nature of Change
 * ----------  ---------------  ------------  ----------------------------------------
 * 22/10/2026  Jonathan Duffy    PO-10626      Initial publication evidence contract.
 */

\set ON_ERROR_STOP on
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SET LOCAL search_path = public, pg_catalog;
SELECT plan(30);

-- -----------------------------------------------------------------------------
-- Scenario A01: attempt identity, association and timestamp types.
-- Setup: fresh migrated schema.
-- Expected: UUID key, required parent/outcome/start and nullable completion.
-- -----------------------------------------------------------------------------
SELECT columns_are('public', 'draft_casefile_test_send_attempts',
    ARRAY['attempt_id', 'observation_id', 'outcome', 'started_at', 'completed_at'], 'A01 exact metadata columns');
SELECT col_hasnt_default('public', 'draft_casefile_test_send_attempts', 'attempt_id', 'A01 UUID supplied by caller');
SELECT is((SELECT confrelid FROM pg_constraint WHERE conrelid =
    TO_REGCLASS('public.draft_casefile_test_send_attempts') AND contype = 'f'),
    'public.draft_casefile_test_observations'::regclass::oid, 'A01 foreign key targets observations');
SELECT has_table('public', 'draft_casefile_test_send_attempts', 'has_table draft_casefile_test_send_attempts');
SELECT col_type_is('public', 'draft_casefile_test_send_attempts', 'attempt_id', 'uuid', 'col_type_is uuid');
SELECT col_type_is('public', 'draft_casefile_test_send_attempts', 'observation_id', 'uuid', 'col_type_is uuid');
SELECT col_type_is('public', 'draft_casefile_test_send_attempts', 'outcome', 'character varying(16)', 'col_type_is character varying(16)');
SELECT col_type_is('public', 'draft_casefile_test_send_attempts', 'started_at', 'timestamp with time zone', 'col_type_is timestamp with time zone');
SELECT col_type_is('public', 'draft_casefile_test_send_attempts', 'completed_at', 'timestamp with time zone', 'col_type_is timestamp with time zone');
SELECT col_is_pk('public', 'draft_casefile_test_send_attempts', 'attempt_id', 'col_is_pk attempt_id');
SELECT col_not_null('public', 'draft_casefile_test_send_attempts', 'observation_id', 'col_not_null observation_id');
SELECT col_not_null('public', 'draft_casefile_test_send_attempts', 'outcome', 'col_not_null outcome');
SELECT col_not_null('public', 'draft_casefile_test_send_attempts', 'started_at', 'col_not_null started_at');
SELECT col_is_null('public', 'draft_casefile_test_send_attempts', 'completed_at', 'col_is_null completed_at');
SELECT is((SELECT confdeltype::text FROM pg_constraint WHERE conrelid =
    TO_REGCLASS('public.draft_casefile_test_send_attempts') AND contype = 'f'), 'c', 'A01 cascading observation FK');
SELECT has_index('public', 'draft_casefile_test_send_attempts', 'dctsa_observation_id_idx', 'has_index dctsa_observation_id_idx');

-- -----------------------------------------------------------------------------
-- Scenario A02: allowed outcomes and temporal integrity.
-- Setup: two observation scopes with valid started, acknowledged and uncertain rows.
-- Expected: invalid outcomes, dangling parent, duplicate identity and invalid times fail.
-- -----------------------------------------------------------------------------
INSERT INTO public.draft_casefile_test_observations VALUES
    ('10626000-0000-0000-0000-000000000001', 910626001, 'E2E-0123456789abcdef', NOW()),
    ('10626000-0000-0000-0000-000000000002', 910626002, 'E2E-fedcba9876543210', NOW());
INSERT INTO public.draft_casefile_test_send_attempts VALUES
    ('10626000-0000-0000-0000-000000000011', '10626000-0000-0000-0000-000000000001',
        'STARTED', '2026-10-22T10:00:00Z', NULL),
    ('10626000-0000-0000-0000-000000000012', '10626000-0000-0000-0000-000000000001',
        'ACKNOWLEDGED', '2026-10-22T10:00:00Z', '2026-10-22T10:00:00Z'),
    ('10626000-0000-0000-0000-000000000013', '10626000-0000-0000-0000-000000000002',
        'UNCERTAIN', '2026-10-22T10:00:00Z', '2026-10-22T10:00:01Z');
SELECT is((SELECT COUNT(*) FROM public.draft_casefile_test_send_attempts), 3::bigint, 'A02 all allowed outcomes');
SELECT throws_ok($$INSERT INTO public.draft_casefile_test_send_attempts VALUES
    ('10626000-0000-0000-0000-000000000011', '10626000-0000-0000-0000-000000000001', 'STARTED', NOW(), NULL)$$,
    '23505', NULL, 'A02 duplicate attempt rejected');
SELECT throws_ok($$INSERT INTO public.draft_casefile_test_send_attempts VALUES
    ('10626000-0000-0000-0000-000000000014', '10626000-0000-0000-0000-000000000099', 'STARTED', NOW(), NULL)$$,
    '23503', NULL, 'A02 missing observation rejected');
SELECT throws_ok($$UPDATE public.draft_casefile_test_send_attempts SET outcome = 'SENT'
    WHERE attempt_id = '10626000-0000-0000-0000-000000000011'$$,
    '23514', NULL, 'A02 unknown outcome rejected');
SELECT throws_ok($$UPDATE public.draft_casefile_test_send_attempts SET completed_at = NOW()
    WHERE attempt_id = '10626000-0000-0000-0000-000000000011'$$,
    '23514', NULL, 'A02 started attempt cannot be complete');
SELECT throws_ok($$UPDATE public.draft_casefile_test_send_attempts SET completed_at = NULL
    WHERE attempt_id = '10626000-0000-0000-0000-000000000012'$$,
    '23514', NULL, 'A02 acknowledged attempt requires nonnull completion');
SELECT throws_ok($$UPDATE public.draft_casefile_test_send_attempts SET completed_at = NULL
    WHERE attempt_id = '10626000-0000-0000-0000-000000000013'$$,
    '23514', NULL, 'A02 uncertain attempt requires nonnull completion');
SELECT throws_ok($$UPDATE public.draft_casefile_test_send_attempts SET completed_at = started_at - INTERVAL '1 second'
    WHERE attempt_id = '10626000-0000-0000-0000-000000000012'$$,
    '23514', NULL, 'A02 completion cannot precede start');
SELECT throws_ok($$UPDATE public.draft_casefile_test_send_attempts SET observation_id = NULL
    WHERE attempt_id = '10626000-0000-0000-0000-000000000011'$$,
    '23502', NULL, 'A02 null observation rejected');
SELECT throws_ok($$UPDATE public.draft_casefile_test_send_attempts SET outcome = NULL
    WHERE attempt_id = '10626000-0000-0000-0000-000000000011'$$,
    '23502', NULL, 'A02 null outcome rejected');
SELECT throws_ok($$UPDATE public.draft_casefile_test_send_attempts SET started_at = NULL
    WHERE attempt_id = '10626000-0000-0000-0000-000000000011'$$,
    '23502', NULL, 'A02 null start rejected');

-- -----------------------------------------------------------------------------
-- Scenario A03: delete only the selected observation scope.
-- Setup: delete first observation while the other has an uncertain attempt.
-- Expected: only related attempts cascade, preserving other evidence.
-- -----------------------------------------------------------------------------
DELETE FROM public.draft_casefile_test_observations WHERE observation_id = '10626000-0000-0000-0000-000000000001';
SELECT is((SELECT COUNT(*) FROM public.draft_casefile_test_send_attempts
    WHERE observation_id = '10626000-0000-0000-0000-000000000001'), 0::bigint, 'A03 selected scope cascades');
SELECT is((SELECT COUNT(*) FROM public.draft_casefile_test_send_attempts
    WHERE observation_id = '10626000-0000-0000-0000-000000000002'), 1::bigint, 'A03 other attempt survives');
SELECT is((SELECT COUNT(*) FROM public.draft_casefile_test_observations
    WHERE observation_id = '10626000-0000-0000-0000-000000000002'), 1::bigint, 'A03 other observation survives');
SELECT * FROM finish();
ROLLBACK;
