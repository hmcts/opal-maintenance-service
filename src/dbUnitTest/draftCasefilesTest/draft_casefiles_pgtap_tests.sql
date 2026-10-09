/**
 * OPAL Program
 *
 * MODULE      : draft_casefiles_pgtap_tests.sql
 *
 * DESCRIPTION : Verify the Draft Casefiles schema, integrity rules and caller rollback.
 *
 * CHANGE HISTORY:
 *
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * 26/09/2026  Chris Larkin  PO-10299      Initial pgTAP test suite.
 * 03/10/2026  Chris Larkin  PO-10659      Update coverage for the account foreign key and unrelated-row preservation.
 */

-- PO-10299: physical contract, synthetic integrity cases and caller rollback.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SET LOCAL search_path = public, pg_catalog;
SELECT plan(119);

-- -----------------------------------------------------------------------------
-- Scenario: Physical schema and supporting objects
-- Setup: Migrations applied; public schema selected
-- Expected: Exact TDIA contract including the publication account foreign key
-- -----------------------------------------------------------------------------
SELECT has_table('public', 'draft_casefiles', 'table exists');

SELECT is((SELECT array_agg(attname::text ORDER BY attnum) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attnum>0 AND NOT attisdropped), ARRAY['draft_casefile_id','business_unit_id','created_date','submitted_by','submitted_by_name','validated_date','validated_by','validated_by_name','casefile','casefile_snapshot','casefile_type','casefile_status','casefile_status_date','status_message','timeline_data','account_number','account_id','version_number']::text[], 'exact ordered 18 columns');

SELECT is((SELECT format_type(atttypid,atttypmod) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='draft_casefile_id'), 'bigint', 'draft_casefile_id exact type');

SELECT is((SELECT attnotnull FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='draft_casefile_id'), true, 'draft_casefile_id nullability');

SELECT is((SELECT col_description(attrelid,attnum) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='draft_casefile_id'), 'Primary key and unique identifier for the Draft Case file', 'draft_casefile_id authoritative comment');

SELECT is((SELECT format_type(atttypid,atttypmod) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='business_unit_id'), 'smallint', 'business_unit_id exact type');

SELECT is((SELECT attnotnull FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='business_unit_id'), true, 'business_unit_id nullability');

SELECT is((SELECT col_description(attrelid,attnum) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='business_unit_id'), 'Owning Business Unit', 'business_unit_id authoritative comment');

SELECT is((SELECT format_type(atttypid,atttypmod) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='created_date'), 'timestamp without time zone', 'created_date exact type');

SELECT is((SELECT attnotnull FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='created_date'), true, 'created_date nullability');

SELECT is((SELECT col_description(attrelid,attnum) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='created_date'), 'Date and time at which the Draft Case file is first received for review', 'created_date authoritative comment');

SELECT is((SELECT format_type(atttypid,atttypmod) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='submitted_by'), 'character varying(20)', 'submitted_by exact type');

SELECT is((SELECT attnotnull FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='submitted_by'), true, 'submitted_by nullability');

SELECT is((SELECT col_description(attrelid,attnum) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='submitted_by'), 'Identifier of the submitting user', 'submitted_by authoritative comment');

SELECT is((SELECT format_type(atttypid,atttypmod) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='submitted_by_name'), 'character varying(100)', 'submitted_by_name exact type');

SELECT is((SELECT attnotnull FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='submitted_by_name'), true, 'submitted_by_name nullability');

SELECT is((SELECT col_description(attrelid,attnum) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='submitted_by_name'), 'Display name of the submitting user', 'submitted_by_name authoritative comment');

SELECT is((SELECT format_type(atttypid,atttypmod) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='validated_date'), 'timestamp without time zone', 'validated_date exact type');

SELECT is((SELECT attnotnull FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='validated_date'), false, 'validated_date nullability');

SELECT is((SELECT col_description(attrelid,attnum) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='validated_date'), 'Date and time the Draft Case file was validated', 'validated_date authoritative comment');

SELECT is((SELECT format_type(atttypid,atttypmod) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='validated_by'), 'character varying(20)', 'validated_by exact type');

SELECT is((SELECT attnotnull FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='validated_by'), false, 'validated_by nullability');

SELECT is((SELECT col_description(attrelid,attnum) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='validated_by'), 'Identifier of the user who validated the Draft Case file', 'validated_by authoritative comment');

SELECT is((SELECT format_type(atttypid,atttypmod) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='validated_by_name'), 'character varying(100)', 'validated_by_name exact type');

SELECT is((SELECT attnotnull FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='validated_by_name'), false, 'validated_by_name nullability');

SELECT is((SELECT col_description(attrelid,attnum) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='validated_by_name'), 'Display name of the user who validated the Draft Case file', 'validated_by_name authoritative comment');

SELECT is((SELECT format_type(atttypid,atttypmod) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='casefile'), 'json', 'casefile exact type');

SELECT is((SELECT attnotnull FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='casefile'), true, 'casefile nullability');

SELECT is((SELECT col_description(attrelid,attnum) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='casefile'), 'Complete structured RM Case file payload', 'casefile authoritative comment');

SELECT is((SELECT format_type(atttypid,atttypmod) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='casefile_snapshot'), 'json', 'casefile_snapshot exact type');

SELECT is((SELECT attnotnull FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='casefile_snapshot'), true, 'casefile_snapshot nullability');

SELECT is((SELECT col_description(attrelid,attnum) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='casefile_snapshot'), 'Backend-generated identifying summary for worklist and checking displays', 'casefile_snapshot authoritative comment');

SELECT is((SELECT format_type(atttypid,atttypmod) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='casefile_type'), 't_casefile_type_enum', 'casefile_type exact type');

SELECT is((SELECT attnotnull FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='casefile_type'), true, 'casefile_type nullability');

SELECT is((SELECT col_description(attrelid,attnum) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='casefile_type'), 'REMO In, REMO Out, or REMO Out (CMS)', 'casefile_type authoritative comment');

SELECT is((SELECT format_type(atttypid,atttypmod) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='casefile_status'), 't_draft_casefile_status_enum', 'casefile_status exact type');

SELECT is((SELECT attnotnull FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='casefile_status'), true, 'casefile_status nullability');

SELECT is((SELECT col_description(attrelid,attnum) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='casefile_status'), 'Lifecycle status; initially SUBMITTED', 'casefile_status authoritative comment');

SELECT is((SELECT format_type(atttypid,atttypmod) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='casefile_status_date'), 'timestamp without time zone', 'casefile_status_date exact type');

SELECT is((SELECT attnotnull FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='casefile_status_date'), true, 'casefile_status_date nullability');

SELECT is((SELECT col_description(attrelid,attnum) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='casefile_status_date'), 'Date and time of the current status', 'casefile_status_date authoritative comment');

SELECT is((SELECT format_type(atttypid,atttypmod) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='status_message'), 'text', 'status_message exact type');

SELECT is((SELECT attnotnull FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='status_message'), false, 'status_message nullability');

SELECT is((SELECT col_description(attrelid,attnum) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='status_message'), 'System status message; not accepted from the create-journey frontend', 'status_message authoritative comment');

SELECT is((SELECT format_type(atttypid,atttypmod) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='timeline_data'), 'json', 'timeline_data exact type');

SELECT is((SELECT attnotnull FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='timeline_data'), true, 'timeline_data nullability');

SELECT is((SELECT col_description(attrelid,attnum) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='timeline_data'), 'Backend-created initial entry. Timeline label: Submitted. Database lifecycle value: SUBMITTED', 'timeline_data authoritative comment');

SELECT is((SELECT format_type(atttypid,atttypmod) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='account_number'), 'character varying(25)', 'account_number exact type');

SELECT is((SELECT attnotnull FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='account_number'), false, 'account_number nullability');

SELECT is((SELECT col_description(attrelid,attnum) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='account_number'), 'Account number of the Respondent Account created from the successfully published Draft Case file', 'account_number authoritative comment');

SELECT is((SELECT format_type(atttypid,atttypmod) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='account_id'), 'bigint', 'account_id exact type');

SELECT is((SELECT attnotnull FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='account_id'), false, 'account_id nullability');

SELECT is((SELECT col_description(attrelid,attnum) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='account_id'), 'Nullable Respondent Account reference, populated only after successful publication', 'account_id authoritative comment');

SELECT is((SELECT format_type(atttypid,atttypmod) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='version_number'), 'bigint', 'version_number exact type');

SELECT is((SELECT attnotnull FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='version_number'), false, 'version_number nullability');

SELECT is((SELECT col_description(attrelid,attnum) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='version_number'), 'Optimistic-locking version for later updates', 'version_number authoritative comment');

SELECT is((SELECT array_agg(enumlabel::text ORDER BY enumsortorder) FROM pg_enum WHERE enumtypid='public.t_casefile_type_enum'::regtype), ARRAY['REMO In','REMO Out','REMO Out (CMS)']::text[], 't_casefile_type_enum exact labels and order');

SELECT is((SELECT array_agg(enumlabel::text ORDER BY enumsortorder) FROM pg_enum WHERE enumtypid='public.t_draft_casefile_status_enum'::regtype), ARRAY['SUBMITTED','DELETED','REJECTED','PUBLISHING_PENDING','PUBLISHED','PUBLISHING_FAILED','RESUBMITTED']::text[], 't_draft_casefile_status_enum exact labels and order');

SELECT is((SELECT array_agg(conname::text ORDER BY conname) FROM pg_constraint WHERE conrelid='public.draft_casefiles'::regclass AND contype IN ('p','f','u','c')), ARRAY['dcf_account_id_fk','dcf_business_unit_id_fk','draft_casefiles_account_id_uk','draft_casefiles_pk']::text[], 'exact constraints including publication account foreign key');

SELECT is((SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conrelid='public.draft_casefiles'::regclass AND conname='draft_casefiles_pk'), 'PRIMARY KEY (draft_casefile_id)', 'draft_casefiles_pk definition');

SELECT is((SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conrelid='public.draft_casefiles'::regclass AND conname='draft_casefiles_account_id_uk'), 'UNIQUE (account_id)', 'draft_casefiles_account_id_uk definition');

SELECT is((SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conrelid='public.draft_casefiles'::regclass AND conname='dcf_business_unit_id_fk'), 'FOREIGN KEY (business_unit_id) REFERENCES business_units(business_unit_id)', 'dcf_business_unit_id_fk definition');

SELECT is((SELECT confupdtype::text||confdeltype::text||condeferrable::text||condeferred::text FROM pg_constraint WHERE conrelid='public.draft_casefiles'::regclass AND conname='dcf_business_unit_id_fk'), 'aafalsefalse', 'Business Unit foreign key uses immediate NO ACTION');

SELECT is((SELECT array_agg(indexname::text ORDER BY indexname) FROM pg_indexes WHERE schemaname='public' AND tablename='draft_casefiles'), ARRAY['draft_casefiles_account_id_uk','draft_casefiles_business_unit_id_idx','draft_casefiles_pk']::text[], 'exact three indexes without duplicate account index');

SELECT is((SELECT indexdef FROM pg_indexes WHERE schemaname='public' AND indexname='draft_casefiles_business_unit_id_idx'), 'CREATE INDEX draft_casefiles_business_unit_id_idx ON public.draft_casefiles USING btree (business_unit_id)', 'Business Unit btree index definition');

SELECT is((SELECT bool_and(indisvalid AND indisready) FROM pg_index WHERE indrelid='public.draft_casefiles'::regclass), true, 'all indexes valid and ready');

SELECT is((SELECT seqtypid::regtype::text||':'||seqstart||':'||seqincrement||':'||seqcache||':'||seqcycle FROM pg_sequence WHERE seqrelid='public.draft_casefile_id_seq'::regclass), 'bigint:1:1:1:false', 'sequence type/start/increment/cache/cycle');

SELECT is(pg_get_serial_sequence('public.draft_casefiles','draft_casefile_id'), 'public.draft_casefile_id_seq', 'sequence owned by ID column');

SELECT is((SELECT pg_get_expr(adbin,adrelid) FROM pg_attrdef d JOIN pg_attribute a ON a.attrelid=d.adrelid AND a.attnum=d.adnum WHERE d.adrelid='public.draft_casefiles'::regclass AND a.attname='draft_casefile_id'), 'nextval(''draft_casefile_id_seq''::regclass)', 'explicit sequence default');

SELECT is((SELECT count(*) FROM pg_attrdef WHERE adrelid='public.draft_casefiles'::regclass), 1::bigint, 'only ID has database default');

SELECT is((SELECT count(*) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attidentity<>''), 0::bigint, 'no identity replacement');

SELECT is((SELECT count(*) FROM pg_trigger WHERE tgrelid='public.draft_casefiles'::regclass AND NOT tgisinternal), 0::bigint, 'no backend-owned orchestration triggers');

-- -----------------------------------------------------------------------------
-- Scenario: Collision-free synthetic fixtures
-- Setup: No test rows inserted yet
-- Expected: No reserved synthetic Business Unit keys; the runner proves initial emptiness
-- -----------------------------------------------------------------------------
SELECT is((SELECT count(*) FROM public.business_units WHERE business_unit_id IN (32091,-32092) OR business_unit_code='D991'), 0::bigint, 'synthetic fixture keys do not collide');

-- -----------------------------------------------------------------------------
-- Scenario: Valid inserts including VARCHAR boundaries
-- Setup: Create an owned Business Unit/account, an unrelated draft, and two subject drafts
-- Expected: Minimal and fully populated rows succeed without invented defaults
-- -----------------------------------------------------------------------------
SELECT lives_ok($sql$INSERT INTO public.business_units (business_unit_id,business_unit_code,business_unit_name,business_unit_type,welsh_language) VALUES (32091,'D991','Synthetic PO-10299 test unit','Area',false)$sql$, 'create owned Business Unit fixture');

-- PO-10659: the complete draft now references its own generated Respondent Account.
DO $fixture$ BEGIN IF NOT EXISTS (SELECT 1 FROM public.maintenance_applications) THEN RAISE EXCEPTION 'Required application reference data missing'; END IF; END $fixture$;
CREATE TEMP TABLE dcf_respondent_parent AS WITH inserted AS (
 INSERT INTO public.respondent_accounts(business_unit_id,account_number,application_id,account_balance,orders_balance,orders_amount,payment_period,total_arrears,account_status,last_movement_date,date_arrears_last_updated,allow_cheques,cheque_clearance_period,credit_trans_clearance_period,casefile_type,interest_flag,indexation,payment_arrangement,version_number)
 SELECT 32091,'CV-DCF-PARENT',(SELECT min(application_id) FROM public.maintenance_applications),0,0,0,'Weekly',0,'L',TIMESTAMP '2026-01-01 12:00:00',TIMESTAMP '2026-01-01 12:00:00',true,10,0,'REMO In',false,'None','Court',1 RETURNING respondent_account_id)
 SELECT respondent_account_id FROM inserted;

-- Keep a separate synthetic draft outside the two subject rows, so fixture-scoped
-- uniqueness checks cannot accidentally rely on an otherwise empty business table.
CREATE TEMP TABLE dcf_unrelated AS
WITH inserted AS (
    INSERT INTO public.draft_casefiles
        (business_unit_id, created_date, submitted_by, submitted_by_name, casefile,
         casefile_snapshot, casefile_type, casefile_status, casefile_status_date, timeline_data)
    VALUES
        (32091, TIMESTAMP '2026-01-01 12:00:00', 'synthetic-other', 'Synthetic unrelated',
         '{}', '{}', 'REMO In', 'SUBMITTED', TIMESTAMP '2026-01-01 12:00:00', '[]')
    RETURNING *
)
SELECT draft_casefile_id, to_jsonb(inserted) AS before_image FROM inserted;

CREATE TEMP TABLE dcf_test_ids (label text PRIMARY KEY, id bigint NOT NULL);

SELECT lives_ok($sql$WITH ins AS (INSERT INTO public.draft_casefiles (business_unit_id,created_date,submitted_by,submitted_by_name,casefile,casefile_snapshot,casefile_type,casefile_status,casefile_status_date,timeline_data) VALUES (32091,TIMESTAMP '2026-01-01 12:00:00','synthetic-user','Synthetic User','{"synthetic":true}','{"reference":"test"}','REMO In','SUBMITTED',TIMESTAMP '2026-01-01 12:00:00','[{"label":"Submitted"}]') RETURNING draft_casefile_id) INSERT INTO dcf_test_ids SELECT 'minimal',draft_casefile_id FROM ins$sql$, 'minimal valid insert with generated ID');

SELECT lives_ok($sql$WITH ins AS (INSERT INTO public.draft_casefiles (business_unit_id,created_date,submitted_by,submitted_by_name,casefile,casefile_snapshot,casefile_type,casefile_status,casefile_status_date,timeline_data,validated_date,validated_by,validated_by_name,status_message,account_number,account_id,version_number) VALUES (32091,TIMESTAMP '2026-01-01 12:00:00',repeat('u',20),repeat('n',100),'{"synthetic":true}','{"reference":"test"}','REMO In','SUBMITTED',TIMESTAMP '2026-01-01 12:00:00','[{"label":"Submitted"}]',TIMESTAMP '2026-01-02 12:00:00',repeat('v',20),repeat('w',100),'Synthetic status',repeat('a',25),(SELECT respondent_account_id FROM dcf_respondent_parent),0) RETURNING draft_casefile_id) INSERT INTO dcf_test_ids SELECT 'complete',draft_casefile_id FROM ins$sql$, 'complete valid insert with generated ID');

SELECT is((SELECT id FROM dcf_test_ids WHERE label='complete')-(SELECT id FROM dcf_test_ids WHERE label='minimal'), 1::bigint, 'adjacent generated sequence values increment by one');

SELECT is((SELECT validated_date IS NULL AND validated_by IS NULL AND validated_by_name IS NULL AND status_message IS NULL AND account_number IS NULL AND account_id IS NULL AND version_number IS NULL FROM public.draft_casefiles WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal')), true, 'all seven optional values remain SQL NULL when omitted');

SELECT is((SELECT casefile::text||'|'||casefile_snapshot::text||'|'||timeline_data::text FROM public.draft_casefiles WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal')), '{"synthetic":true}|{"reference":"test"}|[{"label":"Submitted"}]', 'JSON values retain supplied content without backend-shape assumptions');

-- -----------------------------------------------------------------------------
-- Scenario: Required column failures
-- Setup: Update the minimal valid row, one required value at a time
-- Expected: Every NULL update fails with 23502 and preserves the row
-- -----------------------------------------------------------------------------
SELECT throws_ok($sql$UPDATE public.draft_casefiles SET draft_casefile_id=NULL WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal')$sql$, '23502', NULL, 'draft_casefile_id rejects SQL NULL');

SELECT throws_ok($sql$UPDATE public.draft_casefiles SET business_unit_id=NULL WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal')$sql$, '23502', NULL, 'business_unit_id rejects SQL NULL');

SELECT throws_ok($sql$UPDATE public.draft_casefiles SET created_date=NULL WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal')$sql$, '23502', NULL, 'created_date rejects SQL NULL');

SELECT throws_ok($sql$UPDATE public.draft_casefiles SET submitted_by=NULL WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal')$sql$, '23502', NULL, 'submitted_by rejects SQL NULL');

SELECT throws_ok($sql$UPDATE public.draft_casefiles SET submitted_by_name=NULL WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal')$sql$, '23502', NULL, 'submitted_by_name rejects SQL NULL');

SELECT throws_ok($sql$UPDATE public.draft_casefiles SET casefile=NULL WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal')$sql$, '23502', NULL, 'casefile rejects SQL NULL');

SELECT throws_ok($sql$UPDATE public.draft_casefiles SET casefile_snapshot=NULL WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal')$sql$, '23502', NULL, 'casefile_snapshot rejects SQL NULL');

SELECT throws_ok($sql$UPDATE public.draft_casefiles SET casefile_type=NULL WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal')$sql$, '23502', NULL, 'casefile_type rejects SQL NULL');

SELECT throws_ok($sql$UPDATE public.draft_casefiles SET casefile_status=NULL WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal')$sql$, '23502', NULL, 'casefile_status rejects SQL NULL');

SELECT throws_ok($sql$UPDATE public.draft_casefiles SET casefile_status_date=NULL WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal')$sql$, '23502', NULL, 'casefile_status_date rejects SQL NULL');

SELECT throws_ok($sql$UPDATE public.draft_casefiles SET timeline_data=NULL WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal')$sql$, '23502', NULL, 'timeline_data rejects SQL NULL');

-- -----------------------------------------------------------------------------
-- Scenario: VARCHAR overflow failures
-- Setup: Assign one character beyond each declared maximum
-- Expected: Each update fails with 22001 without explicit narrowing casts
-- -----------------------------------------------------------------------------
SELECT throws_ok($sql$UPDATE public.draft_casefiles SET submitted_by=repeat('x',21) WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal')$sql$, '22001', NULL, 'submitted_by rejects overlength value');

SELECT throws_ok($sql$UPDATE public.draft_casefiles SET submitted_by_name=repeat('x',101) WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal')$sql$, '22001', NULL, 'submitted_by_name rejects overlength value');

SELECT throws_ok($sql$UPDATE public.draft_casefiles SET validated_by=repeat('x',21) WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal')$sql$, '22001', NULL, 'validated_by rejects overlength value');

SELECT throws_ok($sql$UPDATE public.draft_casefiles SET validated_by_name=repeat('x',101) WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal')$sql$, '22001', NULL, 'validated_by_name rejects overlength value');

SELECT throws_ok($sql$UPDATE public.draft_casefiles SET account_number=repeat('x',26) WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal')$sql$, '22001', NULL, 'account_number rejects overlength value');

-- -----------------------------------------------------------------------------
-- Scenario: Enum and JSON input failures
-- Setup: Supply unknown enum labels and malformed JSON to the minimal row
-- Expected: Each update fails with 22P02
-- -----------------------------------------------------------------------------
SELECT throws_ok($sql$UPDATE public.draft_casefiles SET casefile_type='INVALID' WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal')$sql$, '22P02', NULL, 'casefile_type rejects unknown enum');

SELECT throws_ok($sql$UPDATE public.draft_casefiles SET casefile_status='INVALID' WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal')$sql$, '22P02', NULL, 'casefile_status rejects unknown enum');

SELECT throws_ok($sql$UPDATE public.draft_casefiles SET casefile='{invalid' WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal')$sql$, '22P02', NULL, 'casefile rejects malformed JSON');

SELECT throws_ok($sql$UPDATE public.draft_casefiles SET casefile_snapshot='{invalid' WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal')$sql$, '22P02', NULL, 'casefile_snapshot rejects malformed JSON');

SELECT throws_ok($sql$UPDATE public.draft_casefiles SET timeline_data='{invalid' WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal')$sql$, '22P02', NULL, 'timeline_data rejects malformed JSON');

-- -----------------------------------------------------------------------------
-- Scenario: Key conflicts and Business Unit integrity
-- Setup: Attempt duplicate PK/account, missing parent and referenced-parent deletion
-- Expected: 23505/23503 errors and original row values retained
-- -----------------------------------------------------------------------------
SELECT throws_ok($sql$UPDATE public.draft_casefiles SET draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='complete') WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal')$sql$, '23505', NULL, 'duplicate PK rejected');

SELECT throws_ok($sql$UPDATE public.draft_casefiles SET business_unit_id=-32092 WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal')$sql$, '23503', NULL, 'unknown Business Unit rejected');

SELECT throws_ok($sql$UPDATE public.draft_casefiles SET account_id=(SELECT respondent_account_id FROM dcf_respondent_parent) WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal')$sql$, '23505', NULL, 'duplicate non-null account rejected');

SELECT throws_ok($sql$DELETE FROM public.business_units WHERE business_unit_id=32091$sql$, '23503', NULL, 'referenced Business Unit deletion rejected');

SELECT is((SELECT business_unit_id=32091 AND account_id IS NULL AND submitted_by='synthetic-user' AND casefile_type='REMO In' AND casefile_status='SUBMITTED' FROM public.draft_casefiles WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal')), true, 'failed statements leave original row unchanged');

-- -----------------------------------------------------------------------------
-- Scenario: All supported lifecycle and type labels
-- Setup: Update only the minimal row through every declared enum value
-- Expected: Every valid enum assignment succeeds
-- -----------------------------------------------------------------------------
SELECT lives_ok($sql$UPDATE public.draft_casefiles SET casefile_type='REMO In' WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal')$sql$, 'casefile_type permits REMO In');

SELECT lives_ok($sql$UPDATE public.draft_casefiles SET casefile_type='REMO Out' WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal')$sql$, 'casefile_type permits REMO Out');

SELECT lives_ok($sql$UPDATE public.draft_casefiles SET casefile_type='REMO Out (CMS)' WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal')$sql$, 'casefile_type permits REMO Out (CMS)');

SELECT lives_ok($sql$UPDATE public.draft_casefiles SET casefile_status='SUBMITTED' WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal')$sql$, 'casefile_status permits SUBMITTED');

SELECT lives_ok($sql$UPDATE public.draft_casefiles SET casefile_status='DELETED' WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal')$sql$, 'casefile_status permits DELETED');

SELECT lives_ok($sql$UPDATE public.draft_casefiles SET casefile_status='REJECTED' WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal')$sql$, 'casefile_status permits REJECTED');

SELECT lives_ok($sql$UPDATE public.draft_casefiles SET casefile_status='PUBLISHING_PENDING' WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal')$sql$, 'casefile_status permits PUBLISHING_PENDING');

SELECT lives_ok($sql$UPDATE public.draft_casefiles SET casefile_status='PUBLISHED' WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal')$sql$, 'casefile_status permits PUBLISHED');

SELECT lives_ok($sql$UPDATE public.draft_casefiles SET casefile_status='PUBLISHING_FAILED' WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal')$sql$, 'casefile_status permits PUBLISHING_FAILED');

SELECT lives_ok($sql$UPDATE public.draft_casefiles SET casefile_status='RESUBMITTED' WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal')$sql$, 'casefile_status permits RESUBMITTED');

-- -----------------------------------------------------------------------------
-- Scenario: Nullable account uniqueness
-- Setup: Clear the complete row account; minimal row already has NULL account
-- Expected: Two NULL account references coexist
-- -----------------------------------------------------------------------------
SELECT lives_ok($sql$UPDATE public.draft_casefiles SET account_id=NULL WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='complete')$sql$, 'account can return to NULL');

SELECT is((SELECT count(*) FROM public.draft_casefiles WHERE draft_casefile_id IN (SELECT id FROM dcf_test_ids) AND account_id IS NULL), 2::bigint, 'unique account constraint permits multiple NULLs');

-- -----------------------------------------------------------------------------
-- Scenario: Caller-owned rollback
-- Setup: Change status_message within a savepoint then roll back to it
-- Expected: Previous NULL value is restored without a database orchestration routine
-- -----------------------------------------------------------------------------
SAVEPOINT dcf_backend_transaction;

UPDATE public.draft_casefiles SET status_message='rolled back' WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal');

ROLLBACK TO SAVEPOINT dcf_backend_transaction;

SELECT is((SELECT status_message IS NULL FROM public.draft_casefiles WHERE draft_casefile_id=(SELECT id FROM dcf_test_ids WHERE label='minimal')), true, 'caller rollback restores prior state');

-- -----------------------------------------------------------------------------
-- Scenario: Unrelated draft preservation
-- Setup: The separate draft was excluded from every subject mutation
-- Expected: Its complete row still matches the captured before-image
-- -----------------------------------------------------------------------------
SELECT is((SELECT to_jsonb(d) FROM public.draft_casefiles d JOIN dcf_unrelated u USING (draft_casefile_id)),
          (SELECT before_image FROM dcf_unrelated), 'unrelated draft remains unchanged');

SELECT * FROM finish();
ROLLBACK;
