/**
 * OPAL Program
 *
 * MODULE      : owner.sql
 *
 * DESCRIPTION : Fixed framework-only phase, durability and failure regressions.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket        Nature of Change
 * ----------  -------------  ------------  ----------------------------------------
 * 13/10/2026  Frankie Moran  PO-10643      Initial framework regression fixture.
 */
-- OPAL-DB-UPGRADE {"id":"framework.candidate","candidate":"ddl/V1_10__candidate.sql","scope":"both","data":"migration-created-only"}
\set ON_ERROR_STOP 1
SELECT :'opal_phase' = 'fresh' AS fresh, :'opal_phase' = 'prepare' AS prepare, :'opal_phase' = 'verify' AS verify,
       :'opal_phase' = 'cleanup' AS cleanup,
       :'opal_test_case' = 'temp' AS temporary,
       :'opal_test_case' = 'rollback' AS rolled_back,
       :'opal_test_case' IN ('retry','migration-failure') AS retry,
       :'opal_test_case' = 'resolve' AS resolve,
       :'opal_test_case' = 'failed-history' AS failed_history,
       :'opal_test_case' = 'mutation' AS mutation,
       :'opal_test_case' = 'zero-' || :'opal_phase' AS zero_plan,
       :'opal_test_case' = 'plan-' || :'opal_phase' AS wrong_plan,
       :'opal_test_case' = 'sql-' || :'opal_phase' AS sql_error,
       :'opal_test_case' = 'tap-' || :'opal_phase' AS tap_error
\gset
DO $guard$ BEGIN
    IF CURRENT_DATABASE() <> 'opal_maintenance_db_unit_test' OR CURRENT_USER <> 'postgres' THEN
        RAISE EXCEPTION 'Framework fixture requires disposable identity';
    END IF;
END; $guard$;
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
\if :resolve
    -- -------------------------------------------------------------------------
    -- Scenario: Candidate failure is transactional; resolve only its external cause.
    -- Setup: Unchanged candidate bytes raised from the closed synthetic gate.
    -- Expected: P remains intact; open the gate without editing or repairing history.
    -- -------------------------------------------------------------------------
    SELECT plan(4);
    SELECT is((SELECT COUNT(*) FROM public.flyway_schema_history), 2::bigint, 'Failed candidate left predecessor history');
    SELECT ok(TO_REGCLASS('public.framework_candidate') IS NULL, 'Failed candidate object is absent');
    SELECT is((SELECT label FROM public.framework_reference WHERE id=9), 'predecessor', 'Predecessor data survived failure');
    INSERT INTO public.framework_gate VALUES (true);
    SELECT ok((SELECT BOOL_OR(allowed) FROM public.framework_gate), 'Resolve gate without changing candidate bytes');
    SELECT * FROM finish();
    COMMIT;
\else
    \if :zero_plan
        SELECT '1..0 # SKIP fixed zero-plan regression';
        ROLLBACK;
        \quit
    \elif :wrong_plan
        SELECT plan(99);
    \elif :prepare
        SELECT plan(3);
    \elif :verify
        SELECT plan(6);
    \else
        SELECT plan(2);
    \endif

    \if :fresh
        -- ---------------------------------------------------------------------
        -- Scenario: Full fresh applies the initial migration and later sentinel.
        -- Setup: Entire fixed history has migrated from empty.
        -- Expected: Foundation reference survives; sentinel removed candidate view.
        -- ---------------------------------------------------------------------
        SELECT is((SELECT label FROM public.framework_reference WHERE id=9), 'predecessor', 'Initial foundation and reference data exist on fresh');
        SELECT ok(TO_REGCLASS('public.framework_candidate') IS NULL, 'Latest sentinel removes candidate object on fresh');
    \elif :prepare
        -- ---------------------------------------------------------------------
        -- Scenario: Preparation commits ordinary owner observations across sessions.
        -- Setup: Only the migration-created reference row is observed.
        -- Expected: TEMP and rollback controls lose evidence and verification fails.
        -- ---------------------------------------------------------------------
        CREATE SCHEMA opal_framework_owner_state;
        \if :temporary
            CREATE TEMP TABLE observation AS SELECT :'opal_scenario_id'::text AS scenario_id,
                (SELECT JSONB_AGG(TO_JSONB(r) ORDER BY id) FROM public.framework_reference r) AS rows;
        \else
            CREATE TABLE opal_framework_owner_state.observation AS
            SELECT :'opal_scenario_id'::text AS scenario_id,
                (SELECT JSONB_AGG(TO_JSONB(r) ORDER BY id) FROM public.framework_reference r) AS rows;
        \endif
        SELECT ok(TO_REGCLASS('public.framework_candidate') IS NULL, 'Candidate absent before install');
        SELECT is((SELECT label FROM public.framework_reference WHERE id=9), 'predecessor', 'Nonempty migration-created predecessor');
        SELECT ok(TO_REGNAMESPACE('opal_framework_owner_state') IS NOT NULL, 'Owner observation namespace created');
        \if :retry
            DELETE FROM public.framework_gate;
        \else
            INSERT INTO public.framework_gate VALUES (true);
        \endif
        \if :failed_history
            INSERT INTO public.flyway_schema_history VALUES (90, '0.1', 'fixed failed row', 'SQL', 'failed.sql', 1, 'postgres', NOW(), 0, false);
        \endif
    \elif :verify
        -- ---------------------------------------------------------------------
        -- Scenario: C is visible while later sentinel and test catalogue are excluded.
        -- Setup: A new connection reads the named committed owner observation.
        -- Expected: Exact scoped preservation, active view, positive full contract.
        -- ---------------------------------------------------------------------
        \if :mutation
            UPDATE public.framework_reference SET label='changed' WHERE id=9;
        \endif
        SELECT is((SELECT scenario_id FROM opal_framework_owner_state.observation), :'opal_scenario_id', 'Durable observation belongs to scenario');
        SELECT is((SELECT JSONB_AGG(TO_JSONB(r) ORDER BY id) FROM public.framework_reference r),
                  (SELECT rows FROM opal_framework_owner_state.observation), 'Named application rows preserved before functional work');
        SELECT ok(TO_REGCLASS('public.framework_candidate') IS NOT NULL, 'Later sentinel excluded at C');
        SELECT is((SELECT label FROM public.framework_candidate WHERE id=9), 'predecessor', 'Candidate view has correct behavior');
        SELECT ok(NOT EXISTS (SELECT 1 FROM public.flyway_schema_history WHERE version='1.11'), 'Later history excluded at C');
        SELECT ok(TO_REGNAMESPACE('opal_db_unit_test_framework_state') IS NOT NULL
                  AND TO_REGNAMESPACE('opal_framework_owner_state') IS NOT NULL,
                  'Test state exists outside named application observations');
    \elif :cleanup
        -- ---------------------------------------------------------------------
        -- Scenario: Successful cleanup removes only the owner observation schema.
        -- Setup: Verify persisted scenario identity before dropping test state.
        -- Expected: Namespace removal commits and carries a positive TAP plan.
        -- ---------------------------------------------------------------------
        SELECT is((SELECT scenario_id FROM opal_framework_owner_state.observation), :'opal_scenario_id', 'Cleanup owns the scenario');
        DROP SCHEMA opal_framework_owner_state CASCADE;
        SELECT ok(TO_REGNAMESPACE('opal_framework_owner_state') IS NULL, 'Owner observation removed');
    \else
        DO $unknown$ BEGIN RAISE EXCEPTION 'Unknown fixed fixture phase'; END; $unknown$;
    \endif
    \if :sql_error
        DO $failure$ BEGIN RAISE EXCEPTION 'fixed hard SQL error after passing assertions'; END; $failure$;
    \endif
    \if :tap_error
        SELECT fail('fixed failing phase assertion');
    \endif
    SELECT * FROM finish();
    \if :fresh
        ROLLBACK;
    \elif :verify
        ROLLBACK;
    \elif :rolled_back
        ROLLBACK;
    \else
        COMMIT;
    \endif
\endif
