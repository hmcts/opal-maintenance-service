/**
 * OPAL Program
 *
 * MODULE      : p_insert_third_party_contacts_pgtap_tests.sql
 *
 * DESCRIPTION : Verify contact mapping, validation and native errors on fresh
 *               and predecessor-upgrade PostgreSQL targets.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket        Nature of Change
 * ----------  -------------  ------------  ----------------------------------------
 * 17/10/2026  Frankie Moran  PO-10651      Initial pgTAP test suite.
 */
-- OPAL-DB-UPGRADE {"id":"p_insert_third_party_contacts.create","candidate":"ddl/V1_59__create_p_insert_third_party_contacts_procedure.sql","scope":"both","data":"migration-created-only","inputs":["src/main/resources/db/migration/ddl/V1_2__create_countries_table.sql","src/main/resources/db/migration/ddl/V1_22__create_third_party_contact_table.sql","src/main/resources/db/migration/data/allEnvs/V1_5__insert_countries_reference_data.sql","src/main/resources/db/migration/data/dev/V1_3__insert_countries_dev_data.sql","src/main/resources/db/migration/data/dev/V1_4__insert_inactive_country_dev_data.sql"],"contract":{"type":"additive","objects":{"created":[{"kind":"routine","identity":"public.p_insert_third_party_contacts(json)"}],"replaced":[]},"preserve":{"rows":["public.countries","public.third_party_contact"],"tables":["public.countries","public.third_party_contact"],"routines":[],"enums":[],"sequences":["public.country_id_seq","public.third_party_contact_id_seq"]},"assertion":"p_insert_third_party_contacts.current"}}

\set ON_ERROR_STOP 1
\if :{?opal_assertion_group}
\else
    \set opal_assertion_group p_insert_third_party_contacts.current
\endif
SELECT :'opal_assertion_group' = 'p_insert_third_party_contacts.current' AS valid_group
\gset
\if :valid_group
\else
    DO $group$ BEGIN RAISE EXCEPTION 'Unknown third-party contact assertion group'; END; $group$;
\endif
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SET LOCAL search_path = public, pg_catalog;
SET LOCAL TIME ZONE 'UTC';
SET LOCAL plpgsql.check_asserts = on;

SET LOCAL standard_conforming_strings = on;
-- -----------------------------------------------------------------------------
-- Scenario: Functional fixtures coexist with existing migration-created data.
-- Setup: Reserve explicit synthetic IDs/codes and refuse collisions before inserts.
-- Expected: No existing row is deleted/updated; account/draft sentinels are nonempty.
-- -----------------------------------------------------------------------------
DO $guard$
BEGIN
    IF EXISTS (SELECT 1 FROM public.countries
               WHERE country_id BETWEEN -1065108 AND -1065101
                  OR cjs_code IN (31001,31002,31003,31004,31005,31006,-32768,32767))
       OR EXISTS (SELECT 1 FROM public.third_party_contact WHERE third_party_contact_id = -1065199)
       OR EXISTS (SELECT 1 FROM public.business_units WHERE business_unit_id = 32051 OR business_unit_code = 'P051')
       OR EXISTS (SELECT 1 FROM public.maintenance_applications WHERE application_id = 32051 OR application_code = 'T10651')
       OR EXISTS (SELECT 1 FROM public.respondent_accounts WHERE respondent_account_id = -1065199)
       OR EXISTS (SELECT 1 FROM public.creditor_accounts WHERE creditor_account_id = -1065199)
       OR EXISTS (SELECT 1 FROM public.draft_casefiles WHERE draft_casefile_id = -1065199) THEN
        RAISE EXCEPTION 'Synthetic contact fixture collision';
    END IF;
END;
$guard$;
CREATE TEMP TABLE ctc_country_sequence_before AS
SELECT last_value, is_called FROM public.country_id_seq;
INSERT INTO public.countries (country_id,cjs_code,country_name,date_used_from,date_used_to,active)
VALUES
    (-1065101,31001,'Synthetic active',DATE '2000-01-01',NULL,true),
    (-1065102,31002,'Synthetic deactivated',DATE '2000-01-01',NULL,false),
    (-1065103,31003,'Synthetic expired',DATE '2000-01-01',CURRENT_DATE-1,true),
    (-1065104,31004,'Synthetic future',CURRENT_DATE+1,NULL,true),
    (-1065105,31005,'Synthetic ambiguous active',DATE '2000-01-01',NULL,true),
    (-1065106,31005,'Synthetic ambiguous inactive',DATE '2000-01-01',NULL,false),
    (-1065107,-32768,'Synthetic minimum',DATE '2000-01-01',NULL,true),
    (-1065108,32767,'Synthetic maximum',DATE '2000-01-01',NULL,true);
INSERT INTO public.third_party_contact (
    third_party_contact_id,name_organisation,relationship,address_line_1,country
) VALUES (-1065199,'Synthetic sentinel','Synthetic relationship','Synthetic Road',-1065101);
INSERT INTO public.business_units (
    business_unit_id,business_unit_code,business_unit_name,business_unit_type,welsh_language
) VALUES (32051,'P051','Synthetic contact area','Area',false);
INSERT INTO public.maintenance_applications (
    application_id,application_code,application_title,application_group,active,date_used_from
) VALUES (32051,'T10651','Synthetic contact application','Synthetic',true,DATE '2000-01-01');
INSERT INTO public.respondent_accounts (
    respondent_account_id,business_unit_id,account_number,application_id,
    account_balance,orders_balance,orders_amount,payment_period,total_arrears,
    account_status,last_movement_date,date_arrears_last_updated,allow_cheques,
    cheque_clearance_period,credit_trans_clearance_period,casefile_type,
    interest_flag,indexation,payment_arrangement,version_number,third_party_contact_id
) VALUES (
    -1065199,32051,'TPC-RESP',32051,0,0,0,'Weekly',0,'L',
    TIMESTAMP '2000-01-01 00:00:00',TIMESTAMP '2000-01-01 00:00:00',
    true,10,0,'REMO In',false,'None','Court',1,-1065199
);
INSERT INTO public.creditor_accounts (
    creditor_account_id,business_unit_id,account_number,creditor_account_type,
    from_suspense,hold_payout,pay_by_bacs,third_party_contact_id
) VALUES (-1065199,32051,'TPC-CRED','MN',false,false,false,-1065199);
INSERT INTO public.draft_casefiles (
    draft_casefile_id,business_unit_id,created_date,submitted_by,submitted_by_name,
    casefile,casefile_snapshot,casefile_type,casefile_status,casefile_status_date,
    status_message,timeline_data,account_id,version_number
) VALUES (
    -1065199,32051,TIMESTAMP '2000-01-01 00:00:00','synthetic','Synthetic fixture',
    '{"synthetic":1, "synthetic":2}','{ "label" : "Synthetic" }',
    'REMO In','SUBMITTED',TIMESTAMP '2000-01-01 00:00:00',
    'Synthetic unchanged status','[ { "event" : "synthetic" } ]',-1065199,1
);
CREATE TEMP TABLE ctc_base (payload JSONB NOT NULL, expected JSONB NOT NULL);
INSERT INTO ctc_base VALUES (
    '{"name":"Synthetic contact","relationship":"Synthetic relation","reference":"Synthetic ref",
      "address":{"address_line_1":"Synthetic Road","address_line_2":"Synthetic 2",
      "address_line_3":"Synthetic 3","address_line_4":"Synthetic 4","address_line_5":"Synthetic 5",
      "postcode":"SYN 1","cjs_code":31001}}',
    '{"name_organisation":"Synthetic contact","relationship":"Synthetic relation","reference":"Synthetic ref",
      "address_line_1":"Synthetic Road","address_line_2":"Synthetic 2",
      "address_line_3":"Synthetic 3","address_line_4":"Synthetic 4","address_line_5":"Synthetic 5",
      "postcode":"SYN 1","country":-1065101,"version_number":null}'
);
CREATE TEMP TABLE ctc_cases (
    label TEXT PRIMARY KEY,
    payload JSON,
    expected_state TEXT NOT NULL,
    expected JSONB,
    expected_diag JSONB NOT NULL DEFAULT '{}',
    mode TEXT NOT NULL DEFAULT 'normal'
);
CREATE TEMP TABLE ctc_outputs (label TEXT PRIMARY KEY, id BIGINT NOT NULL);
CREATE SEQUENCE pg_temp.ctc_attempts START 1;

CREATE FUNCTION pg_temp.ctc_rows() RETURNS JSONB LANGUAGE plpgsql AS $rows$
DECLARE v_table TEXT; v_values JSONB; v_result JSONB := '{}';
BEGIN
    FOR v_table IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename LOOP
        EXECUTE FORMAT(
            'SELECT COALESCE(JSONB_AGG(value ORDER BY value),''[]''::JSONB)
             FROM (SELECT ROW_TO_JSON(t)::TEXT AS value FROM public.%I t) observed',
            v_table) INTO v_values;
        v_result := v_result || JSONB_BUILD_OBJECT(v_table,v_values);
    END LOOP;
    RETURN v_result;
END;
$rows$;

CREATE FUNCTION pg_temp.ctc_probe(p_json JSON, p_operation TEXT DEFAULT 'call')
RETURNS JSONB LANGUAGE plpgsql AS $probe$
DECLARE
    v_id BIGINT; v_country BIGINT;
    v_state TEXT; v_message TEXT; v_detail TEXT; v_hint TEXT;
    v_schema TEXT; v_table TEXT; v_column TEXT; v_constraint TEXT; v_datatype TEXT; v_context TEXT;
BEGIN
    CASE p_operation
        WHEN 'country' THEN
            SELECT country_id INTO STRICT v_country FROM public.countries
            WHERE cjs_code = (p_json #>> '{address,cjs_code}')::SMALLINT;
        WHEN 'decode' THEN
            PERFORM key FROM JSON_EACH(p_json);
            PERFORM p_json->>'name';
        WHEN 'numeric' THEN
            PERFORM (p_json #>> '{address,cjs_code}')::NUMERIC;
        WHEN 'insert' THEN
            INSERT INTO public.third_party_contact (
                name_organisation,relationship,reference,address_line_1,address_line_2,
                address_line_3,address_line_4,address_line_5,postcode,country
            ) VALUES (
                'Synthetic contact','Synthetic relation','Synthetic ref','Synthetic Road',
                'Synthetic 2','Synthetic 3','Synthetic 4','Synthetic 5','SYN 1',-1065101
            ) RETURNING third_party_contact_id INTO v_id;
        WHEN 'call' THEN CALL public.p_insert_third_party_contacts(p_json,v_id);
        ELSE RAISE EXCEPTION 'Unknown contact test probe operation';
    END CASE;
    RETURN JSONB_BUILD_OBJECT('state','00000','succeeded',true,'id',v_id);
EXCEPTION WHEN query_canceled OR assert_failure OR OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_message = MESSAGE_TEXT,
        v_detail = PG_EXCEPTION_DETAIL, v_hint = PG_EXCEPTION_HINT, v_schema = SCHEMA_NAME,
        v_table = TABLE_NAME, v_column = COLUMN_NAME, v_constraint = CONSTRAINT_NAME,
        v_datatype = PG_DATATYPE_NAME, v_context = PG_EXCEPTION_CONTEXT;

    RETURN JSONB_BUILD_OBJECT('state',v_state,'succeeded',false,'id',v_id,
        'message',v_message,'detail',v_detail,'hint',v_hint,'schema',v_schema,
        'table',v_table,'column',v_column,'constraint',v_constraint,
        'datatype',v_datatype,'context',v_context);
END;
$probe$;

CREATE FUNCTION pg_temp.ctc_numeric_payload(p_token TEXT)
RETURNS JSON LANGUAGE sql AS $numeric_fixture$
    SELECT JSON_BUILD_OBJECT(
        'name',payload->'name',
        'relationship',payload->'relationship',
        'reference',payload->'reference',
        'address',(LEFT(((payload->'address')-'cjs_code')::TEXT,-1)
            ||',"cjs_code":'||p_token||'}')::JSON)
    FROM ctc_base;
$numeric_fixture$;


-- Preserve the decimal/exponent lexical forms used by the numeric fixtures.
DO $numeric_fixture_guard$
DECLARE token TEXT;
BEGIN
    FOREACH token IN ARRAY ARRAY['31001.0','3.1001e4','31001e0','1e999999'] LOOP
        IF (pg_temp.ctc_numeric_payload(token) #> '{address,cjs_code}')::TEXT <> token THEN
            RAISE EXCEPTION 'Synthetic contact numeric fixture lost its lexical form';
        END IF;
    END LOOP;
END;
$numeric_fixture_guard$;


-- -----------------------------------------------------------------------------
-- Scenario: Both intended caller shapes use one neutral helper; repeat calls insert.
-- Setup: Two identical present contact objects and a fully populated base object.
-- Expected: One exact mapped row per call, NULL version and distinct generated IDs.
-- -----------------------------------------------------------------------------
INSERT INTO ctc_cases(label,payload,expected_state,expected)
SELECT label,payload::JSON,'00000',expected FROM ctc_base
CROSS JOIN (VALUES ('respondent-present'),('applicant-present'),('repeat-a'),('repeat-b')) calls(label);
INSERT INTO ctc_cases(label,payload,expected_state,expected) VALUES (
    'all-optional-omitted',
    '{"name":"Synthetic contact","relationship":"Synthetic relation","address":{"address_line_1":"Synthetic Road","cjs_code":31001}}',
    '00000',
    '{"name_organisation":"Synthetic contact","relationship":"Synthetic relation","reference":null,
      "address_line_1":"Synthetic Road","address_line_2":null,"address_line_3":null,
      "address_line_4":null,"address_line_5":null,"postcode":null,"country":-1065101,"version_number":null}'
);

-- -----------------------------------------------------------------------------
-- Scenario: Country resolution uses ID and all-row cardinality, ignoring eligibility dates.
-- Setup: Different CJS/ID values, inactive/expired/future rows, absent and ambiguous codes.
-- Expected: Unique rows map to their IDs; absent/ambiguous codes retain P0002/P0003.
-- -----------------------------------------------------------------------------
INSERT INTO ctc_cases(label,payload,expected_state,expected)
SELECT 'country-'||code,
    JSONB_SET(payload,'{address,cjs_code}',TO_JSONB(code))::JSON,state,
    CASE WHEN state='00000' THEN JSONB_SET(expected,'{country}',TO_JSONB(id)) END
FROM ctc_base CROSS JOIN (VALUES
    (31002,-1065102::BIGINT,'00000'),(31003,-1065103,'00000'),(31004,-1065104,'00000'),
    (-32768,-1065107,'00000'),(32767,-1065108,'00000'),
    (31006,0,'P0002'),(31005,0,'P0003')) countries(code,id,state);
UPDATE ctc_cases SET expected_diag = pg_temp.ctc_probe(payload,'country')-'context'-'id'
WHERE expected_state IN ('P0002','P0003');
INSERT INTO ctc_cases(label,payload,expected_state,expected)
SELECT 'integral-'||form,
    pg_temp.ctc_numeric_payload(form),
    '00000',expected
FROM ctc_base CROSS JOIN (VALUES ('31001.0'),('3.1001e4'),('31001e0')) numbers(form);
-- SQL JSON embeds the raw numeric token without JSONB normalization.
INSERT INTO ctc_cases(label,payload,expected_state)
SELECT 'cjs-invalid-'||value::TEXT,
    JSONB_SET(payload,'{address,cjs_code}',value)::JSON,'P0001'
FROM ctc_base CROSS JOIN (VALUES
    ('"31001"'::JSONB),('null'::JSONB),('true'::JSONB),('{}'::JSONB),('[]'::JSONB),
    ('31001.5'::JSONB),('-32769'::JSONB),('32768'::JSONB)) invalid(value);
INSERT INTO ctc_cases(label,payload,expected_state)
SELECT 'cjs-absent',(payload#-'{address,cjs_code}')::JSON,'P0001' FROM ctc_base;

-- -----------------------------------------------------------------------------
-- Scenario: Root/address requiredness and shape reject SQL NULL, JSON null and primitives.
-- Setup: Each otherwise valid input has one controlled object-shape defect.
-- Expected: P0001, no successful OUT and no contact/unrelated row changes.
-- -----------------------------------------------------------------------------
INSERT INTO ctc_cases(label,payload,expected_state) VALUES
    ('root-sql-null',NULL,'P0001'),('root-json-null','null','P0001'),
    ('root-empty','{}','P0001'),('root-number','1','P0001'),
    ('root-bool','true','P0001'),('root-string','"Synthetic"','P0001'),('root-array','[]','P0001');
INSERT INTO ctc_cases(label,payload,expected_state)
SELECT 'address-'||value::TEXT,JSONB_SET(payload,'{address}',value)::JSON,'P0001'
FROM ctc_base CROSS JOIN (VALUES
    ('null'::JSONB),('{}'::JSONB),('1'::JSONB),('true'::JSONB),('"Synthetic"'::JSONB),('[]'::JSONB)) shapes(value);
INSERT INTO ctc_cases(label,payload,expected_state)
SELECT 'address-absent',(payload-'address')::JSON,'P0001' FROM ctc_base;

CREATE TEMP TABLE ctc_fields(path TEXT[] PRIMARY KEY, target TEXT, required BOOLEAN, max_length INTEGER);
INSERT INTO ctc_fields VALUES
    (ARRAY['name'],'name_organisation',true,40),
    (ARRAY['relationship'],'relationship',true,40),
    (ARRAY['reference'],'reference',false,40),
    (ARRAY['address','address_line_1'],'address_line_1',true,30),
    (ARRAY['address','address_line_2'],'address_line_2',false,30),
    (ARRAY['address','address_line_3'],'address_line_3',false,30),
    (ARRAY['address','address_line_4'],'address_line_4',false,30),
    (ARRAY['address','address_line_5'],'address_line_5',false,30),
    (ARRAY['address','postcode'],'postcode',false,10);
-- -----------------------------------------------------------------------------
-- Scenario: Optional omission differs from supplied null/type and supplied blank strings.
-- Setup: Mutate each text field independently, preserving the rest of the valid input.
-- Expected: Required omission fails; optional omission becomes NULL; supplied primitives fail.
-- -----------------------------------------------------------------------------
INSERT INTO ctc_cases(label,payload,expected_state,expected)
SELECT 'omit-'||target,(payload#-path)::JSON,CASE WHEN required THEN 'P0001' ELSE '00000' END,
    CASE WHEN NOT required THEN JSONB_SET(expected,ARRAY[target],'null') END
FROM ctc_base CROSS JOIN ctc_fields;
INSERT INTO ctc_cases(label,payload,expected_state)
SELECT 'type-'||target||'-'||value::TEXT,JSONB_SET(payload,path,value)::JSON,'P0001'
FROM ctc_base CROSS JOIN ctc_fields
CROSS JOIN (VALUES ('null'::JSONB),('123'::JSONB),('true'::JSONB),('{}'::JSONB),('[]'::JSONB)) wrong(value);
INSERT INTO ctc_cases(label,payload,expected_state,expected)
SELECT 'optional-value-'||target||'-'||tag,JSONB_SET(payload,path,TO_JSONB(value::TEXT))::JSON,
    '00000',JSONB_SET(expected,ARRAY[target],TO_JSONB(value::TEXT))
FROM ctc_base CROSS JOIN ctc_fields
CROSS JOIN (VALUES ('empty',''),('spaces','  '),('unicode-space',CHR(160)||CHR(12288))) supplied(tag,value)
WHERE NOT required;

-- -----------------------------------------------------------------------------
-- Scenario: Original character limits apply before bounded PostgreSQL storage.
-- Setup: Every string at its exact limit, one over, empty, and over-limit trailing spaces;
--        address lines additionally at31/35/36; multibyte/combining strings at boundaries.
-- Expected: Original PostgreSQL character counts govern acceptance with exact persistence.
-- -----------------------------------------------------------------------------
INSERT INTO ctc_cases(label,payload,expected_state,expected)
SELECT 'length-'||target||'-'||n,JSONB_SET(payload,path,TO_JSONB(REPEAT('X',n)))::JSON,
    CASE WHEN n>max_length OR (required AND n=0) THEN 'P0001' ELSE '00000' END,
    CASE WHEN n<=max_length AND (NOT required OR n>0)
         THEN JSONB_SET(expected,ARRAY[target],TO_JSONB(REPEAT('X',n))) END
FROM ctc_base CROSS JOIN ctc_fields
CROSS JOIN LATERAL (SELECT DISTINCT n FROM UNNEST(
    CASE WHEN max_length=30 THEN ARRAY[0,30,31,35,36] ELSE ARRAY[0,max_length,max_length+1] END) lengths(n)) sizes;
INSERT INTO ctc_cases(label,payload,expected_state)
SELECT 'trailing-overflow-'||target,
    JSONB_SET(payload,path,TO_JSONB(REPEAT('X',max_length)||' '))::JSON,'P0001'
FROM ctc_base CROSS JOIN ctc_fields;
INSERT INTO ctc_cases(label,payload,expected_state,expected)
SELECT 'fidelity-'||target||'-'||tag,JSONB_SET(payload,path,TO_JSONB(value::TEXT))::JSON,
    CASE WHEN CHAR_LENGTH(value)>max_length THEN 'P0001' ELSE '00000' END,
    CASE WHEN CHAR_LENGTH(value)<=max_length THEN JSONB_SET(expected,ARRAY[target],TO_JSONB(value::TEXT)) END
FROM ctc_base CROSS JOIN ctc_fields
CROSS JOIN LATERAL (VALUES
    ('surrounding','  X  '),
    ('multibyte-limit',REPEAT(CHR(233),max_length)),
    ('multibyte-over',REPEAT(CHR(233),max_length+1)),
    ('combining-limit',REPEAT('e'||CHR(769),max_length/2)),
    ('combining-over',REPEAT('e'||CHR(769),max_length/2)||'X')
) strings(tag,value);

CREATE TEMP TABLE ctc_whitespace(code INTEGER PRIMARY KEY);
INSERT INTO ctc_whitespace VALUES
    (9),(10),(11),(12),(13),(32),(133),(160),(5760),
    (8192),(8193),(8194),(8195),(8196),(8197),(8198),(8199),(8200),(8201),(8202),
    (8232),(8233),(8239),(8287),(12288);
-- -----------------------------------------------------------------------------
-- Scenario: Pinned Unicode blankness applies only to required strings.
-- Setup: Each of25 code points and a mixed set in each required field;
--        U+180E/U+200B/U+FEFF and mixed nonblank strings use independent expectations.
-- Expected: Pinned-only required strings fail; outside-set/nonblank originals persist.
-- -----------------------------------------------------------------------------
INSERT INTO ctc_cases(label,payload,expected_state)
SELECT 'blank-'||target||'-'||code,JSONB_SET(payload,path,TO_JSONB(CHR(code)))::JSON,'P0001'
FROM ctc_base CROSS JOIN ctc_fields CROSS JOIN ctc_whitespace WHERE required;
INSERT INTO ctc_cases(label,payload,expected_state)
SELECT 'blank-mixed-'||target,JSONB_SET(payload,path,TO_JSONB(
    (SELECT STRING_AGG(CHR(code),'' ORDER BY code) FROM ctc_whitespace)))::JSON,'P0001'
FROM ctc_base CROSS JOIN ctc_fields WHERE required;
INSERT INTO ctc_cases(label,payload,expected_state,expected)
SELECT 'outside-white-'||target||'-'||code,JSONB_SET(payload,path,TO_JSONB(CHR(code)))::JSON,
    '00000',JSONB_SET(expected,ARRAY[target],TO_JSONB(CHR(code)))
FROM ctc_base CROSS JOIN ctc_fields CROSS JOIN (VALUES (6158),(8203),(65279)) outside(code) WHERE required;
INSERT INTO ctc_cases(label,payload,expected_state,expected)
SELECT 'mixed-white-'||target||'-'||code,
    JSONB_SET(payload,path,TO_JSONB(CHR(code)||'X'||CHR(code)))::JSON,
    '00000',JSONB_SET(expected,ARRAY[target],TO_JSONB(CHR(code)||'X'||CHR(code)))
FROM ctc_base CROSS JOIN ctc_fields CROSS JOIN ctc_whitespace WHERE required;

-- -----------------------------------------------------------------------------
-- Scenario: Closed decoded allowlists forbid alternate IDs/Country/version and case aliases.
-- Setup: Add forbidden members with null and synthetic values at both levels.
-- Expected: P0001 before insertion; no untrusted member/value appears in deliberate errors.
-- -----------------------------------------------------------------------------
INSERT INTO ctc_cases(label,payload,expected_state)
SELECT 'unknown-root-'||key||'-'||value::TEXT,
    JSONB_SET(payload,ARRAY[key],value)::JSON,'P0001'
FROM ctc_base CROSS JOIN (VALUES ('third_party_contact_id'),('country_id'),('country'),('country_name'),
    ('cjs_code'),('owner_type'),('owner'),('version_number'),('Name'),('Relationship'),('Reference'),
    ('Address'),('__payload__')) members(key)
CROSS JOIN (VALUES ('null'::JSONB),('"__payload__"'::JSONB)) supplied(value);
INSERT INTO ctc_cases(label,payload,expected_state)
SELECT 'unknown-address-'||key||'-'||value::TEXT,
    JSONB_SET(payload,ARRAY['address',key],value)::JSON,'P0001'
FROM ctc_base CROSS JOIN (VALUES ('country_id'),('country_name'),('country'),('version_number'),
    ('address_id'),('owner'),('Cjs_code'),('Address_line_1'),('__payload__')) members(key)
CROSS JOIN (VALUES ('null'::JSONB),('"__payload__"'::JSONB)) supplied(value);
INSERT INTO ctc_cases(label,payload,expected_state)
SELECT 'version-number-'||value::TEXT,JSONB_SET(payload,'{version_number}',value)::JSON,'P0001'
FROM ctc_base CROSS JOIN (VALUES ('0'::JSONB),('1'::JSONB),('-1'::JSONB)) versions(value);

-- -----------------------------------------------------------------------------
-- Scenario: Duplicates are rejected even when equal, valid, or escaped decoded equivalents.
-- Setup: Append each allowed member to original JSON TEXT; never cast these cases to JSONB.
-- Expected: P0001 instead of silently selecting the first/last member.
-- -----------------------------------------------------------------------------
DO $duplicates$
DECLARE b ctc_base%ROWTYPE; k RECORD; spelling TEXT; value JSONB; raw TEXT; variant TEXT;
BEGIN
    SELECT * INTO b FROM ctc_base;
    FOR k IN SELECT e.key,e.value AS original FROM JSONB_EACH(b.payload) e LOOP
        FOREACH variant IN ARRAY ARRAY['equal','different','escaped','escaped-different'] LOOP
            spelling := CASE WHEN variant LIKE 'escaped%' THEN
                '"\u'||LPAD(TO_HEX(ASCII(LEFT(k.key,1))),4,'0')||SUBSTRING(k.key FROM 2)||'"'
                ELSE TO_JSON(k.key)::TEXT END;
            value := CASE WHEN variant NOT IN ('different','escaped-different') THEN k.original
                WHEN k.key='address' THEN JSONB_SET(k.original,'{address_line_1}','"Other Road"')
                ELSE '"Other"'::JSONB END;
            raw := LEFT(b.payload::TEXT,-1)||','||spelling||':'||value::TEXT||'}';
            INSERT INTO ctc_cases(label,payload,expected_state)
            VALUES ('duplicate-root-'||k.key||'-'||variant,raw::JSON,'P0001');
        END LOOP;
    END LOOP;
    FOR k IN SELECT e.key,e.value AS original FROM JSONB_EACH(b.payload->'address') e LOOP
        FOREACH variant IN ARRAY ARRAY['equal','different','escaped','escaped-different'] LOOP
            spelling := CASE WHEN variant LIKE 'escaped%' THEN
                '"\u'||LPAD(TO_HEX(ASCII(LEFT(k.key,1))),4,'0')||SUBSTRING(k.key FROM 2)||'"'
                ELSE TO_JSON(k.key)::TEXT END;
            value := CASE WHEN variant NOT IN ('different','escaped-different') THEN k.original
                WHEN k.key='cjs_code' THEN '31002'::JSONB ELSE '"Other"'::JSONB END;
            raw := LEFT((b.payload->'address')::TEXT,-1)||','||spelling||':'||value::TEXT||'}';
            INSERT INTO ctc_cases(label,payload,expected_state)
            VALUES ('duplicate-address-'||k.key||'-'||variant,
                FORMAT('{"name":"Synthetic contact","relationship":"Synthetic relation","address":%s}',raw)::JSON,
                'P0001');
        END LOOP;
    END LOOP;
END;
$duplicates$;
-- Literal Unicode-zero escapes are valid SQL JSON but cannot decode to PostgreSQL TEXT.
INSERT INTO ctc_cases(label,payload,expected_state) VALUES
    ('native-zero-key','{"\u0000":"__payload__","name":"Synthetic contact","relationship":"Synthetic relation","address":{"address_line_1":"Synthetic Road","cjs_code":31001}}','22P05'),
    ('native-zero-text','{"name":"\u0000","relationship":"Synthetic relation","address":{"address_line_1":"Synthetic Road","cjs_code":31001}}','22P05');
UPDATE ctc_cases SET expected_diag=pg_temp.ctc_probe(payload,'decode')-'context'-'id'
WHERE expected_state='22P05';
INSERT INTO ctc_cases(label,payload,expected_state)
SELECT 'native-numeric-overflow',
    pg_temp.ctc_numeric_payload('1e999999'),'22003'
FROM ctc_base;
UPDATE ctc_cases SET expected_diag=pg_temp.ctc_probe(payload,'numeric')-'context'-'id'
WHERE label='native-numeric-overflow';

CREATE FUNCTION pg_temp.ctc_run_cases() RETURNS SETOF TEXT LANGUAGE plpgsql AS $cases$
DECLARE
    c ctc_cases%ROWTYPE; before_rows JSONB; after_rows JSONB; r JSONB; n BIGINT; id BIGINT;
    seq_before BIGINT; seq_called BOOLEAN; late_ok BOOLEAN;
BEGIN
    FOR c IN SELECT * FROM ctc_cases ORDER BY label LOOP
        before_rows := pg_temp.ctc_rows();
        SELECT COUNT(*) INTO n FROM public.third_party_contact;
        SELECT last_value,is_called INTO seq_before,seq_called FROM public.third_party_contact_id_seq;
        PERFORM SET_CONFIG('opal.ctc_mode',c.mode,true);
        PERFORM SETVAL('pg_temp.ctc_attempts',1,false);
        r := pg_temp.ctc_probe(c.payload);
        after_rows := pg_temp.ctc_rows();
        RETURN NEXT is(r->>'state',c.expected_state,c.label||': SQLSTATE');
        IF c.expected_state='00000' THEN
            id := (r->>'id')::BIGINT;
            INSERT INTO ctc_outputs VALUES(c.label,id);
            RETURN NEXT ok(r->'succeeded'='true'::JSONB AND id IS NOT NULL
                AND (SELECT COUNT(*) FROM public.third_party_contact)=n+1
                AND (SELECT COUNT(*) FROM public.third_party_contact t WHERE t.third_party_contact_id=id)=1
                AND id=CURRVAL('public.third_party_contact_id_seq'),c.label||': one row and generated OUT');
            RETURN NEXT is((SELECT TO_JSONB(t)-'third_party_contact_id'
                FROM public.third_party_contact t WHERE t.third_party_contact_id=id),
                c.expected,c.label||': independent exact mapped values and NULL version');
            RETURN NEXT ok((before_rows-'third_party_contact') IS NOT DISTINCT FROM
                (after_rows-'third_party_contact')
                AND NOT EXISTS (
                    SELECT 1 FROM JSONB_ARRAY_ELEMENTS_TEXT(before_rows->'third_party_contact') old
                    WHERE NOT EXISTS (SELECT 1 FROM public.third_party_contact t
                                      WHERE ROW_TO_JSON(t)::TEXT=old.value)),
                c.label||': old contacts and unrelated rows/status/snapshot unchanged');
        ELSE
            RETURN NEXT ok(r->'succeeded'='false'::JSONB AND r->'id'='null'::JSONB,
                c.label||': failure never returns successful OUT');
            RETURN NEXT is(after_rows,before_rows,c.label||': no partial or unrelated row mutation');
            late_ok := c.mode='normal' OR (
                (SELECT last_value=1 AND is_called FROM pg_temp.ctc_attempts)
                AND (SELECT last_value=CASE WHEN seq_called THEN seq_before+1 ELSE seq_before END
                            AND is_called FROM public.third_party_contact_id_seq)
                AND (c.mode='suppress' OR (
                    POSITION('p_insert_third_party_contacts(' IN COALESCE(r->>'context',''))>0
                    AND CASE WHEN c.mode LIKE 'inject:%' OR c.mode='assert' THEN
                        POSITION('ctc_inject(' IN COALESCE(r->>'context',''))>0
                        ELSE true
                    END))
            );
            RETURN NEXT ok(r @> c.expected_diag AND late_ok
                AND (c.expected_state<>'P0001' OR c.mode<>'normal' OR (
                    r->>'message' LIKE 'p_insert_third_party_contacts:%'
                    AND POSITION('__payload__' IN r->>'message')=0
                    AND r->>'detail'='' AND r->>'hint'='')),
                c.label||': original diagnostics, safe deliberate context and no retry');
        END IF;
    END LOOP;
    PERFORM SET_CONFIG('opal.ctc_mode','normal',true);
END;
$cases$;

-- -----------------------------------------------------------------------------
-- Scenario: Late insertion failures preserve diagnostics and do not retry.
-- Setup: One collision-guarded rollback-scoped trigger gates modes for synthetic contacts.
-- Expected: Native errors remain unchanged; suppression fails; actual ASSERT propagates.
-- -----------------------------------------------------------------------------
DO $trigger_guard$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='opal_ctc_fault')
       OR TO_REGPROCEDURE('pg_temp.ctc_inject()') IS NOT NULL THEN
        RAISE EXCEPTION 'Synthetic contact trigger collision';
    END IF;
END;
$trigger_guard$;
CREATE FUNCTION pg_temp.ctc_inject() RETURNS TRIGGER LANGUAGE plpgsql AS $inject$
DECLARE v_mode TEXT := CURRENT_SETTING('opal.ctc_mode',true);
BEGIN
    IF COALESCE(v_mode,'normal')='normal' OR NEW.name_organisation<>'Synthetic contact' THEN
        RETURN NEW;
    END IF;
    PERFORM NEXTVAL('pg_temp.ctc_attempts');
    CASE v_mode
        WHEN 'native-pk' THEN
            NEW.third_party_contact_id := -1065199;
            RETURN NEW;
        WHEN 'native-notnull' THEN
            NEW.third_party_contact_id := -1065198;
            NEW.name_organisation := NULL;
            RETURN NEW;
        WHEN 'suppress' THEN RETURN NULL;
        WHEN 'assert' THEN
            ASSERT false, 'Synthetic contact assertion';
        WHEN 'cancel' THEN
            PERFORM PG_SLEEP(1);
            RETURN NEW;
        ELSE
            IF v_mode IN ('inject:22001','inject:40001','inject:40P01') THEN
                RAISE EXCEPTION USING ERRCODE=SUBSTRING(v_mode FROM 8),
                    MESSAGE='Synthetic contact diagnostic',DETAIL='Synthetic contact detail',
                    HINT='Synthetic contact hint',SCHEMA='public',TABLE='third_party_contact',
                    COLUMN='name_organisation',CONSTRAINT='ctc_synthetic_diagnostic',DATATYPE='text';
            END IF;
    END CASE;
    RAISE EXCEPTION 'Unknown synthetic contact fault mode';
END;
$inject$;
CREATE TRIGGER opal_ctc_fault BEFORE INSERT ON public.third_party_contact
    FOR EACH ROW EXECUTE FUNCTION pg_temp.ctc_inject();
INSERT INTO ctc_cases(label,payload,expected_state,mode)
SELECT 'fault-'||mode,payload::JSON,state,mode FROM ctc_base
CROSS JOIN (VALUES ('native-pk','23505'),('native-notnull','23502'),
    ('inject:22001','22001'),('inject:40001','40001'),('inject:40P01','40P01'),('assert','P0004')) faults(mode,state);
DO $native_references$
DECLARE c ctc_cases%ROWTYPE; reference JSONB;
BEGIN
    FOR c IN SELECT * FROM ctc_cases WHERE mode<>'normal' ORDER BY label LOOP
        PERFORM SET_CONFIG('opal.ctc_mode',c.mode,true);
        reference := pg_temp.ctc_probe(c.payload,'insert');
        UPDATE ctc_cases SET expected_diag=reference-'context'-'id' WHERE label=c.label;
    END LOOP;
    PERFORM SET_CONFIG('opal.ctc_mode','normal',true);
END;
$native_references$;
INSERT INTO ctc_cases(label,payload,expected_state,expected_diag,mode)
SELECT 'fault-suppress',payload::JSON,'P0001',
    '{"message":"p_insert_third_party_contacts: insert did not create exactly one contact"}',
    'suppress' FROM ctc_base;

-- -----------------------------------------------------------------------------
-- Scenario: The contact helper has its exact public catalogue and encoding contract.
-- Setup: Inspect the migrated routine and effective UTF-8 server/client settings.
-- Expected: One ordinary PL/pgSQL procedure with ordered JSON IN and BIGINT OUT.
-- -----------------------------------------------------------------------------
SELECT plan(28 + 4*(SELECT COUNT(*)::INTEGER FROM ctc_cases));
SELECT ok((SELECT prokind = 'p' AND pronargs = 1 FROM pg_proc
    WHERE oid = TO_REGPROCEDURE('public.p_insert_third_party_contacts(json)')),
    'contact procedure exists with one JSON input');
SELECT ok((SELECT proargnames = ARRAY['pi_third_party_contact_json','po_third_party_contact_id']
    AND proargmodes = ARRAY['i','o']::"char"[]
    AND proallargtypes = ARRAY['json'::REGTYPE::OID,'bigint'::REGTYPE::OID]
    FROM pg_proc WHERE oid = TO_REGPROCEDURE('public.p_insert_third_party_contacts(json)')),
    'ordered JSON IN and BIGINT OUT contract');
SELECT ok((SELECT NOT prosecdef AND NOT proisstrict AND pronargdefaults = 0 AND proconfig IS NULL
    FROM pg_proc WHERE oid = TO_REGPROCEDURE('public.p_insert_third_party_contacts(json)')),
    'ordinary invoker behavior without defaults or elevated configuration');
SELECT is((SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'p_insert_third_party_contacts'), 1::BIGINT,
    'one public contact overload');
SELECT ok(CURRENT_SETTING('server_encoding') = 'UTF8'
    AND CURRENT_SETTING('client_encoding') = 'UTF8', 'UTF-8 character contract');
SELECT ok((SELECT p.proowner=(SELECT oid FROM pg_roles WHERE rolname=CURRENT_USER)
    AND l.lanname='plpgsql'
    FROM pg_proc p JOIN pg_language l ON l.oid=p.prolang
    WHERE p.oid=TO_REGPROCEDURE('public.p_insert_third_party_contacts(json)')),
    'routine uses the migration role and PL/pgSQL without ownership reassignment');
SELECT is(OBJ_DESCRIPTION(TO_REGPROCEDURE('public.p_insert_third_party_contacts(json)'),'pg_proc'),
    'Insert one neutral contact with original values and resolved Country ID; return its generated ID. Caller owns transaction and publication.',
    'object comment documents neutral row effect, generated output and caller ownership');
SET LOCAL statement_timeout = '90s';
SELECT * FROM pg_temp.ctc_run_cases();
SET LOCAL statement_timeout = '30s';
-- -----------------------------------------------------------------------------
-- Scenario: Identical successful calls insert distinct contacts, not deduplicated rows.
-- Setup: repeat-a/repeat-b each used the same complete synthetic object.
-- Expected: Different generated IDs and both success outputs remain recorded.
-- -----------------------------------------------------------------------------
SELECT ok((SELECT a.id<>b.id FROM ctc_outputs a CROSS JOIN ctc_outputs b
    WHERE a.label='repeat-a' AND b.label='repeat-b'),'identical calls create distinct contacts');
-- -----------------------------------------------------------------------------
-- Scenario: Caller controls rollback after a successful contact.
-- Setup: Capture observations in psql variables; emit no TAP inside the savepoint.
-- Expected: Contact visible then removed, original rows restored and sequence gap allowed.
-- -----------------------------------------------------------------------------
SELECT pg_temp.ctc_rows()::TEXT AS ctc_before_rollback \gset
SAVEPOINT ctc_caller_owned;
SELECT pg_temp.ctc_probe(payload::JSON)::TEXT AS ctc_rollback_result FROM ctc_base \gset
SELECT EXISTS (SELECT 1 FROM public.third_party_contact
    WHERE third_party_contact_id=(:'ctc_rollback_result'::JSONB->>'id')::BIGINT)
    AS ctc_visible_before_rollback \gset
ROLLBACK TO SAVEPOINT ctc_caller_owned;
RELEASE SAVEPOINT ctc_caller_owned;
SELECT ok(:'ctc_visible_before_rollback'::BOOLEAN,'caller sees successful contact inside savepoint');
SELECT ok(NOT EXISTS (SELECT 1 FROM public.third_party_contact
    WHERE third_party_contact_id=(:'ctc_rollback_result'::JSONB->>'id')::BIGINT),
    'caller rollback removes successful contact');
SELECT is(pg_temp.ctc_rows(),:'ctc_before_rollback'::JSONB,'caller restores scoped rows');
SELECT ok((SELECT last_value=(:'ctc_rollback_result'::JSONB->>'id')::BIGINT AND is_called
    FROM public.third_party_contact_id_seq),'caller rollback retains sequence consumption');
SELECT results_eq('SELECT last_value,is_called FROM public.country_id_seq',
    'SELECT last_value,is_called FROM ctc_country_sequence_before','Country sequence never consumed');
-- -----------------------------------------------------------------------------
-- Scenario: Malformed JSON cannot reach the JSON-typed procedure body.
-- Setup: A TEXT wrapper records whether its JSON cast completed before calling.
-- Expected: Native22P02 before cast completion, no successful OUT or row/sequence change.
-- -----------------------------------------------------------------------------
CREATE FUNCTION pg_temp.ctc_binding_probe(p_text TEXT) RETURNS JSONB LANGUAGE plpgsql AS $binding$
DECLARE v_payload JSON; v_cast_completed BOOLEAN := false; v_id BIGINT;
BEGIN
    v_payload := p_text::JSON;
    v_cast_completed := true;
    CALL public.p_insert_third_party_contacts(v_payload,v_id);
    RETURN JSONB_BUILD_OBJECT('state','00000','succeeded',true,'cast_completed',v_cast_completed,'id',v_id);
EXCEPTION WHEN OTHERS THEN
    RETURN JSONB_BUILD_OBJECT('state',SQLSTATE,'succeeded',false,'cast_completed',v_cast_completed,'id',v_id);
END;
$binding$;
CREATE TEMP TABLE ctc_binding_before AS
SELECT pg_temp.ctc_rows() AS rows,last_value,is_called FROM public.third_party_contact_id_seq;
CREATE TEMP TABLE ctc_binding_result AS SELECT pg_temp.ctc_binding_probe('{"name":') AS result;
SELECT is((SELECT result->>'state' FROM ctc_binding_result),'22P02','malformed JSON native binding error');
SELECT ok((SELECT result->'cast_completed'='false'::JSONB
    AND result->'succeeded'='false'::JSONB AND result->'id'='null'::JSONB FROM ctc_binding_result),
    'cast fails before CALL and no successful OUT exists');
SELECT is(pg_temp.ctc_rows(),(SELECT rows FROM ctc_binding_before),'binding failure preserves scoped rows');
SELECT results_eq('SELECT last_value,is_called FROM public.third_party_contact_id_seq',
    'SELECT last_value,is_called FROM ctc_binding_before','binding failure consumes no contact ID');

-- -----------------------------------------------------------------------------
-- Scenario: Ordinary invoker permissions suffice without account/draft write rights.
-- Setup: A transaction-owned NOLOGIN role receives only direct helper prerequisites.
-- Expected: One exact contact, no other row changes and no account/draft UPDATE grants.
-- -----------------------------------------------------------------------------
DO $role_guard$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='opal_ctc_invoker') THEN
        RAISE EXCEPTION 'Synthetic contact role collision';
    END IF;
END;
$role_guard$;
CREATE ROLE opal_ctc_invoker NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT;
GRANT USAGE ON SCHEMA public TO opal_ctc_invoker;
GRANT EXECUTE ON PROCEDURE public.p_insert_third_party_contacts(JSON) TO opal_ctc_invoker;
GRANT SELECT ON public.countries TO opal_ctc_invoker;
GRANT INSERT ON public.third_party_contact TO opal_ctc_invoker;
GRANT SELECT (third_party_contact_id) ON public.third_party_contact TO opal_ctc_invoker;
GRANT USAGE ON SEQUENCE public.third_party_contact_id_seq TO opal_ctc_invoker;
SELECT payload::TEXT AS ctc_role_payload FROM ctc_base \gset
SELECT pg_temp.ctc_rows()::TEXT AS ctc_role_before \gset
SELECT COUNT(*) AS ctc_role_count_before FROM public.third_party_contact \gset
SET LOCAL ROLE opal_ctc_invoker;
CALL public.p_insert_third_party_contacts(:'ctc_role_payload'::JSON,NULL) \gset
RESET ROLE;
SELECT is((SELECT TO_JSONB(t)-'third_party_contact_id' FROM public.third_party_contact t
    WHERE third_party_contact_id=:'po_third_party_contact_id'::BIGINT),
    (SELECT expected FROM ctc_base),'ordinary invoker maps exact contact');
SELECT ok(:'po_third_party_contact_id'::BIGINT IS NOT NULL
    AND (SELECT COUNT(*) FROM public.third_party_contact)=:'ctc_role_count_before'::BIGINT+1
    AND (pg_temp.ctc_rows()-'third_party_contact') IS NOT DISTINCT FROM
        (:'ctc_role_before'::JSONB-'third_party_contact'),'ordinary invoker inserts only one contact');
SELECT ok(NOT HAS_TABLE_PRIVILEGE('opal_ctc_invoker','public.respondent_accounts','UPDATE')
    AND NOT HAS_TABLE_PRIVILEGE('opal_ctc_invoker','public.creditor_accounts','UPDATE')
    AND NOT HAS_TABLE_PRIVILEGE('opal_ctc_invoker','public.draft_casefiles','UPDATE'),
    'invoker success does not depend on account/status update permission');

-- -----------------------------------------------------------------------------
-- Scenario: Actual statement cancellation escapes the helper without retry or success.
-- Setup: Separate100ms SET then a gated one-second trigger sleep; test probe catches57014.
-- Expected: Original timeout/context, no rows, one attempt/ID consumption and restored state.
-- -----------------------------------------------------------------------------
SELECT CURRENT_SETTING('statement_timeout') AS ctc_original_timeout \gset
CREATE TEMP TABLE ctc_cancel_before AS
SELECT pg_temp.ctc_rows() AS rows,
    (SELECT CASE WHEN is_called THEN last_value ELSE 0 END FROM pg_temp.ctc_attempts) AS attempts,
    last_value,is_called FROM public.third_party_contact_id_seq;
SELECT SET_CONFIG('opal.ctc_mode','cancel',true) AS ctc_cancel_mode \gset
SET LOCAL statement_timeout = '100ms';
CREATE TEMP TABLE ctc_cancel_result AS
SELECT pg_temp.ctc_probe(payload::JSON) AS result FROM ctc_base;
SELECT SET_CONFIG('statement_timeout',:'ctc_original_timeout',true) AS ctc_restored_timeout \gset
SELECT SET_CONFIG('opal.ctc_mode','normal',true) AS ctc_restored_mode \gset
DROP TRIGGER opal_ctc_fault ON public.third_party_contact;
DROP FUNCTION pg_temp.ctc_inject();
SELECT is((SELECT result->>'state' FROM ctc_cancel_result),'57014','actual cancellation preserves native state');
SELECT ok((SELECT result->>'message'='canceling statement due to statement timeout'
    AND result->>'detail'='' AND result->>'hint'=''
    AND POSITION('pg_sleep' IN LOWER(result->>'context'))>0
    AND POSITION('ctc_inject(' IN result->>'context')>0
    AND POSITION('p_insert_third_party_contacts(' IN result->>'context')>0 FROM ctc_cancel_result),
    'original timeout message and source context remain internally available');
SELECT ok((SELECT result->'succeeded'='false'::JSONB AND result->'id'='null'::JSONB FROM ctc_cancel_result)
    AND pg_temp.ctc_rows() IS NOT DISTINCT FROM (SELECT rows FROM ctc_cancel_before),
    'cancellation is a failed call without partial rows');
SELECT ok((SELECT CASE WHEN is_called THEN last_value ELSE 0 END FROM pg_temp.ctc_attempts)
    -(SELECT attempts FROM ctc_cancel_before)=1,'cancellation reaches insertion once without retry');
SELECT ok(CURRENT_SETTING('statement_timeout')=:'ctc_original_timeout'
    AND CURRENT_SETTING('opal.ctc_mode')='normal','timeout and mode restored before assertions');
SELECT ok((SELECT s.last_value=CASE WHEN b.is_called THEN b.last_value+1 ELSE b.last_value END
    AND s.is_called FROM public.third_party_contact_id_seq s CROSS JOIN ctc_cancel_before b),
    'cancellation leaves only expected sequence consumption');
SELECT ok(NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='opal_ctc_fault'),
    'owned fault trigger explicitly removed');
SELECT ok(TO_REGPROCEDURE('pg_temp.ctc_inject()') IS NULL,'owned trigger helper explicitly removed');
SELECT * FROM finish();
ROLLBACK;
