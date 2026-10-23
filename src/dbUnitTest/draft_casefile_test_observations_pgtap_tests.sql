/**
 * OPAL Program
 *
 * MODULE      : draft_casefile_test_observations_pgtap_tests.sql
 *
 * DESCRIPTION : Verify durable observation registration. Fresh DB-01 and future DB-03 contract assertions.
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
SELECT plan(24);

-- -----------------------------------------------------------------------------
-- Scenario O01: observation identity and types.
-- Setup: fresh migrated schema.
-- Expected: UUID identity, unique bigint draft reference, bounded marker and timestamp.
-- -----------------------------------------------------------------------------
SELECT columns_are('public', 'draft_casefile_test_observations',
    ARRAY['observation_id', 'draft_casefile_id', 'test_run_reference', 'registered_at'], 'O01 exact metadata columns');
SELECT col_hasnt_default('public', 'draft_casefile_test_observations', 'observation_id', 'O01 UUID supplied by caller');
SELECT has_table('public', 'draft_casefile_test_observations', 'has_table draft_casefile_test_observations');
SELECT col_type_is('public', 'draft_casefile_test_observations', 'observation_id', 'uuid', 'col_type_is uuid');
SELECT col_type_is('public', 'draft_casefile_test_observations', 'draft_casefile_id', 'bigint', 'col_type_is bigint');
SELECT col_type_is('public', 'draft_casefile_test_observations', 'test_run_reference', 'character varying(20)', 'col_type_is character varying(20)');
SELECT col_type_is('public', 'draft_casefile_test_observations', 'registered_at', 'timestamp with time zone', 'col_type_is timestamp with time zone');
SELECT col_is_pk('public', 'draft_casefile_test_observations', 'observation_id', 'col_is_pk observation_id');
SELECT col_is_unique('public', 'draft_casefile_test_observations', 'draft_casefile_id', 'col_is_unique draft_casefile_id');
SELECT col_not_null('public', 'draft_casefile_test_observations', 'draft_casefile_id', 'col_not_null draft_casefile_id');
SELECT col_not_null('public', 'draft_casefile_test_observations', 'test_run_reference', 'col_not_null test_run_reference');
SELECT col_not_null('public', 'draft_casefile_test_observations', 'registered_at', 'col_not_null registered_at');
SELECT is((SELECT COUNT(*) FROM pg_constraint WHERE conrelid =
    TO_REGCLASS('public.draft_casefile_test_observations') AND contype = 'f'), 0::bigint,
    'O01 no foreign key to a locked draft');

-- -----------------------------------------------------------------------------
-- Scenario O02: independent registration and duplicate identities.
-- Setup: positive draft identifier with no draft row, synthetic run marker.
-- Expected: registration succeeds without loading a draft; duplicate draft or UUID fails.
-- -----------------------------------------------------------------------------
INSERT INTO public.draft_casefile_test_observations VALUES
    ('10626000-0000-0000-0000-000000000001', 910626001, 'E2E-0123456789abcdef', '2026-10-22T10:00:00Z');
SELECT is((SELECT COUNT(*) FROM public.draft_casefile_test_observations
    WHERE draft_casefile_id = 910626001), 1::bigint, 'O02 missing draft does not block registration');
SELECT throws_ok($$INSERT INTO public.draft_casefile_test_observations VALUES
    ('10626000-0000-0000-0000-000000000002', 910626001, 'E2E-fedcba9876543210', NOW())$$,
    '23505', NULL, 'O02 draft registration is unique');
SELECT throws_ok($$INSERT INTO public.draft_casefile_test_observations VALUES
    ('10626000-0000-0000-0000-000000000001', 910626002, 'E2E-fedcba9876543210', NOW())$$,
    '23505', NULL, 'O02 observation identity is unique');

-- -----------------------------------------------------------------------------
-- Scenario O03: marker and identifier boundaries.
-- Setup: malformed identifiers/markers and missing required values.
-- Expected: native constraints reject each invalid row.
-- -----------------------------------------------------------------------------
SELECT throws_ok($$INSERT INTO public.draft_casefile_test_observations VALUES
    ('10626000-0000-0000-0000-000000000002', 0, 'E2E-0123456789abcdef', NOW())$$,
    '23514', NULL, 'O03 zero draft rejected');
SELECT throws_ok($$INSERT INTO public.draft_casefile_test_observations VALUES
    ('10626000-0000-0000-0000-000000000002', -1, 'E2E-0123456789abcdef', NOW())$$,
    '23514', NULL, 'O03 negative draft rejected');
SELECT throws_ok($$INSERT INTO public.draft_casefile_test_observations VALUES
    ('10626000-0000-0000-0000-000000000002', 910626002, 'E2E-ABCDEF0123456789', NOW())$$,
    '23514', NULL, 'O03 uppercase marker rejected');
SELECT throws_ok($$INSERT INTO public.draft_casefile_test_observations VALUES
    ('10626000-0000-0000-0000-000000000002', 910626002, 'E2E-0123456789abcde', NOW())$$,
    '23514', NULL, 'O03 short marker rejected');
SELECT throws_ok($$INSERT INTO public.draft_casefile_test_observations VALUES
    ('10626000-0000-0000-0000-000000000002', 910626002, 'RUN-0123456789abcdef', NOW())$$,
    '23514', NULL, 'O03 marker prefix rejected');
SELECT throws_ok($$INSERT INTO public.draft_casefile_test_observations VALUES
    ('10626000-0000-0000-0000-000000000002', NULL, 'E2E-0123456789abcdef', NOW())$$,
    '23502', NULL, 'O03 null draft rejected');
SELECT throws_ok($$INSERT INTO public.draft_casefile_test_observations VALUES
    ('10626000-0000-0000-0000-000000000002', 910626002, NULL, NOW())$$,
    '23502', NULL, 'O03 null marker rejected');
SELECT throws_ok($$INSERT INTO public.draft_casefile_test_observations VALUES
    ('10626000-0000-0000-0000-000000000002', 910626002, 'E2E-0123456789abcdef', NULL)$$,
    '23502', NULL, 'O03 null registration timestamp rejected');
SELECT * FROM finish();
ROLLBACK;
