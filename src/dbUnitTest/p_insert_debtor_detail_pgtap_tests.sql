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
 * 13/10/2026  Frankie Moran  PO-10644  Verify strict widths and forward replacement.
 * 14/10/2026  Frankie Moran  PO-10643  Adopt enabling shared upgrade lifecycle.
 * 15/10/2026  Frankie Moran  PO-10644  Adopt shared contracts and verify preserved error diagnostics.
 */
-- OPAL-DB-UPGRADE {"id":"p_insert_debtor_detail.create","candidate":"ddl/V1_34__create_p_insert_debtor_detail_procedure.sql","scope":"both","data":"migration-created-only","contract":{"type":"additive","objects":{"created":[{"kind":"routine","identity":"public.p_insert_debtor_detail(json,character varying)"}],"replaced":[]},"preserve":{"rows":["public.debtor_detail","public.countries","public.draft_casefiles","public.respondent_accounts"],"tables":["public.debtor_detail","public.countries"],"routines":[],"enums":[],"sequences":["public.debtor_detail_id_seq","public.country_id_seq"]},"assertion":"debtor.create"}}
-- OPAL-DB-UPGRADE {"id":"p_insert_debtor_detail.strict_widths","candidate":"ddl/V1_35__replace_p_insert_debtor_detail_strict_widths.sql","scope":"both","data":"migration-created-only","contract":{"type":"replacement","objects":{"created":[],"replaced":[{"kind":"routine","identity":"public.p_insert_debtor_detail(json,character varying)"}]},"preserve":{"rows":["public.debtor_detail","public.countries","public.draft_casefiles","public.respondent_accounts"],"tables":["public.debtor_detail","public.countries"],"routines":[],"enums":[],"sequences":["public.debtor_detail_id_seq","public.country_id_seq"]},"assertion":"debtor.strict_widths"}}
-- OPAL-DB-UPGRADE {"id":"p_insert_debtor_detail.error_handler","candidate":"ddl/V1_38__replace_p_insert_debtor_detail_error_handler.sql","scope":"both","data":"migration-created-only","contract":{"type":"replacement","objects":{"created":[],"replaced":[{"kind":"routine","identity":"public.p_insert_debtor_detail(json,character varying)"}]},"preserve":{"rows":["public.debtor_detail","public.countries","public.draft_casefiles","public.respondent_accounts"],"tables":["public.debtor_detail","public.countries"],"routines":[],"enums":[],"sequences":["public.debtor_detail_id_seq","public.country_id_seq"]},"assertion":"debtor.current"}}
-- DB-04/DB-06: catalogue, mapping, errors, row scope, repeat and caller rollback.
-- Historical groups retain their original contracts without requiring later handlers.
-- Shared support owns predecessor preservation, lifecycle and independent cleanup.
\set ON_ERROR_STOP 1
\if :{?opal_assertion_group}
\else
    \set opal_assertion_group debtor.current
\endif
SELECT :'opal_assertion_group' IN ('debtor.create','debtor.strict_widths','debtor.current') AS valid_debtor_group,
       :'opal_assertion_group' <> 'debtor.create' AS strict_widths,
       :'opal_assertion_group' = 'debtor.current' AS current_contract \gset
\if :valid_debtor_group
\else
    DO $group$ BEGIN RAISE EXCEPTION 'Unknown debtor assertion group'; END; $group$;
\endif
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SET LOCAL search_path = public, pg_catalog;
SET LOCAL TIME ZONE 'UTC';
SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '5s';

CREATE FUNCTION pg_temp.dd_scope_rows() RETURNS JSONB LANGUAGE plpgsql AS $state$
DECLARE
    v_table TEXT;
    v_rows JSONB := '{}'::JSONB;
    v_values JSONB;

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
    RETURN v_rows;
END;
$state$;

\if :current_contract
    SELECT plan(240);
\elif :strict_widths
    SELECT plan(173);
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
DECLARE
    v_id BIGINT;
    v_detail TEXT;
    v_hint TEXT;
    v_schema TEXT;
    v_table TEXT;
    v_column TEXT;
    v_constraint TEXT;
    v_context TEXT;

BEGIN
    v_id := pg_temp.dd_call(p_payload,p_info);
    RETURN JSONB_BUILD_OBJECT('id',v_id,'state',NULL,'constraint',NULL,'succeeded',true);

EXCEPTION
    WHEN query_canceled OR assert_failure OR OTHERS THEN
        GET STACKED DIAGNOSTICS v_detail=PG_EXCEPTION_DETAIL,v_hint=PG_EXCEPTION_HINT,
            v_schema=SCHEMA_NAME,v_table=TABLE_NAME,v_column=COLUMN_NAME,
            v_constraint=CONSTRAINT_NAME,v_context=PG_EXCEPTION_CONTEXT;

        RETURN JSONB_BUILD_OBJECT('id',v_id,'state',SQLSTATE,'message',SQLERRM,
            'detail',v_detail,'hint',v_hint,'schema',v_schema,'table',v_table,
            'column',v_column,'constraint',v_constraint,'context',v_context,'succeeded',false);
END;
$probe$;
CREATE TEMP TABLE dd_scope_before AS SELECT pg_temp.dd_scope_rows() AS rows;

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
-- The immutable create boundary retains its original legacy contract coverage.
-- Current fresh/replacement paths additionally reject excess trailing spaces.
\if :strict_widths
INSERT INTO dd_error_cases VALUES
('name excess trailing space',JSONB_BUILD_OBJECT('employer_name',REPEAT('N',50)||' ')::JSON,NULL,'22001'),
('reference excess trailing space',JSONB_BUILD_OBJECT('employee_reference',REPEAT('R',35)||' ')::JSON,NULL,'22001'),
('email excess trailing space',JSONB_BUILD_OBJECT('employer_email_address',REPEAT('E',80)||' ')::JSON,NULL,'22001'),
('telephone excess trailing space',JSONB_BUILD_OBJECT('employer_telephone_number',REPEAT('T',35)||' ')::JSON,NULL,'22001'),
('postcode excess trailing space',JSONB_BUILD_OBJECT('employer_address',JSONB_BUILD_OBJECT('postcode',REPEAT('P',10)||' '))::JSON,NULL,'22001'),
('information excess trailing space',NULL,REPEAT('I',200)||' ','22001');
INSERT INTO dd_error_cases
SELECT 'address line '||n||' excess trailing space',
    JSONB_BUILD_OBJECT('employer_address',JSONB_BUILD_OBJECT('address_line_'||n,REPEAT('A',35)||' '))::JSON,
    NULL,'22001' FROM GENERATE_SERIES(1,5) n;
\endif
SELECT SET_CONFIG('opal.dd_strict_widths',:'strict_widths',false) AS strict_width_flag \gset
DO $guard$
BEGIN
    IF (SELECT COUNT(*) FROM dd_error_cases)<>
       (CASE WHEN CURRENT_SETTING('opal.dd_strict_widths')::BOOLEAN THEN 29 ELSE 18 END) THEN
        RAISE EXCEPTION 'Debtor failure inventory must contain eighteen legacy or twenty-nine current cases';
    END IF;
END;
$guard$;
CREATE FUNCTION pg_temp.dd_failure(p_payload JSON,p_info VARCHAR,p_state TEXT,p_label TEXT)
RETURNS SETOF TEXT LANGUAGE plpgsql AS $test$
DECLARE v_before JSONB; v_outcome JSONB;

BEGIN
    v_before := pg_temp.dd_rows();
    v_outcome := pg_temp.dd_probe(p_payload,p_info);
    RETURN NEXT is(v_outcome->>'state',p_state,p_label||': required SQLSTATE propagates');
    RETURN NEXT ok(v_outcome->>'id' IS NULL,p_label||': no successful ID');
    RETURN NEXT ok(v_before IS NOT DISTINCT FROM pg_temp.dd_rows(),
        p_label||': all prior detail rows unchanged');
END;
$test$;
-- -----------------------------------------------------------------------------
-- Scenario: Width, conversion and strict-lookup failures propagate atomically.
-- Setup: Eighteen legacy calls plus eleven excess-space cases on current paths.
-- Expected: Required SQLSTATE, no successful ID, no persisted row or overwrite.
-- -----------------------------------------------------------------------------
SELECT test.* FROM dd_error_cases c CROSS JOIN LATERAL
    pg_temp.dd_failure(c.payload,c.info,c.state,c.label) test;

\if :current_contract
-- -----------------------------------------------------------------------------
-- Scenario: Native lookup/conversion errors and the deliberate width error retain diagnostics.
-- Setup: Reuse the collision-checked unknown/duplicate Country and over-width inputs.
-- Expected: Original SQLSTATE, message, detail, hint and object fields are unchanged;
--           context retains the procedure frame; TAP emits booleans rather than values.
-- -----------------------------------------------------------------------------
CREATE TEMP TABLE dd_native_diagnostics(label TEXT PRIMARY KEY,payload JSON,expected JSONB);
INSERT INTO dd_native_diagnostics VALUES
('missing Country diagnostics','{"employer_address":{"cjs_code":31976}}',
    '["P0002","query returned no rows","","","","","",""]'),
('ambiguous Country diagnostics','{"employer_address":{"cjs_code":31973}}',
    '["P0003","query returned more than one row","","Make sure the query returns a single row, or use LIMIT 1.","","","",""]'),
('conversion diagnostics','{"employer_address":{"cjs_code":"synthetic-invalid"}}',
    '["22P02","invalid input syntax for type smallint: \"synthetic-invalid\"","","","","","",""]'),
('deliberate width diagnostics',JSONB_BUILD_OBJECT('employer_name',REPEAT('N',51))::JSON,
    '["22001","p_insert_debtor_detail: mapped value exceeds its storage width","","","","","",""]');
CREATE FUNCTION pg_temp.dd_native_diagnostic_tests(p_payload JSON,p_expected JSONB,p_label TEXT)
RETURNS SETOF TEXT LANGUAGE plpgsql AS $diagnostics$
DECLARE v_result JSONB;

BEGIN
    v_result := pg_temp.dd_probe(p_payload,NULL);
    RETURN NEXT ok(JSONB_BUILD_ARRAY(v_result->>'state',v_result->>'message',
        v_result->>'detail',v_result->>'hint',v_result->>'schema',v_result->>'table',
        v_result->>'column',v_result->>'constraint') IS NOT DISTINCT FROM p_expected,
        p_label||': original SQLSTATE and all applicable diagnostic fields retained');
    RETURN NEXT ok(v_result->>'context' LIKE '%p_insert_debtor_detail%',
        p_label||': original procedure context remains observable');
END;
$diagnostics$;
SELECT test.* FROM dd_native_diagnostics c CROSS JOIN LATERAL
    pg_temp.dd_native_diagnostic_tests(c.payload,c.expected,c.label) test;
\endif

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
\if :current_contract
SELECT ok((SELECT JSONB_BUILD_ARRAY(outcome->>'message',outcome->>'detail',outcome->>'hint',
    outcome->>'schema',outcome->>'table',outcome->>'column',outcome->>'constraint')
    FROM dd_fault_observation) IS NOT DISTINCT FROM JSONB_BUILD_ARRAY(
        'insert or update on table "debtor_detail" violates foreign key constraint "dd_employer_country_id_fk"',
        'Key (employer_country_id)=(-31979) is not present in table "countries".',
        '','public','debtor_detail','','dd_employer_country_id_fk'),
    'real FK failure retains original message detail hint and object diagnostics');
SELECT ok((SELECT outcome->>'context' LIKE '%p_insert_debtor_detail%' FROM dd_fault_observation),
    'real FK failure retains the original procedure context');
\endif
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
    (pg_temp.dd_scope_rows()->'countries'),'all Country rows remain unchanged');
SELECT ok((SELECT rows->'draft_casefiles' FROM dd_scope_before) IS NOT DISTINCT FROM
    (pg_temp.dd_scope_rows()->'draft_casefiles'),
    'all Draft Casefile status snapshot and timeline rows remain unchanged');
SELECT ok((SELECT rows->'respondent_accounts' FROM dd_scope_before) IS NOT DISTINCT FROM
    (pg_temp.dd_scope_rows()->'respondent_accounts'),
    'all Respondent Account rows remain unchanged');

\if :current_contract
-- -----------------------------------------------------------------------------
-- Scenario: Late native-style and deliberate failures retain every supplied diagnostic.
-- Setup: A request-filtered BEFORE INSERT trigger consumes a test attempt and updates
--        the owned sentinel before raising; the probe also catches cancellation/assertion.
-- Expected: Original diagnostics/context, no successful ID, rollback of all statement
--           writes, one attempt without retry and one consumed debtor sequence value.
-- -----------------------------------------------------------------------------
DO $guard$
BEGIN
    IF EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.debtor_detail'::REGCLASS
              AND tgname='dd_test_diagnostics') THEN
        RAISE EXCEPTION 'Debtor diagnostic trigger collision';
    END IF;
END;
$guard$;
CREATE SEQUENCE pg_temp.dd_diagnostic_attempts START 1;
CREATE FUNCTION pg_temp.dd_inject_diagnostics() RETURNS TRIGGER LANGUAGE plpgsql AS $inject$
BEGIN
    IF NEW.other_personal_information='Synthetic diagnostic request' THEN
        PERFORM NEXTVAL('pg_temp.dd_diagnostic_attempts');
        UPDATE public.debtor_detail SET other_personal_information='Synthetic uncommitted write'
        WHERE debtor_detail_id=-31978;
        RAISE EXCEPTION USING ERRCODE=CURRENT_SETTING('po10644.diagnostic_state'),
            MESSAGE='synthetic debtor diagnostic message',
            DETAIL='synthetic debtor diagnostic detail',
            HINT='synthetic debtor diagnostic hint',
            SCHEMA='public',TABLE='debtor_detail',COLUMN='debtor_detail_id',
            CONSTRAINT='dd_synthetic_diagnostic';
    END IF;

    RETURN NEW;
END;
$inject$;
CREATE TRIGGER dd_test_diagnostics BEFORE INSERT ON public.debtor_detail
FOR EACH ROW EXECUTE FUNCTION pg_temp.dd_inject_diagnostics();
CREATE FUNCTION pg_temp.dd_diagnostic_tests() RETURNS SETOF TEXT LANGUAGE plpgsql AS $diagnostics$
DECLARE
    v_state TEXT;
    v_result JSONB;
    v_rows_before JSONB;
    v_sequence_before BIGINT;

BEGIN
    v_rows_before := pg_temp.dd_scope_rows();

    FOREACH v_state IN ARRAY ARRAY['23503','23505','22001','40001','40P01','P0001','57014','P0004'] LOOP
        PERFORM SETVAL('pg_temp.dd_diagnostic_attempts',1,false);
        PERFORM SET_CONFIG('po10644.diagnostic_state',v_state,true);
        SELECT last_value INTO v_sequence_before FROM public.debtor_detail_id_seq;
        v_result := pg_temp.dd_probe(NULL,'Synthetic diagnostic request');
        RETURN NEXT is(v_result->>'state',v_state,v_state||': late failure retains original SQLSTATE');
        RETURN NEXT ok(JSONB_BUILD_ARRAY(v_result->>'message',v_result->>'detail',
            v_result->>'hint',v_result->>'schema',v_result->>'table',v_result->>'column',
            v_result->>'constraint') IS NOT DISTINCT FROM JSONB_BUILD_ARRAY(
                'synthetic debtor diagnostic message','synthetic debtor diagnostic detail',
                'synthetic debtor diagnostic hint','public','debtor_detail','debtor_detail_id',
                'dd_synthetic_diagnostic'),
            v_state||': late failure retains every supplied diagnostic without displaying values');
        RETURN NEXT ok(v_result->>'context' LIKE '%dd_inject_diagnostics()%'
            AND v_result->>'context' LIKE '%p_insert_debtor_detail%',
            v_state||': original trigger and procedure context remains observable');
        RETURN NEXT ok(v_result->>'succeeded'='false' AND v_result->>'id' IS NULL,
            v_state||': late failure returns no successful output ID');
        RETURN NEXT ok((SELECT JSONB_BUILD_ARRAY(last_value,is_called) FROM pg_temp.dd_diagnostic_attempts)
            IS NOT DISTINCT FROM '[1,true]'::JSONB,
            v_state||': late failure has one attempt without a procedure retry');
        RETURN NEXT ok(pg_temp.dd_scope_rows() IS NOT DISTINCT FROM v_rows_before,
            v_state||': statement rollback restores sentinel and all four row sets');
        RETURN NEXT is((SELECT last_value FROM public.debtor_detail_id_seq),v_sequence_before+1,
            v_state||': failed insertion consumes one sequence value without rewinding');
    END LOOP;
END;
$diagnostics$;
SELECT * FROM pg_temp.dd_diagnostic_tests();
DROP TRIGGER dd_test_diagnostics ON public.debtor_detail;
DROP FUNCTION pg_temp.dd_inject_diagnostics();
DROP SEQUENCE pg_temp.dd_diagnostic_attempts;
SELECT ok(NOT EXISTS(SELECT 1 FROM pg_trigger
    WHERE tgrelid='public.debtor_detail'::REGCLASS AND tgname='dd_test_diagnostics')
    AND TO_REGPROCEDURE('pg_temp.dd_inject_diagnostics()') IS NULL
    AND TO_REGCLASS('pg_temp.dd_diagnostic_attempts') IS NULL,
    'exact diagnostic trigger function and attempt sequence removed');
\endif
SELECT * FROM finish();
ROLLBACK;
