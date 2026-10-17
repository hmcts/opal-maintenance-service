/**
 * OPAL Program
 *
 * MODULE      : p_insert_party_aliases_pgtap_tests.sql
 *
 * DESCRIPTION : Verify alias inputs, exact mapping, failures and caller ownership.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket        Nature of Change
 * ----------  -------------  ------------  ----------------------------------------
 * 17/10/2026  Frankie Moran  PO-10648      Initial pgTAP test suite.
 */

-- OPAL-DB-UPGRADE {"id":"p_insert_party_aliases.create","candidate":"ddl/V1_45__create_p_insert_party_aliases_procedure.sql","scope":"both","data":"migration-created-only","inputs":["src/main/resources/db/migration/ddl/V1_2__create_countries_table.sql","src/main/resources/db/migration/ddl/V1_6__create_business_units_table.sql","src/main/resources/db/migration/ddl/V1_14__create_draft_casefiles_table.sql","src/main/resources/db/migration/ddl/V1_20__create_parties_table.sql","src/main/resources/db/migration/ddl/V1_21__create_debtor_detail_table.sql","src/main/resources/db/migration/ddl/V1_22__create_third_party_contact_table.sql","src/main/resources/db/migration/ddl/V1_23__create_account_number_index_table.sql","src/main/resources/db/migration/ddl/V1_24__create_notes_table.sql","src/main/resources/db/migration/ddl/V1_25__create_aliases_table.sql","src/main/resources/db/migration/ddl/V1_26__create_respondent_accounts_table.sql","src/main/resources/db/migration/ddl/V1_27__create_creditor_accounts_table.sql","src/main/resources/db/migration/ddl/V1_28__create_respondent_account_parties_table.sql","src/main/resources/db/migration/ddl/V1_29__create_order_terms_table.sql","src/main/resources/db/migration/ddl/V1_30__add_draft_casefiles_account_id_foreign_key.sql","src/main/resources/db/migration/ddl/V1_40__create_p_insert_parties_procedure.sql","src/main/resources/db/migration/ddl/V1_44__alter_aliases_name_columns.sql"],"contract":{"type":"additive","objects":{"created":[{"kind":"routine","identity":"public.p_insert_party_aliases(bigint,json)"}],"replaced":[]},"preserve":{"rows":["public.aliases","public.parties","public.countries","public.draft_casefiles","public.creditor_accounts","public.respondent_accounts","public.respondent_account_parties","public.account_number_index","public.debtor_detail","public.third_party_contact","public.notes","public.order_terms","public.business_units"],"tables":["public.aliases","public.parties"],"routines":[],"enums":[],"sequences":["public.alias_id_seq","public.party_id_seq","public.country_id_seq"]},"assertion":"party_aliases.create"}}



\set ON_ERROR_STOP 1
\if :{?opal_assertion_group}
\else
  \set opal_assertion_group party_aliases.current
\endif
SELECT :'opal_assertion_group' IN ('party_aliases.current','party_aliases.create') AS pa_valid_group \gset
\if :pa_valid_group
\else
  DO $group$ BEGIN RAISE EXCEPTION 'Unknown Party aliases assertion group'; END; $group$;
\endif
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SET LOCAL search_path = public, pg_catalog;
SET LOCAL TIME ZONE 'UTC';
SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '5s';

-- -----------------------------------------------------------------------------
-- Scenario: Isolate alias fixtures and preserve unrelated publication state.
-- Setup: Collision-guarded synthetic Parties, Country, sentinel alias and Draft Casefile.
-- Expected: Existing data is never overwritten; every scoped row is compared exactly.
-- -----------------------------------------------------------------------------
DO $guard$
BEGIN
  IF EXISTS(SELECT 1 FROM public.countries WHERE country_id=-1064801 OR cjs_code=31048)
     OR EXISTS(SELECT 1 FROM public.parties WHERE party_id IN (-1064801,-1064802,-1064803,-1064804,-1064899))
     OR EXISTS(SELECT 1 FROM public.aliases WHERE alias_id IN (-1064890,-1064898))
     OR EXISTS(SELECT 1 FROM public.business_units WHERE business_unit_id=32048 OR business_unit_code='P048')
     OR EXISTS(SELECT 1 FROM public.draft_casefiles WHERE draft_casefile_id=-1064801)
     OR EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='po10648_alias_fault') THEN
    RAISE EXCEPTION 'Party aliases synthetic fixture collision';
  END IF;
END;
$guard$;
CREATE TEMP TABLE pa_party_sequence_before AS SELECT last_value,is_called FROM public.party_id_seq;
CREATE TEMP TABLE pa_country_sequence_before AS SELECT last_value,is_called FROM public.country_id_seq;
INSERT INTO public.countries(country_id,cjs_code,country_name,date_used_from,date_used_to,active)
VALUES(-1064801,31048,'Synthetic Alias Country',DATE '2000-01-01',NULL,true);
INSERT INTO public.parties(party_id,organisation,surname,address_line_1,restrict_personal_information,country_id,account_type)
VALUES(-1064801,false,'Synthetic target','Synthetic Road',false,-1064801,'Respondent'),
      (-1064802,true,NULL,'Synthetic Road',false,-1064801,'Respondent'),
      (-1064803,NULL,NULL,'Synthetic Road',false,-1064801,'Minor Creditor'),
      (-1064804,false,'Synthetic sentinel','Synthetic Road',false,-1064801,'Respondent');
INSERT INTO public.aliases(alias_id,party_id,surname,forenames,organisation_name,sequence_number)
VALUES(-1064890,-1064804,'Existing synthetic','Sentinel',NULL,5);
INSERT INTO public.business_units(business_unit_id,business_unit_code,business_unit_name,business_unit_type,welsh_language)
VALUES(32048,'P048','Synthetic Alias Area','Area',false);
INSERT INTO public.draft_casefiles(draft_casefile_id,business_unit_id,created_date,submitted_by,submitted_by_name,
  casefile,casefile_snapshot,casefile_type,casefile_status,casefile_status_date,timeline_data)
VALUES(-1064801,32048,TIMESTAMP '2026-01-01','synthetic','Synthetic fixture',
  '{"synthetic":"input"}','{"synthetic":"snapshot"}','REMO In','SUBMITTED',
  TIMESTAMP '2026-01-01','[{"synthetic":"timeline"}]');

CREATE FUNCTION pg_temp.pa_rows() RETURNS JSONB LANGUAGE plpgsql AS $rows$
DECLARE v_table TEXT; v_values JSONB; v_result JSONB := '{}';
BEGIN
  FOREACH v_table IN ARRAY ARRAY['aliases','parties','countries','draft_casefiles','creditor_accounts',
    'respondent_accounts','respondent_account_parties','account_number_index','debtor_detail',
    'third_party_contact','notes','order_terms','business_units'] LOOP
    EXECUTE FORMAT('SELECT COALESCE(JSONB_AGG(value ORDER BY value),''[]''::JSONB)
      FROM (SELECT ROW_TO_JSON(t)::TEXT AS value FROM public.%I t) r',v_table) INTO v_values;
    v_result := v_result || JSONB_BUILD_OBJECT(v_table,v_values);
  END LOOP;
  RETURN v_result;
END;
$rows$;

CREATE FUNCTION pg_temp.pa_probe(p_party BIGINT,p_raw TEXT,p_direct BOOLEAN DEFAULT false)
RETURNS JSONB LANGUAGE plpgsql AS $probe$
DECLARE v_state TEXT; v_message TEXT; v_detail TEXT; v_hint TEXT; v_schema TEXT;
  v_table TEXT; v_column TEXT; v_constraint TEXT; v_context TEXT; v_datatype TEXT;
BEGIN
  IF p_direct THEN
    INSERT INTO public.aliases(alias_id,party_id,surname,forenames,organisation_name,sequence_number)
    VALUES(-1064898,p_party,'Synthetic','Names',NULL,1);
  ELSE
    CALL public.p_insert_party_aliases(p_party,p_raw::JSON);
  END IF;
  RETURN JSONB_BUILD_OBJECT('state','00000');
EXCEPTION WHEN query_canceled OR assert_failure OR OTHERS THEN
  GET STACKED DIAGNOSTICS v_state=RETURNED_SQLSTATE,v_message=MESSAGE_TEXT,
    v_detail=PG_EXCEPTION_DETAIL,v_hint=PG_EXCEPTION_HINT,v_schema=SCHEMA_NAME,
    v_table=TABLE_NAME,v_column=COLUMN_NAME,v_constraint=CONSTRAINT_NAME,
    v_context=PG_EXCEPTION_CONTEXT,v_datatype=PG_DATATYPE_NAME;

  RETURN JSONB_BUILD_OBJECT('state',v_state,'message',v_message,'detail',v_detail,'hint',v_hint,
    'schema',v_schema,'table',v_table,'column',v_column,'constraint',v_constraint,
    'context',v_context,'datatype',v_datatype);
END;
$probe$;

CREATE TEMP TABLE pa_cases(
  label TEXT PRIMARY KEY,
  party_id BIGINT DEFAULT -1064801,
  raw_input TEXT,
  expected_state TEXT NOT NULL,
  expected_rows JSONB NOT NULL DEFAULT '[]',
  expected_diag JSONB NOT NULL DEFAULT '{}',
  seq_rule TEXT NOT NULL DEFAULT 'untouched',
  mode TEXT NOT NULL DEFAULT 'normal'
);

INSERT INTO pa_cases(label,party_id,raw_input,expected_state)
SELECT 'noop-'||p.label||'-'||a.label,p.id,a.raw,
  CASE WHEN p.label='valid' THEN '00000' ELSE 'P0001' END
FROM (VALUES('valid',-1064801::BIGINT),('null',NULL::BIGINT),('missing',-1064899::BIGINT)) p(label,id)
CROSS JOIN (VALUES('sql-null',NULL::TEXT),('empty','[]')) a(label,raw);
INSERT INTO pa_cases(label,raw_input,expected_state)
SELECT 'root-'||label,raw,'P0001' FROM (VALUES('null','null'),('object','{}'),('string','"text"'),
  ('array-looking-string','"[]"'),('number','1'),('true','true'),('false','false')) v(label,raw);
INSERT INTO pa_cases(label,raw_input,expected_state)
VALUES('malformed-json','[','22P02');
INSERT INTO pa_cases(label,raw_input,expected_state)
SELECT 'element-'||label,'['||raw||']','P0001' FROM (VALUES('null','null'),('array','[]'),
  ('string','"x"'),('number','1'),('true','true'),('false','false')) v(label,raw);

INSERT INTO pa_cases(label,raw_input,expected_state,expected_rows,seq_rule)
SELECT 'cardinality-'||n,
  (SELECT JSON_AGG(JSON_BUILD_OBJECT('sequence_number',CASE WHEN i=6 THEN 1 ELSE i END,
    'surname','Synthetic '||i,'forenames','Names') ORDER BY i)::TEXT
   FROM GENERATE_SERIES(1,n) i),
  CASE WHEN n<=5 THEN '00000' ELSE 'P0001' END,
  CASE WHEN n<=5 THEN (SELECT JSONB_AGG(JSONB_BUILD_OBJECT('party_id',-1064801,'surname','Synthetic '||i,
    'forenames','Names','organisation_name',NULL,'sequence_number',i)) FROM GENERATE_SERIES(1,n) i)
    ELSE '[]'::JSONB END,
  CASE WHEN n<=5 THEN 'generated' ELSE 'untouched' END
FROM GENERATE_SERIES(1,6) n;

CREATE TEMP TABLE pa_shapes(label TEXT PRIMARY KEY,wire JSONB,expected JSONB);
INSERT INTO pa_shapes VALUES
('individual','{"sequence_number":1,"surname":"Synthetic","forenames":"Names"}',
 '{"surname":"Synthetic","forenames":"Names","organisation_name":null,"sequence_number":1}'),
('organisation','{"sequence_number":3,"organisation_name":"Synthetic organisation"}',
 '{"surname":null,"forenames":null,"organisation_name":"Synthetic organisation","sequence_number":3}');
INSERT INTO pa_cases(label,party_id,raw_input,expected_state,expected_rows,seq_rule)
SELECT s.label||'-party-'||p.id,p.id,JSONB_BUILD_ARRAY(s.wire)::TEXT,'00000',
  JSONB_BUILD_ARRAY(s.expected||JSONB_BUILD_OBJECT('party_id',p.id)),'generated'
FROM pa_shapes s CROSS JOIN (VALUES(-1064801),(-1064802),(-1064803)) p(id);
INSERT INTO pa_cases(label,party_id,raw_input,expected_state,expected_rows,seq_rule)
SELECT 'mixed-party-'||p.id,p.id,
  '[{"sequence_number":5,"organisation_name":"Synthetic organisation"},{"sequence_number":2,"surname":"Synthetic","forenames":"Names"}]',
  '00000',JSONB_BUILD_ARRAY(
    JSONB_BUILD_OBJECT('party_id',p.id,'surname',NULL,'forenames',NULL,'organisation_name','Synthetic organisation','sequence_number',5),
    JSONB_BUILD_OBJECT('party_id',p.id,'surname','Synthetic','forenames','Names','organisation_name',NULL,'sequence_number',2)),
  'generated'
FROM (VALUES(-1064801),(-1064802),(-1064803)) p(id);
INSERT INTO pa_cases(label,party_id,raw_input,expected_state)
VALUES('populated-null-party',NULL,'[{"sequence_number":1,"surname":"Synthetic","forenames":"Names"}]','23502'),
('populated-missing-party',-1064899,'[{"sequence_number":1,"surname":"Synthetic","forenames":"Names"}]','23503');
UPDATE pa_cases SET seq_rule='may-consume' WHERE label LIKE 'populated-%-party';

INSERT INTO pa_cases(label,raw_input,expected_state)
VALUES('sequence-only','[{"sequence_number":1}]','P0001'),
('empty-object','[{}]','P0001'),
('surname-only','[{"sequence_number":1,"surname":"Synthetic"}]','P0001'),
('forenames-only','[{"sequence_number":1,"forenames":"Names"}]','P0001'),
('combined','[{"sequence_number":1,"surname":"Synthetic","forenames":"Names","organisation_name":"Synthetic organisation"}]','P0001'),
('forbidden-org-null','[{"sequence_number":1,"surname":"Synthetic","forenames":"Names","organisation_name":null}]','P0001'),
('forbidden-surname-null','[{"sequence_number":1,"organisation_name":"Synthetic organisation","surname":null}]','P0001'),
('forbidden-forenames-null','[{"sequence_number":1,"organisation_name":"Synthetic organisation","forenames":null}]','P0001');
INSERT INTO pa_cases(label,raw_input,expected_state)
SELECT 'type-'||s.label||'-'||f.key||'-'||v.label,
  JSONB_BUILD_ARRAY(JSONB_SET(s.wire,ARRAY[f.key],v.value))::TEXT,'P0001'
FROM pa_shapes s CROSS JOIN LATERAL JSONB_OBJECT_KEYS(s.wire) f(key)
CROSS JOIN (VALUES('null','null'::JSONB),('number','4'::JSONB),('boolean','true'::JSONB),
  ('object','{}'::JSONB),('array','[]'::JSONB)) v(label,value)
WHERE f.key<>'sequence_number';
INSERT INTO pa_cases(label,raw_input,expected_state)
SELECT 'unknown-'||s.label||'-'||v.label,JSONB_BUILD_ARRAY(s.wire||JSONB_BUILD_OBJECT(v.key,'__private_alias_marker__'))::TEXT,'P0001'
FROM pa_shapes s CROSS JOIN (VALUES('plain','__private_alias_marker__'),('case','Sequence_number'),
  ('name-case','Surname')) v(label,key);
INSERT INTO pa_cases(label,raw_input,expected_state)
VALUES('repeat-same','[{"sequence_number":1,"surname":"Synthetic","surname":"Synthetic","forenames":"Names"}]','P0001'),
('repeat-different','[{"sequence_number":1,"surname":"Synthetic","surname":"Other","forenames":"Names"}]','P0001'),
('repeat-escaped','[{"sequence_number":1,"surname":"Synthetic","surn\u0061me":"Synthetic","forenames":"Names"}]','P0001'),
('repeat-sequence','[{"sequence_number":1,"sequence_number":1,"surname":"Synthetic","forenames":"Names"}]','P0001'),
('repeat-org','[{"sequence_number":1,"organisation_name":"Synthetic","organisation_name":"Synthetic"}]','P0001'),
('escaped-unknown','[{"sequence_number":1,"surname":"Synthetic","forenames":"Names","\u005f_private_alias_marker__":1}]','P0001');
INSERT INTO pa_cases(label,raw_input,expected_state,expected_rows,seq_rule)
VALUES('escaped-known','[{"sequence_\u006eumber":1,"surn\u0061me":"Synthet\u0069c","forenames":"Names"}]','00000',
 '[{"party_id":-1064801,"surname":"Synthetic","forenames":"Names","organisation_name":null,"sequence_number":1}]','generated');

INSERT INTO pa_cases(label,raw_input,expected_state)
SELECT 'repeat-matrix-'||s.label||'-'||f.key||'-'||v.label,
  '['||LEFT(s.wire::TEXT,-1)||','||TO_JSON(f.key)::TEXT||':'||v.value||'}]','P0001'
FROM pa_shapes s CROSS JOIN LATERAL JSONB_EACH(s.wire) f(key,value)
CROSS JOIN LATERAL (VALUES('same',f.value::TEXT),('different',
  CASE WHEN f.key='sequence_number' THEN '2' ELSE '"Different synthetic"' END)) v(label,value);

CREATE TEMP TABLE pa_fields(shape TEXT,key TEXT,max_length INTEGER);
INSERT INTO pa_fields VALUES('individual','surname',40),('individual','forenames',40),
  ('organisation','organisation_name',80);
CREATE TEMP TABLE pa_text_vectors(label TEXT,value TEXT,valid BOOLEAN);
INSERT INTO pa_text_vectors VALUES('empty','',false),('spaced',' Synthetic ',true),
  ('escaped-decoded',E'Synthetic\nAlias',true),('decomposed',U&'e\0301',true),
  ('supplementary',CHR(128512),true),('FEFF',CHR(65279),true),('zero-width-space',CHR(8203),true),
  ('word-joiner',CHR(8288),true);
INSERT INTO pa_text_vectors
SELECT 'White_Space-'||cp,CHR(cp),false
FROM (SELECT GENERATE_SERIES(9,13) cp UNION ALL SELECT 32 UNION ALL SELECT 133 UNION ALL SELECT 160
  UNION ALL SELECT 5760 UNION ALL SELECT GENERATE_SERIES(8192,8202) UNION ALL SELECT 8232
  UNION ALL SELECT 8233 UNION ALL SELECT 8239 UNION ALL SELECT 8287 UNION ALL SELECT 12288) u;
INSERT INTO pa_text_vectors
SELECT 'White_Space-mixture',STRING_AGG(CHR(cp),'' ORDER BY cp),false
FROM (SELECT GENERATE_SERIES(9,13) cp UNION ALL SELECT 32 UNION ALL SELECT 133 UNION ALL SELECT 160
  UNION ALL SELECT 5760 UNION ALL SELECT GENERATE_SERIES(8192,8202) UNION ALL SELECT 8232
  UNION ALL SELECT 8233 UNION ALL SELECT 8239 UNION ALL SELECT 8287 UNION ALL SELECT 12288) u;
INSERT INTO pa_cases(label,raw_input,expected_state,expected_rows,seq_rule)
SELECT 'name-'||f.key||'-'||v.label,
  JSONB_BUILD_ARRAY(JSONB_SET(s.wire,ARRAY[f.key],TO_JSONB(v.value)))::TEXT,
  CASE WHEN v.valid THEN '00000' ELSE 'P0001' END,
  CASE WHEN v.valid THEN JSONB_BUILD_ARRAY(s.expected||JSONB_BUILD_OBJECT(f.key,v.value,'party_id',-1064801))
    ELSE '[]'::JSONB END,
  CASE WHEN v.valid THEN 'generated' ELSE 'untouched' END
FROM pa_fields f JOIN pa_shapes s ON s.label=f.shape CROSS JOIN pa_text_vectors v;

INSERT INTO pa_cases(label,raw_input,expected_state,expected_rows,seq_rule)
SELECT 'length-'||f.key||'-'||v.label,
  JSONB_BUILD_ARRAY(JSONB_SET(s.wire,ARRAY[f.key],TO_JSONB(v.value)))::TEXT,
  CASE WHEN v.valid THEN '00000' ELSE 'P0001' END,
  CASE WHEN v.valid THEN JSONB_BUILD_ARRAY(s.expected||JSONB_BUILD_OBJECT(f.key,v.value,'party_id',-1064801))
    ELSE '[]'::JSONB END,
  CASE WHEN v.valid THEN 'generated' ELSE 'untouched' END
FROM pa_fields f JOIN pa_shapes s ON s.label=f.shape
CROSS JOIN LATERAL (VALUES
  ('ascii-max',REPEAT('A',f.max_length),true),('ascii-over',REPEAT('A',f.max_length+1),false),
  ('padded-max',' '||REPEAT('A',f.max_length-2)||' ',true),
  ('padded-over','A'||REPEAT(' ',f.max_length),false),
  ('multibyte-max',REPEAT('é',f.max_length),true),('multibyte-over',REPEAT('é',f.max_length+1),false),
  ('supplementary-max',REPEAT(CHR(128512),f.max_length),true),
  ('supplementary-over',REPEAT(CHR(128512),f.max_length+1),false),
  ('decomposed-max',REPEAT(U&'e\0301',f.max_length/2),true),
  ('decomposed-over',REPEAT(U&'e\0301',f.max_length/2)||'A',false)
) v(label,value,valid);

INSERT INTO pa_cases(label,raw_input,expected_state,expected_rows,seq_rule)
SELECT 'escaped-boundary-'||f.key||'-'||n,
  '['||LEFT((s.wire-f.key)::TEXT,-1)||','||TO_JSON(f.key)::TEXT||':"'||REPEAT('\u00e9',n)||'"}]',
  CASE WHEN n=f.max_length THEN '00000' ELSE 'P0001' END,
  CASE WHEN n=f.max_length THEN JSONB_BUILD_ARRAY(s.expected||JSONB_BUILD_OBJECT(f.key,REPEAT('é',n),'party_id',-1064801))
    ELSE '[]'::JSONB END,
  CASE WHEN n=f.max_length THEN 'generated' ELSE 'untouched' END
FROM pa_fields f JOIN pa_shapes s ON s.label=f.shape
CROSS JOIN LATERAL GENERATE_SERIES(f.max_length,f.max_length+1) n;

INSERT INTO pa_cases(label,raw_input,expected_state,expected_rows,seq_rule)
SELECT 'sequence-valid-'||v.token,
  '[{"sequence_number":'||v.token||',"surname":"Synthetic","forenames":"Names"}]','00000',
  JSONB_BUILD_ARRAY(JSONB_BUILD_OBJECT('party_id',-1064801,'surname','Synthetic','forenames','Names',
    'organisation_name',NULL,'sequence_number',v.expected)),'generated'
FROM (VALUES('1',1),('2',2),('3',3),('4',4),('5',5),('1.0',1),('1e0',1),('5.000',5),('50e-1',5)) v(token,expected);
INSERT INTO pa_cases(label,raw_input,expected_state)
SELECT 'sequence-invalid-'||v.label,
  '[{"sequence_number":'||v.token||',"surname":"Synthetic","forenames":"Names"}]','P0001'
FROM (VALUES('null','null'),('string','"1"'),('boolean','true'),('object','{}'),('array','[]'),
  ('fraction','1.5'),('precise-fraction','1.0000000000000000001'),('zero','0'),('negative','-1'),
  ('six','6'),('decimal-below','0.9999999999999999999'),('decimal-above','5.0000000000000000001')) v(label,token);
INSERT INTO pa_cases(label,raw_input,expected_state)
VALUES('sequence-missing','[{"surname":"Synthetic","forenames":"Names"}]','P0001');
INSERT INTO pa_cases(label,raw_input,expected_state,expected_rows,seq_rule)
VALUES('shuffled-gapped-duplicates',
 '[{"sequence_number":5,"surname":"A","forenames":"Names"},{"sequence_number":2,"surname":"B","forenames":"Names"},{"sequence_number":2,"surname":"B","forenames":"Names"}]',
 '00000','[{"party_id":-1064801,"surname":"A","forenames":"Names","organisation_name":null,"sequence_number":5},{"party_id":-1064801,"surname":"B","forenames":"Names","organisation_name":null,"sequence_number":2},{"party_id":-1064801,"surname":"B","forenames":"Names","organisation_name":null,"sequence_number":2}]','generated'),
('late-invalid','[{"sequence_number":1,"surname":"Valid","forenames":"Names"},{"sequence_number":2,"surname":"Valid","forenames":"Names"},{"sequence_number":1.0000000000000000001,"surname":"Invalid","forenames":"Names"}]',
 'P0001','[]','untouched');

CREATE SEQUENCE pg_temp.pa_attempts START 1;
CREATE FUNCTION pg_temp.pa_inject() RETURNS TRIGGER LANGUAGE plpgsql AS $inject$
DECLARE v_mode TEXT := CURRENT_SETTING('opal.alias_test_mode',true); v_attempt BIGINT;
BEGIN
  IF v_mode IS NULL OR v_mode='normal' THEN RETURN NEW; END IF;
  v_attempt := NEXTVAL('pg_temp.pa_attempts');

  IF v_mode='native-id' THEN
    NEW.alias_id := -1064898;
    RETURN NEW;
  END IF;

  IF v_mode='suppress-all' OR (v_mode='suppress-part' AND NEW.sequence_number=2) THEN
    RETURN NULL;
  END IF;

  IF v_mode LIKE 'late:%' AND v_attempt=2 THEN
    RAISE EXCEPTION USING ERRCODE=SUBSTRING(v_mode FROM 6),
      MESSAGE='synthetic Alias diagnostic',DETAIL='synthetic Alias detail',HINT='synthetic Alias hint',
      SCHEMA='public',TABLE='aliases',COLUMN='party_id',CONSTRAINT='pa_synthetic_diagnostic';
  END IF;

  RETURN NEW;
END;
$inject$;
CREATE TRIGGER po10648_alias_fault BEFORE INSERT ON public.aliases
FOR EACH ROW EXECUTE FUNCTION pg_temp.pa_inject();
CREATE TEMP TABLE pa_results(label TEXT PRIMARY KEY,result JSONB,rows_before JSONB,rows_after JSONB,
  seq_before BIGINT,called_before BOOLEAN,seq_after BIGINT,called_after BOOLEAN,
  attempts BIGINT,attempts_called BOOLEAN);
CREATE TEMP TABLE pa_checks(label TEXT PRIMARY KEY,passed BOOLEAN);

SELECT SET_CONFIG('opal.alias_test_mode','native-id',true);
UPDATE pa_cases SET expected_diag=pg_temp.pa_probe(party_id,NULL,true)-'context',mode='native-id'
WHERE label IN ('populated-null-party','populated-missing-party');
SELECT SET_CONFIG('opal.alias_test_mode','normal',true);
INSERT INTO pa_cases(label,raw_input,expected_state,seq_rule,mode,expected_diag)
SELECT 'fault-'||v.mode,
  '[{"sequence_number":1,"surname":"Synthetic first","forenames":"Names"},{"sequence_number":2,"organisation_name":"Synthetic second"},{"sequence_number":3,"surname":"Synthetic third","forenames":"Names"}]',
  v.state,'may-consume',v.mode,
  CASE WHEN v.mode LIKE 'late:%' THEN JSONB_BUILD_OBJECT('state',v.state,'message','synthetic Alias diagnostic',
    'detail','synthetic Alias detail','hint','synthetic Alias hint','schema','public','table','aliases',
    'column','party_id','constraint','pa_synthetic_diagnostic','datatype','')
    ELSE '{"message":"p_insert_party_aliases: insert batch: incomplete insertion"}'::JSONB END
FROM (VALUES('suppress-part','P0001'),('suppress-all','P0001'),('late:22001','22001'),
  ('late:23503','23503'),('late:40001','40001'),('late:40P01','40P01'),('late:57014','57014'),('late:P0004','P0004')) v(mode,state);
INSERT INTO pa_checks(label)
SELECT 'fault-observation-'||label FROM pa_cases
WHERE mode<>'normal';

CREATE FUNCTION pg_temp.pa_native_text(p_raw TEXT) RETURNS JSONB LANGUAGE plpgsql AS $native$
DECLARE s TEXT; m TEXT; d TEXT; h TEXT; ns TEXT; t TEXT; col TEXT; con TEXT; typ TEXT;
BEGIN
  PERFORM p_raw::JSON->0->>'surname';
  RETURN JSONB_BUILD_OBJECT('state','00000');
EXCEPTION WHEN OTHERS THEN
  GET STACKED DIAGNOSTICS s=RETURNED_SQLSTATE,m=MESSAGE_TEXT,d=PG_EXCEPTION_DETAIL,h=PG_EXCEPTION_HINT,
    ns=SCHEMA_NAME,t=TABLE_NAME,col=COLUMN_NAME,con=CONSTRAINT_NAME,typ=PG_DATATYPE_NAME;
  RETURN JSONB_BUILD_OBJECT('state',s,'message',m,'detail',d,'hint',h,'schema',ns,'table',t,
    'column',col,'constraint',con,'datatype',typ);
END;
$native$;
INSERT INTO pa_cases(label,raw_input,expected_state,expected_diag)
SELECT 'native-text-escape',v.raw,d.diag->>'state',d.diag
FROM (VALUES('[{"sequence_number":1,"surname":"\u0000","forenames":"Names"}]')) v(raw)
CROSS JOIN LATERAL (SELECT pg_temp.pa_native_text(v.raw) diag) d;
INSERT INTO pa_checks(label) VALUES('native-text-error-observed');

INSERT INTO pa_checks(label) VALUES
('repeat-appends-six'),('repeat-new-identities'),('repeat-originals-preserved'),
('caller-sentinel-survives-failed-call'),('successful-call-visible'),('caller-rollback-removes-aliases'),
('caller-rollback-restores-scope'),('caller-rollback-retains-sequence-gap'),
('provider-party-id-handoff'),('provider-handoff-rollback'),
('owned-trigger-removed'),('owned-trigger-function-removed'),('owned-probes-removed'),
('Party-sequence-unchanged-before-provider'),('Country-sequence-unchanged'),
('whitespace-vector-count'),('raw-escape-setting'),('malformed-fails-before-entry');

UPDATE pa_cases SET expected_diag=expected_diag||
  '{"message":"p_insert_party_aliases: validate alias 1: invalid members"}'::JSONB
WHERE label LIKE 'unknown-%' OR label LIKE 'repeat-%' OR label='escaped-unknown';
UPDATE pa_cases SET expected_diag=
  '{"detail":"","hint":"","schema":"","table":"","column":"","constraint":"","datatype":""}'::JSONB
  ||expected_diag
WHERE expected_state='P0001' AND mode='normal';

-- -----------------------------------------------------------------------------
-- Scenario: Deliberate validation failures expose only fixed safe labels.
-- Setup: Assign independent exact expectations to each single-invalid vector.
-- Expected: No submitted value, decoded untrusted key, Party ID or raw JSON leaks.
-- -----------------------------------------------------------------------------
UPDATE pa_cases SET expected_diag=expected_diag||JSONB_BUILD_OBJECT('message',CASE
  WHEN label LIKE 'noop-%' THEN 'p_insert_party_aliases: validate target: existing Party required'
  WHEN label LIKE 'root-%' THEN 'p_insert_party_aliases: validate collection: array required'
  WHEN label='cardinality-6' THEN 'p_insert_party_aliases: validate collection: too many aliases'
  WHEN label LIKE 'element-%' THEN 'p_insert_party_aliases: validate alias 1: object required'
  WHEN label IN ('empty-object','sequence-only') OR label LIKE 'type-organisation-%'
    THEN 'p_insert_party_aliases: validate alias 1: organisation shape invalid'
  WHEN label IN ('surname-only','forenames-only','combined') OR label LIKE 'forbidden-%'
    OR label LIKE 'type-individual-%'
    THEN 'p_insert_party_aliases: validate alias 1: individual shape invalid'
  WHEN label LIKE 'name-surname-%' OR label LIKE 'length-surname-%' OR label LIKE 'escaped-boundary-surname-%'
    THEN 'p_insert_party_aliases: validate alias 1: surname blank or over length'
  WHEN label LIKE 'name-forenames-%' OR label LIKE 'length-forenames-%' OR label LIKE 'escaped-boundary-forenames-%'
    THEN 'p_insert_party_aliases: validate alias 1: forenames blank or over length'
  WHEN label LIKE 'name-organisation_name-%' OR label LIKE 'length-organisation_name-%'
    OR label LIKE 'escaped-boundary-organisation_name-%'
    THEN 'p_insert_party_aliases: validate alias 1: organisation_name blank or over length'
  WHEN label IN ('sequence-missing','sequence-invalid-null','sequence-invalid-string','sequence-invalid-boolean',
    'sequence-invalid-object','sequence-invalid-array')
    THEN 'p_insert_party_aliases: validate alias 1: sequence_number must be numeric'
  WHEN label LIKE 'sequence-invalid-%'
    THEN 'p_insert_party_aliases: validate alias 1: sequence_number must be integral in range'
  WHEN label='late-invalid'
    THEN 'p_insert_party_aliases: validate alias 3: sequence_number must be integral in range'
  ELSE 'Unmapped synthetic expected diagnostic'
END)
WHERE expected_state='P0001' AND mode='normal' AND NOT(expected_diag ? 'message');


CREATE FUNCTION pg_temp.pa_run_cases() RETURNS SETOF TEXT LANGUAGE plpgsql AS $run$
DECLARE c pa_cases%ROWTYPE; b JSONB; a JSONB; r JSONB; old_ids BIGINT[];
  actual JSONB; expected JSONB; seq_before BIGINT; called_before BOOLEAN;
  seq_after BIGINT; called_after BOOLEAN; n INTEGER;
BEGIN
  FOR c IN SELECT * FROM pa_cases ORDER BY label LOOP
    b := pg_temp.pa_rows();
    SELECT COALESCE(ARRAY_AGG(alias_id),'{}'::BIGINT[]) INTO old_ids FROM public.aliases;
    SELECT last_value,is_called INTO seq_before,called_before FROM public.alias_id_seq;
    PERFORM SET_CONFIG('opal.alias_test_mode',c.mode,true);
    PERFORM SETVAL('pg_temp.pa_attempts',1,false);
    r := pg_temp.pa_probe(c.party_id,c.raw_input);
    a := pg_temp.pa_rows();
    SELECT last_value,is_called INTO seq_after,called_after FROM public.alias_id_seq;

    INSERT INTO pa_results
    SELECT c.label,r,b,a,seq_before,called_before,seq_after,called_after,last_value,is_called
    FROM pg_temp.pa_attempts;

    SELECT COALESCE(JSONB_AGG(value ORDER BY value),'[]'::JSONB) INTO actual
    FROM (SELECT TO_JSONB(t)-'alias_id' value FROM public.aliases t WHERE NOT(alias_id=ANY(old_ids))) q;
    SELECT COALESCE(JSONB_AGG(value ORDER BY value),'[]'::JSONB) INTO expected
    FROM JSONB_ARRAY_ELEMENTS(c.expected_rows);
    n := JSONB_ARRAY_LENGTH(c.expected_rows);
    RETURN NEXT is(r->>'state',c.expected_state,c.label||': SQLSTATE');
    RETURN NEXT is(actual,expected,c.label||': exact new rows, count, names, Party and supplied sequences');
    RETURN NEXT ok((b-'aliases') IS NOT DISTINCT FROM (a-'aliases')
      AND NOT EXISTS(SELECT 1 FROM JSONB_ARRAY_ELEMENTS_TEXT(b->'aliases') old
        WHERE NOT EXISTS(SELECT 1 FROM public.aliases t WHERE ROW_TO_JSON(t)::TEXT=old.value))
      AND (c.expected_state='00000' OR a=b),c.label||': exact scoped and existing alias preservation');
    RETURN NEXT ok(CASE c.seq_rule
      WHEN 'untouched' THEN seq_after=seq_before AND called_after=called_before
      WHEN 'generated' THEN called_after AND seq_after=seq_before+n-CASE WHEN called_before THEN 0 ELSE 1 END
        AND (SELECT COUNT(DISTINCT alias_id)=n FROM public.aliases WHERE NOT(alias_id=ANY(old_ids)))
      WHEN 'may-consume' THEN true ELSE false END,c.label||': declared sequence effects and fresh identities');
    RETURN NEXT ok(r @> c.expected_diag
      AND (c.expected_state<>'P0001' OR c.mode<>'normal' OR (
        POSITION('__private_alias_marker__' IN COALESCE(r->>'message',''))=0
        AND POSITION('Synthetic' IN COALESCE(r->>'message',''))=0
        AND POSITION('-10648' IN COALESCE(r->>'message',''))=0
        AND r->>'message' LIKE 'p_insert_party_aliases:%')),
      c.label||': required diagnostics and safe deliberate labels');
  END LOOP;
  PERFORM SET_CONFIG('opal.alias_test_mode','normal',true);
END;
$run$;

SELECT plan(6 + 5*(SELECT COUNT(*)::INTEGER FROM pa_cases)
  + (SELECT COUNT(*)::INTEGER FROM pa_checks));

SELECT ok((SELECT prokind='p' AND prorettype='void'::REGTYPE
  FROM pg_proc WHERE oid=TO_REGPROCEDURE('public.p_insert_party_aliases(bigint,json)')),
  'public aliases helper is a procedure returning no value');
SELECT ok((SELECT proargnames=ARRAY['pi_party_id','pi_aliases_json']
  AND pronargs=2 AND proargtypes='20 114'::OIDVECTOR
  AND proallargtypes IS NULL AND proargmodes IS NULL
  FROM pg_proc WHERE oid=TO_REGPROCEDURE('public.p_insert_party_aliases(bigint,json)')),
  'exact ordered BIGINT JSON IN arguments and no output');
SELECT is((SELECT JSONB_BUILD_ARRAY(l.lanname::TEXT,p.prosecdef,p.proisstrict,
  p.provolatile::TEXT,p.proparallel::TEXT,p.pronargdefaults,p.proconfig)
  FROM pg_proc p JOIN pg_language l ON l.oid=p.prolang
  WHERE p.oid=TO_REGPROCEDURE('public.p_insert_party_aliases(bigint,json)')),
  '["plpgsql",false,false,"v","u",0,null]'::JSONB,'effective defaults and invoker behavior');
SELECT is(OBJ_DESCRIPTION(TO_REGPROCEDURE('public.p_insert_party_aliases(bigint,json)'),'pg_proc'),
  'Insert zero-to-five aliases for one existing Party with exact names and supplied sequences; caller owns transaction and publication.',
  'comment states mapping and ownership');
SELECT is((SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname='p_insert_party_aliases'),1::BIGINT,
  'exactly one public overload');
SELECT ok(CURRENT_SETTING('server_encoding')='UTF8' AND CURRENT_SETTING('client_encoding')='UTF8',
  'UTF-8 supports decoded character boundary tests');

SELECT * FROM pg_temp.pa_run_cases();

UPDATE pa_checks k SET passed=(
  r.rows_after=r.rows_before AND r.attempts_called
  AND r.attempts=CASE WHEN c.mode='native-id' THEN 1 WHEN c.mode LIKE 'late:%' THEN 2 ELSE 3 END
  AND r.called_after
  AND r.seq_after=r.seq_before+CASE WHEN c.mode='native-id' THEN 1 WHEN c.mode LIKE 'late:%' THEN 2 ELSE 3 END
    -CASE WHEN r.called_before THEN 0 ELSE 1 END
  AND (c.mode NOT LIKE 'late:%' OR (
    r.result->>'context' LIKE '%pa_inject()%'
    AND r.result->>'context' LIKE '%p_insert_party_aliases%'))
  AND (c.label<>'populated-missing-party' OR r.result->>'constraint'='als_party_id_fk')
  AND (c.label<>'populated-null-party' OR (r.result->>'table'='aliases' AND r.result->>'column'='party_id'))
)
FROM pa_cases c JOIN pa_results r USING(label)
WHERE k.label='fault-observation-'||c.label;

SELECT SET_CONFIG('opal.alias_test_mode','normal',true);
SELECT pg_temp.pa_rows()::TEXT AS pa_repeat_before \gset
SELECT ARRAY_AGG(alias_id)::TEXT AS pa_repeat_old_ids FROM public.aliases \gset
CALL public.p_insert_party_aliases(-1064803,
  '[{"sequence_number":4,"surname":"Repeat","forenames":"One"},{"sequence_number":4,"surname":"Repeat","forenames":"One"},{"sequence_number":1,"organisation_name":"Repeat organisation"}]');
SELECT ARRAY_AGG(alias_id)::TEXT AS pa_repeat_first_ids FROM public.aliases
WHERE NOT(alias_id=ANY(:'pa_repeat_old_ids'::BIGINT[])) \gset
CALL public.p_insert_party_aliases(-1064803,
  '[{"sequence_number":4,"surname":"Repeat","forenames":"One"},{"sequence_number":4,"surname":"Repeat","forenames":"One"},{"sequence_number":1,"organisation_name":"Repeat organisation"}]');
UPDATE pa_checks SET passed=(SELECT COUNT(*)=6 AND COUNT(*) FILTER(WHERE sequence_number=4)=4
  AND COUNT(*) FILTER(WHERE sequence_number=1)=2
  FROM public.aliases WHERE NOT(alias_id=ANY(:'pa_repeat_old_ids'::BIGINT[])))
WHERE label='repeat-appends-six';
UPDATE pa_checks SET passed=(SELECT COUNT(DISTINCT alias_id)=6
  AND COUNT(*) FILTER(WHERE alias_id=ANY(:'pa_repeat_first_ids'::BIGINT[]))=3
  FROM public.aliases WHERE NOT(alias_id=ANY(:'pa_repeat_old_ids'::BIGINT[])))
WHERE label='repeat-new-identities';
UPDATE pa_checks SET passed=(
  (pg_temp.pa_rows()-'aliases')=(:'pa_repeat_before'::JSONB-'aliases')
  AND NOT EXISTS(SELECT 1 FROM JSONB_ARRAY_ELEMENTS_TEXT(:'pa_repeat_before'::JSONB->'aliases') old
    WHERE NOT EXISTS(SELECT 1 FROM public.aliases a WHERE ROW_TO_JSON(a)::TEXT=old.value)))
WHERE label='repeat-originals-preserved';

INSERT INTO public.aliases(alias_id,party_id,surname,forenames,organisation_name,sequence_number)
VALUES(-1064898,-1064804,'Caller sentinel','Names',NULL,2);
SELECT pg_temp.pa_rows()::TEXT AS pa_sentinel_before \gset
SELECT SET_CONFIG('opal.alias_test_mode','late:23503',true);
SELECT SETVAL('pg_temp.pa_attempts',1,false);
SELECT pg_temp.pa_probe(-1064801,
  '[{"sequence_number":1,"surname":"First","forenames":"Names"},{"sequence_number":2,"surname":"Second","forenames":"Names"}]')::TEXT
  AS pa_failed_result \gset
SELECT SET_CONFIG('opal.alias_test_mode','normal',true);
UPDATE pa_checks SET passed=(pg_temp.pa_rows()=:'pa_sentinel_before'::JSONB
  AND :'pa_failed_result'::JSONB->>'state'='23503'
  AND EXISTS(SELECT 1 FROM public.aliases WHERE alias_id=-1064898 AND surname='Caller sentinel'))
WHERE label='caller-sentinel-survives-failed-call';

SELECT pg_temp.pa_rows()::TEXT AS pa_before_rollback \gset
SELECT ARRAY_AGG(alias_id)::TEXT AS pa_before_rollback_ids FROM public.aliases \gset
SAVEPOINT pa_caller_owned;
CALL public.p_insert_party_aliases(-1064801,'[{"sequence_number":5,"surname":"Rollback","forenames":"Names"}]');
SELECT EXISTS(SELECT 1 FROM public.aliases WHERE NOT(alias_id=ANY(:'pa_before_rollback_ids'::BIGINT[])))
  AS pa_visible \gset
SELECT last_value::TEXT AS pa_consumed FROM public.alias_id_seq \gset
ROLLBACK TO SAVEPOINT pa_caller_owned;
RELEASE SAVEPOINT pa_caller_owned;
UPDATE pa_checks SET passed=:'pa_visible'::BOOLEAN WHERE label='successful-call-visible';
UPDATE pa_checks SET passed=NOT EXISTS(SELECT 1 FROM public.aliases WHERE alias_id=:'pa_consumed'::BIGINT)
WHERE label='caller-rollback-removes-aliases';
UPDATE pa_checks SET passed=pg_temp.pa_rows()=:'pa_before_rollback'::JSONB
WHERE label='caller-rollback-restores-scope';
UPDATE pa_checks SET passed=(SELECT is_called AND last_value=:'pa_consumed'::BIGINT FROM public.alias_id_seq)
WHERE label='caller-rollback-retains-sequence-gap';

UPDATE pa_checks SET passed=(SELECT ROW(last_value,is_called) IS NOT DISTINCT FROM
  (SELECT ROW(last_value,is_called) FROM pa_party_sequence_before) FROM public.party_id_seq)
WHERE label='Party-sequence-unchanged-before-provider';
SELECT pg_temp.pa_rows()::TEXT AS pa_before_handoff \gset
SAVEPOINT pa_provider_handoff;
DO $handoff$
DECLARE v_id BIGINT;
BEGIN
  CALL public.p_insert_parties(
    '{"organisation":false,"individual_details":{"surname":"Synthetic provider"},"address":{"address_line_1":"Synthetic Road","cjs_code":31048}}',
    'Respondent'::public.t_party_account_type_enum,v_id);
  CALL public.p_insert_party_aliases(v_id,'[{"sequence_number":3,"organisation_name":"Synthetic handoff alias"}]');
  PERFORM SET_CONFIG('opal.alias_handoff_party',v_id::TEXT,true);
END;
$handoff$;
SELECT (EXISTS(SELECT 1 FROM public.aliases a JOIN public.parties p USING(party_id)
  WHERE p.party_id=CURRENT_SETTING('opal.alias_handoff_party')::BIGINT
    AND p.surname='Synthetic provider' AND a.sequence_number=3
    AND a.organisation_name='Synthetic handoff alias' AND a.surname IS NULL AND a.forenames IS NULL))
  AS pa_handoff_ok \gset
ROLLBACK TO SAVEPOINT pa_provider_handoff;
RELEASE SAVEPOINT pa_provider_handoff;
UPDATE pa_checks SET passed=:'pa_handoff_ok'::BOOLEAN WHERE label='provider-party-id-handoff';
UPDATE pa_checks SET passed=pg_temp.pa_rows()=:'pa_before_handoff'::JSONB
WHERE label='provider-handoff-rollback';

UPDATE pa_checks SET passed=(SELECT COUNT(*)=25 FROM pa_text_vectors WHERE label LIKE 'White_Space-%'
  AND label<>'White_Space-mixture') WHERE label='whitespace-vector-count';
UPDATE pa_checks SET passed=CURRENT_SETTING('standard_conforming_strings')='on' WHERE label='raw-escape-setting';
UPDATE pa_checks SET passed=(SELECT result->>'state'='22P02'
  AND POSITION('PL/pgSQL function p_insert_party_aliases(' IN COALESCE(result->>'context',''))=0
  AND rows_before=rows_after AND seq_before=seq_after AND called_before=called_after
  FROM pa_results WHERE label='malformed-json') WHERE label='malformed-fails-before-entry';
UPDATE pa_checks SET passed=(SELECT result->>'state' NOT IN ('00000','P0001')
  AND result->>'context' LIKE '%p_insert_party_aliases%'
  FROM pa_results WHERE label='native-text-escape') WHERE label='native-text-error-observed';
UPDATE pa_checks SET passed=(SELECT ROW(last_value,is_called) IS NOT DISTINCT FROM
  (SELECT ROW(last_value,is_called) FROM pa_country_sequence_before) FROM public.country_id_seq)
WHERE label='Country-sequence-unchanged';
DROP TRIGGER po10648_alias_fault ON public.aliases;
DROP FUNCTION pg_temp.pa_inject();
UPDATE pa_checks SET passed=NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='po10648_alias_fault')
WHERE label='owned-trigger-removed';
UPDATE pa_checks SET passed=TO_REGPROCEDURE('pg_temp.pa_inject()') IS NULL
WHERE label='owned-trigger-function-removed';
DROP FUNCTION pg_temp.pa_run_cases();
DROP FUNCTION pg_temp.pa_probe(BIGINT,TEXT,BOOLEAN);
DROP FUNCTION pg_temp.pa_native_text(TEXT);
DROP FUNCTION pg_temp.pa_rows();
DROP SEQUENCE pg_temp.pa_attempts;
UPDATE pa_checks SET passed=TO_REGPROCEDURE('pg_temp.pa_probe(bigint,text,boolean)') IS NULL
  AND TO_REGPROCEDURE('pg_temp.pa_native_text(text)') IS NULL
  AND TO_REGPROCEDURE('pg_temp.pa_run_cases()') IS NULL
  AND TO_REGPROCEDURE('pg_temp.pa_rows()') IS NULL
  AND TO_REGCLASS('pg_temp.pa_attempts') IS NULL
WHERE label='owned-probes-removed';
SELECT ok(COALESCE(passed,false),label) FROM pa_checks ORDER BY label;
SELECT * FROM finish();
ROLLBACK;
