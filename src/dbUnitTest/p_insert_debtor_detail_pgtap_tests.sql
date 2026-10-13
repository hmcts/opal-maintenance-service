/**
 * OPAL Program
 *
 * MODULE      : p_insert_debtor_detail_pgtap_tests.sql
 *
 * DESCRIPTION : Verify debtor mapping, nulls, integrity, rollback and upgrade preservation.
 *
 * CHANGE HISTORY:
 *
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * 13/10/2026  Frankie Moran  PO-10644  Initial pgTAP test suite.
 */
-- OPAL-DB-UPGRADE {"id":"p_insert_debtor_detail.create","candidate":"ddl/V1_34__create_p_insert_debtor_detail_procedure.sql","scope":"both","data":"migration-created-only"}
-- DB-04/DB-06: catalogue, mapping, native errors, row scope, repeat and caller rollback.
-- All functional assertions apply to DB-01 fresh and DB-03 candidate verification.
\set ON_ERROR_STOP on
\if :{?opal_phase}
\else
    \set opal_phase fresh
\endif
SELECT :'opal_phase' IN ('fresh','prepare','verify','cleanup') AS valid_phase,
       :'opal_phase'='prepare' AS is_prepare,
       :'opal_phase'='verify' AS is_verify,
       :'opal_phase'='cleanup' AS is_cleanup,
       :'opal_phase'<>'fresh' AS needs_identity
\gset
\if :valid_phase
\else
    DO $guard$ BEGIN RAISE EXCEPTION 'Unknown debtor suite phase'; END; $guard$;
\endif
\if :needs_identity
    \if :{?opal_scenario_id}
    \else
        DO $guard$ BEGIN RAISE EXCEPTION 'Missing debtor scenario'; END; $guard$;
    \endif
    \if :{?opal_candidate_version}
    \else
        DO $guard$ BEGIN RAISE EXCEPTION 'Missing debtor candidate'; END; $guard$;
    \endif
    \if :{?opal_predecessor_version}
    \else
        DO $guard$ BEGIN RAISE EXCEPTION 'Missing debtor predecessor'; END; $guard$;
    \endif
    SELECT SET_CONFIG('opal.dd_scenario',:'opal_scenario_id',false) AS scenario,
           SET_CONFIG('opal.dd_candidate',:'opal_candidate_version',false) AS candidate,
           SET_CONFIG('opal.dd_predecessor',:'opal_predecessor_version',false) AS predecessor
    \gset
    DO $guard$
    BEGIN
        IF CURRENT_SETTING('opal.dd_scenario')<>'p_insert_debtor_detail.create'
           OR CURRENT_SETTING('opal.dd_candidate')=''
           OR CURRENT_SETTING('opal.dd_predecessor')='' THEN
            RAISE EXCEPTION 'Invalid debtor upgrade identity';
        END IF;
    END;
    $guard$;
\endif
DO $target$
BEGIN
    IF CURRENT_DATABASE()<>'opal_maintenance_db_unit_test' OR current_user<>'postgres' THEN
        RAISE EXCEPTION 'Debtor tests require the disposable framework target';
    END IF;
END;
$target$;
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SET LOCAL search_path = public, pg_catalog;
SET LOCAL TIME ZONE 'UTC';
SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '5s';

CREATE FUNCTION pg_temp.dd_installation_state() RETURNS JSONB LANGUAGE plpgsql AS $state$
DECLARE
    v_table TEXT;
    v_rows JSONB := '{}'::JSONB;
    v_values JSONB;
    v_columns JSONB;
    v_constraints JSONB;
    v_indexes JSONB;
    v_sequences JSONB;
    v_ownership JSONB;

BEGIN
    FOREACH v_table IN ARRAY ARRAY[
        'debtor_detail','countries','draft_casefiles','respondent_accounts'] LOOP
        IF TO_REGCLASS(FORMAT('public.%I',v_table)) IS NULL THEN
            RAISE EXCEPTION 'Missing named debtor dependency: %',v_table;
        END IF;
        EXECUTE FORMAT(
            'SELECT COALESCE(JSONB_AGG(value ORDER BY value),''[]''::JSONB)
             FROM (SELECT ROW_TO_JSON(t)::TEXT AS value FROM public.%I t) r',v_table)
        INTO v_values;
        v_rows := v_rows || JSONB_BUILD_OBJECT(v_table,v_values);
    END LOOP;
    SELECT JSONB_AGG(TO_JSONB(c) ORDER BY c.table_name,c.position) INTO v_columns
    FROM (
        SELECT a.attrelid::REGCLASS::TEXT AS table_name,a.attnum AS position,a.attname,
               FORMAT_TYPE(a.atttypid,a.atttypmod) AS type,a.attnotnull,a.attidentity,a.attgenerated,
               PG_GET_EXPR(d.adbin,d.adrelid) AS default_expression,
               COL_DESCRIPTION(a.attrelid,a.attnum) AS comment
        FROM pg_attribute a LEFT JOIN pg_attrdef d
          ON d.adrelid=a.attrelid AND d.adnum=a.attnum
        WHERE a.attrelid IN ('public.debtor_detail'::REGCLASS,'public.countries'::REGCLASS)
          AND a.attnum>0 AND NOT a.attisdropped
    ) c;
    SELECT JSONB_AGG(TO_JSONB(c) ORDER BY c.table_name,c.conname) INTO v_constraints
    FROM (
        SELECT conrelid::REGCLASS::TEXT AS table_name,conname,contype,convalidated,
               condeferrable,condeferred,PG_GET_CONSTRAINTDEF(oid,false) AS definition
        FROM pg_constraint WHERE conrelid IN
            ('public.debtor_detail'::REGCLASS,'public.countries'::REGCLASS)
    ) c;
    SELECT JSONB_AGG(TO_JSONB(i) ORDER BY i.table_name,i.index_name) INTO v_indexes
    FROM (
        SELECT indrelid::REGCLASS::TEXT AS table_name,indexrelid::REGCLASS::TEXT AS index_name,
               indisvalid,indisready,PG_GET_INDEXDEF(indexrelid) AS definition
        FROM pg_index WHERE indrelid IN
            ('public.debtor_detail'::REGCLASS,'public.countries'::REGCLASS)
    ) i;
    SELECT JSONB_AGG(TO_JSONB(s) ORDER BY s.seqrelid) INTO v_sequences FROM pg_sequence s
    WHERE seqrelid IN ('public.debtor_detail_id_seq'::REGCLASS,'public.country_id_seq'::REGCLASS);
    SELECT JSONB_AGG(TO_JSONB(d) ORDER BY d.objid,d.refobjid,d.refobjsubid,d.deptype)
    INTO v_ownership FROM pg_depend d
    WHERE d.classid='pg_class'::REGCLASS AND d.refclassid='pg_class'::REGCLASS
      AND d.objid IN ('public.debtor_detail_id_seq'::REGCLASS,'public.country_id_seq'::REGCLASS);
    RETURN JSONB_BUILD_OBJECT('rows',v_rows,'columns',v_columns,'constraints',v_constraints,
        'indexes',v_indexes,'sequences',v_sequences,'ownership',v_ownership,
        'debtor_sequence',(SELECT JSONB_BUILD_ARRAY(last_value,is_called) FROM public.debtor_detail_id_seq),
        'country_sequence',(SELECT JSONB_BUILD_ARRAY(last_value,is_called) FROM public.country_id_seq));
END;
$state$;

\if :is_prepare
    SELECT plan(7);
    -- -------------------------------------------------------------------------
    -- Scenario: Observe the real predecessor before routine-only installation.
    -- Setup: Native selected P migrations only; no extra business fixtures.
    -- Expected: Candidate absent, dependencies/seeds present, durable owned state.
    -- -------------------------------------------------------------------------
    SELECT ok(TO_REGPROCEDURE('public.p_insert_debtor_detail(json,character varying)') IS NULL,
        'debtor procedure absent at predecessor');
    SELECT ok(TO_REGCLASS('public.debtor_detail') IS NOT NULL
        AND TO_REGCLASS('public.countries') IS NOT NULL,'debtor tables exist');
    SELECT ok(TO_REGCLASS('public.debtor_detail_id_seq') IS NOT NULL
        AND TO_REGCLASS('public.country_id_seq') IS NOT NULL,'existing owned sequences exist');
    SELECT ok(EXISTS(SELECT 1 FROM pg_constraint
        WHERE conrelid='public.debtor_detail'::REGCLASS AND conname='dd_employer_country_id_fk'),
        'existing employer Country foreign key exists');
    SELECT ok(EXISTS(SELECT 1 FROM public.countries WHERE cjs_code=1 AND international_code='GBR'),
        'real migration-created Country reference is nonempty');
    DO $guard$
    BEGIN
        IF TO_REGNAMESPACE('opal_test_dd_upgrade') IS NOT NULL THEN
            RAISE EXCEPTION 'Debtor observation namespace collision';
        END IF;
    END;
    $guard$;
    CREATE SCHEMA opal_test_dd_upgrade;
    CREATE TABLE opal_test_dd_upgrade.observation (
        scenario TEXT PRIMARY KEY,candidate TEXT NOT NULL,predecessor TEXT NOT NULL,state JSONB NOT NULL
    );
    INSERT INTO opal_test_dd_upgrade.observation VALUES (
        CURRENT_SETTING('opal.dd_scenario'),CURRENT_SETTING('opal.dd_candidate'),
        CURRENT_SETTING('opal.dd_predecessor'),pg_temp.dd_installation_state());
    SELECT is((SELECT COUNT(*) FROM opal_test_dd_upgrade.observation),1::BIGINT,
        'one durable debtor predecessor observation');
    SELECT is((SELECT COUNT(*) FROM JSONB_OBJECT_KEYS(
        (SELECT state->'rows' FROM opal_test_dd_upgrade.observation))),4::BIGINT,
        'exact four-table observation scope');
    SELECT * FROM finish();
    COMMIT;
\elif :is_cleanup
    SELECT plan(2);
    -- -------------------------------------------------------------------------
    -- Scenario: Remove committed debtor observations and verify persisted absence.
    -- Setup: Exact scenario/P/C guard, owned drop, independent backend readback.
    -- Expected: No unrelated object removed; consumer observation is truly absent.
    -- -------------------------------------------------------------------------
    DO $guard$
    BEGIN
        IF TO_REGCLASS('opal_test_dd_upgrade.observation') IS NULL THEN
            RAISE EXCEPTION 'Debtor cleanup lacks owned observation';
        END IF;
        IF (SELECT COUNT(*) FROM opal_test_dd_upgrade.observation)<>1
           OR NOT EXISTS(SELECT 1 FROM opal_test_dd_upgrade.observation
              WHERE scenario=CURRENT_SETTING('opal.dd_scenario')
                AND candidate=CURRENT_SETTING('opal.dd_candidate')
                AND predecessor=CURRENT_SETTING('opal.dd_predecessor')) THEN
            RAISE EXCEPTION 'Debtor cleanup ownership mismatch';
        END IF;
    END;
    $guard$;
    SELECT is((SELECT COUNT(*) FROM opal_test_dd_upgrade.observation),1::BIGINT,
        'cleanup confirmed exact owned debtor observation');
    DROP TABLE opal_test_dd_upgrade.observation;
    DROP SCHEMA opal_test_dd_upgrade;
    COMMIT;
    BEGIN;
    SET LOCAL search_path = public, pg_catalog;
    SET LOCAL statement_timeout = '30s';
    CREATE EXTENSION IF NOT EXISTS dblink WITH SCHEMA public;
    SELECT ok(observed.backend_pid<>PG_BACKEND_PID()
        AND observed.namespace_absent AND observed.relation_absent,
        'separate backend confirms committed debtor observation removal')
    FROM public.DBLINK(
        FORMAT('host=127.0.0.1 port=5432 dbname=%L user=postgres connect_timeout=5 options=%L',
            CURRENT_DATABASE(),'-csearch_path=pg_catalog -cstatement_timeout=20000'),
        'SELECT PG_BACKEND_PID(), TO_REGNAMESPACE(''opal_test_dd_upgrade'') IS NULL,
            TO_REGCLASS(''opal_test_dd_upgrade.observation'') IS NULL'
    ) AS observed(backend_pid INTEGER,namespace_absent BOOLEAN,relation_absent BOOLEAN);
    SELECT * FROM finish();
    ROLLBACK;
\else
    \if :is_verify
        SELECT plan(145);
        -- ---------------------------------------------------------------------
        -- Scenario: Installation preserves predecessor rows, objects and sequences.
        -- Setup: Compare durable P state before any fixture, CALL or NEXTVAL.
        -- Expected: Complete null-safe preservation; TAP receives only booleans.
        -- ---------------------------------------------------------------------
        DO $guard$
        BEGIN
            IF TO_REGCLASS('opal_test_dd_upgrade.observation') IS NULL THEN
                RAISE EXCEPTION 'Durable debtor observation unavailable';
            END IF;
        END;
        $guard$;
        SELECT is((SELECT COUNT(*) FROM opal_test_dd_upgrade.observation),1::BIGINT,
            'debtor observation survives a new connection');
        SELECT ok(EXISTS(SELECT 1 FROM opal_test_dd_upgrade.observation
            WHERE scenario=CURRENT_SETTING('opal.dd_scenario')
              AND candidate=CURRENT_SETTING('opal.dd_candidate')
              AND predecessor=CURRENT_SETTING('opal.dd_predecessor')),
            'debtor observation matches actual scenario and P/C');
        SELECT ok((SELECT state->'rows' FROM opal_test_dd_upgrade.observation)
            IS NOT DISTINCT FROM (pg_temp.dd_installation_state()->'rows'),
            'all four debtor predecessor row sets preserved');
        SELECT ok((SELECT state-'rows' FROM opal_test_dd_upgrade.observation)
            IS NOT DISTINCT FROM (pg_temp.dd_installation_state()-'rows'),
            'debtor table and sequence definitions and state preserved');
        SELECT ok(TO_REGPROCEDURE('public.p_insert_debtor_detail(json,character varying)') IS NOT NULL,
            'debtor procedure installed before functional mutation');
    \else
        SELECT plan(140);
    \endif

-- -----------------------------------------------------------------------------
-- Scenario: Synthetic fixtures isolate mapping, duplicate resolution and row scope.
-- Setup: Guard all reserved IDs/codes; omitted international codes avoid unique clashes.
-- Expected: Fixture Country code differs from its BIGINT ID; unrelated rows persist.
-- -----------------------------------------------------------------------------
DO $fixtures$
BEGIN
    IF EXISTS(SELECT 1 FROM public.countries WHERE country_id IN (-31971,-31972,-31973,-31974,-31979)
              OR cjs_code IN (31971,31972,31973,31976))
       OR EXISTS(SELECT 1 FROM public.debtor_detail WHERE debtor_detail_id=-31978)
       OR EXISTS(SELECT 1 FROM public.business_units
                 WHERE business_unit_id=31977 OR business_unit_code='DD77')
       OR EXISTS(SELECT 1 FROM public.draft_casefiles WHERE draft_casefile_id=-31977) THEN
        RAISE EXCEPTION 'Synthetic debtor fixture collision';
    END IF;
END;
$fixtures$;
INSERT INTO public.countries(country_id,cjs_code,country_name,date_used_from,active) VALUES
    (-31971,31971,'Synthetic debtor active',DATE '2026-01-01',true),
    (-31972,31972,'Synthetic debtor inactive',DATE '2026-01-01',false),
    (-31973,31973,'Synthetic debtor duplicate A',DATE '2026-01-01',true),
    (-31974,31973,'Synthetic debtor duplicate B',DATE '2026-01-01',true);
INSERT INTO public.debtor_detail(debtor_detail_id,other_personal_information)
VALUES (-31978,'Synthetic pre-call detail');
INSERT INTO public.business_units(business_unit_id,business_unit_type,business_unit_code,business_unit_name,welsh_language)
VALUES (31977,'Area','DD77','Synthetic debtor area',false);
INSERT INTO public.draft_casefiles(draft_casefile_id,business_unit_id,created_date,submitted_by,
    submitted_by_name,casefile,casefile_snapshot,casefile_type,casefile_status,casefile_status_date,timeline_data)
VALUES (-31977,31977,TIMESTAMP '2026-01-01 00:00:00','synthetic','Synthetic fixture',
    '{ "synthetic": "input" }','{ "synthetic": "snapshot" }','REMO In','SUBMITTED',
    TIMESTAMP '2026-01-01 00:00:00','[ { "synthetic": "timeline" } ]');

CREATE FUNCTION pg_temp.dd_rows() RETURNS JSONB LANGUAGE sql AS $rows$
    SELECT COALESCE(JSONB_AGG(value ORDER BY value),'[]'::JSONB)
    FROM (SELECT ROW_TO_JSON(t)::TEXT AS value FROM public.debtor_detail t) r;
$rows$;
CREATE FUNCTION pg_temp.dd_call(p_payload JSON,p_info VARCHAR) RETURNS BIGINT LANGUAGE plpgsql AS $call$
DECLARE v_id BIGINT;

BEGIN
    CALL public.p_insert_debtor_detail(p_payload,p_info,v_id);
    RETURN v_id;
END;
$call$;
CREATE FUNCTION pg_temp.dd_probe(p_payload JSON,p_info VARCHAR) RETURNS JSONB LANGUAGE plpgsql AS $probe$
DECLARE v_id BIGINT; v_constraint TEXT;

BEGIN
    v_id := pg_temp.dd_call(p_payload,p_info);
    RETURN JSONB_BUILD_OBJECT('id',v_id,'state',NULL,'constraint',NULL);

EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_constraint = CONSTRAINT_NAME;

    RETURN JSONB_BUILD_OBJECT('id',NULL,'state',SQLSTATE,'constraint',v_constraint);
END;
$probe$;
CREATE TEMP TABLE dd_scope_before AS SELECT pg_temp.dd_installation_state()->'rows' AS rows;

-- -----------------------------------------------------------------------------
-- Scenario: Catalogue identity includes the actual OUT mode and effective types.
-- Setup: Resolve by two IN types; OUT participates in proallargtypes/proargmodes.
-- Expected: Procedure, exact names/modes/types, no defaults and ordinary invoker.
-- -----------------------------------------------------------------------------
SELECT ok(COALESCE((SELECT prokind='p' FROM pg_proc WHERE oid=
    TO_REGPROCEDURE('public.p_insert_debtor_detail(json,character varying)')),false),
    'debtor catalogue identifies the procedure');
SELECT ok(COALESCE((SELECT proargnames=ARRAY['pi_debtor_detail_json',
    'pi_other_personal_information','po_debtor_detail_id']::TEXT[] FROM pg_proc WHERE oid=
    TO_REGPROCEDURE('public.p_insert_debtor_detail(json,character varying)')),false),
    'debtor parameter names and order are exact');
SELECT ok(COALESCE((SELECT proargmodes=ARRAY['i','i','o']::"char"[] AND
    proallargtypes=ARRAY['json'::REGTYPE::OID,'character varying'::REGTYPE::OID,'bigint'::REGTYPE::OID]
    FROM pg_proc WHERE oid=TO_REGPROCEDURE('public.p_insert_debtor_detail(json,character varying)')),false),
    'debtor modes and effective JSON VARCHAR BIGINT types are exact');
SELECT ok(COALESCE((SELECT NOT prosecdef AND pronargdefaults=0 FROM pg_proc WHERE oid=
    TO_REGPROCEDURE('public.p_insert_debtor_detail(json,character varying)')),false),
    'debtor procedure uses invoker rights and no defaults');

CREATE TEMP TABLE dd_success_cases(label TEXT PRIMARY KEY,payload JSON,info VARCHAR,expected JSONB NOT NULL);
INSERT INTO dd_success_cases VALUES
('complete mapping',
 '{"employer_name":"Synthetic employer","employee_reference":"REF-SYN","employer_email_address":"synthetic@example.invalid","employer_telephone_number":"SYN-TEL","employer_address":{"address_line_1":"Line one","address_line_2":"Line two","address_line_3":"Line three","address_line_4":"Line four","address_line_5":"Line five","postcode":"SYN1","cjs_code":31971}}',
 'Separate synthetic information',
 '{"employer_name":"Synthetic employer","employee_reference":"REF-SYN","employer_email":"synthetic@example.invalid","employer_telephone":"SYN-TEL","employer_address_line_1":"Line one","employer_address_line_2":"Line two","employer_address_line_3":"Line three","employer_address_line_4":"Line four","employer_address_line_5":"Line five","employer_postcode":"SYN1","employer_country_id":-31971,"other_personal_information":"Separate synthetic information"}'),
('SQL null with information',NULL,'Synthetic information','{"other_personal_information":"Synthetic information"}'),
('JSON null with information','null','Synthetic information','{"other_personal_information":"Synthetic information"}'),
('empty object with information','{}','Synthetic information','{"other_personal_information":"Synthetic information"}'),
('SQL null without information',NULL,NULL,'{}'),
('JSON null without information','null',NULL,'{}'),
('empty object without information','{}',NULL,'{}'),
('explicit canonical nulls','{"employer_name":null,"employee_reference":null,"employer_email_address":null,"employer_telephone_number":null,"employer_address":{"address_line_1":null,"address_line_2":null,"address_line_3":null,"address_line_4":null,"address_line_5":null,"postcode":null,"cjs_code":null}}',NULL,'{}'),
('name only address absent','{"employer_name":"Synthetic name"}',NULL,'{"employer_name":"Synthetic name"}'),
('reference only name absent','{"employee_reference":"Synthetic reference"}',NULL,'{"employee_reference":"Synthetic reference"}'),
('line two only','{"employer_address":{"address_line_2":"Synthetic line two"}}',NULL,'{"employer_address_line_2":"Synthetic line two"}'),
('JSON null address','{"employer_name":"Synthetic name","employer_address":null}',NULL,'{"employer_name":"Synthetic name"}'),
('empty address','{"employer_name":"Synthetic name","employer_address":{}}',NULL,'{"employer_name":"Synthetic name"}'),
('Country key absent','{"employer_address":{"address_line_1":"Synthetic line"}}',NULL,'{"employer_address_line_1":"Synthetic line"}'),
('Country JSON null','{"employer_address":{"address_line_1":"Synthetic line","cjs_code":null}}',NULL,'{"employer_address_line_1":"Synthetic line"}'),
('scalar information overrides JSON field','{"other_personal_information":"Ignored synthetic JSON"}','Synthetic scalar','{"other_personal_information":"Synthetic scalar"}'),
('null scalar ignores JSON field','{"other_personal_information":"Ignored synthetic JSON"}',NULL,'{}'),
('strings preserve whitespace','{"employer_name":"  Synthetic name  ","employee_reference":"  REF  ","employer_email_address":"  synthetic@example.invalid  ","employer_telephone_number":"  TEL  ","employer_address":{"address_line_1":"  Line  ","postcode":"  SYN  "}}','  Info  ',
 '{"employer_name":"  Synthetic name  ","employee_reference":"  REF  ","employer_email":"  synthetic@example.invalid  ","employer_telephone":"  TEL  ","employer_address_line_1":"  Line  ","employer_postcode":"  SYN  ","other_personal_information":"  Info  "}'),
('unique inactive Country','{"employer_address":{"cjs_code":31972}}',NULL,'{"employer_country_id":-31972}');
INSERT INTO dd_success_cases VALUES ('exact storage widths',
    JSONB_BUILD_OBJECT('employer_name',REPEAT('N',50),'employee_reference',REPEAT('R',35),
        'employer_email_address',REPEAT('E',80),'employer_telephone_number',REPEAT('T',35),
        'employer_address',JSONB_BUILD_OBJECT('address_line_1',REPEAT('A',35),'address_line_2',REPEAT('B',35),
            'address_line_3',REPEAT('C',35),'address_line_4',REPEAT('D',35),'address_line_5',REPEAT('F',35),
            'postcode',REPEAT('P',10),'cjs_code',31971))::JSON,REPEAT('I',200),
    JSONB_BUILD_OBJECT('employer_name',REPEAT('N',50),'employee_reference',REPEAT('R',35),
        'employer_email',REPEAT('E',80),'employer_telephone',REPEAT('T',35),
        'employer_address_line_1',REPEAT('A',35),'employer_address_line_2',REPEAT('B',35),
        'employer_address_line_3',REPEAT('C',35),'employer_address_line_4',REPEAT('D',35),
        'employer_address_line_5',REPEAT('F',35),'employer_postcode',REPEAT('P',10),
        'employer_country_id',-31971,'other_personal_information',REPEAT('I',200)));
DO $guard$
BEGIN
    IF (SELECT COUNT(*) FROM dd_success_cases)<>20 THEN
        RAISE EXCEPTION 'Debtor successful case inventory must contain twenty cases';
    END IF;
END;
$guard$;
CREATE FUNCTION pg_temp.dd_success(p_payload JSON,p_info VARCHAR,p_expected JSONB,p_label TEXT)
RETURNS SETOF TEXT LANGUAGE plpgsql AS $test$
DECLARE
    v_before BIGINT;
    v_id BIGINT;
    v_expected JSONB := '{"employer_name":null,"employer_address_line_1":null,"employer_address_line_2":null,"employer_address_line_3":null,"employer_address_line_4":null,"employer_address_line_5":null,"employer_postcode":null,"employer_country_id":null,"employee_reference":null,"employer_telephone":null,"employer_email":null,"other_personal_information":null}'::JSONB || p_expected;

BEGIN
    SELECT COUNT(*) INTO v_before FROM public.debtor_detail;
    v_id := pg_temp.dd_call(p_payload,p_info);
    RETURN NEXT is((SELECT COUNT(*) FROM public.debtor_detail WHERE debtor_detail_id=v_id),
        1::BIGINT,p_label||': returned ID identifies exactly one row');
    RETURN NEXT is((SELECT COUNT(*) FROM public.debtor_detail),v_before+1,
        p_label||': exactly one-row delta');
    RETURN NEXT ok((SELECT TO_JSONB(d)-'debtor_detail_id' FROM public.debtor_detail d
        WHERE debtor_detail_id=v_id) IS NOT DISTINCT FROM v_expected,
        p_label||': complete independent mapping preserved');
END;
$test$;
-- -----------------------------------------------------------------------------
-- Scenario: Canonical mapping, all null variants, partial input and storage limits.
-- Setup: Twenty explicit independent cases and collision-checked Countries.
-- Expected: One row/ID per CALL, scalar sourcing, exact widths and no trimming.
-- -----------------------------------------------------------------------------
SELECT test.* FROM dd_success_cases c CROSS JOIN LATERAL
    pg_temp.dd_success(c.payload,c.info,c.expected,c.label) test;

CREATE TEMP TABLE dd_error_cases(label TEXT PRIMARY KEY,payload JSON,info VARCHAR,state TEXT NOT NULL);
INSERT INTO dd_error_cases VALUES
('name over width',JSONB_BUILD_OBJECT('employer_name',REPEAT('N',51))::JSON,NULL,'22001'),
('reference over width',JSONB_BUILD_OBJECT('employee_reference',REPEAT('R',36))::JSON,NULL,'22001'),
('email over width',JSONB_BUILD_OBJECT('employer_email_address',REPEAT('E',81))::JSON,NULL,'22001'),
('telephone over width',JSONB_BUILD_OBJECT('employer_telephone_number',REPEAT('T',36))::JSON,NULL,'22001'),
('postcode over width',JSONB_BUILD_OBJECT('employer_address',JSONB_BUILD_OBJECT('postcode',REPEAT('P',11)))::JSON,NULL,'22001'),
('information over width','{}',REPEAT('I',201),'22001'),
('unknown Country','{"employer_address":{"cjs_code":31976}}',NULL,'P0002'),
('ambiguous Country','{"employer_address":{"cjs_code":31973}}',NULL,'P0003'),
('empty Country code','{"employer_address":{"cjs_code":""}}',NULL,'22P02'),
('whitespace Country code','{"employer_address":{"cjs_code":"   "}}',NULL,'22P02'),
('nonnumeric Country code','{"employer_address":{"cjs_code":"synthetic-invalid"}}',NULL,'22P02'),
('Country above SMALLINT','{"employer_address":{"cjs_code":32768}}',NULL,'22003'),
('Country below SMALLINT','{"employer_address":{"cjs_code":-32769}}',NULL,'22003');
INSERT INTO dd_error_cases
SELECT 'address line '||n||' over width',
    JSONB_BUILD_OBJECT('employer_address',JSONB_BUILD_OBJECT('address_line_'||n,REPEAT('A',36)))::JSON,
    NULL,'22001' FROM GENERATE_SERIES(1,5) n;
DO $guard$
BEGIN
    IF (SELECT COUNT(*) FROM dd_error_cases)<>18 THEN
        RAISE EXCEPTION 'Debtor native failure inventory must contain eighteen cases';
    END IF;
END;
$guard$;
CREATE FUNCTION pg_temp.dd_failure(p_payload JSON,p_info VARCHAR,p_state TEXT,p_label TEXT)
RETURNS SETOF TEXT LANGUAGE plpgsql AS $test$
DECLARE v_before JSONB; v_outcome JSONB;

BEGIN
    v_before := pg_temp.dd_rows();
    v_outcome := pg_temp.dd_probe(p_payload,p_info);
    RETURN NEXT is(v_outcome->>'state',p_state,p_label||': native SQLSTATE propagates');
    RETURN NEXT ok(v_outcome->>'id' IS NULL,p_label||': no successful ID');
    RETURN NEXT ok(v_before IS NOT DISTINCT FROM pg_temp.dd_rows(),
        p_label||': all prior detail rows unchanged');
END;
$test$;
-- -----------------------------------------------------------------------------
-- Scenario: Width, conversion and strict-lookup failures propagate atomically.
-- Setup: Eighteen invalid calls, unique/duplicate fixture codes, no narrowed casts.
-- Expected: Native SQLSTATE, no successful ID, no persisted row or overwrite.
-- -----------------------------------------------------------------------------
SELECT test.* FROM dd_error_cases c CROSS JOIN LATERAL
    pg_temp.dd_failure(c.payload,c.info,c.state,c.label) test;

-- -----------------------------------------------------------------------------
-- Scenario: A valid canonical code encounters a real persisted-ID FK failure.
-- Setup: Scoped BEFORE INSERT trigger changes only the owned valid Country ID.
-- Expected: Native 23503/constraint propagate, no row/ID, fixture and cleanup intact.
-- -----------------------------------------------------------------------------
SELECT is((SELECT COUNT(*) FROM public.countries WHERE cjs_code=31971),1::BIGINT,
    'FK fault uses one valid code match');
SELECT is((SELECT COUNT(*) FROM public.countries WHERE country_id=-31979),0::BIGINT,
    'injected Country ID is absent');
DO $guard$
BEGIN
    IF EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.debtor_detail'::REGCLASS
              AND tgname='dd_test_invalid_country') THEN
        RAISE EXCEPTION 'Debtor fault trigger collision';
    END IF;
END;
$guard$;
CREATE TEMP TABLE dd_fault_observation AS
SELECT pg_temp.dd_rows() AS before_rows,
       (SELECT TO_JSONB(c) FROM public.countries c WHERE country_id=-31971) AS country_before;
CREATE FUNCTION pg_temp.dd_inject_invalid_country() RETURNS TRIGGER LANGUAGE plpgsql AS $fault$
BEGIN
    IF NEW.employer_country_id=-31971 THEN
        NEW.employer_country_id := -31979;
    END IF;
    RETURN NEW;
END;
$fault$;
CREATE TRIGGER dd_test_invalid_country BEFORE INSERT ON public.debtor_detail
FOR EACH ROW EXECUTE FUNCTION pg_temp.dd_inject_invalid_country();
ALTER TABLE dd_fault_observation ADD COLUMN outcome JSONB;
UPDATE dd_fault_observation
SET outcome=pg_temp.dd_probe('{"employer_address":{"cjs_code":31971}}',NULL);
SELECT is((SELECT outcome->>'state' FROM dd_fault_observation),'23503',
    'real FK SQLSTATE propagates through debtor helper');
SELECT is((SELECT outcome->>'constraint' FROM dd_fault_observation),'dd_employer_country_id_fk',
    'real employer Country FK diagnostic is retained');
SELECT ok((SELECT outcome->>'id' FROM dd_fault_observation) IS NULL,
    'FK failure supplies no successful ID');
SELECT ok((SELECT before_rows FROM dd_fault_observation) IS NOT DISTINCT FROM pg_temp.dd_rows(),
    'FK failure preserves all detail rows');
SELECT ok((SELECT country_before FROM dd_fault_observation) IS NOT DISTINCT FROM
    (SELECT TO_JSONB(c) FROM public.countries c WHERE country_id=-31971),
    'FK fault preserves the original Country fixture');
DROP TRIGGER dd_test_invalid_country ON public.debtor_detail;
DROP FUNCTION pg_temp.dd_inject_invalid_country();
SELECT ok(NOT EXISTS(SELECT 1 FROM pg_trigger
    WHERE tgrelid='public.debtor_detail'::REGCLASS AND tgname='dd_test_invalid_country')
    AND TO_REGPROCEDURE('pg_temp.dd_inject_invalid_country()') IS NULL,
    'exact fault trigger and function removed before later calls');

-- -----------------------------------------------------------------------------
-- Scenario: Repeated identical calls create two independently returned rows.
-- Setup: Same information-only input twice after fault removal; record count first.
-- Expected: Distinct IDs, two-row delta and identical independently expected content.
-- -----------------------------------------------------------------------------
CREATE TEMP TABLE dd_repeat AS SELECT COUNT(*) AS before_count FROM public.debtor_detail;
ALTER TABLE dd_repeat ADD COLUMN first_id BIGINT;
ALTER TABLE dd_repeat ADD COLUMN second_id BIGINT;
UPDATE dd_repeat SET first_id=pg_temp.dd_call(NULL,'Synthetic repeat');
UPDATE dd_repeat SET second_id=pg_temp.dd_call(NULL,'Synthetic repeat');
SELECT ok(EXISTS(SELECT 1 FROM public.debtor_detail WHERE debtor_detail_id=(SELECT first_id FROM dd_repeat)),
    'first repeat ID identifies its inserted row');
SELECT ok(EXISTS(SELECT 1 FROM public.debtor_detail WHERE debtor_detail_id=(SELECT second_id FROM dd_repeat)),
    'second repeat ID identifies its inserted row');
SELECT ok((SELECT first_id<>second_id FROM dd_repeat),'repeat returns distinct IDs');
SELECT is((SELECT COUNT(*) FROM public.debtor_detail),(SELECT before_count+2 FROM dd_repeat),
    'repeat has exact two-row delta');
SELECT ok((SELECT COUNT(*) FROM public.debtor_detail
    WHERE debtor_detail_id IN ((SELECT first_id FROM dd_repeat),(SELECT second_id FROM dd_repeat))
      AND other_personal_information='Synthetic repeat')=2,
    'both repeated rows preserve the independent supplied information');

-- -----------------------------------------------------------------------------
-- Scenario: The caller rolls back a successful insertion using its savepoint.
-- Setup: Save observations in psql variables; emit no TAP before rollback.
-- Expected: ID existed inside caller scope, row removed, pre-call rows unchanged.
-- -----------------------------------------------------------------------------
SELECT COUNT(*) AS rollback_count FROM public.debtor_detail \gset
SELECT pg_temp.dd_rows()::TEXT AS rollback_rows \gset
SELECT last_value AS rollback_sequence FROM public.debtor_detail_id_seq \gset
SAVEPOINT dd_caller;
SELECT pg_temp.dd_call(NULL,'Synthetic rollback') AS rollback_id \gset
SELECT EXISTS(SELECT 1 FROM public.debtor_detail WHERE debtor_detail_id=:'rollback_id'::BIGINT)
    AS rollback_was_visible \gset
ROLLBACK TO SAVEPOINT dd_caller;
RELEASE SAVEPOINT dd_caller;
SELECT ok(:'rollback_was_visible'::BOOLEAN,'caller saw the returned inserted row before rollback');
SELECT ok(NOT EXISTS(SELECT 1 FROM public.debtor_detail WHERE debtor_detail_id=:'rollback_id'::BIGINT),
    'caller rollback removes its inserted detail');
SELECT is((SELECT COUNT(*) FROM public.debtor_detail),:'rollback_count'::BIGINT,
    'caller rollback restores pre-call row count');
SELECT ok(pg_temp.dd_rows() IS NOT DISTINCT FROM :'rollback_rows'::JSONB,
    'caller rollback preserves every pre-call detail row');
SELECT ok((SELECT last_value>:'rollback_sequence'::BIGINT AND is_called FROM public.debtor_detail_id_seq),
    'caller rollback permits consumed sequence values without resetting them');

-- -----------------------------------------------------------------------------
-- Scenario: Calls affect only newly inserted detail rows and native sequence state.
-- Setup: Pre-call four-table snapshots include owned detail and draft sentinels.
-- Expected: Existing details, Countries, Draft status/snapshot/timeline and accounts unchanged.
-- -----------------------------------------------------------------------------
SELECT ok(NOT EXISTS(
    SELECT 1 FROM dd_scope_before b CROSS JOIN LATERAL JSONB_ARRAY_ELEMENTS_TEXT(b.rows->'debtor_detail') old
    WHERE NOT EXISTS(SELECT 1 FROM public.debtor_detail d WHERE ROW_TO_JSON(d)::TEXT=old.value)),
    'all pre-call detail rows remain unchanged');
SELECT ok((SELECT rows->'countries' FROM dd_scope_before) IS NOT DISTINCT FROM
    (pg_temp.dd_installation_state()->'rows'->'countries'),'all Country rows remain unchanged');
SELECT ok((SELECT rows->'draft_casefiles' FROM dd_scope_before) IS NOT DISTINCT FROM
    (pg_temp.dd_installation_state()->'rows'->'draft_casefiles'),
    'all Draft Casefile status snapshot and timeline rows remain unchanged');
SELECT ok((SELECT rows->'respondent_accounts' FROM dd_scope_before) IS NOT DISTINCT FROM
    (pg_temp.dd_installation_state()->'rows'->'respondent_accounts'),
    'all Respondent Account rows remain unchanged');
SELECT * FROM finish();
ROLLBACK;
\endif
