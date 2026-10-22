/**
 * OPAL Program
 *
 * MODULE      : db_upgrade_contract_pgtap_tests.sql
 *
 * DESCRIPTION : Shared declared-scope preservation and contract regression checks.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket        Nature of Change
 * ----------  -------------  ------------  ----------------------------------------
 * 15/10/2026  Frankie Moran  PO-10643      Initial shared-contract pgTAP test suite.
 * 22/10/2026  Frankie Moran  PO-10643      Verify bounded data observations and exact capture.
 */
\set ON_ERROR_STOP 1
\ir support/upgrade_contract.sql
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SET LOCAL search_path = public, pg_catalog;
SELECT plan(36);
-- -----------------------------------------------------------------------------
-- Scenario: Shared capture observes real scoped rows without rewriting JSON text.
-- Setup: A rolled-back synthetic table contains duplicate-key JSON source text.
-- Expected: Shared capture accepts the declared native table and its exact rows.
-- -----------------------------------------------------------------------------
CREATE TABLE public.opal_contract_fixture(id BIGINT, payload JSON);
INSERT INTO public.opal_contract_fixture VALUES (1, '{ "key" : 1, "key" : 2 }');
SELECT lives_ok($check$
    SELECT pg_temp.opal_contract_snapshot('{"objects":{"created":[],"replaced":[]},
        "preserve":{"rows":["public.opal_contract_fixture"],"tables":[],"routines":[],
        "enums":[],"sequences":[]},"assertion":"fixture.current"}'::JSONB)
$check$, 'shared preservation captures declared native rows');
SELECT '{"objects":{"created":[],"replaced":[]},"preserve":{
    "rows":["public.opal_contract_fixture"],"tables":["public.opal_contract_fixture"],
    "routines":[],"enums":[],"sequences":[]},"assertion":"fixture.current"}'::JSONB AS fixture_contract
\gset
SELECT pg_temp.opal_contract_snapshot(:'fixture_contract'::JSONB) AS original_snapshot \gset
SELECT is(:'original_snapshot'::JSONB->'rows'->'public.opal_contract_fixture'->>0,
    (SELECT ROW_TO_JSON(t)::TEXT FROM public.opal_contract_fixture t),
    'shared snapshot retains exact duplicate-key JSON row text');
SELECT ok(POSITION('{ "key" : 1, "key" : 2 }' IN (:'original_snapshot'::JSONB->'rows'->'public.opal_contract_fixture'->>0))>0,
    'embedded JSON formatting and duplicate keys remain present');
UPDATE public.opal_contract_fixture SET payload='{ "key" : 1, "key" : 3 }';
SELECT ok(:'original_snapshot'::JSONB->'rows' IS DISTINCT FROM
    pg_temp.opal_contract_snapshot(:'fixture_contract'::JSONB)->'rows',
    'changed duplicate-key row text fails preservation equality');
UPDATE public.opal_contract_fixture SET payload='{ "key" : 1, "key" : 2 }';
SELECT ok(:'original_snapshot'::JSONB IS NOT DISTINCT FROM pg_temp.opal_contract_snapshot(:'fixture_contract'::JSONB),
    'restored row text and native metadata equal original scope');
COMMENT ON COLUMN public.opal_contract_fixture.id IS 'Synthetic changed column contract';
SELECT ok(:'original_snapshot'::JSONB-'rows' IS DISTINCT FROM
    pg_temp.opal_contract_snapshot(:'fixture_contract'::JSONB)-'rows',
    'changed column metadata fails preservation equality');
COMMENT ON COLUMN public.opal_contract_fixture.id IS NULL;
GRANT SELECT(id) ON public.opal_contract_fixture TO PUBLIC;
SELECT ok(:'original_snapshot'::JSONB-'rows' IS DISTINCT FROM
    pg_temp.opal_contract_snapshot(:'fixture_contract'::JSONB)-'rows',
    'changed column privilege fails preservation equality');
REVOKE SELECT(id) ON public.opal_contract_fixture FROM PUBLIC;
SELECT throws_ok($q$SELECT pg_temp.opal_contract_snapshot('{}'::JSONB)$q$,'P0001',NULL,
    'missing shared contract fails closed');
SELECT throws_ok($q$SELECT pg_temp.opal_contract_snapshot('{"objects":{"created":[],"replaced":[]},
    "preserve":{"rows":["public.opal_contract_missing"],"tables":[],"routines":[],"enums":[],"sequences":[]},
    "assertion":"fixture.current"}'::JSONB)$q$,'P0001',NULL,
    'missing historical row dependency fails closed');
-- -----------------------------------------------------------------------------
-- Scenario: Native object captures distinguish creation, replacement and preservation.
-- Setup: Rolled-back test-only routine, enum, sequence and table definitions.
-- Expected: Definitions and sequence values are exact; incompatible kinds fail.
-- -----------------------------------------------------------------------------
CREATE FUNCTION public.opal_contract_routine(BIGINT) RETURNS BIGINT LANGUAGE SQL AS 'SELECT $1 + 1';
CREATE TYPE public.opal_contract_enum AS ENUM ('synthetic_a','synthetic_b');
CREATE SEQUENCE public.opal_contract_sequence;
CREATE VIEW public.opal_contract_view AS SELECT id FROM public.opal_contract_fixture;
SELECT pg_temp.opal_contract_object('routine','public.opal_contract_routine(bigint)') AS original_routine \gset
SELECT ok(:'original_routine'::JSONB->>'definition' IS NOT NULL,
    'shared routine capture includes native definition');
CREATE OR REPLACE FUNCTION public.opal_contract_routine(BIGINT) RETURNS BIGINT LANGUAGE SQL AS 'SELECT $1 + 2';
SELECT ok(:'original_routine'::JSONB->'definition' IS DISTINCT FROM
    pg_temp.opal_contract_object('routine','public.opal_contract_routine(bigint)')->'definition',
    'replacement routine definition change is detected');
SELECT ok(:'original_routine'::JSONB->'metadata' IS NOT DISTINCT FROM
    pg_temp.opal_contract_object('routine','public.opal_contract_routine(bigint)')->'metadata',
    'ordinary replacement preserves catalogue identity and properties');
ALTER FUNCTION public.opal_contract_routine(BIGINT) SECURITY DEFINER;
SELECT ok(:'original_routine'::JSONB->'metadata' IS DISTINCT FROM
    pg_temp.opal_contract_object('routine','public.opal_contract_routine(bigint)')->'metadata',
    'changed routine security property fails preservation equality');
SELECT ok(pg_temp.opal_contract_object('enum','public.opal_contract_enum')->'labels' IS NOT NULL,
    'shared enum capture includes ordered labels');
SELECT pg_temp.opal_contract_object('sequence','public.opal_contract_sequence') AS original_sequence \gset
SELECT NEXTVAL('public.opal_contract_sequence');
SELECT ok(:'original_sequence'::JSONB IS DISTINCT FROM
    pg_temp.opal_contract_object('sequence','public.opal_contract_sequence'),
    'sequence consumption is detected before functional assertions');
SELECT ok(pg_temp.opal_contract_object('routine','public.opal_contract_missing(bigint)') IS NULL,
    'missing created routine is represented as absent');
SELECT ok(pg_temp.opal_contract_object('view','public.opal_contract_view')->>'definition' IS NOT NULL,
    'declared view has a native definition');
SELECT throws_ok($q$SELECT pg_temp.opal_contract_object('table','public.opal_contract_view')$q$,'P0001',NULL,
    'view cannot satisfy a declared table contract');
SELECT throws_ok($q$SELECT pg_temp.opal_contract_object('sequence','public.opal_contract_fixture')$q$,'P0001',NULL,
    'table cannot satisfy a declared sequence contract');
SELECT throws_ok($q$SELECT pg_temp.opal_contract_object('enum','public.opal_contract_fixture')$q$,'P0001',NULL,
    'missing enum does not substitute a same-named table');
SELECT ok(pg_temp.opal_contract_object('table','public.opal_contract_fixture') IS NOT NULL,
    'declared table resolves its actual native kind');
SELECT ok(pg_temp.opal_contract_changed_objects('{"objects":{"created":[
    {"kind":"routine","identity":"public.opal_contract_missing(bigint)"}],"replaced":[]},
    "preserve":{"rows":[],"tables":[],"routines":[],"enums":[],"sequences":[]},
    "assertion":"fixture.current"}'::JSONB)->'created'->'routine:public.opal_contract_missing(bigint)'='null'::JSONB,
    'created declaration records true predecessor absence');
SELECT ok(pg_temp.opal_contract_changed_objects('{"objects":{"created":[],"replaced":[
    {"kind":"routine","identity":"public.opal_contract_routine(bigint)"}]},
    "preserve":{"rows":[],"tables":[],"routines":[],"enums":[],"sequences":[]},
    "assertion":"fixture.current"}'::JSONB)->'replaced'->'routine:public.opal_contract_routine(bigint)' IS NOT NULL,
    'replacement declaration records complete predecessor routine');
SELECT throws_ok($q$SELECT pg_temp.opal_contract_object('unsupported','public.opal_contract_fixture')$q$,'P0001',NULL,
    'unsupported changed object kind fails closed');
-- -----------------------------------------------------------------------------
-- Scenario: Shared data observations retain exact mutable data for custom checks.
-- Setup: Duplicate source-JSON rows and a sequence are observed without preservation exemptions.
-- Expected: Original row text/multiplicity and full sequence state survive capture; invalid scopes fail.
-- -----------------------------------------------------------------------------
INSERT INTO public.opal_contract_fixture SELECT * FROM public.opal_contract_fixture;
SELECT '{"type":"data","objects":{"created":[],"replaced":[]},
    "preserve":{"rows":[],"tables":[],"routines":[],"enums":[],"sequences":[]},
    "observe":{"rows":["public.opal_contract_fixture"],"sequences":["public.opal_contract_sequence"]},
    "assertion":"fixture.data"}'::JSONB AS observation_contract \gset
SELECT is(pg_temp.opal_contract_observe(:'observation_contract'::JSONB)->'rows'->'public.opal_contract_fixture',
    (SELECT JSONB_AGG(ROW_TO_JSON(t)::TEXT ORDER BY ROW_TO_JSON(t)::TEXT) FROM public.opal_contract_fixture t),
    'data observation retains duplicate-key source text and duplicate row multiplicity');
SELECT is(pg_temp.opal_contract_observe(:'observation_contract'::JSONB)->'sequences'->'public.opal_contract_sequence',
    pg_temp.opal_contract_object('sequence','public.opal_contract_sequence'),
    'data observation captures complete sequence definition, ownership, privileges and state');
SELECT is(pg_temp.opal_contract_observe(:'fixture_contract'::JSONB),'{}'::JSONB,
    'existing contracts without observations keep their bounded empty observation');
SELECT throws_ok($q$SELECT pg_temp.opal_contract_observe('{"type":"data","objects":{"created":[],"replaced":[]},
    "preserve":{"rows":[],"tables":[],"routines":[],"enums":[],"sequences":[]},
    "observe":{"rows":[]},"assertion":"fixture.data"}'::JSONB)$q$,'P0001',NULL,
    'malformed observation missing sequence scope fails closed');
SELECT throws_ok($q$SELECT pg_temp.opal_contract_observe('{"type":"additive","objects":{"created":[],"replaced":[]},
    "preserve":{"rows":[],"tables":[],"routines":[],"enums":[],"sequences":[]},
    "observe":{"rows":["public.opal_contract_fixture"],"sequences":[]},"assertion":"fixture.data"}'::JSONB)$q$,'P0001',NULL,
    'observation outside an explicit data contract fails closed');
SELECT throws_ok($q$SELECT pg_temp.opal_contract_observe('{"type":"data","objects":{"created":[],"replaced":[]},
    "preserve":{"rows":[],"tables":[],"routines":[],"enums":[],"sequences":[]},
    "observe":{"rows":[],"sequences":["public.opal_contract_missing"]},"assertion":"fixture.data"}'::JSONB)$q$,'P0001',NULL,
    'missing observed sequence cannot silently produce incomplete data evidence');
SELECT ok(TO_REGNAMESPACE('opal_test_upgrade_observation') IS NULL,
    'pure shared snapshots create no committed observation state');
-- -----------------------------------------------------------------------------
-- Scenario: Stored declaration provenance guards observations and cleanup eligibility.
-- Setup: A rolled-back exact identity tuple owns one shared contract observation.
-- Expected: A changed declaration cannot load it; rejected access preserves its state.
-- -----------------------------------------------------------------------------
SELECT SET_CONFIG('opal.upgrade_scenario','fixture.shared',false);
SELECT SET_CONFIG('opal.upgrade_candidate','2',false);
SELECT SET_CONFIG('opal.upgrade_predecessor','1',false);
SELECT pg_temp.opal_upgrade_save('fixture.shared','2','1',
    JSONB_BUILD_OBJECT('contract',:'fixture_contract'::JSONB,
        'snapshot',pg_temp.opal_contract_snapshot(:'fixture_contract'::JSONB)));
SELECT lives_ok($q$SELECT pg_temp.opal_contract_load('{"objects":{"created":[],"replaced":[]},
    "preserve":{"rows":["public.opal_contract_fixture"],"tables":["public.opal_contract_fixture"],
    "routines":[],"enums":[],"sequences":[]},"assertion":"fixture.current"}'::JSONB,
    'fixture.shared','2','1')$q$,'matching declaration loads its exact owned observation');
SELECT throws_ok($q$SELECT pg_temp.opal_contract_load('{"objects":{"created":[],"replaced":[]},
    "preserve":{"rows":["public.opal_contract_fixture"],"tables":["public.opal_contract_fixture"],
    "routines":[],"enums":[],"sequences":[]},"assertion":"fixture.changed"}'::JSONB,
    'fixture.shared','2','1')$q$,'P0001','Stored preservation contract provenance mismatch',
    'changed declaration is rejected before observation access or cleanup');
SELECT throws_ok($q$SELECT pg_temp.opal_contract_remove('{"objects":{"created":[],"replaced":[]},
    "preserve":{"rows":["public.opal_contract_fixture"],"tables":["public.opal_contract_fixture"],
    "routines":[],"enums":[],"sequences":[]},"assertion":"fixture.changed"}'::JSONB,
    'fixture.shared','2','1')$q$,'P0001','Stored preservation contract provenance mismatch',
    'changed cleanup declaration cannot remove original owned observation');
SELECT ok(TO_REGCLASS('opal_test_upgrade_observation.observation') IS NOT NULL,
    'rejected changed declaration preserves owned observation');
SELECT lives_ok($q$SELECT pg_temp.opal_upgrade_remove('fixture.shared','2','1')$q$,
    'original exact owner can remove its validated observation');
SELECT * FROM finish();
ROLLBACK;
