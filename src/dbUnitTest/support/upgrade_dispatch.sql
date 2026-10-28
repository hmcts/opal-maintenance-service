/**
 * OPAL Program
 *
 * MODULE      : upgrade_dispatch.sql
 *
 * DESCRIPTION : Shared prepare, preservation and cleanup for compact contracts.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket        Nature of Change
 * ----------  -------------  ------------  ----------------------------------------
 * 15/10/2026  Frankie Moran  PO-10643      Centralise contract lifecycle and TAP.
 * 22/10/2026  Frankie Moran  PO-10643      Share bounded data observation capture.
 */
\set ON_ERROR_STOP 1
\ir upgrade_contract.sql
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SET LOCAL search_path = public, pg_catalog;
SET LOCAL TIME ZONE 'UTC';
SET LOCAL statement_timeout = '30s';
SELECT pg_temp.opal_upgrade_require_identity(:'opal_scenario_id', :'opal_candidate_version', :'opal_predecessor_version');
SELECT pg_temp.opal_contract_require(:'opal_contract_json'::JSONB);
SELECT :'opal_contract_json'::JSONB AS contract,
       :'opal_contract_json'::JSONB ? 'observe' AS has_observation \gset
\if :is_prepare
    SELECT plan(2 + CASE WHEN :'has_observation'::BOOLEAN THEN 1 ELSE 0 END
        + JSONB_ARRAY_LENGTH(:'contract'::JSONB->'objects'->'created')
        + JSONB_ARRAY_LENGTH(:'contract'::JSONB->'objects'->'replaced'));
    -- -------------------------------------------------------------------------
    -- Scenario: Capture declared predecessor scope through shared observation state.
    -- Setup: Real predecessor migrations and any approved custom preparation ran.
    -- Expected: Creates are absent, replacements present, exact rows/metadata saved.
    -- -------------------------------------------------------------------------
    SELECT pg_temp.opal_contract_changed_objects(:'contract'::JSONB) AS changed \gset
    SELECT ok(value='null'::JSONB,'declared created object absent at predecessor')
    FROM JSONB_EACH(:'changed'::JSONB->'created');
    SELECT ok(value IS DISTINCT FROM 'null'::JSONB,'declared replaced routine present at predecessor')
    FROM JSONB_EACH(:'changed'::JSONB->'replaced');
    SELECT pg_temp.opal_upgrade_save(:'opal_scenario_id', :'opal_candidate_version', :'opal_predecessor_version',
        JSONB_BUILD_OBJECT('contract', :'contract'::JSONB,
            'snapshot',pg_temp.opal_contract_snapshot(:'contract'::JSONB),'objects',:'changed'::JSONB,
            'observed',pg_temp.opal_contract_observe(:'contract'::JSONB)));
    SELECT pg_temp.opal_contract_load(:'contract'::JSONB, :'opal_scenario_id', :'opal_candidate_version', :'opal_predecessor_version') AS saved \gset
    SELECT ok(:'saved'::JSONB->'contract'=:'contract'::JSONB,'stored contract has exact provenance');
    SELECT ok(:'saved'::JSONB->'snapshot'=pg_temp.opal_contract_snapshot(:'contract'::JSONB),
        'stored declared predecessor state is exact');
    \if :has_observation
        SELECT ok(:'saved'::JSONB->'observed'=pg_temp.opal_contract_observe(:'contract'::JSONB),
            'stored declared data observation is exact');
    \endif
    SELECT * FROM finish();
    COMMIT;
\elif :is_verify
    SELECT plan(3 + JSONB_ARRAY_LENGTH(:'contract'::JSONB->'objects'->'created')
        + 3 * JSONB_ARRAY_LENGTH(:'contract'::JSONB->'objects'->'replaced'));
    -- -------------------------------------------------------------------------
    -- Scenario: Shared preservation finishes before functional calls mutate state.
    -- Setup: A new connection loads the committed exact contract and predecessor.
    -- Expected: All scoped rows/metadata unchanged; only declared definitions change.
    -- -------------------------------------------------------------------------
    SELECT pg_temp.opal_contract_load(:'contract'::JSONB, :'opal_scenario_id', :'opal_candidate_version', :'opal_predecessor_version') AS saved \gset
    SELECT pg_temp.opal_contract_snapshot(:'contract'::JSONB) AS current_snapshot \gset
    SELECT pg_temp.opal_contract_changed_objects(:'contract'::JSONB) AS changed \gset
    SELECT ok(:'saved'::JSONB->'contract'=:'contract'::JSONB,'verification contract matches preparation');
    SELECT ok(:'saved'::JSONB->'snapshot'->'rows' IS NOT DISTINCT FROM :'current_snapshot'::JSONB->'rows',
        'all declared predecessor row text preserved');
    SELECT ok(((:'saved'::JSONB->'snapshot')-'rows') IS NOT DISTINCT FROM (:'current_snapshot'::JSONB-'rows'),
        'all declared predecessor metadata and sequence state preserved');
    SELECT ok(value IS DISTINCT FROM 'null'::JSONB,'declared created object installed at candidate')
    FROM JSONB_EACH(:'changed'::JSONB->'created');
    SELECT ok(value IS DISTINCT FROM 'null'::JSONB,'declared replacement exists at candidate')
    FROM JSONB_EACH(:'changed'::JSONB->'replaced');
    SELECT ok(value->'metadata' IS NOT DISTINCT FROM (:'saved'::JSONB->'objects'->'replaced'->key->'metadata'),
        'replaced routine retains catalogue identity and properties')
    FROM JSONB_EACH(:'changed'::JSONB->'replaced');
    SELECT ok(value->'definition' IS DISTINCT FROM (:'saved'::JSONB->'objects'->'replaced'->key->'definition'),
        'declared replacement changes routine definition')
    FROM JSONB_EACH(:'changed'::JSONB->'replaced');
    SELECT * FROM finish();
    ROLLBACK;
\elif :is_cleanup
    SELECT plan(2);
    -- -------------------------------------------------------------------------
    -- Scenario: Shared cleanup removes only the validated owned observations.
    -- Setup: Exact stored contract and guarded observation provenance are checked.
    -- Expected: Committed removal has independent readback; no connection remains.
    -- -------------------------------------------------------------------------
    SELECT pg_temp.opal_contract_load(:'contract'::JSONB, :'opal_scenario_id', :'opal_candidate_version', :'opal_predecessor_version') AS saved \gset
    SELECT ok(:'saved'::JSONB->'contract'=:'contract'::JSONB,'cleanup contract matches preparation');
    SELECT pg_temp.opal_contract_remove(:'contract'::JSONB, :'opal_scenario_id', :'opal_candidate_version', :'opal_predecessor_version');
    COMMIT;
    BEGIN;
    SELECT ok(pg_temp.opal_upgrade_absent_from_new_backend(),'independent backend confirms committed shared cleanup');
    SELECT * FROM finish();
    ROLLBACK;
\else
    DO $phase$ BEGIN RAISE EXCEPTION 'Shared dispatch requires prepare, verify or cleanup'; END; $phase$;
\endif
