/**
 * OPAL Program
 *
 * MODULE      : p_insert_parties_pgtap_tests.sql
 *
 * DESCRIPTION : Verify Party mapping, generated identifiers, scoped row effects
 *               and compatible fresh/upgrade contracts.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket        Nature of Change
 * ----------  -------------  ------------  ----------------------------------------
 * 16/10/2026  Frankie Moran  PO-10647      Initial pgTAP test suite.
 * 22/10/2026  Frankie Moran  PO-10655      Port reviewed coverage to the Stage 3 migration lineage.
 */
-- OPAL-DB-UPGRADE {"id":"p_insert_parties.create","candidate":"ddl/V1_56__create_p_insert_parties_procedure.sql","scope":"both","data":"migration-created-only","contract":{"type":"additive","objects":{"created":[{"kind":"routine","identity":"public.p_insert_parties(json,public.t_party_account_type_enum)"}],"replaced":[]},"preserve":{"rows":["public.parties","public.countries"],"tables":["public.parties","public.countries"],"routines":[],"enums":["public.t_party_account_type_enum"],"sequences":["public.party_id_seq","public.country_id_seq"]},"assertion":"parties.create"}}
\set ON_ERROR_STOP 1
\if :{?opal_assertion_group}
\else
    \set opal_assertion_group parties.current
\endif
SELECT :'opal_assertion_group' IN ('parties.current','parties.create') AS pp_valid_group \gset
\if :pp_valid_group
\else
    DO $group$ BEGIN RAISE EXCEPTION 'Unknown Parties assertion group'; END; $group$;
\endif
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SET LOCAL search_path = public, pg_catalog;
SET LOCAL TIME ZONE 'UTC';
SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '5s';

-- -----------------------------------------------------------------------------
-- Scenario: Guard independent synthetic publication fixtures.
-- Setup: Reserve Country/CJS, Party, Business Unit, Draft Casefile and trigger names.
-- Expected: Collisions raise a fixed error; fixtures never replace existing rows.
-- -----------------------------------------------------------------------------
DO $guard$
BEGIN
    IF EXISTS (SELECT 1 FROM public.countries WHERE country_id IN (-1064701,-1064702,-1064703,-1064704,-1064799)
               OR cjs_code IN (31001,31002,31003,31004))
       OR EXISTS (SELECT 1 FROM public.parties WHERE party_id=-1064799)
       OR EXISTS (SELECT 1 FROM public.business_units WHERE business_unit_id=32047 OR business_unit_code='P047')
       OR EXISTS (SELECT 1 FROM public.draft_casefiles WHERE draft_casefile_id=-1064701)
       OR EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='po10647_party_diagnostics') THEN
        RAISE EXCEPTION 'Parties synthetic fixture collision';
    END IF;
END;
$guard$;
INSERT INTO public.countries(country_id,cjs_code,country_name,date_used_from,date_used_to,active)
VALUES (-1064701,31001,'Synthetic future Country',DATE '2099-01-01',NULL,true),
       (-1064702,31002,'Synthetic inactive Country',DATE '1990-01-01',DATE '1999-01-01',false),
       (-1064703,31003,'Synthetic duplicate active',DATE '2000-01-01',NULL,true),
       (-1064704,31003,'Synthetic duplicate inactive',DATE '2000-01-01',NULL,false);
INSERT INTO public.parties(party_id,organisation,surname,address_line_1,restrict_personal_information,country_id,account_type)
VALUES (-1064799,false,'Synthetic sentinel','Synthetic Road',false,-1064701,'Respondent');
INSERT INTO public.business_units(business_unit_id,business_unit_code,business_unit_name,business_unit_type,welsh_language)
VALUES (32047,'P047','Synthetic Parties area','Area',false);
INSERT INTO public.draft_casefiles(draft_casefile_id,business_unit_id,created_date,submitted_by,submitted_by_name,
    casefile,casefile_snapshot,casefile_type,casefile_status,casefile_status_date,timeline_data)
VALUES (-1064701,32047,TIMESTAMP '2026-01-01','synthetic','Synthetic fixture',
    '{"synthetic":"input"}','{"synthetic":"snapshot"}','REMO In','SUBMITTED',
    TIMESTAMP '2026-01-01','[{"synthetic":"timeline"}]');
CREATE TEMP TABLE pp_country_sequence_before AS SELECT last_value,is_called FROM public.country_id_seq;
CREATE TEMP TABLE pp_cases(
    label TEXT PRIMARY KEY,
    payload JSONB,
    raw_payload JSON,
    account TEXT,
    expected JSONB,
    expected_state TEXT NOT NULL DEFAULT '00000',
    expected_diag JSONB NOT NULL DEFAULT '{}',
    mode TEXT NOT NULL DEFAULT 'normal'
);
CREATE TEMP TABLE pp_outputs(label TEXT PRIMARY KEY,id BIGINT);

-- -----------------------------------------------------------------------------
-- Scenario: Map person and organisation for each physical account type.
-- Setup: Independent complete expected row; Applicant uses Minor Creditor.
-- Expected: One new row preserves every mapped value and all preexisting scoped rows.
-- -----------------------------------------------------------------------------
INSERT INTO pp_cases(label,payload,account,expected) VALUES ('person-base',
    '{"organisation":false,"individual_details":{"surname":"Synthetic"},"address":{"address_line_1":"Synthetic Road","cjs_code":31001},"contact_details":{}}',
    'Respondent',
    '{"organisation":false,"organisation_name":null,"foreign_authority_reference":null,"surname":"Synthetic","forenames":null,"title":null,"birth_date":null,"national_insurance_number":null,"address_line_1":"Synthetic Road","address_line_2":null,"address_line_3":null,"address_line_4":null,"address_line_5":null,"postcode":null,"telephone_home":null,"telephone_business":null,"telephone_mobile":null,"email_1":null,"email_2":null,"restrict_personal_information":false,"restriction_reason":null,"country_id":-1064701,"account_type":"Respondent","last_changed_date":null}');
INSERT INTO pp_cases(label,payload,account,expected)
SELECT 'organisation-base',
    (payload-'individual_details') || '{"organisation":true,"organisation_details":{"organisation_name":"Synthetic organisation"}}',
    'Respondent',expected || '{"organisation":true,"organisation_name":"Synthetic organisation","surname":null}'
FROM pp_cases WHERE label='person-base';
INSERT INTO pp_cases(label,payload,account,expected)
SELECT 'person-minor',payload,'Minor Creditor',expected || '{"account_type":"Minor Creditor"}'
FROM pp_cases WHERE label='person-base';
INSERT INTO pp_cases(label,payload,account,expected)
SELECT 'organisation-minor',payload,'Minor Creditor',expected || '{"account_type":"Minor Creditor"}'
FROM pp_cases WHERE label='organisation-base';
INSERT INTO pp_cases(label,payload,account,expected)
SELECT 'applicant-handoff',payload,'Minor Creditor',expected || '{"account_type":"Minor Creditor"}'
FROM pp_cases WHERE label='person-base';

-- -----------------------------------------------------------------------------
-- Scenario: Repeat an identical person call.
-- Setup: Populate two cases with the same synthetic person and independent row expectation.
-- Expected: Each call inserts one row; distinct-ID assertion is added in the boundary gate.
-- -----------------------------------------------------------------------------
INSERT INTO pp_cases(label,payload,account,expected)
SELECT v.label,b.payload,b.account,b.expected
FROM pp_cases b CROSS JOIN (VALUES ('person-repeat-a'),('person-repeat-b')) v(label)
WHERE b.label='person-base';

-- -----------------------------------------------------------------------------
-- Scenario: Validate every mapped string on both applicable branches before narrowing.
-- Setup: Independent field metadata generates omitted/null/type/length/Unicode cases.
-- Expected: Accepted strings persist exactly, including spaces; invalid inputs raise P0001.
-- -----------------------------------------------------------------------------
CREATE TEMP TABLE pp_fields(path TEXT[],destination TEXT,min_length INTEGER,max_length INTEGER,
    base_label TEXT,required BOOLEAN,alphanumeric BOOLEAN);
INSERT INTO pp_fields VALUES
    ('{organisation_details,organisation_name}','organisation_name',1,80,'organisation-base',true,false),
    ('{organisation_details,foreign_authority_reference}','foreign_authority_reference',0,40,'organisation-base',false,true),
    ('{individual_details,surname}','surname',1,50,'person-base',true,false),
    ('{individual_details,forenames}','forenames',1,50,'person-base',false,false),
    ('{individual_details,title}','title',0,20,'person-base',false,false),
    ('{individual_details,national_insurance_number}','national_insurance_number',0,9,'person-base',false,false),
    ('{address,address_line_1}','address_line_1',1,35,'person-base',true,false),
    ('{address,address_line_2}','address_line_2',0,35,'person-base',false,false),
    ('{address,address_line_3}','address_line_3',0,35,'person-base',false,false),
    ('{address,address_line_4}','address_line_4',0,35,'person-base',false,false),
    ('{address,address_line_5}','address_line_5',0,35,'person-base',false,false),
    ('{address,postcode}','postcode',0,10,'person-base',false,false),
    ('{contact_details,main_telephone_number}','telephone_home',0,35,'person-base',false,false),
    ('{contact_details,other_telephone_number}','telephone_mobile',0,35,'person-base',false,false),
    ('{contact_details,primary_email_address}','email_1',0,76,'person-base',false,false),
    ('{contact_details,secondary_email_address}','email_2',0,76,'person-base',false,false),
    ('{individual_details,restriction_reason}','restriction_reason',0,250,'person-base',false,false);
INSERT INTO pp_cases(label,payload,account,expected,expected_state,expected_diag)
SELECT b.label||':'||ARRAY_TO_STRING(f.path,'.')||':'||v.label,
    CASE WHEN v.label='omitted' THEN b.payload #- f.path ELSE JSONB_SET(b.payload,f.path,v.value,true) END,
    b.account,
    b.expected || JSONB_BUILD_OBJECT(f.destination,CASE WHEN v.label='omitted' THEN NULL ELSE v.value END),
    CASE WHEN v.valid THEN '00000' ELSE 'P0001' END,
    CASE WHEN v.valid THEN '{}'::JSONB ELSE JSONB_BUILD_OBJECT('message',
        CASE WHEN v.label='omitted' THEN 'p_insert_parties: '||ARRAY_TO_STRING(f.path,'.')||' is required'
             WHEN v.label IN ('null','number','boolean','object','array') THEN
                 'p_insert_parties: '||ARRAY_TO_STRING(f.path,'.')||' must be a string'
             WHEN f.alphanumeric AND v.label IN ('spaces','exact-spaced') THEN
                 'p_insert_parties: foreign_authority_reference must be alphanumeric'
             ELSE 'p_insert_parties: '||ARRAY_TO_STRING(f.path,'.')||' length is invalid' END) END
FROM pp_fields f JOIN pp_cases b ON b.label=f.base_label
    OR (b.label='organisation-base' AND f.path[1] IN ('address','contact_details'))
CROSS JOIN LATERAL (VALUES
    ('omitted',NULL::JSONB,NOT f.required),
    ('null','null'::JSONB,false),
    ('empty',TO_JSONB(''::TEXT),f.min_length=0),
    ('spaces',TO_JSONB('   '::TEXT),NOT f.alphanumeric),
    ('number','12'::JSONB,false),
    ('boolean','true'::JSONB,false),
    ('object','{}'::JSONB,false),
    ('array','[]'::JSONB,false),
    ('minimum',TO_JSONB(REPEAT('A',f.min_length)),true),
    ('maximum',TO_JSONB(REPEAT('A',f.max_length)),true),
    ('overlength',TO_JSONB(REPEAT('A',f.max_length+1)),false),
    ('trailing-overlength',TO_JSONB('A'||REPEAT(' ',f.max_length)),false),
    ('exact-spaced',TO_JSONB(' A '::TEXT),NOT f.alphanumeric),
    ('unicode-maximum',TO_JSONB(REPEAT('é',f.max_length)),true),
    ('unicode-overlength',TO_JSONB(REPEAT('é',f.max_length+1)),false)
) v(label,value,valid)
WHERE NOT (f.alphanumeric AND v.label LIKE 'unicode-%');

-- -----------------------------------------------------------------------------
-- Scenario: Reject wrong root, account, branch and nested-object shapes.
-- Setup: Mutate one independent shape at a time, including conflicting branch data.
-- Expected: Every invalid shape fails privately; omitted/empty contact objects map NULLs.
-- -----------------------------------------------------------------------------
INSERT INTO pp_cases(label,payload,account,expected_state,expected_diag)
SELECT 'root-'||v.label,v.value,b.account,'P0001',
    '{"message":"p_insert_parties: Party object and account type are required"}'
FROM pp_cases b CROSS JOIN (VALUES ('sql-null',NULL::JSONB),('json-null','null'::JSONB),
    ('array','[]'::JSONB),('number','1'::JSONB),('boolean','true'::JSONB),
    ('string','"x"'::JSONB),('private-marker','"__payload__"'::JSONB)) v(label,value) WHERE b.label='person-base';
INSERT INTO pp_cases(label,payload,account,expected_state,expected_diag)
SELECT 'account-null',payload,NULL,'P0001',
    '{"message":"p_insert_parties: Party object and account type are required"}'
FROM pp_cases WHERE label='person-base';
INSERT INTO pp_cases(label,payload,account,expected_state)
SELECT 'account-invalid-enum',payload,'Applicant','22P02' FROM pp_cases WHERE label='person-base';
INSERT INTO pp_cases(label,payload,account,expected_state,expected_diag)
SELECT 'organisation-flag-'||v.label,
    CASE WHEN v.label='omitted' THEN b.payload-'organisation'
         ELSE JSONB_SET(b.payload,'{organisation}',v.value) END,
    b.account,'P0001','{"message":"p_insert_parties: organisation must be Boolean"}'
FROM pp_cases b CROSS JOIN (VALUES ('omitted',NULL::JSONB),('null','null'::JSONB),
    ('string','"false"'::JSONB),('number','1'::JSONB),('array','[]'::JSONB),('object','{}'::JSONB))
    v(label,value) WHERE b.label='person-base';
INSERT INTO pp_cases(label,payload,account,expected_state,expected_diag)
SELECT b.label||':selected-branch:'||v.label,
    CASE WHEN v.label='omitted' THEN b.payload-br.key ELSE JSONB_SET(b.payload,ARRAY[br.key],v.value) END,
    b.account,'P0001',JSONB_BUILD_OBJECT('message',CASE WHEN v.label='empty' THEN
        'p_insert_parties: '||br.key||'.'||br.required_name||' is required'
        ELSE 'p_insert_parties: '||br.branch_name||' branch is invalid' END)
FROM pp_cases b JOIN (VALUES ('person-base','individual_details','surname','individual'),
    ('organisation-base','organisation_details','organisation_name','organisation'))
    br(base_label,key,required_name,branch_name) ON b.label=br.base_label
CROSS JOIN (VALUES ('omitted',NULL::JSONB),('null','null'::JSONB),('string','"__payload__"'::JSONB),
    ('number','1'::JSONB),('boolean','true'::JSONB),('array','[]'::JSONB),('empty','{}'::JSONB)) v(label,value);
INSERT INTO pp_cases(label,payload,account,expected_state,expected_diag)
SELECT b.label||':conflicting-branch:'||v.label,JSONB_SET(b.payload,ARRAY[br.key],v.value),
    b.account,'P0001',JSONB_BUILD_OBJECT('message','p_insert_parties: '||br.branch_name||' branch is invalid')
FROM pp_cases b JOIN (VALUES ('person-base','organisation_details','individual'),
    ('organisation-base','individual_details','organisation')) br(base_label,key,branch_name) ON b.label=br.base_label
CROSS JOIN (VALUES ('null','null'::JSONB),('empty','{}'::JSONB),
    ('populated','{"surname":"__payload__","organisation_name":"__payload__"}'::JSONB),
    ('string','"__payload__"'::JSONB),('array','[]'::JSONB)) v(label,value);
INSERT INTO pp_cases(label,payload,account,expected,expected_state,expected_diag)
SELECT b.label||':'||o.key||':'||v.label,
    CASE WHEN v.label='omitted' THEN b.payload-o.key ELSE JSONB_SET(b.payload,ARRAY[o.key],v.value) END,
    b.account,b.expected,
    CASE WHEN o.key='contact_details' AND v.label IN ('omitted','empty') THEN '00000' ELSE 'P0001' END,
    CASE WHEN o.key='contact_details' AND v.label IN ('omitted','empty') THEN '{}'::JSONB
         ELSE JSONB_BUILD_OBJECT('message',CASE WHEN o.key='contact_details' THEN
             'p_insert_parties: contact_details must be an object'
             WHEN v.label='empty' THEN 'p_insert_parties: address.address_line_1 is required'
             ELSE 'p_insert_parties: address object is required' END) END
FROM pp_cases b CROSS JOIN (VALUES ('address'),('contact_details')) o(key)
CROSS JOIN (VALUES ('omitted',NULL::JSONB),('null','null'::JSONB),('string','"__payload__"'::JSONB),
    ('number','1'::JSONB),('boolean','true'::JSONB),('array','[]'::JSONB),('empty','{}'::JSONB)) v(label,value)
WHERE b.label IN ('person-base','organisation-base');
INSERT INTO pp_cases(label,payload,account,expected_state,expected_diag)
SELECT 'private-overlength-marker',JSONB_SET(payload,'{individual_details,surname}',
    TO_JSONB('__payload__'||REPEAT('X',51))),account,'P0001',
    '{"message":"p_insert_parties: individual_details.surname length is invalid"}'
FROM pp_cases WHERE label='person-base';

-- -----------------------------------------------------------------------------
-- Scenario: Resolve numeric Country representations without active/effective filters.
-- Setup: Missing, wrong-type, fractional and SMALLINT boundaries; raw exponent JSON.
-- Expected: Integral decimals/exponents resolve; no-match/ambiguous lookups retain native errors.
-- -----------------------------------------------------------------------------
INSERT INTO pp_cases(label,payload,account,expected,expected_state,expected_diag)
SELECT 'country-'||v.label,
    CASE WHEN v.label='omitted' THEN b.payload #- '{address,cjs_code}'
         ELSE JSONB_SET(b.payload,'{address,cjs_code}',v.value) END,
    b.account,b.expected||COALESCE(v.patch,'{}'),v.state,
    CASE WHEN v.state='P0001' THEN JSONB_BUILD_OBJECT('message',CASE WHEN v.label IN
        ('fraction','below-smallint','above-smallint') THEN
            'p_insert_parties: cjs_code must be an integer within SMALLINT range'
        ELSE 'p_insert_parties: cjs_code must be an integer number' END) ELSE '{}'::JSONB END
FROM pp_cases b CROSS JOIN (VALUES
    ('omitted',NULL::JSONB,'P0001',NULL::JSONB),('null','null'::JSONB,'P0001',NULL::JSONB),
    ('string','"31001"'::JSONB,'P0001',NULL::JSONB),('boolean','true'::JSONB,'P0001',NULL::JSONB),
    ('object','{}'::JSONB,'P0001',NULL::JSONB),('array','[]'::JSONB,'P0001',NULL::JSONB),
    ('fraction','31001.5'::JSONB,'P0001',NULL::JSONB),
    ('below-smallint','-32769'::JSONB,'P0001',NULL::JSONB),
    ('above-smallint','32768'::JSONB,'P0001',NULL::JSONB),
    ('minimum-no-match','-32768'::JSONB,'P0002',NULL::JSONB),
    ('maximum-no-match','32767'::JSONB,'P0002',NULL::JSONB),
    ('integer-decimal','31001.0'::JSONB,'00000',NULL::JSONB),
    ('active-future-unique','31001'::JSONB,'00000',NULL::JSONB),
    ('inactive-expired','31002'::JSONB,'00000','{"country_id":-1064702}'::JSONB),
    ('no-match','31004'::JSONB,'P0002',NULL::JSONB),
    ('ambiguous-mixed-active','31003'::JSONB,'P0003',NULL::JSONB)
) v(label,value,state,patch) WHERE b.label='person-base';
-- Preserve this exact source spelling: JSONB would normalize 3.1001e4 to 31001.
INSERT INTO pp_cases(label,raw_payload,account,expected)
SELECT 'country-raw-exponent',
    '{"organisation":false,"individual_details":{"surname":"Synthetic"},"address":{"address_line_1":"Synthetic Road","cjs_code":3.1001e4},"contact_details":{}}'::JSON,
    account,expected FROM pp_cases WHERE label='person-base';

-- -----------------------------------------------------------------------------
-- Scenario: Enforce DOB wire shape while delegating calendar validity to native DATE.
-- Setup: Omitted/valid/future dates, malformed types/representations and invalid calendars.
-- Expected: Exact DATE mappings or fixed private guards; native calendar diagnostics survive.
-- -----------------------------------------------------------------------------
INSERT INTO pp_cases(label,payload,account,expected,expected_state,expected_diag)
SELECT 'dob-'||v.label,
    CASE WHEN v.label='omitted' THEN b.payload #- '{individual_details,date_of_birth}'
         ELSE JSONB_SET(b.payload,'{individual_details,date_of_birth}',v.value) END,
    b.account,b.expected||JSONB_BUILD_OBJECT('birth_date',v.stored),v.state,
    CASE WHEN v.state='P0001' THEN '{"message":"p_insert_parties: date_of_birth must be an ISO date string"}'::JSONB
         ELSE '{}'::JSONB END
FROM pp_cases b CROSS JOIN (VALUES
    ('omitted',NULL::JSONB,'00000',NULL::TEXT),('null','null'::JSONB,'P0001',NULL::TEXT),
    ('empty','""'::JSONB,'P0001',NULL::TEXT),('space','" "'::JSONB,'P0001',NULL::TEXT),
    ('number','20000229'::JSONB,'P0001',NULL::TEXT),('boolean','true'::JSONB,'P0001',NULL::TEXT),
    ('object','{}'::JSONB,'P0001',NULL::TEXT),('array','[]'::JSONB,'P0001',NULL::TEXT),
    ('presentation-format','"29/02/2000"'::JSONB,'P0001',NULL::TEXT),
    ('nonpadded','"2000-2-29"'::JSONB,'P0001',NULL::TEXT),
    ('leap-day','"2000-02-29"'::JSONB,'00000','2000-02-29'),
    ('year-end','"1999-12-31"'::JSONB,'00000','1999-12-31'),
    ('future','"2099-01-01"'::JSONB,'00000','2099-01-01'),
    ('invalid-calendar','"2026-02-30"'::JSONB,'22008',NULL::TEXT),
    ('invalid-century','"1900-02-29"'::JSONB,'22008',NULL::TEXT),
    ('invalid-zero-year','"0000-01-01"'::JSONB,'22008',NULL::TEXT)
) v(label,value,state,stored) WHERE b.label='person-base';

-- -----------------------------------------------------------------------------
-- Scenario: Preserve optional restriction reasons and require nonblank text when true.
-- Setup: Independent omitted/false/true flag and omitted/null/blank/type/length reasons.
-- Expected: Defaults and retained strings match exactly; only true rejects blank strings.
-- -----------------------------------------------------------------------------
INSERT INTO pp_cases(label,payload,account,expected,expected_state,expected_diag)
SELECT 'restriction-'||f.label||':'||v.label,
    CASE WHEN v.label='omitted' THEN f.payload #- '{individual_details,restriction_reason}'
         ELSE JSONB_SET(f.payload,'{individual_details,restriction_reason}',v.value) END,
    b.account,b.expected||JSONB_BUILD_OBJECT('restrict_personal_information',f.restricted,
        'restriction_reason',CASE WHEN v.label='omitted' THEN NULL ELSE v.value END),
    CASE WHEN v.valid AND (NOT f.restricted OR v.nonblank) THEN '00000' ELSE 'P0001' END,
    CASE WHEN v.valid AND (NOT f.restricted OR v.nonblank) THEN '{}'::JSONB
         ELSE JSONB_BUILD_OBJECT('message',CASE WHEN v.label IN ('null','number','boolean','object','array') THEN
                 'p_insert_parties: individual_details.restriction_reason must be a string'
             WHEN v.label='overlength' THEN 'p_insert_parties: individual_details.restriction_reason length is invalid'
             ELSE 'p_insert_parties: restriction_reason must be nonblank when restricted' END) END
FROM pp_cases b CROSS JOIN LATERAL (VALUES
    ('omitted',b.payload,false),
    ('false',JSONB_SET(b.payload,'{individual_details,restrict_personal_information}','false'),false),
    ('true',JSONB_SET(b.payload,'{individual_details,restrict_personal_information}','true'),true)
) f(label,payload,restricted)
CROSS JOIN (VALUES ('omitted',NULL::JSONB,true,false),('null','null'::JSONB,false,false),
    ('empty','""'::JSONB,true,false),('spaces','"   "'::JSONB,true,false),
    ('tab',TO_JSONB(CHR(9)),true,false),('newline',TO_JSONB(CHR(10)),true,false),
    ('retained','"  Synthetic reason  "'::JSONB,true,true),
    ('maximum',TO_JSONB(REPEAT('R',250)),true,true),
    ('overlength',TO_JSONB(REPEAT('R',251)),false,true),
    ('number','12'::JSONB,false,false),('boolean','true'::JSONB,false,false),
    ('object','{}'::JSONB,false,false),('array','[]'::JSONB,false,false)
) v(label,value,valid,nonblank) WHERE b.label='person-base';
INSERT INTO pp_cases(label,payload,account,expected_state,expected_diag)
SELECT 'restriction-flag-'||v.label,
    JSONB_SET(b.payload,'{individual_details,restrict_personal_information}',v.value),b.account,'P0001',
    '{"message":"p_insert_parties: restrict_personal_information must be Boolean"}'
FROM pp_cases b CROSS JOIN (VALUES ('null','null'::JSONB),('string','"false"'::JSONB),
    ('number','1'::JSONB),('object','{}'::JSONB),('array','[]'::JSONB)) v(label,value)
WHERE b.label='person-base';

-- -----------------------------------------------------------------------------
-- Scenario: Map Main/Other independently for both branches and both account types.
-- Setup: Main only, Other only, both and neither use distinct untrimmed accepted text.
-- Expected: Home/mobile follow their input; business stays NULL without fallback.
-- -----------------------------------------------------------------------------
INSERT INTO pp_cases(label,payload,account,expected)
SELECT b.label||':telephones:'||v.label||':'||a.account,
    JSONB_SET(b.payload,'{contact_details}',v.contact),a.account,
    b.expected||JSONB_BUILD_OBJECT('telephone_home',v.main,'telephone_mobile',v.other,
        'telephone_business',NULL,'account_type',a.account)
FROM pp_cases b CROSS JOIN (VALUES ('Respondent'),('Minor Creditor')) a(account)
CROSS JOIN (VALUES
    ('main-only','{"main_telephone_number":"  Synthetic Main  "}'::JSONB,'  Synthetic Main  ',NULL::TEXT),
    ('other-only','{"other_telephone_number":"Synthetic Other "}'::JSONB,NULL::TEXT,'Synthetic Other '),
    ('both','{"main_telephone_number":"  Synthetic Main  ","other_telephone_number":"Synthetic Other "}'::JSONB,
        '  Synthetic Main  ','Synthetic Other '),
    ('neither','{}'::JSONB,NULL::TEXT,NULL::TEXT)
) v(label,contact,main,other) WHERE b.label IN ('person-base','organisation-base');

-- -----------------------------------------------------------------------------
-- Scenario: Preserve NI text and ignore fields owned by downstream/caller packages.
-- Setup: Synthetic accepted NI forms and non-owned aliases/personal information/age.
-- Expected: NI is exact through nine characters; non-owned fields leave Party mapping unchanged.
-- -----------------------------------------------------------------------------
INSERT INTO pp_cases(label,payload,account,expected,expected_state)
SELECT 'ni-'||v.label,JSONB_SET(b.payload,'{individual_details,national_insurance_number}',TO_JSONB(v.value)),
    b.account,b.expected||JSONB_BUILD_OBJECT('national_insurance_number',v.value),v.state
FROM pp_cases b CROSS JOIN (VALUES ('eight','AB123456','00000'),('final-u0020','AB123456 ','00000'),
    ('nny-shape','12A34567','00000'),('nine','AB123456C','00000'),('ten','AB123456CD','P0001'),
    ('lowercase','ab123456','00000'),('whitespace','   ','00000'),('empty','','00000'))
    v(label,value,state) WHERE b.label='person-base';
INSERT INTO pp_cases(label,payload,account,expected)
SELECT 'non-owned-inputs',payload||'{"aliases":[{"synthetic":"alias"}],"age":29}'
    ||JSONB_BUILD_OBJECT('individual_details',(payload->'individual_details')
        ||'{"other_personal_information":"Synthetic unowned information","age":29}'),account,expected
FROM pp_cases WHERE label='person-base';

-- -----------------------------------------------------------------------------
-- Scenario: Assert every mapped destination together for both branches/account types.
-- Setup: Independent literal expected patches use five address lines, distinct contacts and emails.
-- Expected: Exact whole-row mapping; false restriction retains its supplied reason.
-- -----------------------------------------------------------------------------
INSERT INTO pp_cases(label,payload,account,expected)
SELECT 'person-all-fields',
    '{"organisation":false,"individual_details":{"surname":" Synthetic surname ","forenames":" Synthetic names ","title":" T ","date_of_birth":"2000-02-29","national_insurance_number":"AB123456 ","restrict_personal_information":false,"restriction_reason":" Retained reason "},"address":{"address_line_1":" Address one ","address_line_2":" Address two ","address_line_3":" Address three ","address_line_4":" Address four ","address_line_5":" Address five ","postcode":" P1 ","cjs_code":31001},"contact_details":{"main_telephone_number":" Main ","other_telephone_number":" Other ","primary_email_address":" Synthetic primary ","secondary_email_address":" Synthetic secondary "}}',
    account,
    expected||'{"surname":" Synthetic surname ","forenames":" Synthetic names ","title":" T ","birth_date":"2000-02-29","national_insurance_number":"AB123456 ","restriction_reason":" Retained reason ","address_line_1":" Address one ","address_line_2":" Address two ","address_line_3":" Address three ","address_line_4":" Address four ","address_line_5":" Address five ","postcode":" P1 ","telephone_home":" Main ","telephone_mobile":" Other ","email_1":" Synthetic primary ","email_2":" Synthetic secondary "}'
FROM pp_cases WHERE label='person-base';
INSERT INTO pp_cases(label,payload,account,expected)
SELECT 'organisation-all-fields',
    (payload-'individual_details')||'{"organisation":true,"organisation_details":{"organisation_name":" Synthetic organisation ","foreign_authority_reference":"A123"}}',
    account,expected||'{"organisation":true,"organisation_name":" Synthetic organisation ","foreign_authority_reference":"A123","surname":null,"forenames":null,"title":null,"birth_date":null,"national_insurance_number":null,"restriction_reason":null}'
FROM pp_cases WHERE label='person-all-fields';
INSERT INTO pp_cases(label,payload,account,expected)
SELECT label||'-minor',payload,'Minor Creditor',expected||'{"account_type":"Minor Creditor"}'
FROM pp_cases WHERE label IN ('person-all-fields','organisation-all-fields');

-- -----------------------------------------------------------------------------
-- Scenario: Capture real row scope and original procedure diagnostics.
-- Setup: Temporary SQL-only snapshots/probes surround each call in the owning transaction.
-- Expected: Each case emits four assertions for state, identity/mapping or failure, and scope.
-- -----------------------------------------------------------------------------
CREATE FUNCTION pg_temp.pp_rows() RETURNS JSONB LANGUAGE plpgsql AS $rows$
DECLARE v_table TEXT; v_values JSONB; v_result JSONB := '{}';

BEGIN
    FOREACH v_table IN ARRAY ARRAY['parties','countries','aliases','creditor_accounts',
        'respondent_account_parties','draft_casefiles','debtor_detail','third_party_contact',
        'notes','respondent_accounts','account_number_index','order_terms','business_units'] LOOP
        EXECUTE FORMAT('SELECT COALESCE(JSONB_AGG(value ORDER BY value),''[]''::JSONB)
            FROM (SELECT ROW_TO_JSON(t)::TEXT AS value FROM public.%I t) r',v_table) INTO v_values;
        v_result := v_result || JSONB_BUILD_OBJECT(v_table,v_values);
    END LOOP;
    RETURN v_result;
END;
$rows$;
CREATE FUNCTION pg_temp.pp_probe(p_json JSON,p_account TEXT) RETURNS JSONB LANGUAGE plpgsql AS $probe$
DECLARE v_id BIGINT; v_state TEXT; v_message TEXT; v_detail TEXT; v_hint TEXT;
        v_schema TEXT; v_table TEXT; v_column TEXT; v_constraint TEXT; v_context TEXT; v_datatype TEXT;

BEGIN
    CALL public.p_insert_parties(p_json,p_account::public.t_party_account_type_enum,v_id);
    RETURN JSONB_BUILD_OBJECT('state','00000','succeeded',true,'id',v_id);
EXCEPTION WHEN query_canceled OR assert_failure OR OTHERS THEN
    GET STACKED DIAGNOSTICS v_state=RETURNED_SQLSTATE,v_message=MESSAGE_TEXT,
        v_detail=PG_EXCEPTION_DETAIL,v_hint=PG_EXCEPTION_HINT,v_schema=SCHEMA_NAME,
        v_table=TABLE_NAME,v_column=COLUMN_NAME,v_constraint=CONSTRAINT_NAME,
        v_context=PG_EXCEPTION_CONTEXT,v_datatype=PG_DATATYPE_NAME;

    RETURN JSONB_BUILD_OBJECT('state',v_state,'succeeded',false,'id',v_id,
        'message',v_message,'detail',v_detail,'hint',v_hint,'schema',v_schema,
        'table',v_table,'column',v_column,'constraint',v_constraint,'context',v_context,'datatype',v_datatype);
END;
$probe$;
-- -----------------------------------------------------------------------------
-- Scenario: Compare native conversion/integrity diagnostics with direct PostgreSQL errors.
-- Setup: Direct DATE/enum/STRICT lookup/INSERT probes use the same synthetic inputs.
-- Expected: SQLSTATE, message, detail, hint and object/datatype fields match exactly.
-- Context differs because direct expressions and procedure calls have different stacks.
-- FK detail names the same fixed Country and PK detail the same fixed Party, so no
-- generated-ID message normalization or broad diagnostic suppression is necessary.
-- -----------------------------------------------------------------------------
CREATE FUNCTION pg_temp.pp_native_probe(p_mode TEXT,p_text TEXT DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql AS $native$
DECLARE v_country BIGINT; v_state TEXT; v_message TEXT; v_detail TEXT; v_hint TEXT;
        v_schema TEXT; v_table TEXT; v_column TEXT; v_constraint TEXT; v_datatype TEXT;
BEGIN
    CASE p_mode
        WHEN 'date' THEN PERFORM p_text::DATE;
        WHEN 'enum' THEN PERFORM p_text::public.t_party_account_type_enum;
        WHEN 'country-no-match' THEN
            SELECT country_id INTO STRICT v_country FROM public.countries WHERE cjs_code=31004;
        WHEN 'country-ambiguous' THEN
            SELECT country_id INTO STRICT v_country FROM public.countries WHERE cjs_code=31003;
        WHEN 'fk' THEN
            INSERT INTO public.parties(organisation,surname,address_line_1,
                restrict_personal_information,country_id,account_type)
            VALUES(false,'Synthetic','Synthetic Road',false,-1064799,'Respondent');
        WHEN 'pk' THEN
            INSERT INTO public.parties(party_id,organisation,surname,address_line_1,
                restrict_personal_information,country_id,account_type)
            VALUES(-1064799,false,'Synthetic','Synthetic Road',false,-1064701,'Respondent');
        ELSE RAISE EXCEPTION 'Unknown native Party diagnostic probe';
    END CASE;
    RETURN JSONB_BUILD_OBJECT('state','00000');
EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state=RETURNED_SQLSTATE,v_message=MESSAGE_TEXT,
        v_detail=PG_EXCEPTION_DETAIL,v_hint=PG_EXCEPTION_HINT,v_schema=SCHEMA_NAME,
        v_table=TABLE_NAME,v_column=COLUMN_NAME,v_constraint=CONSTRAINT_NAME,v_datatype=PG_DATATYPE_NAME;
    RETURN JSONB_BUILD_OBJECT('state',v_state,'message',v_message,'detail',v_detail,'hint',v_hint,
        'schema',v_schema,'table',v_table,'column',v_column,'constraint',v_constraint,'datatype',v_datatype);
END;
$native$;
UPDATE pp_cases SET expected_diag=pg_temp.pp_native_probe('date',payload #>> '{individual_details,date_of_birth}')
WHERE label IN ('dob-invalid-calendar','dob-invalid-century','dob-invalid-zero-year');
UPDATE pp_cases SET expected_diag=pg_temp.pp_native_probe('enum','Applicant') WHERE label='account-invalid-enum';
UPDATE pp_cases SET expected_diag=pg_temp.pp_native_probe('country-no-match') WHERE expected_state='P0002';
UPDATE pp_cases SET expected_diag=pg_temp.pp_native_probe('country-ambiguous') WHERE expected_state='P0003';

-- -----------------------------------------------------------------------------
-- Scenario: Preserve late native FK/PK errors and injected original diagnostics without retry.
-- Setup: One gated test-only trigger counts attempts and alters only explicit test modes.
-- Expected: Original errors/context survive, scoped rows roll back, and one sequence value is consumed.
-- -----------------------------------------------------------------------------
INSERT INTO pp_cases(label,payload,account,expected_state,expected_diag,mode)
SELECT 'native-fk',payload,account,'23503',pg_temp.pp_native_probe('fk'),'native-fk'
FROM pp_cases WHERE label='person-base';
INSERT INTO pp_cases(label,payload,account,expected_state,expected_diag,mode)
SELECT 'native-pk',payload,account,'23505',pg_temp.pp_native_probe('pk'),'native-pk'
FROM pp_cases WHERE label='person-base';
CREATE SEQUENCE pg_temp.pp_attempts START 1;
CREATE FUNCTION pg_temp.pp_inject() RETURNS TRIGGER LANGUAGE plpgsql AS $inject$
DECLARE v_mode TEXT := CURRENT_SETTING('opal.party_test_mode',true);
BEGIN
    IF v_mode IS NULL OR v_mode='normal' THEN RETURN NEW; END IF;
    PERFORM NEXTVAL('pg_temp.pp_attempts');
    IF v_mode='native-fk' THEN
        NEW.country_id := -1064799;
        RETURN NEW;
    END IF;
    IF v_mode='native-pk' THEN
        NEW.party_id := -1064799;
        RETURN NEW;
    END IF;
    RAISE EXCEPTION USING ERRCODE=SUBSTRING(v_mode FROM 8),
        MESSAGE='synthetic Party diagnostic',DETAIL='synthetic Party detail',HINT='synthetic Party hint',
        SCHEMA='public',TABLE='parties',COLUMN='party_id',CONSTRAINT='pp_synthetic_diagnostic';
END;
$inject$;
CREATE TRIGGER po10647_party_diagnostics BEFORE INSERT ON public.parties
    FOR EACH ROW EXECUTE FUNCTION pg_temp.pp_inject();
INSERT INTO pp_cases(label,payload,account,expected_state,expected_diag,mode)
SELECT 'diagnostic-'||s.state,b.payload,b.account,s.state,
    JSONB_BUILD_OBJECT('message','synthetic Party diagnostic','detail','synthetic Party detail',
        'hint','synthetic Party hint','schema','public','table','parties','column','party_id',
        'constraint','pp_synthetic_diagnostic','datatype',''),'inject:'||s.state
FROM pp_cases b CROSS JOIN (VALUES ('22001'),('23503'),('23505'),('40001'),('40P01'),('P0001'),('57014'),('P0004')) s(state)
WHERE b.label='person-base';
-- Deliberate guards supply no auxiliary diagnostics and never interpolate payload values.
UPDATE pp_cases SET expected_diag=
    '{"detail":"","hint":"","schema":"","table":"","column":"","constraint":"","datatype":""}'::JSONB
    ||expected_diag WHERE expected_state='P0001' AND mode='normal';

CREATE FUNCTION pg_temp.pp_run_cases() RETURNS SETOF TEXT LANGUAGE plpgsql AS $cases$
DECLARE c pp_cases%ROWTYPE; b JSONB; a JSONB; r JSONB; n BIGINT; new_id BIGINT;
        seq_before BIGINT; seq_called BOOLEAN; late_ok BOOLEAN;

BEGIN
    FOR c IN SELECT * FROM pp_cases ORDER BY label LOOP
        b := pg_temp.pp_rows();
        SELECT COUNT(*) INTO n FROM public.parties;
        PERFORM SET_CONFIG('opal.party_test_mode',c.mode,true);
        SELECT last_value,is_called INTO seq_before,seq_called FROM public.party_id_seq;
        PERFORM SETVAL('pg_temp.pp_attempts',1,false);
        r := pg_temp.pp_probe(COALESCE(c.raw_payload,c.payload::JSON),c.account);
        a := pg_temp.pp_rows();
        RETURN NEXT is(r->>'state',c.expected_state,c.label||': SQLSTATE');
        IF c.expected_state='00000' THEN
            new_id := (r->>'id')::BIGINT;
            INSERT INTO pp_outputs VALUES(c.label,new_id);
            RETURN NEXT ok((r->>'succeeded')::BOOLEAN AND new_id IS NOT NULL
                AND (SELECT COUNT(*) FROM public.parties)=n+1
                AND (SELECT COUNT(*) FROM public.parties WHERE party_id=new_id)=1
                AND new_id=CURRVAL('public.party_id_seq')
                AND (c.label<>'country-raw-exponent' OR c.raw_payload #>> '{address,cjs_code}'='3.1001e4'),
                c.label||': one row and generated OUT ID; original raw JSON when supplied');
            RETURN NEXT is((SELECT TO_JSONB(p)-'party_id' FROM public.parties p WHERE party_id=new_id),
                c.expected,c.label||': every mapped column preserves expected value');
            RETURN NEXT ok((b-'parties') IS NOT DISTINCT FROM (a-'parties')
                AND NOT EXISTS(SELECT 1 FROM JSONB_ARRAY_ELEMENTS_TEXT(b->'parties') old
                    WHERE NOT EXISTS(SELECT 1 FROM public.parties p WHERE ROW_TO_JSON(p)::TEXT=old.value)),
                c.label||': preexisting Parties and downstream/status rows unchanged');
        ELSE
            RETURN NEXT ok(r->'succeeded'='false'::JSONB AND r->'id'='null'::JSONB,
                c.label||': no successful result or ID');
            RETURN NEXT is(a,b,c.label||': failed call preserves scoped rows');
            late_ok := c.mode='normal' OR (
                (SELECT last_value=1 AND is_called FROM pg_temp.pp_attempts)
                AND (SELECT last_value=CASE WHEN seq_called THEN seq_before+1 ELSE seq_before END AND is_called
                     FROM public.party_id_seq)
                AND (c.mode NOT LIKE 'inject:%' OR (
                    r->>'context' LIKE '%pp_inject()%'
                    AND r->>'context' LIKE '%p_insert_parties%'))
            );
            RETURN NEXT ok(r @> c.expected_diag AND late_ok
                AND (c.expected_state<>'P0001' OR c.mode<>'normal'
                    OR POSITION('__payload__' IN COALESCE(r->>'message',''))=0),
                c.label||': original diagnostics context one attempt and sequence consumption');
        END IF;
    END LOOP;
    PERFORM SET_CONFIG('opal.party_test_mode','normal',true);
END;
$cases$;

-- -----------------------------------------------------------------------------
-- Scenario: Verify catalogue contract and populated functional cases.
-- Setup: Inspect exact IN identity, ordered IN/OUT arguments, defaults, comment and UTF-8.
-- Expected: Six catalogue assertions, four per case and eight rollback/cleanup assertions.
-- -----------------------------------------------------------------------------
SELECT plan(14 + 4*(SELECT COUNT(*)::INTEGER FROM pp_cases));
SELECT ok((SELECT prokind='p' FROM pg_proc WHERE oid=
    TO_REGPROCEDURE('public.p_insert_parties(json,public.t_party_account_type_enum)')),
    'public Party object is a procedure with exact IN identity');
SELECT ok((SELECT proargnames=ARRAY['pi_party_json','pi_account_type','po_party_id']
    AND proargmodes=ARRAY['i','i','o']::"char"[]
    AND proallargtypes=ARRAY['json'::REGTYPE::OID,'public.t_party_account_type_enum'::REGTYPE::OID,'bigint'::REGTYPE::OID]
    FROM pg_proc WHERE oid=TO_REGPROCEDURE('public.p_insert_parties(json,public.t_party_account_type_enum)')),
    'ordered names modes and resolved JSON enum BIGINT types');
SELECT is((SELECT JSONB_BUILD_ARRAY(l.lanname::TEXT,p.prosecdef,p.proisstrict,p.provolatile::TEXT,
    p.proparallel::TEXT,p.pronargdefaults,p.proconfig)
    FROM pg_proc p JOIN pg_language l ON l.oid=p.prolang
    WHERE p.oid=TO_REGPROCEDURE('public.p_insert_parties(json,public.t_party_account_type_enum)')),
    '["plpgsql",false,false,"v","u",0,null]'::JSONB,'effective invoker defaults and no parameter defaults');
SELECT is(OBJ_DESCRIPTION(TO_REGPROCEDURE('public.p_insert_parties(json,public.t_party_account_type_enum)'),'pg_proc'),
    'Insert one Party with exact mapped values and resolved Country; return its generated ID. Caller owns transaction and publication.',
    'object comment states one-row output and ownership');
SELECT is((SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.proname='p_insert_parties'),1::BIGINT,'one public procedure overload');
SELECT ok(CURRENT_SETTING('server_encoding')='UTF8' AND CURRENT_SETTING('client_encoding')='UTF8',
    'UTF-8 permits decoded multibyte character boundaries');
-- The complete field matrix snapshots all scoped tables in one buffered statement.
SET LOCAL statement_timeout = '60s';
SELECT * FROM pg_temp.pp_run_cases();
SET LOCAL statement_timeout = '30s';

-- -----------------------------------------------------------------------------
-- Scenario: Repeat calls insert distinct Parties and the caller owns rollback.
-- Setup: Savepoint observations are psql variables; no TAP counter is changed inside it.
-- Expected: The caller sees then removes one Party, restores scoped rows and retains the ID gap.
-- -----------------------------------------------------------------------------
SELECT ok((SELECT a.id<>b.id FROM pp_outputs a CROSS JOIN pp_outputs b
    WHERE a.label='person-repeat-a' AND b.label='person-repeat-b'),
    'repeat successful calls create distinct Parties without deduplication');
SELECT pg_temp.pp_rows()::TEXT AS pp_before_rollback \gset
SAVEPOINT pp_caller_owned;
SELECT pg_temp.pp_probe(payload::JSON,account)::TEXT AS pp_rollback_result
FROM pp_cases WHERE label='person-base' \gset
SELECT EXISTS(SELECT 1 FROM public.parties
    WHERE party_id=(:'pp_rollback_result'::JSONB->>'id')::BIGINT) AS pp_visible_before_rollback \gset
ROLLBACK TO SAVEPOINT pp_caller_owned;
RELEASE SAVEPOINT pp_caller_owned;
SELECT ok(:'pp_visible_before_rollback'::BOOLEAN,'successful insert is visible inside caller savepoint');
SELECT ok(NOT EXISTS(SELECT 1 FROM public.parties
    WHERE party_id=(:'pp_rollback_result'::JSONB->>'id')::BIGINT),'caller rollback removes successful Party');
SELECT is(pg_temp.pp_rows(),:'pp_before_rollback'::JSONB,'caller rollback restores scoped row state');
SELECT ok((SELECT last_value=(:'pp_rollback_result'::JSONB->>'id')::BIGINT AND is_called FROM public.party_id_seq),
    'caller rollback retains consumed sequence value');

-- -----------------------------------------------------------------------------
-- Scenario: Remove owned injection objects and prove the Country sequence is untouched.
-- Setup: Drop only the collision-guarded test trigger/function before the owner rollback.
-- Expected: Injection objects are absent and explicit fixture IDs did not consume Country IDs.
-- -----------------------------------------------------------------------------
DROP TRIGGER po10647_party_diagnostics ON public.parties;
DROP FUNCTION pg_temp.pp_inject();
SELECT ok(NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='po10647_party_diagnostics'),
    'owned injection trigger removed');
SELECT ok(TO_REGPROCEDURE('pg_temp.pp_inject()') IS NULL,'owned injection helper removed');
SELECT results_eq('SELECT last_value,is_called FROM public.country_id_seq',
    'SELECT last_value,is_called FROM pp_country_sequence_before','Country sequence unchanged by fixtures and calls');
SELECT * FROM finish();
ROLLBACK;
