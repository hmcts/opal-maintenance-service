/**
 * OPAL Program
 *
 * MODULE      : db_upgrade_framework_pgtap_tests.sql
 *
 * DESCRIPTION : Disposable Flyway history boundaries and durable observations.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket        Nature of Change
 * ----------  -------------  ------------  ----------------------------------------
 * 13/10/2026  Frankie Moran  PO-10643      Initial pgTAP test suite.
 */
\set ON_ERROR_STOP 1
\if :{?opal_framework_phase}
\else
    \set opal_framework_phase fresh
\endif

-- -----------------------------------------------------------------------------
-- Scenario: Every phase runs only inside the maintained disposable harness.
-- Setup: The runner supplies a validated selected-history prefix as JSON.
-- Expected: Unknown phases or harness identities fail before modifying test state.
-- -----------------------------------------------------------------------------
SELECT :'opal_framework_phase' IN ('fresh','snapshot','predecessor','candidate','repeat','cleanup') AS valid_phase,
       :'opal_framework_phase' = 'cleanup' AS is_cleanup,
       :'opal_framework_phase' IN ('snapshot','predecessor') AS is_capture,
       :'opal_framework_phase' = 'candidate' AS is_candidate,
       :'opal_framework_phase' = 'repeat' AS is_repeat,
       :'opal_framework_phase' = 'predecessor' AS is_predecessor
\gset
DO $guard$
BEGIN
    IF CURRENT_DATABASE() <> 'opal_maintenance_db_unit_test' OR CURRENT_USER <> 'postgres' THEN
        RAISE EXCEPTION 'Framework requires its disposable harness database and role';
    END IF;
END;
$guard$;
\if :valid_phase
\else
    DO $invalid$ BEGIN RAISE EXCEPTION 'Unknown framework phase'; END; $invalid$;
\endif

BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT diag('pgTAP version: ' || pgtap_version());
\if :is_cleanup
    SELECT plan(2);
    SELECT is((SELECT scenario_id FROM opal_db_unit_test_framework_state.observation),
              :'opal_scenario_id', 'Framework cleanup owns this scenario');
    SELECT SET_CONFIG('opal.framework_cleanup_scenario', :'opal_scenario_id', true) AS identity_setting
    \gset
    DO $ownership$
    BEGIN
        IF (SELECT COUNT(*) FROM opal_db_unit_test_framework_state.observation) <> 1
           OR (SELECT scenario_id FROM opal_db_unit_test_framework_state.observation)
              IS DISTINCT FROM CURRENT_SETTING('opal.framework_cleanup_scenario') THEN
            RAISE EXCEPTION 'Framework cleanup identity mismatch';
        END IF;
    END;
    $ownership$;
    DROP SCHEMA opal_db_unit_test_framework_state CASCADE;
    SELECT ok(TO_REGNAMESPACE('opal_db_unit_test_framework_state') IS NULL,
              'Framework observation state removed');
    SELECT * FROM finish();
    COMMIT;
\else
    \if :is_predecessor
        SELECT plan(5);
    \elif :is_candidate
        SELECT plan(8);
    \elif :is_repeat
        SELECT plan(5);
    \else
        SELECT plan(3);
    \endif

    -- -------------------------------------------------------------------------
    -- Scenario: History equals precisely the selected boundary, including failures.
    -- Setup: Native discovery supplies the numerically ordered expected identities.
    -- Expected: Missing/extra/failed/later rows cannot pass a subset comparison.
    -- -------------------------------------------------------------------------
    SELECT is((SELECT JSONB_AGG(JSONB_BUILD_OBJECT('version',version,'script',script)
                               ORDER BY installed_rank) FROM public.flyway_schema_history),
              :'opal_expected_history'::jsonb, 'History equals exact selected prefix');
    SELECT ok((SELECT COUNT(*) > 0 AND BOOL_AND(success) FROM public.flyway_schema_history),
              'Every selected migration succeeded and history is nonempty');
    SELECT ok((SELECT BOOL_AND(type = 'SQL' AND checksum IS NOT NULL)
               FROM public.flyway_schema_history), 'Every selected migration is checksummed SQL');

    \if :is_capture
        CREATE SCHEMA opal_db_unit_test_framework_state;
        CREATE TABLE opal_db_unit_test_framework_state.observation AS
        SELECT :'opal_scenario_id'::text AS scenario_id,
               (SELECT JSONB_AGG(TO_JSONB(h) ORDER BY installed_rank)
                FROM public.flyway_schema_history h) AS history;
        \if :is_predecessor
            SELECT is((SELECT version FROM public.flyway_schema_history ORDER BY installed_rank DESC LIMIT 1),
                      :'opal_predecessor_version', 'Actual immediate predecessor is the boundary');
            SELECT ok(NOT EXISTS (SELECT 1 FROM public.flyway_schema_history
                                  WHERE version = :'opal_candidate_version'), 'Candidate is absent at predecessor');
        \endif
        SELECT * FROM finish();
        COMMIT;
    \elif :is_candidate
        -- ---------------------------------------------------------------------
        -- Scenario: Installing C preserves every complete predecessor history row.
        -- Setup: A separate connection committed the predecessor observation.
        -- Expected: Only C is appended; capture all columns for the no-op repeat.
        -- ---------------------------------------------------------------------
        SELECT is((SELECT scenario_id FROM opal_db_unit_test_framework_state.observation),
                  :'opal_scenario_id', 'Candidate reads its durable predecessor scenario');
        SELECT is((SELECT JSONB_AGG(TO_JSONB(h) ORDER BY installed_rank)
                   FROM public.flyway_schema_history h WHERE version <> :'opal_candidate_version'),
                  (SELECT history FROM opal_db_unit_test_framework_state.observation),
                  'All complete predecessor history rows are preserved');
        SELECT is((SELECT COUNT(*) FROM public.flyway_schema_history WHERE version = :'opal_candidate_version'),
                  1::bigint, 'Exactly one candidate history row was added');
        SELECT is((SELECT version FROM public.flyway_schema_history ORDER BY installed_rank DESC LIMIT 1),
                  :'opal_candidate_version', 'Candidate is the last installed version');
        SELECT is((SELECT COUNT(*) FROM public.flyway_schema_history),
                  (SELECT JSONB_ARRAY_LENGTH(history)::bigint + 1 FROM opal_db_unit_test_framework_state.observation),
                  'Candidate added exactly one row to predecessor history');
        UPDATE opal_db_unit_test_framework_state.observation
        SET history = (SELECT JSONB_AGG(TO_JSONB(h) ORDER BY installed_rank) FROM public.flyway_schema_history h);
        SELECT * FROM finish();
        COMMIT;
    \elif :is_repeat
        SELECT is((SELECT scenario_id FROM opal_db_unit_test_framework_state.observation),
                  :'opal_scenario_id', 'Repeat reads the correct durable scenario');
        SELECT is((SELECT JSONB_AGG(TO_JSONB(h) ORDER BY installed_rank) FROM public.flyway_schema_history h),
                  (SELECT history FROM opal_db_unit_test_framework_state.observation),
                  'Repeat preserves every complete history row');
        SELECT * FROM finish();
        ROLLBACK;
    \else
        SELECT * FROM finish();
        ROLLBACK;
    \endif
\endif
