/**
 * OPAL Program
 *
 * MODULE      : p_process_draft_casefiles_pgtap_tests.sql
 *
 * DESCRIPTION : Verify the single-draft publication orchestrator contract.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket        Nature of Change
 * ----------  -------------  ------------  ----------------------------------------
 * 18/10/2026  Frankie Moran  PO-10655      Create Draft Casefile publication pgTAP coverage.
 */
-- OPAL-DB-UPGRADE {"id":"p_process_draft_casefiles.create","candidate":"ddl/V1_64__create_p_process_draft_casefiles_procedure.sql","scope":"both","data":"migration-created-only","inputs":["src/main/resources/db/migration/data/allEnvs/V1_10__insert_major_creditors_reference_data.sql","src/main/resources/db/migration/data/allEnvs/V1_12__insert_maintenance_applications_reference_data.sql","src/main/resources/db/migration/data/allEnvs/V1_13__insert_results_reference_data.sql","src/main/resources/db/migration/data/allEnvs/V1_16__refresh_results_reference_data.sql","src/main/resources/db/migration/data/allEnvs/V1_19__insert_configuration_items_data.sql","src/main/resources/db/migration/data/allEnvs/V1_5__insert_countries_reference_data.sql","src/main/resources/db/migration/data/allEnvs/V1_7__insert_business_units_reference_data.sql","src/main/resources/db/migration/data/dev/V1_33__insert_major_creditors_dev_data.sql","src/main/resources/db/migration/data/dev/V1_3__insert_countries_dev_data.sql","src/main/resources/db/migration/data/dev/V1_4__insert_inactive_country_dev_data.sql","src/main/resources/db/migration/data/nle/V1_34__insert_major_creditors_nle_data.sql","src/main/resources/db/migration/ddl/V1_11__create_maintenance_applications_table.sql","src/main/resources/db/migration/ddl/V1_14__create_draft_casefiles_table.sql","src/main/resources/db/migration/ddl/V1_15__allow_null_results_permitted_actions.sql","src/main/resources/db/migration/ddl/V1_17__create_associated_record_type_enum.sql","src/main/resources/db/migration/ddl/V1_18__create_configuration_items_table.sql","src/main/resources/db/migration/ddl/V1_20__create_parties_table.sql","src/main/resources/db/migration/ddl/V1_21__create_debtor_detail_table.sql","src/main/resources/db/migration/ddl/V1_22__create_third_party_contact_table.sql","src/main/resources/db/migration/ddl/V1_23__create_account_number_index_table.sql","src/main/resources/db/migration/ddl/V1_24__create_notes_table.sql","src/main/resources/db/migration/ddl/V1_25__create_aliases_table.sql","src/main/resources/db/migration/ddl/V1_26__create_respondent_accounts_table.sql","src/main/resources/db/migration/ddl/V1_27__create_creditor_accounts_table.sql","src/main/resources/db/migration/ddl/V1_28__create_respondent_account_parties_table.sql","src/main/resources/db/migration/ddl/V1_29__create_order_terms_table.sql","src/main/resources/db/migration/ddl/V1_2__create_countries_table.sql","src/main/resources/db/migration/ddl/V1_30__add_draft_casefiles_account_id_foreign_key.sql","src/main/resources/db/migration/ddl/V1_31__create_f_get_check_letter.sql","src/main/resources/db/migration/ddl/V1_32__create_f_get_account_number.sql","src/main/resources/db/migration/ddl/V1_49__create_p_insert_creditor_accounts_procedure.sql","src/main/resources/db/migration/ddl/V1_50__create_p_insert_debtor_detail_procedure.sql","src/main/resources/db/migration/ddl/V1_52__create_p_insert_notes_procedure.sql","src/main/resources/db/migration/ddl/V1_56__create_p_insert_parties_procedure.sql","src/main/resources/db/migration/ddl/V1_57__create_p_insert_respondent_account_parties_procedure.sql","src/main/resources/db/migration/ddl/V1_58__create_p_insert_respondent_account_procedure.sql","src/main/resources/db/migration/ddl/V1_59__create_p_insert_third_party_contacts_procedure.sql","src/main/resources/db/migration/ddl/V1_60__alter_aliases_name_columns.sql","src/main/resources/db/migration/ddl/V1_61__create_p_insert_party_aliases_procedure.sql","src/main/resources/db/migration/ddl/V1_62__add_order_terms_result_responses.sql","src/main/resources/db/migration/ddl/V1_63__create_p_insert_order_terms_procedure.sql","src/main/resources/db/migration/ddl/V1_6__create_business_units_table.sql","src/main/resources/db/migration/ddl/V1_8__create_results_table.sql","src/main/resources/db/migration/ddl/V1_9__create_major_creditors_table.sql"],"contract":{"type":"additive","objects":{"created":[{"kind":"routine","identity":"public.p_process_draft_casefiles(bigint)"}],"replaced":[]},"preserve":{"rows":["public.draft_casefiles","public.parties","public.aliases","public.third_party_contact","public.debtor_detail","public.respondent_accounts","public.creditor_accounts","public.order_terms","public.notes","public.respondent_account_parties","public.account_number_index","public.business_units","public.countries","public.major_creditors","public.maintenance_applications","public.results","public.configuration_items"],"tables":["public.draft_casefiles","public.parties","public.aliases","public.third_party_contact","public.debtor_detail","public.respondent_accounts","public.creditor_accounts","public.order_terms","public.notes","public.respondent_account_parties","public.account_number_index","public.business_units","public.countries","public.major_creditors","public.maintenance_applications","public.results","public.configuration_items"],"routines":["public.p_insert_parties(json,public.t_party_account_type_enum)","public.p_insert_party_aliases(bigint,json)","public.p_insert_third_party_contacts(json)","public.p_insert_debtor_detail(json,character varying)","public.p_insert_respondent_account(smallint,public.t_casefile_type_enum,json,bigint,bigint)","public.p_insert_creditor_accounts(smallint,json,bigint,bigint,bigint)","public.p_insert_order_terms(bigint,bigint,character varying,character varying,json)","public.p_insert_notes(bigint,character varying,character varying,json)","public.p_insert_respondent_account_parties(bigint,bigint,public.t_association_type_enum)","public.f_get_account_number(smallint,public.t_associated_record_type_enum)","public.f_get_check_letter(character varying)"],"enums":["public.t_associated_record_type_enum","public.t_association_type_enum","public.t_business_unit_type_enum","public.t_case_result_type_enum","public.t_casefile_type_enum","public.t_creditor_account_type_enum","public.t_da_account_status_enum","public.t_draft_casefile_status_enum","public.t_indexation_enum","public.t_note_type_enum","public.t_party_account_type_enum","public.t_payment_arrangement_enum","public.t_payment_frequency_enum"],"sequences":["public.account_number_index_id_seq","public.alias_id_seq","public.application_id_seq","public.configuration_item_id_seq","public.country_id_seq","public.creditor_account_id_seq","public.debtor_detail_id_seq","public.draft_casefile_id_seq","public.major_creditor_id_seq","public.note_id_seq","public.order_terms_id_seq","public.party_id_seq","public.respondent_account_id_seq","public.respondent_account_party_id_seq","public.third_party_contact_id_seq"]},"assertion":"p_process_draft_casefiles.current"}}

\set ON_ERROR_STOP on
\if :{?opal_assertion_group}
 SELECT :'opal_assertion_group'='p_process_draft_casefiles.current' AS pdc_known_group \gset
 \if :pdc_known_group
 \else
  DO $group$ BEGIN RAISE EXCEPTION 'Unknown Draft Casefile assertion group'; END; $group$;
 \endif
\endif
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SET LOCAL search_path=public,pg_catalog;
SET LOCAL TIME ZONE 'UTC';
SET LOCAL DateStyle='ISO, YMD';
SELECT plan(2707);

-- -----------------------------------------------------------------------------
-- Scenario: The approved one-input, three-output orchestrator is installed.
-- Setup: Inspect the effective catalogue before any behavior or fixture setup.
-- Expected: All eight properties pass only for the exact installed contract.
-- -----------------------------------------------------------------------------
CREATE TEMP TABLE pdc_installed AS
SELECT TO_REGPROCEDURE('public.p_process_draft_casefiles(bigint)') AS oid;
SELECT ok((SELECT oid IS NOT NULL FROM pdc_installed), 'orchestrator exists');
SELECT ok((SELECT prokind='p' FROM pg_proc WHERE oid=(SELECT oid FROM pdc_installed)), 'procedure kind');
SELECT ok((SELECT proargtypes=ARRAY['bigint'::REGTYPE::OID]::OIDVECTOR
 FROM pg_proc WHERE oid=(SELECT oid FROM pdc_installed)), 'one BIGINT input identity');
SELECT ok((SELECT proallargtypes=ARRAY['bigint'::REGTYPE::OID,'bigint'::REGTYPE::OID,
 'varchar'::REGTYPE::OID,'json'::REGTYPE::OID] AND proargmodes=ARRAY['i','o','o','o']::"char"[]
 FROM pg_proc WHERE oid=(SELECT oid FROM pdc_installed)), 'ordered input and three outputs');
SELECT ok((SELECT proargnames=ARRAY['pi_draft_casefile_id','po_respondent_account_id',
 'po_account_number','po_published_accounts']::TEXT[] FROM pg_proc
 WHERE oid=(SELECT oid FROM pdc_installed)), 'exact parameter names');
SELECT ok((SELECT pronargdefaults=0 AND proargdefaults IS NULL AND NOT prosecdef
 AND NOT proisstrict AND NOT proleakproof AND NOT proretset AND provolatile='v'
 AND proparallel='u' AND proconfig IS NULL FROM pg_proc
 WHERE oid=(SELECT oid FROM pdc_installed)), 'ordinary invoker without defaults');
SELECT ok((SELECT lanname='plpgsql' FROM pg_proc p JOIN pg_language l ON l.oid=p.prolang
 WHERE p.oid=(SELECT oid FROM pdc_installed)), 'PLpgSQL language');
SELECT is((SELECT COUNT(*) FROM pg_proc WHERE pronamespace='public'::REGNAMESPACE
 AND proname='p_process_draft_casefiles'), 1::BIGINT, 'one public overload');

-- -----------------------------------------------------------------------------
-- Scenario: Observe raw draft data, graph/reference rows and reservation membership.
-- Setup: Owner-local observers retain whole rows as text, with deterministic ordering.
-- Expected: JSONB contains observations only; persisted payload JSON is never normalized.
-- -----------------------------------------------------------------------------
CREATE FUNCTION pg_temp.pdc_scope() RETURNS JSONB LANGUAGE plpgsql AS $scope$
DECLARE table_name TEXT; observed JSONB; scope JSONB := '{}'::JSONB;
BEGIN
 FOREACH table_name IN ARRAY ARRAY[
  'draft_casefiles','parties','aliases','third_party_contact','debtor_detail',
  'respondent_accounts','creditor_accounts','order_terms','notes',
  'respondent_account_parties','account_number_index','business_units','countries',
  'major_creditors','maintenance_applications','results','configuration_items']
 LOOP
  EXECUTE FORMAT('SELECT COALESCE(JSONB_AGG(raw ORDER BY raw COLLATE "C"),''[]''::JSONB) '
   'FROM (SELECT ROW_TO_JSON(t)::TEXT AS raw FROM public.%I t) rows',table_name)
   INTO observed;
  scope := scope || JSONB_BUILD_OBJECT(table_name,observed);
 END LOOP;
 -- Whole draft rows include every column; these explicit observations also expose
 -- the three original JSON texts without a JSONB input-path round trip.
 SELECT COALESCE(JSONB_AGG(JSONB_BUILD_OBJECT('id',draft_casefile_id,
  'casefile',casefile::TEXT,'snapshot',casefile_snapshot::TEXT,'timeline',timeline_data::TEXT)
  ORDER BY draft_casefile_id),'[]'::JSONB) INTO observed FROM public.draft_casefiles;
 RETURN scope || JSONB_BUILD_OBJECT('draft_raw',observed);
END;
$scope$;

CREATE FUNCTION pg_temp.pdc_ids() RETURNS JSONB LANGUAGE plpgsql AS $ids$
DECLARE target RECORD; observed JSONB; ids JSONB := '{}'::JSONB;
BEGIN
 FOR target IN SELECT * FROM (VALUES
  ('parties','party_id'),('aliases','alias_id'),('third_party_contact','third_party_contact_id'),
  ('debtor_detail','debtor_detail_id'),('respondent_accounts','respondent_account_id'),
  ('creditor_accounts','creditor_account_id'),('order_terms','order_terms_id'),('notes','note_id'),
  ('respondent_account_parties','respondent_account_party_id'),
  ('account_number_index','account_number_index_id')) AS t(table_name,id_column)
 LOOP
  EXECUTE FORMAT('SELECT COALESCE(JSONB_AGG(%I ORDER BY %I),''[]''::JSONB) FROM public.%I',
   target.id_column,target.id_column,target.table_name) INTO observed;
  ids := ids || JSONB_BUILD_OBJECT(target.table_name,observed);
 END LOOP;
 RETURN ids;
END;
$ids$;

CREATE FUNCTION pg_temp.pdc_call(draft_id BIGINT) RETURNS JSONB LANGUAGE plpgsql AS $observe$
DECLARE code TEXT; message TEXT; detail TEXT; hint TEXT; schema_name TEXT; table_name TEXT;
 column_name TEXT; data_type TEXT; constraint_name TEXT; context TEXT;
 respondent_id BIGINT; account_number VARCHAR; published JSON; completed BOOLEAN := FALSE;
 before_scope JSONB; after_scope JSONB; before_ids JSONB; after_ids JSONB;
 created_ids JSONB := '{}'::JSONB; target TEXT; ids JSONB;
BEGIN
 before_scope := pg_temp.pdc_scope();
 before_ids := pg_temp.pdc_ids();
 BEGIN
  CALL public.p_process_draft_casefiles(draft_id,respondent_id,account_number,published);
  completed := TRUE;
 EXCEPTION WHEN query_canceled OR assert_failure THEN
  GET STACKED DIAGNOSTICS code=RETURNED_SQLSTATE,message=MESSAGE_TEXT,detail=PG_EXCEPTION_DETAIL,
   hint=PG_EXCEPTION_HINT,schema_name=SCHEMA_NAME,table_name=TABLE_NAME,column_name=COLUMN_NAME,
   data_type=PG_DATATYPE_NAME,constraint_name=CONSTRAINT_NAME,context=PG_EXCEPTION_CONTEXT;
 WHEN OTHERS THEN
  GET STACKED DIAGNOSTICS code=RETURNED_SQLSTATE,message=MESSAGE_TEXT,detail=PG_EXCEPTION_DETAIL,
   hint=PG_EXCEPTION_HINT,schema_name=SCHEMA_NAME,table_name=TABLE_NAME,column_name=COLUMN_NAME,
   data_type=PG_DATATYPE_NAME,constraint_name=CONSTRAINT_NAME,context=PG_EXCEPTION_CONTEXT;
 END;
 after_scope := pg_temp.pdc_scope();
 after_ids := pg_temp.pdc_ids();
 FOR target IN SELECT JSONB_OBJECT_KEYS(after_ids) LOOP
  SELECT COALESCE(JSONB_AGG(value ORDER BY value::BIGINT),'[]'::JSONB) INTO ids
  FROM JSONB_ARRAY_ELEMENTS(after_ids->target) AS a(value)
  WHERE NOT (before_ids->target @> JSONB_BUILD_ARRAY(value));
  created_ids := created_ids || JSONB_BUILD_OBJECT(target,ids);
 END LOOP;
 RETURN JSONB_BUILD_OBJECT('completed',completed,'code',code,'message',message,
  'detail',detail,'hint',hint,'schema',schema_name,'table',table_name,'column',column_name,
  'datatype',data_type,'constraint',constraint_name,'context',context,
  'before',before_scope,'after',after_scope,'created_ids',created_ids)
  || CASE WHEN completed THEN JSONB_BUILD_OBJECT('respondent_id',respondent_id,
   'account_number',account_number,'published_raw',published::TEXT)
  ELSE '{}'::JSONB END;
END;
$observe$;

-- -----------------------------------------------------------------------------
-- Scenario: Synthetic reference, draft and sentinel fixtures are transaction-owned.
-- Setup: Refuse occupied identifiers before inserting distinct role values.
-- Expected: Real helpers receive synthetic JSON; no existing data is overwritten.
-- -----------------------------------------------------------------------------
DO $fixtures$
BEGIN
 IF CURRENT_DATABASE()<>'opal_maintenance_db_unit_test' OR CURRENT_USER<>'postgres' THEN
  RAISE EXCEPTION 'Draft Casefile tests require the maintained disposable database and role';
 END IF;
 IF EXISTS(SELECT 1 FROM public.business_units WHERE business_unit_id=32055 OR business_unit_code='P055')
 OR EXISTS(SELECT 1 FROM public.countries WHERE country_id IN (-1065501,-1065502) OR cjs_code IN (31055,31056))
 OR EXISTS(SELECT 1 FROM public.maintenance_applications WHERE application_id=-10655 OR application_code='PDC55')
 OR EXISTS(SELECT 1 FROM public.results WHERE result_id IN ('P55A','P55B','P55N'))
 OR EXISTS(SELECT 1 FROM public.major_creditors WHERE major_creditor_id IN (-1065501,-1065502,-1065503)
  OR (business_unit_id=32055 AND major_creditor_code IN ('M55A','M55B','C55A')))
 OR EXISTS(SELECT 1 FROM public.draft_casefiles WHERE draft_casefile_id BETWEEN -1065599 AND -1065501)
 THEN
  RAISE EXCEPTION 'Draft Casefile synthetic fixture collision; allocate and record a new owned scope';
 END IF;
END;
$fixtures$;
INSERT INTO public.business_units(business_unit_id,business_unit_code,business_unit_name,business_unit_type,welsh_language)
VALUES(32055,'P055','Synthetic publication unit','Area',FALSE);
INSERT INTO public.countries(country_id,cjs_code,country_name,date_used_from,active)
VALUES(-1065501,31055,'Synthetic publication country',DATE '2000-01-01',TRUE),
 (-1065502,31056,'Synthetic inactive publication country',DATE '2000-01-01',FALSE);
INSERT INTO public.maintenance_applications(application_id,application_code,application_title,application_group,active,date_used_from)
VALUES(-10655,'PDC55','Synthetic publication application','Synthetic',TRUE,DATE '2000-01-01');
INSERT INTO public.major_creditors(major_creditor_id,business_unit_id,major_creditor_code,name,address_line_1,active,central_authority)
VALUES(-1065501,32055,'M55A','Synthetic first Major','First Major address',TRUE,FALSE),
 (-1065502,32055,'M55B','Synthetic second Major','Second Major address',TRUE,FALSE),
 (-1065503,32055,'C55A','Synthetic Central Authority','Authority address',TRUE,TRUE);
INSERT INTO public.results(result_id,result_title,order_term,enforcement_result,case_result,active,order_accruing,
 requires_creditor,enforcement_hold,requires_enforcer,generates_hearing,generates_warrant,lists_monies,
 requires_employment_data,allow_additional_action,enf_next_permitted_actions,manual_enforcement,auto_enforcement,
 result_parameters)
SELECT id,'Synthetic publication Result',TRUE,FALSE,FALSE,TRUE,FALSE,creditor,FALSE,FALSE,FALSE,FALSE,FALSE,
 FALSE,FALSE,'',FALSE,FALSE,
 '[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":0,"max":10000,"language_dependent":false}]'::JSON
FROM(VALUES('P55A',TRUE),('P55B',TRUE),('P55N',FALSE))v(id,creditor);
CREATE TEMP TABLE pdc_payloads(label TEXT PRIMARY KEY,payload JSON NOT NULL);
INSERT INTO pdc_payloads VALUES('base',$payload$
{ "respondent_account": {
 "application_code":"PDC55",
 "respondent":{"party_details":{"organisation":false,"individual_details":{"surname":"Synthetic Respondent"},
 "address":{"address_line_1":"Respondent address","cjs_code":31055}}},
 "order_details":{"date_ordered":"2024-01-01","date_arrears_last_updated":"2024-01-01",
 "payment_period":"Monthly","interest_flag":false,"indexation":"None","payment_arrangement":"Court",
 "order_terms":[{"result_id":"P55A","creditor_type":"Applicant",
 "result_responses":[ { "parameter_name" : "Amount", "response" : "00012.30" } ]}]}},
 "applicant":{"party_details":{"organisation":false,"individual_details":{"surname":"Synthetic Applicant"},
 "address":{"address_line_1":"Applicant address","cjs_code":31055}},
 "bank_account_details":{"bank_account_type":"None or not applicable"}},
 "minor_creditors":[{"creditor_sequence":7,"party_details":{"organisation":false,
 "individual_details":{"surname":"Synthetic Minor Seven"},
 "address":{"address_line_1":"Minor Seven address","cjs_code":31055}},
 "bank_account_details":{"bank_account_type":"None or not applicable"}}] }
$payload$::JSON);
INSERT INTO public.draft_casefiles(draft_casefile_id,business_unit_id,created_date,submitted_by,submitted_by_name,
 validated_date,validated_by,validated_by_name,casefile,casefile_snapshot,casefile_type,casefile_status,
 casefile_status_date,timeline_data,version_number)
SELECT id,32055,TIMESTAMP '2024-01-01','P55_SUBMIT','Synthetic saved submitter',
 TIMESTAMP '2024-01-02','P55_APPROVE','Synthetic saved approver',payload,
 '{ "respondent_name" : "Synthetic Respondent", "applicant_name" : "Synthetic Applicant" }'::JSON,
 'REMO In','PUBLISHING_PENDING',TIMESTAMP '2024-01-02','[ { "event" : "Synthetic approval" } ]'::JSON,1
FROM pdc_payloads CROSS JOIN(VALUES(-1065501::BIGINT),(-1065502::BIGINT))v(id);
-- Unrelated sentinel is deliberately ineligible and contains its own raw text.
INSERT INTO public.draft_casefiles(draft_casefile_id,business_unit_id,created_date,submitted_by,submitted_by_name,
 casefile,casefile_snapshot,casefile_type,casefile_status,casefile_status_date,timeline_data,version_number)
VALUES(-1065599,32055,TIMESTAMP '2024-01-01','P55_SENTINEL','Synthetic sentinel submitter',
 '{ "sentinel" : true }'::JSON,'{ "sentinel_snapshot" : true }'::JSON,'REMO Out','SUBMITTED',
 TIMESTAMP '2024-01-01','[ { "sentinel_timeline" : true } ]'::JSON,NULL);




-- -----------------------------------------------------------------------------
-- Scenario: Change one synthetic source path without normalising original JSON.
-- Setup: Rebuild only fixture ancestors, retaining original descendant JSON text.
-- Expected: Duplicate members remain observable; SQL NULL removes a fixture member.
-- -----------------------------------------------------------------------------
CREATE FUNCTION pg_temp.pdc_put(source JSON,path TEXT[],replacement JSON) RETURNS JSON
LANGUAGE plpgsql AS $put$
DECLARE result TEXT; found BOOLEAN;
BEGIN
 IF CARDINALITY(path)=0 THEN RETURN replacement; END IF;
 IF JSON_TYPEOF(source)='array' THEN
  SELECT '['||STRING_AGG(COALESCE(CASE WHEN (ordinality-1)::TEXT=path[1]
   THEN pg_temp.pdc_put(value,path[2:],replacement)::TEXT ELSE value::TEXT END,'null'),',' ORDER BY ordinality)||']'
  INTO result FROM JSON_ARRAY_ELEMENTS(source) WITH ORDINALITY;
 ELSE
  SELECT EXISTS(SELECT 1 FROM JSON_EACH(source) WHERE key=path[1]) INTO found;
  SELECT '{'||COALESCE(STRING_AGG(TO_JSON(key)::TEXT||':'||changed::TEXT,',' ORDER BY ordinality),'')||'}'
  INTO result FROM (SELECT key,ordinality,CASE WHEN key=path[1]
   THEN pg_temp.pdc_put(value,path[2:],replacement) ELSE value END AS changed
   FROM JSON_EACH(source) WITH ORDINALITY) entries WHERE changed IS NOT NULL;
  IF NOT found AND replacement IS NOT NULL THEN
   result:=LEFT(result,LENGTH(result)-1)||CASE WHEN result='{}' THEN '' ELSE ',' END
    ||TO_JSON(path[1])::TEXT||':'||pg_temp.pdc_put('{}',path[2:],replacement)::TEXT||'}';
  END IF;
 END IF;
 RETURN result::JSON;
END;
$put$;
CREATE TEMP TABLE pdc_guard_cases(label TEXT PRIMARY KEY,input_id BIGINT,setup TEXT,
 expected_code TEXT,expected_message TEXT);

DO $bu$ BEGIN IF EXISTS(SELECT 1 FROM public.business_units WHERE business_unit_id=32054 OR business_unit_code='P054') THEN RAISE EXCEPTION 'Draft Casefile alternate BU collision'; END IF; END; $bu$;
INSERT INTO public.business_units(business_unit_id,business_unit_code,business_unit_name,business_unit_type,welsh_language) VALUES(32054,'P054','Synthetic other publication unit','Area',FALSE);

INSERT INTO pdc_guard_cases VALUES
('null identifier',NULL,'','P0001','p_process_draft_casefiles: draft casefile identifier is required'),
('missing identifier 0',0,'','P0002','query returned no rows'),
('missing identifier -1',-1,'','P0002','query returned no rows'),
('missing identifier 9223372036854775807',9223372036854775807,'','P0002','query returned no rows'),
('status SUBMITTED',-1065501,'UPDATE public.draft_casefiles SET casefile_status=''SUBMITTED'' WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile is not publishing pending'),
('status DELETED',-1065501,'UPDATE public.draft_casefiles SET casefile_status=''DELETED'' WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile is not publishing pending'),
('status REJECTED',-1065501,'UPDATE public.draft_casefiles SET casefile_status=''REJECTED'' WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile is not publishing pending'),
('status PUBLISHED',-1065501,'UPDATE public.draft_casefiles SET casefile_status=''PUBLISHED'' WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile is not publishing pending'),
('status PUBLISHING_FAILED',-1065501,'UPDATE public.draft_casefiles SET casefile_status=''PUBLISHING_FAILED'' WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile is not publishing pending'),
('status RESUBMITTED',-1065501,'UPDATE public.draft_casefiles SET casefile_status=''RESUBMITTED'' WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile is not publishing pending'),
('linked number ''''',-1065501,'UPDATE public.draft_casefiles SET account_number='''' WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile already has publication identity'),
('linked number ''existing''',-1065501,'UPDATE public.draft_casefiles SET account_number=''existing'' WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile already has publication identity'),
('missing validated_date',-1065501,'UPDATE public.draft_casefiles SET validated_date=NULL WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('missing validated_by',-1065501,'UPDATE public.draft_casefiles SET validated_by=NULL WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('missing validated_by_name',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=NULL WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by blank 0',-1065501,'UPDATE public.draft_casefiles SET validated_by='''' WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by blank 9',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(9) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by blank 10',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(10) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by blank 11',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(11) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by blank 12',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(12) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by blank 13',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(13) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by blank 32',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(32) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by blank 133',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(133) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by blank 160',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(160) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by blank 5760',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(5760) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by blank 8192',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(8192) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by blank 8193',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(8193) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by blank 8194',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(8194) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by blank 8195',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(8195) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by blank 8196',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(8196) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by blank 8197',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(8197) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by blank 8198',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(8198) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by blank 8199',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(8199) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by blank 8200',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(8200) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by blank 8201',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(8201) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by blank 8202',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(8202) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by blank 8232',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(8232) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by blank 8233',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(8233) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by blank 8239',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(8239) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by blank 8287',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(8287) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by blank 12288',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(12288) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by nonblank 9',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(9)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by nonblank 10',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(10)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by nonblank 11',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(11)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by nonblank 12',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(12)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by nonblank 13',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(13)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by nonblank 32',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(32)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by nonblank 133',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(133)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by nonblank 160',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(160)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by nonblank 5760',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(5760)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by nonblank 8192',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(8192)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by nonblank 8193',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(8193)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by nonblank 8194',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(8194)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by nonblank 8195',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(8195)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by nonblank 8196',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(8196)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by nonblank 8197',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(8197)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by nonblank 8198',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(8198)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by nonblank 8199',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(8199)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by nonblank 8200',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(8200)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by nonblank 8201',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(8201)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by nonblank 8202',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(8202)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by nonblank 8232',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(8232)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by nonblank 8233',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(8233)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by nonblank 8239',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(8239)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by nonblank 8287',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(8287)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by nonblank 12288',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(12288)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by nonblank 65279',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(65279)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by nonblank 8203',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(8203)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by nonwhite alone 65279',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(65279),casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by nonwhite alone 8203',-1065501,'UPDATE public.draft_casefiles SET validated_by=CHR(8203),casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by_name blank 0',-1065501,'UPDATE public.draft_casefiles SET validated_by_name='''' WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by_name blank 9',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(9) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by_name blank 10',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(10) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by_name blank 11',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(11) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by_name blank 12',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(12) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by_name blank 13',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(13) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by_name blank 32',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(32) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by_name blank 133',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(133) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by_name blank 160',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(160) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by_name blank 5760',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(5760) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by_name blank 8192',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(8192) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by_name blank 8193',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(8193) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by_name blank 8194',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(8194) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by_name blank 8195',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(8195) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by_name blank 8196',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(8196) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by_name blank 8197',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(8197) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by_name blank 8198',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(8198) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by_name blank 8199',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(8199) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by_name blank 8200',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(8200) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by_name blank 8201',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(8201) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by_name blank 8202',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(8202) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by_name blank 8232',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(8232) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by_name blank 8233',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(8233) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by_name blank 8239',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(8239) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by_name blank 8287',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(8287) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by_name blank 12288',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(12288) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is incomplete'),
('validated_by_name nonblank 9',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(9)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by_name nonblank 10',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(10)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by_name nonblank 11',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(11)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by_name nonblank 12',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(12)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by_name nonblank 13',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(13)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by_name nonblank 32',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(32)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by_name nonblank 133',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(133)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by_name nonblank 160',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(160)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by_name nonblank 5760',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(5760)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by_name nonblank 8192',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(8192)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by_name nonblank 8193',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(8193)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by_name nonblank 8194',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(8194)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by_name nonblank 8195',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(8195)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by_name nonblank 8196',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(8196)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by_name nonblank 8197',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(8197)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by_name nonblank 8198',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(8198)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by_name nonblank 8199',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(8199)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by_name nonblank 8200',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(8200)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by_name nonblank 8201',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(8201)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by_name nonblank 8202',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(8202)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by_name nonblank 8232',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(8232)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by_name nonblank 8233',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(8233)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by_name nonblank 8239',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(8239)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by_name nonblank 8287',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(8287)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by_name nonblank 12288',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(12288)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by_name nonblank 65279',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(65279)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by_name nonblank 8203',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(8203)||''x'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by_name nonwhite alone 65279',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(65279),casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('validated_by_name nonwhite alone 8203',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=CHR(8203),casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('self approval',-1065501,'UPDATE public.draft_casefiles SET validated_by=submitted_by WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: draft casefile approval is not independent'),
('eligible case distinct',-1065501,'UPDATE public.draft_casefiles SET validated_by=''p55_submit'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('eligible space distinct',-1065501,'UPDATE public.draft_casefiles SET validated_by=''P55_SUBMIT '',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('eligible same display names',-1065501,'UPDATE public.draft_casefiles SET validated_by_name=submitted_by_name,casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('eligible nullable version',-1065501,'UPDATE public.draft_casefiles SET version_number=NULL,casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('eligible approval earlier',-1065501,'UPDATE public.draft_casefiles SET validated_date=''1900-01-01'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('eligible approval future',-1065501,'UPDATE public.draft_casefiles SET validated_date=''2200-01-01'',casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('container respondent_account None',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account''],NULL) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('container respondent_account null',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account''],''null''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('container respondent_account []',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account''],''[]''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('container respondent_account "bad"',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account''],''"bad"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('container respondent_account.respondent None',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent''],NULL) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('container respondent_account.respondent null',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent''],''null''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('container respondent_account.respondent []',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent''],''[]''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('container respondent_account.respondent "bad"',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent''],''"bad"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('container applicant None',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''applicant''],NULL) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('container applicant null',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''applicant''],''null''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('container applicant []',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''applicant''],''[]''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('container applicant "bad"',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''applicant''],''"bad"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('container respondent_account.respondent.party_details None',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''party_details''],NULL) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('container respondent_account.respondent.party_details null',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''party_details''],''null''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('container respondent_account.respondent.party_details []',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''party_details''],''[]''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('container respondent_account.respondent.party_details "bad"',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''party_details''],''"bad"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('container applicant.party_details None',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''applicant'',''party_details''],NULL) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('container applicant.party_details null',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''applicant'',''party_details''],''null''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('container applicant.party_details []',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''applicant'',''party_details''],''[]''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('container applicant.party_details "bad"',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''applicant'',''party_details''],''"bad"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('container minor_creditors.0.party_details None',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''minor_creditors'',''0'',''party_details''],NULL) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('container minor_creditors.0.party_details null',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''minor_creditors'',''0'',''party_details''],''null''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('container minor_creditors.0.party_details []',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''minor_creditors'',''0'',''party_details''],''[]''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('container minor_creditors.0.party_details "bad"',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''minor_creditors'',''0'',''party_details''],''"bad"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('container respondent_account.order_details None',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details''],NULL) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('container respondent_account.order_details null',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details''],''null''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('container respondent_account.order_details []',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details''],''[]''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('container respondent_account.order_details "bad"',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details''],''"bad"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('root null',-1065501,'UPDATE public.draft_casefiles SET casefile=''null''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('root []',-1065501,'UPDATE public.draft_casefiles SET casefile=''[]''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('root "bad"',-1065501,'UPDATE public.draft_casefiles SET casefile=''"bad"''::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('collection minor_creditors null',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''minor_creditors''],''null''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('collection minor_creditors {}',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''minor_creditors''],''{}''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('collection minor_creditors "bad"',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''minor_creditors''],''"bad"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('collection minor_creditors [null]',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''minor_creditors''],''[null]''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('collection minor_creditors [1]',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''minor_creditors''],''[1]''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('collection respondent_account.order_details.order_terms null',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms''],''null''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('collection respondent_account.order_details.order_terms {}',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms''],''{}''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('collection respondent_account.order_details.order_terms "bad"',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms''],''"bad"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('collection respondent_account.order_details.order_terms [null]',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms''],''[null]''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('collection respondent_account.order_details.order_terms [1]',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms''],''[1]''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('collection respondent_account.order_details.order_terms []',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms''],''[]''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('contact respondent_account.respondent null',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''third_party_details''],''null''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('contact respondent_account.respondent []',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''third_party_details''],''[]''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('contact respondent_account.respondent 1',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''third_party_details''],''1''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('contact applicant null',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''applicant'',''third_party_details''],''null''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('contact applicant []',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''applicant'',''third_party_details''],''[]''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('contact applicant 1',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''applicant'',''third_party_details''],''1''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('aliases respondent_account.respondent null',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''party_details'',''aliases''],''null''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('aliases respondent_account.respondent {}',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''party_details'',''aliases''],''{}''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('aliases respondent_account.respondent 1',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''party_details'',''aliases''],''1''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('malformed branch respondent_account.respondent individual_details',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''party_details'',''individual_details''],''[]''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('malformed branch respondent_account.respondent organisation_details',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''party_details'',''organisation_details''],''[]''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('aliases applicant null',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''applicant'',''party_details'',''aliases''],''null''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('aliases applicant {}',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''applicant'',''party_details'',''aliases''],''{}''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('aliases applicant 1',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''applicant'',''party_details'',''aliases''],''1''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('malformed branch applicant individual_details',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''applicant'',''party_details'',''individual_details''],''[]''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('malformed branch applicant organisation_details',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''applicant'',''party_details'',''organisation_details''],''[]''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('aliases minor_creditors.0 null',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''minor_creditors'',''0'',''party_details'',''aliases''],''null''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('aliases minor_creditors.0 {}',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''minor_creditors'',''0'',''party_details'',''aliases''],''{}''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('aliases minor_creditors.0 1',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''minor_creditors'',''0'',''party_details'',''aliases''],''1''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('malformed branch minor_creditors.0 individual_details',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''minor_creditors'',''0'',''party_details'',''individual_details''],''[]''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('malformed branch minor_creditors.0 organisation_details',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''minor_creditors'',''0'',''party_details'',''organisation_details''],''[]''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('debtor []',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''[]''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('debtor 1',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''1''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('debtor "bad"',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''"bad"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('employer address []',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''{"employer_address":[]}''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('employer address 1',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''{"employer_address":1}''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('employer address "bad"',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''{"employer_address":"bad"}''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('note null',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''notes''],''null''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('note []',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''notes''],''[]''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('note 1',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''notes''],''1''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('duplicate .respondent_account',-1065501,'UPDATE public.draft_casefiles SET casefile=(LEFT(RTRIM((casefile)::TEXT,CHR(32)||CHR(9)||CHR(10)||CHR(13)),LENGTH(RTRIM((casefile)::TEXT,CHR(32)||CHR(9)||CHR(10)||CHR(13)))-1)||'',"respondent_\u0061ccount":''||((casefile)->''respondent_account'')::TEXT||''}'')::JSON WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('duplicate respondent_account.respondent',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account''],(LEFT(RTRIM((casefile#>''{respondent_account}'')::TEXT,CHR(32)||CHR(9)||CHR(10)||CHR(13)),LENGTH(RTRIM((casefile#>''{respondent_account}'')::TEXT,CHR(32)||CHR(9)||CHR(10)||CHR(13)))-1)||'',"respondent":''||((casefile#>''{respondent_account}'')->''respondent'')::TEXT||''}'')::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('duplicate respondent_account.respondent.party_details',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent''],(LEFT(RTRIM((casefile#>''{respondent_account,respondent}'')::TEXT,CHR(32)||CHR(9)||CHR(10)||CHR(13)),LENGTH(RTRIM((casefile#>''{respondent_account,respondent}'')::TEXT,CHR(32)||CHR(9)||CHR(10)||CHR(13)))-1)||'',"party_\u0064etails":''||((casefile#>''{respondent_account,respondent}'')->''party_details'')::TEXT||''}'')::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('duplicate applicant.party_details',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''applicant''],(LEFT(RTRIM((casefile#>''{applicant}'')::TEXT,CHR(32)||CHR(9)||CHR(10)||CHR(13)),LENGTH(RTRIM((casefile#>''{applicant}'')::TEXT,CHR(32)||CHR(9)||CHR(10)||CHR(13)))-1)||'',"party_details":''||((casefile#>''{applicant}'')->''party_details'')::TEXT||''}'')::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('duplicate respondent_account.order_details.order_terms',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details''],(LEFT(RTRIM((casefile#>''{respondent_account,order_details}'')::TEXT,CHR(32)||CHR(9)||CHR(10)||CHR(13)),LENGTH(RTRIM((casefile#>''{respondent_account,order_details}'')::TEXT,CHR(32)||CHR(9)||CHR(10)||CHR(13)))-1)||'',"order_terms":''||((casefile#>''{respondent_account,order_details}'')->''order_terms'')::TEXT||''}'')::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('duplicate minor_creditors.0.creditor_sequence',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''minor_creditors'',''0''],(LEFT(RTRIM((casefile#>''{minor_creditors,0}'')::TEXT,CHR(32)||CHR(9)||CHR(10)||CHR(13)),LENGTH(RTRIM((casefile#>''{minor_creditors,0}'')::TEXT,CHR(32)||CHR(9)||CHR(10)||CHR(13)))-1)||'',"creditor_\u0073equence":''||((casefile#>''{minor_creditors,0}'')->''creditor_sequence'')::TEXT||''}'')::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('duplicate respondent_account.order_details.order_terms.0.creditor_type',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0''],(LEFT(RTRIM((casefile#>''{respondent_account,order_details,order_terms,0}'')::TEXT,CHR(32)||CHR(9)||CHR(10)||CHR(13)),LENGTH(RTRIM((casefile#>''{respondent_account,order_details,order_terms,0}'')::TEXT,CHR(32)||CHR(9)||CHR(10)||CHR(13)))-1)||'',"creditor_\u0074ype":''||((casefile#>''{respondent_account,order_details,order_terms,0}'')->''creditor_type'')::TEXT||''}'')::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('duplicate respondent_account.respondent.party_details {"organisation":false,"individual_details":{"surname":"Synthetic"},"aliases":[],"aliase\u0073":[]}',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''party_details''],''{"organisation":false,"individual_details":{"surname":"Synthetic"},"aliases":[],"aliase\u0073":[]}''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('duplicate respondent_account.respondent.party_details.individual_details {"surname":"Synthetic","other_personal_information":null,"other_personal_information":null}',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''party_details'',''individual_details''],''{"surname":"Synthetic","other_personal_information":null,"other_personal_information":null}''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('duplicate respondent_account.respondent.debtor_details {"employer_name":null,"employer_\u006eame":null}',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''{"employer_name":null,"employer_\u006eame":null}''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('duplicate respondent_account.respondent.debtor_details {"employer_address":{"cjs_code":null,"cjs_code":null}}',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''{"employer_address":{"cjs_code":null,"cjs_code":null}}''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('source sequence None',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''minor_creditors'',''0'',''creditor_sequence''],NULL) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid minor creditor correlation'),
('source sequence null',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''minor_creditors'',''0'',''creditor_sequence''],''null''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid minor creditor correlation'),
('source sequence "7"',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''minor_creditors'',''0'',''creditor_sequence''],''"7"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid minor creditor correlation'),
('source sequence 0',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''minor_creditors'',''0'',''creditor_sequence''],''0''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid minor creditor correlation'),
('source sequence -1',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''minor_creditors'',''0'',''creditor_sequence''],''-1''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid minor creditor correlation'),
('source sequence 1.5',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''minor_creditors'',''0'',''creditor_sequence''],''1.5''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid minor creditor correlation'),
('source sequence 2147483648',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''minor_creditors'',''0'',''creditor_sequence''],''2147483648''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid minor creditor correlation'),
('source sequence true',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''minor_creditors'',''0'',''creditor_sequence''],''true''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid minor creditor correlation'),
('duplicate source sequence',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''minor_creditors''],(''[''||(casefile->''minor_creditors''->0)::TEXT||'',''||(casefile->''minor_creditors''->0)::TEXT||'']'')::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid minor creditor correlation'),
('discriminator None',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''creditor_type''],NULL) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid creditor routing'),
('discriminator null',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''creditor_type''],''null''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid creditor routing'),
('discriminator 1',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''creditor_type''],''1''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid creditor routing'),
('discriminator true',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''creditor_type''],''true''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid creditor routing'),
('discriminator "applicant"',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''creditor_type''],''"applicant"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid creditor routing'),
('discriminator ""',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''creditor_type''],''""''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid creditor routing'),
('discriminator "Unknown"',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''creditor_type''],''"Unknown"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid creditor routing'),
('Applicant conflicting minor_creditor_sequence',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''minor_creditor_sequence''],''null''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid creditor routing'),
('Applicant conflicting major_creditor_code',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''major_creditor_code''],''null''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid creditor routing'),
('Minor selector None',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''creditor_type''],''"Minor Creditor"''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''minor_creditor_sequence''],NULL) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid creditor routing'),
('Minor selector null',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''creditor_type''],''"Minor Creditor"''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''minor_creditor_sequence''],''null''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid minor creditor correlation'),
('Minor selector "7"',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''creditor_type''],''"Minor Creditor"''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''minor_creditor_sequence''],''"7"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid minor creditor correlation'),
('Minor selector 0',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''creditor_type''],''"Minor Creditor"''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''minor_creditor_sequence''],''0''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid minor creditor correlation'),
('Minor selector 1.5',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''creditor_type''],''"Minor Creditor"''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''minor_creditor_sequence''],''1.5''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid minor creditor correlation'),
('Minor selector 2147483648',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''creditor_type''],''"Minor Creditor"''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''minor_creditor_sequence''],''2147483648''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid minor creditor correlation'),
('Minor selector 8',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''creditor_type''],''"Minor Creditor"''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''minor_creditor_sequence''],''8''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid minor creditor correlation'),
('Minor conflicting Major',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''creditor_type''],''"Minor Creditor"''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''minor_creditor_sequence''],''7''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''major_creditor_code''],''null''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid creditor routing'),
('Major selector None',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''creditor_type''],''"Major Creditor"''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''major_creditor_code''],NULL) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid creditor routing'),
('Major selector null',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''creditor_type''],''"Major Creditor"''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''major_creditor_code''],''null''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid creditor routing'),
('Major selector 1',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''creditor_type''],''"Major Creditor"''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''major_creditor_code''],''1''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid creditor routing'),
('Major selector true',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''creditor_type''],''"Major Creditor"''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''major_creditor_code''],''true''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid creditor routing'),
('Major selector ""',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''creditor_type''],''"Major Creditor"''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''major_creditor_code''],''""''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid creditor routing'),
('Major conflicting Minor',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''creditor_type''],''"Major Creditor"''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''major_creditor_code''],''"M55A"''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''minor_creditor_sequence''],''null''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid creditor routing'),
('legacy Major id alone',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''creditor_type''],''"Major Creditor"''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''major_creditor_id''],''-1065501''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid creditor routing'),
('Major exact lookup missing',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''creditor_type''],''"Major Creditor"''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''major_creditor_code''],''"missing"''::JSON) WHERE draft_casefile_id=-1065501;','P0002','query returned no rows'),
('Major exact lookup  M55A',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''creditor_type''],''"Major Creditor"''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''major_creditor_code''],''" M55A"''::JSON) WHERE draft_casefile_id=-1065501;','P0002','query returned no rows'),
('Major exact lookup m55a',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''creditor_type''],''"Major Creditor"''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''major_creditor_code''],''"m55a"''::JSON) WHERE draft_casefile_id=-1065501;','P0002','query returned no rows'),
('inactive Major',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''creditor_type''],''"Major Creditor"''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''major_creditor_code''],''"M55A"''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.major_creditors SET active=FALSE WHERE major_creditor_id=-1065501;','P0001','p_process_draft_casefiles: required reference is ineligible'),
('CA type null',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''central_authority_code''],''null''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('CA type 1',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''central_authority_code''],''1''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('CA type true',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''central_authority_code''],''true''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('CA exact lookup missing',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''central_authority_code''],''"missing"''::JSON) WHERE draft_casefile_id=-1065501;','P0002','query returned no rows'),
('CA exact lookup  C55A',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''central_authority_code''],''" C55A"''::JSON) WHERE draft_casefile_id=-1065501;','P0002','query returned no rows'),
('CA exact lookup c55a',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''central_authority_code''],''"c55a"''::JSON) WHERE draft_casefile_id=-1065501;','P0002','query returned no rows'),
('inactive CA',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''central_authority_code''],''"C55A"''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.major_creditors SET active=FALSE WHERE major_creditor_id=-1065503;','P0001','p_process_draft_casefiles: required reference is ineligible'),
('non CA reference',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''central_authority_code''],''"M55A"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: required reference is ineligible'),
('creditor free Result',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('missing Result',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55X"''::JSON) WHERE draft_casefile_id=-1065501;','P0002','query returned no rows'),
('later invalid route',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms''],(''[''||(casefile#>''{respondent_account,order_details,order_terms,0}'')::TEXT||'', {"result_id":"P55A","creditor_type":null}]'')::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid creditor routing'),
('linked account id only',-1065501,'DO $linked$ DECLARE v_id BIGINT; v_number VARCHAR; v_payload JSON; BEGIN SELECT p.payload->''respondent_account'' INTO v_payload FROM pdc_payloads p WHERE label=''base''; CALL public.p_insert_respondent_account(32055::SMALLINT,''REMO In''::public.t_casefile_type_enum,v_payload,NULL,NULL,v_id,v_number); UPDATE public.draft_casefiles SET account_id=v_id WHERE draft_casefile_id=-1065501; END; $linked$;','P0001','p_process_draft_casefiles: draft casefile already has publication identity'),
('linked account both',-1065501,'DO $linked$ DECLARE v_id BIGINT; v_number VARCHAR; v_payload JSON; BEGIN SELECT p.payload->''respondent_account'' INTO v_payload FROM pdc_payloads p WHERE label=''base''; CALL public.p_insert_respondent_account(32055::SMALLINT,''REMO In''::public.t_casefile_type_enum,v_payload,NULL,NULL,v_id,v_number); UPDATE public.draft_casefiles SET account_id=v_id,account_number=v_number WHERE draft_casefile_id=-1065501; END; $linked$;','P0001','p_process_draft_casefiles: draft casefile already has publication identity'),
('Debtor supplied leaf container employer_name{}',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''{"employer_name":{}}''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('Debtor supplied leaf container employer_name[]',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''{"employer_name":[]}''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('Debtor supplied leaf container employee_reference{}',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''{"employee_reference":{}}''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('Debtor supplied leaf container employee_reference[]',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''{"employee_reference":[]}''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('Debtor supplied leaf container employer_email_address{}',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''{"employer_email_address":{}}''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('Debtor supplied leaf container employer_email_address[]',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''{"employer_email_address":[]}''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('Debtor supplied leaf container employer_telephone_number{}',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''{"employer_telephone_number":{}}''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('Debtor supplied leaf container employer_telephone_number[]',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''{"employer_telephone_number":[]}''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('Debtor supplied address leaf container address_line_1{}',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''{"employer_address":{"address_line_1":{}}}''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('Debtor supplied address leaf container address_line_1[]',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''{"employer_address":{"address_line_1":[]}}''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('Debtor supplied address leaf container address_line_2{}',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''{"employer_address":{"address_line_2":{}}}''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('Debtor supplied address leaf container address_line_2[]',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''{"employer_address":{"address_line_2":[]}}''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('Debtor supplied address leaf container address_line_3{}',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''{"employer_address":{"address_line_3":{}}}''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('Debtor supplied address leaf container address_line_3[]',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''{"employer_address":{"address_line_3":[]}}''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('Debtor supplied address leaf container address_line_4{}',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''{"employer_address":{"address_line_4":{}}}''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('Debtor supplied address leaf container address_line_4[]',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''{"employer_address":{"address_line_4":[]}}''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('Debtor supplied address leaf container address_line_5{}',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''{"employer_address":{"address_line_5":{}}}''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('Debtor supplied address leaf container address_line_5[]',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''{"employer_address":{"address_line_5":[]}}''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('Debtor supplied address leaf container postcode{}',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''{"employer_address":{"postcode":{}}}''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('Debtor supplied address leaf container postcode[]',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''{"employer_address":{"postcode":[]}}''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('Debtor supplied address leaf container cjs_code{}',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''{"employer_address":{"cjs_code":{}}}''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('Debtor supplied address leaf container cjs_code[]',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''{"employer_address":{"cjs_code":[]}}''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('information container {}',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''party_details'',''individual_details'',''other_personal_information''],''{}''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('information container []',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''party_details'',''individual_details'',''other_personal_information''],''[]''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('information container 1',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''party_details'',''individual_details'',''other_personal_information''],''1''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('information container true',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''party_details'',''individual_details'',''other_personal_information''],''true''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: invalid publication structure'),
('Debtor guard accepts null',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''null''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('Debtor guard accepts {}',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''{}''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('Debtor guard accepts {"context":{"arbitrary":[1,2]}}',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''{"context":{"arbitrary":[1,2]}}''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('Debtor guard accepts {"employer_address":null}',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''{"employer_address":null}''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('Debtor guard accepts {"employer_address":{}}',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''{"employer_address":{}}''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('Debtor guard accepts {"employer_name":null,"employer_address":{"cjs_code":null}}',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''{"employer_name":null,"employer_address":{"cjs_code":null}}''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('Debtor guard accepts {"employee_reference":""}',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''{"employee_reference":""}''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('Debtor guard accepts {"employee_reference":" "}',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''{"employee_reference":" "}''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('Debtor guard accepts {"employee_reference":42}',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''{"employee_reference":42}''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('Debtor guard accepts {"employer_address":{"cjs_code":""}}',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''debtor_details''],''{"employer_address":{"cjs_code":""}}''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('optional Minors accepts []',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''minor_creditors''],''[]''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('optional Minors accepts None',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''minor_creditors''],NULL) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('source sequence accepts 1',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''minor_creditors'',''0'',''creditor_sequence''],''1''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('source sequence accepts 2147483647',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''minor_creditors'',''0'',''creditor_sequence''],''2147483647''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('source sequence accepts 7.0',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''minor_creditors'',''0'',''creditor_sequence''],''7.0''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('empty aliases accepted respondent_account.respondent',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''respondent'',''party_details'',''aliases''],''[]''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('empty aliases accepted applicant',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''applicant'',''party_details'',''aliases''],''[]''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('empty aliases accepted minor_creditors.0',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''minor_creditors'',''0'',''party_details'',''aliases''],''[]''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''result_id''],''"P55N"''::JSON) WHERE draft_casefile_id=-1065501;','P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('wrong BU M55A',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''creditor_type''],''"Major Creditor"''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''order_details'',''order_terms'',''0'',''major_creditor_code''],''"M55A"''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.major_creditors SET business_unit_id=32054 WHERE major_creditor_id=-1065501;','P0002','query returned no rows'),
('wrong BU C55A',-1065501,'UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY[''respondent_account'',''central_authority_code''],''"C55A"''::JSON) WHERE draft_casefile_id=-1065501;UPDATE public.major_creditors SET business_unit_id=32054 WHERE major_creditor_id=-1065503;','P0002','query returned no rows');

-- -----------------------------------------------------------------------------
-- Scenario: Persisted eligibility and consumed selection reject invalid publication.
-- Setup: Reset the owned draft/reference mutations before each single-defect case.
-- Expected: Exact error code/message, no successful OUT tuple and no row effects.
-- -----------------------------------------------------------------------------
-- -----------------------------------------------------------------------------
-- Scenario: Selection retains independent text and classifies numeric correlations.
-- Setup: An overwidth string precedes a creditor-free Result; numeric exponents
--        exceed NUMERIC storage in both source and term correlation positions.
-- Expected: Child-owned width stays deferred, while invalid int32 correlations
--           retain the orchestrator's fixed error without native cast overflow.
-- -----------------------------------------------------------------------------
INSERT INTO pdc_guard_cases VALUES
('independent information width stays child-owned',-1065501,
 $setup$UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(pg_temp.pdc_put(casefile,
 ARRAY['respondent_account','respondent','party_details','individual_details','other_personal_information'],TO_JSON(REPEAT('x',201))),
 ARRAY['respondent_account','order_details','order_terms','0','result_id'],'"P55N"'::JSON) WHERE draft_casefile_id=-1065501;$setup$,
 'P0001','p_process_draft_casefiles: unsupported creditor-free result'),
('source sequence exceeds NUMERIC capacity',-1065501,
 $setup$UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(casefile,ARRAY['minor_creditors','0','creditor_sequence'],'1e1000000'::JSON) WHERE draft_casefile_id=-1065501;$setup$,
 'P0001','p_process_draft_casefiles: invalid minor creditor correlation'),
('term sequence exceeds NUMERIC capacity',-1065501,
 $setup$UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_put(pg_temp.pdc_put(casefile,
 ARRAY['respondent_account','order_details','order_terms','0','creditor_type'],'"Minor Creditor"'::JSON),
 ARRAY['respondent_account','order_details','order_terms','0','minor_creditor_sequence'],'1e1000000'::JSON) WHERE draft_casefile_id=-1065501;$setup$,
 'P0001','p_process_draft_casefiles: invalid minor creditor correlation');

CREATE FUNCTION pg_temp.pdc_guard_assertions() RETURNS SETOF TEXT LANGUAGE plpgsql AS $checks$
DECLARE test RECORD; observed JSONB;
BEGIN
 FOR test IN SELECT * FROM pdc_guard_cases ORDER BY label LOOP
  UPDATE public.draft_casefiles SET casefile=(SELECT payload FROM pdc_payloads WHERE label='base'),
   casefile_status='PUBLISHING_PENDING',account_number=NULL,account_id=NULL,
   validated_date=TIMESTAMP '2024-01-02',validated_by='P55_APPROVE',
   validated_by_name='Synthetic saved approver',version_number=1 WHERE draft_casefile_id=-1065501;
  UPDATE public.major_creditors SET active=TRUE,business_unit_id=32055 WHERE major_creditor_id IN(-1065501,-1065503);
  IF test.setup<>'' THEN EXECUTE test.setup; END IF;
  observed:=pg_temp.pdc_call(test.input_id);
  RETURN NEXT is(observed->>'code',test.expected_code,test.label||': SQLSTATE');
  RETURN NEXT is(observed->>'message',test.expected_message,test.label||': fixed/native message');
  RETURN NEXT ok(observed->>'completed'='false' AND NOT(observed ? 'published_raw')
   AND observed->'before'=observed->'after',test.label||': no output or row effects');
 END LOOP;
END;
$checks$;
SELECT * FROM pg_temp.pdc_guard_assertions();


-- -----------------------------------------------------------------------------
-- Scenario: Publish original persisted sources through the nine unchanged helpers.
-- Setup: Independent synthetic payloads and literal expected role/value projections.
-- Expected: Complete graph, correct provenance, optional skips and identity-only output.
-- -----------------------------------------------------------------------------
CREATE TEMP TABLE pdc_graph_cases(ordinal INTEGER PRIMARY KEY,label TEXT,payload JSON,expected JSONB);
INSERT INTO pdc_graph_cases VALUES
(1,'minimal omitted optionals','{"respondent_account": {"application_code": "PDC55", "respondent": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Respondent"}, "address": {"address_line_1": "Respondent address", "cjs_code": 31056}}}, "order_details": {"date_ordered": "2024-01-01", "date_arrears_last_updated": "2024-01-01", "payment_period": "Monthly", "interest_flag": false, "indexation": "None", "payment_arrangement": "Court", "order_terms": [{"result_id": "P55A", "creditor_type": "Applicant", "result_responses": [{"parameter_name": "Amount", "response": "00012.30"}]}]}}, "applicant": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Applicant"}, "address": {"address_line_1": "Applicant address", "cjs_code": 31056}}, "bank_account_details": {"bank_account_type": "None or not applicable"}}}'::JSON,'{"roles": ["Respondent", "Applicant"], "routes": ["Applicant"], "amounts": [12.3], "debtor": null, "contacts": [], "aliases": [], "note": false, "ca": false, "sequences": []}'::JSON::JSONB),
(2,'empty Minors and empty aliases','{"respondent_account": {"application_code": "PDC55", "respondent": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Respondent"}, "address": {"address_line_1": "Respondent address", "cjs_code": 31056}, "aliases": []}}, "order_details": {"date_ordered": "2024-01-01", "date_arrears_last_updated": "2024-01-01", "payment_period": "Monthly", "interest_flag": false, "indexation": "None", "payment_arrangement": "Court", "order_terms": [{"result_id": "P55A", "creditor_type": "Applicant", "result_responses": [{"parameter_name": "Amount", "response": "00012.30"}]}]}}, "applicant": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Applicant"}, "address": {"address_line_1": "Applicant address", "cjs_code": 31056}, "aliases": []}, "bank_account_details": {"bank_account_type": "None or not applicable"}}, "minor_creditors": []}'::JSON,'{"roles": ["Respondent", "Applicant"], "routes": ["Applicant"], "amounts": [12.3], "debtor": null, "contacts": [], "aliases": [], "note": false, "ca": false, "sequences": []}'::JSON::JSONB),
(3,'all nine helpers mixed routes','{"respondent_account": {"application_code": "PDC55", "respondent": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Respondent", "other_personal_information": "Independent synthetic information"}, "address": {"address_line_1": "Respondent address", "cjs_code": 31056}, "aliases": [{"sequence_number": 2, "surname": "Respondent alias", "forenames": "Synthetic"}]}, "third_party_details": {"name": "Respondent contact", "relationship": "Respondent relation", "reference": "Respondent ref", "address": {"address_line_1": "Respondent contact address", "cjs_code": 31056}}, "debtor_details": {"employer_name": "Synthetic Employer", "employee_reference": "Synthetic employee", "employer_email_address": "synthetic@example.invalid", "employer_telephone_number": "0000000", "employer_address": {"address_line_1": "Synthetic employer address", "cjs_code": 31056}, "other_personal_information": "Wrong nested information"}}, "order_details": {"date_ordered": "2024-01-01", "date_arrears_last_updated": "2024-01-01", "payment_period": "Monthly", "interest_flag": false, "indexation": "None", "payment_arrangement": "Court", "order_terms": [{"result_id": "P55A", "creditor_type": "Major Creditor", "result_responses": [{"parameter_name": "Amount", "response": "1.10"}], "major_creditor_code": "M55B"}, {"result_id": "P55A", "creditor_type": "Minor Creditor", "result_responses": [{"parameter_name": "Amount", "response": "2.20"}], "minor_creditor_sequence": 7}, {"result_id": "P55A", "creditor_type": "Major Creditor", "result_responses": [{"parameter_name": "Amount", "response": "3.30"}], "major_creditor_code": "M55B"}, {"result_id": "P55A", "creditor_type": "Applicant", "result_responses": [{"parameter_name": "Amount", "response": "4.40"}]}, {"result_id": "P55A", "creditor_type": "Minor Creditor", "result_responses": [{"parameter_name": "Amount", "response": "5.50"}], "minor_creditor_sequence": 91}, {"result_id": "P55A", "creditor_type": "Major Creditor", "result_responses": [{"parameter_name": "Amount", "response": "6.60"}], "major_creditor_code": "M55A"}, {"result_id": "P55A", "creditor_type": "Major Creditor", "result_responses": [{"parameter_name": "Amount", "response": "7.70"}], "major_creditor_code": "M55B"}]}, "central_authority_code": "C55A", "notes": {"note_text": "Synthetic note \\ original \"text\""}, "originator_name": "Synthetic originator", "remo_reference": "Synthetic REMO", "central_authority_reference": "Synthetic CA", "account_comment": "Synthetic account comment"}, "applicant": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Applicant"}, "address": {"address_line_1": "Applicant address", "cjs_code": 31056}, "aliases": [{"sequence_number": 2, "surname": "Applicant alias", "forenames": "Synthetic"}]}, "bank_account_details": {"bank_account_type": "UK Bank", "uk_bank_details": {"account_name": "Synthetic bank", "sort_code": "001234", "account_number": "00012345", "payment_reference": "Synthetic ref"}}, "third_party_details": {"name": "Applicant contact", "relationship": "Applicant relation", "reference": "Applicant ref", "address": {"address_line_1": "Applicant contact address", "cjs_code": 31056}}}, "minor_creditors": [{"creditor_sequence": 91, "party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Minor Ninety One"}, "address": {"address_line_1": "Minor Ninety One address", "cjs_code": 31056}, "aliases": [{"sequence_number": 2, "surname": "Minor Ninety One alias", "forenames": "Synthetic"}]}, "bank_account_details": {"bank_account_type": "Non-UK Bank", "non_uk_bank_details": {"bank_name": "Synthetic foreign bank", "iban": "SYNTHETIC"}}}, {"creditor_sequence": 7, "party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Minor Seven"}, "address": {"address_line_1": "Minor Seven address", "cjs_code": 31056}, "aliases": [{"sequence_number": 2, "surname": "Minor Seven alias", "forenames": "Synthetic"}]}, "bank_account_details": {"bank_account_type": "None or not applicable"}}, {"creditor_sequence": 2147483647, "party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Unused Minor"}, "address": {"address_line_1": "Unused Minor address", "cjs_code": 31056}, "aliases": [{"sequence_number": 2, "surname": "Unused Minor alias", "forenames": "Synthetic"}]}, "bank_account_details": {"bank_account_type": "None or not applicable"}}]}'::JSON,'{"roles": ["Respondent", "Applicant", "Minor Ninety One", "Minor Seven", "Unused Minor"], "routes": ["Major B", "Minor Seven", "Major B", "Applicant", "Minor Ninety One", "Major A", "Major B"], "amounts": [1.1, 2.2, 3.3, 4.4, 5.5, 6.6, 7.7], "debtor": {"employer_name": "Synthetic Employer", "employee_reference": "Synthetic employee", "employer_email": "synthetic@example.invalid", "employer_telephone": "0000000", "employer_address_line_1": "Synthetic employer address", "employer_country_id": -1065502, "other_personal_information": "Independent synthetic information"}, "contacts": [{"role": "Respondent", "name_organisation": "Respondent contact", "relationship": "Respondent relation", "reference": "Respondent ref", "address_line_1": "Respondent contact address", "country": -1065502}, {"role": "Applicant", "name_organisation": "Applicant contact", "relationship": "Applicant relation", "reference": "Applicant ref", "address_line_1": "Applicant contact address", "country": -1065502}], "aliases": [{"role": "Respondent", "surname": "Respondent alias", "forenames": "Synthetic", "sequence_number": 2}, {"role": "Applicant", "surname": "Applicant alias", "forenames": "Synthetic", "sequence_number": 2}, {"role": "Minor Ninety One", "surname": "Minor Ninety One alias", "forenames": "Synthetic", "sequence_number": 2}, {"role": "Minor Seven", "surname": "Minor Seven alias", "forenames": "Synthetic", "sequence_number": 2}, {"role": "Unused Minor", "surname": "Unused Minor alias", "forenames": "Synthetic", "sequence_number": 2}], "note": true, "ca": true, "sequences": [91, 7, 2147483647]}'::JSON::JSONB),
(4,'second draft separate Major accounts','{"respondent_account": {"application_code": "PDC55", "respondent": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Respondent", "other_personal_information": "Independent synthetic information"}, "address": {"address_line_1": "Respondent address", "cjs_code": 31056}, "aliases": [{"sequence_number": 2, "surname": "Respondent alias", "forenames": "Synthetic"}]}, "third_party_details": {"name": "Respondent contact", "relationship": "Respondent relation", "reference": "Respondent ref", "address": {"address_line_1": "Respondent contact address", "cjs_code": 31056}}, "debtor_details": {"employer_name": "Synthetic Employer", "employee_reference": "Synthetic employee", "employer_email_address": "synthetic@example.invalid", "employer_telephone_number": "0000000", "employer_address": {"address_line_1": "Synthetic employer address", "cjs_code": 31056}, "other_personal_information": "Wrong nested information"}}, "order_details": {"date_ordered": "2024-01-01", "date_arrears_last_updated": "2024-01-01", "payment_period": "Monthly", "interest_flag": false, "indexation": "None", "payment_arrangement": "Court", "order_terms": [{"result_id": "P55A", "creditor_type": "Major Creditor", "result_responses": [{"parameter_name": "Amount", "response": "1.10"}], "major_creditor_code": "M55B"}, {"result_id": "P55A", "creditor_type": "Minor Creditor", "result_responses": [{"parameter_name": "Amount", "response": "2.20"}], "minor_creditor_sequence": 7}, {"result_id": "P55A", "creditor_type": "Major Creditor", "result_responses": [{"parameter_name": "Amount", "response": "3.30"}], "major_creditor_code": "M55B"}, {"result_id": "P55A", "creditor_type": "Applicant", "result_responses": [{"parameter_name": "Amount", "response": "4.40"}]}, {"result_id": "P55A", "creditor_type": "Minor Creditor", "result_responses": [{"parameter_name": "Amount", "response": "5.50"}], "minor_creditor_sequence": 91}, {"result_id": "P55A", "creditor_type": "Major Creditor", "result_responses": [{"parameter_name": "Amount", "response": "6.60"}], "major_creditor_code": "M55A"}, {"result_id": "P55A", "creditor_type": "Major Creditor", "result_responses": [{"parameter_name": "Amount", "response": "7.70"}], "major_creditor_code": "M55B"}]}, "central_authority_code": "C55A", "notes": {"note_text": "Synthetic note \\ original \"text\""}, "originator_name": "Synthetic originator", "remo_reference": "Synthetic REMO", "central_authority_reference": "Synthetic CA", "account_comment": "Synthetic account comment"}, "applicant": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Applicant"}, "address": {"address_line_1": "Applicant address", "cjs_code": 31056}, "aliases": [{"sequence_number": 2, "surname": "Applicant alias", "forenames": "Synthetic"}]}, "bank_account_details": {"bank_account_type": "UK Bank", "uk_bank_details": {"account_name": "Synthetic bank", "sort_code": "001234", "account_number": "00012345", "payment_reference": "Synthetic ref"}}, "third_party_details": {"name": "Applicant contact", "relationship": "Applicant relation", "reference": "Applicant ref", "address": {"address_line_1": "Applicant contact address", "cjs_code": 31056}}}, "minor_creditors": [{"creditor_sequence": 91, "party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Minor Ninety One"}, "address": {"address_line_1": "Minor Ninety One address", "cjs_code": 31056}, "aliases": [{"sequence_number": 2, "surname": "Minor Ninety One alias", "forenames": "Synthetic"}]}, "bank_account_details": {"bank_account_type": "Non-UK Bank", "non_uk_bank_details": {"bank_name": "Synthetic foreign bank", "iban": "SYNTHETIC"}}}, {"creditor_sequence": 7, "party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Minor Seven"}, "address": {"address_line_1": "Minor Seven address", "cjs_code": 31056}, "aliases": [{"sequence_number": 2, "surname": "Minor Seven alias", "forenames": "Synthetic"}]}, "bank_account_details": {"bank_account_type": "None or not applicable"}}, {"creditor_sequence": 2147483647, "party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Unused Minor"}, "address": {"address_line_1": "Unused Minor address", "cjs_code": 31056}, "aliases": [{"sequence_number": 2, "surname": "Unused Minor alias", "forenames": "Synthetic"}]}, "bank_account_details": {"bank_account_type": "None or not applicable"}}]}'::JSON,'{"roles": ["Respondent", "Applicant", "Minor Ninety One", "Minor Seven", "Unused Minor"], "routes": ["Major B", "Minor Seven", "Major B", "Applicant", "Minor Ninety One", "Major A", "Major B"], "amounts": [1.1, 2.2, 3.3, 4.4, 5.5, 6.6, 7.7], "debtor": {"employer_name": "Synthetic Employer", "employee_reference": "Synthetic employee", "employer_email": "synthetic@example.invalid", "employer_telephone": "0000000", "employer_address_line_1": "Synthetic employer address", "employer_country_id": -1065502, "other_personal_information": "Independent synthetic information"}, "contacts": [{"role": "Respondent", "name_organisation": "Respondent contact", "relationship": "Respondent relation", "reference": "Respondent ref", "address_line_1": "Respondent contact address", "country": -1065502}, {"role": "Applicant", "name_organisation": "Applicant contact", "relationship": "Applicant relation", "reference": "Applicant ref", "address_line_1": "Applicant contact address", "country": -1065502}], "aliases": [{"role": "Respondent", "surname": "Respondent alias", "forenames": "Synthetic", "sequence_number": 2}, {"role": "Applicant", "surname": "Applicant alias", "forenames": "Synthetic", "sequence_number": 2}, {"role": "Minor Ninety One", "surname": "Minor Ninety One alias", "forenames": "Synthetic", "sequence_number": 2}, {"role": "Minor Seven", "surname": "Minor Seven alias", "forenames": "Synthetic", "sequence_number": 2}, {"role": "Unused Minor", "surname": "Unused Minor alias", "forenames": "Synthetic", "sequence_number": 2}], "note": true, "ca": true, "sequences": [91, 7, 2147483647]}'::JSON::JSONB),
(5,'Debtor skipped null','{"respondent_account": {"application_code": "PDC55", "respondent": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Respondent"}, "address": {"address_line_1": "Respondent address", "cjs_code": 31056}}, "debtor_details": null}, "order_details": {"date_ordered": "2024-01-01", "date_arrears_last_updated": "2024-01-01", "payment_period": "Monthly", "interest_flag": false, "indexation": "None", "payment_arrangement": "Court", "order_terms": [{"result_id": "P55A", "creditor_type": "Applicant", "result_responses": [{"parameter_name": "Amount", "response": "00012.30"}]}]}}, "applicant": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Applicant"}, "address": {"address_line_1": "Applicant address", "cjs_code": 31056}}, "bank_account_details": {"bank_account_type": "None or not applicable"}}}'::JSON,'{"roles": ["Respondent", "Applicant"], "routes": ["Applicant"], "amounts": [12.3], "debtor": null, "contacts": [], "aliases": [], "note": false, "ca": false, "sequences": []}'::JSON::JSONB),
(6,'Debtor skipped empty','{"respondent_account": {"application_code": "PDC55", "respondent": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Respondent"}, "address": {"address_line_1": "Respondent address", "cjs_code": 31056}}, "debtor_details": {}}, "order_details": {"date_ordered": "2024-01-01", "date_arrears_last_updated": "2024-01-01", "payment_period": "Monthly", "interest_flag": false, "indexation": "None", "payment_arrangement": "Court", "order_terms": [{"result_id": "P55A", "creditor_type": "Applicant", "result_responses": [{"parameter_name": "Amount", "response": "00012.30"}]}]}}, "applicant": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Applicant"}, "address": {"address_line_1": "Applicant address", "cjs_code": 31056}}, "bank_account_details": {"bank_account_type": "None or not applicable"}}}'::JSON,'{"roles": ["Respondent", "Applicant"], "routes": ["Applicant"], "amounts": [12.3], "debtor": null, "contacts": [], "aliases": [], "note": false, "ca": false, "sequences": []}'::JSON::JSONB),
(7,'Debtor skipped unknown only','{"respondent_account": {"application_code": "PDC55", "respondent": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Respondent"}, "address": {"address_line_1": "Respondent address", "cjs_code": 31056}}, "debtor_details": {"context": "ignored"}}, "order_details": {"date_ordered": "2024-01-01", "date_arrears_last_updated": "2024-01-01", "payment_period": "Monthly", "interest_flag": false, "indexation": "None", "payment_arrangement": "Court", "order_terms": [{"result_id": "P55A", "creditor_type": "Applicant", "result_responses": [{"parameter_name": "Amount", "response": "00012.30"}]}]}}, "applicant": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Applicant"}, "address": {"address_line_1": "Applicant address", "cjs_code": 31056}}, "bank_account_details": {"bank_account_type": "None or not applicable"}}}'::JSON,'{"roles": ["Respondent", "Applicant"], "routes": ["Applicant"], "amounts": [12.3], "debtor": null, "contacts": [], "aliases": [], "note": false, "ca": false, "sequences": []}'::JSON::JSONB),
(8,'Debtor skipped mapped null','{"respondent_account": {"application_code": "PDC55", "respondent": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Respondent"}, "address": {"address_line_1": "Respondent address", "cjs_code": 31056}}, "debtor_details": {"employer_name": null, "employer_address": {"cjs_code": null}}}, "order_details": {"date_ordered": "2024-01-01", "date_arrears_last_updated": "2024-01-01", "payment_period": "Monthly", "interest_flag": false, "indexation": "None", "payment_arrangement": "Court", "order_terms": [{"result_id": "P55A", "creditor_type": "Applicant", "result_responses": [{"parameter_name": "Amount", "response": "00012.30"}]}]}}, "applicant": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Applicant"}, "address": {"address_line_1": "Applicant address", "cjs_code": 31056}}, "bank_account_details": {"bank_account_type": "None or not applicable"}}}'::JSON,'{"roles": ["Respondent", "Applicant"], "routes": ["Applicant"], "amounts": [12.3], "debtor": null, "contacts": [], "aliases": [], "note": false, "ca": false, "sequences": []}'::JSON::JSONB),
(9,'Debtor partial employer','{"respondent_account": {"application_code": "PDC55", "respondent": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Respondent"}, "address": {"address_line_1": "Respondent address", "cjs_code": 31056}}, "debtor_details": {"employer_name": "Synthetic partial"}}, "order_details": {"date_ordered": "2024-01-01", "date_arrears_last_updated": "2024-01-01", "payment_period": "Monthly", "interest_flag": false, "indexation": "None", "payment_arrangement": "Court", "order_terms": [{"result_id": "P55A", "creditor_type": "Applicant", "result_responses": [{"parameter_name": "Amount", "response": "00012.30"}]}]}}, "applicant": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Applicant"}, "address": {"address_line_1": "Applicant address", "cjs_code": 31056}}, "bank_account_details": {"bank_account_type": "None or not applicable"}}}'::JSON,'{"roles": ["Respondent", "Applicant"], "routes": ["Applicant"], "amounts": [12.3], "debtor": {"employer_name": "Synthetic partial"}, "contacts": [], "aliases": [], "note": false, "ca": false, "sequences": []}'::JSON::JSONB),
(10,'Debtor empty supplied','{"respondent_account": {"application_code": "PDC55", "respondent": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Respondent"}, "address": {"address_line_1": "Respondent address", "cjs_code": 31056}}, "debtor_details": {"employer_name": ""}}, "order_details": {"date_ordered": "2024-01-01", "date_arrears_last_updated": "2024-01-01", "payment_period": "Monthly", "interest_flag": false, "indexation": "None", "payment_arrangement": "Court", "order_terms": [{"result_id": "P55A", "creditor_type": "Applicant", "result_responses": [{"parameter_name": "Amount", "response": "00012.30"}]}]}}, "applicant": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Applicant"}, "address": {"address_line_1": "Applicant address", "cjs_code": 31056}}, "bank_account_details": {"bank_account_type": "None or not applicable"}}}'::JSON,'{"roles": ["Respondent", "Applicant"], "routes": ["Applicant"], "amounts": [12.3], "debtor": {"employer_name": ""}, "contacts": [], "aliases": [], "note": false, "ca": false, "sequences": []}'::JSON::JSONB),
(11,'Debtor whitespace supplied','{"respondent_account": {"application_code": "PDC55", "respondent": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Respondent"}, "address": {"address_line_1": "Respondent address", "cjs_code": 31056}}, "debtor_details": {"employee_reference": "   "}}, "order_details": {"date_ordered": "2024-01-01", "date_arrears_last_updated": "2024-01-01", "payment_period": "Monthly", "interest_flag": false, "indexation": "None", "payment_arrangement": "Court", "order_terms": [{"result_id": "P55A", "creditor_type": "Applicant", "result_responses": [{"parameter_name": "Amount", "response": "00012.30"}]}]}}, "applicant": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Applicant"}, "address": {"address_line_1": "Applicant address", "cjs_code": 31056}}, "bank_account_details": {"bank_account_type": "None or not applicable"}}}'::JSON,'{"roles": ["Respondent", "Applicant"], "routes": ["Applicant"], "amounts": [12.3], "debtor": {"employee_reference": "   "}, "contacts": [], "aliases": [], "note": false, "ca": false, "sequences": []}'::JSON::JSONB),
(12,'Debtor Country only','{"respondent_account": {"application_code": "PDC55", "respondent": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Respondent"}, "address": {"address_line_1": "Respondent address", "cjs_code": 31056}}, "debtor_details": {"employer_address": {"cjs_code": 31056}}}, "order_details": {"date_ordered": "2024-01-01", "date_arrears_last_updated": "2024-01-01", "payment_period": "Monthly", "interest_flag": false, "indexation": "None", "payment_arrangement": "Court", "order_terms": [{"result_id": "P55A", "creditor_type": "Applicant", "result_responses": [{"parameter_name": "Amount", "response": "00012.30"}]}]}}, "applicant": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Applicant"}, "address": {"address_line_1": "Applicant address", "cjs_code": 31056}}, "bank_account_details": {"bank_account_type": "None or not applicable"}}}'::JSON,'{"roles": ["Respondent", "Applicant"], "routes": ["Applicant"], "amounts": [12.3], "debtor": {"employer_country_id": -1065502}, "contacts": [], "aliases": [], "note": false, "ca": false, "sequences": []}'::JSON::JSONB),
(13,'information only ''Independent only''','{"respondent_account": {"application_code": "PDC55", "respondent": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Respondent", "other_personal_information": "Independent only"}, "address": {"address_line_1": "Respondent address", "cjs_code": 31056}}}, "order_details": {"date_ordered": "2024-01-01", "date_arrears_last_updated": "2024-01-01", "payment_period": "Monthly", "interest_flag": false, "indexation": "None", "payment_arrangement": "Court", "order_terms": [{"result_id": "P55A", "creditor_type": "Applicant", "result_responses": [{"parameter_name": "Amount", "response": "00012.30"}]}]}}, "applicant": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Applicant"}, "address": {"address_line_1": "Applicant address", "cjs_code": 31056}}, "bank_account_details": {"bank_account_type": "None or not applicable"}}}'::JSON,'{"roles": ["Respondent", "Applicant"], "routes": ["Applicant"], "amounts": [12.3], "debtor": {"other_personal_information": "Independent only"}, "contacts": [], "aliases": [], "note": false, "ca": false, "sequences": []}'::JSON::JSONB),
(14,'information only ''''','{"respondent_account": {"application_code": "PDC55", "respondent": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Respondent", "other_personal_information": ""}, "address": {"address_line_1": "Respondent address", "cjs_code": 31056}}}, "order_details": {"date_ordered": "2024-01-01", "date_arrears_last_updated": "2024-01-01", "payment_period": "Monthly", "interest_flag": false, "indexation": "None", "payment_arrangement": "Court", "order_terms": [{"result_id": "P55A", "creditor_type": "Applicant", "result_responses": [{"parameter_name": "Amount", "response": "00012.30"}]}]}}, "applicant": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Applicant"}, "address": {"address_line_1": "Applicant address", "cjs_code": 31056}}, "bank_account_details": {"bank_account_type": "None or not applicable"}}}'::JSON,'{"roles": ["Respondent", "Applicant"], "routes": ["Applicant"], "amounts": [12.3], "debtor": {"other_personal_information": ""}, "contacts": [], "aliases": [], "note": false, "ca": false, "sequences": []}'::JSON::JSONB),
(15,'information only ''   ''','{"respondent_account": {"application_code": "PDC55", "respondent": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Respondent", "other_personal_information": "   "}, "address": {"address_line_1": "Respondent address", "cjs_code": 31056}}}, "order_details": {"date_ordered": "2024-01-01", "date_arrears_last_updated": "2024-01-01", "payment_period": "Monthly", "interest_flag": false, "indexation": "None", "payment_arrangement": "Court", "order_terms": [{"result_id": "P55A", "creditor_type": "Applicant", "result_responses": [{"parameter_name": "Amount", "response": "00012.30"}]}]}}, "applicant": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Applicant"}, "address": {"address_line_1": "Applicant address", "cjs_code": 31056}}, "bank_account_details": {"bank_account_type": "None or not applicable"}}}'::JSON,'{"roles": ["Respondent", "Applicant"], "routes": ["Applicant"], "amounts": [12.3], "debtor": {"other_personal_information": "   "}, "contacts": [], "aliases": [], "note": false, "ca": false, "sequences": []}'::JSON::JSONB),
(16,'permissive leaf employer_name{}','{"respondent_account": {"application_code": "PDC55", "respondent": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Respondent"}, "address": {"address_line_1": "Respondent address", "cjs_code": 31056}}, "debtor_details": {"employer_name": {}}}, "order_details": {"date_ordered": "2024-01-01", "date_arrears_last_updated": "2024-01-01", "payment_period": "Monthly", "interest_flag": false, "indexation": "None", "payment_arrangement": "Court", "order_terms": [{"result_id": "P55A", "creditor_type": "Applicant", "result_responses": [{"parameter_name": "Amount", "response": "00012.30"}]}]}}, "applicant": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Applicant"}, "address": {"address_line_1": "Applicant address", "cjs_code": 31056}}, "bank_account_details": {"bank_account_type": "None or not applicable"}}}'::JSON,'{"roles": ["Respondent", "Applicant"], "routes": ["Applicant"], "amounts": [12.3], "debtor": {"employer_name": "{}"}, "contacts": [], "aliases": [], "note": false, "ca": false, "sequences": []}'::JSON::JSONB),
(17,'permissive leaf employer_name[]','{"respondent_account": {"application_code": "PDC55", "respondent": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Respondent"}, "address": {"address_line_1": "Respondent address", "cjs_code": 31056}}, "debtor_details": {"employer_name": []}}, "order_details": {"date_ordered": "2024-01-01", "date_arrears_last_updated": "2024-01-01", "payment_period": "Monthly", "interest_flag": false, "indexation": "None", "payment_arrangement": "Court", "order_terms": [{"result_id": "P55A", "creditor_type": "Applicant", "result_responses": [{"parameter_name": "Amount", "response": "00012.30"}]}]}}, "applicant": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Applicant"}, "address": {"address_line_1": "Applicant address", "cjs_code": 31056}}, "bank_account_details": {"bank_account_type": "None or not applicable"}}}'::JSON,'{"roles": ["Respondent", "Applicant"], "routes": ["Applicant"], "amounts": [12.3], "debtor": {"employer_name": "[]"}, "contacts": [], "aliases": [], "note": false, "ca": false, "sequences": []}'::JSON::JSONB),
(18,'permissive leaf employee_reference{}','{"respondent_account": {"application_code": "PDC55", "respondent": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Respondent"}, "address": {"address_line_1": "Respondent address", "cjs_code": 31056}}, "debtor_details": {"employee_reference": {}}}, "order_details": {"date_ordered": "2024-01-01", "date_arrears_last_updated": "2024-01-01", "payment_period": "Monthly", "interest_flag": false, "indexation": "None", "payment_arrangement": "Court", "order_terms": [{"result_id": "P55A", "creditor_type": "Applicant", "result_responses": [{"parameter_name": "Amount", "response": "00012.30"}]}]}}, "applicant": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Applicant"}, "address": {"address_line_1": "Applicant address", "cjs_code": 31056}}, "bank_account_details": {"bank_account_type": "None or not applicable"}}}'::JSON,'{"roles": ["Respondent", "Applicant"], "routes": ["Applicant"], "amounts": [12.3], "debtor": {"employee_reference": "{}"}, "contacts": [], "aliases": [], "note": false, "ca": false, "sequences": []}'::JSON::JSONB),
(19,'permissive leaf employee_reference[]','{"respondent_account": {"application_code": "PDC55", "respondent": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Respondent"}, "address": {"address_line_1": "Respondent address", "cjs_code": 31056}}, "debtor_details": {"employee_reference": []}}, "order_details": {"date_ordered": "2024-01-01", "date_arrears_last_updated": "2024-01-01", "payment_period": "Monthly", "interest_flag": false, "indexation": "None", "payment_arrangement": "Court", "order_terms": [{"result_id": "P55A", "creditor_type": "Applicant", "result_responses": [{"parameter_name": "Amount", "response": "00012.30"}]}]}}, "applicant": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Applicant"}, "address": {"address_line_1": "Applicant address", "cjs_code": 31056}}, "bank_account_details": {"bank_account_type": "None or not applicable"}}}'::JSON,'{"roles": ["Respondent", "Applicant"], "routes": ["Applicant"], "amounts": [12.3], "debtor": {"employee_reference": "[]"}, "contacts": [], "aliases": [], "note": false, "ca": false, "sequences": []}'::JSON::JSONB),
(20,'permissive leaf employer_email_address{}','{"respondent_account": {"application_code": "PDC55", "respondent": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Respondent"}, "address": {"address_line_1": "Respondent address", "cjs_code": 31056}}, "debtor_details": {"employer_email_address": {}}}, "order_details": {"date_ordered": "2024-01-01", "date_arrears_last_updated": "2024-01-01", "payment_period": "Monthly", "interest_flag": false, "indexation": "None", "payment_arrangement": "Court", "order_terms": [{"result_id": "P55A", "creditor_type": "Applicant", "result_responses": [{"parameter_name": "Amount", "response": "00012.30"}]}]}}, "applicant": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Applicant"}, "address": {"address_line_1": "Applicant address", "cjs_code": 31056}}, "bank_account_details": {"bank_account_type": "None or not applicable"}}}'::JSON,'{"roles": ["Respondent", "Applicant"], "routes": ["Applicant"], "amounts": [12.3], "debtor": {"employer_email": "{}"}, "contacts": [], "aliases": [], "note": false, "ca": false, "sequences": []}'::JSON::JSONB),
(21,'permissive leaf employer_email_address[]','{"respondent_account": {"application_code": "PDC55", "respondent": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Respondent"}, "address": {"address_line_1": "Respondent address", "cjs_code": 31056}}, "debtor_details": {"employer_email_address": []}}, "order_details": {"date_ordered": "2024-01-01", "date_arrears_last_updated": "2024-01-01", "payment_period": "Monthly", "interest_flag": false, "indexation": "None", "payment_arrangement": "Court", "order_terms": [{"result_id": "P55A", "creditor_type": "Applicant", "result_responses": [{"parameter_name": "Amount", "response": "00012.30"}]}]}}, "applicant": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Applicant"}, "address": {"address_line_1": "Applicant address", "cjs_code": 31056}}, "bank_account_details": {"bank_account_type": "None or not applicable"}}}'::JSON,'{"roles": ["Respondent", "Applicant"], "routes": ["Applicant"], "amounts": [12.3], "debtor": {"employer_email": "[]"}, "contacts": [], "aliases": [], "note": false, "ca": false, "sequences": []}'::JSON::JSONB),
(22,'permissive leaf employer_telephone_number{}','{"respondent_account": {"application_code": "PDC55", "respondent": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Respondent"}, "address": {"address_line_1": "Respondent address", "cjs_code": 31056}}, "debtor_details": {"employer_telephone_number": {}}}, "order_details": {"date_ordered": "2024-01-01", "date_arrears_last_updated": "2024-01-01", "payment_period": "Monthly", "interest_flag": false, "indexation": "None", "payment_arrangement": "Court", "order_terms": [{"result_id": "P55A", "creditor_type": "Applicant", "result_responses": [{"parameter_name": "Amount", "response": "00012.30"}]}]}}, "applicant": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Applicant"}, "address": {"address_line_1": "Applicant address", "cjs_code": 31056}}, "bank_account_details": {"bank_account_type": "None or not applicable"}}}'::JSON,'{"roles": ["Respondent", "Applicant"], "routes": ["Applicant"], "amounts": [12.3], "debtor": {"employer_telephone": "{}"}, "contacts": [], "aliases": [], "note": false, "ca": false, "sequences": []}'::JSON::JSONB),
(23,'permissive leaf employer_telephone_number[]','{"respondent_account": {"application_code": "PDC55", "respondent": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Respondent"}, "address": {"address_line_1": "Respondent address", "cjs_code": 31056}}, "debtor_details": {"employer_telephone_number": []}}, "order_details": {"date_ordered": "2024-01-01", "date_arrears_last_updated": "2024-01-01", "payment_period": "Monthly", "interest_flag": false, "indexation": "None", "payment_arrangement": "Court", "order_terms": [{"result_id": "P55A", "creditor_type": "Applicant", "result_responses": [{"parameter_name": "Amount", "response": "00012.30"}]}]}}, "applicant": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Applicant"}, "address": {"address_line_1": "Applicant address", "cjs_code": 31056}}, "bank_account_details": {"bank_account_type": "None or not applicable"}}}'::JSON,'{"roles": ["Respondent", "Applicant"], "routes": ["Applicant"], "amounts": [12.3], "debtor": {"employer_telephone": "[]"}, "contacts": [], "aliases": [], "note": false, "ca": false, "sequences": []}'::JSON::JSONB),
(24,'permissive leaf address_line_1{}','{"respondent_account": {"application_code": "PDC55", "respondent": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Respondent"}, "address": {"address_line_1": "Respondent address", "cjs_code": 31056}}, "debtor_details": {"employer_address": {"address_line_1": {}}}}, "order_details": {"date_ordered": "2024-01-01", "date_arrears_last_updated": "2024-01-01", "payment_period": "Monthly", "interest_flag": false, "indexation": "None", "payment_arrangement": "Court", "order_terms": [{"result_id": "P55A", "creditor_type": "Applicant", "result_responses": [{"parameter_name": "Amount", "response": "00012.30"}]}]}}, "applicant": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Applicant"}, "address": {"address_line_1": "Applicant address", "cjs_code": 31056}}, "bank_account_details": {"bank_account_type": "None or not applicable"}}}'::JSON,'{"roles": ["Respondent", "Applicant"], "routes": ["Applicant"], "amounts": [12.3], "debtor": {"employer_address_line_1": "{}"}, "contacts": [], "aliases": [], "note": false, "ca": false, "sequences": []}'::JSON::JSONB),
(25,'permissive leaf address_line_1[]','{"respondent_account": {"application_code": "PDC55", "respondent": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Respondent"}, "address": {"address_line_1": "Respondent address", "cjs_code": 31056}}, "debtor_details": {"employer_address": {"address_line_1": []}}}, "order_details": {"date_ordered": "2024-01-01", "date_arrears_last_updated": "2024-01-01", "payment_period": "Monthly", "interest_flag": false, "indexation": "None", "payment_arrangement": "Court", "order_terms": [{"result_id": "P55A", "creditor_type": "Applicant", "result_responses": [{"parameter_name": "Amount", "response": "00012.30"}]}]}}, "applicant": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Applicant"}, "address": {"address_line_1": "Applicant address", "cjs_code": 31056}}, "bank_account_details": {"bank_account_type": "None or not applicable"}}}'::JSON,'{"roles": ["Respondent", "Applicant"], "routes": ["Applicant"], "amounts": [12.3], "debtor": {"employer_address_line_1": "[]"}, "contacts": [], "aliases": [], "note": false, "ca": false, "sequences": []}'::JSON::JSONB),
(26,'permissive leaf address_line_2{}','{"respondent_account": {"application_code": "PDC55", "respondent": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Respondent"}, "address": {"address_line_1": "Respondent address", "cjs_code": 31056}}, "debtor_details": {"employer_address": {"address_line_2": {}}}}, "order_details": {"date_ordered": "2024-01-01", "date_arrears_last_updated": "2024-01-01", "payment_period": "Monthly", "interest_flag": false, "indexation": "None", "payment_arrangement": "Court", "order_terms": [{"result_id": "P55A", "creditor_type": "Applicant", "result_responses": [{"parameter_name": "Amount", "response": "00012.30"}]}]}}, "applicant": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Applicant"}, "address": {"address_line_1": "Applicant address", "cjs_code": 31056}}, "bank_account_details": {"bank_account_type": "None or not applicable"}}}'::JSON,'{"roles": ["Respondent", "Applicant"], "routes": ["Applicant"], "amounts": [12.3], "debtor": {"employer_address_line_2": "{}"}, "contacts": [], "aliases": [], "note": false, "ca": false, "sequences": []}'::JSON::JSONB),
(27,'permissive leaf address_line_2[]','{"respondent_account": {"application_code": "PDC55", "respondent": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Respondent"}, "address": {"address_line_1": "Respondent address", "cjs_code": 31056}}, "debtor_details": {"employer_address": {"address_line_2": []}}}, "order_details": {"date_ordered": "2024-01-01", "date_arrears_last_updated": "2024-01-01", "payment_period": "Monthly", "interest_flag": false, "indexation": "None", "payment_arrangement": "Court", "order_terms": [{"result_id": "P55A", "creditor_type": "Applicant", "result_responses": [{"parameter_name": "Amount", "response": "00012.30"}]}]}}, "applicant": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Applicant"}, "address": {"address_line_1": "Applicant address", "cjs_code": 31056}}, "bank_account_details": {"bank_account_type": "None or not applicable"}}}'::JSON,'{"roles": ["Respondent", "Applicant"], "routes": ["Applicant"], "amounts": [12.3], "debtor": {"employer_address_line_2": "[]"}, "contacts": [], "aliases": [], "note": false, "ca": false, "sequences": []}'::JSON::JSONB),
(28,'permissive leaf address_line_3{}','{"respondent_account": {"application_code": "PDC55", "respondent": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Respondent"}, "address": {"address_line_1": "Respondent address", "cjs_code": 31056}}, "debtor_details": {"employer_address": {"address_line_3": {}}}}, "order_details": {"date_ordered": "2024-01-01", "date_arrears_last_updated": "2024-01-01", "payment_period": "Monthly", "interest_flag": false, "indexation": "None", "payment_arrangement": "Court", "order_terms": [{"result_id": "P55A", "creditor_type": "Applicant", "result_responses": [{"parameter_name": "Amount", "response": "00012.30"}]}]}}, "applicant": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Applicant"}, "address": {"address_line_1": "Applicant address", "cjs_code": 31056}}, "bank_account_details": {"bank_account_type": "None or not applicable"}}}'::JSON,'{"roles": ["Respondent", "Applicant"], "routes": ["Applicant"], "amounts": [12.3], "debtor": {"employer_address_line_3": "{}"}, "contacts": [], "aliases": [], "note": false, "ca": false, "sequences": []}'::JSON::JSONB),
(29,'permissive leaf address_line_3[]','{"respondent_account": {"application_code": "PDC55", "respondent": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Respondent"}, "address": {"address_line_1": "Respondent address", "cjs_code": 31056}}, "debtor_details": {"employer_address": {"address_line_3": []}}}, "order_details": {"date_ordered": "2024-01-01", "date_arrears_last_updated": "2024-01-01", "payment_period": "Monthly", "interest_flag": false, "indexation": "None", "payment_arrangement": "Court", "order_terms": [{"result_id": "P55A", "creditor_type": "Applicant", "result_responses": [{"parameter_name": "Amount", "response": "00012.30"}]}]}}, "applicant": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Applicant"}, "address": {"address_line_1": "Applicant address", "cjs_code": 31056}}, "bank_account_details": {"bank_account_type": "None or not applicable"}}}'::JSON,'{"roles": ["Respondent", "Applicant"], "routes": ["Applicant"], "amounts": [12.3], "debtor": {"employer_address_line_3": "[]"}, "contacts": [], "aliases": [], "note": false, "ca": false, "sequences": []}'::JSON::JSONB),
(30,'permissive leaf address_line_4{}','{"respondent_account": {"application_code": "PDC55", "respondent": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Respondent"}, "address": {"address_line_1": "Respondent address", "cjs_code": 31056}}, "debtor_details": {"employer_address": {"address_line_4": {}}}}, "order_details": {"date_ordered": "2024-01-01", "date_arrears_last_updated": "2024-01-01", "payment_period": "Monthly", "interest_flag": false, "indexation": "None", "payment_arrangement": "Court", "order_terms": [{"result_id": "P55A", "creditor_type": "Applicant", "result_responses": [{"parameter_name": "Amount", "response": "00012.30"}]}]}}, "applicant": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Applicant"}, "address": {"address_line_1": "Applicant address", "cjs_code": 31056}}, "bank_account_details": {"bank_account_type": "None or not applicable"}}}'::JSON,'{"roles": ["Respondent", "Applicant"], "routes": ["Applicant"], "amounts": [12.3], "debtor": {"employer_address_line_4": "{}"}, "contacts": [], "aliases": [], "note": false, "ca": false, "sequences": []}'::JSON::JSONB),
(31,'permissive leaf address_line_4[]','{"respondent_account": {"application_code": "PDC55", "respondent": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Respondent"}, "address": {"address_line_1": "Respondent address", "cjs_code": 31056}}, "debtor_details": {"employer_address": {"address_line_4": []}}}, "order_details": {"date_ordered": "2024-01-01", "date_arrears_last_updated": "2024-01-01", "payment_period": "Monthly", "interest_flag": false, "indexation": "None", "payment_arrangement": "Court", "order_terms": [{"result_id": "P55A", "creditor_type": "Applicant", "result_responses": [{"parameter_name": "Amount", "response": "00012.30"}]}]}}, "applicant": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Applicant"}, "address": {"address_line_1": "Applicant address", "cjs_code": 31056}}, "bank_account_details": {"bank_account_type": "None or not applicable"}}}'::JSON,'{"roles": ["Respondent", "Applicant"], "routes": ["Applicant"], "amounts": [12.3], "debtor": {"employer_address_line_4": "[]"}, "contacts": [], "aliases": [], "note": false, "ca": false, "sequences": []}'::JSON::JSONB),
(32,'permissive leaf address_line_5{}','{"respondent_account": {"application_code": "PDC55", "respondent": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Respondent"}, "address": {"address_line_1": "Respondent address", "cjs_code": 31056}}, "debtor_details": {"employer_address": {"address_line_5": {}}}}, "order_details": {"date_ordered": "2024-01-01", "date_arrears_last_updated": "2024-01-01", "payment_period": "Monthly", "interest_flag": false, "indexation": "None", "payment_arrangement": "Court", "order_terms": [{"result_id": "P55A", "creditor_type": "Applicant", "result_responses": [{"parameter_name": "Amount", "response": "00012.30"}]}]}}, "applicant": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Applicant"}, "address": {"address_line_1": "Applicant address", "cjs_code": 31056}}, "bank_account_details": {"bank_account_type": "None or not applicable"}}}'::JSON,'{"roles": ["Respondent", "Applicant"], "routes": ["Applicant"], "amounts": [12.3], "debtor": {"employer_address_line_5": "{}"}, "contacts": [], "aliases": [], "note": false, "ca": false, "sequences": []}'::JSON::JSONB),
(33,'permissive leaf address_line_5[]','{"respondent_account": {"application_code": "PDC55", "respondent": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Respondent"}, "address": {"address_line_1": "Respondent address", "cjs_code": 31056}}, "debtor_details": {"employer_address": {"address_line_5": []}}}, "order_details": {"date_ordered": "2024-01-01", "date_arrears_last_updated": "2024-01-01", "payment_period": "Monthly", "interest_flag": false, "indexation": "None", "payment_arrangement": "Court", "order_terms": [{"result_id": "P55A", "creditor_type": "Applicant", "result_responses": [{"parameter_name": "Amount", "response": "00012.30"}]}]}}, "applicant": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Applicant"}, "address": {"address_line_1": "Applicant address", "cjs_code": 31056}}, "bank_account_details": {"bank_account_type": "None or not applicable"}}}'::JSON,'{"roles": ["Respondent", "Applicant"], "routes": ["Applicant"], "amounts": [12.3], "debtor": {"employer_address_line_5": "[]"}, "contacts": [], "aliases": [], "note": false, "ca": false, "sequences": []}'::JSON::JSONB),
(34,'permissive leaf postcode{}','{"respondent_account": {"application_code": "PDC55", "respondent": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Respondent"}, "address": {"address_line_1": "Respondent address", "cjs_code": 31056}}, "debtor_details": {"employer_address": {"postcode": {}}}}, "order_details": {"date_ordered": "2024-01-01", "date_arrears_last_updated": "2024-01-01", "payment_period": "Monthly", "interest_flag": false, "indexation": "None", "payment_arrangement": "Court", "order_terms": [{"result_id": "P55A", "creditor_type": "Applicant", "result_responses": [{"parameter_name": "Amount", "response": "00012.30"}]}]}}, "applicant": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Applicant"}, "address": {"address_line_1": "Applicant address", "cjs_code": 31056}}, "bank_account_details": {"bank_account_type": "None or not applicable"}}}'::JSON,'{"roles": ["Respondent", "Applicant"], "routes": ["Applicant"], "amounts": [12.3], "debtor": {"employer_postcode": "{}"}, "contacts": [], "aliases": [], "note": false, "ca": false, "sequences": []}'::JSON::JSONB),
(35,'permissive leaf postcode[]','{"respondent_account": {"application_code": "PDC55", "respondent": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Respondent"}, "address": {"address_line_1": "Respondent address", "cjs_code": 31056}}, "debtor_details": {"employer_address": {"postcode": []}}}, "order_details": {"date_ordered": "2024-01-01", "date_arrears_last_updated": "2024-01-01", "payment_period": "Monthly", "interest_flag": false, "indexation": "None", "payment_arrangement": "Court", "order_terms": [{"result_id": "P55A", "creditor_type": "Applicant", "result_responses": [{"parameter_name": "Amount", "response": "00012.30"}]}]}}, "applicant": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Applicant"}, "address": {"address_line_1": "Applicant address", "cjs_code": 31056}}, "bank_account_details": {"bank_account_type": "None or not applicable"}}}'::JSON,'{"roles": ["Respondent", "Applicant"], "routes": ["Applicant"], "amounts": [12.3], "debtor": {"employer_postcode": "[]"}, "contacts": [], "aliases": [], "note": false, "ca": false, "sequences": []}'::JSON::JSONB),
(36,'only Respondent contact','{"respondent_account": {"application_code": "PDC55", "respondent": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Respondent"}, "address": {"address_line_1": "Respondent address", "cjs_code": 31056}}, "third_party_details": {"name": "Respondent contact", "relationship": "Respondent relation", "reference": "Respondent ref", "address": {"address_line_1": "Respondent contact address", "cjs_code": 31056}}}, "order_details": {"date_ordered": "2024-01-01", "date_arrears_last_updated": "2024-01-01", "payment_period": "Monthly", "interest_flag": false, "indexation": "None", "payment_arrangement": "Court", "order_terms": [{"result_id": "P55A", "creditor_type": "Applicant", "result_responses": [{"parameter_name": "Amount", "response": "00012.30"}]}]}}, "applicant": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Applicant"}, "address": {"address_line_1": "Applicant address", "cjs_code": 31056}}, "bank_account_details": {"bank_account_type": "None or not applicable"}}}'::JSON,'{"roles": ["Respondent", "Applicant"], "routes": ["Applicant"], "amounts": [12.3], "debtor": null, "contacts": [{"role": "Respondent", "name_organisation": "Respondent contact", "relationship": "Respondent relation", "reference": "Respondent ref", "address_line_1": "Respondent contact address", "country": -1065502}], "aliases": [], "note": false, "ca": false, "sequences": []}'::JSON::JSONB),
(37,'only Applicant contact','{"respondent_account": {"application_code": "PDC55", "respondent": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Respondent"}, "address": {"address_line_1": "Respondent address", "cjs_code": 31056}}}, "order_details": {"date_ordered": "2024-01-01", "date_arrears_last_updated": "2024-01-01", "payment_period": "Monthly", "interest_flag": false, "indexation": "None", "payment_arrangement": "Court", "order_terms": [{"result_id": "P55A", "creditor_type": "Applicant", "result_responses": [{"parameter_name": "Amount", "response": "00012.30"}]}]}}, "applicant": {"party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Applicant"}, "address": {"address_line_1": "Applicant address", "cjs_code": 31056}}, "bank_account_details": {"bank_account_type": "None or not applicable"}, "third_party_details": {"name": "Applicant contact", "relationship": "Applicant relation", "reference": "Applicant ref", "address": {"address_line_1": "Applicant contact address", "cjs_code": 31056}}}}'::JSON,'{"roles": ["Respondent", "Applicant"], "routes": ["Applicant"], "amounts": [12.3], "debtor": null, "contacts": [{"role": "Applicant", "name_organisation": "Applicant contact", "relationship": "Applicant relation", "reference": "Applicant ref", "address_line_1": "Applicant contact address", "country": -1065502}], "aliases": [], "note": false, "ca": false, "sequences": []}'::JSON::JSONB);

INSERT INTO pdc_graph_cases SELECT 38,'one Minor only route with mandatory Applicant',pg_temp.pdc_put(pg_temp.pdc_put(payload,ARRAY['minor_creditors'],'[{"creditor_sequence": 7, "party_details": {"organisation": false, "individual_details": {"surname": "Synthetic Single Minor"}, "address": {"address_line_1": "Single Minor address", "cjs_code": 31056}, "aliases": []}, "bank_account_details": {"bank_account_type": "None or not applicable"}}]'::JSON),ARRAY['respondent_account','order_details','order_terms'],'[{"result_id": "P55A", "creditor_type": "Minor Creditor", "minor_creditor_sequence": 7, "result_responses": [{"parameter_name": "Amount", "response": "12.30"}]}]'::JSON),'{"roles": ["Respondent", "Applicant", "Single Minor"], "routes": ["Single Minor"], "amounts": [12.3], "debtor": null, "contacts": [], "aliases": [], "note": false, "ca": false, "sequences": [7]}'::JSON::JSONB FROM pdc_graph_cases WHERE ordinal=1;
INSERT INTO pdc_graph_cases SELECT 39,'one Major shared by three terms',pg_temp.pdc_put(payload,ARRAY['respondent_account','order_details','order_terms'],'[{"result_id": "P55A", "creditor_type": "Major Creditor", "major_creditor_code": "M55B", "result_responses": [{"parameter_name": "Amount", "response": "1.10"}]}, {"result_id": "P55A", "creditor_type": "Major Creditor", "major_creditor_code": "M55B", "result_responses": [{"parameter_name": "Amount", "response": "2.20"}]}, {"result_id": "P55A", "creditor_type": "Major Creditor", "major_creditor_code": "M55B", "result_responses": [{"parameter_name": "Amount", "response": "3.30"}]}]'::JSON),'{"roles": ["Respondent", "Applicant"], "routes": ["Major B", "Major B", "Major B"], "amounts": [1.1, 2.2, 3.3], "debtor": null, "contacts": [], "aliases": [], "note": false, "ca": false, "sequences": []}'::JSON::JSONB FROM pdc_graph_cases WHERE ordinal=1;

-- Preserve sequence state explicitly: SETVAL does not roll back with the transaction.
CREATE TEMP TABLE pdc_graph_sequence_state(name TEXT PRIMARY KEY,value BIGINT,called BOOLEAN);
DO $sequences$
DECLARE seq TEXT; last BIGINT; called BOOLEAN;
BEGIN
 FOREACH seq IN ARRAY ARRAY['party_id_seq','respondent_account_id_seq','creditor_account_id_seq'] LOOP
  EXECUTE FORMAT('SELECT last_value,is_called FROM public.%I',seq) INTO last,called;
  INSERT INTO pdc_graph_sequence_state VALUES(seq,last,called);
 END LOOP;
 IF EXISTS(SELECT 1 FROM public.parties WHERE party_id>=9007199254741000)
 OR EXISTS(SELECT 1 FROM public.creditor_accounts WHERE creditor_account_id>=9007199254741000)
 OR EXISTS(SELECT 1 FROM public.respondent_accounts WHERE respondent_account_id>=9007199254741000)
 OR EXISTS(SELECT 1 FROM public.major_creditors WHERE major_creditor_id=9007199254741000) THEN
  RAISE EXCEPTION 'Publication graph large identity fixture collision';
 END IF;
 PERFORM SETVAL('public.party_id_seq',9007199254742000,FALSE);
 PERFORM SETVAL('public.respondent_account_id_seq',9007199254743000,FALSE);
 PERFORM SETVAL('public.creditor_account_id_seq',9007199254741000,FALSE);
END;
$sequences$;
-- The first generated Applicant account deliberately coincides with a Major reference;
-- subsequent graphs must still route by the correct domain and create new Major accounts.
UPDATE public.major_creditors SET major_creditor_id=9007199254741000 WHERE major_creditor_id=-1065502;

CREATE FUNCTION pg_temp.pdc_graph_assertions() RETURNS SETOF TEXT LANGUAGE plpgsql AS $checks$
DECLARE test RECORD; observed JSONB; expected JSONB; payload JSON; published JSONB;
 actual JSONB; wanted JSONB; row_expected JSONB; role TEXT; target TEXT; ids JSONB;
 respondent BIGINT; applicant BIGINT; respondent_party BIGINT; contact_id BIGINT; debtor_id BIGINT;
 party_id BIGINT; creditor_id BIGINT; saved RECORD; previous_majors BIGINT[]; current_majors BIGINT[];
 graph_roles JSONB; term_row RECORD; i INTEGER; amount NUMERIC; total NUMERIC;
 today DATE := (TRANSACTION_TIMESTAMP() AT TIME ZONE 'Europe/London')::DATE;
BEGIN
 FOR test IN SELECT * FROM pdc_graph_cases ORDER BY ordinal LOOP
  expected:=test.expected;
  IF test.ordinal=3 THEN
   -- Deliberately overlap Respondent Party and Applicant account numeric domains.
   SELECT last_value+1 INTO creditor_id FROM public.creditor_account_id_seq;
   PERFORM SETVAL('public.party_id_seq',creditor_id,FALSE);
  END IF;
  payload:=pg_temp.pdc_put(test.payload,ARRAY['respondent_account','order_details','date_arrears_last_updated'],TO_JSON(today::TEXT));
  UPDATE public.draft_casefiles SET casefile=payload,casefile_status='PUBLISHING_PENDING',account_id=NULL,
   account_number=NULL,validated_date=TIMESTAMP '2024-01-02',validated_by='P55_APPROVE',
   validated_by_name='Synthetic saved approver',version_number=NULL
   WHERE draft_casefile_id=CASE WHEN test.ordinal=4 THEN -1065502 ELSE -1065501 END;
  UPDATE public.major_creditors SET active=TRUE,business_unit_id=32055
   WHERE major_creditor_id IN(-1065501,-1065503,9007199254741000);
  observed:=pg_temp.pdc_call(CASE WHEN test.ordinal=4 THEN -1065502 ELSE -1065501 END);
  RETURN NEXT is(observed->>'code',NULL::TEXT,test.label||': real-helper success');
  RETURN NEXT ok(observed->>'completed'='true' AND observed->>'respondent_id' IS NOT NULL
   AND observed->>'account_number' IS NOT NULL AND observed->>'published_raw' IS NOT NULL,
   test.label||': complete output tuple');
  published:=(observed->>'published_raw')::JSONB;
  respondent:=(observed->>'respondent_id')::BIGINT;
  ids:=observed->'created_ids';
  SELECT COALESCE(JSONB_AGG(JSONB_STRIP_NULLS(TO_JSONB(p)-'party_id') ORDER BY surname),'[]') INTO actual
  FROM public.parties p WHERE ids->'parties' @> TO_JSONB(ARRAY[p.party_id]);
  SELECT JSONB_AGG(JSONB_BUILD_OBJECT('organisation',FALSE,'surname','Synthetic '||value,
   'address_line_1',value||' address','restrict_personal_information',FALSE,'country_id',-1065502,
   'account_type',CASE WHEN value='Respondent' THEN 'Respondent' ELSE 'Minor Creditor' END) ORDER BY 'Synthetic '||value)
   INTO wanted FROM JSONB_ARRAY_ELEMENTS_TEXT(expected->'roles');
  RETURN NEXT is(actual,wanted,test.label||': every full Party row and inactive Country mapping');
  SELECT p.party_id INTO respondent_party FROM public.parties p
   WHERE ids->'parties' @> TO_JSONB(ARRAY[p.party_id]) AND surname='Synthetic Respondent';
  SELECT c.creditor_account_id INTO applicant FROM public.creditor_accounts c JOIN public.parties p ON p.party_id=c.minor_creditor_party_id
   WHERE ids->'creditor_accounts' @> TO_JSONB(ARRAY[c.creditor_account_id]) AND p.surname='Synthetic Applicant';
  SELECT COALESCE(JSONB_AGG(JSONB_STRIP_NULLS((TO_JSONB(a)-'alias_id'-'party_id')||
   JSONB_BUILD_OBJECT('role',SUBSTRING(p.surname FROM 11))) ORDER BY p.surname),'[]') INTO actual
   FROM public.aliases a JOIN public.parties p ON p.party_id=a.party_id
   WHERE ids->'aliases' @> TO_JSONB(ARRAY[a.alias_id]);
  SELECT COALESCE(JSONB_AGG(value ORDER BY value->>'role'),'[]') INTO wanted FROM JSONB_ARRAY_ELEMENTS(expected->'aliases');
  RETURN NEXT is(actual,wanted,test.label||': exact aliases on their owning Party');
  SELECT COALESCE(JSONB_AGG(JSONB_STRIP_NULLS(TO_JSONB(c)-'third_party_contact_id') ORDER BY name_organisation),'[]') INTO actual
   FROM public.third_party_contact c WHERE ids->'third_party_contact' @> TO_JSONB(ARRAY[c.third_party_contact_id]);
  SELECT COALESCE(JSONB_AGG(value-'role' ORDER BY value->>'name_organisation'),'[]') INTO wanted FROM JSONB_ARRAY_ELEMENTS(expected->'contacts');
  RETURN NEXT is(actual,wanted,test.label||': full separate contact rows');
  SELECT debtor_detail_id,third_party_contact_id INTO debtor_id,contact_id FROM public.respondent_accounts WHERE respondent_account_id=respondent;
  SELECT COALESCE(JSONB_AGG(JSONB_STRIP_NULLS(TO_JSONB(d)-'debtor_detail_id')),'[]') INTO actual
   FROM public.debtor_detail d WHERE ids->'debtor_detail' @> TO_JSONB(ARRAY[d.debtor_detail_id]);
  wanted:=CASE WHEN expected->'debtor'='null'::JSONB THEN '[]'::JSONB ELSE JSONB_BUILD_ARRAY(expected->'debtor') END;
  RETURN NEXT is(actual,wanted,test.label||': exact Debtor leaf values and independent information');
  RETURN NEXT ok(CASE WHEN expected->'debtor'='null'::JSONB THEN debtor_id IS NULL ELSE
   ids->'debtor_detail'=TO_JSONB(ARRAY[debtor_id]) END,test.label||': Debtor ID or SQL NULL handoff');
  RETURN NEXT ok(CASE WHEN EXISTS(SELECT 1 FROM JSONB_ARRAY_ELEMENTS(expected->'contacts') e WHERE e->>'role'='Respondent')
   THEN EXISTS(SELECT 1 FROM public.third_party_contact WHERE third_party_contact_id=contact_id AND name_organisation='Respondent contact')
   ELSE contact_id IS NULL END,test.label||': Respondent contact handoff');
  SELECT SUM(value::NUMERIC) INTO total FROM JSONB_ARRAY_ELEMENTS_TEXT(expected->'amounts');
  SELECT JSONB_STRIP_NULLS(TO_JSONB(r)-ARRAY['respondent_account_id','account_number','debtor_detail_id','third_party_contact_id','last_movement_date'])
   INTO actual FROM public.respondent_accounts r WHERE respondent_account_id=respondent;
  wanted:=JSONB_BUILD_OBJECT('business_unit_id',32055,'application_id',-10655,'imposed_hearing_date','2024-01-01T00:00:00',
   'account_balance',0,'orders_balance',0,'orders_amount',total,'payment_period','Monthly','total_arrears',0,
   'account_status','L','date_arrears_last_updated',today::TEXT||'T00:00:00','allow_cheques',TRUE,
   'cheque_clearance_period',10,'credit_trans_clearance_period',0,'casefile_type','REMO In','interest_flag',FALSE,
   'indexation','None','payment_arrangement','Court','version_number',1);
  IF (expected->>'note')::BOOLEAN THEN wanted:=wanted||'{"originator_name":"Synthetic originator","remo_reference":"Synthetic REMO","ca_reference":"Synthetic CA","account_comment":"Synthetic account comment"}'::JSONB; END IF;
  RETURN NEXT is(actual,wanted,test.label||': full Respondent row and real-helper financial values');
  RETURN NEXT ok((SELECT last_movement_date BETWEEN (TRANSACTION_TIMESTAMP() AT TIME ZONE 'UTC') AND (CLOCK_TIMESTAMP() AT TIME ZONE 'UTC')
   FROM public.respondent_accounts WHERE respondent_account_id=respondent),test.label||': Respondent generated timestamp');
  SELECT COALESCE(JSONB_AGG(JSONB_STRIP_NULLS((TO_JSONB(c)-ARRAY['creditor_account_id','account_number','minor_creditor_party_id','third_party_contact_id','major_creditor_id'])||
   JSONB_BUILD_OBJECT('role',CASE WHEN m.major_creditor_code='M55A' THEN 'Major A' WHEN m.major_creditor_code='M55B' THEN 'Major B' ELSE SUBSTRING(p.surname FROM 11) END,
    'contact',t.name_organisation)) ORDER BY COALESCE(m.major_creditor_code,p.surname)),'[]') INTO actual
   FROM public.creditor_accounts c LEFT JOIN public.parties p ON p.party_id=c.minor_creditor_party_id
   LEFT JOIN public.major_creditors m ON m.major_creditor_id=c.major_creditor_id
   LEFT JOIN public.third_party_contact t ON t.third_party_contact_id=c.third_party_contact_id
   WHERE ids->'creditor_accounts' @> TO_JSONB(ARRAY[c.creditor_account_id]);
  wanted:='[]';
  FOR role IN SELECT value FROM JSONB_ARRAY_ELEMENTS_TEXT(expected->'roles') WHERE value<>'Respondent' LOOP
   row_expected:=JSONB_BUILD_OBJECT('role',role,'business_unit_id',32055,'creditor_account_type','MN','from_suspense',FALSE,'hold_payout',FALSE,'pay_by_bacs',FALSE);
   IF role='Applicant' AND EXISTS(SELECT 1 FROM JSONB_ARRAY_ELEMENTS(expected->'contacts') e WHERE e->>'role'='Applicant') THEN
    row_expected:=row_expected||'{"contact":"Applicant contact"}';
   END IF;
   IF (expected->>'note')::BOOLEAN AND role='Applicant' THEN row_expected:=row_expected||'{"pay_by_bacs":true,"bank_sort_code":"001234","bank_account_number":"00012345","bank_account_name":"Synthetic bank","bank_account_reference":"Synthetic ref"}'; END IF;
   IF (expected->>'note')::BOOLEAN AND role='Minor Ninety One' THEN row_expected:=row_expected||'{"pay_by_bacs":true,"non_uk_bank_detail":{"bank_name":"Synthetic foreign bank","iban":"SYNTHETIC"}}'; END IF;
   wanted:=wanted||JSONB_BUILD_ARRAY(row_expected);
  END LOOP;
  FOR role IN SELECT DISTINCT value FROM JSONB_ARRAY_ELEMENTS_TEXT(expected->'routes') WHERE value LIKE 'Major %' LOOP
   wanted:=wanted||JSONB_BUILD_ARRAY(JSONB_BUILD_OBJECT('role',role,'business_unit_id',32055,'creditor_account_type','MJ','from_suspense',FALSE,'hold_payout',FALSE,'pay_by_bacs',FALSE));
  END LOOP;
  SELECT COALESCE(JSONB_AGG(value ORDER BY value->>'role'),'[]') INTO wanted FROM JSONB_ARRAY_ELEMENTS(wanted);
  SELECT COALESCE(JSONB_AGG(value ORDER BY value->>'role'),'[]') INTO actual FROM JSONB_ARRAY_ELEMENTS(actual);
  RETURN NEXT is(actual,wanted,test.label||': full creditor rows with correct Party/contact/Major domains');
  SELECT COALESCE(JSONB_AGG(JSONB_BUILD_OBJECT('association_type',a.association_type,'associated_account_id',a.associated_account_id) ORDER BY association_type::TEXT),'[]') INTO actual
   FROM public.respondent_account_parties a WHERE respondent_account_id=respondent;
  wanted:=JSONB_BUILD_ARRAY(JSONB_BUILD_OBJECT('association_type','Applicant','associated_account_id',applicant));
  IF (expected->>'ca')::BOOLEAN THEN wanted:=wanted||JSONB_BUILD_ARRAY(JSONB_BUILD_OBJECT('association_type','Central Authority','associated_account_id',-1065503)); END IF;
  wanted:=wanted||JSONB_BUILD_ARRAY(JSONB_BUILD_OBJECT('association_type','Respondent','associated_account_id',respondent_party));
  RETURN NEXT is(actual,wanted,test.label||': exact final fan-in and polymorphic identity domains');
  SELECT COALESCE(JSONB_AGG(JSONB_STRIP_NULLS((TO_JSONB(o)-ARRAY['order_terms_id','respondent_account_id','creditor_account_id','posted_date','result_responses'])||
   JSONB_BUILD_OBJECT('role',CASE WHEN m.major_creditor_code='M55A' THEN 'Major A' WHEN m.major_creditor_code='M55B' THEN 'Major B' ELSE SUBSTRING(p.surname FROM 11) END)) ORDER BY o.order_terms_id),'[]') INTO actual
   FROM public.order_terms o JOIN public.creditor_accounts c ON c.creditor_account_id=o.creditor_account_id
   LEFT JOIN public.parties p ON p.party_id=c.minor_creditor_party_id LEFT JOIN public.major_creditors m ON m.major_creditor_id=c.major_creditor_id
   WHERE o.respondent_account_id=respondent;
  wanted:='[]';
  FOR i IN 0..JSONB_ARRAY_LENGTH(expected->'routes')-1 LOOP
   wanted:=wanted||JSONB_BUILD_ARRAY(JSONB_BUILD_OBJECT('role',expected->'routes'->>i,'result_id','P55A',
    'posted_by','P55_SUBMIT','posted_by_name','Synthetic saved submitter','imposed_date','2024-01-01T00:00:00',
    'imposed_amount',expected->'amounts'->i,'completed',FALSE));
  END LOOP;
  RETURN NEXT is(actual,wanted,test.label||': all full term rows in source order with saved attribution');
  SELECT COALESCE(JSONB_AGG(result_responses::TEXT ORDER BY order_terms_id),'[]') INTO actual FROM public.order_terms WHERE respondent_account_id=respondent;
  SELECT JSONB_AGG((value->'result_responses')::TEXT ORDER BY ordinality) INTO wanted
   FROM JSON_ARRAY_ELEMENTS(payload#>'{respondent_account,order_details,order_terms}') WITH ORDINALITY;
  RETURN NEXT is(actual,wanted,test.label||': original response JSON text survives real helpers');
  RETURN NEXT ok(NOT EXISTS(SELECT 1 FROM public.order_terms WHERE respondent_account_id=respondent
   AND posted_date NOT BETWEEN (TRANSACTION_TIMESTAMP() AT TIME ZONE 'UTC') AND (CLOCK_TIMESTAMP() AT TIME ZONE 'UTC')),test.label||': generated term timestamps');
  SELECT COALESCE(JSONB_AGG(TO_JSONB(n)-'note_id'-'posted_date'),'[]') INTO actual FROM public.notes n
   WHERE ids->'notes' @> TO_JSONB(ARRAY[n.note_id]);
  wanted:=CASE WHEN (expected->>'note')::BOOLEAN THEN JSONB_BUILD_ARRAY(JSONB_BUILD_OBJECT('note_type','NT','associated_record_type','respondent_accounts',
   'associated_record_id',respondent::TEXT,'note_text','Synthetic note \ original "text"','posted_by','P55_SUBMIT','posted_by_name','Synthetic saved submitter')) ELSE '[]'::JSONB END;
  RETURN NEXT is(actual,wanted,test.label||': standard Note target and persisted submitter');
  RETURN NEXT ok(NOT EXISTS(SELECT 1 FROM public.notes WHERE ids->'notes' @> TO_JSONB(ARRAY[note_id])
   AND posted_date IS DISTINCT FROM TRANSACTION_TIMESTAMP() AT TIME ZONE 'UTC'),test.label||': Note transaction timestamp');
  SELECT JSONB_BUILD_OBJECT('respondent_account',JSONB_BUILD_OBJECT('account_id',r.respondent_account_id,'account_number',r.account_number),
   'applicant_account',(SELECT JSONB_BUILD_OBJECT('account_id',creditor_account_id,'account_number',account_number) FROM public.creditor_accounts WHERE creditor_account_id=applicant),
   'minor_creditor_accounts',COALESCE((SELECT JSONB_AGG(JSONB_BUILD_OBJECT('creditor_sequence',e.value,'account_id',c.creditor_account_id,'account_number',c.account_number) ORDER BY e.ordinality)
    FROM JSONB_ARRAY_ELEMENTS(expected->'sequences') WITH ORDINALITY e
    JOIN public.parties p ON p.surname='Synthetic '||(expected->'roles'->>(e.ordinality::INTEGER+1)) AND ids->'parties' @> TO_JSONB(ARRAY[p.party_id])
    JOIN public.creditor_accounts c ON c.minor_creditor_party_id=p.party_id),'[]'::JSONB)) INTO wanted
   FROM public.respondent_accounts r WHERE r.respondent_account_id=respondent;
  RETURN NEXT is(published,wanted,test.label||': exact identity-only output, int64 values and source Minor order');
  RETURN NEXT ok(JSONB_TYPEOF(published->'minor_creditor_accounts')='array'
   AND published#>>'{respondent_account,account_id}'=observed->>'respondent_id'
   AND published#>>'{respondent_account,account_number}'=observed->>'account_number',test.label||': scalar consistency and mandatory Minor array');
  SELECT COALESCE(JSONB_AGG(JSONB_BUILD_OBJECT('business_unit_id',business_unit_id,'account_number',account_number,'associated_record_type',associated_record_type) ORDER BY account_number),'[]') INTO actual
   FROM public.account_number_index a WHERE ids->'account_number_index' @> TO_JSONB(ARRAY[a.account_number_index_id]);
  SELECT COALESCE(JSONB_AGG(row ORDER BY row->>'account_number'),'[]') INTO wanted FROM (
   SELECT JSONB_BUILD_OBJECT('business_unit_id',32055,'account_number',account_number,'associated_record_type','respondent_accounts') row
    FROM public.respondent_accounts WHERE respondent_account_id=respondent UNION ALL
   SELECT JSONB_BUILD_OBJECT('business_unit_id',32055,'account_number',account_number,'associated_record_type','creditor_accounts')
    FROM public.creditor_accounts c WHERE ids->'creditor_accounts' @> TO_JSONB(ARRAY[c.creditor_account_id])) rows;
  RETURN NEXT is(actual,wanted,test.label||': exact reservations correspond to all generated accounts');
  SELECT ARRAY_AGG(c.creditor_account_id ORDER BY c.creditor_account_id) INTO current_majors FROM public.creditor_accounts c
   WHERE ids->'creditor_accounts' @> TO_JSONB(ARRAY[c.creditor_account_id]) AND creditor_account_type='MJ';
  RETURN NEXT ok(CASE WHEN test.ordinal=4 THEN CARDINALITY(previous_majors)=2 AND CARDINALITY(current_majors)=2
   AND NOT(previous_majors && current_majors) ELSE TRUE END,test.label||': Major accounts are invocation-local');
  IF test.ordinal=3 THEN previous_majors:=current_majors; END IF;
  RETURN NEXT ok(CASE WHEN test.ordinal=3 THEN respondent_party=applicant
   WHEN test.ordinal=1 THEN respondent_party<>applicant AND applicant=9007199254741000 ELSE TRUE END,
   test.label||': explicit coincident and shifted identity-domain fixtures');
  SELECT COALESCE(JSONB_AGG(m.major_creditor_code ORDER BY c.creditor_account_id),'[]') INTO actual
   FROM public.creditor_accounts c JOIN public.major_creditors m ON m.major_creditor_id=c.major_creditor_id
   WHERE ids->'creditor_accounts' @> TO_JSONB(ARRAY[c.creditor_account_id]);
  RETURN NEXT is(actual,CASE WHEN test.ordinal IN(3,4) THEN '["M55B","M55A"]'::JSONB WHEN test.ordinal=39 THEN '["M55B"]'::JSONB ELSE '[]'::JSONB END,
   test.label||': Major creation follows first source occurrence');
  RETURN NEXT ok(NOT EXISTS(SELECT 1 FROM JSONB_EACH(observed->'before') b
   WHERE NOT ((observed->'after'->b.key) @> b.value)),test.label||': every existing row and original draft JSON preserved');
  RETURN NEXT ok(NOT EXISTS(SELECT 1 FROM JSONB_EACH(observed->'before') b
   WHERE b.key IN('draft_casefiles','draft_raw','business_units','countries','major_creditors','maintenance_applications','results','configuration_items')
   AND observed->'after'->b.key IS DISTINCT FROM b.value),test.label||': drafts and references exactly unchanged');
  wanted:=JSONB_BUILD_OBJECT('parties',JSONB_ARRAY_LENGTH(expected->'roles'),'aliases',JSONB_ARRAY_LENGTH(expected->'aliases'),
   'third_party_contact',JSONB_ARRAY_LENGTH(expected->'contacts'),'debtor_detail',CASE WHEN expected->'debtor'='null'::JSONB THEN 0 ELSE 1 END,
   'respondent_accounts',1,'creditor_accounts',JSONB_ARRAY_LENGTH(expected->'roles')-1+(SELECT COUNT(DISTINCT value) FROM JSONB_ARRAY_ELEMENTS_TEXT(expected->'routes') WHERE value LIKE 'Major %'),
   'order_terms',JSONB_ARRAY_LENGTH(expected->'routes'),'notes',CASE WHEN (expected->>'note')::BOOLEAN THEN 1 ELSE 0 END,
   'respondent_account_parties',CASE WHEN (expected->>'ca')::BOOLEAN THEN 3 ELSE 2 END,
   'account_number_index',JSONB_ARRAY_LENGTH(expected->'roles')+(SELECT COUNT(DISTINCT value) FROM JSONB_ARRAY_ELEMENTS_TEXT(expected->'routes') WHERE value LIKE 'Major %'));
  SELECT JSONB_OBJECT_AGG(key,JSONB_ARRAY_LENGTH(value)) INTO actual FROM JSONB_EACH(ids);
  RETURN NEXT is(actual,wanted,test.label||': independent exact cardinalities for every graph table');
  RETURN NEXT ok(NOT EXISTS(SELECT 1 FROM public.creditor_accounts c
   WHERE ids->'creditor_accounts' @> TO_JSONB(ARRAY[c.creditor_account_id]) AND (
    (c.creditor_account_type='MN' AND NOT(ids->'parties' @> TO_JSONB(ARRAY[c.minor_creditor_party_id])))
    OR (c.third_party_contact_id IS NOT NULL AND NOT(ids->'third_party_contact' @> TO_JSONB(ARRAY[c.third_party_contact_id])))))
   AND NOT EXISTS(SELECT 1 FROM public.aliases a WHERE ids->'aliases' @> TO_JSONB(ARRAY[a.alias_id])
    AND NOT(ids->'parties' @> TO_JSONB(ARRAY[a.party_id])))
   AND NOT EXISTS(SELECT 1 FROM public.order_terms o WHERE ids->'order_terms' @> TO_JSONB(ARRAY[o.order_terms_id])
    AND (o.respondent_account_id IS DISTINCT FROM respondent OR NOT(ids->'creditor_accounts' @> TO_JSONB(ARRAY[o.creditor_account_id]))))
   AND (contact_id IS NULL OR ids->'third_party_contact' @> TO_JSONB(ARRAY[contact_id])),
   test.label||': every role FK belongs to this invocation, never an older same-name graph');
 END LOOP;
EXCEPTION WHEN query_canceled OR assert_failure OR OTHERS THEN
 FOR saved IN SELECT * FROM pdc_graph_sequence_state LOOP
  PERFORM SETVAL('public.'||saved.name,saved.value,saved.called);
 END LOOP;
 RAISE;
END;
$checks$;
SELECT * FROM pg_temp.pdc_graph_assertions();

-- Scenario: Permissive supplied leaves reach real Debtor conversion/width checks.
-- Setup: Keep the rest of the graph valid; observe exact child failures and rollback.
-- Expected: Native conversion/child width errors, no successful tuple, no graph effects.
CREATE FUNCTION pg_temp.pdc_debtor_handoff_failures() RETURNS SETOF TEXT LANGUAGE plpgsql AS $checks$
DECLARE test RECORD; payload JSON; observed JSONB; saved RECORD;
BEGIN
 FOR test IN SELECT * FROM (VALUES
  ('object Country','{"employer_address":{"cjs_code":{}}}'::JSON,NULL::TEXT,'22P02'),
  ('array Country','{"employer_address":{"cjs_code":[]}}'::JSON,NULL::TEXT,'22P02'),
  ('empty Country','{"employer_address":{"cjs_code":""}}'::JSON,NULL::TEXT,'22P02'),
  ('whitespace Country','{"employer_address":{"cjs_code":"   "}}'::JSON,NULL::TEXT,'22P02'),
  ('independent information width',NULL::JSON,REPEAT('x',201),'22001')
 ) cases(label,debtor,information,code) LOOP
  SELECT g.payload INTO payload FROM pdc_graph_cases g WHERE ordinal=1;
  payload:=pg_temp.pdc_put(payload,ARRAY['respondent_account','respondent','debtor_details'],test.debtor);
  IF test.information IS NOT NULL THEN
   payload:=pg_temp.pdc_put(payload,ARRAY['respondent_account','respondent','party_details','individual_details','other_personal_information'],TO_JSON(test.information));
  END IF;
  UPDATE public.draft_casefiles SET casefile=payload WHERE draft_casefile_id=-1065501;
  observed:=pg_temp.pdc_call(-1065501);
  RETURN NEXT is(observed->>'code',test.code,test.label||': unchanged real Debtor error');
  RETURN NEXT ok(POSITION('p_insert_debtor_detail' IN observed->>'context')>0,test.label||': real child reached');
  RETURN NEXT ok(observed->>'completed'='false' AND NOT(observed ? 'published_raw')
   AND observed->'before'=observed->'after',test.label||': no output or row effects');
 END LOOP;
EXCEPTION WHEN query_canceled OR assert_failure OR OTHERS THEN
 FOR saved IN SELECT * FROM pdc_graph_sequence_state LOOP
  PERFORM SETVAL('public.'||saved.name,saved.value,saved.called);
 END LOOP;
 RAISE;
END;
$checks$;
SELECT * FROM pg_temp.pdc_debtor_handoff_failures();
-- Restore manipulated sequences after every graph check. Ordinary nextval consumption is not asserted gap-free.
DO $restore$ DECLARE saved RECORD; BEGIN
 FOR saved IN SELECT * FROM pdc_graph_sequence_state LOOP
  PERFORM SETVAL('public.'||saved.name,saved.value,saved.called);
 END LOOP;
END; $restore$;

SELECT ok((SELECT ROW(last_value,is_called) FROM public.party_id_seq) IS NOT DISTINCT FROM
 (SELECT ROW(value,called) FROM pdc_graph_sequence_state WHERE name='party_id_seq'),
 'explicit SETVAL state restored: party_id_seq');
SELECT ok((SELECT ROW(last_value,is_called) FROM public.respondent_account_id_seq) IS NOT DISTINCT FROM
 (SELECT ROW(value,called) FROM pdc_graph_sequence_state WHERE name='respondent_account_id_seq'),
 'explicit SETVAL state restored: respondent_account_id_seq');
SELECT ok((SELECT ROW(last_value,is_called) FROM public.creditor_account_id_seq) IS NOT DISTINCT FROM
 (SELECT ROW(value,called) FROM pdc_graph_sequence_state WHERE name='creditor_account_id_seq'),
 'explicit SETVAL state restored: creditor_account_id_seq');

-- -----------------------------------------------------------------------------
-- Scenario: Each real child path fails independently without a partial publication.
-- Setup: Role-targeted rollback-scoped controls; direct real-child diagnostic oracle.
-- Expected: Original diagnostics, no tuple/rows, exact catalogue and lock restoration.
-- -----------------------------------------------------------------------------
CREATE FUNCTION pg_temp.pdc_catalogue() RETURNS JSONB LANGUAGE sql AS $catalogue$
 SELECT JSONB_BUILD_OBJECT(
 'routines',(SELECT JSONB_AGG(TO_JSONB(p)||JSONB_BUILD_OBJECT('definition',PG_GET_FUNCTIONDEF(p.oid),
  'comment',OBJ_DESCRIPTION(p.oid,'pg_proc')) ORDER BY p.oid) FROM pg_proc p
  WHERE p.pronamespace='public'::REGNAMESPACE AND (p.proname LIKE 'p_insert_%' OR p.proname LIKE 'pdc_%')),
 'triggers',(SELECT COALESCE(JSONB_AGG(TO_JSONB(t) ORDER BY t.oid),'[]') FROM pg_trigger t
  JOIN pg_class c ON c.oid=t.tgrelid WHERE c.relnamespace='public'::REGNAMESPACE),
 'namespace',(SELECT TO_JSONB(n) FROM pg_namespace n WHERE oid='public'::REGNAMESPACE),
 'temporary_controls',(SELECT COALESCE(JSONB_AGG(TO_JSONB(p) ORDER BY oid),'[]') FROM pg_proc p
  WHERE pronamespace=PG_MY_TEMP_SCHEMA() AND proname='pdc_native_fk'),
 'tables',(SELECT JSONB_AGG(JSONB_BUILD_OBJECT('oid',oid,'owner',relowner,'acl',relacl) ORDER BY oid)
  FROM pg_class WHERE relnamespace='public'::REGNAMESPACE),
 'roles',(SELECT JSONB_AGG(TO_JSONB(r) ORDER BY oid) FROM pg_roles r),
 'ddl_locks',(SELECT COALESCE(JSONB_AGG(JSONB_BUILD_ARRAY(l.relation,l.mode) ORDER BY l.relation,l.mode),'[]') FROM pg_locks l JOIN pg_class c ON c.oid=l.relation WHERE l.pid=PG_BACKEND_PID() AND c.relnamespace='public'::REGNAMESPACE AND l.mode IN('AccessExclusiveLock','ShareRowExclusiveLock')),
 'settings',(SELECT JSONB_AGG(JSONB_BUILD_ARRAY(name,setting,source) ORDER BY name) FROM pg_settings))
$catalogue$;
CREATE FUNCTION pg_temp.pdc_diagnostic(command TEXT) RETURNS JSONB LANGUAGE plpgsql AS $diagnostic$
DECLARE code TEXT; message TEXT; detail TEXT; hint TEXT; schema_name TEXT; table_name TEXT;
 column_name TEXT; data_type TEXT; constraint_name TEXT; context TEXT; ignored RECORD;
BEGIN
 BEGIN
  EXECUTE command INTO ignored;
  RETURN JSONB_BUILD_OBJECT('completed',TRUE);
 EXCEPTION WHEN query_canceled OR assert_failure OR OTHERS THEN
  GET STACKED DIAGNOSTICS code=RETURNED_SQLSTATE,message=MESSAGE_TEXT,detail=PG_EXCEPTION_DETAIL,
   hint=PG_EXCEPTION_HINT,schema_name=SCHEMA_NAME,table_name=TABLE_NAME,column_name=COLUMN_NAME,
   data_type=PG_DATATYPE_NAME,constraint_name=CONSTRAINT_NAME,context=PG_EXCEPTION_CONTEXT;
 END;
 RETURN JSONB_BUILD_OBJECT('completed',FALSE,'code',code,'message',message,'detail',detail,'hint',hint,
  'schema',schema_name,'table',table_name,'column',column_name,'datatype',data_type,'constraint',constraint_name,'context',context);
END;
$diagnostic$;
CREATE FUNCTION pg_temp.pdc_fault() RETURNS TRIGGER LANGUAGE plpgsql AS $fault$
DECLARE hit BOOLEAN;
BEGIN
 EXECUTE 'SELECT '||TG_ARGV[0] INTO hit USING TO_JSONB(NEW);
 IF hit THEN
  RAISE EXCEPTION USING ERRCODE=TG_ARGV[2],MESSAGE=TG_ARGV[1],DETAIL='synthetic child detail',
   HINT='synthetic child hint',SCHEMA=TG_TABLE_SCHEMA,TABLE=TG_TABLE_NAME,COLUMN='synthetic_column',
   CONSTRAINT='synthetic_constraint',DATATYPE='synthetic_datatype';
 END IF;
 RETURN NEW;
END;
$fault$;
CREATE FUNCTION pg_temp.pdc_task5_payload() RETURNS JSON LANGUAGE plpgsql AS $payload$
DECLARE payload JSON; role TEXT; path TEXT[]; aliases JSON;
BEGIN
 SELECT g.payload INTO payload FROM pdc_graph_cases g WHERE ordinal=3;
 payload:=pg_temp.pdc_put(payload,ARRAY['respondent_account','order_details','date_arrears_last_updated'],
  TO_JSON((TRANSACTION_TIMESTAMP() AT TIME ZONE 'Europe/London')::DATE::TEXT));
 -- A distinct second alias in each collection makes later iteration failures observable.
 FOREACH path SLICE 1 IN ARRAY ARRAY[
  ARRAY['respondent_account','respondent','party_details','aliases'],
  ARRAY['applicant','party_details','aliases',NULL],
  ARRAY['minor_creditors','0','party_details','aliases'],
  ARRAY['minor_creditors','1','party_details','aliases'],
  ARRAY['minor_creditors','2','party_details','aliases']] LOOP
  path:=ARRAY_REMOVE(path,NULL);
  aliases:=payload#>path;
  role:=aliases->0->>'surname';
  aliases:=('['||(aliases->0)::TEXT||', '||JSON_BUILD_OBJECT('sequence_number',3,'surname',role||' later','forenames','Synthetic')::TEXT||']')::JSON;
  payload:=pg_temp.pdc_put(payload,path,aliases);
 END LOOP;
 payload:=pg_temp.pdc_put(payload,ARRAY['respondent_account','order_details','order_terms'],
  (LEFT((payload#>'{respondent_account,order_details,order_terms}')::TEXT,-1)||', '||
   '{"result_id":"P55A","creditor_type":"Applicant","result_responses":[{"parameter_name":"Amount","response":"8.80"}]},'||
   '{"result_id":"P55A","creditor_type":"Minor Creditor","minor_creditor_sequence":7,"result_responses":[{"parameter_name":"Amount","response":"9.90"}]}]')::JSON);
 RETURN payload;
END;
$payload$;
CREATE FUNCTION pg_temp.pdc_direct(kind TEXT,role TEXT,payload JSON,seed JSONB,term_index INTEGER DEFAULT 0)
RETURNS TEXT LANGUAGE plpgsql AS $direct$
DECLARE part JSON; party BIGINT; contact BIGINT; creditor BIGINT; major BIGINT; respondent BIGINT;
 debtor BIGINT; term JSON; ids JSONB:=seed->'created_ids';
BEGIN
 respondent:=(seed->>'respondent_id')::BIGINT;
 IF role='Respondent' THEN part:=payload#>'{respondent_account,respondent}';
 ELSIF role='Applicant' THEN part:=payload->'applicant';
 ELSE SELECT value INTO part FROM JSON_ARRAY_ELEMENTS(payload->'minor_creditors')
  WHERE value#>>'{party_details,individual_details,surname}'='Synthetic '||role; END IF;
 SELECT party_id INTO party FROM public.parties WHERE surname='Synthetic '||role
  AND ids->'parties' @> TO_JSONB(ARRAY[party_id]);
 SELECT third_party_contact_id INTO contact FROM public.third_party_contact WHERE name_organisation=role||' contact'
  AND ids->'third_party_contact' @> TO_JSONB(ARRAY[third_party_contact_id]);
 SELECT debtor_detail_id INTO debtor FROM public.debtor_detail WHERE ids->'debtor_detail' @> TO_JSONB(ARRAY[debtor_detail_id]);
 IF role LIKE 'Major %' THEN SELECT major_creditor_id INTO major FROM public.major_creditors
  WHERE business_unit_id=32055 AND major_creditor_code=CASE role WHEN 'Major A' THEN 'M55A' ELSE 'M55B' END; END IF;
 SELECT creditor_account_id INTO creditor FROM public.creditor_accounts
  WHERE ids->'creditor_accounts' @> TO_JSONB(ARRAY[creditor_account_id])
  AND (minor_creditor_party_id=party OR major_creditor_id=major);
 CASE kind
 WHEN 'parties' THEN RETURN FORMAT('CALL public.p_insert_parties(%L::json,%L::public.t_party_account_type_enum,NULL)',part->'party_details',CASE role WHEN 'Respondent' THEN 'Respondent' ELSE 'Minor Creditor' END);
 WHEN 'aliases' THEN RETURN FORMAT('CALL public.p_insert_party_aliases(%s,%L::json)',party,part#>'{party_details,aliases}');
 WHEN 'contacts' THEN RETURN FORMAT('CALL public.p_insert_third_party_contacts(%L::json,NULL)',part->'third_party_details');
 WHEN 'debtor' THEN RETURN FORMAT('CALL public.p_insert_debtor_detail(%L::json,%L,NULL)',payload#>'{respondent_account,respondent,debtor_details}',payload#>>'{respondent_account,respondent,party_details,individual_details,other_personal_information}');
 WHEN 'respondent' THEN RETURN FORMAT('CALL public.p_insert_respondent_account(32055::smallint,%L::public.t_casefile_type_enum,%L::json,%L::bigint,%L::bigint,NULL,NULL)','REMO In',payload->'respondent_account',debtor,contact);
 WHEN 'creditors' THEN RETURN FORMAT('CALL public.p_insert_creditor_accounts(32055::smallint,%L::json,%L::bigint,%L::bigint,%L::bigint,NULL,NULL)',part,major,party,contact);
 WHEN 'terms' THEN
  term:=payload#>ARRAY['respondent_account','order_details','order_terms',term_index::TEXT];
  RETURN FORMAT('CALL public.p_insert_order_terms(%s,%s,%L,%L,%L::json)',respondent,creditor,'P55_SUBMIT','Synthetic saved submitter',term);
 WHEN 'notes' THEN RETURN FORMAT('CALL public.p_insert_notes(%s,%L,%L,%L::json)',respondent,'P55_SUBMIT','Synthetic saved submitter',payload#>'{respondent_account,notes}');
 WHEN 'associations' THEN
  IF role='Central Authority' THEN SELECT major_creditor_id INTO major FROM public.major_creditors WHERE business_unit_id=32055 AND major_creditor_code='C55A'; END IF;
  RETURN FORMAT('CALL public.p_insert_respondent_account_parties(%s,%s,%L::public.t_association_type_enum)',respondent,
   CASE role WHEN 'Respondent' THEN party WHEN 'Applicant' THEN creditor ELSE major END,role);
 END CASE;
 RAISE EXCEPTION 'Unknown owned direct-child test kind';
END;
$direct$;
CREATE TEMP TABLE pdc_child_faults(label TEXT,kind TEXT,role TEXT,target TEXT,predicate TEXT,term_index INTEGER,code TEXT);
INSERT INTO pdc_child_faults VALUES
('Party Respondent','parties','Respondent','parties','$1->>''surname''=''Synthetic Respondent''',0,'P5501'),
('Alias Respondent','aliases','Respondent','aliases','$1->>''surname''=''Respondent alias''',0,'P5501'),
('Alias Respondent later','aliases','Respondent','aliases','$1->>''surname''=''Respondent alias later''',0,'P5501'),
('Party Applicant','parties','Applicant','parties','$1->>''surname''=''Synthetic Applicant''',0,'P5501'),
('Alias Applicant','aliases','Applicant','aliases','$1->>''surname''=''Applicant alias''',0,'P5501'),
('Alias Applicant later','aliases','Applicant','aliases','$1->>''surname''=''Applicant alias later''',0,'P5501'),
('Party Minor Ninety One','parties','Minor Ninety One','parties','$1->>''surname''=''Synthetic Minor Ninety One''',0,'P5501'),
('Alias Minor Ninety One','aliases','Minor Ninety One','aliases','$1->>''surname''=''Minor Ninety One alias''',0,'P5501'),
('Alias Minor Ninety One later','aliases','Minor Ninety One','aliases','$1->>''surname''=''Minor Ninety One alias later''',0,'P5501'),
('Party Minor Seven','parties','Minor Seven','parties','$1->>''surname''=''Synthetic Minor Seven''',0,'P5501'),
('Alias Minor Seven','aliases','Minor Seven','aliases','$1->>''surname''=''Minor Seven alias''',0,'P5501'),
('Alias Minor Seven later','aliases','Minor Seven','aliases','$1->>''surname''=''Minor Seven alias later''',0,'P5501'),
('Party Unused Minor','parties','Unused Minor','parties','$1->>''surname''=''Synthetic Unused Minor''',0,'P5501'),
('Alias Unused Minor','aliases','Unused Minor','aliases','$1->>''surname''=''Unused Minor alias''',0,'P5501'),
('Alias Unused Minor later','aliases','Unused Minor','aliases','$1->>''surname''=''Unused Minor alias later''',0,'P5501'),
('Contact Respondent','contacts','Respondent','third_party_contact','$1->>''name_organisation''=''Respondent contact''',0,'P5501'),
('Contact Applicant','contacts','Applicant','third_party_contact','$1->>''name_organisation''=''Applicant contact''',0,'P5501'),
('Debtor selected','debtor','Respondent','debtor_detail','$1->>''employer_name''=''Synthetic Employer''',0,'P5501'),
('Respondent account','respondent','Respondent','respondent_accounts','($1->>''business_unit_id'')::smallint=32055',0,'P5501'),
('MN Applicant','creditors','Applicant','creditor_accounts','EXISTS(SELECT 1 FROM public.parties WHERE party_id=($1->>''minor_creditor_party_id'')::bigint AND surname=''Synthetic Applicant'')',0,'P5501'),
('MN Minor Ninety One','creditors','Minor Ninety One','creditor_accounts','EXISTS(SELECT 1 FROM public.parties WHERE party_id=($1->>''minor_creditor_party_id'')::bigint AND surname=''Synthetic Minor Ninety One'')',0,'P5501'),
('MN Minor Seven','creditors','Minor Seven','creditor_accounts','EXISTS(SELECT 1 FROM public.parties WHERE party_id=($1->>''minor_creditor_party_id'')::bigint AND surname=''Synthetic Minor Seven'')',0,'P5501'),
('MN Unused Minor','creditors','Unused Minor','creditor_accounts','EXISTS(SELECT 1 FROM public.parties WHERE party_id=($1->>''minor_creditor_party_id'')::bigint AND surname=''Synthetic Unused Minor'')',0,'P5501'),
('MJ Major B','creditors','Major B','creditor_accounts','EXISTS(SELECT 1 FROM public.major_creditors WHERE major_creditor_id=($1->>''major_creditor_id'')::bigint AND business_unit_id=32055 AND major_creditor_code=''M55B'')',0,'P5501'),
('MJ Major A','creditors','Major A','creditor_accounts','EXISTS(SELECT 1 FROM public.major_creditors WHERE major_creditor_id=($1->>''major_creditor_id'')::bigint AND business_unit_id=32055 AND major_creditor_code=''M55A'')',0,'P5501'),
('Term 1 Major B','terms','Major B','order_terms','$1#>>''{result_responses,0,response}''=''1.10''',0,'P5501'),
('Term 2 Minor Seven','terms','Minor Seven','order_terms','$1#>>''{result_responses,0,response}''=''2.20''',1,'P5501'),
('Term 3 Major B','terms','Major B','order_terms','$1#>>''{result_responses,0,response}''=''3.30''',2,'P5501'),
('Term 4 Applicant','terms','Applicant','order_terms','$1#>>''{result_responses,0,response}''=''4.40''',3,'P5501'),
('Term 5 Minor Ninety One','terms','Minor Ninety One','order_terms','$1#>>''{result_responses,0,response}''=''5.50''',4,'P5501'),
('Term 6 Major A','terms','Major A','order_terms','$1#>>''{result_responses,0,response}''=''6.60''',5,'P5501'),
('Term 7 Major B','terms','Major B','order_terms','$1#>>''{result_responses,0,response}''=''7.70''',6,'P5501'),
('Note present','notes','Respondent','notes','$1->>''posted_by''=''P55_SUBMIT''',0,'P5501'),
('Association Respondent','associations','Respondent','respondent_account_parties','$1->>''association_type''=''Respondent''',0,'P5501'),
('Association Applicant','associations','Applicant','respondent_account_parties','$1->>''association_type''=''Applicant''',0,'P5501'),
('Association Central Authority','associations','Central Authority','respondent_account_parties','$1->>''association_type''=''Central Authority''',0,'P5501'),
('Controlled 57014','notes','Respondent','notes','$1->>''posted_by''=''P55_SUBMIT''',0,'57014'),
('Controlled P0004','notes','Respondent','notes','$1->>''posted_by''=''P55_SUBMIT''',0,'P0004');
INSERT INTO pdc_child_faults VALUES
 ('later Applicant term','terms','Applicant','order_terms','$1#>>''{result_responses,0,response}''=''8.80''',7,'P5501'),
 ('later Minor term','terms','Minor Seven','order_terms','$1#>>''{result_responses,0,response}''=''9.90''',8,'P5501');
-- Prior rows are observed within the same generated Respondent/Party domain at fault time.
UPDATE pdc_child_faults SET predicate=predicate||FORMAT(
 ' AND (SELECT COUNT(*) FROM public.respondent_account_parties WHERE respondent_account_id=($1->>''respondent_account_id'')::bigint)=%s',
 CASE role WHEN 'Applicant' THEN 1 ELSE 2 END)
 WHERE kind='associations' AND role IN('Applicant','Central Authority');
UPDATE pdc_child_faults SET predicate=predicate||FORMAT(
 ' AND (SELECT COUNT(*) FROM public.order_terms WHERE respondent_account_id=($1->>''respondent_account_id'')::bigint)=%s',term_index)
 WHERE kind='terms';
UPDATE pdc_child_faults SET predicate=predicate||
 ' AND EXISTS(SELECT 1 FROM public.aliases WHERE party_id=($1->>''party_id'')::bigint AND sequence_number=2)'
 WHERE kind='aliases' AND label LIKE '% later';
CREATE FUNCTION pg_temp.pdc_helper(kind TEXT) RETURNS TEXT LANGUAGE sql AS $$
 SELECT CASE kind WHEN 'parties' THEN 'p_insert_parties' WHEN 'aliases' THEN 'p_insert_party_aliases'
 WHEN 'contacts' THEN 'p_insert_third_party_contacts' WHEN 'debtor' THEN 'p_insert_debtor_detail'
 WHEN 'respondent' THEN 'p_insert_respondent_account' WHEN 'creditors' THEN 'p_insert_creditor_accounts'
 WHEN 'terms' THEN 'p_insert_order_terms' WHEN 'notes' THEN 'p_insert_notes' ELSE 'p_insert_respondent_account_parties' END
$$;
CREATE FUNCTION pg_temp.pdc_child_failure_assertions() RETURNS SETOF TEXT LANGUAGE plpgsql AS $checks$
DECLARE test RECORD; payload JSON; seed JSONB; observed JSONB; direct JSONB; original JSONB;
 scope JSONB; command TEXT; restored JSONB;
BEGIN
 FOR test IN SELECT * FROM pdc_child_faults LOOP
  payload:=pg_temp.pdc_task5_payload();
  UPDATE public.draft_casefiles SET casefile=payload,casefile_type='REMO In',submitted_by='P55_SUBMIT',
   submitted_by_name='Synthetic saved submitter',version_number=NULL WHERE draft_casefile_id=-1065501;
  original:=pg_temp.pdc_catalogue(); scope:=pg_temp.pdc_scope();
  BEGIN
   seed:=pg_temp.pdc_call(-1065501);
   IF seed->>'completed'<>'true' THEN RAISE EXCEPTION 'Invalid child fault seed: %',seed->>'message'; END IF;
   DELETE FROM public.aliases WHERE seed->'created_ids'->'aliases' @> TO_JSONB(ARRAY[alias_id]);
   DELETE FROM public.respondent_account_parties WHERE seed->'created_ids'->'respondent_account_parties' @> TO_JSONB(ARRAY[respondent_account_party_id])
    AND (test.kind<>'associations' OR CASE test.role WHEN 'Applicant' THEN association_type<>'Respondent'
     WHEN 'Central Authority' THEN association_type='Central Authority' ELSE TRUE END);
   IF test.kind='terms' THEN
    DELETE FROM public.order_terms WHERE order_terms_id IN(SELECT order_terms_id FROM public.order_terms
     WHERE seed->'created_ids'->'order_terms' @> TO_JSONB(ARRAY[order_terms_id]) ORDER BY order_terms_id OFFSET test.term_index);
   END IF;
   command:=pg_temp.pdc_direct(test.kind,test.role,payload,seed,test.term_index);
   EXECUTE FORMAT('CREATE TRIGGER pdc_owned_fault BEFORE INSERT ON public.%I FOR EACH ROW EXECUTE FUNCTION pg_temp.pdc_fault(%L,%L,%L)',
    test.target,test.predicate,'Synthetic fault: '||test.label,test.code);
   direct:=pg_temp.pdc_diagnostic(command);
   observed:=pg_temp.pdc_call(-1065501);
   RAISE EXCEPTION USING ERRCODE='P5599',MESSAGE='pdc restore fault scope';
  EXCEPTION WHEN SQLSTATE 'P5599' THEN NULL;
  END;
  restored:=pg_temp.pdc_catalogue();
  RETURN NEXT is(observed->>'code',test.code,test.label||': targeted child SQLSTATE');
  RETURN NEXT is(observed->>'message','Synthetic fault: '||test.label,test.label||': exact intended role/iteration reached');
  RETURN NEXT is(observed-ARRAY['before','after','created_ids','context'],direct-'context',test.label||': all direct-child diagnostic fields retained');
  RETURN NEXT ok(POSITION(pg_temp.pdc_helper(test.kind)||'(' IN observed->>'context')>0 AND POSITION('p_process_draft_casefiles' IN observed->>'context')>0,test.label||': real child and orchestrator stack');
  RETURN NEXT ok(observed->>'completed'='false' AND NOT(observed ? 'published_raw') AND observed->'before'=observed->'after',test.label||': no successful tuple or graph/reservation effects');
  RETURN NEXT is(restored,original,test.label||': exact catalogue owner ACL settings and control restoration');
  RETURN NEXT is(pg_temp.pdc_scope(),scope,test.label||': aborted control removes seed and releases its DDL scope');
 END LOOP;
END;
$checks$;
SELECT * FROM pg_temp.pdc_child_failure_assertions();
-- Scenario: A real helper succeeds but loses one required OUT at its boundary.
-- Setup: Rollback-scoped delegating wrappers corrupt only that output and role.
-- Expected: Fixed consumer failure immediately; exact original OID and definition restored.
CREATE TEMP TABLE pdc_missing_outputs(label TEXT,helper TEXT,predicate TEXT,output TEXT,value TEXT);
INSERT INTO pdc_missing_outputs VALUES
('Party Respondent po_party_id NULL','p_insert_parties','pi_party_json#>>''{individual_details,surname}''=''Synthetic Respondent''','po_party_id','NULL'),
('Party Applicant po_party_id NULL','p_insert_parties','pi_party_json#>>''{individual_details,surname}''=''Synthetic Applicant''','po_party_id','NULL'),
('Party Minor Ninety One po_party_id NULL','p_insert_parties','pi_party_json#>>''{individual_details,surname}''=''Synthetic Minor Ninety One''','po_party_id','NULL'),
('Party Minor Seven po_party_id NULL','p_insert_parties','pi_party_json#>>''{individual_details,surname}''=''Synthetic Minor Seven''','po_party_id','NULL'),
('Party Unused Minor po_party_id NULL','p_insert_parties','pi_party_json#>>''{individual_details,surname}''=''Synthetic Unused Minor''','po_party_id','NULL'),
('Contact Respondent po_third_party_contact_id NULL','p_insert_third_party_contacts','pi_third_party_contact_json->>''name''=''Respondent contact''','po_third_party_contact_id','NULL'),
('Contact Applicant po_third_party_contact_id NULL','p_insert_third_party_contacts','pi_third_party_contact_json->>''name''=''Applicant contact''','po_third_party_contact_id','NULL'),
('Debtor po_debtor_detail_id NULL','p_insert_debtor_detail','TRUE','po_debtor_detail_id','NULL'),
('Respondent po_respondent_account_id NULL','p_insert_respondent_account','TRUE','po_respondent_account_id','NULL'),
('Respondent po_account_number NULL','p_insert_respondent_account','TRUE','po_account_number','NULL'),
('Respondent po_account_number ''''','p_insert_respondent_account','TRUE','po_account_number',''''''),
('Creditor Applicant po_creditor_account_id NULL','p_insert_creditor_accounts','pi_creditor_account_json#>>''{party_details,individual_details,surname}''=''Synthetic Applicant''','po_creditor_account_id','NULL'),
('Creditor Applicant po_account_number NULL','p_insert_creditor_accounts','pi_creditor_account_json#>>''{party_details,individual_details,surname}''=''Synthetic Applicant''','po_account_number','NULL'),
('Creditor Applicant po_account_number ''''','p_insert_creditor_accounts','pi_creditor_account_json#>>''{party_details,individual_details,surname}''=''Synthetic Applicant''','po_account_number',''''''),
('Creditor Minor Ninety One po_creditor_account_id NULL','p_insert_creditor_accounts','pi_creditor_account_json#>>''{party_details,individual_details,surname}''=''Synthetic Minor Ninety One''','po_creditor_account_id','NULL'),
('Creditor Minor Ninety One po_account_number NULL','p_insert_creditor_accounts','pi_creditor_account_json#>>''{party_details,individual_details,surname}''=''Synthetic Minor Ninety One''','po_account_number','NULL'),
('Creditor Minor Ninety One po_account_number ''''','p_insert_creditor_accounts','pi_creditor_account_json#>>''{party_details,individual_details,surname}''=''Synthetic Minor Ninety One''','po_account_number',''''''),
('Creditor Minor Seven po_creditor_account_id NULL','p_insert_creditor_accounts','pi_creditor_account_json#>>''{party_details,individual_details,surname}''=''Synthetic Minor Seven''','po_creditor_account_id','NULL'),
('Creditor Minor Seven po_account_number NULL','p_insert_creditor_accounts','pi_creditor_account_json#>>''{party_details,individual_details,surname}''=''Synthetic Minor Seven''','po_account_number','NULL'),
('Creditor Minor Seven po_account_number ''''','p_insert_creditor_accounts','pi_creditor_account_json#>>''{party_details,individual_details,surname}''=''Synthetic Minor Seven''','po_account_number',''''''),
('Creditor Unused Minor po_creditor_account_id NULL','p_insert_creditor_accounts','pi_creditor_account_json#>>''{party_details,individual_details,surname}''=''Synthetic Unused Minor''','po_creditor_account_id','NULL'),
('Creditor Unused Minor po_account_number NULL','p_insert_creditor_accounts','pi_creditor_account_json#>>''{party_details,individual_details,surname}''=''Synthetic Unused Minor''','po_account_number','NULL'),
('Creditor Unused Minor po_account_number ''''','p_insert_creditor_accounts','pi_creditor_account_json#>>''{party_details,individual_details,surname}''=''Synthetic Unused Minor''','po_account_number',''''''),
('Creditor M55B po_creditor_account_id NULL','p_insert_creditor_accounts','pi_major_creditor_id=(SELECT major_creditor_id FROM public.major_creditors WHERE business_unit_id=32055 AND major_creditor_code=''M55B'')','po_creditor_account_id','NULL'),
('Creditor M55B po_account_number NULL','p_insert_creditor_accounts','pi_major_creditor_id=(SELECT major_creditor_id FROM public.major_creditors WHERE business_unit_id=32055 AND major_creditor_code=''M55B'')','po_account_number','NULL'),
('Creditor M55B po_account_number ''''','p_insert_creditor_accounts','pi_major_creditor_id=(SELECT major_creditor_id FROM public.major_creditors WHERE business_unit_id=32055 AND major_creditor_code=''M55B'')','po_account_number',''''''),
('Creditor M55A po_creditor_account_id NULL','p_insert_creditor_accounts','pi_major_creditor_id=(SELECT major_creditor_id FROM public.major_creditors WHERE business_unit_id=32055 AND major_creditor_code=''M55A'')','po_creditor_account_id','NULL'),
('Creditor M55A po_account_number NULL','p_insert_creditor_accounts','pi_major_creditor_id=(SELECT major_creditor_id FROM public.major_creditors WHERE business_unit_id=32055 AND major_creditor_code=''M55A'')','po_account_number','NULL'),
('Creditor M55A po_account_number ''''','p_insert_creditor_accounts','pi_major_creditor_id=(SELECT major_creditor_id FROM public.major_creditors WHERE business_unit_id=32055 AND major_creditor_code=''M55A'')','po_account_number','''''');
CREATE TEMP TABLE pdc_canary(armed BOOLEAN NOT NULL);
INSERT INTO pdc_canary VALUES(FALSE);
CREATE FUNCTION pg_temp.pdc_missing_assertions() RETURNS SETOF TEXT LANGUAGE plpgsql AS $checks$
DECLARE test RECORD; proc RECORD; original JSONB; scope JSONB; observed JSONB; body TEXT; success JSONB; delegate_name TEXT; calibration JSONB;
BEGIN
 FOR test IN SELECT * FROM pdc_missing_outputs LOOP
  UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_task5_payload() WHERE draft_casefile_id=-1065501;
  original:=pg_temp.pdc_catalogue(); scope:=pg_temp.pdc_scope();
  BEGIN
   FOR proc IN SELECT p.*,PG_GET_FUNCTION_IDENTITY_ARGUMENTS(p.oid) identity_args,PG_GET_FUNCTION_ARGUMENTS(p.oid) arguments
    FROM pg_proc p WHERE pronamespace='public'::REGNAMESPACE AND proname IN(
     'p_insert_parties','p_insert_party_aliases','p_insert_third_party_contacts','p_insert_debtor_detail',
     'p_insert_respondent_account','p_insert_creditor_accounts','p_insert_order_terms','p_insert_notes','p_insert_respondent_account_parties') LOOP
    delegate_name:='pdc_original_'||proc.proname;
    EXECUTE FORMAT('ALTER PROCEDURE public.%I(%s) RENAME TO %I',proc.proname,proc.identity_args,delegate_name);
    body:='BEGIN IF (SELECT armed FROM pg_temp.pdc_canary) THEN RAISE EXCEPTION USING ERRCODE=''P5503'',MESSAGE=''Synthetic dependent child reached after missing OUT''; END IF; CALL public.'
     ||QUOTE_IDENT(delegate_name)||'('||ARRAY_TO_STRING(proc.proargnames,',')||');';
    IF proc.proname=test.helper THEN
     body:=body||' IF '||test.predicate||' THEN '||QUOTE_IDENT(test.output)||':='||test.value||'; UPDATE pg_temp.pdc_canary SET armed=TRUE; END IF;';
    END IF;
    body:=body||' END;';
    EXECUTE FORMAT('CREATE PROCEDURE public.%I(%s) LANGUAGE plpgsql AS %L',proc.proname,proc.arguments,body);
   END LOOP;
   UPDATE pg_temp.pdc_canary SET armed=TRUE;
   calibration:=pg_temp.pdc_diagnostic('CALL public.p_insert_notes(NULL,NULL,NULL,NULL)');
   UPDATE pg_temp.pdc_canary SET armed=FALSE;
   observed:=pg_temp.pdc_call(-1065501);
   RAISE EXCEPTION USING ERRCODE='P5599',MESSAGE='pdc restore wrapper scope';
  EXCEPTION WHEN SQLSTATE 'P5599' THEN NULL;
  END;
  RETURN NEXT is(calibration->>'code','P5503',test.label||': dependent-entry canary independently active');
  RETURN NEXT is(observed->>'code','P0001',test.label||': missing OUT rejected');
  RETURN NEXT is(observed->>'message','p_process_draft_casefiles: required child output is missing',test.label||': immediate consumer output guard before dependent children');
  RETURN NEXT ok(observed->>'completed'='false' AND NOT(observed ? 'published_raw') AND observed->'before'=observed->'after',test.label||': delegated real writes fully unwind');
  RETURN NEXT is(pg_temp.pdc_catalogue(),original,test.label||': exact OID definition properties owner ACL settings restored');
  RETURN NEXT is(pg_temp.pdc_scope(),scope,test.label||': scope unchanged after actual control abort');
  BEGIN
   success:=pg_temp.pdc_call(-1065501);
   RAISE EXCEPTION USING ERRCODE='P5599',MESSAGE='pdc remove recovery graph';
  EXCEPTION WHEN SQLSTATE 'P5599' THEN NULL;
  END;
  RETURN NEXT ok(success->>'completed'='true' AND JSONB_ARRAY_LENGTH(success->'created_ids'->'respondent_account_parties')=3,
   test.label||': real original helpers succeed after restoration');
 END LOOP;
END;
$checks$;
SELECT * FROM pg_temp.pdc_missing_assertions();
-- Scenario: Real conversion, strict lookup, permission and FK errors cross the boundary.
-- Setup: Equivalent direct-child dependencies, no diagnostic translation or fake success.
-- Expected: All native stacked diagnostics retained and full catalogue/row restoration.
CREATE FUNCTION pg_temp.pdc_native_assertions() RETURNS SETOF TEXT LANGUAGE plpgsql AS $checks$
DECLARE test RECORD; payload JSON; seed JSONB; observed JSONB; direct JSONB; original JSONB; scope JSONB; command TEXT;
BEGIN
 FOR test IN SELECT * FROM (VALUES
  ('Country cast','22P02','debtor'),('Country missing','P0002','debtor'),
  ('Country ambiguous','P0003','debtor'),('information width','22001','debtor'),
  ('Note permission','42501','notes'),('native FK','23503','respondent')) v(label,code,kind) LOOP
  payload:=pg_temp.pdc_task5_payload();
  UPDATE public.draft_casefiles SET casefile=payload WHERE draft_casefile_id=-1065501;
  original:=pg_temp.pdc_catalogue(); scope:=pg_temp.pdc_scope();
  BEGIN
   seed:=pg_temp.pdc_call(-1065501);
   IF seed->>'completed'<>'true' THEN RAISE EXCEPTION 'Invalid native seed'; END IF;
   IF test.label='Country cast' THEN
    payload:=pg_temp.pdc_put(payload,ARRAY['respondent_account','respondent','debtor_details','employer_address','cjs_code'],'"synthetic invalid"');
   ELSIF test.label='Country missing' THEN
    DELETE FROM public.countries WHERE cjs_code=31055;
    payload:=pg_temp.pdc_put(payload,ARRAY['respondent_account','respondent','debtor_details','employer_address','cjs_code'],'31055');
   ELSIF test.label='Country ambiguous' THEN
    INSERT INTO public.countries(country_id,cjs_code,country_name,date_used_from,active) VALUES(-1065503,31055,'Synthetic ambiguous country',DATE '2000-01-01',TRUE);
    payload:=pg_temp.pdc_put(payload,ARRAY['respondent_account','respondent','debtor_details','employer_address','cjs_code'],'31055');
   ELSIF test.label='information width' THEN
    payload:=pg_temp.pdc_put(payload,ARRAY['respondent_account','respondent','party_details','individual_details','other_personal_information'],TO_JSON(REPEAT('x',201)));
   ELSIF test.label='native FK' THEN
    -- Mutation is confined to a test trigger; PostgreSQL itself supplies the FK diagnostic.
    EXECUTE $ddl$CREATE FUNCTION pg_temp.pdc_native_fk() RETURNS trigger LANGUAGE plpgsql AS $body$
     BEGIN NEW.business_unit_id:=-32055; RETURN NEW; END; $body$$ddl$;
    IF EXISTS(SELECT 1 FROM public.business_units WHERE business_unit_id=-32055) THEN RAISE EXCEPTION 'Native FK scope collision'; END IF;
    CREATE TRIGGER pdc_owned_fk BEFORE INSERT ON public.respondent_accounts FOR EACH ROW EXECUTE FUNCTION pg_temp.pdc_native_fk();
   END IF;
   UPDATE public.draft_casefiles SET casefile=payload WHERE draft_casefile_id=-1065501;
   command:=pg_temp.pdc_direct(test.kind,'Respondent',payload,seed);
   IF test.label='Note permission' THEN
    CREATE ROLE pdc_owned_permission NOLOGIN;
    GRANT USAGE ON SCHEMA public TO pdc_owned_permission;
    GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA public TO pdc_owned_permission;
    GRANT USAGE,SELECT ON ALL SEQUENCES IN SCHEMA public TO pdc_owned_permission;
    REVOKE INSERT ON public.notes FROM pdc_owned_permission;
    SET LOCAL ROLE pdc_owned_permission;
   END IF;
   direct:=pg_temp.pdc_diagnostic(command);
   observed:=pg_temp.pdc_call(-1065501);
   RAISE EXCEPTION USING ERRCODE='P5599',MESSAGE='pdc native cleanup';
  EXCEPTION WHEN SQLSTATE 'P5599' THEN NULL;
  END;
  RETURN NEXT ok(observed->>'code'=test.code AND POSITION(pg_temp.pdc_helper(test.kind)||'(' IN observed->>'context')>0,test.label||': actual native SQLSTATE and exact helper');
  RETURN NEXT is(observed-ARRAY['before','after','created_ids','context'],direct-'context',test.label||': unchanged native diagnostic tuple');
  RETURN NEXT ok(observed->>'completed'='false' AND observed->'before'=observed->'after' AND NOT(observed ? 'published_raw'),test.label||': no rows or successful output');
  RETURN NEXT is(pg_temp.pdc_catalogue(),original,test.label||': role grants definitions settings exactly restored');
  RETURN NEXT is(pg_temp.pdc_scope(),scope,test.label||': native control scope fully removed');
 END LOOP;
END;
$checks$;
SELECT * FROM pg_temp.pdc_native_assertions();
-- Scenario: Caller owns rollback after success, identity merge and exact-one completion.
-- Setup: Real CALL inside an outer protected caller block; fail after CALL has returned.
-- Expected: Earlier caller DML and complete graph/reservations unwind together.
CREATE FUNCTION pg_temp.pdc_merge(snapshot JSONB,published JSONB) RETURNS JSONB LANGUAGE plpgsql AS $merge$
DECLARE source_rows JSONB:=snapshot->'minor_creditors'; result_rows JSONB:=published->'minor_creditor_accounts'; merged JSONB;
BEGIN
 IF JSONB_TYPEOF(source_rows) IS DISTINCT FROM 'array' OR JSONB_TYPEOF(result_rows) IS DISTINCT FROM 'array'
 OR EXISTS(SELECT 1 FROM JSONB_ARRAY_ELEMENTS(source_rows) GROUP BY value->>'creditor_sequence' HAVING COUNT(*)<>1 OR value->>'creditor_sequence' IS NULL)
 OR EXISTS(SELECT 1 FROM JSONB_ARRAY_ELEMENTS(result_rows) GROUP BY value->>'creditor_sequence' HAVING COUNT(*)<>1 OR value->>'creditor_sequence' IS NULL)
 OR EXISTS(SELECT value->>'creditor_sequence' FROM JSONB_ARRAY_ELEMENTS(source_rows) EXCEPT SELECT value->>'creditor_sequence' FROM JSONB_ARRAY_ELEMENTS(result_rows))
 OR EXISTS(SELECT value->>'creditor_sequence' FROM JSONB_ARRAY_ELEMENTS(result_rows) EXCEPT SELECT value->>'creditor_sequence' FROM JSONB_ARRAY_ELEMENTS(source_rows)) THEN
  RAISE EXCEPTION USING ERRCODE='P5502',MESSAGE='Synthetic caller merge rejected correlation';
 END IF;
 SELECT COALESCE(JSONB_AGG(s.value||(r.value-'creditor_sequence') ORDER BY s.ordinality),'[]') INTO merged
 FROM JSONB_ARRAY_ELEMENTS(source_rows) WITH ORDINALITY s
 JOIN JSONB_ARRAY_ELEMENTS(result_rows) r ON r.value->>'creditor_sequence'=s.value->>'creditor_sequence';
 RETURN snapshot||JSONB_BUILD_OBJECT('minor_creditors',merged,'respondent_account',
  (snapshot->'respondent_account')||(published->'respondent_account'),'applicant',
  (snapshot->'applicant')||(published->'applicant_account'));
END;
$merge$;
CREATE FUNCTION pg_temp.pdc_caller_assertions() RETURNS SETOF TEXT LANGUAGE plpgsql AS $checks$
DECLARE label TEXT; payload JSON; snapshot JSONB; fragment JSONB; original_fragment JSONB; merged JSONB; before_scope JSONB; after_scope JSONB;
 first_call JSONB; second_call JSONB; observed_version BIGINT; changed BIGINT; caught TEXT; successful_graph BOOLEAN; model_state_ok BOOLEAN;
BEGIN
 FOREACH label IN ARRAY ARRAY['explicit caller rollback','output validation','snapshot duplicate','snapshot missing','snapshot unmatched',
  'output duplicate','output missing','output unmatched','completion version mismatch','completion zero rows',
  'supported NULL version','supported nonnull version','unsupported direct repeat','unsupported no completion'] LOOP
  payload:=pg_temp.pdc_task5_payload();
  UPDATE public.draft_casefiles SET casefile=payload,casefile_snapshot=(payload::JSONB||
   '{"respondent_name":"Synthetic snapshot Respondent","applicant_name":"Synthetic snapshot Applicant","other_snapshot":{"preserve":true}}'::JSONB)::JSON,version_number=
   CASE WHEN label='supported nonnull version' THEN 4 ELSE NULL END,casefile_status='PUBLISHING_PENDING',account_id=NULL,account_number=NULL
   WHERE draft_casefile_id=-1065501;
  before_scope:=pg_temp.pdc_scope(); caught:=NULL; successful_graph:=FALSE; second_call:=NULL; merged:=NULL; model_state_ok:=FALSE;
  BEGIN
   SELECT version_number,casefile_snapshot::JSONB INTO observed_version,snapshot FROM public.draft_casefiles WHERE draft_casefile_id=-1065501 FOR UPDATE;
   -- Earlier caller DML must roll back too, not just the protected procedure writes.
   UPDATE public.draft_casefiles SET status_message='Synthetic earlier caller DML' WHERE draft_casefile_id=-1065599;
   first_call:=pg_temp.pdc_call(-1065501);
   IF first_call->>'completed'<>'true' THEN RAISE EXCEPTION 'Invalid caller seed: %',first_call->>'message'; END IF;
   successful_graph:=JSONB_ARRAY_LENGTH(first_call->'created_ids'->'respondent_account_parties')=3;
   fragment:=(first_call->>'published_raw')::JSONB; original_fragment:=fragment;
   IF label='output validation' THEN RAISE EXCEPTION USING ERRCODE='P5502',MESSAGE='Synthetic caller output rejection'; END IF;
   IF label='snapshot duplicate' THEN snapshot:=JSONB_SET(snapshot,'{minor_creditors}',(snapshot->'minor_creditors')||JSONB_BUILD_ARRAY(snapshot#>'{minor_creditors,0}'));
   ELSIF label='snapshot missing' THEN snapshot:=JSONB_SET(snapshot,'{minor_creditors}',(snapshot->'minor_creditors')-0);
   ELSIF label='snapshot unmatched' THEN snapshot:=JSONB_SET(snapshot,'{minor_creditors,0,creditor_sequence}','123');
   ELSIF label='output duplicate' THEN fragment:=JSONB_SET(fragment,'{minor_creditor_accounts}',(fragment->'minor_creditor_accounts')||JSONB_BUILD_ARRAY(fragment#>'{minor_creditor_accounts,0}'));
   ELSIF label='output missing' THEN fragment:=JSONB_SET(fragment,'{minor_creditor_accounts}',(fragment->'minor_creditor_accounts')-0);
   ELSIF label='output unmatched' THEN fragment:=JSONB_SET(fragment,'{minor_creditor_accounts,0,creditor_sequence}','123'); END IF;
   -- Shuffled result order must not alter source order or names in the keyed merge.
   fragment:=JSONB_SET(fragment,'{minor_creditor_accounts}',(SELECT JSONB_AGG(value ORDER BY ordinality DESC) FROM JSONB_ARRAY_ELEMENTS(fragment->'minor_creditor_accounts') WITH ORDINALITY));
   merged:=pg_temp.pdc_merge(snapshot,fragment);
   IF label='completion version mismatch' THEN UPDATE public.draft_casefiles SET version_number=9 WHERE draft_casefile_id=-1065501; END IF;
   IF label='completion zero rows' THEN UPDATE public.draft_casefiles SET casefile_status='REJECTED' WHERE draft_casefile_id=-1065501; END IF;
   IF label LIKE 'completion %' OR label LIKE 'supported %' THEN
    UPDATE public.draft_casefiles SET casefile_snapshot=merged::JSON,casefile_status='PUBLISHED',
     account_id=(first_call->>'respondent_id')::BIGINT,account_number=first_call->>'account_number',version_number=COALESCE(version_number,0)+1
     WHERE draft_casefile_id=-1065501 AND casefile_status='PUBLISHING_PENDING' AND account_id IS NULL AND account_number IS NULL
      AND version_number IS NOT DISTINCT FROM observed_version;
    GET DIAGNOSTICS changed=ROW_COUNT;
    IF changed<>1 THEN RAISE EXCEPTION USING ERRCODE='P5502',MESSAGE='Synthetic caller completion cardinality'; END IF;
    SELECT casefile_status='PUBLISHED' AND account_id=(first_call->>'respondent_id')::BIGINT
     AND account_number=first_call->>'account_number' AND casefile_snapshot::JSONB=merged
     AND version_number=COALESCE(observed_version,0)+1 INTO model_state_ok
     FROM public.draft_casefiles WHERE draft_casefile_id=-1065501;
    -- Supported redelivery reconciles complete durable state and never calls again.
    SELECT COUNT(*) INTO changed FROM public.draft_casefiles WHERE draft_casefile_id=-1065501
     AND casefile_status='PUBLISHING_PENDING' AND account_id IS NULL AND account_number IS NULL;
    IF changed<>0 THEN RAISE EXCEPTION 'Supported redelivery was not declined'; END IF;
   ELSIF label='unsupported direct repeat' THEN
    second_call:=pg_temp.pdc_call(-1065501);
   ELSIF label='unsupported no completion' THEN
    SELECT casefile_status='PUBLISHING_PENDING' AND account_id IS NULL AND account_number IS NULL
     INTO model_state_ok FROM public.draft_casefiles WHERE draft_casefile_id=-1065501;
   END IF;
   RAISE EXCEPTION USING ERRCODE='P5599',MESSAGE='Synthetic explicit caller rollback';
  EXCEPTION WHEN SQLSTATE 'P5502' OR SQLSTATE 'P5599' THEN GET STACKED DIAGNOSTICS caught=RETURNED_SQLSTATE;
  END;
  after_scope:=pg_temp.pdc_scope();
  RETURN NEXT ok(successful_graph,label||': CALL returned after complete final fan-in');
  RETURN NEXT is(caught,CASE WHEN label IN('output validation','snapshot duplicate','snapshot missing','snapshot unmatched','output duplicate','output missing','output unmatched','completion version mismatch','completion zero rows') THEN 'P5502' ELSE 'P5599' END,label||': intended outer caller failure/rollback');
  RETURN NEXT is(after_scope,before_scope,label||': earlier caller DML, graph, reservations and draft completion rolled back');
  RETURN NEXT ok(CASE WHEN label LIKE 'supported %' THEN model_state_ok AND merged IS NOT NULL AND
   NOT EXISTS(SELECT 1 FROM JSONB_ARRAY_ELEMENTS(snapshot->'minor_creditors') WITH ORDINALITY s
    WHERE (merged->'minor_creditors'->(s.ordinality::INTEGER-1))-ARRAY['account_id','account_number'] IS DISTINCT FROM s.value)
   AND (merged-ARRAY['respondent_account','applicant','minor_creditors'])=(snapshot-ARRAY['respondent_account','applicant','minor_creditors'])
   AND (merged->'respondent_account')-ARRAY['account_id','account_number']=snapshot->'respondent_account'
   AND (merged->'applicant')-ARRAY['account_id','account_number']=snapshot->'applicant'
   AND JSONB_BUILD_OBJECT('account_id',merged#>'{respondent_account,account_id}',
    'account_number',merged#>'{respondent_account,account_number}')=original_fragment->'respondent_account'
   AND JSONB_BUILD_OBJECT('account_id',merged#>'{applicant,account_id}',
    'account_number',merged#>'{applicant,account_number}')=original_fragment->'applicant_account'
   AND NOT EXISTS(SELECT 1 FROM JSONB_ARRAY_ELEMENTS(original_fragment->'minor_creditor_accounts') r
    LEFT JOIN LATERAL (SELECT value FROM JSONB_ARRAY_ELEMENTS(merged->'minor_creditors')
     WHERE value->'creditor_sequence'=r.value->'creditor_sequence') m ON TRUE
    WHERE m.value->'account_id' IS DISTINCT FROM r.value->'account_id'
     OR m.value->'account_number' IS DISTINCT FROM r.value->'account_number')
   AND changed=0
   WHEN label='unsupported direct repeat' THEN second_call->>'completed'='true'
    AND second_call->>'respondent_id'<>first_call->>'respondent_id'
    AND JSONB_ARRAY_LENGTH(second_call->'created_ids'->'respondent_account_parties')=3
   WHEN label='unsupported no completion' THEN model_state_ok
   WHEN label LIKE 'completion %' THEN merged IS NOT NULL AND changed=0
   WHEN label='explicit caller rollback' THEN merged IS NOT NULL AND JSONB_ARRAY_LENGTH(merged->'minor_creditors')=3
   ELSE merged IS NULL END,label||': intended caller stage, keyed names or unsupported duplicate graph');
 END LOOP;
END;
$checks$;
SELECT * FROM pg_temp.pdc_caller_assertions();
-- Scenario: Persisted authority and exact accepted author strings cross the real graph.
-- Setup: All three persisted types; embedded copies omitted, then independently conflicting.
-- Expected: No new embedded requirement, exact authors and unchanged original draft.
CREATE FUNCTION pg_temp.pdc_authority_assertions() RETURNS SETOF TEXT LANGUAGE plpgsql AS $checks$
DECLARE kind public.t_casefile_type_enum; payload JSON; observed JSONB; ids JSONB; original JSONB; label TEXT; seed JSONB; direct JSONB;
BEGIN
 FOREACH kind IN ARRAY ARRAY['REMO In','REMO Out','REMO Out (CMS)']::public.t_casefile_type_enum[] LOOP
  payload:=pg_temp.pdc_task5_payload();
  UPDATE public.draft_casefiles SET casefile=payload,casefile_type=kind,submitted_by=' P55_SUBMIT ',
   submitted_by_name=' Synthetic saved submitter ',version_number=NULL WHERE draft_casefile_id=-1065501;
  original:=pg_temp.pdc_scope();
  BEGIN
   observed:=pg_temp.pdc_call(-1065501); ids:=observed->'created_ids';
   RETURN NEXT ok(observed->>'completed'='true',kind||': persisted type accepted with embedded BU/type omitted');
   RETURN NEXT ok(EXISTS(SELECT 1 FROM public.respondent_accounts WHERE respondent_account_id=(observed->>'respondent_id')::BIGINT
    AND business_unit_id=32055 AND casefile_type=kind),kind||': persisted BU/type authoritative');
   RETURN NEXT ok((SELECT COUNT(*)=9 AND BOOL_AND(posted_by=' P55_SUBMIT ' AND posted_by_name=' Synthetic saved submitter ')
    FROM public.order_terms WHERE ids->'order_terms' @> TO_JSONB(ARRAY[order_terms_id]))
    AND (SELECT COUNT(*)=1 AND BOOL_AND(posted_by=' P55_SUBMIT ' AND posted_by_name=' Synthetic saved submitter ')
    FROM public.notes WHERE ids->'notes' @> TO_JSONB(ARRAY[note_id])),kind||': exact saved author whitespace retained');
   RETURN NEXT ok(observed->'before'->'draft_raw'=observed->'after'->'draft_raw',kind||': original payload/snapshot/timeline unchanged');
   RAISE EXCEPTION USING ERRCODE='P5599',MESSAGE='pdc authority cleanup';
  EXCEPTION WHEN SQLSTATE 'P5599' THEN NULL;
  END;
  RETURN NEXT is(pg_temp.pdc_scope(),original,kind||': successful graph caller rollback');
 END LOOP;
 FOREACH label IN ARRAY ARRAY['business_unit_id','casefile_type'] LOOP
  payload:=pg_temp.pdc_task5_payload();
  UPDATE public.draft_casefiles SET casefile=payload,casefile_type='REMO In',submitted_by='P55_SUBMIT',
   submitted_by_name='Synthetic saved submitter' WHERE draft_casefile_id=-1065501;
  original:=pg_temp.pdc_scope();
  BEGIN
   seed:=pg_temp.pdc_call(-1065501);
   payload:=pg_temp.pdc_put(payload,ARRAY['respondent_account',label],CASE label WHEN 'business_unit_id' THEN '32054'::JSON ELSE '"REMO Out"'::JSON END);
   UPDATE public.draft_casefiles SET casefile=payload WHERE draft_casefile_id=-1065501;
   direct:=pg_temp.pdc_diagnostic(pg_temp.pdc_direct('respondent','Respondent',payload,seed));
   observed:=pg_temp.pdc_call(-1065501);
   RAISE EXCEPTION USING ERRCODE='P5599',MESSAGE='pdc contradiction cleanup';
  EXCEPTION WHEN SQLSTATE 'P5599' THEN NULL;
  END;
  RETURN NEXT is(observed->>'code','P0001',label||': embedded contradiction rejected');
  RETURN NEXT is(observed-ARRAY['before','after','created_ids','context'],direct-'context',label||': unchanged direct Respondent diagnostics');
  RETURN NEXT ok(POSITION('p_insert_respondent_account' IN observed->>'context')>0 AND observed->'before'=observed->'after',label||': child owns contradiction and complete rollback');
  RETURN NEXT is(pg_temp.pdc_scope(),original,label||': fixture and prior seed removed');
 END LOOP;
END;
$checks$;
SELECT * FROM pg_temp.pdc_authority_assertions();
-- Final observed control absence; retained restoration RED deliberately expected one delegate.
SELECT is((SELECT COUNT(*) FROM pg_proc WHERE pronamespace='public'::REGNAMESPACE AND proname LIKE 'pdc_original%'),
 0::BIGINT,'observed wrapper restoration count is zero after every control');
SELECT ok((SELECT NOT armed FROM pg_temp.pdc_canary),'missing-output entry canaries restored after retained command-failing RED');
-- Scenario: Absent Note must skip the helper entirely, even if a no-op call would leave zero rows.
-- Setup: Entry rejection wrapper; original helper retained and restored by subtransaction abort.
-- Expected: Successful no-Note graph, exact catalogue/DDL-lock restoration, real recovery.
CREATE FUNCTION pg_temp.pdc_skip_and_caller_assertions() RETURNS SETOF TEXT LANGUAGE plpgsql AS $checks$
DECLARE payload JSON; original JSONB; scope JSONB; observed JSONB; proc RECORD; caller_scope JSONB; survived BOOLEAN;
BEGIN
 SELECT g.payload INTO payload FROM pdc_graph_cases g WHERE ordinal=1;
 payload:=pg_temp.pdc_put(payload,ARRAY['respondent_account','order_details','date_arrears_last_updated'],
  TO_JSON((TRANSACTION_TIMESTAMP() AT TIME ZONE 'Europe/London')::DATE::TEXT));
 payload:=pg_temp.pdc_put(payload,ARRAY['respondent_account','account_comment'],'"Synthetic comment does not create a Note"');
 UPDATE public.draft_casefiles SET casefile=payload WHERE draft_casefile_id=-1065501;
 original:=pg_temp.pdc_catalogue(); scope:=pg_temp.pdc_scope();
 BEGIN
  SELECT p.*,PG_GET_FUNCTION_IDENTITY_ARGUMENTS(p.oid) identity_args,PG_GET_FUNCTION_ARGUMENTS(p.oid) arguments INTO STRICT proc
   FROM pg_proc p WHERE pronamespace='public'::REGNAMESPACE AND proname='p_insert_notes';
  EXECUTE FORMAT('ALTER PROCEDURE public.p_insert_notes(%s) RENAME TO pdc_original_notes',proc.identity_args);
  EXECUTE FORMAT('CREATE PROCEDURE public.p_insert_notes(%s) LANGUAGE plpgsql AS %L',proc.arguments,
   'BEGIN RAISE EXCEPTION USING ERRCODE=''P5503'',MESSAGE=''Synthetic absent Note helper unexpectedly entered''; END;');
  observed:=pg_temp.pdc_call(-1065501);
  RAISE EXCEPTION USING ERRCODE='P5599',MESSAGE='pdc absent Note cleanup';
 EXCEPTION WHEN SQLSTATE 'P5599' THEN NULL;
 END;
 RETURN NEXT ok(observed->>'completed'='true','absent Note: fail-on-entry proves zero helper calls');
 RETURN NEXT is(observed->'created_ids'->'notes','[]'::JSONB,'absent Note: zero rows including account-comment side effects');
 RETURN NEXT is(pg_temp.pdc_catalogue(),original,'absent Note: original identity and DDL locks restored');
 RETURN NEXT is(pg_temp.pdc_scope(),scope,'absent Note: success graph caller rollback');
 BEGIN
  observed:=pg_temp.pdc_call(-1065501);
  RAISE EXCEPTION USING ERRCODE='P5599',MESSAGE='pdc skip recovery cleanup';
 EXCEPTION WHEN SQLSTATE 'P5599' THEN NULL;
 END;
 RETURN NEXT ok(observed->>'completed'='true','absent Note: unchanged real helpers succeed after restoration');

 UPDATE public.draft_casefiles SET casefile=pg_temp.pdc_task5_payload() WHERE draft_casefile_id=-1065501;
 original:=pg_temp.pdc_catalogue(); scope:=pg_temp.pdc_scope();
 BEGIN
  UPDATE public.draft_casefiles SET status_message='Synthetic caller survives caught failure' WHERE draft_casefile_id=-1065599;
  caller_scope:=pg_temp.pdc_scope();
  CREATE TRIGGER pdc_owned_fault BEFORE INSERT ON public.notes FOR EACH ROW
   EXECUTE FUNCTION pg_temp.pdc_fault('TRUE','Synthetic caught child failure','P5501');
  observed:=pg_temp.pdc_call(-1065501);
  survived:=EXISTS(SELECT 1 FROM public.draft_casefiles WHERE draft_casefile_id=-1065599 AND status_message='Synthetic caller survives caught failure');
  RETURN NEXT ok(survived,'caught failing CALL: earlier caller DML remains until caller rollback');
  RETURN NEXT is(observed->>'message','Synthetic caught child failure','caught failing CALL: intended late child failure reached');
  RETURN NEXT is(pg_temp.pdc_scope(),caller_scope,'caught failing CALL: only protected publication writes unwind');
  RAISE EXCEPTION USING ERRCODE='P5599',MESSAGE='pdc caller failure cleanup';
 EXCEPTION WHEN SQLSTATE 'P5599' THEN NULL;
 END;
 RETURN NEXT is(pg_temp.pdc_scope(),scope,'caught failing CALL: outer caller rollback then removes earlier DML');
 RETURN NEXT is(pg_temp.pdc_catalogue(),original,'caught failing CALL: fault control and DDL locks restored');
END;
$checks$;
SELECT * FROM pg_temp.pdc_skip_and_caller_assertions();

-- -----------------------------------------------------------------------------
-- Scenario: Real independent caller sessions serialize publication of one draft.
-- Setup: Distinct committed test fixtures; worker-local caller models, not backend code.
-- Expected: Lock before preflight, one CALL, keyed completion, durable reconciliation,
--           actual 55P03/full retry and independently committed cleanup.
-- No supported edit/delete writer exists in the accepted Add-only application.
-- These SQL models do not simulate network commit-ack loss or message settlement.
-- -----------------------------------------------------------------------------
DO $gate$
BEGIN
 IF CURRENT_DATABASE()<>'opal_maintenance_db_unit_test' OR CURRENT_USER<>'postgres' THEN
  RAISE EXCEPTION 'Publication concurrency requires the maintained disposable target';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_available_extensions WHERE name='dblink') THEN
  RAISE EXCEPTION 'Publication concurrency requires dblink';
 END IF;
END;
$gate$;
CREATE EXTENSION IF NOT EXISTS dblink WITH SCHEMA public;
DO $namespace$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_extension WHERE extname='dblink' AND extnamespace='public'::REGNAMESPACE) THEN
  RAISE EXCEPTION 'Publication concurrency requires public dblink';
 END IF;
END;
$namespace$;

-- Copied into each worker's own temporary schema before its publication transaction.
CREATE FUNCTION pg_temp.pdc_worker(draft_id BIGINT) RETURNS JSONB LANGUAGE plpgsql AS $worker$
DECLARE draft public.draft_casefiles%ROWTYPE; respondent BIGINT; number VARCHAR; fragment JSON;
 merged JSONB; changed BIGINT; calls INTEGER; after_row public.draft_casefiles%ROWTYPE;
BEGIN
 SELECT * INTO STRICT draft FROM public.draft_casefiles WHERE draft_casefile_id=draft_id FOR UPDATE;
 IF CURRENT_SETTING('transaction_isolation')<>'read committed' THEN
  RAISE EXCEPTION 'Synthetic caller requires READ COMMITTED';
 END IF;
 IF draft.casefile_status='PUBLISHED' THEN
  IF draft.account_id IS NULL OR draft.account_number IS NULL
   OR (draft.casefile_snapshot#>>'{respondent_account,account_id}')::BIGINT IS DISTINCT FROM draft.account_id
   OR draft.casefile_snapshot#>>'{respondent_account,account_number}' IS DISTINCT FROM draft.account_number
   OR NOT EXISTS(SELECT 1 FROM public.respondent_accounts WHERE respondent_account_id=draft.account_id
     AND account_number=draft.account_number AND business_unit_id=draft.business_unit_id) THEN
   RAISE EXCEPTION 'Synthetic reconciliation inconsistent completion';
  END IF;
  SELECT count INTO calls FROM pdc_worker_calls;
  RETURN JSONB_BUILD_OBJECT('action','declined','calls',calls,'version',draft.version_number,
   'id',draft.account_id,'number',draft.account_number,'snapshot',draft.casefile_snapshot::JSONB);
 END IF;
 -- Modeled eligibility/current-payload preflight only: detailed backend validation is separate.
 IF draft.casefile_status<>'PUBLISHING_PENDING' OR draft.account_id IS NOT NULL OR draft.account_number IS NOT NULL
  OR draft.validated_date IS NULL OR draft.validated_by IS NULL OR draft.validated_by=draft.submitted_by
  OR JSON_TYPEOF(draft.casefile) IS DISTINCT FROM 'object' THEN
  RAISE EXCEPTION 'Synthetic preflight rejected current draft';
 END IF;
 UPDATE pdc_worker_calls SET count=count+1 RETURNING count INTO calls;
 IF calls<>1 THEN RAISE EXCEPTION 'Synthetic caller invoked more than once'; END IF;
 CALL public.p_process_draft_casefiles(draft_id,respondent,number,fragment);
 IF respondent IS NULL OR number IS NULL OR number='' OR fragment IS NULL
  OR (fragment#>>'{respondent_account,account_id}')::BIGINT IS DISTINCT FROM respondent
  OR fragment#>>'{respondent_account,account_number}' IS DISTINCT FROM number THEN
  RAISE EXCEPTION 'Synthetic caller output inconsistent';
 END IF;
 merged:=pg_temp.pdc_merge(draft.casefile_snapshot::JSONB,fragment::JSONB);
 UPDATE public.draft_casefiles SET account_id=respondent,account_number=number,casefile_status='PUBLISHED',
  casefile_snapshot=merged::JSON,version_number=COALESCE(version_number,0)+1
 WHERE draft_casefile_id=draft_id AND casefile_status='PUBLISHING_PENDING'
  AND account_id IS NULL AND account_number IS NULL AND version_number IS NOT DISTINCT FROM draft.version_number;
 GET DIAGNOSTICS changed=ROW_COUNT;
 IF changed<>1 THEN RAISE EXCEPTION 'Synthetic caller completion cardinality'; END IF;
 SELECT * INTO STRICT after_row FROM public.draft_casefiles WHERE draft_casefile_id=draft_id;
 RETURN JSONB_BUILD_OBJECT('action','published','calls',calls,'observed_version',draft.version_number,
  'version',after_row.version_number,'id',respondent,'number',number,'fragment',fragment::JSONB,
  'snapshot_before',draft.casefile_snapshot::JSONB,'snapshot',merged,'changed',changed,
  'approval_preserved',ROW(after_row.validated_date,after_row.validated_by,after_row.validated_by_name)
    IS NOT DISTINCT FROM ROW(draft.validated_date,draft.validated_by,draft.validated_by_name),
  'timeline_preserved',after_row.timeline_data::TEXT IS NOT DISTINCT FROM draft.timeline_data::TEXT,
  'source_preserved',after_row.casefile::TEXT IS NOT DISTINCT FROM draft.casefile::TEXT,
  'pid',PG_BACKEND_PID(),'isolation',CURRENT_SETTING('transaction_isolation'));
END;
$worker$;

CREATE FUNCTION pg_temp.pdc_race(mode TEXT) RETURNS JSONB LANGUAGE plpgsql AS $race$
DECLARE connection TEXT; name TEXT; definition TEXT; routine REGPROCEDURE;
 fixture_owned BOOLEAN:=FALSE; async_pending BOOLEAN:=FALSE; blocked BOOLEAN:=FALSE; cleanup_canceled BOOLEAN:=FALSE;
 fixture_pid INTEGER; a_pid INTEGER; b_pid INTEGER; deadline TIMESTAMPTZ;
 a JSONB; b JSONB; winner JSONB; durable JSONB; graph JSONB; original JSONB; remaining BIGINT;
 timeout_state TEXT; timeout_calls INTEGER; aborted_state TEXT; primary_state TEXT; primary_message TEXT;
 cleanup_errors TEXT[]:=ARRAY[]::TEXT[];
 payload JSON; snapshot JSON; before_scope JSONB; catalogue JSONB;
BEGIN
 IF mode NOT IN('commit','rollback','timeout','uncertain','redelivery','cleanup control') OR mode IS NULL THEN
  RAISE EXCEPTION 'Unknown publication race mode';
 END IF;
 IF COALESCE(public.DBLINK_GET_CONNECTIONS(),ARRAY[]::TEXT[]) && ARRAY['po10655_fixture','po10655_a','po10655_b'] THEN
  RAISE EXCEPTION 'Publication connection-name collision';
 END IF;
 before_scope:=pg_temp.pdc_scope(); catalogue:=pg_temp.pdc_catalogue();
 connection:=FORMAT('host=127.0.0.1 port=5432 dbname=%L user=postgres connect_timeout=5 options=%L',
  CURRENT_DATABASE(),'-csearch_path=pg_catalog,public -cstatement_timeout=15000 -clock_timeout=10000 -ctimezone=UTC -cidle_in_transaction_session_timeout=30000');
 payload:=$payload${"respondent_account":{"application_code":"PDC56","respondent":{"party_details":{"organisation":false,"individual_details":{"surname":"Synthetic Race Respondent"},"address":{"address_line_1":"Race Respondent address","cjs_code":31053}}},"order_details":{"date_ordered":"2024-01-01","date_arrears_last_updated":"2024-01-01","payment_period":"Monthly","interest_flag":false,"indexation":"None","payment_arrangement":"Court","order_terms":[{"result_id":"P56A","creditor_type":"Applicant","result_responses":[{"parameter_name":"Amount","response":"12.30"}]}]}},"applicant":{"party_details":{"organisation":false,"individual_details":{"surname":"Synthetic Race Applicant"},"address":{"address_line_1":"Race Applicant address","cjs_code":31053}},"bank_account_details":{"bank_account_type":"None or not applicable"}},"minor_creditors":[{"creditor_sequence":91,"party_details":{"organisation":false,"individual_details":{"surname":"Synthetic Race Ninety One"},"address":{"address_line_1":"Race Minor address","cjs_code":31053}},"bank_account_details":{"bank_account_type":"None or not applicable"}},{"creditor_sequence":7,"party_details":{"organisation":false,"individual_details":{"surname":"Synthetic Race Seven"},"address":{"address_line_1":"Race Minor address","cjs_code":31053}},"bank_account_details":{"bank_account_type":"None or not applicable"}}]}$payload$::JSON;
 snapshot:='{"respondent_account":{"respondent_name":"Retained Respondent","other":1},"applicant":{"applicant_name":"Retained Applicant","other":2},"minor_creditors":[{"creditor_sequence":7,"name":"Retained Seven","other":7},{"creditor_sequence":91,"name":"Retained Ninety One","other":91}],"untouched":{"value":true}}'::JSON;
 BEGIN
  PERFORM public.DBLINK_CONNECT('po10655_fixture',connection);
  PERFORM public.DBLINK_EXEC('po10655_fixture',$setup$
   BEGIN;
   DO $collision$ BEGIN
    IF EXISTS(SELECT 1 FROM public.business_units WHERE business_unit_id=32053 OR business_unit_code='P053')
     OR EXISTS(SELECT 1 FROM public.countries WHERE country_id=-1065601 OR cjs_code=31053)
     OR EXISTS(SELECT 1 FROM public.maintenance_applications WHERE application_id=-10656 OR application_code='PDC56')
     OR EXISTS(SELECT 1 FROM public.results WHERE result_id='P56A')
     OR EXISTS(SELECT 1 FROM public.draft_casefiles WHERE draft_casefile_id=-1065601) THEN
     RAISE EXCEPTION 'Publication remote fixture collision';
    END IF;
   END; $collision$;
   INSERT INTO public.business_units(business_unit_id,business_unit_code,business_unit_name,business_unit_type,welsh_language)
    VALUES(32053,'P053','Synthetic concurrency unit','Area',FALSE);
   INSERT INTO public.countries(country_id,cjs_code,country_name,date_used_from,active)
    VALUES(-1065601,31053,'Synthetic concurrency country',DATE '2000-01-01',TRUE);
   INSERT INTO public.maintenance_applications(application_id,application_code,application_title,application_group,active,date_used_from)
    VALUES(-10656,'PDC56','Synthetic concurrency application','Synthetic',TRUE,DATE '2000-01-01');
   INSERT INTO public.results(result_id,result_title,order_term,enforcement_result,case_result,active,order_accruing,
    requires_creditor,enforcement_hold,requires_enforcer,generates_hearing,generates_warrant,lists_monies,
    requires_employment_data,allow_additional_action,enf_next_permitted_actions,manual_enforcement,auto_enforcement,result_parameters)
    VALUES('P56A','Synthetic concurrency Result',TRUE,FALSE,FALSE,TRUE,FALSE,TRUE,FALSE,FALSE,FALSE,FALSE,FALSE,
    FALSE,FALSE,'',FALSE,FALSE,'[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":0,"max":10000,"language_dependent":false}]');
  $setup$);
  PERFORM public.DBLINK_EXEC('po10655_fixture',FORMAT($draft$
   INSERT INTO public.draft_casefiles(draft_casefile_id,business_unit_id,created_date,submitted_by,submitted_by_name,
    validated_date,validated_by,validated_by_name,casefile,casefile_snapshot,casefile_type,casefile_status,
    casefile_status_date,timeline_data,version_number)
   VALUES(-1065601,32053,TIMESTAMP '2024-01-01','P56_SUBMIT','Synthetic race submitter',TIMESTAMP '2024-01-02',
    'P56_APPROVE','Synthetic race approver',%L::JSON,%L::JSON,'REMO In','PUBLISHING_PENDING',TIMESTAMP '2024-01-02',
    '[ { "event" : "Synthetic race approval" } ]'::JSON,%s); COMMIT;
  $draft$,payload::TEXT,snapshot::TEXT,CASE WHEN mode IN('rollback','uncertain') THEN '4' ELSE 'NULL' END));
  fixture_owned:=TRUE;
  SELECT value INTO original FROM public.DBLINK('po10655_fixture',
   $row$SELECT ROW_TO_JSON(d)::JSONB||JSONB_BUILD_OBJECT('source_raw',d.casefile::TEXT,'timeline_raw',d.timeline_data::TEXT) FROM public.draft_casefiles d WHERE draft_casefile_id=-1065601$row$) x(value JSONB);
  IF original IS NULL THEN RAISE EXCEPTION 'Committed fixture not visible'; END IF;
  SELECT pid INTO fixture_pid FROM public.DBLINK('po10655_fixture','SELECT PG_BACKEND_PID()') x(pid INTEGER);
  FOREACH name IN ARRAY ARRAY['po10655_a','po10655_b'] LOOP
   PERFORM public.DBLINK_CONNECT(name,connection);
   PERFORM public.DBLINK_EXEC(name,'CREATE TEMP TABLE pdc_worker_calls(count INTEGER NOT NULL); INSERT INTO pdc_worker_calls VALUES(0)');
   FOREACH routine IN ARRAY ARRAY['pg_temp.pdc_merge(jsonb,jsonb)'::REGPROCEDURE,'pg_temp.pdc_worker(bigint)'::REGPROCEDURE] LOOP
    definition:=REGEXP_REPLACE(PG_GET_FUNCTIONDEF(routine),'pg_temp_[0-9]+\.', 'pg_temp.', 'g');
    PERFORM public.DBLINK_EXEC(name,definition);
   END LOOP;
  END LOOP;
  SELECT pid INTO a_pid FROM public.DBLINK('po10655_a','SELECT PG_BACKEND_PID()') x(pid INTEGER);
  SELECT pid INTO b_pid FROM public.DBLINK('po10655_b','SELECT PG_BACKEND_PID()') x(pid INTEGER);
  IF fixture_pid IS NULL OR a_pid IS NULL OR b_pid IS NULL OR fixture_pid IN(a_pid,b_pid,PG_BACKEND_PID())
   OR a_pid IN(b_pid,PG_BACKEND_PID()) OR b_pid=PG_BACKEND_PID() THEN
   RAISE EXCEPTION 'Publication requires four independent backends';
  END IF;
  PERFORM public.DBLINK_EXEC('po10655_a','BEGIN ISOLATION LEVEL READ COMMITTED');
  SELECT value INTO a FROM public.DBLINK('po10655_a','SELECT pg_temp.pdc_worker(-1065601)') x(value JSONB);
  IF mode='redelivery' THEN
   PERFORM public.DBLINK_EXEC('po10655_a','COMMIT');
  END IF;
  PERFORM public.DBLINK_EXEC('po10655_b','BEGIN ISOLATION LEVEL READ COMMITTED');
  IF mode='timeout' THEN PERFORM public.DBLINK_EXEC('po10655_b','SET LOCAL lock_timeout=''1s'''); END IF;
  IF public.DBLINK_SEND_QUERY('po10655_b','SELECT pg_temp.pdc_worker(-1065601)')<>1 THEN
   RAISE EXCEPTION 'Publication waiter dispatch failed';
  END IF;
  async_pending:=TRUE;
  IF mode<>'redelivery' THEN
   deadline:=CLOCK_TIMESTAMP()+INTERVAL '5 seconds';
   WHILE NOT(a_pid=ANY(PG_BLOCKING_PIDS(b_pid))) LOOP
    IF public.DBLINK_IS_BUSY('po10655_b')=0 OR CLOCK_TIMESTAMP()>deadline THEN
     RAISE EXCEPTION 'Publication waiter did not visibly block';
    END IF;
    PERFORM PG_SLEEP(0.01);
   END LOOP;
   blocked:=TRUE;
  END IF;
  IF mode='cleanup control' THEN
   RAISE EXCEPTION USING ERRCODE='P5601',MESSAGE='Synthetic failure with pending worker';
  END IF;
  IF mode='timeout' THEN
   deadline:=CLOCK_TIMESTAMP()+INTERVAL '5 seconds';
   WHILE public.DBLINK_IS_BUSY('po10655_b')=1 LOOP
    IF CLOCK_TIMESTAMP()>deadline THEN RAISE EXCEPTION 'Preflight timeout did not finish'; END IF;
    PERFORM PG_SLEEP(0.01);
   END LOOP;
   BEGIN
    SELECT value INTO b FROM public.DBLINK_GET_RESULT('po10655_b') x(value JSONB);
   EXCEPTION WHEN OTHERS THEN timeout_state:=SQLSTATE;
   END;
   PERFORM value FROM public.DBLINK_GET_RESULT('po10655_b') x(value JSONB);
   async_pending:=FALSE;
   IF timeout_state IS DISTINCT FROM '55P03' OR b IS NOT NULL THEN
    RAISE EXCEPTION 'Expected actual preflight 55P03 without successful output';
   END IF;
   BEGIN
    PERFORM value FROM public.DBLINK('po10655_b','SELECT 1') x(value INTEGER);
   EXCEPTION WHEN OTHERS THEN aborted_state:=SQLSTATE;
   END;
   PERFORM public.DBLINK_EXEC('po10655_b','ROLLBACK');
   SELECT count INTO timeout_calls FROM public.DBLINK('po10655_b','SELECT count FROM pdc_worker_calls') x(count INTEGER);
   IF aborted_state IS DISTINCT FROM '25P02' OR timeout_calls IS DISTINCT FROM 0 THEN
    RAISE EXCEPTION 'Timeout did not retain failed transaction without CALL';
   END IF;
   PERFORM public.DBLINK_EXEC('po10655_a','ROLLBACK');
   PERFORM public.DBLINK_EXEC('po10655_b','BEGIN ISOLATION LEVEL READ COMMITTED');
   SELECT value INTO b FROM public.DBLINK('po10655_b','SELECT pg_temp.pdc_worker(-1065601)') x(value JSONB);
  ELSE
   IF mode<>'redelivery' THEN
    PERFORM public.DBLINK_EXEC('po10655_a',CASE WHEN mode='rollback' THEN 'ROLLBACK' ELSE 'COMMIT' END);
   END IF;
   deadline:=CLOCK_TIMESTAMP()+INTERVAL '5 seconds';
   WHILE public.DBLINK_IS_BUSY('po10655_b')=1 LOOP
    IF CLOCK_TIMESTAMP()>deadline THEN RAISE EXCEPTION 'Publication waiter did not finish'; END IF;
    PERFORM PG_SLEEP(0.01);
   END LOOP;
   SELECT value INTO b FROM public.DBLINK_GET_RESULT('po10655_b') x(value JSONB);
   PERFORM value FROM public.DBLINK_GET_RESULT('po10655_b') x(value JSONB);
   async_pending:=FALSE;
  END IF;
  PERFORM public.DBLINK_EXEC('po10655_b','COMMIT');
  winner:=CASE WHEN mode IN('rollback','timeout') THEN b ELSE a END;
  SELECT value INTO durable FROM public.DBLINK('po10655_fixture',
   $row$SELECT ROW_TO_JSON(d)::JSONB||JSONB_BUILD_OBJECT('source_raw',d.casefile::TEXT,'timeline_raw',d.timeline_data::TEXT) FROM public.draft_casefiles d WHERE draft_casefile_id=-1065601$row$) x(value JSONB);
  -- Complete graph oracle is scoped to the committed fixture BU and typed relationships.
  SELECT value INTO graph FROM public.DBLINK('po10655_fixture',$graph$
   SELECT JSONB_BUILD_OBJECT(
    'respondents',(SELECT COUNT(*) FROM public.respondent_accounts WHERE business_unit_id=32053),
    'creditors',(SELECT COUNT(*) FROM public.creditor_accounts WHERE business_unit_id=32053),
    'parties',(SELECT COUNT(*) FROM public.parties WHERE country_id=-1065601),
    'terms',(SELECT COUNT(*) FROM public.order_terms WHERE respondent_account_id IN(SELECT respondent_account_id FROM public.respondent_accounts WHERE business_unit_id=32053)),
    'associations',(SELECT COUNT(*) FROM public.respondent_account_parties WHERE respondent_account_id IN(SELECT respondent_account_id FROM public.respondent_accounts WHERE business_unit_id=32053)),
    'reservations',(SELECT COUNT(*) FROM public.account_number_index WHERE business_unit_id=32053),
    'party_rows',(SELECT COALESCE(JSONB_AGG(TO_JSONB(p) ORDER BY party_id),'[]') FROM public.parties p WHERE country_id=-1065601),
    'rows',(SELECT COALESCE(JSONB_AGG(TO_JSONB(a) ORDER BY creditor_account_id),'[]') FROM public.creditor_accounts a WHERE business_unit_id=32053),
    'respondent',(SELECT TO_JSONB(a) FROM public.respondent_accounts a WHERE business_unit_id=32053),
    'links',(SELECT COALESCE(JSONB_AGG(TO_JSONB(p) ORDER BY association_type),'[]') FROM public.respondent_account_parties p WHERE respondent_account_id IN(SELECT respondent_account_id FROM public.respondent_accounts WHERE business_unit_id=32053)),
    'term_rows',(SELECT COALESCE(JSONB_AGG(TO_JSONB(t) ORDER BY order_terms_id),'[]') FROM public.order_terms t WHERE respondent_account_id IN(SELECT respondent_account_id FROM public.respondent_accounts WHERE business_unit_id=32053)),
    'reservation_rows',(SELECT COALESCE(JSONB_AGG(TO_JSONB(n) ORDER BY account_number),'[]') FROM public.account_number_index n WHERE business_unit_id=32053))
  $graph$) x(value JSONB);
 EXCEPTION WHEN query_canceled OR assert_failure OR OTHERS THEN
  primary_state:=SQLSTATE; primary_message:=SQLERRM;
 END;

 -- Cancel B while A still holds the lock; closing A first would release the waiter.
 -- Failure-path cleanup must not hide the primary error. Cancel/drain before reuse.
 FOREACH name IN ARRAY ARRAY['po10655_b','po10655_a'] LOOP
  IF name=ANY(COALESCE(public.DBLINK_GET_CONNECTIONS(),ARRAY[]::TEXT[])) THEN
   BEGIN
    IF name='po10655_b' AND async_pending THEN
     IF public.DBLINK_IS_BUSY(name)=1 THEN
      cleanup_canceled:=public.DBLINK_CANCEL_QUERY(name)='OK';
      IF NOT cleanup_canceled THEN RAISE EXCEPTION 'Worker cancellation failed'; END IF;
     END IF;
     deadline:=CLOCK_TIMESTAMP()+INTERVAL '5 seconds';
     WHILE public.DBLINK_IS_BUSY(name)=1 LOOP
      IF CLOCK_TIMESTAMP()>deadline THEN RAISE EXCEPTION 'Cleanup worker deadline'; END IF;
      PERFORM PG_SLEEP(0.01);
     END LOOP;
     -- fail_on_error=false consumes a canceled/error result without replacing the primary failure.
     PERFORM value FROM public.DBLINK_GET_RESULT(name,FALSE) x(value JSONB);
     PERFORM value FROM public.DBLINK_GET_RESULT(name,FALSE) x(value JSONB);
     async_pending:=FALSE;
    END IF;
    PERFORM public.DBLINK_EXEC(name,'ROLLBACK');
   EXCEPTION WHEN query_canceled OR assert_failure OR OTHERS THEN
    cleanup_errors:=ARRAY_APPEND(cleanup_errors,name||' rollback/drain: '||SQLSTATE);
   END;
   BEGIN PERFORM public.DBLINK_DISCONNECT(name);
   EXCEPTION WHEN query_canceled OR assert_failure OR OTHERS THEN
    cleanup_errors:=ARRAY_APPEND(cleanup_errors,name||' disconnect: '||SQLSTATE);
   END;
  END IF;
 END LOOP;
 BEGIN
  IF 'po10655_fixture'=ANY(COALESCE(public.DBLINK_GET_CONNECTIONS(),ARRAY[]::TEXT[])) THEN
   PERFORM public.DBLINK_EXEC('po10655_fixture','ROLLBACK');
   IF fixture_owned THEN
    PERFORM public.DBLINK_EXEC('po10655_fixture',$cleanup$
     BEGIN;
     CREATE TEMP TABLE pdc_cleanup_respondents AS SELECT respondent_account_id FROM public.respondent_accounts WHERE business_unit_id=32053;
     CREATE TEMP TABLE pdc_cleanup_creditors AS SELECT creditor_account_id FROM public.creditor_accounts WHERE business_unit_id=32053;
     CREATE TEMP TABLE pdc_cleanup_parties AS
      SELECT minor_creditor_party_id AS party_id FROM public.creditor_accounts WHERE business_unit_id=32053
      UNION SELECT associated_account_id FROM public.respondent_account_parties
       WHERE association_type='Respondent' AND respondent_account_id IN(SELECT respondent_account_id FROM public.respondent_accounts WHERE business_unit_id=32053);
     DELETE FROM public.draft_casefiles WHERE draft_casefile_id=-1065601 AND business_unit_id=32053;
     DELETE FROM public.notes WHERE associated_record_type='respondent_accounts'
      AND associated_record_id IN(SELECT respondent_account_id::TEXT FROM public.respondent_accounts WHERE business_unit_id=32053);
     DELETE FROM public.order_terms WHERE respondent_account_id IN(SELECT respondent_account_id FROM public.respondent_accounts WHERE business_unit_id=32053);
     DELETE FROM public.respondent_account_parties WHERE respondent_account_id IN(SELECT respondent_account_id FROM public.respondent_accounts WHERE business_unit_id=32053);
     DELETE FROM public.creditor_accounts WHERE business_unit_id=32053;
     DELETE FROM public.respondent_accounts WHERE business_unit_id=32053;
     DELETE FROM public.aliases WHERE party_id IN(SELECT party_id FROM pdc_cleanup_parties);
     DELETE FROM public.parties WHERE party_id IN(SELECT party_id FROM pdc_cleanup_parties);
     DELETE FROM public.account_number_index WHERE business_unit_id=32053;
     DELETE FROM public.results WHERE result_id='P56A';
     DELETE FROM public.maintenance_applications WHERE application_id=-10656 AND application_code='PDC56';
     DELETE FROM public.countries WHERE country_id=-1065601 AND cjs_code=31053;
     DELETE FROM public.business_units WHERE business_unit_id=32053 AND business_unit_code='P053';
     COMMIT;
    $cleanup$);
    SELECT count INTO remaining FROM public.DBLINK('po10655_fixture',$absence$
     SELECT (SELECT COUNT(*) FROM public.draft_casefiles WHERE draft_casefile_id=-1065601)
      +(SELECT COUNT(*) FROM public.respondent_accounts WHERE business_unit_id=32053)
      +(SELECT COUNT(*) FROM public.creditor_accounts WHERE business_unit_id=32053)
      +(SELECT COUNT(*) FROM public.account_number_index WHERE business_unit_id=32053)
      +(SELECT COUNT(*) FROM public.parties WHERE country_id=-1065601 OR party_id IN(SELECT party_id FROM pdc_cleanup_parties))
      +(SELECT COUNT(*) FROM public.aliases WHERE party_id IN(SELECT party_id FROM pdc_cleanup_parties))
      +(SELECT COUNT(*) FROM public.notes WHERE associated_record_type='respondent_accounts' AND associated_record_id IN(SELECT respondent_account_id::TEXT FROM pdc_cleanup_respondents))
      +(SELECT COUNT(*) FROM public.order_terms WHERE respondent_account_id IN(SELECT respondent_account_id FROM pdc_cleanup_respondents) OR creditor_account_id IN(SELECT creditor_account_id FROM pdc_cleanup_creditors))
      +(SELECT COUNT(*) FROM public.respondent_account_parties WHERE respondent_account_id IN(SELECT respondent_account_id FROM pdc_cleanup_respondents))
      +(SELECT COUNT(*) FROM public.results WHERE result_id='P56A')
      +(SELECT COUNT(*) FROM public.countries WHERE country_id=-1065601 OR cjs_code=31053)
      +(SELECT COUNT(*) FROM public.maintenance_applications WHERE application_id=-10656 OR application_code='PDC56')
      +(SELECT COUNT(*) FROM public.business_units WHERE business_unit_id=32053 OR business_unit_code='P053')
    $absence$) x(count BIGINT);
    IF remaining<>0 THEN RAISE EXCEPTION 'Committed publication fixtures remain'; END IF;
   END IF;
  ELSIF fixture_owned THEN RAISE EXCEPTION 'Owned fixture connection lost';
  END IF;
 EXCEPTION WHEN query_canceled OR assert_failure OR OTHERS THEN
  cleanup_errors:=ARRAY_APPEND(cleanup_errors,'fixture cleanup: '||SQLSTATE||' '||SQLERRM);
 END;
 BEGIN
  IF 'po10655_fixture'=ANY(COALESCE(public.DBLINK_GET_CONNECTIONS(),ARRAY[]::TEXT[])) THEN
   PERFORM public.DBLINK_DISCONNECT('po10655_fixture');
  END IF;
 EXCEPTION WHEN query_canceled OR assert_failure OR OTHERS THEN
  cleanup_errors:=ARRAY_APPEND(cleanup_errors,'fixture disconnect: '||SQLSTATE);
 END;
 IF COALESCE(public.DBLINK_GET_CONNECTIONS(),ARRAY[]::TEXT[]) && ARRAY['po10655_fixture','po10655_a','po10655_b'] THEN
  cleanup_errors:=ARRAY_APPEND(cleanup_errors,'owned connections remain');
 END IF;
 IF CARDINALITY(cleanup_errors)>0 OR (primary_state IS NOT NULL AND NOT(mode='cleanup control' AND primary_state='P5601')) THEN
  RAISE EXCEPTION USING ERRCODE=COALESCE(primary_state,'P0001'),MESSAGE=COALESCE(primary_message,'Publication cleanup failed'),
   DETAIL=ARRAY_TO_STRING(cleanup_errors,'; ');
 END IF;
 RETURN JSONB_BUILD_OBJECT('mode',mode,'blocked',blocked,'fixture_pid',fixture_pid,'a_pid',a_pid,'b_pid',b_pid,
  'local_pid',PG_BACKEND_PID(),'a',a,'b',b,'winner',winner,'durable',durable,'original',original,'graph',graph,
  'timeout',timeout_state,'aborted',aborted_state,'timeout_calls',timeout_calls,'primary',primary_state,
  'cleanup_errors',TO_JSONB(cleanup_errors),'remaining',remaining,'cleanup_canceled',cleanup_canceled,
  'scope_preserved',pg_temp.pdc_scope()=before_scope,'catalogue_preserved',pg_temp.pdc_catalogue()=catalogue);
END;
$race$;

CREATE TEMP TABLE pdc_race_observations(mode TEXT PRIMARY KEY,observation JSONB);
INSERT INTO pdc_race_observations SELECT mode,pg_temp.pdc_race(mode)
 FROM UNNEST(ARRAY['commit','rollback','timeout','uncertain','redelivery','cleanup control']) mode;
CREATE FUNCTION pg_temp.pdc_race_assertions() RETURNS SETOF TEXT LANGUAGE plpgsql AS $checks$
DECLARE r RECORD; o JSONB; w JSONB; g JSONB; d JSONB; s JSONB;
BEGIN
 FOR r IN SELECT * FROM pdc_race_observations ORDER BY mode LOOP
  o:=r.observation; w:=o->'winner'; g:=o->'graph'; d:=o->'durable'; s:=w->'snapshot_before';
  RETURN NEXT ok((o->>'remaining')::BIGINT=0 AND o->'cleanup_errors'='[]'::JSONB,r.mode||': independently committed fixture absence');
  RETURN NEXT ok((o->>'scope_preserved')::BOOLEAN,r.mode||': local graph and all reference rows preserved');
  RETURN NEXT ok((o->>'catalogue_preserved')::BOOLEAN,r.mode||': service catalogue ACL roles settings and DDL locks preserved');
  RETURN NEXT ok((SELECT COUNT(DISTINCT value)=4 FROM JSONB_ARRAY_ELEMENTS(JSONB_BUILD_ARRAY(o->'fixture_pid',o->'a_pid',o->'b_pid',o->'local_pid'))),r.mode||': four independent PIDs');
  RETURN NEXT ok(CASE WHEN r.mode='redelivery' THEN NOT(o->>'blocked')::BOOLEAN ELSE (o->>'blocked')::BOOLEAN END,r.mode||': required observable caller-preflight blocking');
  IF r.mode='cleanup control' THEN
   RETURN NEXT ok(o->>'primary'='P5601' AND o->>'cleanup_canceled'='true','pending-worker failure cancels the blocked worker and executes full cleanup');
   CONTINUE;
  END IF;
  RETURN NEXT ok(w->>'action'='published' AND w->>'calls'='1' AND w->>'changed'='1' AND w->>'isolation'='read committed',r.mode||': one CALL and exact-one completion');
  RETURN NEXT ok(CASE WHEN r.mode IN('rollback','timeout') THEN o#>>'{b,action}'='published' AND o#>>'{a,id}'<>o#>>'{b,id}' ELSE o#>>'{b,action}'='declined' AND o#>>'{b,calls}'='0' AND o#>>'{b,id}'=w->>'id' AND o#>'{b,version}'=d->'version_number' AND o#>'{b,snapshot}'=d->'casefile_snapshot' END,r.mode||': current-state winner and no duplicate publication');
  RETURN NEXT ok(d->>'casefile_status'='PUBLISHED' AND d->>'account_id'=w->>'id' AND d->>'account_number'=w->>'number'
   AND d->'casefile_snapshot'=w->'snapshot' AND d->'version_number'=w->'version'
   AND (w->>'observed_version')::BIGINT IS NOT DISTINCT FROM (o#>>'{original,version_number}')::BIGINT
   AND (w->>'version')::BIGINT=COALESCE((o#>>'{original,version_number}')::BIGINT,0)+1,r.mode||': durable scalar snapshot and independently observed nullable-version consistency');
  RETURN NEXT ok(w->>'approval_preserved'='true' AND w->>'timeline_preserved'='true' AND w->>'source_preserved'='true'
   AND d->'source_raw'=o#>'{original,source_raw}' AND d->'timeline_raw'=o#>'{original,timeline_raw}'
   AND d->'validated_date'=o#>'{original,validated_date}' AND d->'validated_by'=o#>'{original,validated_by}'
   AND d->'validated_by_name'=o#>'{original,validated_by_name}',r.mode||': independent durable approval timeline and raw source preserved');
  RETURN NEXT ok(s=o#>'{original,casefile_snapshot}' AND ((w->'snapshot')-ARRAY['respondent_account','applicant','minor_creditors'])=(s-ARRAY['respondent_account','applicant','minor_creditors'])
   AND (w#>'{snapshot,respondent_account}')-ARRAY['account_id','account_number']=s->'respondent_account'
   AND (w#>'{snapshot,applicant}')-ARRAY['account_id','account_number']=s->'applicant'
   AND NOT EXISTS(SELECT 1 FROM JSONB_ARRAY_ELEMENTS(w#>'{snapshot,minor_creditors}') WITH ORDINALITY m
    WHERE m.value-ARRAY['account_id','account_number'] IS DISTINCT FROM s->'minor_creditors'->(m.ordinality::INTEGER-1)),r.mode||': keyed merge preserves names order and unrelated fields');
  RETURN NEXT ok((w#>'{snapshot,respondent_account}') @> (w#>'{fragment,respondent_account}')
   AND (w#>'{snapshot,applicant}') @> (w#>'{fragment,applicant_account}')
   AND NOT EXISTS(SELECT 1 FROM JSONB_ARRAY_ELEMENTS(w#>'{fragment,minor_creditor_accounts}') f
    WHERE NOT EXISTS(SELECT 1 FROM JSONB_ARRAY_ELEMENTS(w#>'{snapshot,minor_creditors}') m WHERE m @> f)),r.mode||': every generated identity merged by sequence');
  RETURN NEXT ok(g @> '{"respondents":1,"creditors":3,"parties":4,"terms":1,"associations":2,"reservations":4}'::JSONB,r.mode||': exactly one complete committed graph');
  RETURN NEXT ok(g#>>'{respondent,respondent_account_id}'=w->>'id' AND g#>>'{respondent,account_number}'=w->>'number'
   AND NOT EXISTS(SELECT 1 FROM JSONB_ARRAY_ELEMENTS((w#>'{fragment,minor_creditor_accounts}')||JSONB_BUILD_ARRAY(w#>'{fragment,applicant_account}')) f
    WHERE NOT EXISTS(SELECT 1 FROM JSONB_ARRAY_ELEMENTS(g->'rows') c WHERE c->>'creditor_account_id'=f->>'account_id' AND c->>'account_number'=f->>'account_number'))
   AND NOT EXISTS(SELECT 1 FROM JSONB_ARRAY_ELEMENTS(g->'term_rows') t WHERE t->>'creditor_account_id' IS DISTINCT FROM w#>>'{fragment,applicant_account,account_id}')
   AND EXISTS(SELECT 1 FROM JSONB_ARRAY_ELEMENTS(g->'links') l WHERE l->>'association_type'='Applicant' AND l->>'associated_account_id'=w#>>'{fragment,applicant_account,account_id}')
   AND EXISTS(SELECT 1 FROM JSONB_ARRAY_ELEMENTS(g->'links') l JOIN JSONB_ARRAY_ELEMENTS(g->'party_rows') p ON p->>'party_id'=l->>'associated_account_id'
    WHERE l->>'association_type'='Respondent' AND p->>'surname'='Synthetic Race Respondent')
   AND EXISTS(SELECT 1 FROM JSONB_ARRAY_ELEMENTS(g->'rows') c JOIN JSONB_ARRAY_ELEMENTS(g->'party_rows') p ON p->>'party_id'=c->>'minor_creditor_party_id'
    WHERE c->>'creditor_account_id'=w#>>'{fragment,applicant_account,account_id}' AND p->>'surname'='Synthetic Race Applicant')
   AND NOT EXISTS(SELECT 1 FROM JSONB_ARRAY_ELEMENTS(w#>'{fragment,minor_creditor_accounts}') f
    WHERE NOT EXISTS(SELECT 1 FROM JSONB_ARRAY_ELEMENTS(g->'rows') c JOIN JSONB_ARRAY_ELEMENTS(g->'party_rows') p ON p->>'party_id'=c->>'minor_creditor_party_id'
     WHERE c->>'creditor_account_id'=f->>'account_id' AND p->>'surname'=CASE f->>'creditor_sequence' WHEN '91' THEN 'Synthetic Race Ninety One' WHEN '7' THEN 'Synthetic Race Seven' END)),r.mode||': identities parties terms and final association use correct domains');
  RETURN NEXT ok(NOT EXISTS(SELECT 1 FROM JSONB_ARRAY_ELEMENTS(g->'reservation_rows') n
   WHERE NOT((n->>'associated_record_type'='respondent_accounts' AND n->>'account_number'=w->>'number')
    OR(n->>'associated_record_type'='creditor_accounts' AND EXISTS(SELECT 1 FROM JSONB_ARRAY_ELEMENTS(g->'rows') c WHERE c->>'account_number'=n->>'account_number')))),r.mode||': every reservation belongs to the surviving graph');
  RETURN NEXT ok(CASE WHEN r.mode='timeout' THEN o->>'timeout'='55P03' AND o->>'aborted'='25P02' AND o->>'timeout_calls'='0'
   ELSE o->'timeout'='null'::JSONB END,r.mode||': actual preflight timeout and full retry evidence');
 END LOOP;
 RETURN NEXT ok(NOT(COALESCE(public.DBLINK_GET_CONNECTIONS(),ARRAY[]::TEXT[]) && ARRAY['po10655_fixture','po10655_a','po10655_b']),
  'all owned remote connections and their temporary helpers closed');
END;
$checks$;
SELECT * FROM pg_temp.pdc_race_assertions();
SELECT diag('PO-10655 independent caller model: '||JSONB_BUILD_OBJECT('mode',mode,'blocked',observation->'blocked',
 'local_pid',observation->'local_pid','fixture_pid',observation->'fixture_pid','a_pid',observation->'a_pid',
 'b_pid',observation->'b_pid','timeout',observation->'timeout','remaining',observation->'remaining',
 'cleanup_errors',observation->'cleanup_errors')::TEXT) FROM pdc_race_observations ORDER BY mode;

SELECT * FROM finish();
ROLLBACK;
