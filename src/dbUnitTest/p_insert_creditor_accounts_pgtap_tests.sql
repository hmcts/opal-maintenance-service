/**
 * OPAL Program
 *
 * MODULE      : p_insert_creditor_accounts_pgtap_tests.sql
 *
 * DESCRIPTION : Verify creditor creation, outputs, semantic/native errors and ownership.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket    Nature of Change
 * ----------  -------------  --------  -----------------------------------------
 * 13/10/2026  Frankie Moran  PO-10643  Initial pgTAP test suite.
 */
-- DB-04/DB-06: routine catalogue, direct outcomes, errors, row scope and rollback.
-- DB-01 fresh and DB-03 predecessor paths are both applicable.
-- DB-03 execution remains unmet until maintained shared predecessor support exists.
-- Bank request validation is owned upstream; this suite proves accepted-value mapping.
\set ON_ERROR_STOP on
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SET LOCAL search_path = public, pg_catalog;
SET LOCAL TIME ZONE 'UTC';
SET LOCAL statement_timeout = '30s';

-- -----------------------------------------------------------------------------
-- Scenario: Synthetic reference fixtures establish supported identity paths.
-- Setup: Collision-checked BU IDs/codes, existing reference Country, generated IDs.
-- Expected: No real data, sequence assumptions, truncation or suite-order dependency.
-- -----------------------------------------------------------------------------
DO $fixture$
BEGIN
    IF EXISTS (SELECT 1 FROM public.business_units
               WHERE business_unit_id IN (31981,31982,31984,31990)
                  OR business_unit_code IN ('IC81','IC82','IC84'))
       OR EXISTS (SELECT 1 FROM public.parties WHERE party_id=-31990)
       OR EXISTS (SELECT 1 FROM public.major_creditors WHERE major_creditor_id=-31990)
       OR EXISTS (SELECT 1 FROM public.third_party_contact WHERE third_party_contact_id=-31990) THEN
        RAISE EXCEPTION 'Synthetic creditor fixture collision';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.countries) THEN
        RAISE EXCEPTION 'Country reference data required';
    END IF;
END;
$fixture$;
INSERT INTO public.business_units
    (business_unit_id,business_unit_code,business_unit_name,business_unit_type,welsh_language)
VALUES (31981,'IC81','Synthetic creditor unit A','Area',false),
       (31982,'IC82','Synthetic creditor unit B','Area',false),
       (31984,'IC84','Synthetic late-failure unit','Area',false);
CREATE TEMP TABLE ca_country AS SELECT MIN(country_id) AS id FROM public.countries;
CREATE TEMP TABLE ca_party AS WITH inserted AS (
    INSERT INTO public.parties(organisation,organisation_name,address_line_1,
                              restrict_personal_information,country_id,account_type)
    SELECT true, v.name, 'Synthetic Address', false, c.id, v.account_type
    FROM ca_country c CROSS JOIN (VALUES
        ('Applicant','Minor Creditor'::public.t_party_account_type_enum),
        ('Minor','Minor Creditor'::public.t_party_account_type_enum),
        ('Respondent','Respondent'::public.t_party_account_type_enum),
        ('Untyped',NULL::public.t_party_account_type_enum)) v(name,account_type)
    RETURNING party_id,organisation_name
) SELECT party_id AS id,organisation_name AS role FROM inserted;
CREATE TEMP TABLE ca_contact AS WITH inserted AS (
    INSERT INTO public.third_party_contact(name_organisation,relationship,address_line_1,country)
    SELECT 'Synthetic Contact','Synthetic relation','Synthetic Address',id FROM ca_country
    RETURNING third_party_contact_id
) SELECT third_party_contact_id AS id FROM inserted;
CREATE TEMP TABLE ca_major AS WITH inserted AS (
    INSERT INTO public.major_creditors(business_unit_id,major_creditor_code,name,
        address_line_1,country_id,active,central_authority)
    SELECT bu,code,'Synthetic Major','Synthetic Address',id,active,false
    FROM ca_country CROSS JOIN (VALUES
        (31981::SMALLINT,'ICMC',false),(31982::SMALLINT,'ICMC',true)) v(bu,code,active)
    RETURNING major_creditor_id,business_unit_id
) SELECT major_creditor_id AS id,business_unit_id AS bu FROM inserted;
INSERT INTO public.draft_casefiles(business_unit_id,created_date,submitted_by,submitted_by_name,
    casefile,casefile_snapshot,casefile_type,casefile_status,casefile_status_date,timeline_data)
VALUES (31981,TIMESTAMP '2026-10-12 00:00:00','SYNTHETIC','Synthetic User',
    '{"synthetic":true}','{ "preserve" : true }','REMO In','SUBMITTED',
    TIMESTAMP '2026-10-12 00:00:00','[]');
CREATE TEMP TABLE ca_before_references AS
SELECT 'business_units' AS object,business_unit_id AS id,ROW_TO_JSON(u)::TEXT AS value FROM public.business_units u
UNION ALL SELECT 'parties',party_id,ROW_TO_JSON(p)::TEXT FROM public.parties p
UNION ALL SELECT 'contacts',third_party_contact_id,ROW_TO_JSON(c)::TEXT FROM public.third_party_contact c
UNION ALL SELECT 'majors',major_creditor_id,ROW_TO_JSON(m)::TEXT FROM public.major_creditors m
UNION ALL SELECT 'drafts',draft_casefile_id,ROW_TO_JSON(d)::TEXT FROM public.draft_casefiles d;
CREATE TEMP TABLE ca_before_accounts AS
SELECT creditor_account_id AS id,ROW_TO_JSON(c)::TEXT AS value FROM public.creditor_accounts c;
CREATE TEMP TABLE ca_before_allocations AS SELECT * FROM public.account_number_index;
CREATE TEMP TABLE ca_valid (
    label TEXT PRIMARY KEY,bu SMALLINT DEFAULT 31981,payload JSON,major_id BIGINT,
    party_id BIGINT,contact_id BIGINT,account_type TEXT,payment BOOLEAN,bank_expected JSONB
);
CREATE TEMP TABLE ca_invalid (
    label TEXT PRIMARY KEY,bu SMALLINT,payload JSON,major_id BIGINT,party_id BIGINT,
    contact_id BIGINT,state TEXT,constraint_name TEXT DEFAULT '',column_name TEXT DEFAULT ''
);
CREATE TEMP TABLE ca_outputs (
    label TEXT PRIMARY KEY,id BIGINT,number TEXT,account_delta BIGINT,allocation_delta BIGINT
);

-- -----------------------------------------------------------------------------
-- Scenario: Accepted canonical bank objects map for each independently called role.
-- Setup: Literal expectations, accepted mapping values and explicit storage boundaries and nullable contact.
-- Expected: One account/reservation, exact pair, MN/MJ identities and creation flags.
-- -----------------------------------------------------------------------------
INSERT INTO ca_valid VALUES ('applicant-uk',31981,
    '{"bank_account_details":{"bank_account_type":"UK Bank","uk_bank_details":{"account_name":"A","sort_code":"001234","account_number":"000001","payment_reference":"R"}}}',
    NULL,(SELECT id FROM ca_party WHERE role='Applicant'),NULL,'MN',true,
    '["001234","000001","A","R",null]');
INSERT INTO ca_valid VALUES ('minor-uk-contact',31981,
    '{"bank_account_details":{"bank_account_type":"UK Bank","uk_bank_details":{"account_name":"AAAAAAAAAAAAAAAAAA","sort_code":"000001","account_number":"00000001","payment_reference":"RRRRRRRRRRRRRRRRRR"}}}',
    NULL,(SELECT id FROM ca_party WHERE role='Minor'),(SELECT id FROM ca_contact),'MN',true,
    '["000001","00000001","AAAAAAAAAAAAAAAAAA","RRRRRRRRRRRRRRRRRR",null]');
INSERT INTO ca_valid VALUES ('major',31981,NULL,(SELECT id FROM ca_major WHERE bu=31981),
    NULL,NULL,'MJ',false,'[null,null,null,null,null]');
INSERT INTO ca_valid VALUES ('none',31981,
    '{"bank_account_details":{"bank_account_type":"None or not applicable"}}',
    NULL,(SELECT id FROM ca_party WHERE role='Minor'),NULL,'MN',false,'[null,null,null,null,null]');
INSERT INTO ca_valid VALUES ('none-repeat',31981,
    '{"bank_account_details":{"bank_account_type":"None or not applicable"}}',
    NULL,(SELECT id FROM ca_party WHERE role='Minor'),NULL,'MN',false,'[null,null,null,null,null]');
INSERT INTO ca_valid VALUES ('nonuk-neither',31981,
    '{"bank_account_details":{"bank_account_type":"Non-UK Bank","non_uk_bank_details":{ "account_name" : "A", "payment_reference" : "R", "bank_name":"Synthetic", "branch_code_or_sort_code":"000012", "account_number":"000001" }}}',
    NULL,(SELECT id FROM ca_party WHERE role='Minor'),NULL,'MN',true,
    '[null,null,null,null,{"account_name":"A","payment_reference":"R","bank_name":"Synthetic","branch_code_or_sort_code":"000012","account_number":"000001"}]');
INSERT INTO ca_valid VALUES ('nonuk-bic',31981,
    '{"bank_account_details":{"bank_account_type":"Non-UK Bank","non_uk_bank_details":{"account_name":"A","payment_reference":"R","bic_or_swift_code":"ABCDEFGH"}}}',
    NULL,(SELECT id FROM ca_party WHERE role='Minor'),NULL,'MN',true,
    '[null,null,null,null,{"account_name":"A","payment_reference":"R","bic_or_swift_code":"ABCDEFGH"}]');
INSERT INTO ca_valid VALUES ('nonuk-iban',31981,
    '{"bank_account_details":{"bank_account_type":"Non-UK Bank","non_uk_bank_details":{"account_name":"A","payment_reference":"R","iban":"GB01"}}}',
    NULL,(SELECT id FROM ca_party WHERE role='Minor'),NULL,'MN',true,
    '[null,null,null,null,{"account_name":"A","payment_reference":"R","iban":"GB01"}]');
INSERT INTO ca_valid VALUES ('nonuk-both',31981,
    '{"bank_account_details":{"bank_account_type":"Non-UK Bank","non_uk_bank_details":{"account_name":"AAAAAAAAAAAAAAAAAA","payment_reference":"RRRRRRRRRRRRRRRRRR","bic_or_swift_code":"ABCDEFGHIJK","iban":"IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII","branch_code_or_sort_code":"000000000001","account_number":"00000000000000000001"}}}',
    NULL,(SELECT id FROM ca_party WHERE role='Minor'),NULL,'MN',true,
    '[null,null,null,null,{"account_name":"AAAAAAAAAAAAAAAAAA","payment_reference":"RRRRRRRRRRRRRRRRRR","bic_or_swift_code":"ABCDEFGHIJK","iban":"IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII","branch_code_or_sort_code":"000000000001","account_number":"00000000000000000001"}]');
INSERT INTO ca_valid VALUES ('late-seed',31984,
    '{"bank_account_details":{"bank_account_type":"None or not applicable"}}',
    NULL,(SELECT id FROM ca_party WHERE role='Minor'),NULL,'MN',false,'[null,null,null,null,null]');


-- Applicant is a distinct caller role sharing the same supported Party path.
INSERT INTO ca_valid VALUES ('nonuk-applicant',31981,
    '{"bank_account_details":{"bank_account_type":"Non-UK Bank","non_uk_bank_details":{ "account_name":"A", "payment_reference":"R", "bic_or_swift_code":"ABCDEFGH", "iban":"GB01" }}}',
    NULL,(SELECT id FROM ca_party WHERE role='Applicant'),NULL,'MN',true,
    '[null,null,null,null,{"account_name":"A","payment_reference":"R","bic_or_swift_code":"ABCDEFGH","iban":"GB01"}]');
INSERT INTO ca_valid VALUES ('applicant-none',31981,
    '{"bank_account_details":{"bank_account_type":"None or not applicable"}}',
    NULL,(SELECT id FROM ca_party WHERE role='Applicant'),NULL,'MN',false,
    '[null,null,null,null,null]');
-- This is a SQL storage boundary, not an upstream UK journey-validity assertion.
INSERT INTO ca_valid VALUES ('uk-storage-width',31981,
    '{"bank_account_details":{"bank_account_type":"UK Bank","uk_bank_details":{"account_name":"AAAAAAAAAAAAAAAAAA","sort_code":"000001","account_number":"0000000001","payment_reference":"RRRRRRRRRRRRRRRRRR"}}}',
    NULL,(SELECT id FROM ca_party WHERE role='Minor'),NULL,'MN',true,
    '["000001","0000000001","AAAAAAAAAAAAAAAAAA","RRRRRRRRRRRRRRRRRR",null]');

-- -----------------------------------------------------------------------------
-- Scenario: Semantic conditions absent from table constraints raise deliberate errors.
-- Setup: One isolated invalid path/classification/pairing per row, other inputs valid.
-- Expected: Default P0001, safe routine/operation context and no successful rows/outputs.
-- -----------------------------------------------------------------------------
INSERT INTO ca_invalid(label,bu,payload,major_id,party_id,contact_id,state)
SELECT label,31981,payload::JSON,major_id,party_id,contact_id,'P0001'
FROM ca_party p CROSS JOIN ca_contact c CROSS JOIN ca_major m
CROSS JOIN LATERAL (VALUES
    ('neither','{"bank_account_details":{"bank_account_type":"None or not applicable"}}',NULL::BIGINT,NULL::BIGINT,NULL::BIGINT),
    ('both','{"bank_account_details":{"bank_account_type":"None or not applicable"}}',m.id,p.id,NULL),
    ('major-payload','{}',m.id,NULL,NULL),
    ('major-json-null','null',m.id,NULL,NULL),
    ('major-contact',NULL,m.id,NULL,c.id)
) v(label,payload,major_id,party_id,contact_id) WHERE p.role='Minor' AND m.bu=31981;
INSERT INTO ca_invalid(label,bu,payload,party_id,state)
SELECT 'party-'||role,31981,'{"bank_account_details":{"bank_account_type":"None or not applicable"}}',id,'P0001'
FROM ca_party WHERE role IN ('Respondent','Untyped');
INSERT INTO ca_invalid(label,bu,major_id,state)
SELECT 'major-bu-pairing',31981,id,'P0001' FROM ca_major WHERE bu=31982;

-- -----------------------------------------------------------------------------
-- Scenario: Simple absent references/nullability retain native diagnostics.
-- Setup: Proven-absent IDs; valid bank object, exclusive identity and otherwise valid refs.
-- Expected: The isolated allocator or creditor FK/NOT NULL failure propagates unchanged.
-- -----------------------------------------------------------------------------
INSERT INTO ca_invalid(label,bu,payload,party_id,state,constraint_name,column_name)
SELECT 'bu-null',NULL,'{"bank_account_details":{"bank_account_type":"None or not applicable"}}',id,'23502','','business_unit_id'
FROM ca_party WHERE role='Minor';
INSERT INTO ca_invalid(label,bu,major_id,state,column_name)
SELECT 'major-bu-null',NULL,id,'23502','business_unit_id' FROM ca_major WHERE bu=31981;
INSERT INTO ca_invalid(label,bu,payload,party_id,state,constraint_name)
SELECT 'bu-unknown',31990,'{"bank_account_details":{"bank_account_type":"None or not applicable"}}',id,'23503','ani_business_unit_id_fk'
FROM ca_party WHERE role='Minor';
INSERT INTO ca_invalid(label,bu,payload,party_id,state,constraint_name)
VALUES ('party-unknown',31981,'{"bank_account_details":{"bank_account_type":"None or not applicable"}}',-31990,'23503','ca_minor_creditor_party_id_fk');
INSERT INTO ca_invalid(label,bu,major_id,state,constraint_name)
VALUES ('major-unknown',31981,-31990,'23503','ca_major_creditor_id_fk');
INSERT INTO ca_invalid(label,bu,payload,party_id,contact_id,state,constraint_name)
SELECT 'contact-unknown',31981,'{"bank_account_details":{"bank_account_type":"None or not applicable"}}',id,-31990,'23503','ca_third_party_contact_id_fk'
FROM ca_party WHERE role='Minor';
INSERT INTO ca_invalid(label,bu,payload,party_id,state,constraint_name)
SELECT 'late-native-unique',31984,'{"bank_account_details":{"bank_account_type":"None or not applicable"}}',id,'23505','ca_business_unit_id_account_number_uk'
FROM ca_party WHERE role='Minor';

-- -----------------------------------------------------------------------------
-- Scenario: Storage widths reject excess text without shortening accepted strings.
-- Setup: Each payload exceeds exactly one scalar target; all references are valid.
-- Expected: Native 22001, and the helper's real reservation is rolled back.
-- -----------------------------------------------------------------------------
INSERT INTO ca_invalid(label,bu,payload,party_id,state)
SELECT label,31981,payload::JSON,p.id,'22001'
FROM ca_party p CROSS JOIN (VALUES
    ('sort-overlength','{"bank_account_details":{"bank_account_type":"UK Bank","uk_bank_details":{"account_name":"A","sort_code":"0000001","account_number":"000001","payment_reference":"R"}}}'),
    ('number-overlength','{"bank_account_details":{"bank_account_type":"UK Bank","uk_bank_details":{"account_name":"A","sort_code":"000001","account_number":"00000000001","payment_reference":"R"}}}'),
    ('name-overlength','{"bank_account_details":{"bank_account_type":"UK Bank","uk_bank_details":{"account_name":"AAAAAAAAAAAAAAAAAAA","sort_code":"000001","account_number":"000001","payment_reference":"R"}}}'),
    ('reference-overlength','{"bank_account_details":{"bank_account_type":"UK Bank","uk_bank_details":{"account_name":"A","sort_code":"000001","account_number":"000001","payment_reference":"RRRRRRRRRRRRRRRRRRR"}}}')
) v(label,payload) WHERE p.role='Minor';
-- -----------------------------------------------------------------------------
-- Scenario: Mapping has no alias or implicit no-bank fallback.
-- Setup: Valid Party/BU with unsupported None alias or absent mapping selector.
-- Expected: Native CASE_NOT_FOUND (20000), no claim of detailed bank validation.
-- -----------------------------------------------------------------------------
INSERT INTO ca_invalid(label,bu,payload,party_id,state)
SELECT label,31981,payload::JSON,p.id,'20000'
FROM ca_party p CROSS JOIN (VALUES
    ('selector-none-alias','{"bank_account_details":{"bank_account_type":"None"}}'),
    ('selector-absent','{"bank_account_details":{}}')
) v(label,payload) WHERE p.role='Minor';

CREATE FUNCTION pg_temp.ca_capture(pi_label TEXT) RETURNS VOID LANGUAGE plpgsql AS $capture$
DECLARE
    v_case ca_valid%ROWTYPE;
    v_id BIGINT;
    v_number VARCHAR;
    v_accounts BIGINT;
    v_allocations BIGINT;

BEGIN
    SELECT * INTO STRICT v_case FROM ca_valid WHERE label=pi_label;
    SELECT COUNT(*) INTO v_accounts FROM public.creditor_accounts;
    SELECT COUNT(*) INTO v_allocations FROM public.account_number_index;
    CALL public.p_insert_creditor_accounts(v_case.bu,v_case.payload,v_case.major_id,
        v_case.party_id,v_case.contact_id,v_id,v_number);
    INSERT INTO ca_outputs VALUES (pi_label,v_id,v_number,
        (SELECT COUNT(*) FROM public.creditor_accounts)-v_accounts,
        (SELECT COUNT(*) FROM public.account_number_index)-v_allocations);
END;
$capture$;
CREATE FUNCTION pg_temp.ca_probe(pi_bu SMALLINT,pi_payload JSON,pi_major BIGINT,
    pi_party BIGINT,pi_contact BIGINT) RETURNS JSONB LANGUAGE plpgsql AS $probe$
DECLARE
    v_id BIGINT;
    v_number VARCHAR;
    v_constraint TEXT;
    v_column TEXT;

BEGIN
    CALL public.p_insert_creditor_accounts(pi_bu,pi_payload,pi_major,pi_party,pi_contact,v_id,v_number);
    RETURN JSONB_BUILD_OBJECT('state','00000','succeeded',true,'id',v_id,'number',v_number);

EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_constraint=CONSTRAINT_NAME,v_column=COLUMN_NAME;

    RETURN JSONB_BUILD_OBJECT('state',SQLSTATE,'message',SQLERRM,'constraint',v_constraint,
        'column',v_column,'succeeded',false,'id',v_id,'number',v_number);
END;
$probe$;

DO $case_count$
BEGIN
    IF (SELECT COUNT(*) FROM ca_valid)<>13 OR (SELECT COUNT(*) FROM ca_invalid)<>21 THEN
        RAISE EXCEPTION 'Creditor scenario inventory differs from exact TAP plan';
    END IF;
END;
$case_count$;
SELECT plan(177);
-- -----------------------------------------------------------------------------
-- Scenario: The delivered procedure exposes the exact effective CALL contract.
-- Setup: Inspect independent catalogue expectations, not declaration text.
-- Expected: Public PL/pgSQL procedure, seven named/mode/type arguments, default attributes.
-- -----------------------------------------------------------------------------
SELECT ok(TO_REGPROCEDURE('public.p_insert_creditor_accounts(smallint,json,bigint,bigint,bigint)') IS NOT NULL,
    'procedure exists with five IN types');
SELECT is((SELECT JSONB_BUILD_ARRAY(prokind::TEXT,proargnames,proargmodes::TEXT[],
    ARRAY(SELECT t::REGTYPE::TEXT FROM UNNEST(proallargtypes) t)) FROM pg_proc
    WHERE oid=TO_REGPROCEDURE('public.p_insert_creditor_accounts(smallint,json,bigint,bigint,bigint)')),
    '["p",["pi_business_unit_id","pi_creditor_account_json","pi_major_creditor_id","pi_party_id","pi_third_party_contact_id","po_creditor_account_id","po_account_number"],["i","i","i","i","i","o","o"],["smallint","json","bigint","bigint","bigint","bigint","character varying"]]'::JSONB,
    'exact ordered names, modes and resolved base types');
SELECT is((SELECT JSONB_BUILD_ARRAY(l.lanname::TEXT,p.prosecdef,p.proisstrict,p.provolatile::TEXT,
    p.pronargdefaults,p.proconfig) FROM pg_proc p JOIN pg_language l ON l.oid=p.prolang
    WHERE p.oid=TO_REGPROCEDURE('public.p_insert_creditor_accounts(smallint,json,bigint,bigint,bigint)')),
    '["plpgsql",false,false,"v",0,null]'::JSONB,'default caller privileges and effective attributes');
SELECT is(OBJ_DESCRIPTION(TO_REGPROCEDURE('public.p_insert_creditor_accounts(smallint,json,bigint,bigint,bigint)'),'pg_proc'),
    'Create one creditor account from validated input; allocate once and return its ID and number. Caller owns transaction and publication.',
    'comment describes the responsibility boundary');
SELECT ok(TO_REGPROCEDURE('public.f_get_account_number(smallint,public.t_associated_record_type_enum)') IS NOT NULL
    AND TO_REGPROCEDURE('public.f_get_check_letter(character varying)') IS NOT NULL,
    'real allocator and checksum dependencies are present');

CREATE FUNCTION pg_temp.ca_success_tests() RETURNS SETOF TEXT LANGUAGE plpgsql AS $success$
DECLARE v_case ca_valid%ROWTYPE; v_output ca_outputs%ROWTYPE;

BEGIN
    FOR v_case IN SELECT * FROM ca_valid ORDER BY label LOOP
        RETURN NEXT lives_ok(FORMAT('SELECT pg_temp.ca_capture(%L)',v_case.label),v_case.label||': succeeds');
        SELECT * INTO v_output FROM ca_outputs WHERE label=v_case.label;
        RETURN NEXT is(JSONB_BUILD_ARRAY(v_output.account_delta,v_output.allocation_delta),'[1,1]'::JSONB,
            v_case.label||': one account and one allocation');
        RETURN NEXT is((SELECT COUNT(*) FROM public.creditor_accounts c JOIN public.account_number_index a
            ON a.business_unit_id=c.business_unit_id AND a.account_number=c.account_number
            WHERE c.creditor_account_id=v_output.id AND c.account_number=v_output.number
              AND c.business_unit_id=v_case.bu AND a.associated_record_type='creditor_accounts'),
            1::BIGINT,v_case.label||': both outputs match one persisted pair');
        RETURN NEXT is((SELECT JSONB_BUILD_ARRAY(c.business_unit_id,c.creditor_account_type,c.major_creditor_id,
            c.minor_creditor_party_id,c.third_party_contact_id,c.from_suspense,c.hold_payout,c.pay_by_bacs,
            c.last_changed_date,c.version_number,c.bank_sort_code,c.bank_account_number,c.bank_account_name,
            c.bank_account_reference,c.non_uk_bank_detail::JSONB)
            FROM public.creditor_accounts c WHERE c.creditor_account_id=v_output.id),
            JSONB_BUILD_ARRAY(v_case.bu,v_case.account_type,v_case.major_id,v_case.party_id,v_case.contact_id,
                false,false,v_case.payment,NULL,NULL)||v_case.bank_expected,
            v_case.label||': identity, creation flags and accepted bank mapping');
        RETURN NEXT ok((SELECT c.non_uk_bank_detail::TEXT IS NOT DISTINCT FROM
            CASE WHEN v_case.payload #>> '{bank_account_details,bank_account_type}' = 'Non-UK Bank' THEN
                (v_case.payload->'bank_account_details'->'non_uk_bank_details')::TEXT ELSE NULL END
            FROM public.creditor_accounts c WHERE c.creditor_account_id=v_output.id),
            v_case.label||': original selected JSON text or SQL NULL preserved');
    END LOOP;
END;
$success$;
SELECT * FROM pg_temp.ca_success_tests();

-- -----------------------------------------------------------------------------
-- Scenario: A native account uniqueness failure follows a real successful reservation.
-- Setup: Seed one real account; remove only its test-owned reservation before retry.
-- Expected: ca_business_unit_id_account_number_uk propagates, allocation is unwound.
-- -----------------------------------------------------------------------------
CREATE TEMP TABLE ca_late_allocation AS
SELECT a.* FROM public.account_number_index a JOIN ca_outputs o
    ON o.label='late-seed' AND a.business_unit_id=31984 AND a.account_number=o.number;
DO $guard$
BEGIN
    IF (SELECT COUNT(*) FROM ca_late_allocation)<>1
       OR (SELECT COUNT(*) FROM public.account_number_index WHERE business_unit_id=31984)<>1 THEN
        RAISE EXCEPTION 'Late-failure fixture did not reserve exactly one owned candidate';
    END IF;
END;
$guard$;
DELETE FROM public.account_number_index WHERE account_number_index_id IN
    (SELECT account_number_index_id FROM ca_late_allocation);
CREATE FUNCTION pg_temp.ca_invalid_tests() RETURNS SETOF TEXT LANGUAGE plpgsql AS $invalid$
DECLARE v_case ca_invalid%ROWTYPE; v_result JSONB; v_accounts BIGINT; v_allocations BIGINT;

BEGIN
    FOR v_case IN SELECT * FROM ca_invalid ORDER BY label LOOP
        SELECT COUNT(*) INTO v_accounts FROM public.creditor_accounts;
        SELECT COUNT(*) INTO v_allocations FROM public.account_number_index;
        v_result := pg_temp.ca_probe(v_case.bu,v_case.payload,v_case.major_id,v_case.party_id,v_case.contact_id);
        RETURN NEXT is(JSONB_BUILD_ARRAY(v_result->>'state',v_result->>'constraint',v_result->>'column',
            v_result->'succeeded',v_result->'id',v_result->'number'),
            JSONB_BUILD_ARRAY(v_case.state,v_case.constraint_name,v_case.column_name,false,NULL,NULL),
            v_case.label||': native/semantic diagnostic and no successful output');
        RETURN NEXT ok(CASE WHEN v_case.state='P0001' THEN
            v_result->>'message' LIKE 'p_insert_creditor_accounts: % failed; %' ELSE
            LENGTH(v_result->>'message')>0 END,v_case.label||': useful scoped diagnostic');
        RETURN NEXT is((SELECT COUNT(*) FROM public.creditor_accounts),v_accounts,v_case.label||': no account residue');
        RETURN NEXT is((SELECT COUNT(*) FROM public.account_number_index),v_allocations,v_case.label||': no allocation residue');
    END LOOP;
END;
$invalid$;
SELECT * FROM pg_temp.ca_invalid_tests();
INSERT INTO public.account_number_index(account_number_index_id,business_unit_id,account_number,associated_record_type)
SELECT account_number_index_id,business_unit_id,account_number,associated_record_type FROM ca_late_allocation;

-- -----------------------------------------------------------------------------
-- Scenario: Successful creation participates in the caller's rollback.
-- Setup: Counts outside the savepoint; CALL and ordinary checks inside; TAP afterwards.
-- Expected: Transactional account/allocation rows disappear; no sequence rewind promise.
-- -----------------------------------------------------------------------------
CREATE TEMP TABLE ca_rollback_before AS SELECT
    (SELECT COUNT(*) FROM public.creditor_accounts) AS accounts,
    (SELECT COUNT(*) FROM public.account_number_index) AS allocations;
SAVEPOINT ca_caller;
DO $rollback$
DECLARE v_party BIGINT; v_id BIGINT; v_number VARCHAR;

BEGIN
    SELECT id INTO v_party FROM ca_party WHERE role='Minor';
    CALL public.p_insert_creditor_accounts(31981::SMALLINT,
        '{"bank_account_details":{"bank_account_type":"None or not applicable"}}'::JSON,
        NULL::BIGINT,v_party,NULL::BIGINT,v_id,v_number);

    IF v_id IS NULL OR v_number IS NULL OR NOT EXISTS (
        SELECT 1 FROM public.creditor_accounts c JOIN public.account_number_index a
        ON a.business_unit_id=c.business_unit_id AND a.account_number=c.account_number
        WHERE c.creditor_account_id=v_id AND c.account_number=v_number) THEN
        RAISE EXCEPTION 'Successful rollback probe did not create a matching output pair';
    END IF;
END;
$rollback$;
ROLLBACK TO SAVEPOINT ca_caller;
RELEASE SAVEPOINT ca_caller;
SELECT is((SELECT COUNT(*) FROM public.creditor_accounts),(SELECT accounts FROM ca_rollback_before),'caller rollback removes account');
SELECT is((SELECT COUNT(*) FROM public.account_number_index),(SELECT allocations FROM ca_rollback_before),'caller rollback removes reservation');
SELECT isnt((SELECT id FROM ca_outputs WHERE label='none'),(SELECT id FROM ca_outputs WHERE label='none-repeat'),'repeat creates distinct ID');
SELECT isnt((SELECT number FROM ca_outputs WHERE label='none'),(SELECT number FROM ca_outputs WHERE label='none-repeat'),'repeat creates distinct number');
SELECT results_eq($q$
    SELECT 'business_units' AS object,business_unit_id AS id,ROW_TO_JSON(u)::TEXT AS value FROM public.business_units u
    UNION ALL SELECT 'parties',party_id,ROW_TO_JSON(p)::TEXT FROM public.parties p
    UNION ALL SELECT 'contacts',third_party_contact_id,ROW_TO_JSON(c)::TEXT FROM public.third_party_contact c
    UNION ALL SELECT 'majors',major_creditor_id,ROW_TO_JSON(m)::TEXT FROM public.major_creditors m
    UNION ALL SELECT 'drafts',draft_casefile_id,ROW_TO_JSON(d)::TEXT FROM public.draft_casefiles d
    ORDER BY object,id$q$,'SELECT * FROM ca_before_references ORDER BY object,id',
    'references and Draft Casefile status/snapshot remain unchanged');
SELECT results_eq($q$SELECT c.creditor_account_id AS id,ROW_TO_JSON(c)::TEXT AS value FROM public.creditor_accounts c
    WHERE NOT EXISTS (SELECT 1 FROM ca_outputs o WHERE o.id=c.creditor_account_id) ORDER BY id$q$,
    'SELECT * FROM ca_before_accounts ORDER BY id','unrelated creditor accounts unchanged');
SELECT results_eq($q$SELECT * FROM public.account_number_index WHERE business_unit_id NOT IN (31981,31982,31984)
    ORDER BY account_number_index_id$q$,'SELECT * FROM ca_before_allocations ORDER BY account_number_index_id',
    'unrelated allocations unchanged');

-- -----------------------------------------------------------------------------
-- Scenario: Helper preserves real allocator errors and bounded retry diagnostics.
-- Setup: BU-filtered trigger, nontransactional counter, five injected collisions;
--        then one serialization and one deadlock failure.
-- Expected: Allocator P0001 retains original cause/constraint; other codes are unchanged.
-- -----------------------------------------------------------------------------
CREATE SEQUENCE pg_temp.ca_attempts START 1;
CREATE FUNCTION pg_temp.ca_inject_allocation() RETURNS TRIGGER LANGUAGE plpgsql AS $inject$
BEGIN
    IF NEW.business_unit_id=31982 THEN
        PERFORM NEXTVAL('pg_temp.ca_attempts');
        RAISE EXCEPTION USING ERRCODE=CURRENT_SETTING('po10643.injected_state'),
            MESSAGE='synthetic creditor allocation failure',CONSTRAINT='po10643_synthetic_collision';
    END IF;

    RETURN NEW;
END;
$inject$;
CREATE TRIGGER po10643_inject_allocation BEFORE INSERT ON public.account_number_index
    FOR EACH ROW EXECUTE FUNCTION pg_temp.ca_inject_allocation();
CREATE TEMP TABLE ca_failure_before AS SELECT
    (SELECT COUNT(*) FROM public.creditor_accounts) AS accounts,
    (SELECT COUNT(*) FROM public.account_number_index) AS allocations;
SET LOCAL po10643.injected_state='23505';
CREATE TEMP TABLE ca_failure_result AS SELECT pg_temp.ca_probe(31982::SMALLINT,
    '{"bank_account_details":{"bank_account_type":"None or not applicable"}}'::JSON,
    NULL::BIGINT,(SELECT id FROM ca_party WHERE role='Minor'),NULL::BIGINT) AS value;
SELECT is((SELECT value->>'state' FROM ca_failure_result),'P0001','allocator collision exhaustion propagates');
SELECT is((SELECT value->>'constraint' FROM ca_failure_result),'po10643_synthetic_collision','allocator constraint diagnostic preserved');
SELECT ok((SELECT value->>'message' LIKE 'f_get_account_number: allocation failed after five attempts; Account number = %, BU = 31982; 23505: synthetic creditor allocation failure%'
    FROM ca_failure_result),'allocator operation, candidate, BU and original cause preserved');
SELECT is((SELECT last_value FROM pg_temp.ca_attempts),5::BIGINT,'helper adds no collision retries');
SELECT is((SELECT COUNT(*) FROM public.creditor_accounts),(SELECT accounts FROM ca_failure_before),'exhaustion creates no account');
SELECT is((SELECT COUNT(*) FROM public.account_number_index),(SELECT allocations FROM ca_failure_before),'exhaustion creates no reservation');
SELECT is((SELECT JSONB_BUILD_ARRAY(value->'succeeded',value->'id',value->'number') FROM ca_failure_result),
    '[false,null,null]'::JSONB,'allocation failure returns no successful output pair');

ALTER SEQUENCE pg_temp.ca_attempts RESTART WITH 1;
SET LOCAL po10643.injected_state='40001';
TRUNCATE ca_failure_result;
INSERT INTO ca_failure_result SELECT pg_temp.ca_probe(31982::SMALLINT,
    '{"bank_account_details":{"bank_account_type":"None or not applicable"}}'::JSON,
    NULL::BIGINT,(SELECT id FROM ca_party WHERE role='Minor'),NULL::BIGINT);
SELECT is((SELECT value->>'state' FROM ca_failure_result),'40001','serialization failure propagates');
SELECT is((SELECT last_value FROM pg_temp.ca_attempts),1::BIGINT,'no helper serialization retry');
SELECT is((SELECT COUNT(*) FROM public.creditor_accounts),(SELECT accounts FROM ca_failure_before),'serialization leaves no account');
SELECT is((SELECT COUNT(*) FROM public.account_number_index),(SELECT allocations FROM ca_failure_before),'serialization leaves no reservation');

ALTER SEQUENCE pg_temp.ca_attempts RESTART WITH 1;
SET LOCAL po10643.injected_state='40P01';
TRUNCATE ca_failure_result;
INSERT INTO ca_failure_result SELECT pg_temp.ca_probe(31982::SMALLINT,
    '{"bank_account_details":{"bank_account_type":"None or not applicable"}}'::JSON,
    NULL::BIGINT,(SELECT id FROM ca_party WHERE role='Minor'),NULL::BIGINT);
SELECT is((SELECT value->>'state' FROM ca_failure_result),'40P01','deadlock failure propagates');
SELECT is((SELECT last_value FROM pg_temp.ca_attempts),1::BIGINT,'no helper deadlock retry');
SELECT is((SELECT COUNT(*) FROM public.creditor_accounts),(SELECT accounts FROM ca_failure_before),'deadlock leaves no account');
SELECT is((SELECT COUNT(*) FROM public.account_number_index),(SELECT allocations FROM ca_failure_before),'deadlock leaves no reservation');
DROP TRIGGER po10643_inject_allocation ON public.account_number_index;
DROP FUNCTION pg_temp.ca_inject_allocation();
SELECT is((SELECT COUNT(*) FROM pg_trigger WHERE tgname='po10643_inject_allocation'),0::BIGINT,'test injection removed');
SELECT * FROM finish();
ROLLBACK;
