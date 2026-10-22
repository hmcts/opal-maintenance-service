/**
 * OPAL Program
 *
 * MODULE      : p_insert_respondent_account_pgtap_tests.sql
 *
 * DESCRIPTION : Verify the bounded account helper, mappings and installed clock.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket        Nature of Change
 * ----------  -------------  ------------  ----------------------------------------
 * 16/10/2026  Frankie Moran  PO-10650      Initial pgTAP test suite.
 * 22/10/2026  Frankie Moran  PO-10655      Port reviewed coverage to the Stage 3 migration lineage.
 */

-- OPAL-DB-UPGRADE {"id":"p_insert_respondent_account.create","candidate":"ddl/V1_58__create_p_insert_respondent_account_procedure.sql","scope":"both","data":"migration-created-only","inputs":["src/main/resources/db/migration/ddl/V1_6__create_business_units_table.sql","src/main/resources/db/migration/data/allEnvs/V1_7__insert_business_units_reference_data.sql","src/main/resources/db/migration/ddl/V1_8__create_results_table.sql","src/main/resources/db/migration/ddl/V1_11__create_maintenance_applications_table.sql","src/main/resources/db/migration/data/allEnvs/V1_12__insert_maintenance_applications_reference_data.sql","src/main/resources/db/migration/ddl/V1_14__create_draft_casefiles_table.sql","src/main/resources/db/migration/ddl/V1_15__allow_null_results_permitted_actions.sql","src/main/resources/db/migration/ddl/V1_17__create_associated_record_type_enum.sql","src/main/resources/db/migration/ddl/V1_18__create_configuration_items_table.sql","src/main/resources/db/migration/data/allEnvs/V1_19__insert_configuration_items_data.sql","src/main/resources/db/migration/data/allEnvs/V1_13__insert_results_reference_data.sql","src/main/resources/db/migration/data/allEnvs/V1_16__refresh_results_reference_data.sql","src/main/resources/db/migration/ddl/V1_21__create_debtor_detail_table.sql","src/main/resources/db/migration/ddl/V1_22__create_third_party_contact_table.sql","src/main/resources/db/migration/ddl/V1_23__create_account_number_index_table.sql","src/main/resources/db/migration/ddl/V1_26__create_respondent_accounts_table.sql","src/main/resources/db/migration/ddl/V1_30__add_draft_casefiles_account_id_foreign_key.sql","src/main/resources/db/migration/ddl/V1_31__create_f_get_check_letter.sql","src/main/resources/db/migration/ddl/V1_32__create_f_get_account_number.sql"],"contract":{"type":"additive","objects":{"created":[{"kind":"routine","identity":"public.p_insert_respondent_account(smallint,public.t_casefile_type_enum,json,bigint,bigint)"}],"replaced":[]},"preserve":{"rows":["public.business_units","public.respondent_accounts","public.account_number_index","public.draft_casefiles","public.maintenance_applications","public.results","public.configuration_items","public.debtor_detail","public.third_party_contact"],"tables":["public.business_units","public.respondent_accounts","public.account_number_index","public.draft_casefiles","public.maintenance_applications","public.results","public.configuration_items","public.debtor_detail","public.third_party_contact"],"routines":["public.f_get_account_number(smallint,public.t_associated_record_type_enum)","public.f_get_check_letter(character varying)"],"enums":["public.t_associated_record_type_enum","public.t_casefile_type_enum","public.t_payment_frequency_enum","public.t_da_account_status_enum","public.t_indexation_enum","public.t_payment_arrangement_enum"],"sequences":["public.respondent_account_id_seq","public.account_number_index_id_seq"]},"assertion":"p_insert_respondent_account.current"}}

\set ON_ERROR_STOP on
\if :{?opal_assertion_group}
 SELECT :'opal_assertion_group'='p_insert_respondent_account.current' AS supported_group \gset
 \if :supported_group
 \else
  DO $group$ BEGIN RAISE EXCEPTION 'Unsupported PO-10650 assertion group'; END; $group$;
 \endif
\endif
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SET LOCAL search_path = public, pg_catalog;
SET LOCAL TIME ZONE 'UTC';
SELECT plan(4359);

-- ---------------------------------------------------------------------------
-- Scenario: The exact bounded account procedure is installed.
-- Setup:    Fresh or candidate schema from maintained Flyway migrations.
-- Expected: One procedure has five IN and two OUT parameters without defaults.
-- ---------------------------------------------------------------------------
SELECT ok(TO_REGPROCEDURE('public.p_insert_respondent_account(smallint,public.t_casefile_type_enum,json,bigint,bigint)') IS NOT NULL,
          'account insertion procedure is installed');
SELECT is(prokind::TEXT, 'p', 'catalogue object is a procedure')
FROM pg_proc WHERE oid=TO_REGPROCEDURE('public.p_insert_respondent_account(smallint,public.t_casefile_type_enum,json,bigint,bigint)');
SELECT is(proargmodes::TEXT, '{i,i,i,i,i,o,o}', 'five IN and two OUT modes')
FROM pg_proc WHERE oid=TO_REGPROCEDURE('public.p_insert_respondent_account(smallint,public.t_casefile_type_enum,json,bigint,bigint)');
SELECT is(pronargdefaults, 0::SMALLINT, 'no argument defaults')
FROM pg_proc WHERE oid=TO_REGPROCEDURE('public.p_insert_respondent_account(smallint,public.t_casefile_type_enum,json,bigint,bigint)');
SELECT is(proargnames, ARRAY['pi_business_unit_id','pi_casefile_type','pi_respondent_account_json',
 'pi_debtor_detail_id','pi_third_party_contact_id','po_respondent_account_id','po_account_number']::TEXT[],
 'all parameter names in order')
FROM pg_proc WHERE oid=TO_REGPROCEDURE('public.p_insert_respondent_account(smallint,public.t_casefile_type_enum,json,bigint,bigint)');
-- ---------------------------------------------------------------------------
-- Scenario: Effective catalogue types, defaults and storage preserve the contract.
-- Setup:    The migration installed its one public procedure.
-- Expected: Exact types, ordinary invoker properties and unconstrained finance.
-- ---------------------------------------------------------------------------
SELECT is(proallargtypes, ARRAY['smallint'::REGTYPE::OID,'public.t_casefile_type_enum'::REGTYPE::OID,
    'json'::REGTYPE::OID,'bigint'::REGTYPE::OID,'bigint'::REGTYPE::OID,
    'bigint'::REGTYPE::OID,'varchar'::REGTYPE::OID], 'all seven effective parameter types')
FROM pg_proc WHERE oid=TO_REGPROCEDURE('public.p_insert_respondent_account(smallint,public.t_casefile_type_enum,json,bigint,bigint)');
SELECT is(l.lanname::TEXT,'plpgsql','procedure language is plpgsql')
FROM pg_proc p JOIN pg_language l ON l.oid=p.prolang
WHERE p.oid=TO_REGPROCEDURE('public.p_insert_respondent_account(smallint,public.t_casefile_type_enum,json,bigint,bigint)');
SELECT ok(NOT prosecdef AND NOT proisstrict AND NOT proleakproof AND NOT proretset
    AND provolatile='v' AND proparallel='u' AND proconfig IS NULL AND proargdefaults IS NULL,
    'ordinary invoker execution and default settings')
FROM pg_proc WHERE oid=TO_REGPROCEDURE('public.p_insert_respondent_account(smallint,public.t_casefile_type_enum,json,bigint,bigint)');
SELECT is(COUNT(*),1::BIGINT,'no accidental overload') FROM pg_proc
WHERE pronamespace='public'::REGNAMESPACE AND proname='p_insert_respondent_account';
SELECT is(ARRAY_AGG(atttypmod ORDER BY attname),ARRAY[-1,-1,-1,-1]::INTEGER[],
    'all financial storage is unconstrained numeric') FROM pg_attribute
WHERE attrelid='public.respondent_accounts'::REGCLASS
AND attname IN ('account_balance','orders_balance','orders_amount','total_arrears');
SELECT is(ARRAY_AGG(atttypmod ORDER BY attname),ARRAY[24,54,204,24]::INTEGER[],
    'account number and consumed bounded text retain storage widths') FROM pg_attribute
WHERE attrelid='public.respondent_accounts'::REGCLASS
AND attname IN ('account_number','ca_reference','originator_name','remo_reference');

-- ---------------------------------------------------------------------------
-- Scenario: Synthetic fixtures are owned and isolated from reference metadata.
-- Setup:    Collision-checked IDs/codes and rollback-only BU/application/children.
-- Expected: Valid MAT subset calls use the installed helper and actual allocator.
-- ---------------------------------------------------------------------------
DO $fixtures$
BEGIN
 IF EXISTS (SELECT 1 FROM public.business_units WHERE business_unit_id=31850 OR business_unit_code='P650')
 OR EXISTS (SELECT 1 FROM public.maintenance_applications WHERE application_id=31850 OR application_code='P10650')
 OR EXISTS (SELECT 1 FROM public.debtor_detail WHERE debtor_detail_id=918650)
 OR EXISTS (SELECT 1 FROM public.third_party_contact WHERE third_party_contact_id=918650) THEN
   RAISE EXCEPTION 'PO-10650 synthetic fixture collision';
 END IF;
END;
$fixtures$;
INSERT INTO public.business_units(business_unit_id,business_unit_code,business_unit_name,business_unit_type,welsh_language)
VALUES (31850,'P650','Synthetic account unit','Area',false);
INSERT INTO public.maintenance_applications(application_id,application_code,application_title,application_group,active,date_used_from,date_used_to)
VALUES (31850,'P10650','Synthetic account application','Synthetic',true,DATE '1900-01-01',DATE '2100-12-31');
INSERT INTO public.debtor_detail(debtor_detail_id) VALUES (918650);
INSERT INTO public.third_party_contact(third_party_contact_id,name_organisation,relationship,address_line_1,country,version_number)
VALUES (918650,'Synthetic contact','Synthetic','Synthetic address',1,1);

CREATE FUNCTION pg_temp.account_payload() RETURNS JSON LANGUAGE SQL AS $payload$
 SELECT '{"application_code":"P10650","order_details":{"date_ordered":"2024-01-01","date_arrears_last_updated":"2024-01-01","payment_period":"Monthly","interest_flag":false,"indexation":"None","payment_arrangement":"Court","order_terms":[{"result_id":"MAT","result_responses":[{"parameter_name":"Amount","response":"10.00"}]}]}}'::JSON
$payload$;
CREATE FUNCTION pg_temp.invoke_account(payload JSON, bu SMALLINT DEFAULT 31850,
 kind public.t_casefile_type_enum DEFAULT 'REMO In', debtor BIGINT DEFAULT NULL, contact BIGINT DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql AS $invoke$
DECLARE account_id BIGINT; account_number VARCHAR;
BEGIN
 CALL public.p_insert_respondent_account(bu,kind,payload,debtor,contact,account_id,account_number);
 RETURN JSONB_BUILD_OBJECT('id',account_id,'number',account_number);
END;
$invoke$;
SET LOCAL track_functions='pl';
CREATE FUNCTION pg_temp.allocator_calls() RETURNS BIGINT LANGUAGE SQL VOLATILE AS $calls$
 SELECT COALESCE((SELECT calls FROM pg_catalog.pg_stat_xact_user_functions
 WHERE funcid='public.f_get_account_number(smallint,public.t_associated_record_type_enum)'::REGPROCEDURE),0)
$calls$;
-- ---------------------------------------------------------------------------
-- Scenario: A nominal call creates exactly one account and matching reservation.
-- Setup:    Isolated BU/application/children, unchanged MAT metadata, global 13/7.
-- Expected: Both OUT values identify that row and every creation mapping agrees.
-- ---------------------------------------------------------------------------
UPDATE public.configuration_items SET item_value=CASE item_name
    WHEN 'DEFAULT_CHEQUE_CLEARANCE_PERIOD' THEN '13' ELSE '7' END
WHERE business_unit_id IS NULL
AND item_name IN ('DEFAULT_CHEQUE_CLEARANCE_PERIOD','DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD');
CREATE TEMP TABLE nominal_before AS SELECT
    (SELECT COUNT(*) FROM public.respondent_accounts) AS accounts,
    (SELECT COUNT(*) FROM public.account_number_index WHERE business_unit_id=31850) AS reservations,
    pg_temp.allocator_calls() AS calls;
CREATE TEMP TABLE nominal_output AS SELECT pg_temp.invoke_account(pg_temp.account_payload()) AS output;
SELECT is((SELECT COUNT(*) FROM public.respondent_accounts)-(SELECT accounts FROM nominal_before),
    1::BIGINT,'nominal call creates one account');
SELECT is((SELECT COUNT(*) FROM public.account_number_index WHERE business_unit_id=31850)
    -(SELECT reservations FROM nominal_before),1::BIGINT,'nominal call creates one BU reservation');
SELECT is(pg_temp.allocator_calls()-(SELECT calls FROM nominal_before),1::BIGINT,
    'completed allocator-call statistics increment once');
SELECT is((SELECT COUNT(*) FROM public.respondent_accounts a CROSS JOIN nominal_output n
    JOIN public.account_number_index i ON i.account_number=n.output->>'number'
    WHERE a.respondent_account_id=(n.output->>'id')::BIGINT
    AND a.account_number=n.output->>'number' AND i.business_unit_id=a.business_unit_id
    AND i.associated_record_type='respondent_accounts'),1::BIGINT,'both outputs match the account and typed BU reservation');
CREATE TEMP TABLE nominal_expected AS SELECT JSONB_BUILD_OBJECT(
    'business_unit_id',31850,'debtor_detail_id',NULL,'application_id',31850,
    'imposed_hearing_date',TIMESTAMP '2024-01-01','last_hearing_date',NULL,'last_hearing_court_id',NULL,
    'account_balance',0.00,'orders_balance',10*(SELECT COUNT(*)-1 FROM GENERATE_SERIES(
        TIMESTAMP '2024-01-01',(pg_catalog.TRANSACTION_TIMESTAMP() AT TIME ZONE 'Europe/London')::DATE,
        INTERVAL '1 month')),'orders_amount',10.00,'payment_period','Monthly','total_arrears',0.00,
    'account_status','L','completed_date',NULL,
    'last_movement_date',pg_catalog.TRANSACTION_TIMESTAMP() AT TIME ZONE 'UTC',
    'date_arrears_last_updated',TIMESTAMP '2024-01-01','last_enforcement_result_id',NULL,
    'last_enforcement_date',NULL,'originator_name',NULL,'allow_cheques',true,
    'cheque_clearance_period',13,'credit_trans_clearance_period',7,'casefile_type','REMO In',
    'third_party_contact_id',NULL,'remo_reference',NULL,'ca_reference',NULL,'interest_flag',false,
    'indexation','None','payment_arrangement','Court','account_comment',NULL,'version_number',1) AS row;
SELECT is(TO_JSONB(a)-'respondent_account_id'-'account_number',e.row,
    'every nominal creation column including configured values and native London balance')
FROM public.respondent_accounts a CROSS JOIN nominal_output n CROSS JOIN nominal_expected e
WHERE a.respondent_account_id=(n.output->>'id')::BIGINT;
CREATE TEMP TABLE optional_output AS SELECT pg_temp.invoke_account(
    (pg_temp.account_payload()::JSONB || JSONB_BUILD_OBJECT('business_unit_id',31850,
    'casefile_type','REMO Out','originator_name',' Synthetic originator Ω ',
    'remo_reference',' R650 ','central_authority_reference',' CA650 ','account_comment',' Synthetic comment '))::JSON,
    kind=>'REMO Out',debtor=>918650,contact=>918650) AS output;
SELECT is(TO_JSONB(a)-'respondent_account_id'-'account_number',e.row || JSONB_BUILD_OBJECT(
    'debtor_detail_id',918650,'third_party_contact_id',918650,'casefile_type','REMO Out',
    'originator_name',' Synthetic originator Ω ','remo_reference',' R650 ','ca_reference',' CA650 ',
    'account_comment',' Synthetic comment '),'optional children and exact characters map using persisted BU/type')
FROM public.respondent_accounts a CROSS JOIN optional_output n CROSS JOIN nominal_expected e
WHERE a.respondent_account_id=(n.output->>'id')::BIGINT;

-- ---------------------------------------------------------------------------
-- Scenario: Completed allocation remains observable after subtransaction rollback.
-- Setup:    A valid actual helper call followed by an enclosing test exception.
-- Expected: Statistics retain one completed call; account and ledger rows revert.
-- ---------------------------------------------------------------------------
CREATE TEMP TABLE allocation_calibration(calls BIGINT, accounts BIGINT, reservations BIGINT);
DO $calibrate$
DECLARE before_calls BIGINT; before_accounts BIGINT; before_reservations BIGINT;
BEGIN
    before_calls := pg_temp.allocator_calls();
    SELECT COUNT(*) INTO before_accounts FROM public.respondent_accounts;
    SELECT COUNT(*) INTO before_reservations FROM public.account_number_index WHERE business_unit_id=31850;
    BEGIN
        PERFORM pg_temp.invoke_account(pg_temp.account_payload());
        RAISE EXCEPTION USING MESSAGE='PO-10650 controlled test rollback';
    EXCEPTION WHEN raise_exception THEN
        IF SQLERRM <> 'PO-10650 controlled test rollback' THEN RAISE; END IF;
    END;
    INSERT INTO allocation_calibration SELECT pg_temp.allocator_calls()-before_calls,
        (SELECT COUNT(*) FROM public.respondent_accounts)-before_accounts,
        (SELECT COUNT(*) FROM public.account_number_index WHERE business_unit_id=31850)-before_reservations;
END;
$calibrate$;
SELECT is(calls,1::BIGINT,'completed allocator call survives enclosing rollback in statistics') FROM allocation_calibration;
SELECT ok(accounts=0 AND reservations=0,'controlled enclosing rollback restores both written tables') FROM allocation_calibration;

-- ---------------------------------------------------------------------------
-- Scenario: The installed procedure binds fixed and native clocks after caching.
-- Setup:    Rolled-back clock schema, sequence and state; caller path/zone changes.
-- Expected: One capture per entry, London three/four periods, exact native restore.
-- ---------------------------------------------------------------------------
CREATE TEMP TABLE routine_before AS
SELECT oid, PG_GET_FUNCTIONDEF(oid) AS definition, proconfig, proowner, proacl, prosecdef
FROM pg_proc WHERE oid='public.p_insert_respondent_account(smallint,public.t_casefile_type_enum,json,bigint,bigint)'::REGPROCEDURE;
SELECT pg_catalog.TRANSACTION_TIMESTAMP() AS instant,
 CURRENT_SETTING('search_path') AS path, CURRENT_SETTING('TimeZone') AS zone
\gset native_
CREATE TEMP TABLE clock_calls(label TEXT PRIMARY KEY, output JSONB, capture_count BIGINT, capture_before BIGINT);
INSERT INTO clock_calls(label,output) VALUES ('warm_native',pg_temp.invoke_account(pg_temp.account_payload()));
SAVEPOINT clock_scope;
CREATE SCHEMA opal_po10650_clock;
CREATE SEQUENCE opal_po10650_clock.capture_count START 1;
CREATE TABLE opal_po10650_clock.state(singleton BOOLEAN PRIMARY KEY CHECK(singleton), instant TIMESTAMPTZ NOT NULL);
INSERT INTO opal_po10650_clock.state VALUES (true,TIMESTAMPTZ '2027-03-31 23:30:00+00');
CREATE FUNCTION opal_po10650_clock.transaction_timestamp() RETURNS TIMESTAMPTZ
LANGUAGE plpgsql VOLATILE AS $clock$
DECLARE value TIMESTAMPTZ;
BEGIN
 PERFORM pg_catalog.NEXTVAL('opal_po10650_clock.capture_count'::REGCLASS);
 SELECT instant INTO STRICT value FROM opal_po10650_clock.state WHERE singleton;
 RETURN value;
END;
$clock$;
SET LOCAL search_path=opal_po10650_clock,pg_catalog,public;
SELECT CASE WHEN is_called THEN last_value ELSE 0 END AS before FROM opal_po10650_clock.capture_count
\gset sample_
INSERT INTO clock_calls(label,output) VALUES ('fixed_a',pg_temp.invoke_account(
 JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_arrears_last_updated}','"2027-01-01"')::JSON));
UPDATE clock_calls SET capture_before=:'sample_before'::BIGINT, capture_count=(SELECT CASE WHEN is_called THEN last_value ELSE 0 END FROM opal_po10650_clock.capture_count) WHERE label='fixed_a';
SELECT CASE WHEN is_called THEN last_value ELSE 0 END AS before FROM opal_po10650_clock.capture_count
\gset sample_
INSERT INTO clock_calls(label,output) VALUES ('fixed_cached',pg_temp.invoke_account(
 JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_arrears_last_updated}','"2027-01-01"')::JSON));
UPDATE clock_calls SET capture_before=:'sample_before'::BIGINT, capture_count=(SELECT CASE WHEN is_called THEN last_value ELSE 0 END FROM opal_po10650_clock.capture_count) WHERE label='fixed_cached';
UPDATE opal_po10650_clock.state SET instant=TIMESTAMPTZ '2027-04-30 23:30:00+00';
SELECT CASE WHEN is_called THEN last_value ELSE 0 END AS before FROM opal_po10650_clock.capture_count
\gset sample_
INSERT INTO clock_calls(label,output) VALUES ('fixed_b',pg_temp.invoke_account(
 JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_arrears_last_updated}','"2027-01-01"')::JSON));
UPDATE clock_calls SET capture_before=:'sample_before'::BIGINT, capture_count=(SELECT CASE WHEN is_called THEN last_value ELSE 0 END FROM opal_po10650_clock.capture_count) WHERE label='fixed_b';
SET LOCAL TIME ZONE 'Pacific/Honolulu';
SELECT CASE WHEN is_called THEN last_value ELSE 0 END AS before FROM opal_po10650_clock.capture_count
\gset sample_
INSERT INTO clock_calls(label,output) VALUES ('fixed_zone',pg_temp.invoke_account(
 JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_arrears_last_updated}','"2027-01-01"')::JSON));
UPDATE clock_calls SET capture_before=:'sample_before'::BIGINT, capture_count=(SELECT CASE WHEN is_called THEN last_value ELSE 0 END FROM opal_po10650_clock.capture_count) WHERE label='fixed_zone';
SET LOCAL search_path=pg_catalog,public;
SELECT pg_catalog.PG_SLEEP(0.02);
SELECT CASE WHEN is_called THEN last_value ELSE 0 END AS before FROM opal_po10650_clock.capture_count
\gset sample_
INSERT INTO clock_calls(label,output) VALUES ('native_again',pg_temp.invoke_account(pg_temp.account_payload()));
UPDATE clock_calls SET capture_before=:'sample_before'::BIGINT, capture_count=(SELECT CASE WHEN is_called THEN last_value ELSE 0 END FROM opal_po10650_clock.capture_count) WHERE label='native_again';
SET LOCAL search_path=opal_po10650_clock,pg_catalog,public;
SELECT CASE WHEN is_called THEN last_value ELSE 0 END AS before FROM opal_po10650_clock.capture_count
\gset sample_
INSERT INTO clock_calls(label,output) VALUES ('fixed_again',pg_temp.invoke_account(
 JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_arrears_last_updated}','"2027-01-01"')::JSON));
UPDATE clock_calls SET capture_before=:'sample_before'::BIGINT, capture_count=(SELECT CASE WHEN is_called THEN last_value ELSE 0 END FROM opal_po10650_clock.capture_count) WHERE label='fixed_again';
SELECT BOOL_AND(capture_count=CASE label WHEN 'fixed_a' THEN 1 WHEN 'fixed_cached' THEN 2
 WHEN 'fixed_b' THEN 3 WHEN 'fixed_zone' THEN 4 WHEN 'native_again' THEN 4 WHEN 'fixed_again' THEN 5 END) AS per_call_ok
FROM clock_calls WHERE label<>'warm_native'
\gset clock_
DO $failed_capture$
DECLARE before_count BIGINT; after_count BIGINT; state TEXT; message TEXT;
 calls_before BIGINT; sequence_before JSONB; sequence_after JSONB;
BEGIN
 SELECT CASE WHEN is_called THEN last_value ELSE 0 END INTO before_count FROM opal_po10650_clock.capture_count;
 calls_before := pg_temp.allocator_calls();
 SELECT JSONB_BUILD_ARRAY(last_value,is_called) INTO sequence_before FROM public.account_number_index_id_seq;
 BEGIN
  PERFORM pg_temp.invoke_account(JSONB_SET(pg_temp.account_payload()::JSONB,
   '{order_details,date_arrears_last_updated}','"2099-01-01"')::JSON);
 EXCEPTION WHEN OTHERS THEN
  GET STACKED DIAGNOSTICS state=RETURNED_SQLSTATE,message=MESSAGE_TEXT;
 END;
 SELECT CASE WHEN is_called THEN last_value ELSE 0 END INTO after_count FROM opal_po10650_clock.capture_count;
 SELECT JSONB_BUILD_ARRAY(last_value,is_called) INTO sequence_after FROM public.account_number_index_id_seq;
 IF state IS DISTINCT FROM 'P0001' OR message IS DISTINCT FROM 'p_insert_respondent_account: future arrears date'
 OR after_count-before_count<>1 OR pg_temp.allocator_calls()<>calls_before
 OR sequence_after IS DISTINCT FROM sequence_before THEN
  RAISE EXCEPTION 'PO-10650 failed-call capture observation failed';
 END IF;
END;
$failed_capture$;
SELECT (last_value=6 AND is_called) AS capture_count_ok FROM opal_po10650_clock.capture_count
\gset clock_
SELECT BOOL_AND(a.last_movement_date = CASE
 WHEN c.label IN ('fixed_a','fixed_cached') THEN TIMESTAMP '2027-03-31 23:30:00'
 WHEN c.label IN ('fixed_b','fixed_zone','fixed_again') THEN TIMESTAMP '2027-04-30 23:30:00'
 ELSE :'native_instant'::TIMESTAMPTZ AT TIME ZONE 'UTC' END) AS audit_ok
FROM clock_calls c JOIN public.respondent_accounts a ON a.respondent_account_id=(c.output->>'id')::BIGINT
\gset clock_
SELECT BOOL_AND(a.orders_amount=10 AND a.total_arrears=0 AND a.orders_balance=CASE
 WHEN c.label IN ('fixed_a','fixed_cached') THEN 30 ELSE 40 END) AS calendar_ok
FROM clock_calls c JOIN public.respondent_accounts a ON a.respondent_account_id=(c.output->>'id')::BIGINT
WHERE c.label IN ('fixed_a','fixed_cached','fixed_b','fixed_zone','fixed_again')
\gset clock_
SELECT NOT EXISTS (
 SELECT 1 FROM routine_before b JOIN pg_proc p ON p.oid=b.oid
 WHERE ROW(PG_GET_FUNCTIONDEF(p.oid),p.proconfig,p.proowner,p.proacl,p.prosecdef)
 IS DISTINCT FROM ROW(b.definition,b.proconfig,b.proowner,b.proacl,b.prosecdef)
) AS unchanged_ok
\gset clock_
SELECT BOOL_AND(capture_count-capture_before=CASE WHEN label='native_again' THEN 0 ELSE 1 END) AS delta_ok
FROM clock_calls WHERE label<>'warm_native'
\gset clock_
SELECT JSONB_AGG(TO_JSONB(c) ORDER BY label)::TEXT AS per_call_observations FROM clock_calls c;
ROLLBACK TO SAVEPOINT clock_scope;
RELEASE SAVEPOINT clock_scope;
SELECT ok(:'clock_capture_count_ok'::BOOLEAN AND :'clock_per_call_ok'::BOOLEAN,'five fixed successes and one entered failure each capture once; native binding stops the counter');
SELECT ok(:'clock_audit_ok'::BOOLEAN,'native/fixed/cached/zone switching uses expected exact instants');
SELECT ok(:'clock_calendar_ok'::BOOLEAN,'literal three/four-period outcomes use the intercepted London date');
SELECT ok(:'clock_unchanged_ok'::BOOLEAN,'installed definition and properties unchanged during interception');
SELECT ok(TO_REGNAMESPACE('opal_po10650_clock') IS NULL,'rollback removes clock schema, sequence, function and state');
SELECT is(CURRENT_SETTING('search_path'),:'native_path','rollback restores search_path');
SELECT is(CURRENT_SETTING('TimeZone'),:'native_zone','rollback restores TimeZone');


SELECT ok(:'clock_delta_ok'::BOOLEAN,'each sampled clock delta is one or zero for native binding');
SELECT is(a.last_movement_date,:'native_instant'::TIMESTAMPTZ AT TIME ZONE 'UTC',
    'warm native call captures the exact transaction-start instant')
FROM clock_calls c JOIN public.respondent_accounts a ON a.respondent_account_id=(c.output->>'id')::BIGINT
WHERE c.label='warm_native';
CREATE TEMP TABLE restored_native AS SELECT pg_temp.invoke_account(pg_temp.account_payload()) AS output;
SELECT is(TO_JSONB(a)-'respondent_account_id'-'account_number',e.row,
    'post-rollback native call restores exact audit instant and London-derived balance')
FROM public.respondent_accounts a CROSS JOIN restored_native n CROSS JOIN nominal_expected e
WHERE a.respondent_account_id=(n.output->>'id')::BIGINT;
SELECT ok(NOT EXISTS (
 SELECT 1 FROM routine_before b JOIN pg_proc p ON p.oid=b.oid
 WHERE ROW(PG_GET_FUNCTIONDEF(p.oid),p.proconfig,p.proowner,p.proacl,p.prosecdef)
 IS DISTINCT FROM ROW(b.definition,b.proconfig,b.proowner,b.proacl,b.prosecdef)),
 'installed definition and properties unchanged after clock rollback');


-- ---------------------------------------------------------------------------
-- Scenario: Every consumed input is typed and unambiguous before allocation.
-- Setup:    Original JSON negatives and ordinary JSONB mutations of valid input.
-- Expected: Six rollback assertions plus exact diagnostics and sequence evidence.
-- ---------------------------------------------------------------------------

DO $draft_fixture$
BEGIN
 IF EXISTS (SELECT 1 FROM public.draft_casefiles WHERE draft_casefile_id=918650)
 OR EXISTS (SELECT 1 FROM public.business_units WHERE business_unit_id=-31850 OR business_unit_code='P652') THEN
  RAISE EXCEPTION 'PO-10650 additional synthetic fixture collision';
 END IF;
END;
$draft_fixture$;
INSERT INTO public.business_units(business_unit_id,business_unit_code,business_unit_name,business_unit_type,welsh_language)
VALUES(-31850,'P652','Synthetic negative-ID unit','Area',false);
INSERT INTO public.draft_casefiles(draft_casefile_id,business_unit_id,created_date,submitted_by,
 submitted_by_name,casefile,casefile_snapshot,casefile_type,casefile_status,casefile_status_date,timeline_data)
VALUES(918650,31850,TIMESTAMP '2024-01-01','P10650','Synthetic contributor',
 '{ "synthetic":1,"synthetic":2 }','{ "marker":"P10650" }','REMO In','PUBLISHING_PENDING',
 TIMESTAMP '2024-01-01','[]');
CREATE TEMP TABLE protected_account_ids AS SELECT respondent_account_id FROM public.respondent_accounts;
CREATE TEMP TABLE protected_ledger_ids AS SELECT account_number_index_id FROM public.account_number_index;
CREATE TEMP TABLE protected_rows_before(table_name TEXT PRIMARY KEY, rows TEXT[]);
DO $snapshot$
DECLARE table_name TEXT; rows TEXT[];
BEGIN
 FOREACH table_name IN ARRAY ARRAY['parties','order_terms','notes','respondent_account_parties',
  'creditor_accounts','major_creditors','draft_casefiles','debtor_detail','third_party_contact',
  'results','maintenance_applications','configuration_items'] LOOP
  EXECUTE FORMAT('SELECT COALESCE(ARRAY_AGG(ROW_TO_JSON(r)::TEXT ORDER BY ROW_TO_JSON(r)::TEXT),ARRAY[]::TEXT[]) FROM public.%I r',table_name) INTO rows;
  INSERT INTO protected_rows_before VALUES(table_name,rows);
 END LOOP;
 INSERT INTO protected_rows_before SELECT 'respondent_accounts',
 COALESCE(ARRAY_AGG(ROW_TO_JSON(r)::TEXT ORDER BY ROW_TO_JSON(r)::TEXT),ARRAY[]::TEXT[])
 FROM public.respondent_accounts r;
 INSERT INTO protected_rows_before SELECT 'account_number_index',
 COALESCE(ARRAY_AGG(ROW_TO_JSON(r)::TEXT ORDER BY ROW_TO_JSON(r)::TEXT),ARRAY[]::TEXT[])
 FROM public.account_number_index r;
END;
$snapshot$;

CREATE TEMP TABLE rejection_observations(label TEXT, state TEXT, message TEXT, detail TEXT,
 hint TEXT, context TEXT, constraint_name TEXT, sequence_before JSONB, sequence_after JSONB);
CREATE FUNCTION pg_temp.observe_account_rejection(payload JSON, expected_state TEXT,
 expected_constraint TEXT DEFAULT NULL, bu SMALLINT DEFAULT 31850,
 kind public.t_casefile_type_enum DEFAULT 'REMO In', debtor BIGINT DEFAULT NULL,
 contact BIGINT DEFAULT NULL, expected_calls BIGINT DEFAULT 0)
RETURNS JSONB LANGUAGE plpgsql AS $reject$
DECLARE
 before_calls BIGINT := pg_temp.allocator_calls(); before_accounts BIGINT;
 before_ledger BIGINT; succeeded BOOLEAN := false; state TEXT; constraint_name TEXT;
 actual_id BIGINT; actual_number VARCHAR; message TEXT; detail TEXT; hint TEXT; context TEXT;
 sequence_before JSONB; sequence_after JSONB;
 label TEXT := COALESCE(CURRENT_SETTING('opal.po10650_case',true),'account rejection');
BEGIN
 SELECT COUNT(*) INTO before_accounts FROM public.respondent_accounts WHERE business_unit_id=bu;
 SELECT COUNT(*) INTO before_ledger FROM public.account_number_index WHERE business_unit_id=bu;
 SELECT JSONB_BUILD_ARRAY(last_value,is_called) INTO sequence_before FROM public.account_number_index_id_seq;
 BEGIN
  CALL public.p_insert_respondent_account(bu,kind,payload,debtor,contact,actual_id,actual_number);
  succeeded := true;
  RAISE EXCEPTION SQLSTATE 'ZX650' USING MESSAGE='test rollback after unexpected success';
 EXCEPTION
  WHEN SQLSTATE 'ZX650' THEN NULL;
  WHEN OTHERS THEN GET STACKED DIAGNOSTICS state=RETURNED_SQLSTATE,
   constraint_name=CONSTRAINT_NAME,message=MESSAGE_TEXT,detail=PG_EXCEPTION_DETAIL,
   hint=PG_EXCEPTION_HINT,context=PG_EXCEPTION_CONTEXT;
 END;
 SELECT JSONB_BUILD_ARRAY(last_value,is_called) INTO sequence_after FROM public.account_number_index_id_seq;
 INSERT INTO rejection_observations VALUES(label,state,message,detail,hint,context,
  constraint_name,sequence_before,sequence_after);
 RETURN JSONB_BUILD_OBJECT('succeeded',succeeded,'state',state,'constraint',constraint_name,
  'calls',pg_temp.allocator_calls()-before_calls,
  'accounts',(SELECT COUNT(*) FROM public.respondent_accounts WHERE business_unit_id=bu)-before_accounts,
  'ledger',(SELECT COUNT(*) FROM public.account_number_index WHERE business_unit_id=bu)-before_ledger);
END;
$reject$;
CREATE FUNCTION pg_temp.reject_account(payload JSON, expected_state TEXT,
 expected_constraint TEXT DEFAULT NULL, bu SMALLINT DEFAULT 31850,
 kind public.t_casefile_type_enum DEFAULT 'REMO In', debtor BIGINT DEFAULT NULL,
 contact BIGINT DEFAULT NULL, expected_calls BIGINT DEFAULT 0)
RETURNS SETOF TEXT LANGUAGE plpgsql AS $reject$
DECLARE observation JSONB; label TEXT:=COALESCE(CURRENT_SETTING('opal.po10650_case',true),'account rejection');
BEGIN
 observation:=pg_temp.observe_account_rejection(payload,expected_state,expected_constraint,bu,kind,debtor,contact,expected_calls);
 RETURN NEXT is((observation->>'succeeded')::BOOLEAN,false,label||': failure has no successful CALL result');
 RETURN NEXT is(observation->>'state',expected_state,label||': original expected SQLSTATE');
 RETURN NEXT ok(expected_constraint IS NULL OR observation->>'constraint'=expected_constraint,
  label||': applicable native constraint identity');
 RETURN NEXT is((observation->>'calls')::BIGINT,expected_calls,label||': controlled allocator completed-call delta');
 RETURN NEXT is((observation->>'accounts')::BIGINT,0::BIGINT,label||': no protected account survives');
 RETURN NEXT is((observation->>'ledger')::BIGINT,0::BIGINT,label||': no protected reservation survives');
END;
$reject$;
CREATE TEMP TABLE contract_rejections(label TEXT PRIMARY KEY, payload JSON,
 state TEXT DEFAULT 'P0001', message TEXT, constraint_name TEXT, bu SMALLINT DEFAULT 31850,
 kind public.t_casefile_type_enum DEFAULT 'REMO In', debtor BIGINT, contact BIGINT,
 expected_calls BIGINT DEFAULT 0);
INSERT INTO contract_rejections(label,payload,state,message) VALUES('root sql-null',NULL::JSON,'P0001','p_insert_respondent_account: invalid account input');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('root json-null','null'::JSON,'P0001','p_insert_respondent_account: invalid account input');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('root array','[]'::JSON,'P0001','p_insert_respondent_account: invalid account input');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('root number','1'::JSON,'P0001','p_insert_respondent_account: invalid account input');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('root boolean','true'::JSON,'P0001','p_insert_respondent_account: invalid account input');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('root encoded-object','"{}"'::JSON,'P0001','p_insert_respondent_account: invalid account input');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('application_code missing',(pg_temp.account_payload()::JSONB #- '{application_code}')::JSON,'P0001','p_insert_respondent_account: invalid application_code');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('application_code null',JSONB_SET(pg_temp.account_payload()::JSONB,'{application_code}','null'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid application_code');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('application_code wrong-type',JSONB_SET(pg_temp.account_payload()::JSONB,'{application_code}','{}'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid application_code');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('application_code string ''''',JSONB_SET(pg_temp.account_payload()::JSONB,'{application_code}','""'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid application_code');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('application_code string ''P10650-X9''',JSONB_SET(pg_temp.account_payload()::JSONB,'{application_code}','"P10650-X9"'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid application_code');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('order_details missing',(pg_temp.account_payload()::JSONB #- '{order_details}')::JSON,'P0001','p_insert_respondent_account: invalid order_details');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('order_details null',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details}','null'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid order_details');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('order_details wrong-type',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details}','1'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid order_details');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('order_details,date_ordered missing',(pg_temp.account_payload()::JSONB #- '{order_details,date_ordered}')::JSON,'P0001','p_insert_respondent_account: invalid date_ordered');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('order_details,date_ordered null',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_ordered}','null'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid date_ordered');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('order_details,date_ordered wrong-type',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_ordered}','{}'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid date_ordered');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('order_details,date_ordered string ''''',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_ordered}','""'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid date_ordered');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('order_details,date_ordered string ''not-a-date''',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_ordered}','"not-a-date"'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid date_ordered');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('order_details,date_arrears_last_updated missing',(pg_temp.account_payload()::JSONB #- '{order_details,date_arrears_last_updated}')::JSON,'P0001','p_insert_respondent_account: invalid date_arrears_last_updated');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('order_details,date_arrears_last_updated null',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_arrears_last_updated}','null'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid date_arrears_last_updated');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('order_details,date_arrears_last_updated wrong-type',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_arrears_last_updated}','{}'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid date_arrears_last_updated');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('order_details,date_arrears_last_updated string ''''',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_arrears_last_updated}','""'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid date_arrears_last_updated');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('order_details,date_arrears_last_updated string ''not-a-date''',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_arrears_last_updated}','"not-a-date"'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid date_arrears_last_updated');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('order_details,payment_period missing',(pg_temp.account_payload()::JSONB #- '{order_details,payment_period}')::JSON,'P0001','p_insert_respondent_account: invalid payment_period');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('order_details,payment_period null',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,payment_period}','null'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid payment_period');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('order_details,payment_period wrong-type',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,payment_period}','{}'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid payment_period');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('order_details,interest_flag missing',(pg_temp.account_payload()::JSONB #- '{order_details,interest_flag}')::JSON,'P0001','p_insert_respondent_account: invalid interest_flag');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('order_details,interest_flag null',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,interest_flag}','null'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid interest_flag');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('order_details,interest_flag wrong-type',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,interest_flag}','{}'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid interest_flag');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('order_details,indexation missing',(pg_temp.account_payload()::JSONB #- '{order_details,indexation}')::JSON,'P0001','p_insert_respondent_account: invalid indexation');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('order_details,indexation null',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,indexation}','null'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid indexation');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('order_details,indexation wrong-type',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,indexation}','{}'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid indexation');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('order_details,payment_arrangement missing',(pg_temp.account_payload()::JSONB #- '{order_details,payment_arrangement}')::JSON,'P0001','p_insert_respondent_account: invalid payment_arrangement');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('order_details,payment_arrangement null',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,payment_arrangement}','null'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid payment_arrangement');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('order_details,payment_arrangement wrong-type',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,payment_arrangement}','{}'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid payment_arrangement');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('authority business_unit_id null',JSONB_SET(pg_temp.account_payload()::JSONB,'{business_unit_id}','null'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid business_unit_id');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('authority business_unit_id "31850"',JSONB_SET(pg_temp.account_payload()::JSONB,'{business_unit_id}','"31850"'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid business_unit_id');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('authority business_unit_id true',JSONB_SET(pg_temp.account_payload()::JSONB,'{business_unit_id}','true'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid business_unit_id');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('authority business_unit_id {}',JSONB_SET(pg_temp.account_payload()::JSONB,'{business_unit_id}','{}'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid business_unit_id');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('authority business_unit_id 31849',JSONB_SET(pg_temp.account_payload()::JSONB,'{business_unit_id}','31849'::JSONB)::JSON,'P0001','p_insert_respondent_account: contradictory business_unit_id');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('authority casefile_type null',JSONB_SET(pg_temp.account_payload()::JSONB,'{casefile_type}','null'::JSONB)::JSON,'P0001','p_insert_respondent_account: contradictory casefile_type');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('authority casefile_type 1',JSONB_SET(pg_temp.account_payload()::JSONB,'{casefile_type}','1'::JSONB)::JSON,'P0001','p_insert_respondent_account: contradictory casefile_type');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('authority casefile_type []',JSONB_SET(pg_temp.account_payload()::JSONB,'{casefile_type}','[]'::JSONB)::JSON,'P0001','p_insert_respondent_account: contradictory casefile_type');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('authority casefile_type "REMO Out"',JSONB_SET(pg_temp.account_payload()::JSONB,'{casefile_type}','"REMO Out"'::JSONB)::JSON,'P0001','p_insert_respondent_account: contradictory casefile_type');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('null BU',pg_temp.account_payload(),'P0001','p_insert_respondent_account: invalid account input');
UPDATE contract_rejections SET bu=NULL WHERE label='null BU';
INSERT INTO contract_rejections(label,payload,state,message) VALUES('null kind',pg_temp.account_payload(),'P0001','p_insert_respondent_account: invalid account input');
UPDATE contract_rejections SET kind=NULL WHERE label='null kind';
INSERT INTO contract_rejections(label,payload,state,message) VALUES('duplicate account business_unit_id literal',('{"business_unit_id":31850,"business_unit_id":31850,' || SUBSTRING(pg_temp.account_payload()::TEXT FROM 2))::JSON,'P0001','p_insert_respondent_account: duplicate account member');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('duplicate account business_unit_id escaped',('{"business_unit_id":31850,"b\u0075siness_unit_id":31850,' || SUBSTRING(pg_temp.account_payload()::TEXT FROM 2))::JSON,'P0001','p_insert_respondent_account: duplicate account member');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('duplicate account casefile_type literal',('{"casefile_type":"REMO In","casefile_type":"REMO In",' || SUBSTRING(pg_temp.account_payload()::TEXT FROM 2))::JSON,'P0001','p_insert_respondent_account: duplicate account member');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('duplicate account casefile_type escaped',('{"casefile_type":"REMO In","c\u0061sefile_type":"REMO In",' || SUBSTRING(pg_temp.account_payload()::TEXT FROM 2))::JSON,'P0001','p_insert_respondent_account: duplicate account member');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('duplicate account application_code literal',('{"application_code":"P10650","application_code":"P10650",' || SUBSTRING(pg_temp.account_payload()::TEXT FROM 2))::JSON,'P0001','p_insert_respondent_account: duplicate account member');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('duplicate account application_code escaped',('{"application_code":"P10650","a\u0070plication_code":"P10650",' || SUBSTRING(pg_temp.account_payload()::TEXT FROM 2))::JSON,'P0001','p_insert_respondent_account: duplicate account member');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('duplicate account order_details literal',('{"order_details":{},"order_details":{},' || SUBSTRING(pg_temp.account_payload()::TEXT FROM 2))::JSON,'P0001','p_insert_respondent_account: duplicate account member');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('duplicate account order_details escaped',('{"order_details":{},"o\u0072der_details":{},' || SUBSTRING(pg_temp.account_payload()::TEXT FROM 2))::JSON,'P0001','p_insert_respondent_account: duplicate account member');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('duplicate account originator_name literal',('{"originator_name":"same","originator_name":"same",' || SUBSTRING(pg_temp.account_payload()::TEXT FROM 2))::JSON,'P0001','p_insert_respondent_account: duplicate account member');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('duplicate account originator_name escaped',('{"originator_name":"same","o\u0072iginator_name":"same",' || SUBSTRING(pg_temp.account_payload()::TEXT FROM 2))::JSON,'P0001','p_insert_respondent_account: duplicate account member');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('duplicate account remo_reference literal',('{"remo_reference":"same","remo_reference":"same",' || SUBSTRING(pg_temp.account_payload()::TEXT FROM 2))::JSON,'P0001','p_insert_respondent_account: duplicate account member');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('duplicate account remo_reference escaped',('{"remo_reference":"same","r\u0065mo_reference":"same",' || SUBSTRING(pg_temp.account_payload()::TEXT FROM 2))::JSON,'P0001','p_insert_respondent_account: duplicate account member');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('duplicate account central_authority_reference literal',('{"central_authority_reference":"same","central_authority_reference":"same",' || SUBSTRING(pg_temp.account_payload()::TEXT FROM 2))::JSON,'P0001','p_insert_respondent_account: duplicate account member');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('duplicate account central_authority_reference escaped',('{"central_authority_reference":"same","c\u0065ntral_authority_reference":"same",' || SUBSTRING(pg_temp.account_payload()::TEXT FROM 2))::JSON,'P0001','p_insert_respondent_account: duplicate account member');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('duplicate account account_comment literal',('{"account_comment":"same","account_comment":"same",' || SUBSTRING(pg_temp.account_payload()::TEXT FROM 2))::JSON,'P0001','p_insert_respondent_account: duplicate account member');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('duplicate account account_comment escaped',('{"account_comment":"same","a\u0063count_comment":"same",' || SUBSTRING(pg_temp.account_payload()::TEXT FROM 2))::JSON,'P0001','p_insert_respondent_account: duplicate account member');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('duplicate details date_orderedFalse',('{"application_code":"P10650","order_details":{"date_ordered":null,"date_ordered":null}}')::JSON,'P0001','p_insert_respondent_account: duplicate order_details member');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('duplicate details date_orderedTrue',('{"application_code":"P10650","order_details":{"date_ordered":null,"d\u0061te_ordered":null}}')::JSON,'P0001','p_insert_respondent_account: duplicate order_details member');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('duplicate details date_arrears_last_updatedFalse',('{"application_code":"P10650","order_details":{"date_arrears_last_updated":null,"date_arrears_last_updated":null}}')::JSON,'P0001','p_insert_respondent_account: duplicate order_details member');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('duplicate details date_arrears_last_updatedTrue',('{"application_code":"P10650","order_details":{"date_arrears_last_updated":null,"d\u0061te_arrears_last_updated":null}}')::JSON,'P0001','p_insert_respondent_account: duplicate order_details member');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('duplicate details payment_periodFalse',('{"application_code":"P10650","order_details":{"payment_period":null,"payment_period":null}}')::JSON,'P0001','p_insert_respondent_account: duplicate order_details member');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('duplicate details payment_periodTrue',('{"application_code":"P10650","order_details":{"payment_period":null,"p\u0061yment_period":null}}')::JSON,'P0001','p_insert_respondent_account: duplicate order_details member');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('duplicate details interest_flagFalse',('{"application_code":"P10650","order_details":{"interest_flag":null,"interest_flag":null}}')::JSON,'P0001','p_insert_respondent_account: duplicate order_details member');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('duplicate details interest_flagTrue',('{"application_code":"P10650","order_details":{"interest_flag":null,"i\u006eterest_flag":null}}')::JSON,'P0001','p_insert_respondent_account: duplicate order_details member');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('duplicate details indexationFalse',('{"application_code":"P10650","order_details":{"indexation":null,"indexation":null}}')::JSON,'P0001','p_insert_respondent_account: duplicate order_details member');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('duplicate details indexationTrue',('{"application_code":"P10650","order_details":{"indexation":null,"i\u006edexation":null}}')::JSON,'P0001','p_insert_respondent_account: duplicate order_details member');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('duplicate details payment_arrangementFalse',('{"application_code":"P10650","order_details":{"payment_arrangement":null,"payment_arrangement":null}}')::JSON,'P0001','p_insert_respondent_account: duplicate order_details member');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('duplicate details payment_arrangementTrue',('{"application_code":"P10650","order_details":{"payment_arrangement":null,"p\u0061yment_arrangement":null}}')::JSON,'P0001','p_insert_respondent_account: duplicate order_details member');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('duplicate details order_termsFalse',('{"application_code":"P10650","order_details":{"order_terms":null,"order_terms":null}}')::JSON,'P0001','p_insert_respondent_account: duplicate order_details member');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('duplicate details order_termsTrue',('{"application_code":"P10650","order_details":{"order_terms":null,"o\u0072der_terms":null}}')::JSON,'P0001','p_insert_respondent_account: duplicate order_details member');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('duplicate term result_idFalse',REPLACE(pg_temp.account_payload()::TEXT,'{"result_id":"MAT","result_responses":[{"parameter_name":"Amount","response":"10.00"}]}','{"result_id":null,"result_id":null}')::JSON,'P0001','p_insert_respondent_account: duplicate Order Term member');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('duplicate term result_idTrue',REPLACE(pg_temp.account_payload()::TEXT,'{"result_id":"MAT","result_responses":[{"parameter_name":"Amount","response":"10.00"}]}','{"result_id":null,"r\u0065sult_id":null}')::JSON,'P0001','p_insert_respondent_account: duplicate Order Term member');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('duplicate term result_responsesFalse',REPLACE(pg_temp.account_payload()::TEXT,'{"result_id":"MAT","result_responses":[{"parameter_name":"Amount","response":"10.00"}]}','{"result_responses":null,"result_responses":null}')::JSON,'P0001','p_insert_respondent_account: duplicate Order Term member');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('duplicate term result_responsesTrue',REPLACE(pg_temp.account_payload()::TEXT,'{"result_id":"MAT","result_responses":[{"parameter_name":"Amount","response":"10.00"}]}','{"result_responses":null,"r\u0065sult_responses":null}')::JSON,'P0001','p_insert_respondent_account: duplicate Order Term member');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('order_details,order_terms missing',(pg_temp.account_payload()::JSONB #- '{order_details,order_terms}')::JSON,'P0001','p_insert_respondent_account: invalid order_terms');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('order_details,order_terms null',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms}','null'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid order_terms');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('order_details,order_terms scalar',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms}','1'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid order_terms');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('order_details,order_terms object',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms}','{}'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid order_terms');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('order_details,order_terms empty',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms}','[]'::JSONB)::JSON,'P0001','p_insert_respondent_account: empty order_terms');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('order_details,order_terms,0,result_responses missing',(pg_temp.account_payload()::JSONB #- '{order_details,order_terms,0,result_responses}')::JSON,'P0001','p_insert_respondent_account: invalid financial collections');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('order_details,order_terms,0,result_responses null',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0,result_responses}','null'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid financial collections');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('order_details,order_terms,0,result_responses scalar',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0,result_responses}','1'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid financial collections');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('order_details,order_terms,0,result_responses object',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0,result_responses}','{}'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid financial collections');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('order_details,order_terms,0,result_responses empty',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0,result_responses}','[]'::JSONB)::JSON,'P0001','p_insert_respondent_account: empty result_responses');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('term null',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0}','null'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid Order Term');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('term "term"',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0}','"term"'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid Order Term');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('term []',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0}','[]'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid Order Term');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('invalid term position 0',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms}',(SELECT JSONB_AGG(CASE WHEN n=0 THEN 'null'::JSONB ELSE pg_temp.account_payload()::JSONB#>'{order_details,order_terms,0}' END ORDER BY n) FROM GENERATE_SERIES(0,2) n))::JSON,'P0001','p_insert_respondent_account: invalid Order Term');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('invalid term position 1',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms}',(SELECT JSONB_AGG(CASE WHEN n=1 THEN 'null'::JSONB ELSE pg_temp.account_payload()::JSONB#>'{order_details,order_terms,0}' END ORDER BY n) FROM GENERATE_SERIES(0,2) n))::JSON,'P0001','p_insert_respondent_account: invalid Order Term');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('invalid term position 2',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms}',(SELECT JSONB_AGG(CASE WHEN n=2 THEN 'null'::JSONB ELSE pg_temp.account_payload()::JSONB#>'{order_details,order_terms,0}' END ORDER BY n) FROM GENERATE_SERIES(0,2) n))::JSON,'P0001','p_insert_respondent_account: invalid Order Term');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('response item null',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0,result_responses,0}','null'::JSONB)::JSON,'P0001','p_insert_respondent_account: unreadable response identity');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('response item 1',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0,result_responses,0}','1'::JSONB)::JSON,'P0001','p_insert_respondent_account: unreadable response identity');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('response item "response"',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0,result_responses,0}','"response"'::JSONB)::JSON,'P0001','p_insert_respondent_account: unreadable response identity');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('response item []',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0,result_responses,0}','[]'::JSONB)::JSON,'P0001','p_insert_respondent_account: unreadable response identity');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('response name missing',(pg_temp.account_payload()::JSONB #- '{order_details,order_terms,0,result_responses,0,parameter_name}')::JSON,'P0001','p_insert_respondent_account: unreadable response identity');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('response name null',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0,result_responses,0,parameter_name}','null'::JSONB)::JSON,'P0001','p_insert_respondent_account: unreadable response identity');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('response name number',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0,result_responses,0,parameter_name}','1'::JSONB)::JSON,'P0001','p_insert_respondent_account: unreadable response identity');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('response name empty',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0,result_responses,0,parameter_name}','""'::JSONB)::JSON,'P0001','p_insert_respondent_account: unreadable response identity');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('Amount missing response',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0,result_responses}','[{"parameter_name":"Amount"}]'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid response shape for Amount');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('Amount null response',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0,result_responses}','[{"parameter_name":"Amount","response":null}]'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid response shape for Amount');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('Amount number response',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0,result_responses}','[{"parameter_name":"Amount","response":10}]'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid response shape for Amount');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('Amount extra member',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0,result_responses}','[{"parameter_name":"Amount","response":"10.00","extra":true}]'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid response shape for Amount');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('Amount duplicate parameter_nameFalse',REPLACE(pg_temp.account_payload()::TEXT,'[{"parameter_name":"Amount","response":"10.00"}]','[{"parameter_name":"Amount","response":"10.00","parameter_name":"Amount"}]')::JSON,'P0001','p_insert_respondent_account: unreadable response identity');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('Amount duplicate parameter_nameTrue',REPLACE(pg_temp.account_payload()::TEXT,'[{"parameter_name":"Amount","response":"10.00"}]','[{"parameter_name":"Amount","response":"10.00","p\u0061rameter_name":"Amount"}]')::JSON,'P0001','p_insert_respondent_account: unreadable response identity');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('Amount duplicate responseFalse',REPLACE(pg_temp.account_payload()::TEXT,'[{"parameter_name":"Amount","response":"10.00"}]','[{"parameter_name":"Amount","response":"10.00","response":"10.00"}]')::JSON,'P0001','p_insert_respondent_account: invalid response shape for Amount');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('Amount duplicate responseTrue',REPLACE(pg_temp.account_payload()::TEXT,'[{"parameter_name":"Amount","response":"10.00"}]','[{"parameter_name":"Amount","response":"10.00","r\u0065sponse":"10.00"}]')::JSON,'P0001','p_insert_respondent_account: invalid response shape for Amount');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('Amount repeated entry',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0,result_responses}','[{"parameter_name":"Amount","response":"10.00"},{"parameter_name":"Amount","response":"10.00"}]'::JSONB)::JSON,'P0001','p_insert_respondent_account: missing or duplicate Amount');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('Arrears missing response',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0,result_responses}','[{"parameter_name":"Amount","response":"10.00"},{"parameter_name":"Arrears"}]'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid response shape for Arrears');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('Arrears null response',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0,result_responses}','[{"parameter_name":"Amount","response":"10.00"},{"parameter_name":"Arrears","response":null}]'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid response shape for Arrears');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('Arrears number response',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0,result_responses}','[{"parameter_name":"Amount","response":"10.00"},{"parameter_name":"Arrears","response":10}]'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid response shape for Arrears');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('Arrears extra member',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0,result_responses}','[{"parameter_name":"Amount","response":"10.00"},{"parameter_name":"Arrears","response":"10.00","extra":true}]'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid response shape for Arrears');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('Arrears duplicate parameter_nameFalse',REPLACE(pg_temp.account_payload()::TEXT,'[{"parameter_name":"Amount","response":"10.00"}]','[{"parameter_name":"Amount","response":"10.00"},{"parameter_name":"Arrears","response":"10.00","parameter_name":"Arrears"}]')::JSON,'P0001','p_insert_respondent_account: unreadable response identity');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('Arrears duplicate parameter_nameTrue',REPLACE(pg_temp.account_payload()::TEXT,'[{"parameter_name":"Amount","response":"10.00"}]','[{"parameter_name":"Amount","response":"10.00"},{"parameter_name":"Arrears","response":"10.00","p\u0061rameter_name":"Arrears"}]')::JSON,'P0001','p_insert_respondent_account: unreadable response identity');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('Arrears duplicate responseFalse',REPLACE(pg_temp.account_payload()::TEXT,'[{"parameter_name":"Amount","response":"10.00"}]','[{"parameter_name":"Amount","response":"10.00"},{"parameter_name":"Arrears","response":"10.00","response":"10.00"}]')::JSON,'P0001','p_insert_respondent_account: invalid response shape for Arrears');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('Arrears duplicate responseTrue',REPLACE(pg_temp.account_payload()::TEXT,'[{"parameter_name":"Amount","response":"10.00"}]','[{"parameter_name":"Amount","response":"10.00"},{"parameter_name":"Arrears","response":"10.00","r\u0065sponse":"10.00"}]')::JSON,'P0001','p_insert_respondent_account: invalid response shape for Arrears');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('Arrears repeated entry',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0,result_responses}','[{"parameter_name":"Amount","response":"10.00"},{"parameter_name":"Arrears","response":"10.00"},{"parameter_name":"Arrears","response":"10.00"}]'::JSONB)::JSON,'P0001','p_insert_respondent_account: missing or duplicate Arrears');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('Result length 0',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0,result_id}','""'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid result_id');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('Result length 7',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0,result_id}','"XXXXXXX"'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid result_id');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('Result strict lookup ''x650''',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0,result_id}','"x650"'::JSONB)::JSON,'P0002','query returned no rows');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('Result strict lookup ''mat''',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0,result_id}','"mat"'::JSONB)::JSON,'P0002','query returned no rows');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('Result strict lookup ''MAT ''',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0,result_id}','"MAT "'::JSONB)::JSON,'P0002','query returned no rows');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('Application length 0',JSONB_SET(pg_temp.account_payload()::JSONB,'{application_code}','""'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid application_code');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('Application length 9',JSONB_SET(pg_temp.account_payload()::JSONB,'{application_code}','"XXXXXXXXX"'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid application_code');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('Application strict lookup ''x10650''',JSONB_SET(pg_temp.account_payload()::JSONB,'{application_code}','"x10650"'::JSONB)::JSON,'P0002','query returned no rows');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('Application strict lookup ''p10650''',JSONB_SET(pg_temp.account_payload()::JSONB,'{application_code}','"p10650"'::JSONB)::JSON,'P0002','query returned no rows');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('Application strict lookup ''P10650 ''',JSONB_SET(pg_temp.account_payload()::JSONB,'{application_code}','"P10650 "'::JSONB)::JSON,'P0002','query returned no rows');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('enum payment_period ''''',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,payment_period}','""'::JSONB)::JSON,'22P02',NULL);
INSERT INTO contract_rejections(label,payload,state,message) VALUES('enum payment_period ''P10650_MARKER''',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,payment_period}','"P10650_MARKER"'::JSONB)::JSON,'22P02',NULL);
INSERT INTO contract_rejections(label,payload,state,message) VALUES('enum indexation ''''',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,indexation}','""'::JSONB)::JSON,'22P02',NULL);
INSERT INTO contract_rejections(label,payload,state,message) VALUES('enum indexation ''P10650_MARKER''',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,indexation}','"P10650_MARKER"'::JSONB)::JSON,'22P02',NULL);
INSERT INTO contract_rejections(label,payload,state,message) VALUES('enum payment_arrangement ''''',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,payment_arrangement}','""'::JSONB)::JSON,'22P02',NULL);
INSERT INTO contract_rejections(label,payload,state,message) VALUES('enum payment_arrangement ''P10650_MARKER''',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,payment_arrangement}','"P10650_MARKER"'::JSONB)::JSON,'22P02',NULL);
INSERT INTO contract_rejections(label,payload,state,message) VALUES('optional originator_name null',JSONB_SET(pg_temp.account_payload()::JSONB,'{originator_name}','null'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid originator_name');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('optional originator_name 1',JSONB_SET(pg_temp.account_payload()::JSONB,'{originator_name}','1'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid originator_name');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('optional originator_name false',JSONB_SET(pg_temp.account_payload()::JSONB,'{originator_name}','false'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid originator_name');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('optional originator_name {}',JSONB_SET(pg_temp.account_payload()::JSONB,'{originator_name}','{}'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid originator_name');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('optional originator_name []',JSONB_SET(pg_temp.account_payload()::JSONB,'{originator_name}','[]'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid originator_name');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('optional remo_reference null',JSONB_SET(pg_temp.account_payload()::JSONB,'{remo_reference}','null'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid remo_reference');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('optional remo_reference 1',JSONB_SET(pg_temp.account_payload()::JSONB,'{remo_reference}','1'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid remo_reference');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('optional remo_reference false',JSONB_SET(pg_temp.account_payload()::JSONB,'{remo_reference}','false'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid remo_reference');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('optional remo_reference {}',JSONB_SET(pg_temp.account_payload()::JSONB,'{remo_reference}','{}'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid remo_reference');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('optional remo_reference []',JSONB_SET(pg_temp.account_payload()::JSONB,'{remo_reference}','[]'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid remo_reference');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('optional central_authority_reference null',JSONB_SET(pg_temp.account_payload()::JSONB,'{central_authority_reference}','null'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid central_authority_reference');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('optional central_authority_reference 1',JSONB_SET(pg_temp.account_payload()::JSONB,'{central_authority_reference}','1'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid central_authority_reference');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('optional central_authority_reference false',JSONB_SET(pg_temp.account_payload()::JSONB,'{central_authority_reference}','false'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid central_authority_reference');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('optional central_authority_reference {}',JSONB_SET(pg_temp.account_payload()::JSONB,'{central_authority_reference}','{}'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid central_authority_reference');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('optional central_authority_reference []',JSONB_SET(pg_temp.account_payload()::JSONB,'{central_authority_reference}','[]'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid central_authority_reference');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('optional account_comment null',JSONB_SET(pg_temp.account_payload()::JSONB,'{account_comment}','null'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid account_comment');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('optional account_comment 1',JSONB_SET(pg_temp.account_payload()::JSONB,'{account_comment}','1'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid account_comment');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('optional account_comment false',JSONB_SET(pg_temp.account_payload()::JSONB,'{account_comment}','false'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid account_comment');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('optional account_comment {}',JSONB_SET(pg_temp.account_payload()::JSONB,'{account_comment}','{}'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid account_comment');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('optional account_comment []',JSONB_SET(pg_temp.account_payload()::JSONB,'{account_comment}','[]'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid account_comment');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('width originator_name multibyte 201',JSONB_SET(pg_temp.account_payload()::JSONB,'{originator_name}',TO_JSONB(REPEAT('Ω',201)))::JSON,'22001','p_insert_respondent_account: storage width exceeded for account text');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('width remo_reference multibyte 21',JSONB_SET(pg_temp.account_payload()::JSONB,'{remo_reference}',TO_JSONB(REPEAT('Ω',21)))::JSON,'22001','p_insert_respondent_account: storage width exceeded for account text');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('width central_authority_reference multibyte 51',JSONB_SET(pg_temp.account_payload()::JSONB,'{central_authority_reference}',TO_JSONB(REPEAT('Ω',51)))::JSON,'22001','p_insert_respondent_account: storage width exceeded for account text');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('date date_ordered 2027-02-29',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_ordered}','"2027-02-29"'::JSONB)::JSON,'22008',NULL);
INSERT INTO contract_rejections(label,payload,state,message) VALUES('date date_ordered 2024-13-01',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_ordered}','"2024-13-01"'::JSONB)::JSON,'22008',NULL);
INSERT INTO contract_rejections(label,payload,state,message) VALUES('date date_ordered 2024-04-31',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_ordered}','"2024-04-31"'::JSONB)::JSON,'22008',NULL);
INSERT INTO contract_rejections(label,payload,state,message) VALUES('date date_ordered shape ''2024-1-01''',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_ordered}','"2024-1-01"'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid date_ordered');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('date date_ordered shape ''2024-01-01T00:00:00Z''',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_ordered}','"2024-01-01T00:00:00Z"'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid date_ordered');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('date date_ordered shape ''today''',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_ordered}','"today"'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid date_ordered');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('date date_ordered shape ''infinity''',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_ordered}','"infinity"'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid date_ordered');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('date date_ordered shape ''2024-01-01 ''',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_ordered}','"2024-01-01 "'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid date_ordered');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('date date_ordered shape '' 2024-01-01''',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_ordered}','" 2024-01-01"'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid date_ordered');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('date date_arrears_last_updated 2027-02-29',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_arrears_last_updated}','"2027-02-29"'::JSONB)::JSON,'22008',NULL);
INSERT INTO contract_rejections(label,payload,state,message) VALUES('date date_arrears_last_updated 2024-13-01',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_arrears_last_updated}','"2024-13-01"'::JSONB)::JSON,'22008',NULL);
INSERT INTO contract_rejections(label,payload,state,message) VALUES('date date_arrears_last_updated 2024-04-31',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_arrears_last_updated}','"2024-04-31"'::JSONB)::JSON,'22008',NULL);
INSERT INTO contract_rejections(label,payload,state,message) VALUES('date date_arrears_last_updated shape ''2024-1-01''',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_arrears_last_updated}','"2024-1-01"'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid date_arrears_last_updated');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('date date_arrears_last_updated shape ''2024-01-01T00:00:00Z''',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_arrears_last_updated}','"2024-01-01T00:00:00Z"'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid date_arrears_last_updated');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('date date_arrears_last_updated shape ''today''',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_arrears_last_updated}','"today"'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid date_arrears_last_updated');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('date date_arrears_last_updated shape ''infinity''',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_arrears_last_updated}','"infinity"'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid date_arrears_last_updated');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('date date_arrears_last_updated shape ''2024-01-01 ''',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_arrears_last_updated}','"2024-01-01 "'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid date_arrears_last_updated');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('date date_arrears_last_updated shape '' 2024-01-01''',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_arrears_last_updated}','" 2024-01-01"'::JSONB)::JSON,'P0001','p_insert_respondent_account: invalid date_arrears_last_updated');
INSERT INTO contract_rejections(label,payload,state,message) VALUES('missing debtor FK',pg_temp.account_payload(),'23503',NULL);
UPDATE contract_rejections SET debtor=918651,expected_calls=1,constraint_name='ra_debtor_detail_id_fk' WHERE label='missing debtor FK';
INSERT INTO contract_rejections(label,payload,state,message) VALUES('missing contact FK',pg_temp.account_payload(),'23503',NULL);
UPDATE contract_rejections SET contact=918651,expected_calls=1,constraint_name='ra_third_party_contact_id_fk' WHERE label='missing contact FK';

INSERT INTO contract_rejections(label,payload,message) VALUES('result_id missing',(pg_temp.account_payload()::JSONB #- '{order_details,order_terms,0,result_id}')::JSON,'p_insert_respondent_account: invalid result_id');
INSERT INTO contract_rejections(label,payload,message) VALUES('result_id null',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0,result_id}','null')::JSON,'p_insert_respondent_account: invalid result_id');
INSERT INTO contract_rejections(label,payload,message) VALUES('result_id wrong-type',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0,result_id}','{}')::JSON,'p_insert_respondent_account: invalid result_id');
INSERT INTO contract_rejections(label,payload,message) VALUES('missing Amount response',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0,result_responses}','[{"parameter_name":"Unknown","response":null}]')::JSON,'p_insert_respondent_account: missing or duplicate Amount');

INSERT INTO contract_rejections(label,payload,message) VALUES('Amount malformed required string ''''',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0,result_responses}','[{"parameter_name": "Amount", "response": ""}]'::JSONB)::JSON,'p_insert_respondent_account: invalid money for Amount');
INSERT INTO contract_rejections(label,payload,message) VALUES('Amount malformed required string ''P10650_MARKER''',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0,result_responses}','[{"parameter_name": "Amount", "response": "P10650_MARKER"}]'::JSONB)::JSON,'p_insert_respondent_account: invalid money for Amount');
INSERT INTO contract_rejections(label,payload,message) VALUES('Amount malformed required string '' 10.00''',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0,result_responses}','[{"parameter_name": "Amount", "response": " 10.00"}]'::JSONB)::JSON,'p_insert_respondent_account: invalid money for Amount');
INSERT INTO contract_rejections(label,payload,message) VALUES('Arrears malformed required string ''''',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0,result_responses}','[{"parameter_name": "Amount", "response": "10.00"}, {"parameter_name": "Arrears", "response": ""}]'::JSONB)::JSON,'p_insert_respondent_account: invalid money for Arrears');
INSERT INTO contract_rejections(label,payload,message) VALUES('Arrears malformed required string ''P10650_MARKER''',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0,result_responses}','[{"parameter_name": "Amount", "response": "10.00"}, {"parameter_name": "Arrears", "response": "P10650_MARKER"}]'::JSONB)::JSON,'p_insert_respondent_account: invalid money for Arrears');
INSERT INTO contract_rejections(label,payload,message) VALUES('Arrears malformed required string '' 10.00''',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0,result_responses}','[{"parameter_name": "Amount", "response": "10.00"}, {"parameter_name": "Arrears", "response": " 10.00"}]'::JSONB)::JSON,'p_insert_respondent_account: invalid money for Arrears');
INSERT INTO contract_rejections(label,payload,message) VALUES('interest string false',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,interest_flag}','"false"')::JSON,'p_insert_respondent_account: invalid interest_flag');

SELECT rejected.* FROM contract_rejections c
CROSS JOIN LATERAL pg_temp.reject_account(
 CASE WHEN SET_CONFIG('opal.po10650_case',c.label,true) IS NOT NULL THEN c.payload END,
 c.state,c.constraint_name,c.bu,c.kind,c.debtor,c.contact,c.expected_calls) rejected;
SELECT ok(CASE WHEN c.message IS NOT NULL THEN o.message=c.message AND o.detail='' AND o.hint=''
 AND o.message NOT LIKE '%P10650_MARKER%'
 WHEN c.state='22P02' THEN o.message LIKE 'invalid input value for enum %' AND o.message LIKE '%P10650_MARKER%'
   OR o.message LIKE 'invalid input value for enum %: ""'
 WHEN c.state='22008' THEN o.message LIKE 'date/time field value out of range:%'
 WHEN c.state='23503' THEN o.message LIKE '%violates foreign key constraint%'
   AND o.detail LIKE '%is not present in table%'
 ELSE false END AND o.context LIKE '%p_insert_respondent_account%',c.label||': exact guard or original native diagnostics')
FROM contract_rejections c JOIN rejection_observations o USING(label);
SELECT is(o.sequence_after,o.sequence_before,c.label||': preallocation sequence snapshot unchanged')
FROM contract_rejections c JOIN rejection_observations o USING(label) WHERE c.expected_calls=0;


-- ---------------------------------------------------------------------------
-- Scenario: Accepted values preserve exact source characters and native mappings.
-- Setup:    All enum labels, boundary strings, nullable children and date-only input.
-- Expected: Both outputs identify one account/reservation with exact mapped fields.
-- ---------------------------------------------------------------------------
CREATE TEMP TABLE contract_successes(label TEXT PRIMARY KEY, payload JSON, expected JSONB,
 bu SMALLINT DEFAULT 31850, kind public.t_casefile_type_enum DEFAULT 'REMO In',
 debtor BIGINT, contact BIGINT, zone TEXT DEFAULT 'UTC');
INSERT INTO contract_successes(label,payload,expected) VALUES('actual object and omitted optional members',pg_temp.account_payload(),'{"originator_name": null, "remo_reference": null, "ca_reference": null, "account_comment": null, "debtor_detail_id": null, "third_party_contact_id": null}'::JSONB);
INSERT INTO contract_successes(label,payload,expected) VALUES('omitted authority REMO In',pg_temp.account_payload(),'{"casefile_type": "REMO In"}'::JSONB);
UPDATE contract_successes SET kind='REMO In' WHERE label='omitted authority REMO In';
INSERT INTO contract_successes(label,payload,expected) VALUES('matching authority REMO In',(pg_temp.account_payload()::JSONB||JSONB_BUILD_OBJECT('business_unit_id',31850,'casefile_type','REMO In'))::JSON,'{"business_unit_id": 31850, "casefile_type": "REMO In"}'::JSONB);
UPDATE contract_successes SET kind='REMO In' WHERE label='matching authority REMO In';
INSERT INTO contract_successes(label,payload,expected) VALUES('omitted authority REMO Out',pg_temp.account_payload(),'{"casefile_type": "REMO Out"}'::JSONB);
UPDATE contract_successes SET kind='REMO Out' WHERE label='omitted authority REMO Out';
INSERT INTO contract_successes(label,payload,expected) VALUES('matching authority REMO Out',(pg_temp.account_payload()::JSONB||JSONB_BUILD_OBJECT('business_unit_id',31850,'casefile_type','REMO Out'))::JSON,'{"business_unit_id": 31850, "casefile_type": "REMO Out"}'::JSONB);
UPDATE contract_successes SET kind='REMO Out' WHERE label='matching authority REMO Out';
INSERT INTO contract_successes(label,payload,expected) VALUES('omitted authority REMO Out (CMS)',pg_temp.account_payload(),'{"casefile_type": "REMO Out (CMS)"}'::JSONB);
UPDATE contract_successes SET kind='REMO Out (CMS)' WHERE label='omitted authority REMO Out (CMS)';
INSERT INTO contract_successes(label,payload,expected) VALUES('matching authority REMO Out (CMS)',(pg_temp.account_payload()::JSONB||JSONB_BUILD_OBJECT('business_unit_id',31850,'casefile_type','REMO Out (CMS)'))::JSON,'{"business_unit_id": 31850, "casefile_type": "REMO Out (CMS)"}'::JSONB);
UPDATE contract_successes SET kind='REMO Out (CMS)' WHERE label='matching authority REMO Out (CMS)';
INSERT INTO contract_successes(label,payload,expected) VALUES('negative existing BU authority',pg_temp.account_payload(),'{"business_unit_id": -31850}'::JSONB);
UPDATE contract_successes SET bu=-31850 WHERE label='negative existing BU authority';
INSERT INTO contract_successes(label,payload,expected) VALUES('payment_period Weekly',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,payment_period}','"Weekly"'::JSONB)::JSON,'{"payment_period": "Weekly"}'::JSONB);
INSERT INTO contract_successes(label,payload,expected) VALUES('payment_period Fortnightly',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,payment_period}','"Fortnightly"'::JSONB)::JSON,'{"payment_period": "Fortnightly"}'::JSONB);
INSERT INTO contract_successes(label,payload,expected) VALUES('payment_period Monthly',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,payment_period}','"Monthly"'::JSONB)::JSON,'{"payment_period": "Monthly"}'::JSONB);
INSERT INTO contract_successes(label,payload,expected) VALUES('payment_period Quarterly',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,payment_period}','"Quarterly"'::JSONB)::JSON,'{"payment_period": "Quarterly"}'::JSONB);
INSERT INTO contract_successes(label,payload,expected) VALUES('payment_period Yearly',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,payment_period}','"Yearly"'::JSONB)::JSON,'{"payment_period": "Yearly"}'::JSONB);
INSERT INTO contract_successes(label,payload,expected) VALUES('indexation RPI',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,indexation}','"RPI"'::JSONB)::JSON,'{"indexation": "RPI"}'::JSONB);
INSERT INTO contract_successes(label,payload,expected) VALUES('indexation CPI',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,indexation}','"CPI"'::JSONB)::JSON,'{"indexation": "CPI"}'::JSONB);
INSERT INTO contract_successes(label,payload,expected) VALUES('indexation Other',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,indexation}','"Other"'::JSONB)::JSON,'{"indexation": "Other"}'::JSONB);
INSERT INTO contract_successes(label,payload,expected) VALUES('indexation None',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,indexation}','"None"'::JSONB)::JSON,'{"indexation": "None"}'::JSONB);
INSERT INTO contract_successes(label,payload,expected) VALUES('payment_arrangement Court',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,payment_arrangement}','"Court"'::JSONB)::JSON,'{"payment_arrangement": "Court"}'::JSONB);
INSERT INTO contract_successes(label,payload,expected) VALUES('payment_arrangement Direct',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,payment_arrangement}','"Direct"'::JSONB)::JSON,'{"payment_arrangement": "Direct"}'::JSONB);
INSERT INTO contract_successes(label,payload,expected) VALUES('interest_flag True',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,interest_flag}','true'::JSONB)::JSON,'{"interest_flag": true}'::JSONB);
INSERT INTO contract_successes(label,payload,expected) VALUES('interest_flag False',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,interest_flag}','false'::JSONB)::JSON,'{"interest_flag": false}'::JSONB);
INSERT INTO contract_successes(label,payload,expected) VALUES('originator_name exact ''''',JSONB_SET(pg_temp.account_payload()::JSONB,'{originator_name}','""'::JSONB)::JSON,'{"originator_name": ""}'::JSONB);
INSERT INTO contract_successes(label,payload,expected) VALUES('originator_name exact '' ''',JSONB_SET(pg_temp.account_payload()::JSONB,'{originator_name}','" "'::JSONB)::JSON,'{"originator_name": " "}'::JSONB);
INSERT INTO contract_successes(label,payload,expected) VALUES('originator_name exact '' éΩ ''',JSONB_SET(pg_temp.account_payload()::JSONB,'{originator_name}','" éΩ "'::JSONB)::JSON,'{"originator_name": " éΩ "}'::JSONB);
INSERT INTO contract_successes(label,payload,expected) VALUES('remo_reference exact ''''',JSONB_SET(pg_temp.account_payload()::JSONB,'{remo_reference}','""'::JSONB)::JSON,'{"remo_reference": ""}'::JSONB);
INSERT INTO contract_successes(label,payload,expected) VALUES('remo_reference exact '' ''',JSONB_SET(pg_temp.account_payload()::JSONB,'{remo_reference}','" "'::JSONB)::JSON,'{"remo_reference": " "}'::JSONB);
INSERT INTO contract_successes(label,payload,expected) VALUES('remo_reference exact '' éΩ ''',JSONB_SET(pg_temp.account_payload()::JSONB,'{remo_reference}','" éΩ "'::JSONB)::JSON,'{"remo_reference": " éΩ "}'::JSONB);
INSERT INTO contract_successes(label,payload,expected) VALUES('central_authority_reference exact ''''',JSONB_SET(pg_temp.account_payload()::JSONB,'{central_authority_reference}','""'::JSONB)::JSON,'{"ca_reference": ""}'::JSONB);
INSERT INTO contract_successes(label,payload,expected) VALUES('central_authority_reference exact '' ''',JSONB_SET(pg_temp.account_payload()::JSONB,'{central_authority_reference}','" "'::JSONB)::JSON,'{"ca_reference": " "}'::JSONB);
INSERT INTO contract_successes(label,payload,expected) VALUES('central_authority_reference exact '' éΩ ''',JSONB_SET(pg_temp.account_payload()::JSONB,'{central_authority_reference}','" éΩ "'::JSONB)::JSON,'{"ca_reference": " éΩ "}'::JSONB);
INSERT INTO contract_successes(label,payload,expected) VALUES('account_comment exact ''''',JSONB_SET(pg_temp.account_payload()::JSONB,'{account_comment}','""'::JSONB)::JSON,'{"account_comment": ""}'::JSONB);
INSERT INTO contract_successes(label,payload,expected) VALUES('account_comment exact '' ''',JSONB_SET(pg_temp.account_payload()::JSONB,'{account_comment}','" "'::JSONB)::JSON,'{"account_comment": " "}'::JSONB);
INSERT INTO contract_successes(label,payload,expected) VALUES('account_comment exact '' éΩ ''',JSONB_SET(pg_temp.account_payload()::JSONB,'{account_comment}','" éΩ "'::JSONB)::JSON,'{"account_comment": " éΩ "}'::JSONB);
INSERT INTO contract_successes(label,payload,expected) VALUES('originator_name exact multibyte width 200',JSONB_SET(pg_temp.account_payload()::JSONB,'{originator_name}','"ΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩ"'::JSONB)::JSON,'{"originator_name": "ΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩ"}'::JSONB);
INSERT INTO contract_successes(label,payload,expected) VALUES('remo_reference exact multibyte width 20',JSONB_SET(pg_temp.account_payload()::JSONB,'{remo_reference}','"ΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩ"'::JSONB)::JSON,'{"remo_reference": "ΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩ"}'::JSONB);
INSERT INTO contract_successes(label,payload,expected) VALUES('central_authority_reference exact multibyte width 50',JSONB_SET(pg_temp.account_payload()::JSONB,'{central_authority_reference}','"ΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩ"'::JSONB)::JSON,'{"ca_reference": "ΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩ"}'::JSONB);
INSERT INTO contract_successes(label,payload,expected) VALUES('originator exceeds API40',JSONB_SET(pg_temp.account_payload()::JSONB,'{originator_name}','"ééééééééééééééééééééééééééééééééééééééééé"'::JSONB)::JSON,'{"originator_name": "ééééééééééééééééééééééééééééééééééééééééé"}'::JSONB);
INSERT INTO contract_successes(label,payload,expected) VALUES('comment exceeds API250',JSONB_SET(pg_temp.account_payload()::JSONB,'{account_comment}','"ΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩ"'::JSONB)::JSON,'{"account_comment": "ΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩ"}'::JSONB);
INSERT INTO contract_successes(label,payload,expected) VALUES('children both NULL',pg_temp.account_payload(),'{"debtor_detail_id": null, "third_party_contact_id": null}'::JSONB);
UPDATE contract_successes SET debtor=NULL,contact=NULL WHERE label='children both NULL';
INSERT INTO contract_successes(label,payload,expected) VALUES('children debtor only',pg_temp.account_payload(),'{"debtor_detail_id": 918650, "third_party_contact_id": null}'::JSONB);
UPDATE contract_successes SET debtor=918650,contact=NULL WHERE label='children debtor only';
INSERT INTO contract_successes(label,payload,expected) VALUES('children contact only',pg_temp.account_payload(),'{"debtor_detail_id": null, "third_party_contact_id": 918650}'::JSONB);
UPDATE contract_successes SET debtor=NULL,contact=918650 WHERE label='children contact only';
INSERT INTO contract_successes(label,payload,expected) VALUES('children both supplied',pg_temp.account_payload(),'{"debtor_detail_id": 918650, "third_party_contact_id": 918650}'::JSONB);
UPDATE contract_successes SET debtor=918650,contact=918650 WHERE label='children both supplied';
INSERT INTO contract_successes(label,payload,expected) VALUES('date midnight 2024-01-01 UTC',JSONB_SET(JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_ordered}','"2024-01-01"'::JSONB),'{order_details,date_arrears_last_updated}','"2024-01-01"'::JSONB)::JSON,'{"imposed_hearing_date": "2024-01-01T00:00:00", "date_arrears_last_updated": "2024-01-01T00:00:00"}'::JSONB);
UPDATE contract_successes SET zone='UTC' WHERE label='date midnight 2024-01-01 UTC';
INSERT INTO contract_successes(label,payload,expected) VALUES('date midnight 2024-02-29 UTC',JSONB_SET(JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_ordered}','"2024-02-29"'::JSONB),'{order_details,date_arrears_last_updated}','"2024-02-29"'::JSONB)::JSON,'{"imposed_hearing_date": "2024-02-29T00:00:00", "date_arrears_last_updated": "2024-02-29T00:00:00"}'::JSONB);
UPDATE contract_successes SET zone='UTC' WHERE label='date midnight 2024-02-29 UTC';
INSERT INTO contract_successes(label,payload,expected) VALUES('date midnight 2024-01-01 Pacific/Honolulu',JSONB_SET(JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_ordered}','"2024-01-01"'::JSONB),'{order_details,date_arrears_last_updated}','"2024-01-01"'::JSONB)::JSON,'{"imposed_hearing_date": "2024-01-01T00:00:00", "date_arrears_last_updated": "2024-01-01T00:00:00"}'::JSONB);
UPDATE contract_successes SET zone='Pacific/Honolulu' WHERE label='date midnight 2024-01-01 Pacific/Honolulu';
INSERT INTO contract_successes(label,payload,expected) VALUES('date midnight 2024-02-29 Pacific/Honolulu',JSONB_SET(JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_ordered}','"2024-02-29"'::JSONB),'{order_details,date_arrears_last_updated}','"2024-02-29"'::JSONB)::JSON,'{"imposed_hearing_date": "2024-02-29T00:00:00", "date_arrears_last_updated": "2024-02-29T00:00:00"}'::JSONB);
UPDATE contract_successes SET zone='Pacific/Honolulu' WHERE label='date midnight 2024-02-29 Pacific/Honolulu';
INSERT INTO contract_successes(label,payload,expected) VALUES('ordered date beyond publication allowed',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_ordered}','"2099-12-31"'::JSONB)::JSON,'{"imposed_hearing_date": "2099-12-31T00:00:00"}'::JSONB);
INSERT INTO contract_successes(label,payload,expected) VALUES('ordered date after arrears date allowed',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_ordered}','"2025-06-30"'::JSONB)::JSON,'{"imposed_hearing_date": "2025-06-30T00:00:00"}'::JSONB);
INSERT INTO contract_successes(label,payload,expected) VALUES('unknown readable response opaque',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0,result_responses}',(pg_temp.account_payload()::JSONB#>'{order_details,order_terms,0,result_responses}')||'[{"parameter_name":"Opaque","response":{"malformed":true},"extra":null}]')::JSON,'{"orders_amount": 10, "total_arrears": 0}'::JSONB);
INSERT INTO contract_successes(label,payload,expected) VALUES('duplicate unconsumed keys remain backend-owned',('{"opaque":1,"opaque":2,'||SUBSTRING(pg_temp.account_payload()::TEXT FROM 2))::JSON,'{"orders_amount": 10}'::JSONB);

CREATE TEMP TABLE success_observations(label TEXT, output JSONB, calls BIGINT, account_row JSONB);
DO $successes$
DECLARE c RECORD; output JSONB; before_calls BIGINT;
BEGIN
 FOR c IN SELECT * FROM contract_successes ORDER BY label LOOP
  PERFORM SET_CONFIG('TimeZone',c.zone,true);
  before_calls := pg_temp.allocator_calls();
  output := pg_temp.invoke_account(c.payload,c.bu,c.kind,c.debtor,c.contact);
  INSERT INTO success_observations SELECT c.label,output,pg_temp.allocator_calls()-before_calls,TO_JSONB(a)
  FROM public.respondent_accounts a WHERE a.respondent_account_id=(output->>'id')::BIGINT;
 END LOOP;
 PERFORM SET_CONFIG('TimeZone','UTC',true);
END;
$successes$;
SELECT ok(o.calls=1 AND o.account_row @> c.expected
 AND o.account_row->>'account_number'=o.output->>'number'
 AND EXISTS(SELECT 1 FROM public.account_number_index i WHERE i.business_unit_id=c.bu
  AND i.account_number=o.output->>'number' AND i.associated_record_type='respondent_accounts'),
 c.label||': same-row outputs, one allocation and exact persisted fields')
FROM contract_successes c JOIN success_observations o USING(label);
SELECT is((SELECT COUNT(*) FROM success_observations),(SELECT COUNT(*) FROM contract_successes),
 'every accepted contract case produced a persisted account');


-- ---------------------------------------------------------------------------
-- Scenario: Live Application/Result eligibility and consumed profiles are reread.
-- Setup:    Each synthetic reference mutation occurs in its own rollback block.
-- Expected: Capture actual CALL diagnostics/outputs; emit all TAP after rollback.
-- ---------------------------------------------------------------------------
DO $result_collision$
BEGIN
 IF EXISTS(SELECT 1 FROM public.results WHERE result_id='T10650') THEN
  RAISE EXCEPTION 'PO-10650 synthetic T10650 Result collision';
 END IF;
END;
$result_collision$;
CREATE TEMP TABLE reference_cases(label TEXT PRIMARY KEY, payload JSON DEFAULT pg_temp.account_payload(),
 metadata JSON,replace_metadata BOOLEAN DEFAULT false,result_active BOOLEAN,order_term BOOLEAN,
 app_active BOOLEAN,app_start DATE,set_end BOOLEAN DEFAULT false,app_end DATE,
 clone_result BOOLEAN DEFAULT false,call_contact BIGINT,mutate_contact_country BOOLEAN DEFAULT false,
 expected_extra JSONB DEFAULT '{}'::JSONB,expected_state TEXT,expected_message TEXT);
INSERT INTO reference_cases(label,expected_state,expected_message,result_active) VALUES('Result inactive','P0001','p_insert_respondent_account: ineligible Result',false);
INSERT INTO reference_cases(label,expected_state,expected_message,order_term) VALUES('Result not an Order Term','P0001','p_insert_respondent_account: ineligible Result',false);
INSERT INTO reference_cases(label,expected_state,expected_message,app_active) VALUES('Application deactivated after prior successful selection','P0001','p_insert_respondent_account: ineligible Application',false);
INSERT INTO reference_cases(label,expected_state,expected_message,app_start) VALUES('Application starts tomorrow','P0001','p_insert_respondent_account: ineligible Application',(pg_catalog.TRANSACTION_TIMESTAMP() AT TIME ZONE 'Europe/London')::DATE+1);
INSERT INTO reference_cases(label,expected_state,app_start) VALUES('Application starts on publication',NULL,(pg_catalog.TRANSACTION_TIMESTAMP() AT TIME ZONE 'Europe/London')::DATE);
INSERT INTO reference_cases(label,expected_state,set_end,app_end) VALUES('Application finite end on publication',NULL,true,(pg_catalog.TRANSACTION_TIMESTAMP() AT TIME ZONE 'Europe/London')::DATE);
INSERT INTO reference_cases(label,expected_state,expected_message,set_end,app_end) VALUES('Application after finite end','P0001','p_insert_respondent_account: ineligible Application',true,(pg_catalog.TRANSACTION_TIMESTAMP() AT TIME ZONE 'Europe/London')::DATE-1);
INSERT INTO reference_cases(label,expected_state,set_end,app_end) VALUES('Application NULL end',NULL,true,NULL);
INSERT INTO reference_cases(label,expected_state,expected_message,app_start,set_end,app_end) VALUES('Application end before start','P0001','p_insert_respondent_account: ineligible Application',(pg_catalog.TRANSACTION_TIMESTAMP() AT TIME ZONE 'Europe/London')::DATE+1,true,(pg_catalog.TRANSACTION_TIMESTAMP() AT TIME ZONE 'Europe/London')::DATE-1);
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('profile SQL NULL',NULL::JSON,true,'P0001','p_insert_respondent_account: invalid financial collections');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('profile JSON null','null'::JSON,true,'P0001','p_insert_respondent_account: invalid financial collections');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('profile scalar','1'::JSON,true,'P0001','p_insert_respondent_account: invalid financial collections');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('profile object','{}'::JSON,true,'P0001','p_insert_respondent_account: invalid financial collections');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('profile empty array','[]'::JSON,true,'P0001','p_insert_respondent_account: ambiguous or missing Amount');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('metadata identity null definition',((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT')||JSONB_BUILD_ARRAY('null'::JSONB))::JSON,true,'P0001','p_insert_respondent_account: unreadable metadata identity');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('metadata identity scalar definition',((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT')||JSONB_BUILD_ARRAY('1'::JSONB))::JSON,true,'P0001','p_insert_respondent_account: unreadable metadata identity');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('metadata identity array definition',((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT')||JSONB_BUILD_ARRAY('[]'::JSONB))::JSON,true,'P0001','p_insert_respondent_account: unreadable metadata identity');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('metadata identity missing name',((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT')||JSONB_BUILD_ARRAY('{}'::JSONB))::JSON,true,'P0001','p_insert_respondent_account: unreadable metadata identity');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('metadata identity null name',((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT')||JSONB_BUILD_ARRAY('{"name":null}'::JSONB))::JSON,true,'P0001','p_insert_respondent_account: unreadable metadata identity');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('metadata identity nonstring name',((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT')||JSONB_BUILD_ARRAY('{"name":1}'::JSONB))::JSON,true,'P0001','p_insert_respondent_account: unreadable metadata identity');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('metadata identity empty name',((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT')||JSONB_BUILD_ARRAY('{"name":""}'::JSONB))::JSON,true,'P0001','p_insert_respondent_account: unreadable metadata identity');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('metadata duplicate name False','[{"name":"Amount","name":"Amount"}]'::JSON,true,'P0001','p_insert_respondent_account: unreadable metadata identity');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('metadata duplicate name True','[{"name":"Amount","n\u0061me":"Amount"}]'::JSON,true,'P0001','p_insert_respondent_account: unreadable metadata identity');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Amount repeated definition',((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT')||JSONB_BUILD_ARRAY((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT')->0))::JSON,true,'P0001','p_insert_respondent_account: ambiguous or missing Amount');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Amount escaped consumed metadata duplicate typeFalse','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":0,"max":9999999999.99,"precision":2,"type":"decimal-2dp"}]'::JSON,true,'P0001','p_insert_respondent_account: duplicate metadata for Amount');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Amount escaped consumed metadata duplicate typeTrue','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":0,"max":9999999999.99,"precision":2,"t\u0079pe":"decimal-2dp"}]'::JSON,true,'P0001','p_insert_respondent_account: duplicate metadata for Amount');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Amount escaped consumed metadata duplicate mandatoryFalse','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":0,"max":9999999999.99,"precision":2,"mandatory":true}]'::JSON,true,'P0001','p_insert_respondent_account: duplicate metadata for Amount');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Amount escaped consumed metadata duplicate mandatoryTrue','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":0,"max":9999999999.99,"precision":2,"m\u0061ndatory":true}]'::JSON,true,'P0001','p_insert_respondent_account: duplicate metadata for Amount');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Amount escaped consumed metadata duplicate minFalse','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":0,"max":9999999999.99,"precision":2,"min":0}]'::JSON,true,'P0001','p_insert_respondent_account: duplicate metadata for Amount');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Amount escaped consumed metadata duplicate minTrue','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":0,"max":9999999999.99,"precision":2,"m\u0069n":0}]'::JSON,true,'P0001','p_insert_respondent_account: duplicate metadata for Amount');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Amount escaped consumed metadata duplicate maxFalse','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":0,"max":9999999999.99,"precision":2,"max":9999999999.99}]'::JSON,true,'P0001','p_insert_respondent_account: duplicate metadata for Amount');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Amount escaped consumed metadata duplicate maxTrue','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":0,"max":9999999999.99,"precision":2,"m\u0061x":9999999999.99}]'::JSON,true,'P0001','p_insert_respondent_account: duplicate metadata for Amount');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Amount escaped consumed metadata duplicate precisionFalse','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":0,"max":9999999999.99,"precision":2,"precision":2}]'::JSON,true,'P0001','p_insert_respondent_account: duplicate metadata for Amount');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Amount escaped consumed metadata duplicate precisionTrue','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":0,"max":9999999999.99,"precision":2,"p\u0072ecision":2}]'::JSON,true,'P0001','p_insert_respondent_account: duplicate metadata for Amount');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Amount metadata type omitted',((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT') #- '{0,type}')::JSON,true,'P0001','p_insert_respondent_account: invalid metadata for Amount');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Amount metadata type null',JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{0,type}','null'::JSONB)::JSON,true,'P0001','p_insert_respondent_account: invalid metadata for Amount');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Amount metadata type 1',JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{0,type}','1'::JSONB)::JSON,true,'P0001','p_insert_respondent_account: invalid metadata for Amount');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Amount metadata type "decimal-1dp"',JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{0,type}','"decimal-1dp"'::JSONB)::JSON,true,'P0001','p_insert_respondent_account: invalid metadata for Amount');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Amount metadata type "text-60"',JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{0,type}','"text-60"'::JSONB)::JSON,true,'P0001','p_insert_respondent_account: invalid metadata for Amount');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Amount metadata mandatory omitted',((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT') #- '{0,mandatory}')::JSON,true,'P0001','p_insert_respondent_account: invalid metadata for Amount');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Amount metadata mandatory null',JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{0,mandatory}','null'::JSONB)::JSON,true,'P0001','p_insert_respondent_account: invalid metadata for Amount');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Amount metadata mandatory "true"',JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{0,mandatory}','"true"'::JSONB)::JSON,true,'P0001','p_insert_respondent_account: invalid metadata for Amount');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Amount metadata mandatory 1',JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{0,mandatory}','1'::JSONB)::JSON,true,'P0001','p_insert_respondent_account: invalid metadata for Amount');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Amount metadata min omitted',((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT') #- '{0,min}')::JSON,true,'P0001','p_insert_respondent_account: invalid metadata for Amount');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Amount metadata min null',JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{0,min}','null'::JSONB)::JSON,true,'P0001','p_insert_respondent_account: invalid metadata for Amount');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Amount metadata min "0"',JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{0,min}','"0"'::JSONB)::JSON,true,'P0001','p_insert_respondent_account: invalid metadata for Amount');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Amount metadata min {}',JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{0,min}','{}'::JSONB)::JSON,true,'P0001','p_insert_respondent_account: invalid metadata for Amount');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Amount metadata max omitted',((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT') #- '{0,max}')::JSON,true,'P0001','p_insert_respondent_account: invalid metadata for Amount');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Amount metadata max null',JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{0,max}','null'::JSONB)::JSON,true,'P0001','p_insert_respondent_account: invalid metadata for Amount');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Amount metadata max "10"',JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{0,max}','"10"'::JSONB)::JSON,true,'P0001','p_insert_respondent_account: invalid metadata for Amount');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Amount metadata max {}',JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{0,max}','{}'::JSONB)::JSON,true,'P0001','p_insert_respondent_account: invalid metadata for Amount');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Amount inverted bounds',JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{0,min}','10000000000'::JSONB)::JSON,true,'P0001','p_insert_respondent_account: invalid bounds or mandatory flag for Amount');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Amount precision 1',JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{0,precision}','1'::JSONB)::JSON,true,'P0001','p_insert_respondent_account: invalid precision for Amount');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Amount precision "2"',JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{0,precision}','"2"'::JSONB)::JSON,true,'P0001','p_insert_respondent_account: invalid precision for Amount');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Amount precision null',JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{0,precision}','null'::JSONB)::JSON,true,'P0001','p_insert_respondent_account: invalid precision for Amount');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state) VALUES('Amount precision omitted',((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT') #- '{0,precision}')::JSON,true,NULL);
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state) VALUES('Amount precision numeric2',JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{0,precision}','2'::JSONB)::JSON,true,NULL);
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Arrears repeated definition',((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT')||JSONB_BUILD_ARRAY((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT')->3))::JSON,true,'P0001','p_insert_respondent_account: ambiguous or missing Arrears');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Arrears escaped consumed metadata duplicate typeFalse','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":0,"max":9999999999.99},{"name":"Arrears","type":"decimal-2dp","mandatory":false,"min":0,"max":9999999999.99,"precision":2,"type":"decimal-2dp"}]'::JSON,true,'P0001','p_insert_respondent_account: duplicate metadata for Arrears');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Arrears escaped consumed metadata duplicate typeTrue','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":0,"max":9999999999.99},{"name":"Arrears","type":"decimal-2dp","mandatory":false,"min":0,"max":9999999999.99,"precision":2,"t\u0079pe":"decimal-2dp"}]'::JSON,true,'P0001','p_insert_respondent_account: duplicate metadata for Arrears');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Arrears escaped consumed metadata duplicate mandatoryFalse','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":0,"max":9999999999.99},{"name":"Arrears","type":"decimal-2dp","mandatory":false,"min":0,"max":9999999999.99,"precision":2,"mandatory":true}]'::JSON,true,'P0001','p_insert_respondent_account: duplicate metadata for Arrears');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Arrears escaped consumed metadata duplicate mandatoryTrue','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":0,"max":9999999999.99},{"name":"Arrears","type":"decimal-2dp","mandatory":false,"min":0,"max":9999999999.99,"precision":2,"m\u0061ndatory":true}]'::JSON,true,'P0001','p_insert_respondent_account: duplicate metadata for Arrears');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Arrears escaped consumed metadata duplicate minFalse','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":0,"max":9999999999.99},{"name":"Arrears","type":"decimal-2dp","mandatory":false,"min":0,"max":9999999999.99,"precision":2,"min":0}]'::JSON,true,'P0001','p_insert_respondent_account: duplicate metadata for Arrears');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Arrears escaped consumed metadata duplicate minTrue','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":0,"max":9999999999.99},{"name":"Arrears","type":"decimal-2dp","mandatory":false,"min":0,"max":9999999999.99,"precision":2,"m\u0069n":0}]'::JSON,true,'P0001','p_insert_respondent_account: duplicate metadata for Arrears');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Arrears escaped consumed metadata duplicate maxFalse','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":0,"max":9999999999.99},{"name":"Arrears","type":"decimal-2dp","mandatory":false,"min":0,"max":9999999999.99,"precision":2,"max":9999999999.99}]'::JSON,true,'P0001','p_insert_respondent_account: duplicate metadata for Arrears');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Arrears escaped consumed metadata duplicate maxTrue','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":0,"max":9999999999.99},{"name":"Arrears","type":"decimal-2dp","mandatory":false,"min":0,"max":9999999999.99,"precision":2,"m\u0061x":9999999999.99}]'::JSON,true,'P0001','p_insert_respondent_account: duplicate metadata for Arrears');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Arrears escaped consumed metadata duplicate precisionFalse','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":0,"max":9999999999.99},{"name":"Arrears","type":"decimal-2dp","mandatory":false,"min":0,"max":9999999999.99,"precision":2,"precision":2}]'::JSON,true,'P0001','p_insert_respondent_account: duplicate metadata for Arrears');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Arrears escaped consumed metadata duplicate precisionTrue','[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":0,"max":9999999999.99},{"name":"Arrears","type":"decimal-2dp","mandatory":false,"min":0,"max":9999999999.99,"precision":2,"p\u0072ecision":2}]'::JSON,true,'P0001','p_insert_respondent_account: duplicate metadata for Arrears');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Arrears metadata type omitted',((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT') #- '{3,type}')::JSON,true,'P0001','p_insert_respondent_account: invalid metadata for Arrears');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Arrears metadata type null',JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{3,type}','null'::JSONB)::JSON,true,'P0001','p_insert_respondent_account: invalid metadata for Arrears');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Arrears metadata type 1',JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{3,type}','1'::JSONB)::JSON,true,'P0001','p_insert_respondent_account: invalid metadata for Arrears');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Arrears metadata type "decimal-1dp"',JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{3,type}','"decimal-1dp"'::JSONB)::JSON,true,'P0001','p_insert_respondent_account: invalid metadata for Arrears');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Arrears metadata type "text-60"',JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{3,type}','"text-60"'::JSONB)::JSON,true,'P0001','p_insert_respondent_account: invalid metadata for Arrears');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Arrears metadata mandatory omitted',((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT') #- '{3,mandatory}')::JSON,true,'P0001','p_insert_respondent_account: invalid metadata for Arrears');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Arrears metadata mandatory null',JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{3,mandatory}','null'::JSONB)::JSON,true,'P0001','p_insert_respondent_account: invalid metadata for Arrears');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Arrears metadata mandatory "true"',JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{3,mandatory}','"true"'::JSONB)::JSON,true,'P0001','p_insert_respondent_account: invalid metadata for Arrears');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Arrears metadata mandatory 1',JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{3,mandatory}','1'::JSONB)::JSON,true,'P0001','p_insert_respondent_account: invalid metadata for Arrears');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Arrears metadata min omitted',((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT') #- '{3,min}')::JSON,true,'P0001','p_insert_respondent_account: invalid metadata for Arrears');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Arrears metadata min null',JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{3,min}','null'::JSONB)::JSON,true,'P0001','p_insert_respondent_account: invalid metadata for Arrears');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Arrears metadata min "0"',JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{3,min}','"0"'::JSONB)::JSON,true,'P0001','p_insert_respondent_account: invalid metadata for Arrears');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Arrears metadata min {}',JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{3,min}','{}'::JSONB)::JSON,true,'P0001','p_insert_respondent_account: invalid metadata for Arrears');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Arrears metadata max omitted',((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT') #- '{3,max}')::JSON,true,'P0001','p_insert_respondent_account: invalid metadata for Arrears');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Arrears metadata max null',JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{3,max}','null'::JSONB)::JSON,true,'P0001','p_insert_respondent_account: invalid metadata for Arrears');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Arrears metadata max "10"',JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{3,max}','"10"'::JSONB)::JSON,true,'P0001','p_insert_respondent_account: invalid metadata for Arrears');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Arrears metadata max {}',JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{3,max}','{}'::JSONB)::JSON,true,'P0001','p_insert_respondent_account: invalid metadata for Arrears');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Arrears inverted bounds',JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{3,min}','10000000000'::JSONB)::JSON,true,'P0001','p_insert_respondent_account: invalid bounds or mandatory flag for Arrears');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Arrears precision 1',JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{3,precision}','1'::JSONB)::JSON,true,'P0001','p_insert_respondent_account: invalid precision for Arrears');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Arrears precision "2"',JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{3,precision}','"2"'::JSONB)::JSON,true,'P0001','p_insert_respondent_account: invalid precision for Arrears');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Arrears precision null',JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{3,precision}','null'::JSONB)::JSON,true,'P0001','p_insert_respondent_account: invalid precision for Arrears');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state) VALUES('Arrears precision omitted',((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT') #- '{3,precision}')::JSON,true,NULL);
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state) VALUES('Arrears precision numeric2',JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{3,precision}','2'::JSONB)::JSON,true,NULL);
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Amount missing definition',(SELECT JSONB_AGG(d.value)::JSON FROM JSONB_ARRAY_ELEMENTS((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT')) d WHERE d.value->>'name'<>'Amount'),true,'P0001','p_insert_respondent_account: ambiguous or missing Amount');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Amount mandatory false',JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{0,mandatory}','false'::JSONB)::JSON,true,'P0001','p_insert_respondent_account: invalid bounds or mandatory flag for Amount');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message) VALUES('Arrears mandatory response missing',JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{3,mandatory}','true'::JSONB)::JSON,true,'P0001','p_insert_respondent_account: missing or duplicate Arrears');
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state) VALUES('Arrears absent definition and omitted response',(SELECT JSONB_AGG(d.value)::JSON FROM JSONB_ARRAY_ELEMENTS((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT')) d WHERE d.value->>'name'<>'Arrears'),true,NULL);
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state,expected_message,payload) VALUES('Arrears absent definition but supplied response',(SELECT JSONB_AGG(d.value)::JSON FROM JSONB_ARRAY_ELEMENTS((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT')) d WHERE d.value->>'name'<>'Arrears'),true,'P0001','p_insert_respondent_account: undeclared Arrears',JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0,result_responses}',(pg_temp.account_payload()::JSONB#>'{order_details,order_terms,0,result_responses}')||'[{"parameter_name":"Arrears","response":"0"}]')::JSON);
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state) VALUES('opaque metadata malformed profile fields',((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT')||'[{"name":"Opaque","type":null,"mandatory":"bad","min":{},"max":[],"precision":1,"options":true}]')::JSON,true,NULL);
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state) VALUES('consumed prompt and unconsumed profile fields malformed',JSONB_SET(JSONB_SET((SELECT result_parameters::JSONB FROM public.results WHERE result_id='MAT'),'{0,prompt}','{}'),'{0,options}','false')::JSON,true,NULL);
INSERT INTO reference_cases(label,metadata,replace_metadata,expected_state) VALUES('duplicate unconsumed metadata key opaque',('[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":0,"max":9999999999.99,"prompt":{},"prompt":false}]')::JSON,true,NULL);
INSERT INTO reference_cases(label,expected_state,clone_result,payload) VALUES('six-character nonallowlisted Result clone',NULL,true,JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,order_terms,0,result_id}','"T10650"')::JSON);

INSERT INTO reference_cases(label,call_contact,mutate_contact_country,expected_extra) VALUES('contact Country remains child-helper responsibility',918650,true,'{"third_party_contact_id":918650}');
CREATE TEMP TABLE reference_observations(label TEXT PRIMARY KEY,succeeded BOOLEAN,state TEXT,
 message TEXT,detail TEXT,hint TEXT,context TEXT,constraint_name TEXT,output JSONB,account_row JSONB,
 calls BIGINT,accounts_delta BIGINT,ledger_delta BIGINT,sequence_before JSONB,sequence_after JSONB);
DO $reference_cases$
DECLARE c RECORD; succeeded BOOLEAN; state TEXT; message TEXT; detail TEXT; hint TEXT;
 context TEXT; constraint_name TEXT; output JSONB; account_row JSONB;
 before_calls BIGINT; before_accounts BIGINT; before_ledger BIGINT;
 sequence_before JSONB; sequence_after JSONB;
BEGIN
 FOR c IN SELECT * FROM reference_cases ORDER BY label LOOP
  succeeded:=false; state:=NULL; message:=NULL; detail:=NULL; hint:=NULL;
  context:=NULL; constraint_name:=NULL; output:=NULL; account_row:=NULL;
  before_calls:=pg_temp.allocator_calls();
  SELECT COUNT(*) INTO before_accounts FROM public.respondent_accounts WHERE business_unit_id=31850;
  SELECT COUNT(*) INTO before_ledger FROM public.account_number_index WHERE business_unit_id=31850;
  SELECT JSONB_BUILD_ARRAY(last_value,is_called) INTO sequence_before FROM public.account_number_index_id_seq;
  BEGIN
   IF c.replace_metadata THEN
    UPDATE public.results SET result_parameters=c.metadata WHERE result_id='MAT';
   END IF;
   IF c.result_active IS NOT NULL THEN
    UPDATE public.results SET active=c.result_active WHERE result_id='MAT';
   END IF;
   IF c.order_term IS NOT NULL THEN
    UPDATE public.results SET order_term=c.order_term WHERE result_id='MAT';
   END IF;
   IF c.app_active IS NOT NULL THEN
    UPDATE public.maintenance_applications SET active=c.app_active WHERE application_code='P10650';
   END IF;
   IF c.app_start IS NOT NULL THEN
    UPDATE public.maintenance_applications SET date_used_from=c.app_start WHERE application_code='P10650';
   END IF;
   IF c.set_end THEN
    UPDATE public.maintenance_applications SET date_used_to=c.app_end WHERE application_code='P10650';
   END IF;
   IF c.clone_result THEN
    INSERT INTO public.results
    SELECT (JSONB_POPULATE_RECORD(NULL::public.results,
     TO_JSONB(r)||JSONB_BUILD_OBJECT('result_id','T10650'))).*
    FROM public.results r WHERE r.result_id='MAT';
   END IF;
   IF c.mutate_contact_country THEN
    UPDATE public.third_party_contact SET country=918650 WHERE third_party_contact_id=918650;
   END IF;
   output:=pg_temp.invoke_account(c.payload,contact=>c.call_contact);
   SELECT TO_JSONB(a) INTO account_row FROM public.respondent_accounts a
   WHERE a.respondent_account_id=(output->>'id')::BIGINT;
   succeeded:=true;
   RAISE EXCEPTION SQLSTATE 'ZX651' USING MESSAGE='test rollback after reference observation';
  EXCEPTION
   WHEN SQLSTATE 'ZX651' THEN NULL;
   WHEN OTHERS THEN GET STACKED DIAGNOSTICS state=RETURNED_SQLSTATE,
    message=MESSAGE_TEXT,detail=PG_EXCEPTION_DETAIL,hint=PG_EXCEPTION_HINT,
    context=PG_EXCEPTION_CONTEXT,constraint_name=CONSTRAINT_NAME;
  END;
  SELECT JSONB_BUILD_ARRAY(last_value,is_called) INTO sequence_after FROM public.account_number_index_id_seq;
  INSERT INTO reference_observations SELECT c.label,succeeded,state,message,detail,hint,context,
   constraint_name,output,account_row,pg_temp.allocator_calls()-before_calls,
   (SELECT COUNT(*) FROM public.respondent_accounts WHERE business_unit_id=31850)-before_accounts,
   (SELECT COUNT(*) FROM public.account_number_index WHERE business_unit_id=31850)-before_ledger,
   sequence_before,sequence_after;
 END LOOP;
END;
$reference_cases$;
SELECT is(o.succeeded,false,c.label||': failure has no successful CALL result')
FROM reference_cases c JOIN reference_observations o USING(label) WHERE c.expected_state IS NOT NULL;
SELECT is(o.state,c.expected_state,c.label||': original expected SQLSTATE')
FROM reference_cases c JOIN reference_observations o USING(label) WHERE c.expected_state IS NOT NULL;
SELECT is(o.constraint_name,'',c.label||': deliberate failure has no native constraint')
FROM reference_cases c JOIN reference_observations o USING(label) WHERE c.expected_state IS NOT NULL;
SELECT is(o.calls,0::BIGINT,c.label||': no completed allocator call')
FROM reference_cases c JOIN reference_observations o USING(label) WHERE c.expected_state IS NOT NULL;
SELECT is(o.accounts_delta,0::BIGINT,c.label||': no protected account survives')
FROM reference_cases c JOIN reference_observations o USING(label) WHERE c.expected_state IS NOT NULL;
SELECT is(o.ledger_delta,0::BIGINT,c.label||': no protected reservation survives')
FROM reference_cases c JOIN reference_observations o USING(label) WHERE c.expected_state IS NOT NULL;
SELECT ok(o.message=c.expected_message AND o.detail='' AND o.hint=''
 AND o.context LIKE '%p_insert_respondent_account%' AND o.message NOT LIKE '%P10650_MARKER%',
 c.label||': exact fixed value-free guard diagnostics')
FROM reference_cases c JOIN reference_observations o USING(label) WHERE c.expected_state IS NOT NULL;
SELECT is(o.sequence_after,o.sequence_before,c.label||': preallocation sequence snapshot unchanged')
FROM reference_cases c JOIN reference_observations o USING(label) WHERE c.expected_state IS NOT NULL;
SELECT ok(o.succeeded AND o.state IS NULL,c.label||': reference change permits actual CALL')
FROM reference_cases c JOIN reference_observations o USING(label) WHERE c.expected_state IS NULL;
SELECT ok(o.account_row @> c.expected_extra AND o.account_row @> JSONB_BUILD_OBJECT('orders_amount',10,'total_arrears',0,
 'orders_balance',10*(SELECT COUNT(*)-1 FROM GENERATE_SERIES(TIMESTAMP '2024-01-01',
 (pg_catalog.TRANSACTION_TIMESTAMP() AT TIME ZONE 'Europe/London')::DATE,INTERVAL '1 month')))
 AND o.account_row->>'account_number'=o.output->>'number'
 AND o.account_row->>'respondent_account_id'=o.output->>'id',
 c.label||': exact finances and both same-row outputs')
FROM reference_cases c JOIN reference_observations o USING(label) WHERE c.expected_state IS NULL;
SELECT ok(o.calls=1 AND o.accounts_delta=0 AND o.ledger_delta=0,
 c.label||': one completed allocation and enclosing rollback restores writes')
FROM reference_cases c JOIN reference_observations o USING(label) WHERE c.expected_state IS NULL;
SELECT ok(NOT EXISTS(SELECT 1 FROM public.results WHERE result_id='T10650'),
 'rolled-back six-character Result clone leaves no reference fixture');

-- ---------------------------------------------------------------------------
-- Scenario: Consumed account work has no publication or unrelated-row side effects.
-- Setup:    Sorted ROW_TO_JSON text snapshots precede the entire Task 2 matrix.
-- Expected: Original rows, JSON source bytes/multiplicity, status/snapshot survive.
-- ---------------------------------------------------------------------------
CREATE TEMP TABLE protected_rows_after(LIKE protected_rows_before);
DO $compare_rows$
DECLARE c RECORD; rows TEXT[];
BEGIN
 FOR c IN SELECT * FROM protected_rows_before LOOP
  IF c.table_name='respondent_accounts' THEN
   SELECT COALESCE(ARRAY_AGG(ROW_TO_JSON(r)::TEXT ORDER BY ROW_TO_JSON(r)::TEXT),ARRAY[]::TEXT[]) INTO rows
   FROM public.respondent_accounts r WHERE respondent_account_id IN (SELECT respondent_account_id FROM protected_account_ids);
  ELSIF c.table_name='account_number_index' THEN
   SELECT COALESCE(ARRAY_AGG(ROW_TO_JSON(r)::TEXT ORDER BY ROW_TO_JSON(r)::TEXT),ARRAY[]::TEXT[]) INTO rows
   FROM public.account_number_index r WHERE account_number_index_id IN (SELECT account_number_index_id FROM protected_ledger_ids);
  ELSE
   EXECUTE FORMAT('SELECT COALESCE(ARRAY_AGG(ROW_TO_JSON(r)::TEXT ORDER BY ROW_TO_JSON(r)::TEXT),ARRAY[]::TEXT[]) FROM public.%I r',c.table_name) INTO rows;
  END IF;
  INSERT INTO protected_rows_after VALUES(c.table_name,rows);
 END LOOP;
END;
$compare_rows$;
SELECT is(a.rows,b.rows,b.table_name||': exact original row text and multiplicity preserved')
FROM protected_rows_before b JOIN protected_rows_after a USING(table_name);


-- ---------------------------------------------------------------------------
-- Scenario: Exact money, original-date calendar boundaries and global settings.
-- Setup:    Literal independent fixtures; installed CALL and real allocator.
-- Expected: Seven per-success checks, six rejection-adapter checks plus capture
--           and sequence evidence, all emitted after nested/clock rollback.
-- ---------------------------------------------------------------------------
CREATE TEMP TABLE financial_outputs(label TEXT PRIMARY KEY,output JSONB NOT NULL);
CREATE FUNCTION pg_temp.financial_observation(payload JSON, expected_amount NUMERIC,
 expected_arrears NUMERIC, expected_balance NUMERIC, expected_utc TIMESTAMP, label TEXT)
RETURNS JSONB LANGUAGE plpgsql AS $observe$
DECLARE
 output JSONB; account public.respondent_accounts%ROWTYPE;
 before_calls BIGINT := pg_temp.allocator_calls(); before_capture BIGINT; after_capture BIGINT;
BEGIN
 SELECT CASE WHEN is_called THEN last_value ELSE 0 END INTO before_capture
 FROM opal_po10650_financial_clock.capture_count;
 output := pg_temp.invoke_account(payload);
 INSERT INTO financial_outputs VALUES(label,output);
 SELECT CASE WHEN is_called THEN last_value ELSE 0 END INTO after_capture
 FROM opal_po10650_financial_clock.capture_count;
 SELECT * INTO STRICT account FROM public.respondent_accounts WHERE respondent_account_id=(output->>'id')::BIGINT;
 RETURN JSONB_BUILD_ARRAY(
  JSONB_BUILD_OBJECT('pass',account.account_number=output->>'number' AND EXISTS(
   SELECT 1 FROM public.account_number_index n WHERE n.business_unit_id=account.business_unit_id
    AND n.account_number=account.account_number AND n.associated_record_type='respondent_accounts'),
   'description',label||': row and both outputs/reservation agree'),
  JSONB_BUILD_OBJECT('pass',account.orders_amount=expected_amount,'description',label||': exact persisted Amount sum'),
  JSONB_BUILD_OBJECT('pass',account.total_arrears=expected_arrears,'description',label||': exact persisted Arrears sum'),
  JSONB_BUILD_OBJECT('pass',account.orders_balance=expected_balance AND account.account_balance=0.00,
   'description',label||': exact persisted balances'),
  JSONB_BUILD_OBJECT('pass',account.last_movement_date=expected_utc
   AND account.imposed_hearing_date=(payload->'order_details'->>'date_ordered')::DATE::TIMESTAMP
   AND account.date_arrears_last_updated=(payload->'order_details'->>'date_arrears_last_updated')::DATE::TIMESTAMP,
   'description',label||': independent UTC audit and preserved calendar midnights'),
  JSONB_BUILD_OBJECT('pass',after_capture-before_capture=1,'description',label||': exactly one financial clock capture'),
  JSONB_BUILD_OBJECT('pass',pg_temp.allocator_calls()-before_calls=1,'description',label||': exactly one completed real allocation'));
END;
$observe$;
-- The rejection adapter and this buffered consumer share one observation path.
-- No pgTAP assertion executes inside a scope that will later be rolled back.
CREATE FUNCTION pg_temp.financial_rejection(payload JSON, state TEXT, label TEXT) RETURNS JSONB
LANGUAGE plpgsql AS $reject_observe$
DECLARE observed JSONB; sequence_before JSONB; sequence_after JSONB;
 before_capture BIGINT; after_capture BIGINT;
BEGIN
 SELECT JSONB_BUILD_ARRAY(last_value,is_called) INTO sequence_before FROM public.account_number_index_id_seq;
 SELECT CASE WHEN is_called THEN last_value ELSE 0 END INTO before_capture FROM opal_po10650_financial_clock.capture_count;
 PERFORM SET_CONFIG('opal.po10650_case',label,true);
 observed:=pg_temp.observe_account_rejection(payload,state);
 SELECT JSONB_BUILD_ARRAY(last_value,is_called) INTO sequence_after FROM public.account_number_index_id_seq;
 SELECT CASE WHEN is_called THEN last_value ELSE 0 END INTO after_capture FROM opal_po10650_financial_clock.capture_count;
 RETURN JSONB_BUILD_ARRAY(
  JSONB_BUILD_OBJECT('pass',NOT (observed->>'succeeded')::BOOLEAN,'description',label||': failure has no successful CALL result'),
  JSONB_BUILD_OBJECT('pass',observed->>'state' IS NOT DISTINCT FROM state,'description',label||': original expected SQLSTATE'),
  JSONB_BUILD_OBJECT('pass',observed->>'constraint'='','description',label||': applicable native constraint identity'),
  JSONB_BUILD_OBJECT('pass',(observed->>'calls')::BIGINT=0,'description',label||': controlled allocator completed-call delta'),
  JSONB_BUILD_OBJECT('pass',(observed->>'accounts')::BIGINT=0,'description',label||': no protected account survives'),
  JSONB_BUILD_OBJECT('pass',(observed->>'ledger')::BIGINT=0,'description',label||': no protected reservation survives'),
  JSONB_BUILD_OBJECT('pass',sequence_before=sequence_after,'description',label||': allocator sequence unchanged'),
  JSONB_BUILD_OBJECT('pass',after_capture-before_capture=1,'description',label||': failed entry captures financial clock once'));
END;
$reject_observe$;
CREATE TEMP TABLE financial_observations(label TEXT PRIMARY KEY,checks JSONB NOT NULL);

CREATE TEMP TABLE calendar_cases(frequency TEXT,arrears DATE,publication DATE,periods NUMERIC);
INSERT INTO calendar_cases VALUES
 ('Weekly','2026-08-05','2026-08-05',0),('Weekly','2026-08-05','2026-08-11',0),
 ('Weekly','2026-08-05','2026-08-12',1),('Weekly','2026-08-05','2026-08-13',1),
 ('Weekly','2026-08-05','2026-08-18',1),('Weekly','2026-08-05','2026-08-19',2),('Weekly','2026-08-05','2026-08-20',2),
 ('Fortnightly','2026-08-05','2026-08-05',0),('Fortnightly','2026-08-05','2026-08-18',0),
 ('Fortnightly','2026-08-05','2026-08-19',1),('Fortnightly','2026-08-05','2026-08-20',1),
 ('Fortnightly','2026-08-05','2026-09-01',1),('Fortnightly','2026-08-05','2026-09-02',2),('Fortnightly','2026-08-05','2026-09-03',2),
 ('Monthly','2026-08-05','2026-08-05',0),('Monthly','2026-08-05','2026-09-04',0),
 ('Monthly','2026-08-05','2026-09-05',1),('Monthly','2026-08-05','2026-09-06',1),
 ('Monthly','2026-08-05','2026-10-04',1),('Monthly','2026-08-05','2026-10-05',2),('Monthly','2026-08-05','2026-10-06',2),
 ('Monthly','2027-01-31','2027-02-27',0),('Monthly','2027-01-31','2027-02-28',1),('Monthly','2027-01-31','2027-03-01',1),
 ('Monthly','2027-01-31','2027-03-30',1),('Monthly','2027-01-31','2027-03-31',2),('Monthly','2027-01-31','2027-04-01',2),
 ('Monthly','2027-01-31','2027-04-29',2),('Monthly','2027-01-31','2027-04-30',3),('Monthly','2027-01-31','2027-05-01',3),
 ('Monthly','2027-04-30','2027-05-29',0),('Monthly','2027-04-30','2027-05-30',1),('Monthly','2027-04-30','2027-05-31',1),
 ('Monthly','2027-04-30','2027-06-29',1),('Monthly','2027-04-30','2027-06-30',2),('Monthly','2027-04-30','2027-07-01',2),
 ('Quarterly','2026-11-30','2027-02-27',0),('Quarterly','2026-11-30','2027-02-28',1),('Quarterly','2026-11-30','2027-03-01',1),
 ('Quarterly','2026-11-30','2027-05-29',1),('Quarterly','2026-11-30','2027-05-30',2),('Quarterly','2026-11-30','2027-05-31',2),
 ('Quarterly','2026-11-30','2027-08-29',2),('Quarterly','2026-11-30','2027-08-30',3),('Quarterly','2026-11-30','2027-08-31',3),
 ('Yearly','2024-02-29','2025-02-27',0),('Yearly','2024-02-29','2025-02-28',1),('Yearly','2024-02-29','2025-03-01',1),
 ('Yearly','2024-02-29','2026-02-27',1),('Yearly','2024-02-29','2026-02-28',2),('Yearly','2024-02-29','2026-03-01',2),
 ('Yearly','2024-02-29','2027-02-27',2),('Yearly','2024-02-29','2027-02-28',3),('Yearly','2024-02-29','2027-03-01',3),
 ('Yearly','2024-02-29','2028-02-28',3),('Yearly','2024-02-29','2028-02-29',4),('Yearly','2024-02-29','2028-03-01',4),
 ('Weekly','2027-03-24','2027-03-30',0),('Weekly','2027-03-24','2027-03-31',1),('Weekly','2027-03-24','2027-04-01',1),
 ('Fortnightly','2027-03-17','2027-03-30',0),('Fortnightly','2027-03-17','2027-03-31',1),('Fortnightly','2027-03-17','2027-04-01',1),
 ('Weekly','2027-10-27','2027-11-02',0),('Weekly','2027-10-27','2027-11-03',1),('Weekly','2027-10-27','2027-11-04',1),
 ('Fortnightly','2027-10-20','2027-11-02',0),('Fortnightly','2027-10-20','2027-11-03',1),('Fortnightly','2027-10-20','2027-11-04',1);
CREATE TEMP TABLE monetary_cases(label TEXT PRIMARY KEY,terms JSONB,amount NUMERIC,arrears NUMERIC,balance NUMERIC,metadata JSON,instant TIMESTAMPTZ,arrears_date DATE);
INSERT INTO monetary_cases VALUES('money integer','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "12"}]}]'::JSONB,12,0,24,NULL,'2027-03-01 12:00:00+00','2027-01-01');
INSERT INTO monetary_cases VALUES('money one fraction','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "12.3"}]}]'::JSONB,12.3,0,24.6,NULL,'2027-03-01 12:00:00+00','2027-01-01');
INSERT INTO monetary_cases VALUES('money two fractions','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "12.30"}]}]'::JSONB,12.30,0,24.60,NULL,'2027-03-01 12:00:00+00','2027-01-01');
INSERT INTO monetary_cases VALUES('money leading zeros','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "0012.30"}]}]'::JSONB,12.30,0,24.60,NULL,'2027-03-01 12:00:00+00','2027-01-01');
INSERT INTO monetary_cases VALUES('money positive zero','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "0.00"}]}]'::JSONB,0,0,0,NULL,'2027-03-01 12:00:00+00','2027-01-01');
INSERT INTO monetary_cases VALUES('money negative zero','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "-0.00"}]}]'::JSONB,0,0,0,NULL,'2027-03-01 12:00:00+00','2027-01-01');
INSERT INTO monetary_cases VALUES('money minimum inclusive','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "0"}]}]'::JSONB,0,0,0,NULL,'2027-03-01 12:00:00+00','2027-01-01');
INSERT INTO monetary_cases VALUES('money maximum inclusive','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "9999999999.99"}]}]'::JSONB,9999999999.99,0,19999999999.98,NULL,'2027-03-01 12:00:00+00','2027-01-01');
INSERT INTO monetary_cases VALUES('money large sum','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "9999999999.99"}]}, {"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "9999999999.99"}]}]'::JSONB,19999999999.98,0,39999999999.96,NULL,'2027-03-01 12:00:00+00','2027-01-01');
INSERT INTO monetary_cases VALUES('money mixed 920','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "100"}, {"parameter_name": "Arrears", "response": "20"}]}, {"result_id": "MCHILD", "result_responses": [{"parameter_name": "Amount", "response": "50"}]}, {"result_id": "MLUMP", "result_responses": [{"parameter_name": "Amount", "response": "300"}]}]'::JSONB,450,20,920,NULL,'2027-03-01 12:00:00+00','2027-01-01');
INSERT INTO monetary_cases VALUES('money mixed 12.30','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "100"}, {"parameter_name": "Arrears", "response": "12.30"}]}, {"result_id": "MCHILD", "result_responses": [{"parameter_name": "Amount", "response": "50"}]}, {"result_id": "MLUMP", "result_responses": [{"parameter_name": "Amount", "response": "300"}]}]'::JSONB,450,12.30,912.30,NULL,'2027-03-01 12:00:00+00','2027-01-01');
INSERT INTO monetary_cases VALUES('money all permitted omissions','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "100"}]}, {"result_id": "MCHILD", "result_responses": [{"parameter_name": "Amount", "response": "50"}]}, {"result_id": "MLUMP", "result_responses": [{"parameter_name": "Amount", "response": "300"}]}]'::JSONB,450,0,900,NULL,'2027-03-01 12:00:00+00','2027-01-01');
INSERT INTO monetary_cases VALUES('money explicit Arrears zero','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "100"}, {"parameter_name": "Arrears", "response": "0.00"}]}]'::JSONB,100,0,200,NULL,'2027-03-01 12:00:00+00','2027-01-01');
INSERT INTO monetary_cases VALUES('money Arrears exact maximum','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "0"}, {"parameter_name": "Arrears", "response": "9999999999.99"}]}]'::JSONB,0,9999999999.99,9999999999.99,NULL,'2027-03-01 12:00:00+00','2027-01-01');
INSERT INTO monetary_cases VALUES('money negative permitted','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "-12.30"}]}]'::JSONB,-12.30,0,-24.60,'[{"name": "Amount", "type": "decimal-2dp", "mandatory": true, "min": -20, "max": 20}, {"name": "Arrears", "type": "decimal-2dp", "mandatory": false, "min": -20, "max": 20}]'::JSON,'2027-03-01 12:00:00+00','2027-01-01');
INSERT INTO monetary_cases VALUES('money synthetic minimum','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "-20"}]}]'::JSONB,-20,0,-40,'[{"name": "Amount", "type": "decimal-2dp", "mandatory": true, "min": -20, "max": 20}, {"name": "Arrears", "type": "decimal-2dp", "mandatory": false, "min": -20, "max": 20}]'::JSON,'2027-03-01 12:00:00+00','2027-01-01');
INSERT INTO monetary_cases VALUES('money synthetic maximum','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "20"}]}]'::JSONB,20,0,40,'[{"name": "Amount", "type": "decimal-2dp", "mandatory": true, "min": -20, "max": 20}, {"name": "Arrears", "type": "decimal-2dp", "mandatory": false, "min": -20, "max": 20}]'::JSON,'2027-03-01 12:00:00+00','2027-01-01');
INSERT INTO monetary_cases VALUES('money negative Arrears permitted','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "1"}, {"parameter_name": "Arrears", "response": "-12.30"}]}]'::JSONB,1,-12.30,-10.30,'[{"name": "Amount", "type": "decimal-2dp", "mandatory": true, "min": -20, "max": 20}, {"name": "Arrears", "type": "decimal-2dp", "mandatory": false, "min": -20, "max": 20}]'::JSON,'2027-03-01 12:00:00+00','2027-01-01');
INSERT INTO monetary_cases VALUES('money MLUMP periods 0','[{"result_id": "MLUMP", "result_responses": [{"parameter_name": "Amount", "response": "300"}]}]'::JSONB,300,0,0,NULL,'2027-01-01 12:00:00+00','2027-01-01');
INSERT INTO monetary_cases VALUES('money MLUMP periods 1','[{"result_id": "MLUMP", "result_responses": [{"parameter_name": "Amount", "response": "300"}]}]'::JSONB,300,0,300,NULL,'2027-02-01 12:00:00+00','2027-01-01');
INSERT INTO monetary_cases VALUES('money MLUMP periods 2','[{"result_id": "MLUMP", "result_responses": [{"parameter_name": "Amount", "response": "300"}]}]'::JSONB,300,0,600,NULL,'2027-03-01 12:00:00+00','2027-01-01');
CREATE TEMP TABLE financial_rejections(label TEXT PRIMARY KEY,terms JSONB,state TEXT,metadata JSON);
INSERT INTO financial_rejections VALUES('money reject Amount syntax 00 "+12"','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "+12"}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Amount syntax 01 " 12"','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": " 12"}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Amount syntax 02 "12 "','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "12 "}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Amount syntax 03 "\t12"','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "\t12"}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Amount syntax 04 "12\t"','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "12\t"}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Amount syntax 05 "\n12"','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "\n12"}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Amount syntax 06 "12\n"','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "12\n"}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Amount syntax 07 "1e2"','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "1e2"}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Amount syntax 08 "£12"','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "£12"}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Amount syntax 09 "1,000"','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "1,000"}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Amount syntax 10 ".5"','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": ".5"}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Amount syntax 11 "12."','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "12."}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Amount syntax 12 "12.300"','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "12.300"}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Amount syntax 13 "１２"','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "１２"}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Amount syntax 14 "−12"','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "−12"}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Amount syntax 15 ""','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": ""}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Amount syntax 16 null','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": null}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Amount syntax 17 12','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": 12}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Amount syntax 18 true','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": true}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Amount syntax 19 {}','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": {}}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Amount syntax 20 []','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": []}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Arrears syntax 00 "+12"','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "1"}, {"parameter_name": "Arrears", "response": "+12"}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Arrears syntax 01 " 12"','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "1"}, {"parameter_name": "Arrears", "response": " 12"}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Arrears syntax 02 "12 "','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "1"}, {"parameter_name": "Arrears", "response": "12 "}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Arrears syntax 03 "\t12"','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "1"}, {"parameter_name": "Arrears", "response": "\t12"}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Arrears syntax 04 "12\t"','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "1"}, {"parameter_name": "Arrears", "response": "12\t"}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Arrears syntax 05 "\n12"','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "1"}, {"parameter_name": "Arrears", "response": "\n12"}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Arrears syntax 06 "12\n"','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "1"}, {"parameter_name": "Arrears", "response": "12\n"}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Arrears syntax 07 "1e2"','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "1"}, {"parameter_name": "Arrears", "response": "1e2"}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Arrears syntax 08 "£12"','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "1"}, {"parameter_name": "Arrears", "response": "£12"}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Arrears syntax 09 "1,000"','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "1"}, {"parameter_name": "Arrears", "response": "1,000"}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Arrears syntax 10 ".5"','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "1"}, {"parameter_name": "Arrears", "response": ".5"}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Arrears syntax 11 "12."','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "1"}, {"parameter_name": "Arrears", "response": "12."}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Arrears syntax 12 "12.300"','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "1"}, {"parameter_name": "Arrears", "response": "12.300"}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Arrears syntax 13 "１２"','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "1"}, {"parameter_name": "Arrears", "response": "１２"}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Arrears syntax 14 "−12"','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "1"}, {"parameter_name": "Arrears", "response": "−12"}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Arrears syntax 15 ""','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "1"}, {"parameter_name": "Arrears", "response": ""}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Arrears syntax 16 null','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "1"}, {"parameter_name": "Arrears", "response": null}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Arrears syntax 17 12','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "1"}, {"parameter_name": "Arrears", "response": 12}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Arrears syntax 18 true','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "1"}, {"parameter_name": "Arrears", "response": true}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Arrears syntax 19 {}','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "1"}, {"parameter_name": "Arrears", "response": {}}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Arrears syntax 20 []','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "1"}, {"parameter_name": "Arrears", "response": []}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Amount outside configured bound -0.01','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "-0.01"}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Amount outside configured bound 10000000000.00','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "10000000000.00"}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Arrears outside configured bound -0.01','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "1"}, {"parameter_name": "Arrears", "response": "-0.01"}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject Arrears outside configured bound 10000000000.00','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "1"}, {"parameter_name": "Arrears", "response": "10000000000.00"}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject outside synthetic bound -20.01','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "-20.01"}]}]'::JSONB,'P0001','[{"name": "Amount", "type": "decimal-2dp", "mandatory": true, "min": -20, "max": 20}, {"name": "Arrears", "type": "decimal-2dp", "mandatory": false, "min": -20, "max": 20}]'::JSON);
INSERT INTO financial_rejections VALUES('money reject outside synthetic bound 20.01','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "20.01"}]}]'::JSONB,'P0001','[{"name": "Amount", "type": "decimal-2dp", "mandatory": true, "min": -20, "max": 20}, {"name": "Arrears", "type": "decimal-2dp", "mandatory": false, "min": -20, "max": 20}]'::JSON);
INSERT INTO financial_rejections VALUES('money reject negative unchanged bounds','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "-12.30"}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject mandatory Arrears omitted','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "1"}]}]'::JSONB,'P0001','[{"name": "Amount", "type": "decimal-2dp", "mandatory": true, "min": 0, "max": 9999999999.99}, {"name": "Arrears", "type": "decimal-2dp", "mandatory": true, "min": 0, "max": 9999999999.99}]'::JSON);
INSERT INTO financial_rejections VALUES('money reject undeclared MLUMP Arrears supplied','[{"result_id": "MLUMP", "result_responses": [{"parameter_name": "Amount", "response": "1"}, {"parameter_name": "Arrears", "response": "0"}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject invalid term position 1','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "bad"}]}, {"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "0"}]}, {"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "9999999999.99"}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject invalid term position 2','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "0"}]}, {"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "bad"}]}, {"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "9999999999.99"}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject invalid term position 3','[{"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "0"}]}, {"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "9999999999.99"}]}, {"result_id": "MAT", "result_responses": [{"parameter_name": "Amount", "response": "bad"}]}]'::JSONB,'P0001',NULL);
INSERT INTO financial_rejections VALUES('money reject native money conversion overflow',JSONB_BUILD_ARRAY(JSONB_BUILD_OBJECT('result_id','MAT','result_responses',JSONB_BUILD_ARRAY(JSONB_BUILD_OBJECT('parameter_name','Amount','response',REPEAT('9',131073))))),'22003',NULL);
INSERT INTO financial_rejections VALUES('money reject native aggregate overflow',JSONB_BUILD_ARRAY(JSONB_BUILD_OBJECT('result_id','MAT','result_responses',JSONB_BUILD_ARRAY(JSONB_BUILD_OBJECT('parameter_name','Amount','response',REPEAT('9',131072)))),JSONB_BUILD_OBJECT('result_id','MAT','result_responses',JSONB_BUILD_ARRAY(JSONB_BUILD_OBJECT('parameter_name','Amount','response',REPEAT('9',131072))))),'22003',('[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":0,"max":'||REPEAT('9',131072)||'}]')::JSON);
CREATE TEMP TABLE instant_cases(label TEXT PRIMARY KEY,instant TIMESTAMPTZ,zone TEXT,arrears DATE,london DATE,periods NUMERIC,state TEXT);
INSERT INTO instant_cases VALUES('instant 2027-03-31 22:59:59+00 UTC arrears 2027-01-01','2027-03-31 22:59:59+00','UTC','2027-01-01','2027-03-31',2,NULL);
INSERT INTO instant_cases VALUES('instant 2027-03-31 22:59:59+00 Pacific/Honolulu arrears 2027-01-01','2027-03-31 22:59:59+00','Pacific/Honolulu','2027-01-01','2027-03-31',2,NULL);
INSERT INTO instant_cases VALUES('instant 2027-03-31 22:59:59+00 Asia/Tokyo arrears 2027-01-01','2027-03-31 22:59:59+00','Asia/Tokyo','2027-01-01','2027-03-31',2,NULL);
INSERT INTO instant_cases VALUES('instant 2027-03-31 23:00:00+00 UTC arrears 2027-01-01','2027-03-31 23:00:00+00','UTC','2027-01-01','2027-04-01',3,NULL);
INSERT INTO instant_cases VALUES('instant 2027-03-31 23:00:00+00 Pacific/Honolulu arrears 2027-01-01','2027-03-31 23:00:00+00','Pacific/Honolulu','2027-01-01','2027-04-01',3,NULL);
INSERT INTO instant_cases VALUES('instant 2027-03-31 23:00:00+00 Asia/Tokyo arrears 2027-01-01','2027-03-31 23:00:00+00','Asia/Tokyo','2027-01-01','2027-04-01',3,NULL);
INSERT INTO instant_cases VALUES('instant 2027-03-31 23:00:01+00 UTC arrears 2027-01-01','2027-03-31 23:00:01+00','UTC','2027-01-01','2027-04-01',3,NULL);
INSERT INTO instant_cases VALUES('instant 2027-03-31 23:00:01+00 Pacific/Honolulu arrears 2027-01-01','2027-03-31 23:00:01+00','Pacific/Honolulu','2027-01-01','2027-04-01',3,NULL);
INSERT INTO instant_cases VALUES('instant 2027-03-31 23:00:01+00 Asia/Tokyo arrears 2027-01-01','2027-03-31 23:00:01+00','Asia/Tokyo','2027-01-01','2027-04-01',3,NULL);
INSERT INTO instant_cases VALUES('instant 2027-03-28 00:59:59+00 UTC arrears 2027-01-01','2027-03-28 00:59:59+00','UTC','2027-01-01','2027-03-28',2,NULL);
INSERT INTO instant_cases VALUES('instant 2027-03-28 00:59:59+00 Pacific/Honolulu arrears 2027-01-01','2027-03-28 00:59:59+00','Pacific/Honolulu','2027-01-01','2027-03-28',2,NULL);
INSERT INTO instant_cases VALUES('instant 2027-03-28 00:59:59+00 Asia/Tokyo arrears 2027-01-01','2027-03-28 00:59:59+00','Asia/Tokyo','2027-01-01','2027-03-28',2,NULL);
INSERT INTO instant_cases VALUES('instant 2027-03-28 01:00:00+00 UTC arrears 2027-01-01','2027-03-28 01:00:00+00','UTC','2027-01-01','2027-03-28',2,NULL);
INSERT INTO instant_cases VALUES('instant 2027-03-28 01:00:00+00 Pacific/Honolulu arrears 2027-01-01','2027-03-28 01:00:00+00','Pacific/Honolulu','2027-01-01','2027-03-28',2,NULL);
INSERT INTO instant_cases VALUES('instant 2027-03-28 01:00:00+00 Asia/Tokyo arrears 2027-01-01','2027-03-28 01:00:00+00','Asia/Tokyo','2027-01-01','2027-03-28',2,NULL);
INSERT INTO instant_cases VALUES('instant 2027-03-28 01:00:01+00 UTC arrears 2027-01-01','2027-03-28 01:00:01+00','UTC','2027-01-01','2027-03-28',2,NULL);
INSERT INTO instant_cases VALUES('instant 2027-03-28 01:00:01+00 Pacific/Honolulu arrears 2027-01-01','2027-03-28 01:00:01+00','Pacific/Honolulu','2027-01-01','2027-03-28',2,NULL);
INSERT INTO instant_cases VALUES('instant 2027-03-28 01:00:01+00 Asia/Tokyo arrears 2027-01-01','2027-03-28 01:00:01+00','Asia/Tokyo','2027-01-01','2027-03-28',2,NULL);
INSERT INTO instant_cases VALUES('instant 2027-10-31 00:30:00+00 UTC arrears 2027-01-01','2027-10-31 00:30:00+00','UTC','2027-01-01','2027-10-31',9,NULL);
INSERT INTO instant_cases VALUES('instant 2027-10-31 00:30:00+00 Pacific/Honolulu arrears 2027-01-01','2027-10-31 00:30:00+00','Pacific/Honolulu','2027-01-01','2027-10-31',9,NULL);
INSERT INTO instant_cases VALUES('instant 2027-10-31 00:30:00+00 Asia/Tokyo arrears 2027-01-01','2027-10-31 00:30:00+00','Asia/Tokyo','2027-01-01','2027-10-31',9,NULL);
INSERT INTO instant_cases VALUES('instant 2027-10-31 01:30:00+00 UTC arrears 2027-01-01','2027-10-31 01:30:00+00','UTC','2027-01-01','2027-10-31',9,NULL);
INSERT INTO instant_cases VALUES('instant 2027-10-31 01:30:00+00 Pacific/Honolulu arrears 2027-01-01','2027-10-31 01:30:00+00','Pacific/Honolulu','2027-01-01','2027-10-31',9,NULL);
INSERT INTO instant_cases VALUES('instant 2027-10-31 01:30:00+00 Asia/Tokyo arrears 2027-01-01','2027-10-31 01:30:00+00','Asia/Tokyo','2027-01-01','2027-10-31',9,NULL);
INSERT INTO instant_cases VALUES('instant 2027-10-31 00:59:59+00 UTC arrears 2027-01-01','2027-10-31 00:59:59+00','UTC','2027-01-01','2027-10-31',9,NULL);
INSERT INTO instant_cases VALUES('instant 2027-10-31 00:59:59+00 Pacific/Honolulu arrears 2027-01-01','2027-10-31 00:59:59+00','Pacific/Honolulu','2027-01-01','2027-10-31',9,NULL);
INSERT INTO instant_cases VALUES('instant 2027-10-31 00:59:59+00 Asia/Tokyo arrears 2027-01-01','2027-10-31 00:59:59+00','Asia/Tokyo','2027-01-01','2027-10-31',9,NULL);
INSERT INTO instant_cases VALUES('instant 2027-10-31 01:00:00+00 UTC arrears 2027-01-01','2027-10-31 01:00:00+00','UTC','2027-01-01','2027-10-31',9,NULL);
INSERT INTO instant_cases VALUES('instant 2027-10-31 01:00:00+00 Pacific/Honolulu arrears 2027-01-01','2027-10-31 01:00:00+00','Pacific/Honolulu','2027-01-01','2027-10-31',9,NULL);
INSERT INTO instant_cases VALUES('instant 2027-10-31 01:00:00+00 Asia/Tokyo arrears 2027-01-01','2027-10-31 01:00:00+00','Asia/Tokyo','2027-01-01','2027-10-31',9,NULL);
INSERT INTO instant_cases VALUES('instant 2027-10-31 01:00:01+00 UTC arrears 2027-01-01','2027-10-31 01:00:01+00','UTC','2027-01-01','2027-10-31',9,NULL);
INSERT INTO instant_cases VALUES('instant 2027-10-31 01:00:01+00 Pacific/Honolulu arrears 2027-01-01','2027-10-31 01:00:01+00','Pacific/Honolulu','2027-01-01','2027-10-31',9,NULL);
INSERT INTO instant_cases VALUES('instant 2027-10-31 01:00:01+00 Asia/Tokyo arrears 2027-01-01','2027-10-31 01:00:01+00','Asia/Tokyo','2027-01-01','2027-10-31',9,NULL);
INSERT INTO instant_cases VALUES('instant 2027-03-31 23:30:00+00 UTC arrears 2027-03-31','2027-03-31 23:30:00+00','UTC','2027-03-31','2027-04-01',0,NULL);
INSERT INTO instant_cases VALUES('instant 2027-03-31 23:30:00+00 Pacific/Honolulu arrears 2027-03-31','2027-03-31 23:30:00+00','Pacific/Honolulu','2027-03-31','2027-04-01',0,NULL);
INSERT INTO instant_cases VALUES('instant 2027-03-31 23:30:00+00 Asia/Tokyo arrears 2027-03-31','2027-03-31 23:30:00+00','Asia/Tokyo','2027-03-31','2027-04-01',0,NULL);
INSERT INTO instant_cases VALUES('instant 2027-03-31 23:30:00+00 UTC arrears 2027-04-01','2027-03-31 23:30:00+00','UTC','2027-04-01','2027-04-01',0,NULL);
INSERT INTO instant_cases VALUES('instant 2027-03-31 23:30:00+00 Pacific/Honolulu arrears 2027-04-01','2027-03-31 23:30:00+00','Pacific/Honolulu','2027-04-01','2027-04-01',0,NULL);
INSERT INTO instant_cases VALUES('instant 2027-03-31 23:30:00+00 Asia/Tokyo arrears 2027-04-01','2027-03-31 23:30:00+00','Asia/Tokyo','2027-04-01','2027-04-01',0,NULL);
INSERT INTO instant_cases VALUES('instant 2027-03-31 23:30:00+00 UTC arrears 2027-04-02','2027-03-31 23:30:00+00','UTC','2027-04-02','2027-04-01',NULL,'P0001');
INSERT INTO instant_cases VALUES('instant 2027-03-31 23:30:00+00 Pacific/Honolulu arrears 2027-04-02','2027-03-31 23:30:00+00','Pacific/Honolulu','2027-04-02','2027-04-01',NULL,'P0001');
INSERT INTO instant_cases VALUES('instant 2027-03-31 23:30:00+00 Asia/Tokyo arrears 2027-04-02','2027-03-31 23:30:00+00','Asia/Tokyo','2027-04-02','2027-04-01',NULL,'P0001');
CREATE TEMP TABLE configuration_cases(label TEXT PRIMARY KEY,name TEXT,action TEXT,value TEXT,multi_values JSON,state TEXT,expected SMALLINT);
INSERT INTO configuration_cases VALUES('config DEFAULT_CHEQUE_CLEARANCE_PERIOD changed','DEFAULT_CHEQUE_CLEARANCE_PERIOD','value','14',NULL::JSON,NULL,14);
INSERT INTO configuration_cases VALUES('config DEFAULT_CHEQUE_CLEARANCE_PERIOD zero','DEFAULT_CHEQUE_CLEARANCE_PERIOD','value','0',NULL::JSON,NULL,0);
INSERT INTO configuration_cases VALUES('config DEFAULT_CHEQUE_CLEARANCE_PERIOD native plus','DEFAULT_CHEQUE_CLEARANCE_PERIOD','value','+12',NULL::JSON,NULL,12);
INSERT INTO configuration_cases VALUES('config DEFAULT_CHEQUE_CLEARANCE_PERIOD native whitespace','DEFAULT_CHEQUE_CLEARANCE_PERIOD','value',' 	12
',NULL::JSON,NULL,12);
INSERT INTO configuration_cases VALUES('config DEFAULT_CHEQUE_CLEARANCE_PERIOD native leading zeros','DEFAULT_CHEQUE_CLEARANCE_PERIOD','value','0012',NULL::JSON,NULL,12);
INSERT INTO configuration_cases VALUES('config DEFAULT_CHEQUE_CLEARANCE_PERIOD native maximum','DEFAULT_CHEQUE_CLEARANCE_PERIOD','value','32767',NULL::JSON,NULL,32767);
INSERT INTO configuration_cases VALUES('config DEFAULT_CHEQUE_CLEARANCE_PERIOD missing global valid scoped','DEFAULT_CHEQUE_CLEARANCE_PERIOD','missing','12',NULL::JSON,'P0002',NULL);
INSERT INTO configuration_cases VALUES('config DEFAULT_CHEQUE_CLEARANCE_PERIOD SQL NULL value','DEFAULT_CHEQUE_CLEARANCE_PERIOD','value',NULL,NULL::JSON,'P0001',NULL);
INSERT INTO configuration_cases VALUES('config DEFAULT_CHEQUE_CLEARANCE_PERIOD invalid text','DEFAULT_CHEQUE_CLEARANCE_PERIOD','value','abc',NULL::JSON,'22P02',NULL);
INSERT INTO configuration_cases VALUES('config DEFAULT_CHEQUE_CLEARANCE_PERIOD empty text','DEFAULT_CHEQUE_CLEARANCE_PERIOD','value','',NULL::JSON,'22P02',NULL);
INSERT INTO configuration_cases VALUES('config DEFAULT_CHEQUE_CLEARANCE_PERIOD positive overflow','DEFAULT_CHEQUE_CLEARANCE_PERIOD','value','32768',NULL::JSON,'22003',NULL);
INSERT INTO configuration_cases VALUES('config DEFAULT_CHEQUE_CLEARANCE_PERIOD negative overflow','DEFAULT_CHEQUE_CLEARANCE_PERIOD','value','-32769',NULL::JSON,'22003',NULL);
INSERT INTO configuration_cases VALUES('config DEFAULT_CHEQUE_CLEARANCE_PERIOD negative','DEFAULT_CHEQUE_CLEARANCE_PERIOD','value','-1',NULL::JSON,'P0001',NULL);
INSERT INTO configuration_cases VALUES('config DEFAULT_CHEQUE_CLEARANCE_PERIOD conflicting JSON null','DEFAULT_CHEQUE_CLEARANCE_PERIOD','values','12','null'::JSON,'P0001',NULL);
INSERT INTO configuration_cases VALUES('config DEFAULT_CHEQUE_CLEARANCE_PERIOD conflicting empty array','DEFAULT_CHEQUE_CLEARANCE_PERIOD','values','12','[]'::JSON,'P0001',NULL);
INSERT INTO configuration_cases VALUES('config DEFAULT_CHEQUE_CLEARANCE_PERIOD conflicting empty object','DEFAULT_CHEQUE_CLEARANCE_PERIOD','values','12','{}'::JSON,'P0001',NULL);
INSERT INTO configuration_cases VALUES('config DEFAULT_CHEQUE_CLEARANCE_PERIOD conflicting empty string','DEFAULT_CHEQUE_CLEARANCE_PERIOD','values','12','""'::JSON,'P0001',NULL);
INSERT INTO configuration_cases VALUES('config DEFAULT_CHEQUE_CLEARANCE_PERIOD conflicting string','DEFAULT_CHEQUE_CLEARANCE_PERIOD','values','12','"x"'::JSON,'P0001',NULL);
INSERT INTO configuration_cases VALUES('config DEFAULT_CHEQUE_CLEARANCE_PERIOD conflicting number','DEFAULT_CHEQUE_CLEARANCE_PERIOD','values','12','1'::JSON,'P0001',NULL);
INSERT INTO configuration_cases VALUES('config DEFAULT_CHEQUE_CLEARANCE_PERIOD conflicting boolean','DEFAULT_CHEQUE_CLEARANCE_PERIOD','values','12','true'::JSON,'P0001',NULL);
INSERT INTO configuration_cases VALUES('config DEFAULT_CHEQUE_CLEARANCE_PERIOD conflicting nonempty array','DEFAULT_CHEQUE_CLEARANCE_PERIOD','values','12','[1]'::JSON,'P0001',NULL);
INSERT INTO configuration_cases VALUES('config DEFAULT_CHEQUE_CLEARANCE_PERIOD conflicting nonempty object','DEFAULT_CHEQUE_CLEARANCE_PERIOD','values','12','{"x":1}'::JSON,'P0001',NULL);
INSERT INTO configuration_cases VALUES('config DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD changed','DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD','value','3',NULL::JSON,NULL,3);
INSERT INTO configuration_cases VALUES('config DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD zero','DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD','value','0',NULL::JSON,NULL,0);
INSERT INTO configuration_cases VALUES('config DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD native plus','DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD','value','+12',NULL::JSON,NULL,12);
INSERT INTO configuration_cases VALUES('config DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD native whitespace','DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD','value',' 	12
',NULL::JSON,NULL,12);
INSERT INTO configuration_cases VALUES('config DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD native leading zeros','DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD','value','0012',NULL::JSON,NULL,12);
INSERT INTO configuration_cases VALUES('config DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD native maximum','DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD','value','32767',NULL::JSON,NULL,32767);
INSERT INTO configuration_cases VALUES('config DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD missing global valid scoped','DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD','missing','12',NULL::JSON,'P0002',NULL);
INSERT INTO configuration_cases VALUES('config DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD SQL NULL value','DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD','value',NULL,NULL::JSON,'P0001',NULL);
INSERT INTO configuration_cases VALUES('config DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD invalid text','DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD','value','abc',NULL::JSON,'22P02',NULL);
INSERT INTO configuration_cases VALUES('config DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD empty text','DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD','value','',NULL::JSON,'22P02',NULL);
INSERT INTO configuration_cases VALUES('config DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD positive overflow','DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD','value','32768',NULL::JSON,'22003',NULL);
INSERT INTO configuration_cases VALUES('config DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD negative overflow','DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD','value','-32769',NULL::JSON,'22003',NULL);
INSERT INTO configuration_cases VALUES('config DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD negative','DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD','value','-1',NULL::JSON,'P0001',NULL);
INSERT INTO configuration_cases VALUES('config DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD conflicting JSON null','DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD','values','12','null'::JSON,'P0001',NULL);
INSERT INTO configuration_cases VALUES('config DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD conflicting empty array','DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD','values','12','[]'::JSON,'P0001',NULL);
INSERT INTO configuration_cases VALUES('config DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD conflicting empty object','DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD','values','12','{}'::JSON,'P0001',NULL);
INSERT INTO configuration_cases VALUES('config DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD conflicting empty string','DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD','values','12','""'::JSON,'P0001',NULL);
INSERT INTO configuration_cases VALUES('config DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD conflicting string','DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD','values','12','"x"'::JSON,'P0001',NULL);
INSERT INTO configuration_cases VALUES('config DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD conflicting number','DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD','values','12','1'::JSON,'P0001',NULL);
INSERT INTO configuration_cases VALUES('config DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD conflicting boolean','DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD','values','12','true'::JSON,'P0001',NULL);
INSERT INTO configuration_cases VALUES('config DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD conflicting nonempty array','DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD','values','12','[1]'::JSON,'P0001',NULL);
INSERT INTO configuration_cases VALUES('config DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD conflicting nonempty object','DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD','values','12','{"x":1}'::JSON,'P0001',NULL);

SELECT CURRENT_SETTING('search_path') AS path,CURRENT_SETTING('TimeZone') AS zone \gset financial_before_
SAVEPOINT financial_scope;
CREATE SCHEMA opal_po10650_financial_clock;
CREATE SEQUENCE opal_po10650_financial_clock.capture_count START 1;
CREATE TABLE opal_po10650_financial_clock.state(instant TIMESTAMPTZ NOT NULL,wall_marker TIMESTAMPTZ);
INSERT INTO opal_po10650_financial_clock.state VALUES(TIMESTAMPTZ '2027-03-01 12:00:00+00',NULL);
CREATE FUNCTION opal_po10650_financial_clock.transaction_timestamp() RETURNS TIMESTAMPTZ
LANGUAGE plpgsql VOLATILE AS $fixed$
DECLARE value TIMESTAMPTZ;
BEGIN
 PERFORM pg_catalog.NEXTVAL('opal_po10650_financial_clock.capture_count'::REGCLASS);
 SELECT instant INTO STRICT value FROM opal_po10650_financial_clock.state;
 RETURN value;
END;
$fixed$;
SET LOCAL search_path=opal_po10650_financial_clock,pg_catalog,public;
DO $financial_cases$
DECLARE c RECORD; payload JSONB; result JSONB; account public.respondent_accounts%ROWTYPE;
 checks JSONB; output JSONB; state TEXT; constraint_name TEXT; before_calls BIGINT;
BEGIN
 FOR c IN SELECT * FROM calendar_cases ORDER BY frequency,arrears,publication LOOP
  UPDATE opal_po10650_financial_clock.state SET instant=(c.publication::TIMESTAMP+INTERVAL '12 hours') AT TIME ZONE 'UTC';
  payload:=JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,payment_period}',TO_JSONB(c.frequency));
  payload:=JSONB_SET(payload,'{order_details,date_arrears_last_updated}',TO_JSONB(c.arrears::TEXT));
  payload:=JSONB_SET(payload,'{order_details,order_terms,0,result_responses,0,response}','"1"');
  INSERT INTO financial_observations VALUES(FORMAT('calendar %s %s %s',c.frequency,c.arrears,c.publication),
   pg_temp.financial_observation(payload::JSON,1,0,c.periods,c.publication::TIMESTAMP+INTERVAL '12 hours',
    FORMAT('calendar %s %s %s',c.frequency,c.arrears,c.publication)));
 END LOOP;
 FOR c IN SELECT * FROM monetary_cases ORDER BY label LOOP
  BEGIN
   UPDATE opal_po10650_financial_clock.state SET instant=c.instant;
   IF c.metadata IS NOT NULL THEN UPDATE public.results SET result_parameters=c.metadata WHERE result_id='MAT'; END IF;
   payload:=JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_arrears_last_updated}',TO_JSONB(c.arrears_date::TEXT));
   payload:=JSONB_SET(payload,'{order_details,order_terms}',c.terms);
   result:=pg_temp.financial_observation(payload::JSON,c.amount,c.arrears,c.balance,c.instant AT TIME ZONE 'UTC',c.label);
   RAISE EXCEPTION SQLSTATE 'ZX653' USING MESSAGE='rollback isolated financial fixture';
  EXCEPTION WHEN SQLSTATE 'ZX653' THEN NULL;
  END;
  INSERT INTO financial_observations VALUES(c.label,result);
 END LOOP;
 UPDATE opal_po10650_financial_clock.state SET instant=TIMESTAMPTZ '2027-03-01 12:00:00+00';
 FOR c IN SELECT * FROM financial_rejections ORDER BY label LOOP
  BEGIN
   IF c.metadata IS NOT NULL THEN UPDATE public.results SET result_parameters=c.metadata WHERE result_id='MAT'; END IF;
   payload:=JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_arrears_last_updated}','"2027-01-01"');
   payload:=JSONB_SET(payload,'{order_details,order_terms}',c.terms);
   result:=pg_temp.financial_rejection(payload::JSON,c.state,c.label);
   RAISE EXCEPTION SQLSTATE 'ZX653' USING MESSAGE='rollback isolated financial fixture';
  EXCEPTION WHEN SQLSTATE 'ZX653' THEN NULL;
  END;
  INSERT INTO financial_observations VALUES(c.label,result);
 END LOOP;
 FOR c IN SELECT * FROM instant_cases ORDER BY label LOOP
  PERFORM SET_CONFIG('TimeZone',c.zone,true);
  UPDATE opal_po10650_financial_clock.state SET instant=c.instant;
  payload:=JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_arrears_last_updated}',TO_JSONB(c.arrears::TEXT));
  payload:=JSONB_SET(payload,'{order_details,order_terms,0,result_responses,0,response}','"1"');
  IF c.state IS NULL THEN
   result:=pg_temp.financial_observation(payload::JSON,1,0,c.periods,c.instant AT TIME ZONE 'UTC',c.label);
   -- An eligibility window pinned to the independent expected London date
   -- distinguishes local publication dates even when period counts coincide.
   BEGIN
    UPDATE public.maintenance_applications SET date_used_from=c.london,date_used_to=c.london WHERE application_code='P10650';
    output:=pg_temp.invoke_account(payload::JSON);
    RAISE EXCEPTION SQLSTATE 'ZX653' USING MESSAGE='rollback isolated financial fixture';
   EXCEPTION WHEN SQLSTATE 'ZX653' THEN NULL;
   END;
   result:=result||JSONB_BUILD_ARRAY(JSONB_BUILD_OBJECT('pass',output->>'id' IS NOT NULL,
    'description',c.label||': independent London-date Application window accepts'));
  ELSE result:=pg_temp.financial_rejection(payload::JSON,c.state,c.label);
  END IF;
  INSERT INTO financial_observations VALUES(c.label,result);
 END LOOP;
 PERFORM SET_CONFIG('TimeZone','UTC',true);
 UPDATE opal_po10650_financial_clock.state SET instant=TIMESTAMPTZ '2027-03-01 12:00:00+00';
 FOR c IN SELECT * FROM configuration_cases ORDER BY label LOOP
  BEGIN
   IF c.action='missing' THEN
    DELETE FROM public.configuration_items WHERE item_name=c.name AND business_unit_id IS NULL;
    INSERT INTO public.configuration_items(item_name,business_unit_id,item_value,item_values) VALUES(c.name,31850,'12',NULL);
   ELSE
    UPDATE public.configuration_items SET item_value=c.value,item_values=c.multi_values
     WHERE item_name=c.name AND business_unit_id IS NULL;
   END IF;
   payload:=JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_arrears_last_updated}','"2027-01-01"');
   payload:=JSONB_SET(payload,'{order_details,order_terms,0,result_responses,0,response}','"1"');
   IF c.state IS NULL THEN
    result:=pg_temp.financial_observation(payload::JSON,1,0,2,TIMESTAMP '2027-03-01 12:00:00',c.label);
    SELECT a.* INTO STRICT account FROM public.respondent_accounts a JOIN financial_outputs f
     ON a.respondent_account_id=(f.output->>'id')::BIGINT WHERE f.label=c.label;
    result:=result||JSONB_BUILD_ARRAY(JSONB_BUILD_OBJECT('pass',
     account.cheque_clearance_period=CASE WHEN c.name='DEFAULT_CHEQUE_CLEARANCE_PERIOD' THEN c.expected ELSE 13 END
     AND account.credit_trans_clearance_period=CASE WHEN c.name='DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD' THEN c.expected ELSE 7 END,
     'description',c.label||': configured integer persisted and other setting preserved'));
   ELSE result:=pg_temp.financial_rejection(payload::JSON,c.state,c.label);
   END IF;
   RAISE EXCEPTION SQLSTATE 'ZX653' USING MESSAGE='rollback isolated financial fixture';
  EXCEPTION WHEN SQLSTATE 'ZX653' THEN NULL;
  END;
  INSERT INTO financial_observations VALUES(c.label,result);
 END LOOP;
 -- Both global changes and both zeros must coexist successfully.
 FOR c IN SELECT * FROM (VALUES('config both changed',14,3),('config both zero',0,0)) v(label,cheque,credit) LOOP
  BEGIN
   UPDATE public.configuration_items SET item_value=CASE item_name WHEN 'DEFAULT_CHEQUE_CLEARANCE_PERIOD' THEN c.cheque::TEXT ELSE c.credit::TEXT END,item_values=NULL
   WHERE business_unit_id IS NULL AND item_name IN ('DEFAULT_CHEQUE_CLEARANCE_PERIOD','DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD');
   payload:=JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_arrears_last_updated}','"2027-01-01"');
   payload:=JSONB_SET(payload,'{order_details,order_terms,0,result_responses,0,response}','"1"');
   result:=pg_temp.financial_observation(payload::JSON,1,0,2,TIMESTAMP '2027-03-01 12:00:00',c.label);
   SELECT a.* INTO STRICT account FROM public.respondent_accounts a JOIN financial_outputs f
     ON a.respondent_account_id=(f.output->>'id')::BIGINT WHERE f.label=c.label;
   result:=result||JSONB_BUILD_ARRAY(JSONB_BUILD_OBJECT('pass',account.cheque_clearance_period=c.cheque AND account.credit_trans_clearance_period=c.credit,
    'description',c.label||': both configured values persist'));
   RAISE EXCEPTION SQLSTATE 'ZX653' USING MESSAGE='rollback isolated financial fixture';
  EXCEPTION WHEN SQLSTATE 'ZX653' THEN NULL;
  END;
  INSERT INTO financial_observations VALUES(c.label,result);
 END LOOP;
 -- Ordinary ambiguity is impossible: observe native uniqueness, never drop it.
 FOR c IN SELECT UNNEST(ARRAY['DEFAULT_CHEQUE_CLEARANCE_PERIOD','DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD']) AS name LOOP
  state:=NULL; constraint_name:=NULL; before_calls:=pg_temp.allocator_calls();
  BEGIN
   INSERT INTO public.configuration_items(item_name,business_unit_id,item_value) VALUES(c.name,NULL,'1');
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS state=RETURNED_SQLSTATE,constraint_name=CONSTRAINT_NAME;
  END;
  INSERT INTO financial_observations VALUES('config uniqueness '||c.name,JSONB_BUILD_ARRAY(
   JSONB_BUILD_OBJECT('pass',state='23505','description','config uniqueness '||c.name||': native duplicate global SQLSTATE'),
   JSONB_BUILD_OBJECT('pass',constraint_name='configuration_items_item_name_business_unit_id_uk',
    'description','config uniqueness '||c.name||': native global uniqueness identity'),
   JSONB_BUILD_OBJECT('pass',pg_temp.allocator_calls()=before_calls,'description','config uniqueness '||c.name||': no allocator work')));
 END LOOP;
END;
$financial_cases$;

DO $lifetime$ DECLARE c RECORD; payload JSONB; result JSONB; BEGIN
UPDATE opal_po10650_financial_clock.state SET instant='2027-03-31 22:59:59+00'::TIMESTAMPTZ,wall_marker='2027-03-31 22:59:59+00'::TIMESTAMPTZ;
payload:=JSONB_SET(JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_arrears_last_updated}','"2027-01-01"'),'{order_details,order_terms,0,result_responses,0,response}','"1"');
INSERT INTO financial_observations VALUES('lifetime midnight wall before',pg_temp.financial_observation(payload::JSON,1,0,2,'2027-03-31 22:59:59'::TIMESTAMP,'lifetime midnight wall before'));
UPDATE opal_po10650_financial_clock.state SET instant='2027-03-31 22:59:59+00'::TIMESTAMPTZ,wall_marker='2027-03-31 23:00:01+00'::TIMESTAMPTZ;
payload:=JSONB_SET(JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_arrears_last_updated}','"2027-01-01"'),'{order_details,order_terms,0,result_responses,0,response}','"1"');
INSERT INTO financial_observations VALUES('lifetime midnight wall after',pg_temp.financial_observation(payload::JSON,1,0,2,'2027-03-31 22:59:59'::TIMESTAMP,'lifetime midnight wall after'));
UPDATE opal_po10650_financial_clock.state SET instant='2027-03-28 00:59:59+00'::TIMESTAMPTZ,wall_marker='2027-03-28 00:59:59+00'::TIMESTAMPTZ;
payload:=JSONB_SET(JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_arrears_last_updated}','"2027-01-01"'),'{order_details,order_terms,0,result_responses,0,response}','"1"');
INSERT INTO financial_observations VALUES('lifetime spring wall before',pg_temp.financial_observation(payload::JSON,1,0,2,'2027-03-28 00:59:59'::TIMESTAMP,'lifetime spring wall before'));
UPDATE opal_po10650_financial_clock.state SET instant='2027-03-28 00:59:59+00'::TIMESTAMPTZ,wall_marker='2027-03-28 01:00:01+00'::TIMESTAMPTZ;
payload:=JSONB_SET(JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_arrears_last_updated}','"2027-01-01"'),'{order_details,order_terms,0,result_responses,0,response}','"1"');
INSERT INTO financial_observations VALUES('lifetime spring wall after',pg_temp.financial_observation(payload::JSON,1,0,2,'2027-03-28 00:59:59'::TIMESTAMP,'lifetime spring wall after'));
UPDATE opal_po10650_financial_clock.state SET instant='2027-10-31 00:59:59+00'::TIMESTAMPTZ,wall_marker='2027-10-31 00:59:59+00'::TIMESTAMPTZ;
payload:=JSONB_SET(JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_arrears_last_updated}','"2027-01-01"'),'{order_details,order_terms,0,result_responses,0,response}','"1"');
INSERT INTO financial_observations VALUES('lifetime autumn wall before',pg_temp.financial_observation(payload::JSON,1,0,9,'2027-10-31 00:59:59'::TIMESTAMP,'lifetime autumn wall before'));
UPDATE opal_po10650_financial_clock.state SET instant='2027-10-31 00:59:59+00'::TIMESTAMPTZ,wall_marker='2027-10-31 01:00:01+00'::TIMESTAMPTZ;
payload:=JSONB_SET(JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_arrears_last_updated}','"2027-01-01"'),'{order_details,order_terms,0,result_responses,0,response}','"1"');
INSERT INTO financial_observations VALUES('lifetime autumn wall after',pg_temp.financial_observation(payload::JSON,1,0,9,'2027-10-31 00:59:59'::TIMESTAMP,'lifetime autumn wall after'));
END; $lifetime$;

SET LOCAL search_path=public,pg_catalog;
SELECT pg_catalog.TRANSACTION_TIMESTAMP() AS instant \gset lifetime_native_
DO $native_lifetime$
DECLARE output JSONB; account public.respondent_accounts%ROWTYPE; c RECORD; before_capture BIGINT;
 after_capture BIGINT; before_calls BIGINT; result JSONB; actual_instant TIMESTAMPTZ:=pg_catalog.TRANSACTION_TIMESTAMP();
BEGIN
 FOR c IN SELECT * FROM (VALUES('native lifetime before delay','UTC'),('native lifetime after delay','Asia/Tokyo'),
  ('native lifetime changed zone','Pacific/Honolulu')) v(label,zone) LOOP
  PERFORM pg_catalog.PG_SLEEP(0.02);
  PERFORM SET_CONFIG('TimeZone',c.zone,true);
  SELECT CASE WHEN is_called THEN last_value ELSE 0 END INTO before_capture FROM opal_po10650_financial_clock.capture_count;
  before_calls:=pg_temp.allocator_calls();
  output:=pg_temp.invoke_account(pg_temp.account_payload());
  SELECT * INTO STRICT account FROM public.respondent_accounts WHERE respondent_account_id=(output->>'id')::BIGINT;
  SELECT CASE WHEN is_called THEN last_value ELSE 0 END INTO after_capture FROM opal_po10650_financial_clock.capture_count;
  result:=JSONB_BUILD_ARRAY(
   JSONB_BUILD_OBJECT('pass',account.last_movement_date=actual_instant AT TIME ZONE 'UTC',
    'description',c.label||': exact native transaction-start UTC despite delay/zone'),
   JSONB_BUILD_OBJECT('pass',pg_catalog.TRANSACTION_TIMESTAMP()=actual_instant,
    'description',c.label||': native reference remains constant in caller transaction'),
   JSONB_BUILD_OBJECT('pass',account.imposed_hearing_date=TIMESTAMP '2024-01-01' AND account.date_arrears_last_updated=TIMESTAMP '2024-01-01',
    'description',c.label||': supplied calendar midnights unchanged'),
   JSONB_BUILD_OBJECT('pass',after_capture=before_capture AND pg_temp.allocator_calls()-before_calls=1,
    'description',c.label||': native binding bypasses fake counter and allocates once'),
   JSONB_BUILD_OBJECT('pass',account.account_number=output->>'number' AND EXISTS(SELECT 1 FROM public.account_number_index n
    WHERE n.business_unit_id=account.business_unit_id AND n.account_number=account.account_number AND n.associated_record_type='respondent_accounts'),
    'description',c.label||': native row and both outputs/reservation agree'));
  INSERT INTO financial_observations VALUES(c.label,result);
 END LOOP;
END;
$native_lifetime$;
SET LOCAL search_path=opal_po10650_financial_clock,pg_catalog,public;
SET LOCAL TIME ZONE 'UTC';
UPDATE opal_po10650_financial_clock.state SET instant=TIMESTAMPTZ '2027-05-01 12:00:00+00';
INSERT INTO financial_observations VALUES('lifetime fixed after native and cached calls',pg_temp.financial_observation(
 JSONB_SET(JSONB_SET(pg_temp.account_payload()::JSONB,'{order_details,date_arrears_last_updated}','"2027-01-01"'),
 '{order_details,order_terms,0,result_responses,0,response}','"1"')::JSON,1,0,4,TIMESTAMP '2027-05-01 12:00:00',
 'lifetime fixed after native and cached calls'));

-- Fixed fixture/observation totals prevent missing-row and NULL vacuity.
SELECT COUNT(*)=246 AND COUNT(*) FILTER(WHERE checks IS NOT NULL)=246
 AND (SELECT COUNT(*) FROM calendar_cases)=69
 AND (SELECT COUNT(*) FROM monetary_cases)=21
 AND (SELECT COUNT(*) FROM financial_rejections)=56
 AND (SELECT COUNT(*) FROM instant_cases)=42
 AND (SELECT COUNT(*) FROM configuration_cases)=44
 AS complete,
 SUM(JSONB_ARRAY_LENGTH(checks))=1852 AS check_count,
 BOOL_AND(NOT EXISTS(SELECT 1 FROM JSONB_ARRAY_ELEMENTS(checks) v WHERE v->>'pass' IS NULL OR v->>'description' IS NULL)) AS nonnull
FROM financial_observations \gset financial_
SELECT JSONB_AGG(checks ORDER BY label) AS results FROM financial_observations \gset financial_
ROLLBACK TO SAVEPOINT financial_scope;
RELEASE SAVEPOINT financial_scope;
SELECT ok((check_result->>'pass')::BOOLEAN,check_result->>'description')
FROM JSONB_ARRAY_ELEMENTS(:'financial_results'::JSONB) observations(checks)
CROSS JOIN LATERAL JSONB_ARRAY_ELEMENTS(observations.checks) checks(check_result);
SELECT ok(:'financial_complete'::BOOLEAN,'financial matrix has every fixed literal fixture observation');
SELECT ok(:'financial_check_count'::BOOLEAN,'financial matrix has the exact fixed observation-check count');
SELECT ok(:'financial_nonnull'::BOOLEAN,'financial matrix contains no missing Boolean or description');
SELECT ok(TO_REGNAMESPACE('opal_po10650_financial_clock') IS NULL,'financial rollback removes clock schema and all contained state');
SELECT is(CURRENT_SETTING('search_path'),:'financial_before_path','financial rollback restores original search_path');
SELECT is(CURRENT_SETTING('TimeZone'),:'financial_before_zone','financial rollback restores original TimeZone');
SELECT ok(NOT EXISTS(
 SELECT 1 FROM routine_before b JOIN pg_proc p ON p.oid=b.oid
 WHERE ROW(PG_GET_FUNCTIONDEF(p.oid),p.proconfig,p.proowner,p.proacl,p.prosecdef)
 IS DISTINCT FROM ROW(b.definition,b.proconfig,b.proowner,b.proacl,b.prosecdef)),
 'financial fixed/native/cached transitions preserve installed routine definition and properties');

-- ---------------------------------------------------------------------------
-- Scenario: Native insertion errors and exceptional control flow retain diagnostics.
-- Setup:    Real CALLs; isolated test triggers roll back before assertions execute.
-- Expected: No successful OUT result or surviving write; exact native diagnostics.
-- ---------------------------------------------------------------------------
CREATE FUNCTION pg_temp.account_row_scope() RETURNS JSONB LANGUAGE plpgsql AS $scope$
DECLARE table_name TEXT; rows TEXT[]; observation JSONB := '{}'::JSONB;
BEGIN
 FOREACH table_name IN ARRAY ARRAY['business_units','respondent_accounts','account_number_index',
  'parties','order_terms','notes','respondent_account_parties','creditor_accounts','major_creditors',
  'draft_casefiles','debtor_detail','third_party_contact','results','maintenance_applications','configuration_items'] LOOP
  EXECUTE FORMAT('SELECT COALESCE(ARRAY_AGG(ROW_TO_JSON(r)::TEXT ORDER BY ROW_TO_JSON(r)::TEXT),ARRAY[]::TEXT[]) FROM public.%I r',table_name) INTO rows;
  observation:=observation||JSONB_BUILD_OBJECT(table_name,rows);
 END LOOP;
 RETURN observation;
END;
$scope$;
CREATE FUNCTION pg_temp.account_metadata() RETURNS JSONB LANGUAGE SQL AS $metadata$
 SELECT JSONB_BUILD_OBJECT(
 'routines',(SELECT JSONB_AGG(JSONB_BUILD_ARRAY(p.oid,PG_GET_FUNCTIONDEF(p.oid),p.proowner,p.proacl,p.proconfig,p.prosecdef) ORDER BY p.oid)
 FROM pg_proc p WHERE p.oid IN (
 'public.p_insert_respondent_account(smallint,public.t_casefile_type_enum,json,bigint,bigint)'::REGPROCEDURE,
 'public.f_get_account_number(smallint,public.t_associated_record_type_enum)'::REGPROCEDURE,
 'public.f_get_check_letter(character varying)'::REGPROCEDURE)),
 'tables',(SELECT JSONB_AGG(JSONB_BUILD_ARRAY(c.oid,c.relowner,c.relacl,c.relrowsecurity,c.relforcerowsecurity) ORDER BY c.oid)
 FROM pg_class c WHERE c.oid IN ('public.respondent_accounts'::REGCLASS,'public.account_number_index'::REGCLASS)),
 'columns',(SELECT JSONB_AGG(JSONB_BUILD_ARRAY(a.attrelid,a.attnum,a.attname,a.atttypid,a.atttypmod,a.attnotnull,a.attacl,
 PG_GET_EXPR(d.adbin,d.adrelid),COL_DESCRIPTION(a.attrelid,a.attnum)) ORDER BY a.attrelid,a.attnum)
 FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum
 WHERE a.attrelid IN ('public.respondent_accounts'::REGCLASS,'public.account_number_index'::REGCLASS) AND a.attnum>0 AND NOT a.attisdropped),
 'constraints',(SELECT JSONB_AGG(JSONB_BUILD_ARRAY(c.oid,c.conname,c.convalidated,PG_GET_CONSTRAINTDEF(c.oid)) ORDER BY c.oid)
 FROM pg_constraint c WHERE c.conrelid IN ('public.respondent_accounts'::REGCLASS,'public.account_number_index'::REGCLASS)),
 'indexes',(SELECT JSONB_AGG(JSONB_BUILD_ARRAY(i.indexrelid,PG_GET_INDEXDEF(i.indexrelid),i.indisvalid,i.indisready) ORDER BY i.indexrelid)
 FROM pg_index i WHERE i.indrelid IN ('public.respondent_accounts'::REGCLASS,'public.account_number_index'::REGCLASS)),
 'triggers',(SELECT JSONB_AGG(JSONB_BUILD_ARRAY(t.oid,PG_GET_TRIGGERDEF(t.oid),t.tgenabled) ORDER BY t.oid)
 FROM pg_trigger t WHERE t.tgrelid IN ('public.respondent_accounts'::REGCLASS,'public.account_number_index'::REGCLASS)))
$metadata$;
CREATE TEMP TABLE atomicity_before AS SELECT pg_temp.account_metadata() AS metadata;
CREATE TEMP TABLE native_cases(label TEXT PRIMARY KEY, state TEXT, constraint_name TEXT, calls BIGINT,
 message TEXT, detail TEXT, hint TEXT);
INSERT INTO native_cases VALUES
 ('native missing debtor','23503','ra_debtor_detail_id_fk',1,NULL,NULL,''),
 ('native missing contact','23503','ra_third_party_contact_id_fk',1,NULL,NULL,''),
 ('native missing BU','23503','ani_business_unit_id_fk',0,NULL,NULL,''),
 ('native zero row','P0001','',1,'p_insert_respondent_account: no row inserted for Respondent Account','',''),
 ('native synthetic check','23514','po10650_synthetic_check',1,'synthetic native boundary','synthetic detail marker','synthetic hint marker'),
 ('native cancellation','57014','',1,'synthetic cancellation marker','',''),
 ('native assertion','P0004','',1,'synthetic assertion marker','',''),
 ('native unique','23505','respondent_accounts_pk',1,NULL,NULL,'');
CREATE TEMP TABLE native_observations(label TEXT PRIMARY KEY,checks JSONB,diagnostics JSONB);
SELECT is(CURRENT_SETTING('plpgsql.check_asserts'),'on','native assertion test runs with assertions enabled');
DO $native$
DECLARE c RECORD; observed JSONB; native_error JSONB; checks JSONB; before_rows JSONB;
 before_metadata JSONB; before_calls BIGINT; account_id BIGINT; account_number VARCHAR;
 state TEXT; message TEXT; detail TEXT; hint TEXT; context TEXT; constraint_name TEXT;
 trigger_body TEXT; succeeded BOOLEAN; bu SMALLINT; debtor BIGINT; contact BIGINT;
BEGIN
 IF EXISTS(SELECT 1 FROM public.business_units WHERE business_unit_id=-31849)
 OR EXISTS(SELECT 1 FROM public.debtor_detail WHERE debtor_detail_id=918651)
 OR EXISTS(SELECT 1 FROM public.third_party_contact WHERE third_party_contact_id=918651)
 OR EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='po10650_native_account')
 OR TO_REGPROCEDURE('pg_temp.po10650_native_trigger()') IS NOT NULL THEN
  RAISE EXCEPTION 'PO-10650 native failure fixture collision';
 END IF;
 FOR c IN SELECT * FROM native_cases ORDER BY label LOOP
  before_rows:=pg_temp.account_row_scope(); before_metadata:=pg_temp.account_metadata();
  before_calls:=pg_temp.allocator_calls(); checks:='[]'::JSONB; native_error:=NULL;
  bu:=CASE c.label WHEN 'native missing BU' THEN -31849 ELSE 31850 END;
  debtor:=CASE c.label WHEN 'native missing debtor' THEN 918651 ELSE NULL END;
  contact:=CASE c.label WHEN 'native missing contact' THEN 918651 ELSE NULL END;
  PERFORM SET_CONFIG('opal.po10650_case',c.label,true);
  BEGIN
   trigger_body:=CASE c.label
    WHEN 'native zero row' THEN 'IF NEW.business_unit_id=31850 THEN RETURN NULL; END IF;'
    WHEN 'native synthetic check' THEN $body$IF NEW.business_unit_id=31850 THEN RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='synthetic native boundary',CONSTRAINT='po10650_synthetic_check',DETAIL='synthetic detail marker',HINT='synthetic hint marker'; END IF;$body$
    WHEN 'native cancellation' THEN $body$IF NEW.business_unit_id=31850 THEN RAISE query_canceled USING MESSAGE='synthetic cancellation marker'; END IF;$body$
    WHEN 'native assertion' THEN $body$IF NEW.business_unit_id=31850 THEN ASSERT false,'synthetic assertion marker'; END IF;$body$
    WHEN 'native unique' THEN FORMAT('IF NEW.business_unit_id=31850 THEN NEW.respondent_account_id:=%s; END IF;',
     (SELECT (output->>'id')::BIGINT FROM nominal_output)) ELSE NULL END;
   IF trigger_body IS NOT NULL THEN
    EXECUTE FORMAT('CREATE FUNCTION pg_temp.po10650_native_trigger() RETURNS TRIGGER LANGUAGE plpgsql AS %L',
     'BEGIN '||trigger_body||' RETURN NEW; END;');
    CREATE TRIGGER po10650_native_account BEFORE INSERT ON public.respondent_accounts
     FOR EACH ROW EXECUTE FUNCTION pg_temp.po10650_native_trigger();
   END IF;
   IF c.label IN ('native cancellation','native assertion') THEN
    succeeded:=false; account_id:=NULL; account_number:=NULL;
    state:=NULL; message:=NULL; detail:=NULL; hint:=NULL; context:=NULL; constraint_name:=NULL;
    BEGIN
     CALL public.p_insert_respondent_account(bu,'REMO In',pg_temp.account_payload(),debtor,contact,account_id,account_number);
     succeeded:=true;
     RAISE EXCEPTION SQLSTATE 'ZX654' USING MESSAGE='rollback unexpected control-flow success';
    EXCEPTION
     WHEN SQLSTATE 'ZX654' THEN NULL;
     WHEN query_canceled OR assert_failure THEN
      GET STACKED DIAGNOSTICS state=RETURNED_SQLSTATE,message=MESSAGE_TEXT,detail=PG_EXCEPTION_DETAIL,
       hint=PG_EXCEPTION_HINT,context=PG_EXCEPTION_CONTEXT,constraint_name=CONSTRAINT_NAME;
     WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS state=RETURNED_SQLSTATE,message=MESSAGE_TEXT,detail=PG_EXCEPTION_DETAIL,
       hint=PG_EXCEPTION_HINT,context=PG_EXCEPTION_CONTEXT,constraint_name=CONSTRAINT_NAME;
    END;
    observed:=JSONB_BUILD_OBJECT('succeeded',succeeded,'state',state,'constraint',constraint_name,
     'calls',pg_temp.allocator_calls()-before_calls,
     'accounts',CASE WHEN before_rows->'respondent_accounts'=
     pg_temp.account_row_scope()->'respondent_accounts' THEN 0 ELSE 1 END,
     'ledger',CASE WHEN before_rows->'account_number_index'=
     pg_temp.account_row_scope()->'account_number_index' THEN 0 ELSE 1 END);
    native_error:=JSONB_BUILD_OBJECT('state',state,'message',message,'detail',detail,'hint',hint,
     'context',context,'constraint',constraint_name,'output_id',account_id,'output_number',account_number);
   ELSE
    observed:=pg_temp.observe_account_rejection(pg_temp.account_payload(),c.state,c.constraint_name,bu,'REMO In',debtor,contact,c.calls);
    SELECT JSONB_BUILD_OBJECT('state',r.state,'message',r.message,'detail',r.detail,'hint',r.hint,
     'context',r.context,'constraint',r.constraint_name) INTO STRICT native_error
    FROM rejection_observations r WHERE r.label=c.label;
   END IF;
   checks:=JSONB_BUILD_ARRAY(
    JSONB_BUILD_OBJECT('pass',(observed->>'succeeded')::BOOLEAN=false,'description',c.label||': no successful OUT result'),
    JSONB_BUILD_OBJECT('pass',observed->>'state'=c.state,'description',c.label||': unchanged SQLSTATE'),
    JSONB_BUILD_OBJECT('pass',observed->>'constraint'=c.constraint_name,'description',c.label||': exact applicable constraint'),
    JSONB_BUILD_OBJECT('pass',(observed->>'calls')::BIGINT=c.calls,'description',c.label||': completed allocator-call count'),
    JSONB_BUILD_OBJECT('pass',(observed->>'accounts')::BIGINT=0,'description',c.label||': no account write survives'),
    JSONB_BUILD_OBJECT('pass',(observed->>'ledger')::BIGINT=0,'description',c.label||': no reservation write survives'),
    JSONB_BUILD_OBJECT('pass',CASE WHEN c.message IS NULL THEN LENGTH(native_error->>'message')>0 ELSE native_error->>'message'=c.message END,'description',c.label||': original message'),
    JSONB_BUILD_OBJECT('pass',CASE WHEN c.detail IS NULL THEN LENGTH(native_error->>'detail')>0 ELSE native_error->>'detail'=c.detail END,'description',c.label||': original detail'),
    JSONB_BUILD_OBJECT('pass',native_error->>'hint'=c.hint,'description',c.label||': original hint'),
    JSONB_BUILD_OBJECT('pass',POSITION('p_insert_respondent_account' IN native_error->>'context')>0,'description',c.label||': original helper exception context'),
    JSONB_BUILD_OBJECT('pass',pg_temp.account_row_scope()=before_rows,'description',c.label||': exact whole protected row scope'));
   RAISE EXCEPTION SQLSTATE 'ZX654' USING MESSAGE='rollback native fixture objects';
  EXCEPTION WHEN SQLSTATE 'ZX654' THEN NULL;
  END;
  checks:=checks||JSONB_BUILD_ARRAY(JSONB_BUILD_OBJECT('pass',
   pg_temp.account_metadata()=before_metadata AND TO_REGPROCEDURE('pg_temp.po10650_native_trigger()') IS NULL
   AND NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='po10650_native_account'),
   'description',c.label||': trigger rollback restores routine and table metadata'));
  INSERT INTO native_observations VALUES(c.label,checks,native_error);
 END LOOP;
END;
$native$;
SELECT ok((check_result->>'pass')::BOOLEAN,check_result->>'description')
FROM native_observations CROSS JOIN LATERAL JSONB_ARRAY_ELEMENTS(checks) check_rows(check_result);
SELECT is((SELECT COUNT(*) FROM native_observations),8::BIGINT,'all eight native boundary cases observed');
SELECT ok(NOT EXISTS(SELECT 1 FROM native_observations CROSS JOIN LATERAL JSONB_ARRAY_ELEMENTS(checks) c(value)
 WHERE JSONB_TYPEOF(c.value->'pass') IS DISTINCT FROM 'boolean'),'native boundary observations have no missing Boolean');

-- ---------------------------------------------------------------------------
-- Scenario: Caller rollback, repeated calls and complete affected-row scope.
-- Setup:    An earlier caller-owned draft edit encloses two identical actual CALLs.
-- Expected: Exact distinct row/output pairs; later caller error removes both writes.
-- ---------------------------------------------------------------------------
CREATE TEMP TABLE caller_observations(checks JSONB);
DO $caller$
DECLARE before_rows JSONB; before_calls BIGINT; first_output JSONB; second_output JSONB;
 checks JSONB; after_rows JSONB; caller_rows JSONB;
BEGIN
 before_rows:=pg_temp.account_row_scope(); before_calls:=pg_temp.allocator_calls();
 BEGIN
  UPDATE public.draft_casefiles SET submitted_by_name='Synthetic earlier caller work' WHERE draft_casefile_id=918650;
  caller_rows:=pg_temp.account_row_scope();
  BEGIN
   first_output:=pg_temp.invoke_account(pg_temp.account_payload());
   second_output:=pg_temp.invoke_account(pg_temp.account_payload());
   after_rows:=pg_temp.account_row_scope();
   checks:=JSONB_BUILD_ARRAY(
    JSONB_BUILD_OBJECT('pass',(first_output->>'id')::BIGINT<>(second_output->>'id')::BIGINT
     AND first_output->>'number'<>second_output->>'number','description','caller repeat: identical payload creates distinct IDs and numbers'),
    JSONB_BUILD_OBJECT('pass',pg_temp.allocator_calls()-before_calls=2,'description','caller repeat: exactly two real allocations'),
    JSONB_BUILD_OBJECT('pass',(SELECT COUNT(*) FROM public.respondent_accounts a JOIN public.account_number_index n
     ON n.business_unit_id=a.business_unit_id AND n.account_number=a.account_number
     WHERE a.business_unit_id=31850 AND n.associated_record_type='respondent_accounts'
     AND ((a.respondent_account_id=(first_output->>'id')::BIGINT AND a.account_number=first_output->>'number')
      OR (a.respondent_account_id=(second_output->>'id')::BIGINT AND a.account_number=second_output->>'number')))=2,
     'description','caller repeat: both exact OUT pairs match their account and reservation'),
    JSONB_BUILD_OBJECT('pass',JSONB_ARRAY_LENGTH(after_rows->'respondent_accounts')-JSONB_ARRAY_LENGTH(before_rows->'respondent_accounts')=2
     AND JSONB_ARRAY_LENGTH(after_rows->'account_number_index')-JSONB_ARRAY_LENGTH(before_rows->'account_number_index')=2,
     'description','caller repeat: exactly two accounts and reservations added'),
    JSONB_BUILD_OBJECT('pass',(after_rows-'respondent_accounts'-'account_number_index')=
     (caller_rows-'respondent_accounts'-'account_number_index'),
     'description','caller repeat: other protected tables remain byte-exact'),
    JSONB_BUILD_OBJECT('pass',NOT EXISTS(SELECT 1 FROM JSONB_ARRAY_ELEMENTS(before_rows->'respondent_accounts') r(value)
     WHERE NOT (after_rows->'respondent_accounts' @> JSONB_BUILD_ARRAY(r.value)))
     AND NOT EXISTS(SELECT 1 FROM JSONB_ARRAY_ELEMENTS(before_rows->'account_number_index') r(value)
     WHERE NOT (after_rows->'account_number_index' @> JSONB_BUILD_ARRAY(r.value))),
     'description','caller repeat: every earlier account and reservation remains byte-exact'));
   RAISE EXCEPTION SQLSTATE 'ZX655' USING MESSAGE='synthetic caller failure after actual helper success';
  EXCEPTION WHEN SQLSTATE 'ZX655' THEN NULL;
  END;
  after_rows:=pg_temp.account_row_scope();
  checks:=checks||JSONB_BUILD_ARRAY(
   JSONB_BUILD_OBJECT('pass',after_rows->'respondent_accounts'=before_rows->'respondent_accounts'
    AND after_rows->'account_number_index'=before_rows->'account_number_index',
    'description','caller rollback: both successful accounts and reservations removed'),
   JSONB_BUILD_OBJECT('pass',(SELECT submitted_by_name='Synthetic earlier caller work' FROM public.draft_casefiles WHERE draft_casefile_id=918650),
    'description','caller rollback: earlier work outside failed block remains'),
   JSONB_BUILD_OBJECT('pass',after_rows=caller_rows,
    'description','caller rollback: exact protected rows restored outside earlier caller work'));
  RAISE EXCEPTION SQLSTATE 'ZX655' USING MESSAGE='restore earlier caller fixture';
 EXCEPTION WHEN SQLSTATE 'ZX655' THEN NULL;
 END;
 checks:=checks||JSONB_BUILD_ARRAY(
  JSONB_BUILD_OBJECT('pass',pg_temp.account_row_scope()=before_rows,'description','caller fixture rollback: every protected row restored'),
  JSONB_BUILD_OBJECT('pass',pg_temp.allocator_calls()-before_calls=2,'description','caller rollback: completed allocations remain observable without surviving writes'));
 INSERT INTO caller_observations VALUES(checks);
END;
$caller$;
SELECT ok((check_result->>'pass')::BOOLEAN,check_result->>'description')
FROM caller_observations CROSS JOIN LATERAL JSONB_ARRAY_ELEMENTS(checks) check_rows(check_result);
SELECT is(pg_temp.account_metadata(),(SELECT metadata FROM atomicity_before),
 'native failures and caller rollback preserve production routines and relevant table metadata');


-- ---------------------------------------------------------------------------
-- Scenario: Independent same-BU callers block, then commit or release allocation.
-- Setup:    Harness-only dblink workers, committed owned BU/Application fixtures.
-- Expected: Real helper OUT pairs persist correctly; independent cleanup is empty.
-- ---------------------------------------------------------------------------
DO $gate$
BEGIN
 IF CURRENT_DATABASE()<>'opal_maintenance_db_unit_test' OR CURRENT_USER<>'postgres' THEN
  RAISE EXCEPTION 'PO-10650 concurrency requires the harness-owned disposable database';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_available_extensions WHERE name='dblink') THEN
  RAISE EXCEPTION 'PO-10650 SQL-only concurrency tooling unavailable';
 END IF;
END;
$gate$;
CREATE EXTENSION IF NOT EXISTS dblink WITH SCHEMA public;
DO $namespace$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_extension WHERE extname='dblink' AND extnamespace='public'::REGNAMESPACE) THEN
  RAISE EXCEPTION 'PO-10650 expected dblink in public';
 END IF;
END;
$namespace$;
CREATE TEMP TABLE account_race_observations(mode TEXT PRIMARY KEY,observation JSONB);
CREATE FUNCTION pg_temp.account_race(mode TEXT) RETURNS VOID LANGUAGE plpgsql AS $race$
DECLARE
 connection TEXT;
 name TEXT;
 fixture_owned BOOLEAN := false;
 fixture_pid INTEGER;
 blocked_by_a BOOLEAN := false;
 a_pid INTEGER;
 b_pid INTEGER;
 a_date DATE;
 b_date DATE;
 a_year TEXT;
 b_year TEXT;
 a_id BIGINT;
 b_id BIGINT;
 a_number VARCHAR;
 b_number VARCHAR;
 call_a TEXT;
 call_b TEXT;
 payload JSONB;
 deadline TIMESTAMPTZ;
 count_rows BIGINT;
 expected_rows BIGINT;
 primary_state TEXT;
 primary_message TEXT;
 cleanup_state TEXT;
BEGIN
 IF mode IS NULL OR mode NOT IN ('commit','rollback') THEN
  RAISE EXCEPTION 'PO-10650 unsupported race mode';
 END IF;
 IF COALESCE(public.DBLINK_GET_CONNECTIONS(),ARRAY[]::TEXT[]) &&
    ARRAY['po10650_fixture','po10650_a','po10650_b']::TEXT[] THEN
  RAISE EXCEPTION 'PO-10650 connection-name collision';
 END IF;
 connection := FORMAT('host=127.0.0.1 port=5432 dbname=%L user=postgres connect_timeout=5 options=%L',
  CURRENT_DATABASE(),'-csearch_path=pg_catalog,public -cstatement_timeout=20000 -clock_timeout=15000 -ctimezone=UTC -cidle_in_transaction_session_timeout=30000');
 BEGIN
  PERFORM public.DBLINK_CONNECT('po10650_fixture',connection);
  PERFORM public.DBLINK_EXEC('po10650_fixture',$setup$
   BEGIN;
   DO $collision$ BEGIN
    IF EXISTS (SELECT 1 FROM public.business_units WHERE business_unit_id=31851 OR business_unit_code='P651')
    OR EXISTS (SELECT 1 FROM public.maintenance_applications WHERE application_id=31851 OR application_code='P10651') THEN
     RAISE EXCEPTION 'PO-10650 remote fixture collision';
    END IF;
   END; $collision$;
   INSERT INTO public.business_units(business_unit_id,business_unit_code,business_unit_name,business_unit_type,welsh_language)
   VALUES (31851,'P651','Synthetic concurrent account unit','Area',false);
   INSERT INTO public.maintenance_applications(application_id,application_code,application_title,application_group,active,date_used_from,date_used_to)
   VALUES (31851,'P10651','Synthetic concurrent application','Synthetic',true,DATE '1900-01-01',DATE '2100-12-31');
   COMMIT;
  $setup$);
  fixture_owned := true;
  PERFORM public.DBLINK_CONNECT('po10650_a',connection);
  PERFORM public.DBLINK_CONNECT('po10650_b',connection);
  SELECT pid INTO fixture_pid FROM public.DBLINK('po10650_fixture','SELECT PG_BACKEND_PID()') AS x(pid INTEGER);
  SELECT pid INTO a_pid FROM public.DBLINK('po10650_a','SELECT PG_BACKEND_PID()') AS x(pid INTEGER);
  SELECT pid INTO b_pid FROM public.DBLINK('po10650_b','SELECT PG_BACKEND_PID()') AS x(pid INTEGER);
  IF fixture_pid IN (a_pid,b_pid,PG_BACKEND_PID()) OR a_pid=b_pid OR a_pid=PG_BACKEND_PID() OR b_pid=PG_BACKEND_PID() OR a_pid IS NULL OR b_pid IS NULL THEN
   RAISE EXCEPTION 'PO-10650 requires independent worker backends';
  END IF;
  PERFORM public.DBLINK_EXEC('po10650_a','BEGIN ISOLATION LEVEL READ COMMITTED');
  PERFORM public.DBLINK_EXEC('po10650_b','BEGIN ISOLATION LEVEL READ COMMITTED');
  SELECT business_date,year INTO a_date,a_year FROM public.DBLINK('po10650_a',
   $q$SELECT (TRANSACTION_TIMESTAMP() AT TIME ZONE 'Europe/London')::DATE,TO_CHAR(NOW(),'YY')$q$)
   AS x(business_date DATE,year TEXT);
  SELECT business_date,year INTO b_date,b_year FROM public.DBLINK('po10650_b',
   $q$SELECT (TRANSACTION_TIMESTAMP() AT TIME ZONE 'Europe/London')::DATE,TO_CHAR(NOW(),'YY')$q$)
   AS x(business_date DATE,year TEXT);
  IF a_year IS DISTINCT FROM b_year THEN
   RAISE EXCEPTION 'PO-10650 race crossed native allocator year boundary; rerun';
  END IF;
  payload := JSONB_SET(pg_temp.account_payload()::JSONB,'{application_code}','"P10651"');
  payload := JSONB_SET(JSONB_SET(payload,'{order_details,date_ordered}',TO_JSONB(a_date::TEXT)),
   '{order_details,date_arrears_last_updated}',TO_JSONB(a_date::TEXT));
  call_a := FORMAT('CALL public.p_insert_respondent_account(31851::SMALLINT,''REMO In''::public.t_casefile_type_enum,%L::JSON,NULL,NULL,NULL,NULL)',payload::TEXT);
  payload := JSONB_SET(JSONB_SET(payload,'{order_details,date_ordered}',TO_JSONB(b_date::TEXT)),
   '{order_details,date_arrears_last_updated}',TO_JSONB(b_date::TEXT));
  call_b := FORMAT('CALL public.p_insert_respondent_account(31851::SMALLINT,''REMO In''::public.t_casefile_type_enum,%L::JSON,NULL,NULL,NULL,NULL)',payload::TEXT);
  SELECT id,number INTO a_id,a_number FROM public.DBLINK('po10650_a',call_a) AS outrow(id BIGINT,number VARCHAR);
  IF public.DBLINK_SEND_QUERY('po10650_b',call_b)<>1 THEN
   RAISE EXCEPTION 'PO-10650 second CALL was not dispatched';
  END IF;
  deadline := CLOCK_TIMESTAMP()+INTERVAL '10 seconds';
  WHILE NOT (a_pid=ANY(PG_BLOCKING_PIDS(b_pid))) LOOP
   IF public.DBLINK_IS_BUSY('po10650_b')=0 OR CLOCK_TIMESTAMP()>deadline THEN
    RAISE EXCEPTION 'PO-10650 second CALL did not demonstrably block on first';
   END IF;
   PERFORM PG_SLEEP(0.01);
  END LOOP;
  blocked_by_a:=true;
  PERFORM public.DBLINK_EXEC('po10650_a',CASE mode WHEN 'commit' THEN 'COMMIT' ELSE 'ROLLBACK' END);
  deadline := CLOCK_TIMESTAMP()+INTERVAL '10 seconds';
  WHILE public.DBLINK_IS_BUSY('po10650_b')=1 LOOP
   IF CLOCK_TIMESTAMP()>deadline THEN RAISE EXCEPTION 'PO-10650 waiting CALL did not finish'; END IF;
   PERFORM PG_SLEEP(0.01);
  END LOOP;
  SELECT id,number INTO b_id,b_number FROM public.DBLINK_GET_RESULT('po10650_b') AS outrow(id BIGINT,number VARCHAR);
  PERFORM id FROM public.DBLINK_GET_RESULT('po10650_b') AS outrow(id BIGINT,number VARCHAR);
  PERFORM public.DBLINK_EXEC('po10650_b','COMMIT');
  IF a_id IS NULL OR b_id IS NULL OR a_id=b_id OR a_number IS NULL OR b_number IS NULL
  OR LEFT(a_number,2)<>a_year OR LEFT(b_number,2)<>b_year
  OR a_number !~ '^[0-9]{8}[A-W]$' OR b_number !~ '^[0-9]{8}[A-W]$'
  OR RIGHT(a_number,1)<>public.f_get_check_letter(LEFT(a_number,8)::VARCHAR)
  OR RIGHT(b_number,1)<>public.f_get_check_letter(LEFT(b_number,8)::VARCHAR)
  OR (mode='commit' AND a_number=b_number) THEN
   RAISE EXCEPTION 'PO-10650 invalid independent output pairs';
  END IF;
  expected_rows := CASE mode WHEN 'commit' THEN 2 ELSE 1 END;
  SELECT COUNT(*) INTO count_rows FROM public.respondent_accounts WHERE business_unit_id=31851;
  IF count_rows<>expected_rows THEN RAISE EXCEPTION 'PO-10650 wrong committed account count'; END IF;
  SELECT COUNT(*) INTO count_rows FROM public.account_number_index WHERE business_unit_id=31851;
  IF count_rows<>expected_rows THEN RAISE EXCEPTION 'PO-10650 wrong committed reservation count'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.respondent_accounts a JOIN public.account_number_index n
   ON n.business_unit_id=a.business_unit_id AND n.account_number=a.account_number
   WHERE a.respondent_account_id=b_id AND a.business_unit_id=31851 AND a.account_number=b_number
    AND n.associated_record_type='respondent_accounts' AND a.orders_balance=0 AND a.version_number=1) THEN
   RAISE EXCEPTION 'PO-10650 second inserted row differs from its outputs';
  END IF;
  IF mode='commit' AND NOT EXISTS (SELECT 1 FROM public.respondent_accounts a JOIN public.account_number_index n
   ON n.business_unit_id=a.business_unit_id AND n.account_number=a.account_number
   WHERE a.respondent_account_id=a_id AND a.business_unit_id=31851 AND a.account_number=a_number
    AND n.associated_record_type='respondent_accounts' AND a.orders_balance=0 AND a.version_number=1) THEN
   RAISE EXCEPTION 'PO-10650 first inserted row differs from its outputs';
  END IF;
  IF mode='rollback' AND EXISTS (SELECT 1 FROM public.respondent_accounts WHERE respondent_account_id=a_id) THEN
   RAISE EXCEPTION 'PO-10650 rolled-back first account survived';
  END IF;
 EXCEPTION
  WHEN query_canceled OR assert_failure THEN primary_state:=SQLSTATE; primary_message:=SQLERRM;
  WHEN OTHERS THEN primary_state:=SQLSTATE; primary_message:=SQLERRM;
 END;

 -- Workers close before fixture deletion; close rolls back unfinished transactions.
 FOREACH name IN ARRAY ARRAY['po10650_a','po10650_b'] LOOP
  BEGIN
   IF name=ANY(COALESCE(public.DBLINK_GET_CONNECTIONS(),ARRAY[]::TEXT[])) THEN
    PERFORM public.DBLINK_DISCONNECT(name);
   END IF;
  EXCEPTION WHEN OTHERS THEN cleanup_state:=SQLSTATE;
  END;
 END LOOP;
 BEGIN
  IF 'po10650_fixture'=ANY(COALESCE(public.DBLINK_GET_CONNECTIONS(),ARRAY[]::TEXT[])) THEN
   IF fixture_owned THEN
    PERFORM public.DBLINK_EXEC('po10650_fixture',$cleanup$
     BEGIN;
     DELETE FROM public.respondent_accounts WHERE business_unit_id=31851;
     DELETE FROM public.account_number_index WHERE business_unit_id=31851;
     DELETE FROM public.maintenance_applications WHERE application_id=31851 AND application_code='P10651';
     DELETE FROM public.business_units WHERE business_unit_id=31851 AND business_unit_code='P651';
     COMMIT;
    $cleanup$);
    -- The fixture backend differs from the workers/local backend and sees committed cleanup.
    SELECT remaining INTO count_rows FROM public.DBLINK('po10650_fixture',$readback$
     SELECT (SELECT COUNT(*) FROM public.respondent_accounts WHERE business_unit_id=31851)
      +(SELECT COUNT(*) FROM public.account_number_index WHERE business_unit_id=31851)
      +(SELECT COUNT(*) FROM public.maintenance_applications WHERE application_id=31851 OR application_code='P10651')
      +(SELECT COUNT(*) FROM public.business_units WHERE business_unit_id=31851 OR business_unit_code='P651')
    $readback$) AS x(remaining BIGINT);
    IF count_rows<>0 THEN RAISE EXCEPTION 'PO-10650 committed fixture cleanup incomplete'; END IF;
   ELSE
    PERFORM public.DBLINK_EXEC('po10650_fixture','ROLLBACK');
   END IF;
   PERFORM public.DBLINK_DISCONNECT('po10650_fixture');
  ELSIF fixture_owned THEN
   RAISE EXCEPTION 'PO-10650 fixture cleanup connection unavailable';
  END IF;
 EXCEPTION WHEN OTHERS THEN cleanup_state:=SQLSTATE;
 END;
 IF COALESCE(public.DBLINK_GET_CONNECTIONS(),ARRAY[]::TEXT[]) &&
    ARRAY['po10650_fixture','po10650_a','po10650_b']::TEXT[] THEN
  cleanup_state:='P0001';
 END IF;
 IF primary_state IS NOT NULL THEN
  RAISE EXCEPTION USING ERRCODE=primary_state,MESSAGE=primary_message,
   DETAIL=FORMAT('PO-10650 test cleanup SQLSTATE: %s',COALESCE(cleanup_state,'none'));
 END IF;
 IF cleanup_state IS NOT NULL THEN
  RAISE EXCEPTION 'PO-10650 cleanup failed with SQLSTATE %',cleanup_state;
 END IF;
 INSERT INTO account_race_observations VALUES(mode,JSONB_BUILD_OBJECT(
  'mode',mode,'local_pid',PG_BACKEND_PID(),'fixture_pid',fixture_pid,'a_pid',a_pid,'b_pid',b_pid,
  'observed_blocking',blocked_by_a,'first_output',JSONB_BUILD_OBJECT('id',a_id,'number',a_number),
  'second_output',JSONB_BUILD_OBJECT('id',b_id,'number',b_number),'committed_accounts',expected_rows,
  'committed_reservations',expected_rows,'cleanup_remaining',count_rows,'cleanup_state',cleanup_state));
END;
$race$;

SET LOCAL statement_timeout='60s';
SELECT lives_ok($q$SELECT pg_temp.account_race('commit')$q$,
 'real same-BU helper calls commit distinct row/output pairs');
SELECT ok(NOT EXISTS(SELECT 1 FROM public.respondent_accounts WHERE business_unit_id=31851)
 AND NOT EXISTS(SELECT 1 FROM public.account_number_index WHERE business_unit_id=31851)
 AND NOT EXISTS(SELECT 1 FROM public.business_units WHERE business_unit_id=31851 OR business_unit_code='P651')
 AND NOT EXISTS(SELECT 1 FROM public.maintenance_applications WHERE application_id=31851 OR application_code='P10651')
 AND NOT (COALESCE(public.DBLINK_GET_CONNECTIONS(),ARRAY[]::TEXT[]) &&
 ARRAY['po10650_fixture','po10650_a','po10650_b']::TEXT[]),'commit race records and connections are absent');
SELECT lives_ok($q$SELECT pg_temp.account_race('rollback')$q$,
 'waiting helper completes after first caller rollback');
SELECT ok(NOT EXISTS(SELECT 1 FROM public.respondent_accounts WHERE business_unit_id=31851)
 AND NOT EXISTS(SELECT 1 FROM public.account_number_index WHERE business_unit_id=31851)
 AND NOT EXISTS(SELECT 1 FROM public.business_units WHERE business_unit_id=31851 OR business_unit_code='P651')
 AND NOT EXISTS(SELECT 1 FROM public.maintenance_applications WHERE application_id=31851 OR application_code='P10651')
 AND NOT (COALESCE(public.DBLINK_GET_CONNECTIONS(),ARRAY[]::TEXT[]) &&
 ARRAY['po10650_fixture','po10650_a','po10650_b']::TEXT[]),'rollback race records and connections are absent');
SELECT is((SELECT COUNT(*) FROM account_race_observations),2::BIGINT,'both independent-session race modes observed');
SELECT ok((observation->>'observed_blocking')::BOOLEAN AND (observation->>'cleanup_remaining')::BIGINT=0
 AND observation->'cleanup_state'='null'::JSONB,mode||' race: blocking and independent cleanup readback retained')
FROM account_race_observations ORDER BY mode;
SELECT diag('PO-10650 race observation: '||observation::TEXT) FROM account_race_observations ORDER BY mode;
SELECT is(pg_temp.account_metadata(),(SELECT metadata FROM atomicity_before),
 'independent sessions preserve production routines and relevant table metadata');
SET LOCAL statement_timeout='30s';

SELECT * FROM finish();
ROLLBACK;
