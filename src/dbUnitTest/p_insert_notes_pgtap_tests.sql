/**
 * OPAL Program
 *
 * MODULE      : p_insert_notes_pgtap_tests.sql
 *
 * DESCRIPTION : Verify Notes mapping, database integrity, original diagnostics,
 *               transactions and compatible fresh/upgrade contracts.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket        Nature of Change
 * ----------  -------------  ------------  ----------------------------------------
 * 13/10/2026  Frankie Moran  PO-10645      Initial pgTAP test suite.
 * 23/10/2026  Frankie Moran  PO-10645      Verify original author widths before Note allocation.
 */
-- OPAL-DB-UPGRADE {"id":"p_insert_notes.create","candidate":"ddl/V1_52__create_p_insert_notes_procedure.sql","scope":"both","data":"migration-created-only","contract":{"type":"additive","objects":{"created":[{"kind":"routine","identity":"public.p_insert_notes(bigint,character varying,character varying,json)"}],"replaced":[]},"preserve":{"rows":["public.notes","public.respondent_accounts","public.business_units","public.maintenance_applications","public.draft_casefiles"],"tables":["public.notes","public.respondent_accounts"],"routines":[],"enums":["public.t_note_type_enum","public.t_associated_record_type_enum"],"sequences":["public.note_id_seq","public.respondent_account_id_seq"]},"assertion":"notes.current"}}
-- OPAL-DB-UPGRADE {"id":"p_insert_notes.author_widths","candidate":"ddl/V1_66__replace_p_insert_notes_author_widths.sql","scope":"both","data":"migration-created-only","contract":{"type":"replacement","objects":{"created":[],"replaced":[{"kind":"routine","identity":"public.p_insert_notes(bigint,character varying,character varying,json)"}]},"preserve":{"rows":["public.notes","public.respondent_accounts","public.business_units","public.maintenance_applications","public.draft_casefiles"],"tables":["public.notes","public.respondent_accounts"],"routines":[],"enums":["public.t_note_type_enum","public.t_associated_record_type_enum"],"sequences":["public.note_id_seq","public.respondent_account_id_seq"]},"assertion":"notes.author_width"}}
-- DB-04/DB-06: consolidated creation retains the baseline; author widths are a forward correction.
-- Current assertions prove database integrity and unchanged diagnostic propagation.
-- Request validation and caller response/log safety require separate backend evidence.
-- Shared support owns predecessor preservation, lifecycle and independent cleanup.
\set ON_ERROR_STOP 1
\if :{?opal_assertion_group}
\else
    \set opal_assertion_group notes.author_width
\endif
SELECT :'opal_assertion_group' IN ('notes.current','notes.author_width') AS valid_notes_group,
       :'opal_assertion_group' = 'notes.current' AS legacy_current_contract,
       :'opal_assertion_group' = 'notes.author_width' AS author_width_contract \gset
\if :valid_notes_group
\else
    DO $group$ BEGIN RAISE EXCEPTION 'Unknown Notes assertion group'; END; $group$;
\endif
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SET LOCAL search_path=public,pg_catalog;
SET LOCAL TIME ZONE 'UTC';
SET LOCAL statement_timeout='30s';
SET LOCAL lock_timeout='5s';

CREATE FUNCTION pg_temp.notes_state() RETURNS JSONB LANGUAGE plpgsql AS $state$
DECLARE v_table TEXT; v_rows JSONB:='{}'; v_values JSONB;
BEGIN
    FOREACH v_table IN ARRAY ARRAY[
        'notes','respondent_accounts','business_units','maintenance_applications','draft_casefiles'
    ] LOOP
        EXECUTE FORMAT('SELECT COALESCE(JSONB_AGG(value ORDER BY value),''[]''::JSONB)
            FROM (SELECT ROW_TO_JSON(t)::TEXT AS value FROM public.%I t) r',v_table)
        INTO v_values;
        v_rows:=v_rows||JSONB_BUILD_OBJECT(v_table,v_values);
    END LOOP;
    RETURN JSONB_BUILD_OBJECT('rows',v_rows);
END;
$state$;


\if :author_width_contract
    SELECT plan(843);
\else
    SELECT plan(212);
\endif

-- -----------------------------------------------------------------------------
-- Scenario: Create independent synthetic publication targets and lifecycle sentinel.
-- Setup: Explicit BU/application keys; optional account FKs null; collision guards first.
-- Expected: Negative, zero and signed BIGINT endpoints accepted without sequence setup.
-- -----------------------------------------------------------------------------
DO $guard$
BEGIN
    IF EXISTS(SELECT 1 FROM public.business_units WHERE business_unit_id IN (32045,32046)
        OR business_unit_code IN ('N045','N046'))
       OR EXISTS(SELECT 1 FROM public.maintenance_applications WHERE application_id IN (32045,32046)
        OR application_code IN ('N10645','N10646'))
       OR EXISTS(SELECT 1 FROM public.respondent_accounts WHERE respondent_account_id IN (
            -1064501,-1064599,-1064598,0,'-9223372036854775808'::BIGINT,'9223372036854775807'::BIGINT)
        OR account_number IN ('N045-main','N045-zero','N045-min','N045-max','N046-committed','N045-rollback'))
       OR EXISTS(SELECT 1 FROM public.draft_casefiles WHERE draft_casefile_id=-1064501)
       OR EXISTS(SELECT 1 FROM public.notes WHERE note_id=-1064501) THEN
        RAISE EXCEPTION 'Notes synthetic fixture collision';
    END IF;
END;
$guard$;
INSERT INTO public.business_units(
    business_unit_id,business_unit_code,business_unit_name,business_unit_type,welsh_language
) VALUES (32045,'N045','Synthetic Notes area','Area',false);
INSERT INTO public.maintenance_applications(
    application_id,application_code,application_title,application_group,active,date_used_from
) VALUES (32045,'N10645','Synthetic Notes application','Synthetic',true,DATE '2026-01-01');

CREATE FUNCTION pg_temp.notes_account(p_id BIGINT,p_number TEXT) RETURNS VOID LANGUAGE sql AS $account$
    INSERT INTO public.respondent_accounts(
        respondent_account_id,business_unit_id,account_number,application_id,
        account_balance,orders_balance,orders_amount,payment_period,total_arrears,account_status,
        last_movement_date,date_arrears_last_updated,allow_cheques,cheque_clearance_period,
        credit_trans_clearance_period,casefile_type,interest_flag,indexation,payment_arrangement,
        account_comment,version_number
    ) VALUES (
        p_id,32045,p_number,32045,0,0,0,'Weekly',0,'L',
        TIMESTAMP '2026-01-01',TIMESTAMP '2026-01-01',false,0,0,'REMO In',false,'None','Direct',
        'Synthetic account comment',1
    );
$account$;
SELECT pg_temp.notes_account(-1064501,'N045-main');
SELECT pg_temp.notes_account(0,'N045-zero');
SELECT pg_temp.notes_account('-9223372036854775808'::BIGINT,'N045-min');
SELECT pg_temp.notes_account('9223372036854775807'::BIGINT,'N045-max');
INSERT INTO public.draft_casefiles(
    draft_casefile_id,business_unit_id,created_date,submitted_by,submitted_by_name,
    casefile,casefile_snapshot,casefile_type,casefile_status,casefile_status_date,timeline_data
) VALUES (-1064501,32045,TIMESTAMP '2026-01-01','synthetic','Synthetic fixture',
    '{"synthetic":"input"}','{"synthetic":"snapshot"}','REMO In','SUBMITTED',
    TIMESTAMP '2026-01-01','[{"synthetic":"timeline"}]');
INSERT INTO public.notes(note_id,note_type,associated_record_type,associated_record_id,note_text,
    posted_date,posted_by,posted_by_name)
VALUES (-1064501,'MN','respondent_accounts','-1064501','Synthetic unchanged Note',
    TIMESTAMP '2026-01-01','synthetic','Synthetic fixture');
CREATE TEMP TABLE notes_scope_before AS SELECT pg_temp.notes_state()->'rows' AS rows;
CREATE TEMP TABLE notes_success_results(label TEXT PRIMARY KEY,note_id BIGINT,posted_date TIMESTAMP);

CREATE FUNCTION pg_temp.notes_probe(p_id BIGINT,p_by VARCHAR,p_name VARCHAR,p_json JSON,p_direct BOOLEAN DEFAULT false)
RETURNS JSONB LANGUAGE plpgsql AS $probe$
DECLARE v_state TEXT; v_message TEXT; v_detail TEXT; v_hint TEXT; v_context TEXT;
        v_schema TEXT; v_table TEXT; v_column TEXT; v_constraint TEXT; v_datatype TEXT;
BEGIN
    IF p_direct THEN
        INSERT INTO public.notes(
            note_type,associated_record_type,associated_record_id,note_text,
            posted_date,posted_by,posted_by_name
        ) VALUES (
            'NT','respondent_accounts',p_id::TEXT,p_json->>'note_text',
            TRANSACTION_TIMESTAMP() AT TIME ZONE 'UTC',p_by,p_name
        );
    ELSE
        CALL public.p_insert_notes(p_id,p_by,p_name,p_json);
    END IF;
    RETURN JSONB_BUILD_OBJECT('succeeded',true,'id',CURRVAL('public.note_id_seq'),'state',NULL);
EXCEPTION WHEN query_canceled OR assert_failure OR OTHERS THEN
    GET STACKED DIAGNOSTICS v_state=RETURNED_SQLSTATE,v_message=MESSAGE_TEXT,
        v_detail=PG_EXCEPTION_DETAIL,v_hint=PG_EXCEPTION_HINT,v_context=PG_EXCEPTION_CONTEXT,
        v_schema=SCHEMA_NAME,v_table=TABLE_NAME,v_column=COLUMN_NAME,
        v_constraint=CONSTRAINT_NAME,v_datatype=PG_DATATYPE_NAME;
    RETURN JSONB_BUILD_OBJECT('succeeded',false,'state',v_state,'message',v_message,
        'detail',v_detail,'hint',v_hint,'context',v_context,'schema',v_schema,'table',v_table,
        'column',v_column,'constraint',v_constraint,'datatype',v_datatype);
END;
$probe$;

CREATE FUNCTION pg_temp.notes_error(
    p_label TEXT,p_id BIGINT,p_by VARCHAR,p_name VARCHAR,p_json JSON,p_state TEXT,p_message TEXT
) RETURNS SETOF TEXT LANGUAGE plpgsql AS $error$
DECLARE v_before JSONB:=pg_temp.notes_state()->'rows'; v_result JSONB;
BEGIN
    v_result:=pg_temp.notes_probe(p_id,p_by,p_name,p_json);
    RETURN NEXT ok(v_result->>'state' IS NOT DISTINCT FROM p_state,p_label||': expected SQLSTATE');
    RETURN NEXT ok(v_result->>'message' IS NOT DISTINCT FROM 'p_insert_notes: '||p_message
        AND v_result->>'detail'='' AND v_result->>'hint'='' AND v_result->>'schema'=''
        AND v_result->>'table'='' AND v_result->>'column'='' AND v_result->>'constraint'=''
        AND v_result->>'datatype'='' AND POSITION('__payload__' IN v_result::TEXT)=0,
        p_label||': fixed private diagnostics');
    RETURN NEXT ok((v_result->>'succeeded')::BOOLEAN=false
        AND v_before IS NOT DISTINCT FROM (pg_temp.notes_state()->'rows'),
        p_label||': unsuccessful call preserves all scoped rows');
END;
$error$;

CREATE FUNCTION pg_temp.notes_success(p_label TEXT,p_id BIGINT,p_by VARCHAR,p_name VARCHAR,p_json JSON)
RETURNS SETOF TEXT LANGUAGE plpgsql AS $success$
DECLARE v_before JSONB:=pg_temp.notes_state()->'rows'; v_count BIGINT;
        v_result JSONB; v_note public.notes%ROWTYPE;
BEGIN
    SELECT COUNT(*) INTO v_count FROM public.notes;
    v_result:=pg_temp.notes_probe(p_id,p_by,p_name,p_json);
    SELECT * INTO v_note FROM public.notes WHERE note_id=(v_result->>'id')::BIGINT;
    INSERT INTO notes_success_results VALUES (p_label,v_note.note_id,v_note.posted_date);
    RETURN NEXT ok((v_result->>'succeeded')::BOOLEAN=true,p_label||': call succeeds');
    RETURN NEXT ok((SELECT COUNT(*) FROM public.notes)=v_count+1,p_label||': exactly one row added');
    RETURN NEXT ok(v_note.note_type='NT' AND v_note.associated_record_type='respondent_accounts'
        AND v_note.associated_record_id IS NOT DISTINCT FROM p_id::TEXT
        AND v_note.note_text IS NOT DISTINCT FROM p_json->>'note_text'
        AND v_note.posted_by IS NOT DISTINCT FROM p_by AND v_note.posted_by_name IS NOT DISTINCT FROM p_name
        AND v_note.posted_date IS NOT DISTINCT FROM TRANSACTION_TIMESTAMP() AT TIME ZONE 'UTC'
        AND v_note.note_id=(SELECT last_value FROM public.note_id_seq)
        AND v_note.note_id NOT IN (SELECT (value::JSONB->>'note_id')::BIGINT
            FROM JSONB_ARRAY_ELEMENTS_TEXT(v_before->'notes')),
        p_label||': exact mapping original values UTC timestamp and default identifier');
    RETURN NEXT ok((v_before-'notes') IS NOT DISTINCT FROM ((pg_temp.notes_state()->'rows')-'notes')
        AND NOT EXISTS(SELECT 1 FROM JSONB_ARRAY_ELEMENTS_TEXT(v_before->'notes') b
            WHERE NOT EXISTS(SELECT 1 FROM public.notes n WHERE ROW_TO_JSON(n)::TEXT=b.value)),
        p_label||': preexisting Notes and other scoped rows unchanged');
END;
$success$;

-- -----------------------------------------------------------------------------
-- Scenario: Effective installed procedure and UTF-8 contract match the boundary.
-- Setup: Read catalogue only; arguments from %TYPE resolve to unbounded VARCHAR.
-- Expected: Four ordered IN inputs, no output/default, invoker defaults and comment.
-- -----------------------------------------------------------------------------
SELECT ok(CURRENT_SETTING('server_encoding')='UTF8' AND CURRENT_SETTING('client_encoding')='UTF8',
    'UTF-8 server and client support pinned Unicode');
SELECT ok((SELECT prokind='p' FROM pg_proc WHERE oid=
    'public.p_insert_notes(bigint,character varying,character varying,json)'::REGPROCEDURE),
    'public Notes object is a procedure');
SELECT ok((SELECT proargtypes=ARRAY['bigint'::REGTYPE::OID,'varchar'::REGTYPE::OID,
    'varchar'::REGTYPE::OID,'json'::REGTYPE::OID]::OIDVECTOR FROM pg_proc WHERE oid=
    'public.p_insert_notes(bigint,character varying,character varying,json)'::REGPROCEDURE),
    'effective argument types and order exact');
SELECT ok((SELECT proargnames=ARRAY['pi_respondent_account_id','pi_posted_by','pi_posted_by_name','pi_note_json']
    FROM pg_proc WHERE oid='public.p_insert_notes(bigint,character varying,character varying,json)'::REGPROCEDURE),
    'exact four parameter names');
SELECT ok((SELECT pronargs=4 AND proargmodes IS NULL AND proallargtypes IS NULL
    AND prorettype='void'::REGTYPE FROM pg_proc WHERE oid=
    'public.p_insert_notes(bigint,character varying,character varying,json)'::REGPROCEDURE),
    'all inputs and no OUT INOUT or return value');
SELECT ok((SELECT pronargdefaults=0 AND NOT prosecdef AND NOT proisstrict AND provolatile='v'
    AND proconfig IS NULL FROM pg_proc WHERE oid=
    'public.p_insert_notes(bigint,character varying,character varying,json)'::REGPROCEDURE),
    'no defaults and effective invoker volatile null-input properties');
SELECT ok((SELECT lanname='plpgsql' FROM pg_proc p JOIN pg_language l ON l.oid=p.prolang
    WHERE p.oid='public.p_insert_notes(bigint,character varying,character varying,json)'::REGPROCEDURE),
    'procedure language is PLpgSQL');
SELECT ok(OBJ_DESCRIPTION('public.p_insert_notes(bigint,character varying,character varying,json)'::REGPROCEDURE,'pg_proc')
    ='Insert one standard publication Note for an existing Respondent Account; caller owns transaction and lifecycle.',
    'procedure object comment records scope and ownership');

-- -----------------------------------------------------------------------------
-- Scenario: Preserve original inputs and accept legitimate target/text boundaries.
-- Setup: Same-transaction accounts; ASCII and multibyte author limits; decoded JSON.
-- Expected: One exact Note each; no positivity, provenance or UI TEXT-length restriction.
-- -----------------------------------------------------------------------------
SELECT * FROM pg_temp.notes_success('same transaction',-1064501,'synthetic','Synthetic fixture','{"note_text":"Synthetic note"}');
SELECT * FROM pg_temp.notes_success('minimum bigint','-9223372036854775808'::BIGINT,'synthetic','Synthetic fixture','{"note_text":"Boundary"}');
SELECT * FROM pg_temp.notes_success('maximum bigint','9223372036854775807'::BIGINT,'synthetic','Synthetic fixture','{"note_text":"Boundary"}');
SELECT * FROM pg_temp.notes_success('zero bigint',0,'synthetic','Synthetic fixture','{"note_text":"Boundary"}');
SELECT * FROM pg_temp.notes_success('ASCII widths',-1064501,REPEAT('x',20)::VARCHAR,REPEAT('y',100)::VARCHAR,'{"note_text":"Width"}');
SELECT * FROM pg_temp.notes_success('multibyte widths',-1064501,REPEAT('界',20)::VARCHAR,REPEAT('é',100)::VARCHAR,'{"note_text":"Width"}');
SELECT * FROM pg_temp.notes_success('original whitespace and Unicode',-1064501,
    (CHR(160)||'x'||CHR(12288))::VARCHAR,(CHR(9)||'Synthetic 界'||CHR(8239))::VARCHAR,
    JSON_BUILD_OBJECT('note_text',CHR(160)||'é 界, "quoted" !'||CHR(9)||CHR(12288)));
SELECT * FROM pg_temp.notes_success('TEXT over UI limit',-1064501,'synthetic','Synthetic fixture',JSON_BUILD_OBJECT('note_text',REPEAT('界',1001)));
SELECT * FROM pg_temp.notes_success('excluded U180E',-1064501,CHR(6158)::VARCHAR,CHR(6158)::VARCHAR,JSON_BUILD_OBJECT('note_text',CHR(6158)));
SELECT * FROM pg_temp.notes_success('excluded U200B',-1064501,CHR(8203)::VARCHAR,CHR(8203)::VARCHAR,JSON_BUILD_OBJECT('note_text',CHR(8203)));
SELECT * FROM pg_temp.notes_success('excluded UFEFF',-1064501,CHR(65279)::VARCHAR,CHR(65279)::VARCHAR,JSON_BUILD_OBJECT('note_text',CHR(65279)));
SELECT * FROM pg_temp.notes_success('decoded escaped key',-1064501,'synthetic','Synthetic fixture',
    '{"note_\u0074ext":"decoded \u754c\nquote \" and slash \\"}');

-- -----------------------------------------------------------------------------
-- Scenario: Repeated calls in one transaction use UTC transaction-start time.
-- Setup: First matching Note above in UTC; separate delayed call in Asia/Kathmandu.
-- Expected: Two distinct exact Notes, equal transaction UTC timestamps across timezones.
-- -----------------------------------------------------------------------------
SELECT PG_SLEEP(0.02);
SET LOCAL TIME ZONE 'Asia/Kathmandu';
SELECT * FROM pg_temp.notes_success('non UTC repeat',-1064501,'synthetic','Synthetic fixture','{"note_text":"Synthetic note"}');
SET LOCAL TIME ZONE 'UTC';
SELECT ok((SELECT COUNT(*)=2 AND COUNT(DISTINCT note_id)=2 FROM public.notes
    WHERE associated_record_type='respondent_accounts' AND associated_record_id='-1064501'
      AND note_text='Synthetic note' AND posted_by='synthetic' AND posted_by_name='Synthetic fixture'),
    'two identical calls produce exactly two distinct Notes');
SELECT ok((SELECT COUNT(DISTINCT posted_date)=1 AND MIN(posted_date)=TRANSACTION_TIMESTAMP() AT TIME ZONE 'UTC'
    FROM notes_success_results WHERE label IN ('same transaction','non UTC repeat')),
    'separated UTC and non UTC calls share transaction-start UTC timestamp');

-- -----------------------------------------------------------------------------
-- Scenario: Backend-owned request validation is absent from the database helper.
-- Setup: Direct SQL deliberately bypasses the backend; only table rules apply.
-- Expected: Nullable authors, blank text and JSON extraction follow PostgreSQL.
-- These accepted DB inputs do not establish backend validation coverage or policy.
-- -----------------------------------------------------------------------------
SELECT * FROM pg_temp.notes_success('nullable authors',-1064501,NULL,NULL,'{"note_text":"A"}');
SELECT * FROM pg_temp.notes_success('empty request strings',-1064501,'','','{"note_text":""}');
SELECT * FROM pg_temp.notes_success('Unicode whitespace request',-1064501,CHR(160)::VARCHAR,CHR(12288)::VARCHAR,
    JSON_BUILD_OBJECT('note_text',CHR(9)||CHR(160)||CHR(12288)));
SELECT * FROM pg_temp.notes_success('numeric JSON extraction',-1064501,'synthetic','Synthetic fixture','{"note_text":1}');
SELECT * FROM pg_temp.notes_success('boolean JSON extraction',-1064501,'synthetic','Synthetic fixture','{"note_text":true}');
SELECT * FROM pg_temp.notes_success('object JSON extraction',-1064501,'synthetic','Synthetic fixture','{"note_text":{}}');
SELECT * FROM pg_temp.notes_success('array JSON extraction',-1064501,'synthetic','Synthetic fixture','{"note_text":[]}');
SELECT * FROM pg_temp.notes_success('duplicate JSON extraction',-1064501,'synthetic','Synthetic fixture','{"note_text":"A","note_text":"B"}');
SELECT * FROM pg_temp.notes_success('additional JSON member',-1064501,'synthetic','Synthetic fixture','{"note_text":"A","other":"ignored"}');

CREATE FUNCTION pg_temp.notes_native_input(
    p_label TEXT,p_by VARCHAR,p_name VARCHAR,p_json JSON,p_state TEXT
) RETURNS SETOF TEXT LANGUAGE plpgsql AS $input$
DECLARE v_before JSONB:=pg_temp.notes_state()->'rows'; v_expected JSONB; v_result JSONB;
BEGIN
    v_expected:=pg_temp.notes_probe(-1064501,p_by,p_name,p_json,true);
    v_result:=pg_temp.notes_probe(-1064501,p_by,p_name,p_json);
    RETURN NEXT ok(v_result->>'state' IS NOT DISTINCT FROM p_state,
        p_label||': underlying table SQLSTATE propagates');
    RETURN NEXT ok((v_result-'context'-'detail') IS NOT DISTINCT FROM (v_expected-'context'-'detail')
        AND CASE WHEN p_state='23502' THEN
            v_result->>'detail' LIKE 'Failing row contains (%'
            AND POSITION('NT, respondent_accounts, -1064501, null,' IN v_result->>'detail')>0
        ELSE v_result->>'detail' IS NOT DISTINCT FROM v_expected->>'detail' END
        AND POSITION('p_insert_notes(' IN v_result->>'context')>0,
        p_label||': original native diagnostic fields retained internally');
    RETURN NEXT ok((v_result->>'succeeded')::BOOLEAN=false
        AND v_before IS NOT DISTINCT FROM (pg_temp.notes_state()->'rows'),
        p_label||': failed call leaves every scoped row unchanged');
END;
$input$;

-- -----------------------------------------------------------------------------
-- Scenario: Missing Note text retains native failures.
-- Setup: PostgreSQL extraction supplies NULL to the required table column.
-- Expected: Native 23502 and original diagnostics; no replacement request error.
-- Generated IDs differ across independent probes, so failing-row IDs are not compared.
-- -----------------------------------------------------------------------------
CREATE TEMP TABLE notes_native_nulls(label TEXT,payload JSON);
INSERT INTO notes_native_nulls VALUES
    ('SQL null Note',NULL),('JSON null Note','null'),('missing Note','{}'),
    ('null Note text','{"note_text":null}'),('array request','[]'),
    ('scalar string request','"synthetic"'),('scalar numeric request','1'),('scalar boolean request','true');
SELECT e.* FROM notes_native_nulls c CROSS JOIN LATERAL pg_temp.notes_native_input(
    c.label,'synthetic','Synthetic fixture',c.payload,'23502') e;
\if :legacy_current_contract
-- -----------------------------------------------------------------------------
-- Scenario: Historical overwidth authors retain native assignment failures.
-- Setup: Original ASCII and multibyte authors exceed their table column widths.
-- Expected: V1_55 retains native 22001 and original diagnostics.
-- -----------------------------------------------------------------------------
SELECT * FROM pg_temp.notes_native_input('author identifier width',REPEAT('x',21)::VARCHAR,
    'Synthetic fixture','{"note_text":"A"}','22001');
SELECT * FROM pg_temp.notes_native_input('author identifier multibyte width',REPEAT('界',21)::VARCHAR,
    'Synthetic fixture','{"note_text":"A"}','22001');
SELECT * FROM pg_temp.notes_native_input('author name width','synthetic',REPEAT('x',101)::VARCHAR,
    '{"note_text":"A"}','22001');
SELECT * FROM pg_temp.notes_native_input('author name multibyte width','synthetic',REPEAT('界',101)::VARCHAR,
    '{"note_text":"A"}','22001');

-- -----------------------------------------------------------------------------
-- Scenario: Excess trailing spaces follow native VARCHAR assignment semantics.
-- Setup: Original author strings exceed limits only by one trailing space.
-- Expected: PostgreSQL stores the width-limited prefixes; backend must validate originals.
-- -----------------------------------------------------------------------------
CREATE TEMP TABLE notes_trailing_before AS SELECT COUNT(*) AS count FROM public.notes;
CREATE TEMP TABLE notes_trailing_result AS
SELECT pg_temp.notes_probe(-1064501,(REPEAT('x',20)||' ')::VARCHAR,(REPEAT('y',100)||' ')::VARCHAR,
    '{"note_text":"Native trailing spaces"}') AS result;
SELECT ok((SELECT (result->>'succeeded')::BOOLEAN FROM notes_trailing_result),
    'trailing-space width follows native assignment without a request guard');
SELECT ok((SELECT COUNT(*) FROM public.notes)=(SELECT count+1 FROM notes_trailing_before),
    'native trailing-space assignment inserts one Note');
SELECT ok(EXISTS(SELECT 1 FROM public.notes n,notes_trailing_result r
    WHERE n.note_id=(r.result->>'id')::BIGINT AND n.posted_by=REPEAT('x',20)
        AND n.posted_by_name=REPEAT('y',100) AND n.note_text='Native trailing spaces'),
    'native VARCHAR semantics retain prefixes within table widths');
\endif

-- -----------------------------------------------------------------------------
-- Scenario: The polymorphic respondent-account target remains database-owned.
-- Setup: Null/absent targets, valid and multiply invalid request values.
-- Expected: Fixed P0001 target failure precedes extraction; no business row changes.
-- -----------------------------------------------------------------------------
SELECT * FROM pg_temp.notes_error('null integrity target',NULL,NULL,NULL,'{}',
    'P0001','respondent_account target does not exist');
SELECT * FROM pg_temp.notes_error('missing integrity target',-1064598,'synthetic','Synthetic fixture','{"note_text":"A"}',
    'P0001','respondent_account target does not exist');


\if :author_width_contract
-- -----------------------------------------------------------------------------
-- Scenario: Independently nullable, empty and exact-width authors preserve originals.
-- Setup: Seven unbounded TEXT classes per author; cross all 49 pairs without narrowing.
-- Expected: One exact Note per pair, including spaces and decomposed Unicode characters.
-- -----------------------------------------------------------------------------
CREATE TEMP TABLE notes_width_accepted(field TEXT,class TEXT,value TEXT,PRIMARY KEY(field,class));
INSERT INTO notes_width_accepted
SELECT f.field,c.class,c.value
FROM (VALUES ('posted_by',20),('posted_by_name',100)) f(field,lim)
CROSS JOIN LATERAL (VALUES
    ('null',NULL::TEXT),('empty',''),('all spaces',REPEAT(' ',f.lim)),
    ('ASCII',REPEAT('x',f.lim)),('multibyte',REPEAT('界',f.lim)),
    ('trailing spaces',REPEAT('x',f.lim-2)||'  '),
    ('decomposed',REPEAT('e'||CHR(769),f.lim/2))
) c(class,value);

-- -----------------------------------------------------------------------------
-- Scenario: Any original overwidth author fails before Note-ID allocation.
-- Setup: Six invalid TEXT classes per author; independently valid peers and both invalid.
-- Expected: 84 failures with fixed 22001; posted_by wins when both exceed their limits.
-- -----------------------------------------------------------------------------
CREATE TEMP TABLE notes_width_invalid(field TEXT,class TEXT,value TEXT,PRIMARY KEY(field,class));
INSERT INTO notes_width_invalid
SELECT f.field,c.class,c.value
FROM (VALUES ('posted_by',20),('posted_by_name',100)) f(field,lim)
CROSS JOIN LATERAL (VALUES
    ('ASCII plus one',REPEAT('x',f.lim+1)),('multibyte plus one',REPEAT('界',f.lim+1)),
    ('one excess space',REPEAT('x',f.lim)||' '),
    ('three excess spaces',REPEAT('x',f.lim)||'   '),
    ('multibyte excess spaces',REPEAT('界',f.lim)||'   '),
    ('all spaces plus one',REPEAT(' ',f.lim+1))
) c(class,value);
CREATE TEMP TABLE notes_width_errors(
    label TEXT PRIMARY KEY,kind TEXT,target BIGINT,posted_by TEXT,posted_by_name TEXT,state TEXT,message TEXT
);
INSERT INTO notes_width_errors
SELECT i.field||' '||i.class||' with '||v.class,'single',-1064501,
    CASE WHEN i.field='posted_by' THEN i.value ELSE v.value END,
    CASE WHEN i.field='posted_by_name' THEN i.value ELSE v.value END,
    '22001','p_insert_notes: '||i.field||' exceeds '||
        CASE WHEN i.field='posted_by' THEN '20' ELSE '100' END||' characters'
FROM notes_width_invalid i
CROSS JOIN (VALUES ('null',NULL::TEXT),('empty',''),('one space',' '),('ordinary','synthetic')) v(class,value);
INSERT INTO notes_width_errors
SELECT 'both '||b.class||' and '||n.class,'both',-1064501,b.value,n.value,
    '22001','p_insert_notes: posted_by exceeds 20 characters'
FROM notes_width_invalid b CROSS JOIN notes_width_invalid n
WHERE b.field='posted_by' AND n.field='posted_by_name';

-- -----------------------------------------------------------------------------
-- Scenario: NULL and absent targets precede either author-width failure.
-- Setup: Each invalid target crosses identifier-only, name-only and both overwidth.
-- Expected: Six fixed P0001 failures with no successful result, rows or sequence effects.
-- -----------------------------------------------------------------------------
INSERT INTO notes_width_errors
SELECT t.class||' target with '||a.class,'target',t.id,a.posted_by,a.posted_by_name,
    'P0001','p_insert_notes: respondent_account target does not exist'
FROM (VALUES ('null',NULL::BIGINT),('absent',-1064598::BIGINT)) t(class,id)
CROSS JOIN (VALUES
    ('identifier only',REPEAT('x',21),'synthetic'),
    ('name only','synthetic',REPEAT('x',101)),
    ('both',REPEAT('x',21),REPEAT('x',101))
) a(class,posted_by,posted_by_name);

DO $width_inventory$
BEGIN
    IF (SELECT COUNT(*) FROM notes_width_accepted)<>14
       OR (SELECT COUNT(*) FROM notes_width_accepted WHERE field='posted_by')<>7
       OR (SELECT COUNT(*) FROM notes_width_accepted WHERE field='posted_by_name')<>7
       OR (SELECT COUNT(*) FROM notes_width_accepted b CROSS JOIN notes_width_accepted n
           WHERE b.field='posted_by' AND n.field='posted_by_name')<>49
       OR (SELECT COUNT(*) FROM notes_width_invalid)<>12
       OR (SELECT COUNT(*) FROM notes_width_invalid WHERE field='posted_by')<>6
       OR (SELECT COUNT(*) FROM notes_width_invalid WHERE field='posted_by_name')<>6
       OR (SELECT COUNT(*) FROM notes_width_errors)<>90
       OR (SELECT COUNT(*) FROM notes_width_errors WHERE kind='single')<>48
       OR (SELECT COUNT(*) FROM notes_width_errors WHERE kind='both')<>36
       OR (SELECT COUNT(*) FROM notes_width_errors WHERE kind='target')<>6 THEN
        RAISE EXCEPTION 'Notes author-width inventory differs from exact TAP plan';
    END IF;
END;
$width_inventory$;

SELECT e.* FROM notes_width_accepted b CROSS JOIN notes_width_accepted n
CROSS JOIN LATERAL pg_temp.notes_success('author pair '||b.class||' and '||n.class,
    -1064501,b.value::VARCHAR,n.value::VARCHAR,'{"note_text":"Original author widths"}') e
WHERE b.field='posted_by' AND n.field='posted_by_name';

CREATE FUNCTION pg_temp.notes_width_errors() RETURNS SETOF TEXT LANGUAGE plpgsql AS $width_errors$
DECLARE
    v_case notes_width_errors%ROWTYPE;
    v_payload CONSTANT JSON:='{"note_text":"__payload__"}';
    v_result JSONB;
    v_rows JSONB;
    v_actual_rows JSONB;
    v_sequence JSONB;
    v_actual_sequence JSONB;
BEGIN
    FOR v_case IN SELECT * FROM notes_width_errors ORDER BY label LOOP
        v_rows:=pg_temp.notes_state()->'rows';
        SELECT JSONB_BUILD_ARRAY(last_value,is_called) INTO v_sequence FROM public.note_id_seq;
        BEGIN
            v_result:=pg_temp.notes_probe(v_case.target,v_case.posted_by::VARCHAR,
                v_case.posted_by_name::VARCHAR,v_payload);
            v_actual_rows:=pg_temp.notes_state()->'rows';
            SELECT JSONB_BUILD_ARRAY(last_value,is_called) INTO v_actual_sequence FROM public.note_id_seq;
            -- Observe before restoring any unexpected RED success; never rewind a sequence.
            RAISE EXCEPTION USING ERRCODE='P5599',MESSAGE='Restore private author-width attempt';
        EXCEPTION WHEN SQLSTATE 'P5599' THEN
            NULL;
        END;
        RETURN NEXT ok(v_result->>'state' IS NOT DISTINCT FROM v_case.state,
            v_case.label||': expected SQLSTATE');
        RETURN NEXT ok(v_result->>'message' IS NOT DISTINCT FROM v_case.message
            AND v_result->>'detail'='' AND v_result->>'hint'='' AND v_result->>'schema'=''
            AND v_result->>'table'='' AND v_result->>'column'='' AND v_result->>'constraint'=''
            AND v_result->>'datatype'='' AND POSITION('__payload__' IN v_result::TEXT)=0,
            v_case.label||': fixed value-free message and diagnostics');
        RETURN NEXT ok((v_result->>'succeeded')::BOOLEAN=false AND v_result->>'id' IS NULL,
            v_case.label||': no successful result or identifier');
        RETURN NEXT ok(v_actual_rows IS NOT DISTINCT FROM v_rows,
            v_case.label||': exact five-table rows unchanged');
        RETURN NEXT ok(v_actual_sequence IS NOT DISTINCT FROM v_sequence,
            v_case.label||': exact Note sequence state unchanged before allocation');
    END LOOP;
END;
$width_errors$;
SELECT * FROM pg_temp.notes_width_errors();
\endif

CREATE TEMP SEQUENCE notes_attempt_seq START WITH 1;
CREATE FUNCTION pg_temp.notes_attempts() RETURNS BIGINT LANGUAGE sql AS $attempts$
    SELECT CASE WHEN is_called THEN last_value ELSE 0 END FROM notes_attempt_seq;
$attempts$;
CREATE FUNCTION pg_temp.notes_fault() RETURNS TRIGGER LANGUAGE plpgsql AS $fault$
DECLARE v_mode TEXT:=CURRENT_SETTING('opal.notes_fault',true);
BEGIN
    IF NEW.associated_record_id<>'-1064501' OR NEW.note_text<>'__fault__'
       OR COALESCE(v_mode,'')='' THEN
        RETURN NEW;
    END IF;
    PERFORM NEXTVAL('notes_attempt_seq');
    IF v_mode='native_pk' THEN
        NEW.note_id:=-1064501;
        RETURN NEW;
    ELSIF v_mode='native_notnull' THEN
        NEW.note_id:=-1064502;
        NEW.note_text:=NULL;
        RETURN NEW;
    ELSIF v_mode='cancel' THEN
        PERFORM PG_SLEEP(1);
        RETURN NEW;
    ELSIF v_mode='spoof_all' THEN
        RAISE EXCEPTION USING MESSAGE='__payload__',DETAIL='__payload__',HINT='__payload__',
            SCHEMA='__payload__',TABLE='__payload__',COLUMN='__payload__',
            CONSTRAINT='__payload__',DATATYPE='__payload__';
    ELSIF v_mode='spoof_schema' THEN
        RAISE EXCEPTION USING MESSAGE='__payload__',DETAIL='__payload__',HINT='__payload__',
            SCHEMA='__payload__',TABLE='notes',COLUMN='note_id',CONSTRAINT='notes_pk';
    ELSIF v_mode='spoof_table' THEN
        RAISE EXCEPTION USING MESSAGE='__payload__',DETAIL='__payload__',HINT='__payload__',
            SCHEMA='public',TABLE='__payload__',COLUMN='note_id',CONSTRAINT='notes_pk';
    ELSIF v_mode='spoof_column' THEN
        RAISE EXCEPTION USING ERRCODE='23502',MESSAGE='__payload__',DETAIL='__payload__',HINT='__payload__',
            SCHEMA='public',TABLE='notes',COLUMN='__payload__',DATATYPE='__payload__';
    ELSIF v_mode='spoof_constraint' THEN
        RAISE EXCEPTION USING ERRCODE='23505',MESSAGE='__payload__',DETAIL='__payload__',HINT='__payload__',
            SCHEMA='public',TABLE='notes',COLUMN='note_id',CONSTRAINT='__payload__';
    ELSIF v_mode IN ('40001','40P01','P0004') THEN
        RAISE EXCEPTION USING ERRCODE=v_mode,MESSAGE='__payload__',DETAIL='__payload__',HINT='__payload__';
    END IF;
    RAISE EXCEPTION 'Unknown Notes synthetic fault mode';
END;
$fault$;
CREATE TRIGGER opal_notes_fault BEFORE INSERT ON public.notes
FOR EACH ROW EXECUTE FUNCTION pg_temp.notes_fault();

CREATE FUNCTION pg_temp.notes_native(
    p_label TEXT,p_json JSON,p_mode TEXT,p_state TEXT,p_operation TEXT,
    p_schema TEXT,p_table TEXT,p_column TEXT,p_constraint TEXT,p_attempts INTEGER
) RETURNS SETOF TEXT LANGUAGE plpgsql AS $native$
DECLARE v_before JSONB:=pg_temp.notes_state()->'rows'; v_attempts BIGINT; v_result JSONB; v_expected JSONB;
BEGIN
    PERFORM SET_CONFIG('opal.notes_fault',p_mode,true);
    v_expected:=pg_temp.notes_probe(-1064501,'synthetic','Synthetic fixture',p_json,true);
    v_attempts:=pg_temp.notes_attempts();
    v_result:=pg_temp.notes_probe(-1064501,'synthetic','Synthetic fixture',p_json);
    PERFORM SET_CONFIG('opal.notes_fault','',true);
    RETURN NEXT ok(v_result->>'state' IS NOT DISTINCT FROM p_state,p_label||': native SQLSTATE unchanged');
        RETURN NEXT ok((v_result-'context') IS NOT DISTINCT FROM (v_expected-'context')
            AND POSITION('p_insert_notes(' IN v_result->>'context')>0
            AND CASE WHEN p_mode LIKE 'spoof_%' OR p_mode IN ('40001','40P01','P0004') THEN
                SPLIT_PART(v_result->>'context',E'\n',1)=SPLIT_PART(v_expected->>'context',E'\n',1)
            ELSE true END,
            p_label||': original native diagnostic tuple and source context retained internally');
    RETURN NEXT ok((v_result->>'succeeded')::BOOLEAN=false
        AND v_before IS NOT DISTINCT FROM (pg_temp.notes_state()->'rows'),p_label||': no partial or unrelated mutation');
    RETURN NEXT ok(pg_temp.notes_attempts()-v_attempts=p_attempts,p_label||': exact attempt count and no retry');
END;
$native$;

-- -----------------------------------------------------------------------------
-- Scenario: Valid JSON fails during decoded-key enumeration or text extraction.
-- Setup: Original JSON accepts Unicode zero escape; conversion occurs after procedure entry.
-- Expected: Native UTF-8 22P05, no insert attempts; current diagnostics match direct SQL.
-- -----------------------------------------------------------------------------
SELECT * FROM pg_temp.notes_native('decoded key conversion','{"\u0000":"__payload__"}',
    '','22P05','input processing','','','','',0);
SELECT * FROM pg_temp.notes_native('Note text conversion','{"note_text":"\u0000"}',
    '','22P05','input processing','','','','',0);

-- -----------------------------------------------------------------------------
-- Scenario: Actual Notes primary-key and not-null failures preserve database integrity.
-- Setup: Gated trigger duplicates sentinel ID or nulls required Note text; real constraints fail.
-- Expected: 23505/notes_pk and 23502/note_text, one attempt, original current diagnostics.
-- -----------------------------------------------------------------------------
SELECT * FROM pg_temp.notes_native('genuine primary key','{"note_text":"__fault__"}',
    'native_pk','23505','insert','public','notes','','notes_pk',1);
SELECT * FROM pg_temp.notes_native('genuine not null','{"note_text":"__fault__"}',
    'native_notnull','23502','insert','public','notes','note_text','',1);

-- -----------------------------------------------------------------------------
-- Scenario: Trigger diagnostics distinguish historical sanitisation from current rethrow.
-- Setup: Five gated triggers spoof all fields, schema, table, column or constraint.
-- Expected: Historical allowlist; current complete tuple/source context; no marker printed.
-- -----------------------------------------------------------------------------
SELECT * FROM pg_temp.notes_native('spoof all','{"note_text":"__fault__"}',
    'spoof_all','P0001','insert','','','','',1);
SELECT * FROM pg_temp.notes_native('spoof schema','{"note_text":"__fault__"}',
    'spoof_schema','P0001','insert','','','','',1);
SELECT * FROM pg_temp.notes_native('spoof table','{"note_text":"__fault__"}',
    'spoof_table','P0001','insert','','','','',1);
SELECT * FROM pg_temp.notes_native('spoof column','{"note_text":"__fault__"}',
    'spoof_column','23502','insert','public','notes','','',1);
SELECT * FROM pg_temp.notes_native('spoof constraint','{"note_text":"__fault__"}',
    'spoof_constraint','23505','insert','public','notes','note_id','',1);

-- -----------------------------------------------------------------------------
-- Scenario: Transient and assertion states remain failures without internal retry.
-- Setup: Inject 40001, 40P01 and P0004; capture diagnostic markers without printing them.
-- Expected: Original state propagates; no retry or successful partial Note.
-- -----------------------------------------------------------------------------
SELECT * FROM pg_temp.notes_native('serialization state','{"note_text":"__fault__"}',
    '40001','40001','insert','','','','',1);
SELECT * FROM pg_temp.notes_native('deadlock state','{"note_text":"__fault__"}',
    '40P01','40P01','insert','','','','',1);
SELECT * FROM pg_temp.notes_native('assertion state','{"note_text":"__fault__"}',
    'P0004','P0004','insert','','','','',1);

-- -----------------------------------------------------------------------------
-- Scenario: A real statement timeout cancels inside the child without retry.
-- Setup: Gated trigger increments temporary sequence then sleeps; separate 100ms SET.
-- Expected: 57014, current native timeout diagnostics, one attempt, rollback and fixture removal.
-- -----------------------------------------------------------------------------
SELECT CURRENT_SETTING('statement_timeout') AS notes_original_timeout \gset
CREATE TEMP TABLE notes_cancel_before AS
SELECT pg_temp.notes_state()->'rows' AS rows,pg_temp.notes_attempts() AS attempts;
SELECT SET_CONFIG('opal.notes_fault','cancel',true) AS notes_cancel_mode \gset
SET LOCAL statement_timeout='100ms';
CREATE TEMP TABLE notes_cancel_result AS
SELECT pg_temp.notes_probe(-1064501,'synthetic','Synthetic fixture','{"note_text":"__fault__"}') AS result;
-- The probe catches all specified errors so cleanup precedes every assertion.
SELECT SET_CONFIG('statement_timeout',:'notes_original_timeout',true) AS notes_restored_timeout \gset
SELECT SET_CONFIG('opal.notes_fault','',true) AS notes_fault_off \gset
CREATE TEMP TABLE notes_cancel_cleanup(state TEXT);
DO $cleanup$
BEGIN
    DROP TRIGGER opal_notes_fault ON public.notes;
    INSERT INTO notes_cancel_cleanup VALUES (NULL);
EXCEPTION WHEN query_canceled OR assert_failure OR OTHERS THEN
    INSERT INTO notes_cancel_cleanup VALUES (SQLSTATE);
END;
$cleanup$;
SELECT ok((SELECT result->>'state'='57014' FROM notes_cancel_result),'actual cancellation preserves 57014');
SELECT ok((SELECT result->>'message'='canceling statement due to statement timeout'
    AND result->>'detail'='' AND result->>'hint'='' AND result->>'schema'='' AND result->>'table'=''
    AND result->>'column'='' AND result->>'constraint'='' AND result->>'datatype'=''
    AND POSITION('pg_sleep' IN LOWER(result->>'context'))>0
    AND POSITION('notes_fault(' IN result->>'context')>0
    AND POSITION('p_insert_notes(' IN result->>'context')>0 FROM notes_cancel_result),
    'cancellation preserves original timeout message and originating context internally');
SELECT ok((SELECT (result->>'succeeded')::BOOLEAN=false FROM notes_cancel_result)
    AND (SELECT rows FROM notes_cancel_before) IS NOT DISTINCT FROM (pg_temp.notes_state()->'rows'),
    'cancellation leaves no successful or partial Note');
SELECT ok(pg_temp.notes_attempts()-(SELECT attempts FROM notes_cancel_before)=1,
    'cancellation reached gated trigger exactly once with no internal retry');
SELECT ok(CURRENT_SETTING('statement_timeout')=:'notes_original_timeout'
    AND CURRENT_SETTING('opal.notes_fault')='','original timeout and fault mode restored before assertions');
SELECT ok((SELECT state IS NULL FROM notes_cancel_cleanup)
    AND NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.notes'::REGCLASS AND tgname='opal_notes_fault'),
    'cancellation fixture removed with separate cleanup outcome');

-- -----------------------------------------------------------------------------
-- Scenario: Caller rollback removes both its new account and Note.
-- Setup: Save rows outside savepoint; capture observations in psql variables before rollback.
-- Expected: Visible inserted Note/account disappear; complete scoped rows restored; sequence not reclaimed.
-- -----------------------------------------------------------------------------
SELECT (pg_temp.notes_state()->'rows')::TEXT AS notes_rollback_rows \gset
SELECT last_value AS notes_rollback_sequence FROM public.note_id_seq \gset
SAVEPOINT notes_caller;
SELECT pg_temp.notes_account(-1064598,'N045-rollback');
CALL public.p_insert_notes(-1064598,'synthetic','Synthetic fixture','{"note_text":"Synthetic caller rollback"}');
SELECT EXISTS(SELECT 1 FROM public.notes WHERE associated_record_id='-1064598'
    AND note_text='Synthetic caller rollback') AS notes_rollback_visible \gset
ROLLBACK TO SAVEPOINT notes_caller;
RELEASE SAVEPOINT notes_caller;
SELECT ok(:'notes_rollback_visible'::BOOLEAN,'caller saw its own inserted Note');
SELECT ok(NOT EXISTS(SELECT 1 FROM public.respondent_accounts WHERE respondent_account_id=-1064598),
    'caller rollback removes its publication account');
SELECT ok(NOT EXISTS(SELECT 1 FROM public.notes WHERE associated_record_type='respondent_accounts'
    AND associated_record_id='-1064598'),'caller rollback removes its publication Note');
SELECT ok(pg_temp.notes_state()->'rows' IS NOT DISTINCT FROM :'notes_rollback_rows'::JSONB,
    'caller rollback restores every scoped row');
SELECT ok((SELECT last_value>:'notes_rollback_sequence'::BIGINT AND is_called FROM public.note_id_seq),
    'caller rollback permits unreclaimed sequence consumption');

CREATE EXTENSION IF NOT EXISTS dblink WITH SCHEMA public;
CREATE FUNCTION pg_temp.notes_committed() RETURNS JSONB LANGUAGE plpgsql AS $committed$
DECLARE
    v_connection TEXT:=FORMAT(
        'host=127.0.0.1 port=5432 dbname=%L user=postgres connect_timeout=5 options=%L',
        CURRENT_DATABASE(),
        '-csearch_path=pg_catalog,public -cstatement_timeout=20000 -clock_timeout=5000 -cidle_in_transaction_session_timeout=30000');
    v_token TEXT:=FORMAT('%s:%s',PG_BACKEND_PID(),CLOCK_TIMESTAMP());
    v_rows_before JSONB:=pg_temp.notes_state()->'rows';
    v_primary TEXT; v_cleanup TEXT; v_disconnect TEXT;
    v_independent BOOLEAN:=false; v_success BOOLEAN:=false; v_removed BOOLEAN:=false;
    v_rollback_marker BOOLEAN:=false;
    v_result JSONB; v_note public.notes%ROWTYPE; v_name TEXT; v_count BIGINT;
    v_state_query TEXT:=$query$
        SELECT JSONB_BUILD_OBJECT(
            'account',(SELECT TO_JSONB(a) FROM public.respondent_accounts a WHERE respondent_account_id=-1064599),
            'application',(SELECT TO_JSONB(a) FROM public.maintenance_applications a WHERE application_id=32046),
            'unit',(SELECT TO_JSONB(b) FROM public.business_units b WHERE business_unit_id=32046))
    $query$;
BEGIN
    IF COALESCE(public.DBLINK_GET_CONNECTIONS(),ARRAY[]::TEXT[]) && ARRAY['po10645_setup','po10645_clean'] THEN
        RAISE EXCEPTION 'Notes remote connection-name collision';
    END IF;
    BEGIN
        PERFORM public.DBLINK_CONNECT('po10645_setup',v_connection);
        -- All rows and durable ownership receipt commit atomically on the remote backend.
        PERFORM public.DBLINK_EXEC('po10645_setup',FORMAT($setup$
            BEGIN;
            DO $guard$ BEGIN
                IF TO_REGNAMESPACE('opal_test_notes_committed') IS NOT NULL
                   OR EXISTS(SELECT 1 FROM public.business_units WHERE business_unit_id=32046 OR business_unit_code='N046')
                   OR EXISTS(SELECT 1 FROM public.maintenance_applications WHERE application_id=32046 OR application_code='N10646')
                   OR EXISTS(SELECT 1 FROM public.respondent_accounts WHERE respondent_account_id=-1064599
                             OR account_number='N046-committed') THEN
                    RAISE EXCEPTION 'Notes committed-fixture collision';
                END IF;
            END; $guard$;
            INSERT INTO public.business_units(business_unit_id,business_unit_code,business_unit_name,business_unit_type,welsh_language)
            VALUES (32046,'N046','Synthetic committed Notes area','Area',false);
            INSERT INTO public.maintenance_applications(application_id,application_code,application_title,application_group,active,date_used_from)
            VALUES (32046,'N10646','Synthetic committed Notes application','Synthetic',true,DATE '2026-01-01');
            INSERT INTO public.respondent_accounts(
                respondent_account_id,business_unit_id,account_number,application_id,
                account_balance,orders_balance,orders_amount,payment_period,total_arrears,account_status,
                last_movement_date,date_arrears_last_updated,allow_cheques,cheque_clearance_period,
                credit_trans_clearance_period,casefile_type,interest_flag,indexation,payment_arrangement,
                account_comment,version_number)
            VALUES (-1064599,32046,'N046-committed',32046,0,0,0,'Weekly',0,'L',
                TIMESTAMP '2026-01-01',TIMESTAMP '2026-01-01',false,0,0,'REMO In',false,'None','Direct',
                'Synthetic committed account comment',1);
            CREATE SCHEMA opal_test_notes_committed;
            CREATE TABLE opal_test_notes_committed.owner(token TEXT PRIMARY KEY,state JSONB NOT NULL);
            INSERT INTO opal_test_notes_committed.owner VALUES (%L,(%s));
            COMMIT;
        $setup$,v_token,v_state_query));
        SELECT observed.pid<>PG_BACKEND_PID() AND observed.visible INTO v_independent
        FROM public.DBLINK(v_connection,FORMAT($visible$
            SELECT PG_BACKEND_PID(),EXISTS(SELECT 1 FROM public.respondent_accounts
                WHERE respondent_account_id=-1064599 AND business_unit_id=32046 AND application_id=32046)
                AND EXISTS(SELECT 1 FROM opal_test_notes_committed.owner WHERE token=%L)
        $visible$,v_token)) observed(pid INTEGER,visible BOOLEAN);
        SELECT COUNT(*) INTO v_count FROM public.notes;
        BEGIN
            v_result:=pg_temp.notes_probe(-1064599,'synthetic','Synthetic fixture','{"note_text":"Synthetic committed Note"}');
            SELECT * INTO v_note FROM public.notes WHERE note_id=(v_result->>'id')::BIGINT;
            v_success:=(v_result->>'succeeded')::BOOLEAN=true
                AND (SELECT COUNT(*) FROM public.notes)=v_count+1
                AND v_note.note_type='NT' AND v_note.associated_record_type='respondent_accounts'
                AND v_note.associated_record_id='-1064599' AND v_note.note_text='Synthetic committed Note'
                AND v_note.posted_by='synthetic' AND v_note.posted_by_name='Synthetic fixture'
                AND v_note.posted_date=TRANSACTION_TIMESTAMP() AT TIME ZONE 'UTC';
            IF NOT COALESCE((v_result->>'succeeded')::BOOLEAN,false) THEN
                v_primary:=v_result->>'state';
            END IF;
            v_rollback_marker:=true;
            RAISE EXCEPTION USING ERRCODE='ZX001',MESSAGE='Notes test rollback boundary';
        EXCEPTION WHEN SQLSTATE 'ZX001' THEN
            IF NOT v_rollback_marker THEN v_primary:='ZX001'; END IF;
        WHEN query_canceled OR assert_failure OR OTHERS THEN
            v_primary:=SQLSTATE;
        END;
    EXCEPTION WHEN query_canceled OR assert_failure OR OTHERS THEN
        v_primary:=SQLSTATE;
    END;

    -- Close setup first, rolling back any uncommitted/ambiguous setup transaction.
    BEGIN
        IF 'po10645_setup'=ANY(COALESCE(public.DBLINK_GET_CONNECTIONS(),ARRAY[]::TEXT[])) THEN
            PERFORM public.DBLINK_DISCONNECT('po10645_setup');
        END IF;
    EXCEPTION WHEN query_canceled OR assert_failure OR OTHERS THEN
        v_disconnect:=SQLSTATE;
    END;
    BEGIN
        -- Local trigger DDL holds the Notes lock until rollback; verify removal here.
        -- The independent cleanup backend still verifies durable ownership and absence.
        IF EXISTS(SELECT 1 FROM public.notes WHERE associated_record_type='respondent_accounts'
                  AND associated_record_id='-1064599') THEN
            RAISE EXCEPTION 'Notes fixture removal order mismatch';
        END IF;

        PERFORM public.DBLINK_CONNECT('po10645_clean',v_connection);
        PERFORM public.DBLINK_EXEC('po10645_clean',FORMAT($cleanup$
            BEGIN;
            DO $owned$
            DECLARE v_count BIGINT;
            BEGIN
                IF TO_REGNAMESPACE('opal_test_notes_committed') IS NULL THEN
                    IF EXISTS(SELECT 1 FROM public.respondent_accounts WHERE respondent_account_id=-1064599 OR account_number='N046-committed')
                       OR EXISTS(SELECT 1 FROM public.maintenance_applications WHERE application_id=32046 OR application_code='N10646')
                       OR EXISTS(SELECT 1 FROM public.business_units WHERE business_unit_id=32046 OR business_unit_code='N046') THEN
                        RAISE EXCEPTION 'Notes fixture ownership receipt absent';
                    END IF;
                    RETURN;
                END IF;
                IF TO_REGCLASS('opal_test_notes_committed.owner') IS NULL THEN
                    RAISE EXCEPTION 'Notes fixture ownership relation absent';
                END IF;
                IF (SELECT COUNT(*) FROM opal_test_notes_committed.owner)<>1
                   OR NOT EXISTS(SELECT 1 FROM opal_test_notes_committed.owner WHERE token=%L)
                   OR (SELECT state FROM opal_test_notes_committed.owner) IS DISTINCT FROM (%s) THEN
                    RAISE EXCEPTION 'Notes fixture ownership or removal order mismatch';
                END IF;
                DELETE FROM public.respondent_accounts WHERE respondent_account_id=-1064599;
                GET DIAGNOSTICS v_count=ROW_COUNT;
                IF v_count<>1 THEN RAISE EXCEPTION 'Notes account cleanup count mismatch'; END IF;
                DELETE FROM public.maintenance_applications WHERE application_id=32046;
                GET DIAGNOSTICS v_count=ROW_COUNT;
                IF v_count<>1 THEN RAISE EXCEPTION 'Notes application cleanup count mismatch'; END IF;
                DELETE FROM public.business_units WHERE business_unit_id=32046;
                GET DIAGNOSTICS v_count=ROW_COUNT;
                IF v_count<>1 THEN RAISE EXCEPTION 'Notes Business Unit cleanup count mismatch'; END IF;
                DROP TABLE opal_test_notes_committed.owner;
                DROP SCHEMA opal_test_notes_committed;
            END;
            $owned$;
            COMMIT;
        $cleanup$,v_token,v_state_query));
        SELECT r.pid<>PG_BACKEND_PID() AND r.absent INTO v_removed
        FROM public.DBLINK(v_connection,$absent$
            SELECT PG_BACKEND_PID(),TO_REGNAMESPACE('opal_test_notes_committed') IS NULL
                AND TO_REGCLASS('opal_test_notes_committed.owner') IS NULL
                AND NOT EXISTS(SELECT 1 FROM public.respondent_accounts WHERE respondent_account_id=-1064599 OR account_number='N046-committed')
                AND NOT EXISTS(SELECT 1 FROM public.maintenance_applications WHERE application_id=32046 OR application_code='N10646')
                AND NOT EXISTS(SELECT 1 FROM public.business_units WHERE business_unit_id=32046 OR business_unit_code='N046')
        $absent$) r(pid INTEGER,absent BOOLEAN);
    EXCEPTION WHEN query_canceled OR assert_failure OR OTHERS THEN
        v_cleanup:=SQLSTATE;
    END;
    FOREACH v_name IN ARRAY ARRAY['po10645_setup','po10645_clean'] LOOP
        BEGIN
            IF v_name=ANY(COALESCE(public.DBLINK_GET_CONNECTIONS(),ARRAY[]::TEXT[])) THEN
                PERFORM public.DBLINK_DISCONNECT(v_name);
            END IF;
        EXCEPTION WHEN query_canceled OR assert_failure OR OTHERS THEN
            v_disconnect:=COALESCE(v_disconnect||',','')||SQLSTATE;
        END;
    END LOOP;
    RETURN JSONB_BUILD_OBJECT('primary',v_primary,'cleanup',v_cleanup,'disconnect',v_disconnect,
        'independent',v_independent,'success',v_success,'removed',v_removed,
        'notes_restored',(v_rows_before->'notes') IS NOT DISTINCT FROM (pg_temp.notes_state()->'rows'->'notes'),
        'all_rows_restored',v_rows_before IS NOT DISTINCT FROM (pg_temp.notes_state()->'rows'),
        'closed',NOT(COALESCE(public.DBLINK_GET_CONNECTIONS(),ARRAY[]::TEXT[]) && ARRAY['po10645_setup','po10645_clean']));
END;
$committed$;

-- -----------------------------------------------------------------------------
-- Scenario: A truly committed existing target is accepted and independently removed.
-- Setup: Remote atomic setup owns prerequisites/receipt; main Note rolls back before cleanup.
-- Expected: Independent visibility, exact one Note, all owned rows gone, connections closed.
-- -----------------------------------------------------------------------------
SELECT CURRENT_SETTING('statement_timeout') AS notes_remote_original_timeout \gset
SET LOCAL statement_timeout='60s';
CREATE TEMP TABLE notes_committed_result AS SELECT pg_temp.notes_committed() AS result;
SELECT SET_CONFIG('statement_timeout',:'notes_remote_original_timeout',true) AS notes_remote_restored_timeout \gset
SELECT ok((SELECT result->>'primary' IS NULL AND (result->>'independent')::BOOLEAN FROM notes_committed_result),
    'committed target visible independently with no primary failure');
SELECT ok((SELECT (result->>'success')::BOOLEAN FROM notes_committed_result),'committed target accepts one exactly mapped Note');
SELECT ok((SELECT (result->>'notes_restored')::BOOLEAN FROM notes_committed_result),'main Note rolled back before remote cleanup');
SELECT ok((SELECT result->>'cleanup' IS NULL AND (result->>'removed')::BOOLEAN FROM notes_committed_result),
    'owned committed rows and ownership schema absent on independent backend');
SELECT ok((SELECT result->>'disconnect' IS NULL AND (result->>'closed')::BOOLEAN FROM notes_committed_result)
    AND CURRENT_SETTING('statement_timeout')=:'notes_remote_original_timeout','all remote connections closed and original timeout restored');
SELECT ok((SELECT (result->>'all_rows_restored')::BOOLEAN FROM notes_committed_result),'committed fixture lifecycle restores all five scoped row sets');

-- -----------------------------------------------------------------------------
-- Scenario: Every call preserves preexisting Notes, target rows and Draft lifecycle.
-- Setup: Compare initial local fixture snapshots after all failures and remote cleanup.
-- Expected: No changes to sentinels, accounts, reference fixtures or Draft status/snapshot/timeline.
-- -----------------------------------------------------------------------------
SELECT ok(NOT EXISTS(SELECT 1 FROM notes_scope_before b CROSS JOIN LATERAL JSONB_ARRAY_ELEMENTS_TEXT(b.rows->'notes') old
    WHERE NOT EXISTS(SELECT 1 FROM public.notes n WHERE ROW_TO_JSON(n)::TEXT=old.value)),
    'all preexisting Notes unchanged');
SELECT ok((SELECT rows->'respondent_accounts' FROM notes_scope_before)
    IS NOT DISTINCT FROM (pg_temp.notes_state()->'rows'->'respondent_accounts'),'all target accounts unchanged');
SELECT ok((SELECT rows->'draft_casefiles' FROM notes_scope_before)
    IS NOT DISTINCT FROM (pg_temp.notes_state()->'rows'->'draft_casefiles'),'Draft status snapshot and timeline unchanged');
SELECT ok((SELECT rows-'notes'-'respondent_accounts'-'draft_casefiles' FROM notes_scope_before)
    IS NOT DISTINCT FROM ((pg_temp.notes_state()->'rows')-'notes'-'respondent_accounts'-'draft_casefiles'),
    'Business Unit and application fixtures unchanged');
SELECT * FROM finish();
ROLLBACK;
