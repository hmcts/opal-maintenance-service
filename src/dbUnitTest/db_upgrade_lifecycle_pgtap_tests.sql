/**
 * OPAL Program
 *
 * MODULE      : db_upgrade_lifecycle_pgtap_tests.sql
 *
 * DESCRIPTION : Guarded owner observations and exact payload lifecycle regression.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket        Nature of Change
 * ----------  -------------  ------------  ----------------------------------------
 * 14/10/2026  Frankie Moran  PO-10643      Initial shared lifecycle regressions.
 */
\set ON_ERROR_STOP 1
-- This generic owner uses a synthetic tuple, confined to its rolled-back suite.
\set opal_scenario_id fixture.create
\set opal_candidate_version 2
\set opal_predecessor_version 1
\ir framework/upgrade_lifecycle.sql
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(39);
-- -----------------------------------------------------------------------------
-- Scenario: Transport preserves exact owner-produced text and metadata.
-- Setup: Save duplicate-key JSON text inside a JSONB string using the expected tuple.
-- Expected: Tuple, payload and nested text are exact; duplicate save is refused.
-- -----------------------------------------------------------------------------
SELECT lives_ok($q$SELECT pg_temp.opal_upgrade_require_identity('fixture.create','2','1')$q$,
    'owner expected tuple matches received identity');
SELECT throws_ok($q$SELECT pg_temp.opal_upgrade_require_identity('wrong.create','2','1')$q$,
    'P0001', NULL, 'wrong received scenario fails');
SELECT throws_ok($q$SELECT pg_temp.opal_upgrade_require_identity('fixture.create','3','1')$q$,
    'P0001', NULL, 'wrong received candidate fails');
SELECT throws_ok($q$SELECT pg_temp.opal_upgrade_require_identity('fixture.create','2','0')$q$,
    'P0001', NULL, 'wrong received predecessor fails');
SELECT throws_ok($q$SELECT pg_temp.opal_upgrade_load('fixture.create','2','1')$q$,
    'P0001', NULL, 'missing observation fails');
SELECT throws_ok($q$SELECT pg_temp.opal_upgrade_remove('fixture.create','2','1')$q$,
    'P0001', NULL, 'missing cleanup state fails');
CREATE SCHEMA opal_test_upgrade_observation;
SELECT throws_ok($q$SELECT pg_temp.opal_upgrade_save('fixture.create','2','1','{}'::JSONB)$q$,
    'P0001', NULL, 'pre-existing namespace collision fails');
DROP SCHEMA opal_test_upgrade_observation;
SELECT lives_ok($q$SELECT pg_temp.opal_upgrade_save('fixture.create','2','1',
    '{"rows":["{\"a\":1, \"a\":2}"],"metadata":{"scope":"fixture"}}'::JSONB)$q$,
    'save accepts exact owner-produced text payload');
SELECT is(pg_temp.opal_upgrade_load('fixture.create','2','1')->'rows'->>0,
    '{"a":1, "a":2}', 'embedded row text is not normalised');
SELECT is(pg_temp.opal_upgrade_load('fixture.create','2','1')->'metadata',
    '{"scope":"fixture"}'::JSONB, 'owner metadata survives transport');
SELECT throws_ok($q$SELECT pg_temp.opal_upgrade_save('fixture.create','2','1','{}'::JSONB)$q$,
    'P0001', NULL, 'repeat save refuses namespace collision');
SELECT throws_ok($q$SELECT pg_temp.opal_upgrade_load('wrong.create','2','1')$q$,
    'P0001', NULL, 'wrong observation owner fails');
SELECT throws_ok($q$SELECT pg_temp.opal_upgrade_remove('fixture.create','3','1')$q$,
    'P0001', NULL, 'wrong cleanup candidate fails');
SELECT ok(TO_REGNAMESPACE('opal_test_upgrade_observation') IS NOT NULL,
    'rejected cleanup preserves the namespace');
-- -----------------------------------------------------------------------------
-- Scenario: Every stored provenance field must match the current owner context.
-- Setup: Change each field individually, restoring it after the failing load.
-- Expected: Database OID/name, role and the exact scenario/version tuple are checked.
-- -----------------------------------------------------------------------------
UPDATE opal_test_upgrade_observation.observation SET scenario_id='other.create';
SELECT throws_ok($q$SELECT pg_temp.opal_upgrade_load('fixture.create','2','1')$q$,
    'P0001', NULL, 'stored scenario_id mismatch fails');
UPDATE opal_test_upgrade_observation.observation SET scenario_id='fixture.create';
UPDATE opal_test_upgrade_observation.observation SET candidate_version='3';
SELECT throws_ok($q$SELECT pg_temp.opal_upgrade_load('fixture.create','2','1')$q$,
    'P0001', NULL, 'stored candidate_version mismatch fails');
UPDATE opal_test_upgrade_observation.observation SET candidate_version='2';
UPDATE opal_test_upgrade_observation.observation SET predecessor_version='0';
SELECT throws_ok($q$SELECT pg_temp.opal_upgrade_load('fixture.create','2','1')$q$,
    'P0001', NULL, 'stored predecessor_version mismatch fails');
UPDATE opal_test_upgrade_observation.observation SET predecessor_version='1';
UPDATE opal_test_upgrade_observation.observation SET database_oid=0;
SELECT throws_ok($q$SELECT pg_temp.opal_upgrade_load('fixture.create','2','1')$q$,
    'P0001', NULL, 'stored database_oid mismatch fails');
UPDATE opal_test_upgrade_observation.observation SET database_oid=(SELECT oid FROM pg_database WHERE datname=CURRENT_DATABASE());
UPDATE opal_test_upgrade_observation.observation SET database_name='postgres';
SELECT throws_ok($q$SELECT pg_temp.opal_upgrade_load('fixture.create','2','1')$q$,
    'P0001', NULL, 'stored database_name mismatch fails');
UPDATE opal_test_upgrade_observation.observation SET database_name=CURRENT_DATABASE();
UPDATE opal_test_upgrade_observation.observation SET role_name='other_role';
SELECT throws_ok($q$SELECT pg_temp.opal_upgrade_load('fixture.create','2','1')$q$,
    'P0001', NULL, 'stored role_name mismatch fails');
UPDATE opal_test_upgrade_observation.observation SET role_name=CURRENT_USER;
-- -----------------------------------------------------------------------------
-- Scenario: Missing, multiple and structurally unexpected observations are refused.
-- Setup: Reversible changes affect only this synthetic owner's schema and record.
-- Expected: Load and cleanup fail safely, preserving unexpected owned objects.
-- -----------------------------------------------------------------------------
CREATE TEMP TABLE lifecycle_saved AS TABLE opal_test_upgrade_observation.observation;
DELETE FROM opal_test_upgrade_observation.observation;
SELECT throws_ok($q$SELECT pg_temp.opal_upgrade_load('fixture.create','2','1')$q$,
    'P0001', NULL, 'zero observation records fail');
INSERT INTO opal_test_upgrade_observation.observation TABLE lifecycle_saved;
INSERT INTO opal_test_upgrade_observation.observation TABLE lifecycle_saved;
SELECT throws_ok($q$SELECT pg_temp.opal_upgrade_load('fixture.create','2','1')$q$,
    'P0001', NULL, 'multiple observation records fail');
SELECT throws_ok($q$SELECT pg_temp.opal_upgrade_remove('fixture.create','2','1')$q$,
    'P0001', NULL, 'cleanup refuses multiple records');
DELETE FROM opal_test_upgrade_observation.observation;
INSERT INTO opal_test_upgrade_observation.observation TABLE lifecycle_saved;
CREATE TABLE opal_test_upgrade_observation.unexpected(id INTEGER);
SELECT throws_ok($q$SELECT pg_temp.opal_upgrade_load('fixture.create','2','1')$q$,
    'P0001', NULL, 'unexpected relation fails inventory');
SELECT throws_ok($q$SELECT pg_temp.opal_upgrade_remove('fixture.create','2','1')$q$,
    'P0001', NULL, 'cleanup refuses unexpected relation');
SELECT ok(TO_REGCLASS('opal_test_upgrade_observation.unexpected') IS NOT NULL,
    'strict cleanup preserves unexpected objects');
DROP TABLE opal_test_upgrade_observation.unexpected;
CREATE FUNCTION opal_test_upgrade_observation.unexpected() RETURNS INTEGER
    LANGUAGE SQL AS 'SELECT 1';
SELECT throws_ok($q$SELECT pg_temp.opal_upgrade_remove('fixture.create','2','1')$q$,
    'P0001', NULL, 'unexpected function is never dropped by cleanup');
DROP FUNCTION opal_test_upgrade_observation.unexpected();
CREATE COLLATION opal_test_upgrade_observation.unexpected (provider=libc, locale='C');
SELECT throws_ok($q$SELECT pg_temp.opal_upgrade_load('fixture.create','2','1')$q$,
    'P0001', NULL, 'unexpected collation fails inventory');
SELECT throws_ok($q$SELECT pg_temp.opal_upgrade_remove('fixture.create','2','1')$q$,
    'P0001', NULL, 'cleanup refuses unexpected collation before dropping state');
SELECT ok(TO_REGCLASS('opal_test_upgrade_observation.observation') IS NOT NULL,
    'refused collation cleanup preserves the observation relation');
DROP COLLATION opal_test_upgrade_observation.unexpected;
CREATE ROLE opal_lifecycle_wrong_owner;
ALTER SCHEMA opal_test_upgrade_observation OWNER TO opal_lifecycle_wrong_owner;
SELECT throws_ok($q$SELECT pg_temp.opal_upgrade_load('fixture.create','2','1')$q$,
    'P0001', NULL, 'wrong namespace owner fails');
SELECT throws_ok($q$SELECT pg_temp.opal_upgrade_remove('fixture.create','2','1')$q$,
    'P0001', NULL, 'cleanup refuses wrong namespace owner');
ALTER SCHEMA opal_test_upgrade_observation OWNER TO postgres;
ALTER TABLE opal_test_upgrade_observation.observation OWNER TO opal_lifecycle_wrong_owner;
SELECT throws_ok($q$SELECT pg_temp.opal_upgrade_load('fixture.create','2','1')$q$,
    'P0001', NULL, 'wrong relation owner fails');
ALTER TABLE opal_test_upgrade_observation.observation OWNER TO postgres;
SELECT nspname AS lifecycle_temp_schema FROM pg_namespace WHERE oid=PG_MY_TEMP_SCHEMA()
\gset
GRANT USAGE ON SCHEMA :"lifecycle_temp_schema" TO opal_lifecycle_wrong_owner;
SELECT throws_ok($q$SET LOCAL ROLE opal_lifecycle_wrong_owner;
    SELECT pg_temp.opal_upgrade_load('fixture.create','2','1')$q$,
    'P0001', NULL, 'wrong live database role fails target guard');
REVOKE USAGE ON SCHEMA :"lifecycle_temp_schema" FROM opal_lifecycle_wrong_owner;
DROP ROLE opal_lifecycle_wrong_owner;
-- -----------------------------------------------------------------------------
-- Scenario: Row preservation uses exact text before any functional fixture work.
-- Setup: A changed textual observation contains a distinct duplicate-key value.
-- Expected: Equality is false and the owner observes preservation failure.
-- -----------------------------------------------------------------------------
SELECT isnt(pg_temp.opal_upgrade_load('fixture.create','2','1')->'rows'->>0,
    '{"a":1, "a":3}', 'changed embedded row text is detected before fixtures');
SELECT lives_ok($q$SELECT pg_temp.opal_upgrade_remove('fixture.create','2','1')$q$,
    'strict cleanup removes its exact owned observation');
SELECT ok(TO_REGNAMESPACE('opal_test_upgrade_observation') IS NULL,
    'local cleanup removes the namespace');
SELECT ok(pg_temp.opal_upgrade_absent_from_new_backend(),
    'anonymous independent backend confirms observation absence');
SELECT ok(public.dblink_get_connections() IS NULL,
    'cleanup readback leaves no named dblink connections');
SELECT * FROM finish();
ROLLBACK;
