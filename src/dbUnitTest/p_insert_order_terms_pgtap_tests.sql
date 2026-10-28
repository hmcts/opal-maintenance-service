/**
 * OPAL Program
 *
 * MODULE      : p_insert_order_terms_pgtap_tests.sql
 *
 * DESCRIPTION : Verify the validated single-term helper and exact response persistence.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket        Nature of Change
 * ----------  -------------  ------------  ----------------------------------------
 * 18/10/2026  Frankie Moran  PO-10646      Initial approved-contract pgTAP test suite.
 */

-- OPAL-DB-UPGRADE {"id":"p_insert_order_terms.create","candidate":"ddl/V1_63__create_p_insert_order_terms_procedure.sql","scope":"both","data":"migration-created-only","inputs":["src/main/resources/db/migration/ddl/V1_8__create_results_table.sql","src/main/resources/db/migration/data/allEnvs/V1_13__insert_results_reference_data.sql","src/main/resources/db/migration/ddl/V1_15__allow_null_results_permitted_actions.sql","src/main/resources/db/migration/data/allEnvs/V1_16__refresh_results_reference_data.sql","src/main/resources/db/migration/ddl/V1_26__create_respondent_accounts_table.sql","src/main/resources/db/migration/ddl/V1_27__create_creditor_accounts_table.sql","src/main/resources/db/migration/ddl/V1_29__create_order_terms_table.sql","src/main/resources/db/migration/ddl/V1_62__add_order_terms_result_responses.sql","src/main/resources/db/migration/ddl/V1_6__create_business_units_table.sql","src/main/resources/db/migration/data/allEnvs/V1_7__insert_business_units_reference_data.sql","src/main/resources/db/migration/ddl/V1_11__create_maintenance_applications_table.sql","src/main/resources/db/migration/data/allEnvs/V1_12__insert_maintenance_applications_reference_data.sql","src/main/resources/db/migration/ddl/V1_49__create_p_insert_creditor_accounts_procedure.sql","src/main/resources/db/migration/ddl/V1_58__create_p_insert_respondent_account_procedure.sql","src/main/resources/db/migration/ddl/V1_9__create_major_creditors_table.sql","src/main/resources/db/migration/data/allEnvs/V1_10__insert_major_creditors_reference_data.sql"],"contract":{"type":"additive","objects":{"created":[{"kind":"routine","identity":"public.p_insert_order_terms(bigint,bigint,character varying,character varying,json)"}],"replaced":[]},"preserve":{"rows":["public.order_terms","public.respondent_accounts","public.creditor_accounts","public.results","public.draft_casefiles","public.notes","public.account_number_index"],"tables":["public.order_terms","public.respondent_accounts","public.creditor_accounts","public.results","public.draft_casefiles","public.notes","public.account_number_index"],"routines":["public.p_insert_respondent_account(smallint,public.t_casefile_type_enum,json,bigint,bigint)","public.p_insert_creditor_accounts(smallint,json,bigint,bigint,bigint)"],"enums":["public.t_payment_frequency_enum"],"sequences":["public.order_terms_id_seq","public.respondent_account_id_seq","public.creditor_account_id_seq","public.account_number_index_id_seq"]},"assertion":"p_insert_order_terms.current"}}

\set ON_ERROR_STOP on
\if :{?opal_assertion_group}
 SELECT :'opal_assertion_group'='p_insert_order_terms.current' AS ot_known_group \gset
 \if :ot_known_group
 \else
  DO $group$ BEGIN RAISE EXCEPTION 'Unknown Order Terms assertion group'; END; $group$;
 \endif
\endif
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SET LOCAL search_path=public,pg_catalog;
SET LOCAL TIME ZONE 'UTC';
SET LOCAL DateStyle='ISO, YMD';
SELECT plan(1585);

-- -----------------------------------------------------------------------------
-- Scenario: The approved five-input single-term procedure is installed.
-- Setup: Inspect the effective installed catalogue before behavioral fixtures run.
-- Expected: Exact properties pass; absence fails explicit assertions before any CALL.
-- -----------------------------------------------------------------------------
CREATE TEMP TABLE ot_installed AS
SELECT TO_REGPROCEDURE('public.p_insert_order_terms(bigint,bigint,character varying,character varying,json)') AS oid;
SELECT ok((SELECT oid IS NOT NULL FROM ot_installed),'Order Terms procedure is installed');
SELECT ok((SELECT prokind='p' FROM pg_proc WHERE oid=(SELECT oid FROM ot_installed)),
    'installed object is a procedure');
SELECT ok((SELECT proargtypes=ARRAY['bigint'::REGTYPE::OID,'bigint'::REGTYPE::OID,
    'varchar'::REGTYPE::OID,'varchar'::REGTYPE::OID,'json'::REGTYPE::OID]::OIDVECTOR
    FROM pg_proc WHERE oid=(SELECT oid FROM ot_installed)),
    'effective five argument types and order');
SELECT ok((SELECT proargnames=ARRAY['pi_respondent_account_id','pi_creditor_account_id',
    'pi_posted_by','pi_posted_by_name','pi_order_term_json']::TEXT[]
    FROM pg_proc WHERE oid=(SELECT oid FROM ot_installed)), 'exact five argument names');
SELECT ok((SELECT pronargs=5 AND proargmodes IS NULL AND proallargtypes IS NULL
    AND prorettype='void'::REGTYPE FROM pg_proc WHERE oid=(SELECT oid FROM ot_installed)),
    'five IN arguments have no output');
SELECT ok((SELECT pronargdefaults=0 AND proargdefaults IS NULL AND NOT prosecdef
    AND NOT proisstrict AND NOT proleakproof AND NOT proretset AND provolatile='v'
    AND proparallel='u' AND proconfig IS NULL FROM pg_proc WHERE oid=(SELECT oid FROM ot_installed)),
    'ordinary invoker and default execution properties preserve caller ownership');
SELECT ok((SELECT lanname='plpgsql' FROM pg_proc p JOIN pg_language l ON l.oid=p.prolang
    WHERE p.oid=(SELECT oid FROM ot_installed)), 'procedure language is PLpgSQL');
SELECT is((SELECT COUNT(*) FROM pg_proc
    WHERE pronamespace='public'::REGNAMESPACE AND proname='p_insert_order_terms'),
    1::BIGINT,'exactly one public Order Terms procedure overload');


SELECT (SELECT oid IS NOT NULL FROM ot_installed) AS exists \gset ot_
\if :ot_exists
-- -----------------------------------------------------------------------------
-- Scenario: Synthetic parents and metadata are isolated within the owning transaction.
-- Setup: Collision-check negative IDs, a dedicated BU and independent Result definitions.
-- Expected: Existing reference data remains intact and all test-owned DML rolls back.
-- -----------------------------------------------------------------------------
DO $fixtures$
BEGIN
 IF CURRENT_DATABASE()<>'opal_maintenance_db_unit_test' OR CURRENT_USER<>'postgres' THEN
  RAISE EXCEPTION 'Order Terms tests require the maintained disposable database and role';
 END IF;
 IF EXISTS(SELECT 1 FROM public.business_units WHERE business_unit_id=32080 OR business_unit_code='O046')
 OR EXISTS(SELECT 1 FROM public.respondent_accounts WHERE respondent_account_id IN (-864601,-864603,-864699))
 OR EXISTS(SELECT 1 FROM public.creditor_accounts WHERE creditor_account_id IN (-864602,-864604,-864699))
 OR EXISTS(SELECT 1 FROM public.results WHERE result_id IN ('OT46G','OT46U','OT46I','OT46N','OT46C','OT46X')) THEN
  RAISE EXCEPTION 'Order Terms synthetic fixture collision';
 END IF;
END;
$fixtures$;
INSERT INTO public.business_units(business_unit_id,business_unit_code,business_unit_name,business_unit_type,welsh_language)
VALUES(32080,'O046','Synthetic procedure unit','Area',FALSE);
INSERT INTO public.respondent_accounts(
 respondent_account_id,business_unit_id,account_number,application_id,imposed_hearing_date,
 account_balance,orders_balance,orders_amount,payment_period,total_arrears,account_status,
 last_movement_date,date_arrears_last_updated,allow_cheques,cheque_clearance_period,
 credit_trans_clearance_period,casefile_type,interest_flag,indexation,payment_arrangement,version_number)
SELECT id,32080,'OT-RESP-'||(-id)::TEXT,(SELECT MIN(application_id) FROM public.maintenance_applications),imposed,
 0,0,0,'Weekly',0,'L',TIMESTAMP '2024-01-01',TIMESTAMP '2024-01-01',TRUE,10,0,'REMO In',FALSE,'None','Court',1
FROM(VALUES(-864601::BIGINT,TIMESTAMP '2024-02-29 12:13:14.456789'),(-864603::BIGINT,NULL::TIMESTAMP))v(id,imposed);
INSERT INTO public.creditor_accounts(creditor_account_id,business_unit_id,account_number,creditor_account_type,major_creditor_id,from_suspense,hold_payout,pay_by_bacs)
VALUES(-864602,32080,'OT-MAJOR','MJ',(SELECT MIN(major_creditor_id) FROM public.major_creditors),FALSE,FALSE,FALSE),
 (-864604,32080,'OT-SUSPENSE','MN',NULL,TRUE,FALSE,FALSE);
INSERT INTO public.results(result_id,result_title,order_term,enforcement_result,case_result,active,order_accruing,
 requires_creditor,enforcement_hold,requires_enforcer,generates_hearing,generates_warrant,lists_monies,
 requires_employment_data,allow_additional_action,enf_next_permitted_actions,manual_enforcement,auto_enforcement)
SELECT id,'Synthetic procedure Result',is_term,FALSE,FALSE,is_active,FALSE,creditor,FALSE,FALSE,FALSE,FALSE,FALSE,
 FALSE,FALSE,'',FALSE,FALSE
FROM(VALUES('OT46G',TRUE,TRUE,TRUE),('OT46U',TRUE,TRUE,TRUE),('OT46I',FALSE,TRUE,TRUE),
 ('OT46N',TRUE,FALSE,TRUE),('OT46C',TRUE,TRUE,FALSE))v(id,is_active,is_term,creditor);
UPDATE public.results SET result_parameters='[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON
WHERE result_id IN ('OT46G','OT46I','OT46N','OT46C');
UPDATE public.results SET result_parameters='null'::JSON WHERE result_id='OT46U';

CREATE FUNCTION pg_temp.ot_scope(excluded BIGINT DEFAULT NULL) RETURNS JSONB LANGUAGE SQL VOLATILE AS $scope$
 SELECT JSONB_BUILD_OBJECT(
 'terms',(SELECT COALESCE(JSONB_AGG(ROW_TO_JSON(t)::TEXT ORDER BY order_terms_id),'[]'::JSONB)
  FROM public.order_terms t WHERE excluded IS NULL OR order_terms_id<>excluded),
 'respondents',(SELECT JSONB_AGG(ROW_TO_JSON(t)::TEXT ORDER BY respondent_account_id) FROM public.respondent_accounts t),
 'creditors',(SELECT JSONB_AGG(ROW_TO_JSON(t)::TEXT ORDER BY creditor_account_id) FROM public.creditor_accounts t),
 'results',(SELECT JSONB_AGG(ROW_TO_JSON(t)::TEXT ORDER BY result_id) FROM public.results t),
 'drafts',(SELECT COALESCE(JSONB_AGG(ROW_TO_JSON(t)::TEXT ORDER BY draft_casefile_id),'[]'::JSONB) FROM public.draft_casefiles t),
 'notes',(SELECT COALESCE(JSONB_AGG(ROW_TO_JSON(t)::TEXT ORDER BY note_id),'[]'::JSONB) FROM public.notes t),
 'reservations',(SELECT COALESCE(JSONB_AGG(ROW_TO_JSON(t)::TEXT ORDER BY account_number_index_id),'[]'::JSONB) FROM public.account_number_index t));
$scope$;
CREATE FUNCTION pg_temp.ot_call(payload TEXT,respondent BIGINT,creditor BIGINT,author TEXT,author_name TEXT)
RETURNS JSONB LANGUAGE plpgsql AS $observe$
DECLARE code TEXT; message TEXT; detail TEXT; hint TEXT; schema_name TEXT; table_name TEXT;
 column_name TEXT; data_type TEXT; constraint_name TEXT; context TEXT;
 before_scope JSONB; after_scope JSONB; before_sequence JSONB; after_sequence JSONB;
 before_ids BIGINT[]; new_ids BIGINT[]; typed JSONB; raw TEXT;
BEGIN
 before_scope:=pg_temp.ot_scope();
 SELECT ARRAY_AGG(order_terms_id) INTO before_ids FROM public.order_terms;
 SELECT JSONB_BUILD_ARRAY(last_value,is_called) INTO before_sequence FROM public.order_terms_id_seq;
 BEGIN
  CALL public.p_insert_order_terms(respondent,creditor,author::VARCHAR,author_name::VARCHAR,payload::JSON);
 EXCEPTION WHEN assert_failure THEN
  GET STACKED DIAGNOSTICS code=RETURNED_SQLSTATE,message=MESSAGE_TEXT,detail=PG_EXCEPTION_DETAIL,
   hint=PG_EXCEPTION_HINT,schema_name=SCHEMA_NAME,table_name=TABLE_NAME,column_name=COLUMN_NAME,
   data_type=PG_DATATYPE_NAME,constraint_name=CONSTRAINT_NAME,context=PG_EXCEPTION_CONTEXT;
 WHEN OTHERS THEN
  GET STACKED DIAGNOSTICS code=RETURNED_SQLSTATE,message=MESSAGE_TEXT,detail=PG_EXCEPTION_DETAIL,
   hint=PG_EXCEPTION_HINT,schema_name=SCHEMA_NAME,table_name=TABLE_NAME,column_name=COLUMN_NAME,
   data_type=PG_DATATYPE_NAME,constraint_name=CONSTRAINT_NAME,context=PG_EXCEPTION_CONTEXT;
 END;
 SELECT ARRAY_AGG(order_terms_id ORDER BY order_terms_id) INTO new_ids FROM public.order_terms
 WHERE NOT(order_terms_id=ANY(COALESCE(before_ids,ARRAY[]::BIGINT[])));
 SELECT TO_JSONB(t)-'order_terms_id'-'result_responses',result_responses::TEXT INTO typed,raw
 FROM public.order_terms t WHERE order_terms_id=new_ids[1];
 after_scope:=pg_temp.ot_scope(CASE WHEN code IS NULL AND CARDINALITY(new_ids)=1 THEN new_ids[1] END);
 SELECT JSONB_BUILD_ARRAY(last_value,is_called) INTO after_sequence FROM public.order_terms_id_seq;
 RETURN JSONB_BUILD_OBJECT('code',code,'message',message,'detail',detail,'hint',hint,'schema',schema_name,
  'table',table_name,'column',column_name,'datatype',data_type,'constraint',constraint_name,'context',context,
  'new_count',COALESCE(CARDINALITY(new_ids),0),'id',new_ids[1],'typed',typed,'raw',raw,
  'scope_unchanged',before_scope=after_scope,'sequence_unchanged',before_sequence=after_sequence);
END;
$observe$;
CREATE TEMP TABLE ot_cases(
 label TEXT PRIMARY KEY,result_id TEXT,metadata JSON,responses TEXT,payload_override TEXT,sql_null BOOLEAN,
 respondent BIGINT,creditor BIGINT,author TEXT,author_name TEXT,expected_code TEXT,expected_patch JSONB);

INSERT INTO ot_cases VALUES
('generic amount retains raw spaces and leading zeros','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{}'::JSONB),
('current MAT complete mandatory responses','MAT','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Frequency","response":"Weekly"},{"parameter_name":"Creditor","response":"Synthetic creditor"},{"parameter_name":"Respondent","response":"Synthetic respondent"},{"parameter_name":"Payment","response":"Payable through the Court"},{"parameter_name":"Commencement","response":"2024-02-29"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{}'::JSONB),
('current MCHILD all typed projections','MCHILD','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Frequency","response":"Weekly"},{"parameter_name":"Expiry","response":"2030-12-31"},{"parameter_name":"Education","response":"[\"Additional terms affect order expiry\"]"},{"parameter_name":"Arrears","response":"3.20"},{"parameter_name":"Beneficiary","response":"Synthetic child"},{"parameter_name":"ChildDOB","response":"2012-02-29"},{"parameter_name":"Respondent","response":"Synthetic respondent"},{"parameter_name":"Payment","response":"Payable through the Court"},{"parameter_name":"Commencement","response":"2024-02-29"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{"arrears_amount":3.2,"child_name":"Synthetic child","child_birth_date":"2012-02-29T00:00:00","expiry_date":"2030-12-31T00:00:00","expiry_terms":true}'::JSONB),
('current MLUMP generic Reason and Due','MLUMP','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Creditor","response":"Synthetic creditor"},{"parameter_name":"Respondent","response":"Synthetic respondent"},{"parameter_name":"Payment","response":"Payable between the parties"},{"parameter_name":"Reason","response":"Synthetic reason"},{"parameter_name":"Due","response":"2024-02-29"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{}'::JSONB),
('negative exact amount is metadata governed','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"-00012.30"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{"imposed_amount":-12.3}'::JSONB),
('zero exact amount accepted','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"0"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{"imposed_amount":0}'::JSONB),
('author values independently NULL','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,NULL,NULL,NULL,'{}'::JSONB),
('empty and whitespace author values retained','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'','   ',NULL,'{}'::JSONB),
('author maximum widths retained','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'XXXXXXXXXXXXXXXXXXXX','YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY',NULL,'{}'::JSONB),
('SQL NULL root','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,TRUE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('JSON null root','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]','null',FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('array root','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]','[]',FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('string root','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]','"scalar"',FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('number root','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]','7',FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('Boolean root','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]','true',FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('missing consumed members','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]','{}',FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('missing responses','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]','{"result_id":"OT46G"}',FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('missing Result','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]','{"result_responses":[]}',FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('null responses','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]','{"result_id":"OT46G","result_responses":null}',FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('object responses','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]','{"result_id":"OT46G","result_responses":{}}',FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('number Result','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]','{"result_id":7,"result_responses":[]}',FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('empty Result','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]','{"result_id":"","result_responses":[]}',FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('overlength Result','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]','{"result_id":"OT46LONG","result_responses":[]}',FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('empty array cannot satisfy Amount','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('NULL respondent input','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,NULL,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('NULL creditor input','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,NULL,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('missing respondent lookup retains P0002','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864699,-864602,'Synthetic author','Synthetic name','P0002','{}'::JSONB),
('missing creditor lookup retains P0002','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864699,'Synthetic author','Synthetic name','P0002','{}'::JSONB),
('missing selected Result lookup retains P0002','OT46X','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0002','{}'::JSONB),
('existing parent without imposed timestamp','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864603,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('existing suspense creditor rejected','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864604,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('inactive Result','OT46I','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('non Order Term Result','OT46N','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('otherwise eligible creditor-free Result','OT46C','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('submitter trailing spaces beyond width20','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'XXXXXXXXXXXXXXXXXXXX ','Synthetic name','22001','{}'::JSONB),
('submitter name trailing spaces beyond width100','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY ','22001','{}'::JSONB),
('SQL NULL metadata','OT46G',NULL,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('JSON null metadata','OT46G','null'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('nonarray metadata','OT46G','{}'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('missing Amount definition','OT46G','[]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unknown metadata type','OT46G','[{"name":"Amount","type":"menu-autocomplete","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('metadata fractional decimal cent','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":1.001,"language_dependent":false}]'::JSON,'[ {"parameter_name":"Amount","response":"1"} ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('metadata bound string','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":"-100","max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('metadata true language flag','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":true}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB);

INSERT INTO ot_cases VALUES
('decimal valid 100','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"100"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{"imposed_amount":100}'::JSONB),
('decimal valid -100','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"-100"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{"imposed_amount":-100}'::JSONB),
('decimal valid -0','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"-0"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{"imposed_amount":0}'::JSONB),
('decimal valid 12','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"12"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{"imposed_amount":12}'::JSONB),
('decimal valid 12.3','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"12.3"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{"imposed_amount":12.3}'::JSONB),
('decimal invalid ''+1''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"+1"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('decimal invalid ''1e1''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"1e1"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('decimal invalid ''1E1''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"1E1"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('decimal invalid ''1,00''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"1,00"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('decimal invalid ''£1''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"£1"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('decimal invalid '' 1''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":" 1"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('decimal invalid ''1 ''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"1 "}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('decimal invalid ''1\n''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"1\n"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('decimal invalid ''.5''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":".5"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('decimal invalid ''1.''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"1."}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('decimal invalid ''--1''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"--1"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('decimal invalid ''NaN''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"NaN"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('decimal invalid ''Infinity''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"Infinity"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('decimal invalid ''12.300''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"12.300"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('decimal invalid ''100.01''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"100.01"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('decimal invalid ''-100.01''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"-100.01"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('decimal equal inclusive bounds','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":12.3,"max":12.3,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{}'::JSONB),
('decimal metadata trailing numeric zero accepted','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":1.0,"max":1.0,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"1"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{"imposed_amount":1}'::JSONB),
('Amount optional metadata still supplied','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":false,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{}'::JSONB),
('Amount optional metadata still requires response','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":false,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('nonobject response element null','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[null]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('nonobject response element 7','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[7]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('nonobject response element true','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[true]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('nonobject response element false','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[false]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('nonobject response element []','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[[]]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('nonobject response element "entry"','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'["entry"]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('missing response','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('missing name','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"response":"12.30"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('null response','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":null}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('numeric response','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":12.30}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('array response','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":[]}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('Boolean response','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":true}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('null name','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":null,"response":"12.30"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('numeric name','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":7,"response":"12.30"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('empty name','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"","response":"12.30"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('extra response member','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"12.30","extra":1}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('response name exact ''amount''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"amount","response":"12.30"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('response name exact '' Amount''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":" Amount","response":"12.30"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('response name exact ''Amount ''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Amount ","response":"12.30"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('response name exact ''Unknown''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Unknown","response":"12.30"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('response name exact ''XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX","response":"12.30"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('duplicate equal names','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Amount","response":"12.30"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('duplicate escaped decoded names','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Am\u006funt","response":"12.30"},{"parameter_name":"Amount","response":"12.30"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('duplicate response keys','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"12.30","response":"12.30"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('duplicate escaped response key','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","resp\u006fnse":"12.30","response":"12.30"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('duplicate root consumed key','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]','{"result_id":"OT46G","result_responses":[ { "parameter_name" : "Amount", "response" : "00012.30" } ],"result_id":"OT46G"}',FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('duplicate root opaque key','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]','{"result_id":"OT46G","result_responses":[ { "parameter_name" : "Amount", "response" : "00012.30" } ],"context":1,"context":2}',FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('duplicate escaped root key','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]','{"result_id":"OT46G","result_responses":[ { "parameter_name" : "Amount", "response" : "00012.30" } ],"res\u0075lt_id":"OT46G"}',FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('opaque context cannot override explicit arguments','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]','{"result_id":"OT46G","result_responses":[ { "parameter_name" : "Amount", "response" : "00012.30" } ],"respondent_account_id":999,"creditor_account_id":999,"posted_by":"SYNTHETIC_PAYLOAD_MARKER_46","due":"bad"}',FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{}'::JSONB),
('escaped decoded Amount identity','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[{"parameter_name":"Am\u006funt","response":"00012.30"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{}'::JSONB),
('unused metadata name None','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":null,"type":"text-60","mandatory":false,"min":0,"max":60,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused metadata name 7','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":7,"type":"text-60","mandatory":false,"min":0,"max":60,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused metadata name ''''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"","type":"text-60","mandatory":false,"min":0,"max":60,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused metadata name ''XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX","type":"text-60","mandatory":false,"min":0,"max":60,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused metadata type None','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":null,"mandatory":false,"min":0,"max":60,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused metadata type 7','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":7,"mandatory":false,"min":0,"max":60,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused metadata type ''unsupported''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"unsupported","mandatory":false,"min":0,"max":60,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused metadata mandatory None','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":null,"min":0,"max":60,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused metadata mandatory ''true''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":"true","min":0,"max":60,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused metadata mandatory 7','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":7,"min":0,"max":60,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused metadata language_dependent None','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":false,"min":0,"max":60,"language_dependent":null}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused metadata language_dependent ''false''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":false,"min":0,"max":60,"language_dependent":"false"}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused metadata language_dependent True','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":false,"min":0,"max":60,"language_dependent":true}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused metadata min None','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":false,"min":null,"max":60,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused metadata min ''0''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":false,"min":"0","max":60,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused metadata min False','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":false,"min":false,"max":60,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused metadata max None','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":false,"min":0,"max":null,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused metadata max ''60''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":false,"min":0,"max":"60","language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused metadata max False','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":false,"min":0,"max":false,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused metadata prompt None','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":false,"min":0,"max":60,"language_dependent":false,"prompt":null}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused metadata prompt 7','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":false,"min":0,"max":60,"language_dependent":false,"prompt":7}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused metadata hint None','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":false,"min":0,"max":60,"language_dependent":false,"hint":null}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused metadata hint False','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":false,"min":0,"max":60,"language_dependent":false,"hint":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused metadata missing name','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"type":"text-60","mandatory":false,"min":0,"max":60,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused metadata missing type','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","mandatory":false,"min":0,"max":60,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused metadata missing mandatory','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","min":0,"max":60,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused metadata missing language_dependent','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":false,"min":0,"max":60}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused metadata missing min','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":false,"max":60,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused metadata missing max','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":false,"min":0,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused text misplaced unknown','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":false,"min":0,"max":60,"language_dependent":false,"unknown":1}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused text misplaced options','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":false,"min":0,"max":60,"language_dependent":false,"options":["A"]}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused text misplaced date_today','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":false,"min":0,"max":60,"language_dependent":false,"date_today":true}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused text misplaced apidata','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":false,"min":0,"max":60,"language_dependent":false,"apidata":"x"}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused text misplaced precision','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":false,"min":0,"max":60,"language_dependent":false,"precision":2}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused metadata reversed bounds','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":false,"min":2,"max":1,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused metadata fractional count','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":false,"min":0.1,"max":60,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused metadata negative count','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":false,"min":-1,"max":60,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused metadata overcapacity text60','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":false,"min":0,"max":61,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused metadata unsupported autocomplete','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-autocomplete","mandatory":false,"min":0,"max":60,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused metadata offcent minimum','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"decimal-2dp","mandatory":false,"min":0.001,"max":10,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused metadata offcent maximum','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"decimal-2dp","mandatory":false,"min":0,"max":10.001,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused metadata reversed decimal','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"decimal-2dp","mandatory":false,"min":2,"max":1,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('nonobject metadata definition','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},7]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('duplicate metadata names','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":false,"min":0,"max":60,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":false,"min":0,"max":60,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('duplicate metadata property','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","name":"Extra","type":"text-60","mandatory":false,"min":0,"max":60,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('duplicate escaped metadata property','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":false,"min":0,"max":60,"language_dependent":false,"language_depend\u0065nt":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('duplicate escaped metadata names','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":false,"min":0,"max":60,"language_dependent":false},{"name":"Ex\u0074ra","type":"text-60","mandatory":false,"min":0,"max":60,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('text-60 accepts empty','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":false,"min":0,"max":60,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":""}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{}'::JSONB),
('text-60 accepts whitespace','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":false,"min":0,"max":60,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"   "}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{}'::JSONB),
('text-60 accepts Unicode','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":false,"min":0,"max":60,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"  Café é 😀  "}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{}'::JSONB),
('text-60 accepts maximum','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":false,"min":0,"max":60,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{}'::JSONB),
('text-60 overlength','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":false,"min":0,"max":60,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('text-60 minimum applies to supplied empty','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":false,"min":1,"max":60,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":""}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('text-60 optional minimum still permits omission','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":false,"min":1,"max":60,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{}'::JSONB),
('text-1000 accepts empty','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-1000","mandatory":false,"min":0,"max":1000,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":""}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{}'::JSONB),
('text-1000 accepts whitespace','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-1000","mandatory":false,"min":0,"max":1000,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"   "}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{}'::JSONB),
('text-1000 accepts Unicode','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-1000","mandatory":false,"min":0,"max":1000,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"  Café é 😀  "}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{}'::JSONB),
('text-1000 accepts maximum','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-1000","mandatory":false,"min":0,"max":1000,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{}'::JSONB),
('text-1000 overlength','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-1000","mandatory":false,"min":0,"max":1000,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('text-1000 minimum applies to supplied empty','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-1000","mandatory":false,"min":1,"max":1000,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":""}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('text-1000 optional minimum still permits omission','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-1000","mandatory":false,"min":1,"max":1000,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{}'::JSONB),
('literal whitespace parameter identity','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":" ","type":"text-60","mandatory":false,"min":0,"max":60,"language_dependent":false}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":" ","response":"literal value"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{}'::JSONB),
('presentation prompt and hint accepted','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"text-60","mandatory":false,"min":0,"max":60,"language_dependent":false,"prompt":"Synthetic prompt","hint":"Synthetic hint"}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"value"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{}'::JSONB),
('date valid 2024-02-29','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"date","mandatory":false,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_past":true,"date_today":true,"date_in_future":true}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"2024-02-29"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{}'::JSONB),
('date valid 1900-01-01','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"date","mandatory":false,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_past":true,"date_today":true,"date_in_future":true}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"1900-01-01"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{}'::JSONB),
('date valid 2100-12-31','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"date","mandatory":false,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_past":true,"date_today":true,"date_in_future":true}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"2100-12-31"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{}'::JSONB),
('date lexical invalid 2024-2-29','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"date","mandatory":false,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_past":true,"date_today":true,"date_in_future":true}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"2024-2-29"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('date lexical invalid 24-02-29','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"date","mandatory":false,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_past":true,"date_today":true,"date_in_future":true}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"24-02-29"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('date lexical invalid 2024/02/29','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"date","mandatory":false,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_past":true,"date_today":true,"date_in_future":true}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"2024/02/29"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('date lexical invalid  2024-02-29','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"date","mandatory":false,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_past":true,"date_today":true,"date_in_future":true}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":" 2024-02-29"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('date lexical invalid 2024-02-29 ','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"date","mandatory":false,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_past":true,"date_today":true,"date_in_future":true}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"2024-02-29 "}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('date lexical invalid 2024-02-29T00:00:00','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"date","mandatory":false,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_past":true,"date_today":true,"date_in_future":true}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"2024-02-29T00:00:00"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('date lexical invalid 2024-02-29Z','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"date","mandatory":false,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_past":true,"date_today":true,"date_in_future":true}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"2024-02-29Z"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('date impossible calendar','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"date","mandatory":false,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_past":true,"date_today":true,"date_in_future":true}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"2023-02-29"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','22008','{}'::JSONB),
('date equal inclusive bounds','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"date","mandatory":false,"min":"2024-02-29","max":"2024-02-29","language_dependent":false,"date_in_past":true,"date_today":true,"date_in_future":true}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"2024-02-29"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{}'::JSONB),
('date outside absolute minimum','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"date","mandatory":false,"min":"2025-01-01","max":"2100-12-31","language_dependent":false,"date_in_past":true,"date_today":true,"date_in_future":true}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"2024-02-29"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused date flag date_in_past None','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"date","mandatory":false,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_past":null,"date_today":true,"date_in_future":true}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused date flag date_in_past ''true''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"date","mandatory":false,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_past":"true","date_today":true,"date_in_future":true}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused date missing date_in_past','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"date","mandatory":false,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_today":true,"date_in_future":true}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused date flag date_today None','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"date","mandatory":false,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_past":true,"date_today":null,"date_in_future":true}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused date flag date_today ''true''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"date","mandatory":false,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_past":true,"date_today":"true","date_in_future":true}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused date missing date_today','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"date","mandatory":false,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_past":true,"date_in_future":true}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused date flag date_in_future None','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"date","mandatory":false,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_past":true,"date_today":true,"date_in_future":null}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused date flag date_in_future ''true''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"date","mandatory":false,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_past":true,"date_today":true,"date_in_future":"true"}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused date missing date_in_future','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"date","mandatory":false,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_past":true,"date_today":true}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused date no relative category','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"date","mandatory":false,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_past":false,"date_today":false,"date_in_future":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused date reversed range','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"date","mandatory":false,"min":"2025-01-01","max":"2024-01-01","language_dependent":false,"date_in_past":true,"date_today":true,"date_in_future":true}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('menu-radio accepts exact option','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-radio","mandatory":false,"min":1,"max":1,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"Alpha"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{}'::JSONB),
('menu-radio rejects ''alpha''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-radio","mandatory":false,"min":1,"max":1,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"alpha"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('menu-radio rejects '' Alpha''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-radio","mandatory":false,"min":1,"max":1,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":" Alpha"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('menu-radio rejects ''Alpha ''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-radio","mandatory":false,"min":1,"max":1,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"Alpha "}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('menu-radio rejects ''["Alpha"]''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-radio","mandatory":false,"min":1,"max":1,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"[\"Alpha\"]"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('menu-radio rejects ''''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-radio","mandatory":false,"min":1,"max":1,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":""}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('menu-radio optional min1 permits omission','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-radio","mandatory":false,"min":1,"max":1,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{}'::JSONB),
('unused menu-radio {''options'': []}','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-radio","mandatory":false,"min":1,"max":1,"language_dependent":false,"options":[]}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused menu-radio {''options'': [''Alpha'', ''Alpha'']}','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-radio","mandatory":false,"min":1,"max":1,"language_dependent":false,"options":["Alpha","Alpha"]}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused menu-radio {''options'': ['''']}','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-radio","mandatory":false,"min":1,"max":1,"language_dependent":false,"options":[""]}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused menu-radio {''options'': [7]}','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-radio","mandatory":false,"min":1,"max":1,"language_dependent":false,"options":[7]}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused menu-radio {''options'': None}','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-radio","mandatory":false,"min":1,"max":1,"language_dependent":false,"options":null}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused menu-radio {''min'': 2}','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-radio","mandatory":false,"min":2,"max":1,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused menu-radio {''max'': 2}','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-radio","mandatory":false,"min":1,"max":2,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused menu-radio {''min'': 0.1}','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-radio","mandatory":false,"min":0.1,"max":1,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused menu-radio {''max'': None}','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-radio","mandatory":false,"min":1,"max":null,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused menu-radio missing options','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-radio","mandatory":false,"min":1,"max":1,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('read-only accepts exact option','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"read-only","mandatory":false,"min":1,"max":1,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"Alpha"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{}'::JSONB),
('read-only rejects ''alpha''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"read-only","mandatory":false,"min":1,"max":1,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"alpha"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('read-only rejects '' Alpha''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"read-only","mandatory":false,"min":1,"max":1,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":" Alpha"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('read-only rejects ''Alpha ''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"read-only","mandatory":false,"min":1,"max":1,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"Alpha "}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('read-only rejects ''["Alpha"]''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"read-only","mandatory":false,"min":1,"max":1,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"[\"Alpha\"]"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('read-only rejects ''''','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"read-only","mandatory":false,"min":1,"max":1,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":""}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('read-only optional min1 permits omission','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"read-only","mandatory":false,"min":1,"max":1,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{}'::JSONB),
('unused read-only {''options'': []}','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"read-only","mandatory":false,"min":1,"max":1,"language_dependent":false,"options":[]}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused read-only {''options'': [''Alpha'', ''Alpha'']}','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"read-only","mandatory":false,"min":1,"max":1,"language_dependent":false,"options":["Alpha","Alpha"]}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused read-only {''options'': ['''']}','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"read-only","mandatory":false,"min":1,"max":1,"language_dependent":false,"options":[""]}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused read-only {''options'': [7]}','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"read-only","mandatory":false,"min":1,"max":1,"language_dependent":false,"options":[7]}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused read-only {''options'': None}','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"read-only","mandatory":false,"min":1,"max":1,"language_dependent":false,"options":null}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused read-only {''min'': 2}','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"read-only","mandatory":false,"min":2,"max":1,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused read-only {''max'': 2}','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"read-only","mandatory":false,"min":1,"max":2,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused read-only {''min'': 0.1}','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"read-only","mandatory":false,"min":0.1,"max":1,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused read-only {''max'': None}','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"read-only","mandatory":false,"min":1,"max":null,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused read-only missing options','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"read-only","mandatory":false,"min":1,"max":1,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('checkbox valid []','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-checkbox","mandatory":false,"min":0,"max":2,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"[]"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{}'::JSONB),
('checkbox valid ["Alpha"]','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-checkbox","mandatory":false,"min":0,"max":2,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"[\"Alpha\"]"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{}'::JSONB),
('checkbox valid ["Beta","Alpha"]','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-checkbox","mandatory":false,"min":0,"max":2,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"[\"Beta\",\"Alpha\"]"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{}'::JSONB),
('checkbox invalid null','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-checkbox","mandatory":false,"min":0,"max":2,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"null"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('checkbox invalid {}','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-checkbox","mandatory":false,"min":0,"max":2,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"{}"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('checkbox invalid "Alpha"','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-checkbox","mandatory":false,"min":0,"max":2,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"\"Alpha\""}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('checkbox invalid [null]','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-checkbox","mandatory":false,"min":0,"max":2,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"[null]"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('checkbox invalid [7]','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-checkbox","mandatory":false,"min":0,"max":2,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"[7]"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('checkbox invalid [true]','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-checkbox","mandatory":false,"min":0,"max":2,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"[true]"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('checkbox invalid [{}]','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-checkbox","mandatory":false,"min":0,"max":2,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"[{}]"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('checkbox invalid ["Unknown"]','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-checkbox","mandatory":false,"min":0,"max":2,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"[\"Unknown\"]"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('checkbox invalid ["alpha"]','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-checkbox","mandatory":false,"min":0,"max":2,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"[\"alpha\"]"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('checkbox invalid ["Alpha","Alpha"]','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-checkbox","mandatory":false,"min":0,"max":2,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"[\"Alpha\",\"Alpha\"]"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('checkbox invalid ["Alpha","Alph\u0061"]','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-checkbox","mandatory":false,"min":0,"max":2,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"[\"Alpha\",\"Alph\\u0061\"]"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('checkbox malformed string parses natively','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-checkbox","mandatory":false,"min":0,"max":2,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"[}"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','22P02','{}'::JSONB),
('checkbox supplied empty selection minimum','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-checkbox","mandatory":false,"min":1,"max":2,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"[]"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused checkbox {''min'': -1}','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-checkbox","mandatory":false,"min":-1,"max":2,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused checkbox {''max'': 3}','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-checkbox","mandatory":false,"min":0,"max":3,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused checkbox {''min'': 2, ''max'': 1}','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-checkbox","mandatory":false,"min":2,"max":1,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused checkbox {''min'': 0.1}','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-checkbox","mandatory":false,"min":0.1,"max":2,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused checkbox {''options'': []}','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-checkbox","mandatory":false,"min":0,"max":2,"language_dependent":false,"options":[]}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused checkbox {''options'': [''Alpha'', ''Alpha'']}','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-checkbox","mandatory":false,"min":0,"max":2,"language_dependent":false,"options":["Alpha","Alpha"]}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused checkbox {''options'': ['''']}','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-checkbox","mandatory":false,"min":0,"max":2,"language_dependent":false,"options":[""]}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused checkbox {''options'': [None]}','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-checkbox","mandatory":false,"min":0,"max":2,"language_dependent":false,"options":[null]}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('option whitespace is exact and permitted','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Extra","type":"menu-radio","mandatory":false,"min":1,"max":1,"language_dependent":false,"options":["   "]}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"   "}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{}'::JSONB),
('named binding incompatible even omitted Amount','OT46G','[{"name":"Amount","type":"text-60","mandatory":false,"min":0,"max":60,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('named binding incompatible even omitted Arrears','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Arrears","type":"text-60","mandatory":false,"min":0,"max":60,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('named binding incompatible even omitted Beneficiary','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Beneficiary","type":"text-1000","mandatory":false,"min":0,"max":1000,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('named binding incompatible even omitted ChildDOB','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"ChildDOB","type":"text-60","mandatory":false,"min":0,"max":60,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('named binding incompatible even omitted Expiry','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Expiry","type":"text-60","mandatory":false,"min":0,"max":60,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('named binding incompatible even omitted Education','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Education","type":"text-60","mandatory":false,"min":0,"max":60,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('named binding incompatible even omitted Frequency','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Frequency","type":"text-60","mandatory":false,"min":0,"max":60,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('Education optional absent remains NULL','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Education","type":"menu-checkbox","mandatory":false,"min":0,"max":1,"language_dependent":false,"options":["Additional terms affect order expiry"]}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{}'::JSONB),
('Education explicit empty is FALSE','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Education","type":"menu-checkbox","mandatory":false,"min":0,"max":1,"language_dependent":false,"options":["Additional terms affect order expiry"]}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Education","response":"[]"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{"expiry_terms":false}'::JSONB),
('Education explicit singleton is TRUE','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Education","type":"menu-checkbox","mandatory":false,"min":0,"max":1,"language_dependent":false,"options":["Additional terms affect order expiry"]}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Education","response":"[\"Additional terms affect order expiry\"]"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{"expiry_terms":true}'::JSONB),
('Education mandatory zero count permits explicit empty','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Education","type":"menu-checkbox","mandatory":true,"min":0,"max":1,"language_dependent":false,"options":["Additional terms affect order expiry"]}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Education","response":"[]"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{"expiry_terms":false}'::JSONB),
('unused Education incompatible options','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Education","type":"menu-checkbox","mandatory":false,"min":0,"max":1,"language_dependent":false,"options":["Different"]}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('Frequency actual enum subset accepts exact account period','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Frequency","type":"read-only","mandatory":false,"min":1,"max":1,"language_dependent":false,"options":["Weekly"]}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Frequency","response":"Weekly"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{}'::JSONB),
('Frequency option differs from account','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Frequency","type":"read-only","mandatory":false,"min":1,"max":1,"language_dependent":false,"options":["Monthly"]}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Frequency","response":"Monthly"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('Frequency mandatory needs explicit response','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Frequency","type":"read-only","mandatory":true,"min":1,"max":1,"language_dependent":false,"options":["Weekly"]}]'::JSON,'[{"parameter_name":"Amount","response":"12.30"}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('unused Frequency options outside actual enum','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Frequency","type":"read-only","mandatory":false,"min":1,"max":1,"language_dependent":false,"options":["Weekly","Daily"]}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0001','{}'::JSONB),
('Result whitespace identity is not trimmed',' ','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0002','{}'::JSONB),
('Result case identity is exact','ot46g','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name','P0002','{}'::JSONB),
('Unicode submitters preserved independently','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON,'[ { "parameter_name" : "Amount", "response" : "00012.30" } ]',NULL,FALSE,-864601,-864602,'  Café  ','  Synthetic 😀  ',NULL,'{}'::JSONB),
('all supported generic and named mappings retain complete escaped array','OT46G','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},{"name":"Arrears","type":"decimal-2dp","mandatory":false,"min":-100,"max":100,"language_dependent":false},{"name":"Beneficiary","type":"text-60","mandatory":false,"min":0,"max":60,"language_dependent":false},{"name":"ChildDOB","type":"date","mandatory":false,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_past":true,"date_today":true,"date_in_future":true},{"name":"Expiry","type":"date","mandatory":false,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_past":true,"date_today":true,"date_in_future":true},{"name":"Education","type":"menu-checkbox","mandatory":false,"min":0,"max":1,"language_dependent":false,"options":["Additional terms affect order expiry"]},{"name":"Frequency","type":"read-only","mandatory":false,"min":1,"max":1,"language_dependent":false,"options":["Weekly"]},{"name":"Extra","type":"text-1000","mandatory":false,"min":0,"max":1000,"language_dependent":false},{"name":"Choice","type":"menu-radio","mandatory":false,"min":1,"max":1,"language_dependent":false,"options":["Alpha","Beta"]}]'::JSON,'[{"parameter_name":"Choice","response":"Alpha"},{"parameter_name":"Amount","response":"00012.30"},{"parameter_name":"Arrears","response":"-3.20"},{"parameter_name":"Beneficiary","response":"  Caf\u00e9  "},{"parameter_name":"ChildDOB","response":"2012-02-29"},{"parameter_name":"Expiry","response":"2030-12-31"},{"parameter_name":"Education","response":"[\"Additional terms affect order expiry\"]"},{"parameter_name":"Frequency","response":"Weekly"},{"parameter_name":"Extra","response":"  00007  "}]',NULL,FALSE,-864601,-864602,'Synthetic author','Synthetic name',NULL,'{"arrears_amount":-3.2,"child_name":"  Café  ","child_birth_date":"2012-02-29T00:00:00","expiry_date":"2030-12-31T00:00:00","expiry_terms":true}'::JSONB);


-- Character widths count decoded PostgreSQL characters, including multibyte text.
INSERT INTO ot_cases
SELECT 'author alone may be SQL NULL',result_id,metadata,responses,payload_override,sql_null,
 respondent,creditor,NULL,author_name,expected_code,expected_patch
FROM ot_cases WHERE label='generic amount retains raw spaces and leading zeros';
INSERT INTO ot_cases
SELECT 'author name alone may be SQL NULL',result_id,metadata,responses,payload_override,sql_null,
 respondent,creditor,author,NULL,expected_code,expected_patch
FROM ot_cases WHERE label='generic amount retains raw spaces and leading zeros';
INSERT INTO ot_cases
SELECT 'submitter widths accept exact multibyte character limits',result_id,metadata,responses,payload_override,sql_null,
 respondent,creditor,REPEAT('é',20),REPEAT('😀',100),expected_code,expected_patch
FROM ot_cases WHERE label='generic amount retains raw spaces and leading zeros';
INSERT INTO ot_cases
SELECT 'text60 exact multibyte character capacity',result_id,metadata,
 JSON_BUILD_ARRAY(JSON_BUILD_OBJECT('parameter_name','Amount','response','12.30'),
 JSON_BUILD_OBJECT('parameter_name','Extra','response',REPEAT('é',60)))::TEXT,
 payload_override,sql_null,respondent,creditor,author,author_name,expected_code,expected_patch
FROM ot_cases WHERE label='text-60 accepts maximum';
INSERT INTO ot_cases
SELECT 'text1000 exact multibyte character capacity',result_id,metadata,
 JSON_BUILD_ARRAY(JSON_BUILD_OBJECT('parameter_name','Amount','response','12.30'),
 JSON_BUILD_OBJECT('parameter_name','Extra','response',REPEAT('😀',1000)))::TEXT,
 payload_override,sql_null,respondent,creditor,author,author_name,expected_code,expected_patch
FROM ot_cases WHERE label='text-1000 accepts maximum';
INSERT INTO ot_cases
SELECT 'generic parameter exact fifty character identity',result_id,
 JSONB_SET(metadata::JSONB,'{1,name}',TO_JSONB(REPEAT('G',50)))::JSON,
 JSON_BUILD_ARRAY(JSON_BUILD_OBJECT('parameter_name','Amount','response','12.30'),
 JSON_BUILD_OBJECT('parameter_name',REPEAT('G',50),'response','valid'))::TEXT,
 payload_override,sql_null,respondent,creditor,author,author_name,expected_code,expected_patch
FROM ot_cases WHERE label='text-60 accepts maximum';
INSERT INTO ot_cases
SELECT 'date outside absolute maximum',result_id,metadata,
 '[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Extra","response":"2101-01-01"}]',
 payload_override,sql_null,respondent,creditor,author,author_name,'P0001',expected_patch
FROM ot_cases WHERE label='date valid 2024-02-29';
INSERT INTO ot_cases
SELECT 'unused date numeric bound is not coerced',result_id,
 JSONB_SET(metadata::JSONB,'{1,min}','1900'::JSONB)::JSON,
 '[{"parameter_name":"Amount","response":"12.30"}]',
 payload_override,sql_null,respondent,creditor,author,author_name,'P0001',expected_patch
FROM ot_cases WHERE label='date valid 2024-02-29';
INSERT INTO ot_cases
SELECT 'unused date alternate bound spelling rejected',result_id,
 JSONB_SET(metadata::JSONB,'{1,min}','"1900/01/01"'::JSONB)::JSON,
 '[{"parameter_name":"Amount","response":"12.30"}]',
 payload_override,sql_null,respondent,creditor,author,author_name,'P0001',expected_patch
FROM ot_cases WHERE label='date valid 2024-02-29';
INSERT INTO ot_cases
SELECT 'unused date impossible bound retains native calendar error',result_id,
 JSONB_SET(metadata::JSONB,'{1,min}','"2023-02-29"'::JSONB)::JSON,
 '[{"parameter_name":"Amount","response":"12.30"}]',
 payload_override,sql_null,respondent,creditor,author,author_name,'22008',expected_patch
FROM ot_cases WHERE label='date valid 2024-02-29';

-- -----------------------------------------------------------------------------
-- Scenario: Real calls obey exact insertion, raw-document and rejection boundaries.
-- Setup: Each independent case changes one contract fact; all other required values are valid.
-- Expected: Success adds one exact term; rejection preserves rows and pre-insert sequence state.
-- -----------------------------------------------------------------------------
CREATE TEMP TABLE ot_observed(label TEXT PRIMARY KEY,observation JSONB,expected_typed JSONB);
DO $cases$
DECLARE c RECORD; payload TEXT; observed JSONB; expected JSONB;
BEGIN
 FOR c IN SELECT * FROM ot_cases ORDER BY label LOOP
  UPDATE public.results SET result_parameters=c.metadata WHERE result_id='OT46G';
  payload:=CASE WHEN c.sql_null THEN NULL WHEN c.payload_override IS NOT NULL THEN c.payload_override
   ELSE '{"result_id":'||TO_JSON(c.result_id)::TEXT||',"result_responses":'||c.responses||'}' END;
  observed:=pg_temp.ot_call(payload,c.respondent,c.creditor,c.author,c.author_name);
  expected:=JSONB_BUILD_OBJECT('respondent_account_id',c.respondent,'creditor_account_id',c.creditor,
   'result_id',c.result_id,'posted_date',pg_catalog.TRANSACTION_TIMESTAMP() AT TIME ZONE 'UTC',
   'posted_by',c.author,'posted_by_name',c.author_name,'original_posted_date',NULL,
   'imposed_date',TIMESTAMP '2024-02-29 12:13:14.456789','imposed_amount',12.30,
   'arrears_amount',NULL,'completed',FALSE,'child_name',NULL,'child_birth_date',NULL,
   'expiry_date',NULL,'expiry_terms',NULL,'remitted_amount',NULL)||c.expected_patch;
  INSERT INTO ot_observed VALUES(c.label,observed,expected);
 END LOOP;
END;
$cases$;
SELECT is(o.observation->>'code',c.expected_code,c.label||': actual SQLSTATE')
FROM ot_cases c JOIN ot_observed o USING(label) ORDER BY label;
SELECT ok(CASE WHEN c.expected_code IS NULL THEN o.observation->>'message' IS NULL
 WHEN c.expected_code IN ('P0001','22001') THEN COALESCE(o.observation->>'message' LIKE 'p_insert_order_terms:%'
  AND POSITION('SYNTHETIC_PAYLOAD_MARKER_46' IN o.observation->>'message')=0,FALSE)
 WHEN c.expected_code='P0002' THEN o.observation->>'message'='query returned no rows'
 ELSE o.observation->>'code'=c.expected_code END,c.label||': safe deliberate or unchanged native diagnostic')
FROM ot_cases c JOIN ot_observed o USING(label) ORDER BY label;
SELECT is((o.observation->>'new_count')::INTEGER,CASE WHEN c.expected_code IS NULL THEN 1 ELSE 0 END,
 c.label||': exact inserted-row delta') FROM ot_cases c JOIN ot_observed o USING(label) ORDER BY label;
SELECT ok(CASE WHEN c.expected_code IS NULL THEN o.observation->'typed'=o.expected_typed
 AND o.observation->>'raw'=c.responses ELSE (o.observation->>'scope_unchanged')::BOOLEAN END,
 c.label||': exact original columns and raw responses or complete failure preservation')
FROM ot_cases c JOIN ot_observed o USING(label) ORDER BY label;
SELECT ok(CASE WHEN c.expected_code IS NULL THEN (o.observation->>'scope_unchanged')::BOOLEAN
 ELSE (o.observation->>'sequence_unchanged')::BOOLEAN END,c.label||': unrelated scope or pre-insert sequence preserved')
FROM ot_cases c JOIN ot_observed o USING(label) ORDER BY label;


-- -----------------------------------------------------------------------------
-- Scenario: One unchanged installed routine binds native, fixed and cached clocks.
-- Setup: A guarded savepoint owns the clock schema, literal instants and counter.
-- Expected: One capture per entered CALL; UTC posting and London relative dates agree.
-- -----------------------------------------------------------------------------
CREATE TEMP TABLE ot_routine_before AS
SELECT oid,PG_GET_FUNCTIONDEF(oid) AS definition,proconfig,proowner,proacl,prosecdef
FROM pg_proc WHERE oid=(SELECT oid FROM ot_installed);
CREATE TEMP TABLE ot_clock_checks(label TEXT PRIMARY KEY,pass BOOLEAN);
CREATE FUNCTION pg_temp.ot_clock_check(label TEXT,pass BOOLEAN) RETURNS VOID LANGUAGE SQL AS $check$
 INSERT INTO pg_temp.ot_clock_checks VALUES(label,pass);
$check$;
CREATE FUNCTION pg_temp.ot_clock_payload(day DATE) RETURNS TEXT LANGUAGE SQL IMMUTABLE AS $payload$
 SELECT JSON_BUILD_OBJECT('result_id','OT46G','result_responses',JSON_BUILD_ARRAY(
 JSON_BUILD_OBJECT('parameter_name','Amount','response','12.30'),
 JSON_BUILD_OBJECT('parameter_name','Calendar','response',pg_catalog.TO_CHAR(day,'YYYY-MM-DD'))))::TEXT;
$payload$;
UPDATE public.results SET result_parameters='[
 {"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},
 {"name":"Calendar","type":"date","mandatory":true,"min":"1900-01-01","max":"2100-12-31",
 "language_dependent":false,"date_in_past":false,"date_today":true,"date_in_future":false}]'::JSON
WHERE result_id='OT46G';
SET LOCAL search_path=pg_catalog,public;
SELECT pg_catalog.TRANSACTION_TIMESTAMP() AS instant,CURRENT_SETTING('search_path') AS path,
 CURRENT_SETTING('TimeZone') AS zone,CURRENT_SETTING('DateStyle') AS date_style \gset ot_native_
CREATE TEMP TABLE ot_native_warm AS SELECT pg_temp.ot_call(pg_temp.ot_clock_payload(
 (pg_catalog.TRANSACTION_TIMESTAMP() AT TIME ZONE 'Europe/London')::DATE),
 -864601,-864602,'Synthetic author','Synthetic name') AS observation;
SELECT pg_temp.ot_clock_check('warm native call succeeds',observation->>'code' IS NULL),
 pg_temp.ot_clock_check('warm native call inserts exactly one row',(observation->>'new_count')::INTEGER=1),
 pg_temp.ot_clock_check('warm native call posts exact transaction-start UTC',
 (observation->'typed'->>'posted_date')::TIMESTAMP=pg_catalog.TRANSACTION_TIMESTAMP() AT TIME ZONE 'UTC'),
 pg_temp.ot_clock_check('warm native call preserves unrelated scope',(observation->>'scope_unchanged')::BOOLEAN)
FROM ot_native_warm;
SAVEPOINT ot_clock_scope;
DO $clock_guard$
BEGIN
 IF CURRENT_DATABASE()<>'opal_maintenance_db_unit_test' OR CURRENT_USER<>'postgres'
 OR TO_REGNAMESPACE('opal_po10646_clock') IS NOT NULL THEN
  RAISE EXCEPTION 'Order Terms clock fixture requires an unclaimed disposable schema';
 END IF;
END;
$clock_guard$;
CREATE SCHEMA opal_po10646_clock AUTHORIZATION postgres;
CREATE SEQUENCE opal_po10646_clock.capture_count START 1;
CREATE TABLE opal_po10646_clock.state(singleton BOOLEAN PRIMARY KEY CHECK(singleton),instant TIMESTAMPTZ NOT NULL);
INSERT INTO opal_po10646_clock.state VALUES(TRUE,TIMESTAMPTZ '2027-07-15 23:30:45.123456+00');
CREATE FUNCTION opal_po10646_clock.transaction_timestamp() RETURNS TIMESTAMPTZ
LANGUAGE plpgsql VOLATILE AS $clock$
DECLARE instant_value TIMESTAMPTZ;
BEGIN
 PERFORM pg_catalog.NEXTVAL('opal_po10646_clock.capture_count'::REGCLASS);
 SELECT instant INTO STRICT instant_value FROM opal_po10646_clock.state WHERE singleton;
 RETURN instant_value;
END;
$clock$;
SELECT pg_temp.ot_clock_check('clock schema is owned by the disposable test role',
 (SELECT nspowner=(SELECT oid FROM pg_roles WHERE rolname=CURRENT_USER)
 FROM pg_namespace WHERE nspname='opal_po10646_clock'));
CREATE TEMP TABLE ot_clock_vectors(label TEXT PRIMARY KEY,instant TIMESTAMPTZ,london DATE,posted TIMESTAMP);
INSERT INTO ot_clock_vectors VALUES
 ('summer UTC and London have different dates',TIMESTAMPTZ '2027-07-15 23:30:45.123456+00',DATE '2027-07-16',TIMESTAMP '2027-07-15 23:30:45.123456'),
 ('winter London uses UTC date',TIMESTAMPTZ '2027-01-15 23:30:45.234567+00',DATE '2027-01-15',TIMESTAMP '2027-01-15 23:30:45.234567'),
 ('spring before transition',TIMESTAMPTZ '2027-03-28 00:59:59.345678+00',DATE '2027-03-28',TIMESTAMP '2027-03-28 00:59:59.345678'),
 ('spring after transition',TIMESTAMPTZ '2027-03-28 01:00:00.456789+00',DATE '2027-03-28',TIMESTAMP '2027-03-28 01:00:00.456789'),
 ('autumn first local hour',TIMESTAMPTZ '2027-10-31 00:30:00.567891+00',DATE '2027-10-31',TIMESTAMP '2027-10-31 00:30:00.567891'),
 ('autumn repeated local hour',TIMESTAMPTZ '2027-10-31 01:30:00.678912+00',DATE '2027-10-31',TIMESTAMP '2027-10-31 01:30:00.678912');
SET LOCAL search_path=opal_po10646_clock,pg_catalog,public;
SET LOCAL TIME ZONE 'Pacific/Honolulu';
SET LOCAL DateStyle='SQL, DMY';
DO $clock_calls$
DECLARE c RECORD; offset_days INTEGER; before_count BIGINT; after_count BIGINT; observation JSONB;
 label TEXT; expected_code TEXT; repeat_ids BIGINT[]:=ARRAY[]::BIGINT[]; iteration INTEGER;
BEGIN
 FOR c IN SELECT v.* FROM pg_temp.ot_clock_vectors v ORDER BY v.label LOOP
  UPDATE opal_po10646_clock.state SET instant=c.instant;
  FOR offset_days IN -1..1 LOOP
   label:=c.label||' relative day '||offset_days;
   SELECT CASE WHEN is_called THEN last_value ELSE 0 END INTO before_count FROM opal_po10646_clock.capture_count;
   observation:=pg_temp.ot_call(pg_temp.ot_clock_payload(c.london+offset_days),
    -864601,-864602,'Synthetic author','Synthetic name');
   SELECT CASE WHEN is_called THEN last_value ELSE 0 END INTO after_count FROM opal_po10646_clock.capture_count;
   expected_code:=CASE WHEN offset_days=0 THEN NULL ELSE 'P0001' END;
   PERFORM pg_temp.ot_clock_check(label||': exactly one captured instant',after_count-before_count=1);
   PERFORM pg_temp.ot_clock_check(label||': literal London relative outcome',
    observation->>'code' IS NOT DISTINCT FROM expected_code);
   PERFORM pg_temp.ot_clock_check(label||': exact row effect and complete unrelated scope',
    (observation->>'new_count')::INTEGER=CASE WHEN offset_days=0 THEN 1 ELSE 0 END
    AND (observation->>'scope_unchanged')::BOOLEAN);
   PERFORM pg_temp.ot_clock_check(label||': exact fractional UTC posting or no ID allocation',
    CASE WHEN offset_days=0 THEN
     (observation->'typed'->>'posted_date')::TIMESTAMP=c.posted
     AND (observation->'typed'->>'imposed_date')::TIMESTAMP=TIMESTAMP '2024-02-29 12:13:14.456789'
    ELSE (observation->>'sequence_unchanged')::BOOLEAN END);
  END LOOP;
 END LOOP;
 -- Switching to native binding must invalidate the cached fixed-clock expression.
 PERFORM SET_CONFIG('search_path','pg_catalog,public',TRUE);
 FOR iteration IN 1..2 LOOP
  PERFORM SET_CONFIG('TimeZone',CASE iteration WHEN 1 THEN 'Pacific/Kiritimati' ELSE 'Pacific/Honolulu' END,TRUE);
  PERFORM SET_CONFIG('DateStyle',CASE iteration WHEN 1 THEN 'SQL, DMY' ELSE 'ISO, MDY' END,TRUE);
  SELECT CASE WHEN is_called THEN last_value ELSE 0 END INTO before_count FROM opal_po10646_clock.capture_count;
  observation:=pg_temp.ot_call(pg_temp.ot_clock_payload(
   (pg_catalog.TRANSACTION_TIMESTAMP() AT TIME ZONE 'Europe/London')::DATE),
   -864601,-864602,'Synthetic author','Synthetic name');
  SELECT CASE WHEN is_called THEN last_value ELSE 0 END INTO after_count FROM opal_po10646_clock.capture_count;
  label:='native cached transition '||iteration;
  PERFORM pg_temp.ot_clock_check(label||': fixed counter is untouched',after_count=before_count);
  PERFORM pg_temp.ot_clock_check(label||': native London date succeeds',observation->>'code' IS NULL);
  PERFORM pg_temp.ot_clock_check(label||': native transaction lifetime ignores caller zone and DateStyle',
   (observation->'typed'->>'posted_date')::TIMESTAMP=pg_catalog.TRANSACTION_TIMESTAMP() AT TIME ZONE 'UTC');
  PERFORM pg_temp.ot_clock_check(label||': one row with unrelated scope preserved',
   (observation->>'new_count')::INTEGER=1 AND (observation->>'scope_unchanged')::BOOLEAN);
 END LOOP;
 PERFORM SET_CONFIG('search_path','opal_po10646_clock,pg_catalog,public',TRUE);
 UPDATE opal_po10646_clock.state SET instant=TIMESTAMPTZ '2027-07-15 23:30:45.123456+00';
 FOR iteration IN 1..2 LOOP
  SELECT CASE WHEN is_called THEN last_value ELSE 0 END INTO before_count FROM opal_po10646_clock.capture_count;
  observation:=pg_temp.ot_call(pg_temp.ot_clock_payload(DATE '2027-07-16'),
   -864601,-864602,'Synthetic author','Synthetic name');
  SELECT CASE WHEN is_called THEN last_value ELSE 0 END INTO after_count FROM opal_po10646_clock.capture_count;
  label:='fixed cached repeat '||iteration;
  repeat_ids:=ARRAY_APPEND(repeat_ids,(observation->>'id')::BIGINT);
  PERFORM pg_temp.ot_clock_check(label||': fixed binding captures once again',after_count-before_count=1);
  PERFORM pg_temp.ot_clock_check(label||': unchanged reference date succeeds',observation->>'code' IS NULL);
  PERFORM pg_temp.ot_clock_check(label||': exact fixed fractional timestamp',
   (observation->'typed'->>'posted_date')::TIMESTAMP=TIMESTAMP '2027-07-15 23:30:45.123456');
  PERFORM pg_temp.ot_clock_check(label||': one row with unrelated scope preserved',
   (observation->>'new_count')::INTEGER=1 AND (observation->>'scope_unchanged')::BOOLEAN);
 END LOOP;
 PERFORM pg_temp.ot_clock_check('constant fixed reference still appends distinct generated IDs',
  repeat_ids[1] IS NOT NULL AND repeat_ids[2] IS NOT NULL AND repeat_ids[1]<>repeat_ids[2]);
 SELECT CASE WHEN is_called THEN last_value ELSE 0 END INTO before_count FROM opal_po10646_clock.capture_count;
 observation:=pg_temp.ot_call(pg_temp.ot_clock_payload(DATE '2027-07-16'),NULL,-864602,'Synthetic author','Synthetic name');
 SELECT CASE WHEN is_called THEN last_value ELSE 0 END INTO after_count FROM opal_po10646_clock.capture_count;
 PERFORM pg_temp.ot_clock_check('entered guard failure still captures exactly once',after_count-before_count=1);
 PERFORM pg_temp.ot_clock_check('entered guard failure propagates P0001',observation->>'code'='P0001');
 PERFORM pg_temp.ot_clock_check('entered guard failure leaves all rows unchanged',
  (observation->>'new_count')::INTEGER=0 AND (observation->>'scope_unchanged')::BOOLEAN);
 PERFORM pg_temp.ot_clock_check('entered guard failure allocates no term ID',(observation->>'sequence_unchanged')::BOOLEAN);
END;
$clock_calls$;
SELECT pg_temp.ot_clock_check('interception changes no installed routine properties',NOT EXISTS(
 SELECT 1 FROM ot_routine_before b LEFT JOIN pg_proc p ON p.oid=b.oid
 WHERE p.oid IS NULL OR ROW(PG_GET_FUNCTIONDEF(p.oid),p.proconfig,p.proowner,p.proacl,p.prosecdef)
 IS DISTINCT FROM ROW(b.definition,b.proconfig,b.proowner,b.proacl,b.prosecdef)));
SELECT JSONB_AGG(JSONB_BUILD_OBJECT('label',label,'pass',pass) ORDER BY label)::TEXT AS observations
FROM ot_clock_checks \gset ot_clock_
ROLLBACK TO SAVEPOINT ot_clock_scope;
RELEASE SAVEPOINT ot_clock_scope;
SELECT is(JSONB_ARRAY_LENGTH(:'ot_clock_observations'::JSONB),99,'all fixed/native clock observations are present');
SELECT ok((entry->>'pass')::BOOLEAN,entry->>'label')
FROM JSONB_ARRAY_ELEMENTS(:'ot_clock_observations'::JSONB) entry;
SELECT ok(TO_REGNAMESPACE('opal_po10646_clock') IS NULL,'clock rollback removes its owned schema');
SELECT ok(TO_REGCLASS('opal_po10646_clock.capture_count') IS NULL
 AND TO_REGCLASS('opal_po10646_clock.state') IS NULL
 AND TO_REGPROCEDURE('opal_po10646_clock.transaction_timestamp()') IS NULL,
 'clock rollback removes counter, state and override function');
SELECT is(CURRENT_SETTING('search_path'),:'ot_native_path','clock rollback restores exact caller search_path');
SELECT is(CURRENT_SETTING('TimeZone'),:'ot_native_zone','clock rollback restores exact caller TimeZone');
SELECT is(CURRENT_SETTING('DateStyle'),:'ot_native_date_style','clock rollback restores exact caller DateStyle');
SELECT ok(NOT EXISTS(SELECT 1 FROM ot_routine_before b LEFT JOIN pg_proc p ON p.oid=b.oid
 WHERE p.oid IS NULL OR ROW(PG_GET_FUNCTIONDEF(p.oid),p.proconfig,p.proowner,p.proacl,p.prosecdef)
 IS DISTINCT FROM ROW(b.definition,b.proconfig,b.proowner,b.proacl,b.prosecdef)),
 'clock rollback restores exact installed identity, definition, owner, ACL and settings');
CREATE TEMP TABLE ot_native_after AS SELECT pg_temp.ot_call(pg_temp.ot_clock_payload(
 (pg_catalog.TRANSACTION_TIMESTAMP() AT TIME ZONE 'Europe/London')::DATE),
 -864601,-864602,'Synthetic author','Synthetic name') AS observation;
SELECT ok(observation->>'code' IS NULL,'native execution succeeds after success and failure fixture rollback') FROM ot_native_after;
SELECT is((observation->>'new_count')::INTEGER,1,'post-cleanup native call inserts exactly one row') FROM ot_native_after;
SELECT is((observation->'typed'->>'posted_date')::TIMESTAMP,pg_catalog.TRANSACTION_TIMESTAMP() AT TIME ZONE 'UTC',
 'post-cleanup native call uses genuine unchanged transaction-start timestamp') FROM ot_native_after;
SELECT ok((observation->>'scope_unchanged')::BOOLEAN,'post-cleanup native call preserves unrelated rows') FROM ot_native_after;



-- -----------------------------------------------------------------------------
-- Scenario: Real insertion failures retain every native diagnostic field.
-- Setup: Isolated triggers/constraints give CALL and direct INSERT the same bad row.
-- Expected: No row survives; native diagnostics/context and the cardinality guard propagate.
-- -----------------------------------------------------------------------------
CREATE FUNCTION pg_temp.ot_diagnostics(value JSONB) RETURNS JSONB LANGUAGE SQL IMMUTABLE AS $diagnostics$
 SELECT JSONB_BUILD_OBJECT('code',value->'code','message',value->'message','detail',value->'detail',
 'hint',value->'hint','schema',value->'schema','table',value->'table','column',value->'column',
 'datatype',value->'datatype','constraint',value->'constraint');
$diagnostics$;
CREATE FUNCTION pg_temp.ot_native_sql(statement TEXT) RETURNS JSONB LANGUAGE plpgsql AS $native$
DECLARE code TEXT; message TEXT; detail TEXT; hint TEXT; schema_name TEXT; table_name TEXT;
 column_name TEXT; data_type TEXT; constraint_name TEXT; context TEXT;
BEGIN
 BEGIN
  EXECUTE statement;
 EXCEPTION WHEN assert_failure THEN
  GET STACKED DIAGNOSTICS code=RETURNED_SQLSTATE,message=MESSAGE_TEXT,detail=PG_EXCEPTION_DETAIL,
   hint=PG_EXCEPTION_HINT,schema_name=SCHEMA_NAME,table_name=TABLE_NAME,column_name=COLUMN_NAME,
   data_type=PG_DATATYPE_NAME,constraint_name=CONSTRAINT_NAME,context=PG_EXCEPTION_CONTEXT;
 WHEN OTHERS THEN
  GET STACKED DIAGNOSTICS code=RETURNED_SQLSTATE,message=MESSAGE_TEXT,detail=PG_EXCEPTION_DETAIL,
   hint=PG_EXCEPTION_HINT,schema_name=SCHEMA_NAME,table_name=TABLE_NAME,column_name=COLUMN_NAME,
   data_type=PG_DATATYPE_NAME,constraint_name=CONSTRAINT_NAME,context=PG_EXCEPTION_CONTEXT;
 END;
 RETURN JSONB_BUILD_OBJECT('code',code,'message',message,'detail',detail,'hint',hint,'schema',schema_name,
  'table',table_name,'column',column_name,'datatype',data_type,'constraint',constraint_name,'context',context);
END;
$native$;
CREATE FUNCTION pg_temp.ot_metadata() RETURNS JSONB LANGUAGE SQL VOLATILE AS $metadata$
 SELECT JSONB_BUILD_OBJECT(
 'routine',(SELECT JSONB_BUILD_ARRAY(p.oid,PG_GET_FUNCTIONDEF(p.oid),p.proowner,p.proacl,p.proconfig,p.prosecdef)
 FROM pg_proc p WHERE p.oid=(SELECT oid FROM pg_temp.ot_installed)),
 'relations',(SELECT JSONB_AGG(JSONB_BUILD_ARRAY(c.oid,c.relowner,c.relacl,c.relrowsecurity,c.relforcerowsecurity) ORDER BY c.oid)
 FROM pg_class c WHERE c.oid IN ('public.order_terms'::REGCLASS,'public.respondent_accounts'::REGCLASS,
 'public.creditor_accounts'::REGCLASS,'public.results'::REGCLASS,'public.draft_casefiles'::REGCLASS,
 'public.notes'::REGCLASS,'public.account_number_index'::REGCLASS,'public.order_terms_id_seq'::REGCLASS)),
 'columns',(SELECT JSONB_AGG(JSONB_BUILD_ARRAY(a.attrelid,a.attnum,a.attname,a.atttypid,a.atttypmod,a.attnotnull,a.attacl,
 PG_GET_EXPR(d.adbin,d.adrelid),COL_DESCRIPTION(a.attrelid,a.attnum)) ORDER BY a.attrelid,a.attnum)
 FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum
 WHERE a.attrelid='public.order_terms'::REGCLASS AND a.attnum>0 AND NOT a.attisdropped),
 'constraints',(SELECT JSONB_AGG(JSONB_BUILD_ARRAY(c.oid,c.conname,c.convalidated,PG_GET_CONSTRAINTDEF(c.oid)) ORDER BY c.oid)
 FROM pg_constraint c WHERE c.conrelid='public.order_terms'::REGCLASS),
 'indexes',(SELECT JSONB_AGG(JSONB_BUILD_ARRAY(i.indexrelid,PG_GET_INDEXDEF(i.indexrelid),i.indisvalid,i.indisready) ORDER BY i.indexrelid)
 FROM pg_index i WHERE i.indrelid='public.order_terms'::REGCLASS),
 'triggers',(SELECT JSONB_AGG(JSONB_BUILD_ARRAY(t.oid,PG_GET_TRIGGERDEF(t.oid),t.tgenabled) ORDER BY t.oid)
 FROM pg_trigger t WHERE t.tgrelid='public.order_terms'::REGCLASS),
 'namespaces',(SELECT JSONB_AGG(JSONB_BUILD_ARRAY(n.oid,n.nspowner,n.nspacl) ORDER BY n.oid)
 FROM pg_namespace n WHERE n.oid IN ('public'::REGNAMESPACE,PG_MY_TEMP_SCHEMA())));
$metadata$;
CREATE TEMP TABLE ot_native_cases(label TEXT PRIMARY KEY,expected_code TEXT,expected_constraint TEXT);
INSERT INTO ot_native_cases VALUES
 ('native foreign key','23503','ot_creditor_account_id_fk'),
 ('native not null','23502',''),
 ('native check','23514','ot46_native_check'),
 ('native unique','23505','order_terms_pk'),
 ('native assertion','P0004',''),
 ('suppressed insert','P0001','');
CREATE TEMP TABLE ot_native_observed(label TEXT PRIMARY KEY,checks JSONB,diagnostics JSONB);
UPDATE public.results SET result_parameters='[
 {"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON
WHERE result_id='OT46G';
DO $insert_controls$
DECLARE c RECORD; observed JSONB; control JSONB; checks JSONB; before_rows JSONB; before_metadata JSONB;
 before_attempts BIGINT; after_attempts BIGINT; trigger_body TEXT;
 payload TEXT:='{"result_id":"OT46G","result_responses":[{"parameter_name":"Amount","response":"12.30"}]}';
 direct_insert TEXT:=$insert$INSERT INTO public.order_terms(
 order_terms_id,respondent_account_id,creditor_account_id,result_id,posted_date,posted_by,posted_by_name,
 original_posted_date,imposed_date,imposed_amount,arrears_amount,completed,child_name,child_birth_date,
 expiry_date,expiry_terms,remitted_amount,result_responses)
 VALUES(-864610,-864601,-864602,'OT46G',pg_catalog.TRANSACTION_TIMESTAMP() AT TIME ZONE 'UTC',
 'Synthetic author','Synthetic name',NULL,TIMESTAMP '2024-02-29 12:13:14.456789',12.30,NULL,FALSE,
 NULL,NULL,NULL,NULL,NULL,'[{"parameter_name":"Amount","response":"12.30"}]'::JSON)$insert$;
BEGIN
 IF EXISTS(SELECT 1 FROM public.order_terms WHERE order_terms_id IN (-864610,-864611))
 OR EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='ot46_native_insert')
 OR EXISTS(SELECT 1 FROM pg_constraint WHERE conname='ot46_native_check')
 OR TO_REGPROCEDURE('pg_temp.ot_native_trigger()') IS NOT NULL
 OR TO_REGCLASS('pg_temp.ot_native_attempts') IS NOT NULL THEN
  RAISE EXCEPTION 'Order Terms native fixture collision';
 END IF;
 FOR c IN SELECT n.* FROM pg_temp.ot_native_cases n ORDER BY n.label LOOP
  before_metadata:=pg_temp.ot_metadata();
  BEGIN
   IF c.label='native unique' THEN EXECUTE direct_insert; END IF;
   before_rows:=pg_temp.ot_scope();
   CREATE TEMP SEQUENCE ot_native_attempts START 1;
   IF c.label='native check' THEN
    ALTER TABLE public.order_terms ADD CONSTRAINT ot46_native_check CHECK(order_terms_id<>-864610 OR imposed_amount<>12.30);
   END IF;
   trigger_body:=CASE c.label
    WHEN 'native foreign key' THEN 'NEW.creditor_account_id:=-864699;'
    WHEN 'native not null' THEN 'NEW.imposed_amount:=NULL;'
    WHEN 'native assertion' THEN $assert$ASSERT FALSE,'Order Terms native assertion control';$assert$
    WHEN 'suppressed insert' THEN 'RETURN NULL;'
    ELSE '' END;
   EXECUTE FORMAT('CREATE FUNCTION pg_temp.ot_native_trigger() RETURNS TRIGGER LANGUAGE plpgsql AS %L',
    'BEGIN PERFORM pg_catalog.NEXTVAL(''pg_temp.ot_native_attempts''::REGCLASS); NEW.order_terms_id:=-864610; '
    ||trigger_body||' RETURN NEW; END;');
   CREATE TRIGGER ot46_native_insert BEFORE INSERT ON public.order_terms
    FOR EACH ROW EXECUTE FUNCTION pg_temp.ot_native_trigger();
   control:=CASE WHEN c.label='suppressed insert' THEN NULL ELSE pg_temp.ot_native_sql(direct_insert) END;
   SELECT CASE WHEN is_called THEN last_value ELSE 0 END INTO before_attempts FROM pg_temp.ot_native_attempts;
   observed:=pg_temp.ot_call(payload,-864601,-864602,'Synthetic author','Synthetic name');
   SELECT CASE WHEN is_called THEN last_value ELSE 0 END INTO after_attempts FROM pg_temp.ot_native_attempts;
   checks:=JSONB_BUILD_ARRAY(
    JSONB_BUILD_OBJECT('label',c.label||': original SQLSTATE','pass',observed->>'code'=c.expected_code),
    JSONB_BUILD_OBJECT('label',c.label||': every native message/detail/hint/object field survives','pass',
     CASE WHEN c.label='suppressed insert' THEN observed->>'message' LIKE 'p_insert_order_terms:%'
      AND observed->>'detail'='' AND observed->>'hint'=''
     ELSE pg_temp.ot_diagnostics(observed)=pg_temp.ot_diagnostics(control) END),
    JSONB_BUILD_OBJECT('label',c.label||': original installed procedure exception context survives','pass',
     POSITION('p_insert_order_terms' IN observed->>'context')>0 AND
     CASE WHEN c.label='native assertion' THEN
      POSITION(SPLIT_PART(control->>'context',E'\n',1) IN observed->>'context')>0
     WHEN c.label='suppressed insert' THEN TRUE
     ELSE POSITION('INSERT INTO public.order_terms' IN observed->>'context')>0 END),
    JSONB_BUILD_OBJECT('label',c.label||': no inserted or unrelated row survives','pass',
     (observed->>'new_count')::INTEGER=0 AND (observed->>'scope_unchanged')::BOOLEAN
      AND pg_temp.ot_scope()=before_rows),
    JSONB_BUILD_OBJECT('label',c.label||': actual CALL reaches exactly one INSERT attempt','pass',
     after_attempts-before_attempts=1),
    JSONB_BUILD_OBJECT('label',c.label||': original applicable constraint or deliberate cardinality','pass',
     observed->>'constraint'=c.expected_constraint
     AND CASE WHEN c.label='native not null' THEN observed->>'column'='imposed_amount'
      WHEN c.label='native assertion' THEN observed->>'message'='Order Terms native assertion control'
      ELSE TRUE END));
   RAISE EXCEPTION SQLSTATE 'ZX646' USING MESSAGE='rollback isolated Order Terms insertion controls';
  EXCEPTION WHEN SQLSTATE 'ZX646' THEN NULL;
  END;
  checks:=checks||JSONB_BUILD_ARRAY(JSONB_BUILD_OBJECT(
   'label',c.label||': rollback restores routine, table metadata and removes trigger/counter',
   'pass',pg_temp.ot_metadata()=before_metadata
    AND TO_REGPROCEDURE('pg_temp.ot_native_trigger()') IS NULL
    AND TO_REGCLASS('pg_temp.ot_native_attempts') IS NULL
    AND NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='ot46_native_insert')));
  INSERT INTO pg_temp.ot_native_observed VALUES(c.label,checks,observed);
 END LOOP;
END;
$insert_controls$;
SELECT ok((entry->>'pass')::BOOLEAN,entry->>'label')
FROM ot_native_observed CROSS JOIN LATERAL JSONB_ARRAY_ELEMENTS(checks) entry ORDER BY label;
SELECT is((SELECT COUNT(*) FROM ot_native_observed),6::BIGINT,'all six real insertion control cases execute');
SELECT is((SELECT SUM(JSONB_ARRAY_LENGTH(checks)) FROM ot_native_observed),42::BIGINT,
 'all 42 insertion-control observations are present');

-- -----------------------------------------------------------------------------
-- Scenario: Native conversion diagnostics are not reconstructed or translated.
-- Setup: Compare direct native casts with the same invalid value in a real CALL.
-- Expected: All native fields survive; no term or ID is allocated before insertion.
-- -----------------------------------------------------------------------------
CREATE TEMP TABLE ot_conversion_cases(label TEXT PRIMARY KEY,metadata JSON,responses TEXT,statement TEXT,expected_code TEXT);
INSERT INTO ot_conversion_cases VALUES
 ('native impossible calendar','[
 {"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},
 {"name":"Calendar","type":"date","mandatory":true,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,
 "date_in_past":true,"date_today":true,"date_in_future":true}]'::JSON,
 '[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Calendar","response":"2023-02-29"}]',
 $query$SELECT '2023-02-29'::DATE$query$,'22008'),
 ('native malformed checkbox JSON','[
 {"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false},
 {"name":"Choice","type":"menu-checkbox","mandatory":true,"min":0,"max":1,"language_dependent":false,"options":["Alpha"]}]'::JSON,
 '[{"parameter_name":"Amount","response":"12.30"},{"parameter_name":"Choice","response":"[}"}]',
 $query$SELECT '[}'::JSON$query$,'22P02'),
 ('native numeric representability','[
 {"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-1e1000,"max":1e1000,"language_dependent":false}]'::JSON,
 JSON_BUILD_ARRAY(JSON_BUILD_OBJECT('parameter_name','Amount','response',REPEAT('9',131073)))::TEXT,
 $query$SELECT REPEAT('9',131073)::NUMERIC$query$,'22003');
CREATE TEMP TABLE ot_conversion_observed(label TEXT PRIMARY KEY,checks JSONB);
DO $conversion_controls$
DECLARE c RECORD; observed JSONB; control JSONB;
BEGIN
 FOR c IN SELECT n.* FROM pg_temp.ot_conversion_cases n ORDER BY n.label LOOP
  UPDATE public.results SET result_parameters=c.metadata WHERE result_id='OT46G';
  control:=pg_temp.ot_native_sql(c.statement);
  observed:=pg_temp.ot_call('{"result_id":"OT46G","result_responses":'||c.responses||'}',
   -864601,-864602,'Synthetic author','Synthetic name');
  INSERT INTO pg_temp.ot_conversion_observed VALUES(c.label,JSONB_BUILD_ARRAY(
   JSONB_BUILD_OBJECT('label',c.label||': actual native SQLSTATE','pass',observed->>'code'=c.expected_code),
   JSONB_BUILD_OBJECT('label',c.label||': every native diagnostic field matches independent cast',
    'pass',pg_temp.ot_diagnostics(observed)=pg_temp.ot_diagnostics(control)),
   JSONB_BUILD_OBJECT('label',c.label||': original installed routine context survives',
    'pass',POSITION('p_insert_order_terms' IN observed->>'context')>0),
   JSONB_BUILD_OBJECT('label',c.label||': no inserted or unrelated row survives',
    'pass',(observed->>'new_count')::INTEGER=0 AND (observed->>'scope_unchanged')::BOOLEAN),
   JSONB_BUILD_OBJECT('label',c.label||': conversion allocates no term ID',
    'pass',(observed->>'sequence_unchanged')::BOOLEAN)));
 END LOOP;
END;
$conversion_controls$;
SELECT ok((entry->>'pass')::BOOLEAN,entry->>'label')
FROM ot_conversion_observed CROSS JOIN LATERAL JSONB_ARRAY_ELEMENTS(checks) entry ORDER BY label;
SELECT is((SELECT SUM(JSONB_ARRAY_LENGTH(checks)) FROM ot_conversion_observed),15::BIGINT,
 'all three native conversion cases and 15 observations execute');

-- -----------------------------------------------------------------------------
-- Scenario: The invoker retains genuine PostgreSQL INSERT permission failures.
-- Setup: A savepoint owns a NOLOGIN role with SELECT and no term INSERT privilege.
-- Expected: Real CALL preserves native diagnostics; role, grants and settings roll back.
-- -----------------------------------------------------------------------------
UPDATE public.results SET result_parameters='[
 {"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]'::JSON
WHERE result_id='OT46G';
CREATE TEMP TABLE ot_permission_before AS SELECT pg_temp.ot_metadata() AS metadata,CURRENT_USER AS role_name;
CREATE TEMP TABLE ot_permission_checks(checks JSONB);
SAVEPOINT ot_permission_scope;
DO $permission_guard$
BEGIN
 IF CURRENT_DATABASE()<>'opal_maintenance_db_unit_test' OR CURRENT_USER<>'postgres'
 OR EXISTS(SELECT 1 FROM pg_roles WHERE rolname='opal_po10646_insert_denied') THEN
  RAISE EXCEPTION 'Order Terms permission fixture requires an unclaimed disposable role';
 END IF;
END;
$permission_guard$;
CREATE ROLE opal_po10646_insert_denied NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT;
GRANT USAGE ON SCHEMA public TO opal_po10646_insert_denied;
GRANT SELECT ON public.order_terms,public.respondent_accounts,public.creditor_accounts,public.results,
 public.draft_casefiles,public.notes,public.account_number_index TO opal_po10646_insert_denied;
GRANT SELECT,USAGE ON SEQUENCE public.order_terms_id_seq TO opal_po10646_insert_denied;
DO $permission_control$
DECLARE observed JSONB; control JSONB; denied BOOLEAN;
BEGIN
 EXECUTE FORMAT('GRANT USAGE ON SCHEMA %I TO opal_po10646_insert_denied',
  (SELECT nspname FROM pg_namespace WHERE oid=PG_MY_TEMP_SCHEMA()));
 SET LOCAL ROLE opal_po10646_insert_denied;
 denied:=NOT HAS_TABLE_PRIVILEGE(CURRENT_USER,'public.order_terms','INSERT');
 control:=pg_temp.ot_native_sql($insert$INSERT INTO public.order_terms(
 respondent_account_id,creditor_account_id,result_id,posted_date,imposed_date,imposed_amount,completed)
 VALUES(-864601,-864602,'OT46G',TIMESTAMP '2024-01-01',TIMESTAMP '2024-01-01',12.30,FALSE)$insert$);
 observed:=pg_temp.ot_call(
 '{"result_id":"OT46G","result_responses":[{"parameter_name":"Amount","response":"12.30"}]}',
 -864601,-864602,'Synthetic author','Synthetic name');
 RESET ROLE;
 INSERT INTO pg_temp.ot_permission_checks VALUES(JSONB_BUILD_ARRAY(
  JSONB_BUILD_OBJECT('label','permission control has no INSERT privilege','pass',denied),
  JSONB_BUILD_OBJECT('label','permission failure retains native 42501','pass',observed->>'code'='42501'),
  JSONB_BUILD_OBJECT('label','permission failure retains every native diagnostic field',
   'pass',pg_temp.ot_diagnostics(observed)=pg_temp.ot_diagnostics(control)),
  JSONB_BUILD_OBJECT('label','permission failure retains installed routine context',
   'pass',POSITION('p_insert_order_terms' IN observed->>'context')>0),
  JSONB_BUILD_OBJECT('label','permission failure preserves all rows',
   'pass',(observed->>'new_count')::INTEGER=0 AND (observed->>'scope_unchanged')::BOOLEAN),
  JSONB_BUILD_OBJECT('label','permission failure allocates no term ID',
   'pass',(observed->>'sequence_unchanged')::BOOLEAN)));
END;
$permission_control$;
SELECT checks::TEXT AS observations FROM ot_permission_checks \gset ot_permission_
ROLLBACK TO SAVEPOINT ot_permission_scope;
RELEASE SAVEPOINT ot_permission_scope;
SELECT is(JSONB_ARRAY_LENGTH(:'ot_permission_observations'::JSONB),6,'all six permission observations execute');
SELECT ok((entry->>'pass')::BOOLEAN,entry->>'label')
FROM JSONB_ARRAY_ELEMENTS(:'ot_permission_observations'::JSONB) entry;
SELECT ok(NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='opal_po10646_insert_denied'),
 'permission rollback removes the owned test role');
SELECT ok((SELECT pg_temp.ot_metadata()=metadata AND CURRENT_USER=role_name FROM ot_permission_before),
 'permission rollback restores exact grants, namespaces, routine and caller role');

-- -----------------------------------------------------------------------------
-- Scenario: Caller rollback, repeated append, legacy rows and metadata evolution.
-- Setup: Two identical terms share a valid MJ; later metadata edits reject new input.
-- Expected: Earlier captures remain exact, then caller rollback removes all new terms.
-- -----------------------------------------------------------------------------
CREATE TEMP TABLE ot_lifecycle_checks(checks JSONB);
DO $caller_scope$
DECLARE before_rows JSONB; checks JSONB:='[]'::JSONB; first_call JSONB; second_call JSONB; later_call JSONB;
 first_row TEXT; second_row TEXT; legacy_row TEXT; before_name TEXT; first_id BIGINT; second_id BIGINT;
 payload TEXT:='{"result_id":"OT46G","result_responses":[ { "parameter_name" : "Amount", "response" : "00012.30" } ]}';
 normal_metadata JSON:='[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":-100,"max":100,"language_dependent":false}]';
BEGIN
 IF EXISTS(SELECT 1 FROM public.order_terms WHERE order_terms_id=-864611)
 OR EXISTS(SELECT 1 FROM public.creditor_accounts
  WHERE business_unit_id=44 AND account_number='OT-MAJOR' AND creditor_account_id<>-864602) THEN
  RAISE EXCEPTION 'Order Terms caller fixture collision';
 END IF;
 UPDATE public.results SET result_parameters=normal_metadata WHERE result_id='OT46G';
 INSERT INTO public.order_terms(order_terms_id,respondent_account_id,creditor_account_id,result_id,
 posted_date,imposed_date,imposed_amount,completed,result_responses)
 VALUES(-864611,-864601,-864602,'OT46G',TIMESTAMP '2020-01-01 01:02:03.123456',
 TIMESTAMP '2019-02-28 12:13:14.456789',7.30,FALSE,NULL);
 SELECT ROW_TO_JSON(t)::TEXT INTO legacy_row FROM public.order_terms t WHERE order_terms_id=-864611;
 before_rows:=pg_temp.ot_scope();
 SELECT business_unit_name INTO before_name FROM public.business_units WHERE business_unit_id=32080;
 BEGIN
  UPDATE public.business_units SET business_unit_name='Synthetic caller-owned edit' WHERE business_unit_id=32080;
  first_call:=pg_temp.ot_call(payload,-864601,-864602,'Synthetic author','Synthetic name');
  second_call:=pg_temp.ot_call(payload,-864601,-864602,'Synthetic author','Synthetic name');
  first_id:=(first_call->>'id')::BIGINT; second_id:=(second_call->>'id')::BIGINT;
  SELECT ROW_TO_JSON(t)::TEXT INTO first_row FROM public.order_terms t WHERE order_terms_id=first_id;
  SELECT ROW_TO_JSON(t)::TEXT INTO second_row FROM public.order_terms t WHERE order_terms_id=second_id;
  checks:=JSONB_BUILD_ARRAY(
   JSONB_BUILD_OBJECT('label','first repeated CALL succeeds','pass',first_call->>'code' IS NULL),
   JSONB_BUILD_OBJECT('label','second repeated CALL succeeds','pass',second_call->>'code' IS NULL),
   JSONB_BUILD_OBJECT('label','repeated CALLs each append exactly one term',
    'pass',(first_call->>'new_count')::INTEGER=1 AND (second_call->>'new_count')::INTEGER=1),
   JSONB_BUILD_OBJECT('label','repeated CALLs use distinct generated IDs',
    'pass',first_id IS NOT NULL AND second_id IS NOT NULL AND first_id<>second_id),
   JSONB_BUILD_OBJECT('label','repeated CALLs retain identical typed and exact raw values',
    'pass',first_call->'typed'=second_call->'typed' AND first_call->>'raw'=second_call->>'raw'
     AND first_call->>'raw'='[ { "parameter_name" : "Amount", "response" : "00012.30" } ]'),
   JSONB_BUILD_OBJECT('label','repeated terms share the same valid MJ account',
    'pass',first_call->'typed'->>'creditor_account_id'='-864602'
     AND second_call->'typed'->>'creditor_account_id'='-864602'
     AND EXISTS(SELECT 1 FROM public.creditor_accounts c JOIN public.major_creditors m USING(major_creditor_id)
      WHERE c.creditor_account_id=-864602 AND c.creditor_account_type='MJ')),
   JSONB_BUILD_OBJECT('label','both repeated CALLs preserve every unrelated row',
    'pass',(first_call->>'scope_unchanged')::BOOLEAN AND (second_call->>'scope_unchanged')::BOOLEAN),
   JSONB_BUILD_OBJECT('label','repeated CALLs use the same native transaction instant',
    'pass',(first_call->'typed'->>'posted_date')::TIMESTAMP=pg_catalog.TRANSACTION_TIMESTAMP() AT TIME ZONE 'UTC'
     AND first_call->'typed'->'posted_date'=second_call->'typed'->'posted_date'),
   JSONB_BUILD_OBJECT('label','legacy SQL-NULL responses remain unchanged and readable',
    'pass',EXISTS(SELECT 1 FROM public.order_terms t WHERE order_terms_id=-864611
     AND result_responses IS NULL AND ROW_TO_JSON(t)::TEXT=legacy_row)));
  UPDATE public.results SET result_parameters='[
   {"name":"Amount","type":"decimal-2dp","mandatory":true,"min":0,"max":1,"language_dependent":false}]'::JSON
  WHERE result_id='OT46G';
  later_call:=pg_temp.ot_call(payload,-864601,-864602,'Synthetic author','Synthetic name');
  checks:=checks||JSONB_BUILD_ARRAY(
   JSONB_BUILD_OBJECT('label','new CALL uses later metadata and rejects old out-of-range input','pass',later_call->>'code'='P0001'),
   JSONB_BUILD_OBJECT('label','later metadata rejection preserves rows and pre-insert sequence',
    'pass',(later_call->>'scope_unchanged')::BOOLEAN AND (later_call->>'sequence_unchanged')::BOOLEAN
     AND (later_call->>'new_count')::INTEGER=0),
   JSONB_BUILD_OBJECT('label','metadata edits do not rewrite either captured raw or typed row',
    'pass',EXISTS(SELECT 1 FROM public.order_terms t WHERE order_terms_id=first_id AND ROW_TO_JSON(t)::TEXT=first_row)
     AND EXISTS(SELECT 1 FROM public.order_terms t WHERE order_terms_id=second_id AND ROW_TO_JSON(t)::TEXT=second_row)),
   JSONB_BUILD_OBJECT('label','metadata edits do not rewrite legacy SQL-NULL row',
    'pass',EXISTS(SELECT 1 FROM public.order_terms t WHERE order_terms_id=-864611
     AND result_responses IS NULL AND ROW_TO_JSON(t)::TEXT=legacy_row)));
  UPDATE public.results SET result_parameters=normal_metadata WHERE result_id='OT46G';
  UPDATE public.respondent_accounts SET account_status='C' WHERE respondent_account_id=-864601;
  UPDATE public.creditor_accounts SET business_unit_id=44,creditor_account_type='CF',major_creditor_id=NULL
  WHERE creditor_account_id=-864602;
  later_call:=pg_temp.ot_call(payload,-864601,-864602,'Synthetic author','Synthetic name');
  checks:=checks||JSONB_BUILD_ARRAY(
   JSONB_BUILD_OBJECT('label','closed respondent, different BU and nonsuspense CF add no invented policy',
    'pass',later_call->>'code' IS NULL AND (later_call->>'new_count')::INTEGER=1),
   JSONB_BUILD_OBJECT('label','permitted account variants retain explicit links and all unrelated rows',
    'pass',later_call->'typed'->>'respondent_account_id'='-864601'
     AND later_call->'typed'->>'creditor_account_id'='-864602' AND (later_call->>'scope_unchanged')::BOOLEAN));
  RAISE EXCEPTION SQLSTATE 'ZX646' USING MESSAGE='rollback caller-owned publication test scope';
 EXCEPTION WHEN SQLSTATE 'ZX646' THEN NULL;
 END;
 checks:=checks||JSONB_BUILD_ARRAY(
  JSONB_BUILD_OBJECT('label','caller rollback removes every term and restores complete prior rows','pass',pg_temp.ot_scope()=before_rows),
  JSONB_BUILD_OBJECT('label','caller rollback removes both successful generated IDs',
   'pass',NOT EXISTS(SELECT 1 FROM public.order_terms WHERE order_terms_id IN (first_id,second_id))),
  JSONB_BUILD_OBJECT('label','caller rollback keeps legacy SQL-NULL capture unchanged and readable',
   'pass',EXISTS(SELECT 1 FROM public.order_terms t WHERE order_terms_id=-864611
    AND result_responses IS NULL AND ROW_TO_JSON(t)::TEXT=legacy_row)),
  JSONB_BUILD_OBJECT('label','caller rollback restores earlier caller-owned changes',
   'pass',(SELECT business_unit_name=before_name FROM public.business_units WHERE business_unit_id=32080)));
 INSERT INTO pg_temp.ot_lifecycle_checks VALUES(checks);
END;
$caller_scope$;
SELECT is((SELECT JSONB_ARRAY_LENGTH(checks) FROM ot_lifecycle_checks),19,'all 19 caller/evolution observations execute');
SELECT ok((entry->>'pass')::BOOLEAN,entry->>'label')
FROM ot_lifecycle_checks CROSS JOIN LATERAL JSONB_ARRAY_ELEMENTS(checks) entry;
SELECT ok(NOT EXISTS(SELECT 1 FROM ot_routine_before b LEFT JOIN pg_proc p ON p.oid=b.oid
 WHERE p.oid IS NULL OR ROW(PG_GET_FUNCTIONDEF(p.oid),p.proconfig,p.proowner,p.proacl,p.prosecdef)
 IS DISTINCT FROM ROW(b.definition,b.proconfig,b.proowner,b.proacl,b.prosecdef)),
 'all fault and caller probes preserve installed definition, identity, owner, ACL and settings');
SELECT ok(NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='ot46_native_insert')
 AND TO_REGPROCEDURE('pg_temp.ot_native_trigger()') IS NULL
 AND TO_REGCLASS('pg_temp.ot_native_attempts') IS NULL,'all insertion probes remove their owned trigger, function and counter');
SELECT ok(TO_REGNAMESPACE('opal_po10646_clock') IS NULL
 AND NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='opal_po10646_insert_denied'),
 'all controlled clock and permission objects are absent before suite rollback');

\endif
SELECT * FROM finish();
ROLLBACK;
