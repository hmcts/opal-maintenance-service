/**
 * OPAL Program
 *
 * MODULE      : upgrade_lifecycle.sql
 *
 * DESCRIPTION : Disposable-only shared observation transport and ownership guards.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket        Nature of Change
 * ----------  -------------  ------------  ----------------------------------------
 * 14/10/2026  Frankie Moran  PO-10643      Initial shared SQL observation lifecycle.
 */
\set ON_ERROR_STOP 1
\if :{?opal_phase}
\else
    \set opal_phase fresh
\endif
SELECT :'opal_phase' IN ('fresh','prepare','verify','cleanup') AS valid_phase,
       :'opal_phase' = 'prepare' AS is_prepare,
       :'opal_phase' = 'verify' AS is_verify,
       :'opal_phase' = 'cleanup' AS is_cleanup,
       :'opal_phase' <> 'fresh' AS needs_identity
\gset
DO $guard$
BEGIN
    IF CURRENT_DATABASE() <> 'opal_maintenance_db_unit_test' OR CURRENT_USER <> 'postgres' THEN
        RAISE EXCEPTION 'Upgrade lifecycle requires its disposable harness database and role';
    END IF;
END;
$guard$;
\if :valid_phase
\else
    DO $invalid$ BEGIN RAISE EXCEPTION 'Unknown upgrade lifecycle phase'; END; $invalid$;
\endif
\if :needs_identity
    \if :{?opal_scenario_id}
    \else
        DO $missing$ BEGIN RAISE EXCEPTION 'Upgrade lifecycle requires scenario identity'; END; $missing$;
    \endif
    \if :{?opal_candidate_version}
    \else
        DO $missing$ BEGIN RAISE EXCEPTION 'Upgrade lifecycle requires candidate identity'; END; $missing$;
    \endif
    \if :{?opal_predecessor_version}
    \else
        DO $missing$ BEGIN RAISE EXCEPTION 'Upgrade lifecycle requires predecessor identity'; END; $missing$;
    \endif
\endif
-- Fresh suites need no upgrade tuple. Clear settings when no tuple was supplied.
\if :{?opal_scenario_id}
    SELECT SET_CONFIG('opal.upgrade_scenario', :'opal_scenario_id', false) AS upgrade_scenario_setting \gset
\else
    SELECT SET_CONFIG('opal.upgrade_scenario', '', false) AS upgrade_scenario_setting \gset
\endif
\if :{?opal_candidate_version}
    SELECT SET_CONFIG('opal.upgrade_candidate', :'opal_candidate_version', false) AS upgrade_candidate_setting \gset
\else
    SELECT SET_CONFIG('opal.upgrade_candidate', '', false) AS upgrade_candidate_setting \gset
\endif
\if :{?opal_predecessor_version}
    SELECT SET_CONFIG('opal.upgrade_predecessor', :'opal_predecessor_version', false) AS upgrade_predecessor_setting \gset
\else
    SELECT SET_CONFIG('opal.upgrade_predecessor', '', false) AS upgrade_predecessor_setting \gset
\endif

CREATE OR REPLACE FUNCTION pg_temp.opal_upgrade_require_identity(
    expected_scenario TEXT, expected_candidate TEXT, expected_predecessor TEXT
) RETURNS VOID
LANGUAGE plpgsql SECURITY INVOKER SET search_path = pg_catalog, pg_temp AS $identity$
BEGIN
    IF CURRENT_DATABASE() <> 'opal_maintenance_db_unit_test' OR CURRENT_USER <> 'postgres' THEN
        RAISE EXCEPTION 'Upgrade lifecycle requires its disposable harness database and role';
    END IF;
    IF expected_scenario IS NULL OR expected_scenario = ''
       OR expected_candidate IS NULL OR expected_candidate = ''
       OR expected_predecessor IS NULL OR expected_predecessor = ''
       OR CURRENT_SETTING('opal.upgrade_scenario', true) IS DISTINCT FROM expected_scenario
       OR CURRENT_SETTING('opal.upgrade_candidate', true) IS DISTINCT FROM expected_candidate
       OR CURRENT_SETTING('opal.upgrade_predecessor', true) IS DISTINCT FROM expected_predecessor THEN
        RAISE EXCEPTION 'Upgrade lifecycle identity mismatch';
    END IF;
END;
$identity$;

CREATE OR REPLACE FUNCTION pg_temp.opal_upgrade_save(
    expected_scenario TEXT, expected_candidate TEXT, expected_predecessor TEXT, observation JSONB
) RETURNS VOID
LANGUAGE plpgsql SECURITY INVOKER SET search_path = pg_catalog, pg_temp AS $save$
BEGIN
    PERFORM pg_temp.opal_upgrade_require_identity(expected_scenario, expected_candidate, expected_predecessor);
    IF TO_REGNAMESPACE('opal_test_upgrade_observation') IS NOT NULL THEN
        RAISE EXCEPTION 'Upgrade observation namespace collision';
    END IF;
    IF observation IS NULL THEN
        RAISE EXCEPTION 'Upgrade observation payload must be present';
    END IF;
    CREATE SCHEMA opal_test_upgrade_observation;
    CREATE TABLE opal_test_upgrade_observation.observation (
        scenario_id         TEXT  NOT NULL,
        candidate_version   TEXT  NOT NULL,
        predecessor_version TEXT  NOT NULL,
        database_oid        OID   NOT NULL,
        database_name       TEXT  NOT NULL,
        role_name           TEXT  NOT NULL,
        payload             JSONB NOT NULL
    );
    INSERT INTO opal_test_upgrade_observation.observation
    SELECT expected_scenario, expected_candidate, expected_predecessor,
           oid, CURRENT_DATABASE(), CURRENT_USER, observation
    FROM pg_database WHERE datname = CURRENT_DATABASE();
    PERFORM pg_temp.opal_upgrade_load(expected_scenario, expected_candidate, expected_predecessor);
END;
$save$;

CREATE OR REPLACE FUNCTION pg_temp.opal_upgrade_load(
    expected_scenario TEXT, expected_candidate TEXT, expected_predecessor TEXT
) RETURNS JSONB
LANGUAGE plpgsql SECURITY INVOKER SET search_path = pg_catalog, pg_temp AS $load$
DECLARE
    namespace_oid OID;
    owner_oid OID;
    result JSONB;
BEGIN
    PERFORM pg_temp.opal_upgrade_require_identity(expected_scenario, expected_candidate, expected_predecessor);
    SELECT oid INTO owner_oid FROM pg_roles WHERE rolname = CURRENT_USER;
    SELECT oid INTO namespace_oid FROM pg_namespace
    WHERE nspname = 'opal_test_upgrade_observation' AND nspowner = owner_oid;
    IF namespace_oid IS NULL THEN
        RAISE EXCEPTION 'Upgrade observation namespace missing or owner mismatch';
    END IF;
    IF (SELECT COUNT(*) FROM pg_class WHERE relnamespace = namespace_oid) <> 1
       OR NOT EXISTS (SELECT 1 FROM pg_class WHERE relnamespace = namespace_oid
                      AND relname = 'observation' AND relkind = 'r'
                      AND relpersistence = 'p' AND relowner = owner_oid)
       OR EXISTS (
           SELECT 1 FROM pg_depend dependency
           WHERE dependency.refclassid = 'pg_namespace'::regclass
             AND dependency.refobjid = namespace_oid
             AND NOT (
                 (dependency.classid = 'pg_class'::regclass
                  AND dependency.objid = 'opal_test_upgrade_observation.observation'::regclass)
                 OR (dependency.classid = 'pg_type'::regclass
                     AND dependency.objid IN (
                         SELECT reltype FROM pg_class
                         WHERE oid = 'opal_test_upgrade_observation.observation'::regclass
                         UNION ALL
                         SELECT typarray FROM pg_type
                         WHERE typrelid = 'opal_test_upgrade_observation.observation'::regclass
                     ))
             )
       ) THEN
        RAISE EXCEPTION 'Upgrade observation namespace has unexpected objects';
    END IF;
    IF (SELECT COUNT(*) FROM opal_test_upgrade_observation.observation) <> 1 THEN
        RAISE EXCEPTION 'Upgrade observation requires exactly one record';
    END IF;
    SELECT payload INTO result FROM opal_test_upgrade_observation.observation
    WHERE scenario_id = expected_scenario AND candidate_version = expected_candidate
      AND predecessor_version = expected_predecessor
      AND database_oid = (SELECT oid FROM pg_database WHERE datname = CURRENT_DATABASE())
      AND database_name = CURRENT_DATABASE() AND role_name = CURRENT_USER;
    IF result IS NULL THEN
        RAISE EXCEPTION 'Upgrade observation provenance mismatch';
    END IF;
    RETURN result;
END;
$load$;

CREATE OR REPLACE FUNCTION pg_temp.opal_upgrade_remove(
    expected_scenario TEXT, expected_candidate TEXT, expected_predecessor TEXT
) RETURNS VOID
LANGUAGE plpgsql SECURITY INVOKER SET search_path = pg_catalog, pg_temp AS $remove$
BEGIN
    PERFORM pg_temp.opal_upgrade_load(expected_scenario, expected_candidate, expected_predecessor);
    DROP TABLE opal_test_upgrade_observation.observation;
    DROP SCHEMA opal_test_upgrade_observation;
END;
$remove$;

CREATE OR REPLACE FUNCTION pg_temp.opal_upgrade_absent_from_new_backend() RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY INVOKER SET search_path = pg_catalog, pg_temp AS $absence$
DECLARE
    result BOOLEAN;
BEGIN
    IF CURRENT_DATABASE() <> 'opal_maintenance_db_unit_test' OR CURRENT_USER <> 'postgres' THEN
        RAISE EXCEPTION 'Upgrade lifecycle requires its disposable harness database and role';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'dblink') THEN
        RAISE EXCEPTION 'Upgrade cleanup readback unavailable: test-only dblink extension files missing';
    END IF;
    CREATE EXTENSION IF NOT EXISTS dblink WITH SCHEMA public;
    IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'dblink'
                   AND extnamespace = 'public'::regnamespace) THEN
        RAISE EXCEPTION 'Upgrade cleanup readback requires test dblink in public';
    END IF;
    -- A connection string overload opens an anonymous connection and closes it
    -- automatically. Neither executable SQL nor a connection target is metadata.
    SELECT backend_pid <> PG_BACKEND_PID() AND absent INTO result
    FROM public.dblink('dbname=opal_maintenance_db_unit_test user=postgres',
        'SELECT pg_backend_pid(), NOT EXISTS (SELECT 1 FROM pg_catalog.pg_namespace WHERE nspname = ''opal_test_upgrade_observation'')')
        AS readback(backend_pid INTEGER, absent BOOLEAN);
    RETURN result;
END;
$absence$;
