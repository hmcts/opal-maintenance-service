/**
 * OPAL Program
 *
 * MODULE      : owner.sql
 *
 * DESCRIPTION : Functional assertion groups for the shared contract regression.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket        Nature of Change
 * ----------  -------------  ------------  ----------------------------------------
 * 15/10/2026  Frankie Moran  PO-10643      Verify shared dispatch without owner phases.
 * 22/10/2026  Frankie Moran  PO-10643      Exercise declaring-owner data verification.
 */
-- OPAL-DB-UPGRADE {"id":"framework.shared_candidate","candidate":"ddl/V1_10__candidate.sql","scope":"both","data":"migration-created-only","contract":{"type":"additive","objects":{"created":[{"kind":"view","identity":"public.framework_candidate"}],"replaced":[]},"preserve":{"rows":["public.framework_reference"],"tables":["public.framework_reference"],"routines":[],"enums":[],"sequences":[]},"assertion":"fixture.candidate"}}
-- Approved data scenario: fixed framework-only synthetic custom preparation regression.
\set ON_ERROR_STOP 1
\ir ../../support/upgrade_contract.sql
\if :{?opal_assertion_group}
\else
    \set opal_assertion_group fixture.current
\endif
\if :{?opal_test_case}
\else
    \set opal_test_case good
\endif
SELECT :'opal_assertion_group'='fixture.candidate' AS candidate_group,
       :'opal_assertion_group'='fixture.data' AS data_group,
       :'opal_assertion_group' IN ('fixture.current','fixture.candidate','fixture.data') AS valid_group,
       :'opal_test_case'='contract-future-dependency' AS missing_historical_dependency
\gset
\if :valid_group
\else
    DO $group$ BEGIN RAISE EXCEPTION 'Unknown shared fixture assertion group'; END; $group$;
\endif
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SET LOCAL search_path = public, pg_catalog;
\if :missing_historical_dependency
    SELECT plan(1);
    -- -------------------------------------------------------------------------
    -- Scenario: An unavailable assertion dependency must fail at the real boundary.
    -- Setup: Candidate excludes the future-only dependency requested by this control.
    -- Expected: Actual missing-relation SQL fails the required lives_ok assertion.
    -- -------------------------------------------------------------------------
    SELECT lives_ok($q$SELECT * FROM public.framework_future_only$q$,
        'historical assertions require their real dependency');
\elif :data_group
    SELECT plan(2);
    -- -------------------------------------------------------------------------
    -- Scenario: The declaring owner verifies a compact shared data observation.
    -- Setup: Shared prepare captured an empty table before the real data migration.
    -- Expected: Custom verification loads exact predecessor rows; ordinary probes roll back.
    -- -------------------------------------------------------------------------
    \if :is_verify
        SELECT pg_temp.opal_contract_load(:'opal_contract_json'::JSONB,
            :'opal_scenario_id',:'opal_candidate_version',:'opal_predecessor_version') AS saved \gset
        SELECT is(:'saved'::JSONB->'observed'->'rows'->'public.framework_reference','[]'::JSONB,
            'data owner reads exact empty predecessor observation');
    \else
        SELECT ok(EXISTS(SELECT 1 FROM public.flyway_schema_history WHERE version='1.9')
            AND NOT EXISTS(SELECT 1 FROM public.flyway_schema_history WHERE version='1.10'),
            'data owner runs at the real historical candidate');
    \endif
    SELECT is((SELECT label FROM public.framework_reference WHERE id=9),'predecessor',
        'data candidate inserts its real reference row');
\elif :candidate_group
    SELECT plan(4);
    -- -------------------------------------------------------------------------
    -- Scenario: Direct candidate behaviour runs after shared preservation finishes.
    -- Setup: Real 1.10 installed; later sentinel remains excluded from the target.
    -- Expected: Candidate view and reference behaviour work without owner plumbing.
    -- -------------------------------------------------------------------------
    SELECT ok(TO_REGCLASS('public.framework_candidate') IS NOT NULL,'candidate view installed before direct assertions');
    SELECT is((SELECT label FROM public.framework_candidate WHERE id=9),'predecessor',
        'candidate reads the migration-created reference row');
    SELECT ok(NOT EXISTS(SELECT 1 FROM public.flyway_schema_history WHERE version='1.11'),
        'later sentinel remains excluded at candidate');
    SELECT ok(TO_REGNAMESPACE('opal_test_upgrade_observation') IS NOT NULL,
        'shared observation is available without owner lifecycle code');
\else
    SELECT plan(2);
    -- -------------------------------------------------------------------------
    -- Scenario: Current full schema uses its compatible ordinary assertion group.
    -- Setup: All real fixed migrations installed; the later sentinel removed the view.
    -- Expected: Reference data remains and obsolete candidate view is absent.
    -- -------------------------------------------------------------------------
    SELECT is((SELECT label FROM public.framework_reference WHERE id=9),'predecessor',
        'full fresh reference behaviour remains covered');
    SELECT ok(TO_REGCLASS('public.framework_candidate') IS NULL,'full fresh later sentinel ran');
\endif
SELECT * FROM finish();
ROLLBACK;
