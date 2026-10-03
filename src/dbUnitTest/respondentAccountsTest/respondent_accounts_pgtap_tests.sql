-- PO-10657: V1_24__create_respondent_accounts_table.sql
-- DB-04 contract: columns, comments, owned enum/sequence, defaults, keys and indexes;
-- required/nullable fields, boundaries, generated IDs and native integrity failures.
-- DB-01 fresh path: applicable. This is initial-schema delivery before account use.
-- Existing-state validation: Not run - user-approved initial-schema scope exception.
-- Court column/index retained; only ra_last_hearing_court_id_fk deferred. No locking algorithm.
\set ON_ERROR_STOP on
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SET LOCAL search_path = public, pg_temp;
SET LOCAL TIME ZONE 'UTC';
SELECT plan(126);
DO $fixture$
BEGIN
    IF EXISTS (SELECT 1 FROM public.business_units WHERE business_unit_id IN (32061, 32062)
               OR business_unit_code IN ('CV61', 'CV62')) THEN
        RAISE EXCEPTION 'Synthetic Business Unit fixture collision';
    END IF;
END
$fixture$;
INSERT INTO public.business_units
    (business_unit_id, business_unit_code, business_unit_name, business_unit_type, welsh_language)
VALUES (32061, 'CV61', 'Synthetic test unit A', 'Area', false),
       (32062, 'CV62', 'Synthetic test unit B', 'Area', false);
CREATE TEMP TABLE cv_subject (id bigint PRIMARY KEY);
CREATE TEMP TABLE cv_second (id bigint PRIMARY KEY);
DO $fixture$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.countries) THEN
        RAISE EXCEPTION 'Required Country reference data missing';
    END IF;
END $fixture$;
CREATE TEMP TABLE cv_reference AS
    SELECT min(country_id) AS country_id FROM public.countries;
CREATE TEMP TABLE cv_contact AS WITH inserted AS (
    INSERT INTO public.third_party_contact(name_organisation, relationship, address_line_1, country)
    SELECT 'Synthetic Contact', 'Synthetic relationship', 'Synthetic Address', country_id
    FROM cv_reference RETURNING third_party_contact_id
) SELECT third_party_contact_id FROM inserted;
CREATE TEMP TABLE cv_debtor AS WITH inserted AS (
    INSERT INTO public.debtor_detail(other_personal_information)
    VALUES ('Synthetic additional information') RETURNING debtor_detail_id
) SELECT debtor_detail_id FROM inserted;
DO $fixture$ BEGIN
    IF EXISTS (SELECT 1 FROM public.maintenance_applications WHERE application_code = 'CVRA')
       OR EXISTS (SELECT 1 FROM public.results WHERE result_id IN ('CVR001', 'CVLENA')) THEN
        RAISE EXCEPTION 'Synthetic Application/Result fixture collision';
    END IF;
END $fixture$;
CREATE TEMP TABLE cv_application AS WITH inserted AS (
    INSERT INTO public.maintenance_applications
        (application_code, application_title, application_group, active, date_used_from)
    VALUES ('CVRA', 'Synthetic Application', 'Synthetic', true, DATE '2026-01-01')
    RETURNING application_id
) SELECT application_id FROM inserted;
INSERT INTO public.results(result_id, result_title, order_term, enforcement_result, case_result,
    active, order_accruing, requires_creditor, enforcement_hold, requires_enforcer,
    generates_hearing, generates_warrant, lists_monies, requires_employment_data,
    allow_additional_action, enf_next_permitted_actions, manual_enforcement, auto_enforcement)
VALUES ('CVR001', 'Synthetic Result', false, true, false, true, false, false, false,
    false, false, false, false, false, false, 'None', false, false),
    ('CVLENA', 'Synthetic length Result', false, true, false, true, false, false, false,
    false, false, false, false, false, false, 'None', false, false);

-- -----------------------------------------------------------------------------
-- Scenario: The delivered schema matches the promoted TDIA.
-- Setup: Read the PostgreSQL catalogues against independent literal expectations.
-- Expected: Exact columns, comments, keys, indexes, enum labels and owned sequence; no extra rules.
SELECT has_table('public', 'respondent_accounts', 'respondent_accounts exists');
SELECT is((SELECT jsonb_agg(jsonb_build_array(attname::text,
        format_type(atttypid, atttypmod), attnotnull,
        col_description(attrelid, attnum)) ORDER BY attnum)
    FROM pg_attribute WHERE attrelid = 'public.respondent_accounts'::regclass
      AND attnum > 0 AND NOT attisdropped),
    '[
        ["respondent_account_id","bigint",true,"Unique identifier of the Respondent Account"],
        ["business_unit_id","smallint",true,"Identifier of the Business Unit owning the account"],
        ["debtor_detail_id","bigint",false,"Identifier of the respondent Debtor Detail"],
        ["account_number","character varying(20)",true,"Account number unique within the Business Unit"],
        ["application_id","smallint",true,"Identifier of the primary Maintenance Application"],
        ["imposed_hearing_date","timestamp without time zone",false,"Date the maintenance order was imposed"],
        ["last_hearing_date","timestamp without time zone",false,"Date the account was most recently heard in court"],
        ["last_hearing_court_id","bigint",false,"Identifier of the court for the latest hearing"],
        ["account_balance","numeric",true,"Receipts held on the account before allocation and payout"],
        ["orders_balance","numeric",true,"Total balance due across the account''s order terms"],
        ["orders_amount","numeric",true,"Total periodic amount due across the account''s order terms"],
        ["payment_period","t_payment_frequency_enum",true,"Payment period for the account"],
        ["total_arrears","numeric",true,"Total arrears across costs and order terms"],
        ["account_status","t_da_account_status_enum",true,"Lifecycle status of the Respondent Account"],
        ["completed_date","timestamp without time zone",false,"Date the account completed after all order terms expired and arrears cleared"],
        ["last_movement_date","timestamp without time zone",true,"Date of the most recent account movement"],
        ["date_arrears_last_updated","timestamp without time zone",true,"Date the account arrears were last updated. On publication, populate this from the mandatory Date arrears last updated value in the Draft Casefile’s Order Details object."],
        ["last_enforcement_result_id","character varying(6)",false,"Identifier of the latest applicable enforcement result"],
        ["last_enforcement_date","timestamp without time zone",false,"Date the latest enforcement action was applied"],
        ["originator_name","character varying(200)",false,"Name of the originating court or system"],
        ["allow_cheques","boolean",true,"Whether cheque payments are accepted"],
        ["cheque_clearance_period","smallint",true,"Days before cheque payments are treated as cleared"],
        ["credit_trans_clearance_period","smallint",true,"Days before credit-transfer payments are treated as cleared"],
        ["casefile_type","t_casefile_type_enum",true,"REMO In, REMO Out, or REMO Out (CMS) casefile type"],
        ["third_party_contact_id","bigint",false,"Identifier of the optional third-party contact"],
        ["remo_reference","character varying(20)",false,"REMO reference for the account"],
        ["ca_reference","character varying(50)",false,"Central Authority reference for the account"],
        ["interest_flag","boolean",true,"Whether interest applies to the account"],
        ["indexation","t_indexation_enum",true,"RPI, CPI, None, or Other indexation method"],
        ["payment_arrangement","t_payment_arrangement_enum",true,"Court or direct payment arrangement"],
        ["account_comment","text",false,"Optional account comment displayed in Account Enquiry"],
        ["version_number","bigint",true,"Optimistic-locking version of the account"]
    ]'::jsonb,
    'exact ordered columns, physical types, nullability and source comments');
SELECT is((SELECT jsonb_agg(jsonb_build_array(conname::text, contype::text,
        ARRAY(SELECT a.attname::text FROM unnest(c.conkey) WITH ORDINALITY k(attnum, ord)
              JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = k.attnum ORDER BY k.ord),
        condeferrable, condeferred, convalidated) ORDER BY conname::text COLLATE "C")
    FROM pg_constraint c WHERE conrelid = 'public.respondent_accounts'::regclass
      AND contype IN ('p', 'f', 'u', 'c')),
    '[
        ["ra_application_id_fk","f",["application_id"],false,false,true],
        ["ra_business_unit_id_account_number_uk","u",["business_unit_id","account_number"],false,false,true],
        ["ra_business_unit_id_fk","f",["business_unit_id"],false,false,true],
        ["ra_debtor_detail_id_fk","f",["debtor_detail_id"],false,false,true],
        ["ra_last_enforcement_result_id_fk","f",["last_enforcement_result_id"],false,false,true],
        ["ra_third_party_contact_id_fk","f",["third_party_contact_id"],false,false,true],
        ["respondent_accounts_pk","p",["respondent_account_id"],false,false,true]
    ]'::jsonb,
    'exact constraint names, kinds, keys and immediate validated properties');
SELECT is((SELECT jsonb_agg(jsonb_build_array(c.conname::text, n.nspname::text,
        p.relname::text, ARRAY(SELECT a.attname::text
          FROM unnest(c.confkey) WITH ORDINALITY k(attnum, ord)
          JOIN pg_attribute a ON a.attrelid = c.confrelid AND a.attnum = k.attnum ORDER BY k.ord),
        c.confupdtype::text, c.confdeltype::text, c.confmatchtype::text)
        ORDER BY c.conname::text COLLATE "C")
    FROM pg_constraint c JOIN pg_class p ON p.oid = c.confrelid
    JOIN pg_namespace n ON n.oid = p.relnamespace
    WHERE c.conrelid = 'public.respondent_accounts'::regclass AND c.contype = 'f'),
    '[
        ["ra_application_id_fk","public","maintenance_applications",["application_id"],"a","a","s"],
        ["ra_business_unit_id_fk","public","business_units",["business_unit_id"],"a","a","s"],
        ["ra_debtor_detail_id_fk","public","debtor_detail",["debtor_detail_id"],"a","a","s"],
        ["ra_last_enforcement_result_id_fk","public","results",["result_id"],"a","a","s"],
        ["ra_third_party_contact_id_fk","public","third_party_contact",["third_party_contact_id"],"a","a","s"]
    ]'::jsonb,
    'exact FK endpoints and keys with NO ACTION update/delete and SIMPLE matching');
SELECT is((SELECT jsonb_agg(jsonb_build_array(r.relname::text, am.amname::text,
        i.indisunique, i.indisprimary, i.indisvalid, i.indisready, i.indnkeyatts, i.indnatts,
        ARRAY(SELECT pg_get_indexdef(i.indexrelid, k, true)
              FROM generate_series(1, i.indnkeyatts) k),
        i.indpred IS NULL, i.indexprs IS NULL, i.indnullsnotdistinct)
        ORDER BY r.relname::text COLLATE "C")
    FROM pg_index i JOIN pg_class r ON r.oid = i.indexrelid
    JOIN pg_am am ON am.oid = r.relam WHERE i.indrelid = 'public.respondent_accounts'::regclass),
    '[
        ["ra_business_unit_id_account_number_uk","btree",true,false,true,true,2,2,["business_unit_id","account_number"],true,true,false],
        ["respondent_accounts_application_id_idx","btree",false,false,true,true,1,1,["application_id"],true,true,false],
        ["respondent_accounts_debtor_detail_id_idx","btree",false,false,true,true,1,1,["debtor_detail_id"],true,true,false],
        ["respondent_accounts_last_enforcement_result_id_idx","btree",false,false,true,true,1,1,["last_enforcement_result_id"],true,true,false],
        ["respondent_accounts_last_hearing_court_id_idx","btree",false,false,true,true,1,1,["last_hearing_court_id"],true,true,false],
        ["respondent_accounts_pk","btree",true,true,true,true,1,1,["respondent_account_id"],true,true,false],
        ["respondent_accounts_third_party_contact_id_idx","btree",false,false,true,true,1,1,["third_party_contact_id"],true,true,false]
    ]'::jsonb,
    'exact indexes, ordered keys, uniqueness and valid ready btree properties');
SELECT is(pg_get_serial_sequence('public.respondent_accounts', 'respondent_account_id'),
    'public.respondent_account_id_seq', 'sequence is owned by the identifier column');
SELECT is((SELECT jsonb_build_array(seqtypid::regtype::text, seqstart, seqmin,
        seqmax, seqincrement, seqcache, seqcycle)
    FROM pg_sequence WHERE seqrelid = 'public.respondent_account_id_seq'::regclass),
    '["bigint",1,1,9223372036854775807,1,1,false]'::jsonb,
    'BIGINT sequence starts at one with increment/cache one and no cycle');
SELECT is((SELECT jsonb_agg(jsonb_build_array(a.attname::text,
        pg_get_expr(d.adbin, d.adrelid)) ORDER BY a.attnum)
    FROM pg_attrdef d JOIN pg_attribute a ON a.attrelid = d.adrelid AND a.attnum = d.adnum
    WHERE d.adrelid = 'public.respondent_accounts'::regclass),
    '[
        ["respondent_account_id","nextval(''respondent_account_id_seq''::regclass)"]
    ]'::jsonb,
    'only the identifier has a nextval default; other values are supplied explicitly');
SELECT is((SELECT count(*) FROM pg_trigger
    WHERE tgrelid = 'public.respondent_accounts'::regclass AND NOT tgisinternal),
    0::bigint, 'no user trigger introduces extra behaviour');
SELECT is((SELECT jsonb_agg(enumlabel::text ORDER BY enumsortorder)
    FROM pg_enum WHERE enumtypid = 'public.t_payment_frequency_enum'::regtype),
    '["Weekly","Fortnightly","Monthly","Quarterly","Yearly"]'::jsonb, 't_payment_frequency_enum exact labels and order');
SELECT is((SELECT jsonb_agg(enumlabel::text ORDER BY enumsortorder)
    FROM pg_enum WHERE enumtypid = 'public.t_da_account_status_enum'::regtype),
    '["L","C"]'::jsonb, 't_da_account_status_enum exact labels and order');
SELECT is((SELECT jsonb_agg(enumlabel::text ORDER BY enumsortorder)
    FROM pg_enum WHERE enumtypid = 'public.t_indexation_enum'::regtype),
    '["RPI","CPI","Other","None"]'::jsonb, 't_indexation_enum exact labels and order');
SELECT is((SELECT jsonb_agg(enumlabel::text ORDER BY enumsortorder)
    FROM pg_enum WHERE enumtypid = 'public.t_payment_arrangement_enum'::regtype),
    '["Court","Direct"]'::jsonb, 't_payment_arrangement_enum exact labels and order');
SELECT is((SELECT jsonb_agg(enumlabel::text ORDER BY enumsortorder)
    FROM pg_enum WHERE enumtypid = 'public.t_casefile_type_enum'::regtype),
    '["REMO In","REMO Out","REMO Out (CMS)"]'::jsonb, 't_casefile_type_enum exact labels and order');

-- -----------------------------------------------------------------------------
-- Scenario: A minimal live account generates its identifier.
-- Setup: Supply required financial, boolean, clearance and version values explicitly.
-- Expected: The insert succeeds with no business defaults or account allocator dependency.
SELECT lives_ok($sql$WITH inserted AS (INSERT INTO public.respondent_accounts(business_unit_id, account_number, application_id, account_balance, orders_balance, orders_amount, payment_period, total_arrears, account_status, last_movement_date, date_arrears_last_updated, allow_cheques, cheque_clearance_period, credit_trans_clearance_period, casefile_type, interest_flag, indexation, payment_arrangement, version_number)
 SELECT 32061, 'CV-RESPONDENT', application_id, 0, 0, 0, 'Weekly', 0, 'L', TIMESTAMP '2026-01-01 12:00:00', TIMESTAMP '2026-01-01 12:00:00', true, 10, 0, 'REMO In', false, 'None', 'Court', 1 FROM cv_application RETURNING respondent_account_id)
 INSERT INTO cv_subject SELECT respondent_account_id FROM inserted$sql$, 'minimal valid Respondent Account');

-- -----------------------------------------------------------------------------
-- Scenario: Each column preserves its declared NULL contract.
-- Setup: Update the captured minimal valid row one column at a time.
-- Expected: Required columns reject NULL with 23502; nullable columns accept NULL.
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET respondent_account_id = NULL
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '23502', NULL, 'respondent_account_id rejects NULL');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET business_unit_id = NULL
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '23502', NULL, 'business_unit_id rejects NULL');
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET debtor_detail_id = NULL
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'debtor_detail_id accepts NULL');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET account_number = NULL
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '23502', NULL, 'account_number rejects NULL');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET application_id = NULL
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '23502', NULL, 'application_id rejects NULL');
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET imposed_hearing_date = NULL
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'imposed_hearing_date accepts NULL');
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET last_hearing_date = NULL
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'last_hearing_date accepts NULL');
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET last_hearing_court_id = NULL
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'last_hearing_court_id accepts NULL');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET account_balance = NULL
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '23502', NULL, 'account_balance rejects NULL');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET orders_balance = NULL
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '23502', NULL, 'orders_balance rejects NULL');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET orders_amount = NULL
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '23502', NULL, 'orders_amount rejects NULL');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET payment_period = NULL
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '23502', NULL, 'payment_period rejects NULL');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET total_arrears = NULL
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '23502', NULL, 'total_arrears rejects NULL');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET account_status = NULL
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '23502', NULL, 'account_status rejects NULL');
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET completed_date = NULL
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'completed_date accepts NULL');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET last_movement_date = NULL
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '23502', NULL, 'last_movement_date rejects NULL');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET date_arrears_last_updated = NULL
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '23502', NULL, 'date_arrears_last_updated rejects NULL');
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET last_enforcement_result_id = NULL
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'last_enforcement_result_id accepts NULL');
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET last_enforcement_date = NULL
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'last_enforcement_date accepts NULL');
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET originator_name = NULL
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'originator_name accepts NULL');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET allow_cheques = NULL
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '23502', NULL, 'allow_cheques rejects NULL');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET cheque_clearance_period = NULL
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '23502', NULL, 'cheque_clearance_period rejects NULL');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET credit_trans_clearance_period = NULL
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '23502', NULL, 'credit_trans_clearance_period rejects NULL');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET casefile_type = NULL
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '23502', NULL, 'casefile_type rejects NULL');
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET third_party_contact_id = NULL
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'third_party_contact_id accepts NULL');
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET remo_reference = NULL
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'remo_reference accepts NULL');
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET ca_reference = NULL
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'ca_reference accepts NULL');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET interest_flag = NULL
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '23502', NULL, 'interest_flag rejects NULL');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET indexation = NULL
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '23502', NULL, 'indexation rejects NULL');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET payment_arrangement = NULL
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '23502', NULL, 'payment_arrangement rejects NULL');
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET account_comment = NULL
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'account_comment accepts NULL');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET version_number = NULL
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '23502', NULL, 'version_number rejects NULL');

-- -----------------------------------------------------------------------------
-- Scenario: account_number accepts its exact length and rejects overflow.
-- Setup: Use the valid subject and isolate the VARCHAR boundary.
-- Expected: 20 characters succeed; 21 characters fail with 22001.
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET account_number = repeat('x', 20)
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'account_number accepts 20 characters');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET account_number = repeat('x', 21)
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '22001', NULL, 'account_number rejects 21 characters');

-- -----------------------------------------------------------------------------
-- Scenario: last_enforcement_result_id accepts its exact length and rejects overflow.
-- Setup: Use the valid subject and isolate the VARCHAR boundary.
-- Expected: 6 characters succeed; 7 characters fail with 22001.
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET last_enforcement_result_id = 'CVLENA'
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'last_enforcement_result_id accepts 6 characters');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET last_enforcement_result_id = repeat('x', 7)
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '22001', NULL, 'last_enforcement_result_id rejects 7 characters');

-- -----------------------------------------------------------------------------
-- Scenario: originator_name accepts its exact length and rejects overflow.
-- Setup: Use the valid subject and isolate the VARCHAR boundary.
-- Expected: 200 characters succeed; 201 characters fail with 22001.
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET originator_name = repeat('x', 200)
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'originator_name accepts 200 characters');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET originator_name = repeat('x', 201)
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '22001', NULL, 'originator_name rejects 201 characters');

-- -----------------------------------------------------------------------------
-- Scenario: remo_reference accepts its exact length and rejects overflow.
-- Setup: Use the valid subject and isolate the VARCHAR boundary.
-- Expected: 20 characters succeed; 21 characters fail with 22001.
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET remo_reference = repeat('x', 20)
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'remo_reference accepts 20 characters');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET remo_reference = repeat('x', 21)
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '22001', NULL, 'remo_reference rejects 21 characters');

-- -----------------------------------------------------------------------------
-- Scenario: ca_reference accepts its exact length and rejects overflow.
-- Setup: Use the valid subject and isolate the VARCHAR boundary.
-- Expected: 50 characters succeed; 51 characters fail with 22001.
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET ca_reference = repeat('x', 50)
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'ca_reference accepts 50 characters');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET ca_reference = repeat('x', 51)
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '22001', NULL, 'ca_reference rejects 51 characters');
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET account_number = 'CV-RESPONDENT'
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'restore account identity after length boundary');

-- -----------------------------------------------------------------------------
-- Scenario: payment_period accepts only its controlled values.
-- Setup: Update the subject using every literal label, then an unsupported label.
-- Expected: Each supported value succeeds; the unsupported value fails with 22P02.
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET payment_period = 'Weekly'
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'payment_period accepts Weekly');
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET payment_period = 'Fortnightly'
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'payment_period accepts Fortnightly');
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET payment_period = 'Monthly'
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'payment_period accepts Monthly');
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET payment_period = 'Quarterly'
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'payment_period accepts Quarterly');
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET payment_period = 'Yearly'
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'payment_period accepts Yearly');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET payment_period = 'Unsupported'
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '22P02', NULL, 'payment_period rejects unsupported value');

-- -----------------------------------------------------------------------------
-- Scenario: account_status accepts only its controlled values.
-- Setup: Update the subject using every literal label, then an unsupported label.
-- Expected: Each supported value succeeds; the unsupported value fails with 22P02.
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET account_status = 'L'
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'account_status accepts L');
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET account_status = 'C'
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'account_status accepts C');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET account_status = 'Unsupported'
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '22P02', NULL, 'account_status rejects unsupported value');

-- -----------------------------------------------------------------------------
-- Scenario: indexation accepts only its controlled values.
-- Setup: Update the subject using every literal label, then an unsupported label.
-- Expected: Each supported value succeeds; the unsupported value fails with 22P02.
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET indexation = 'RPI'
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'indexation accepts RPI');
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET indexation = 'CPI'
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'indexation accepts CPI');
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET indexation = 'Other'
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'indexation accepts Other');
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET indexation = 'None'
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'indexation accepts None');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET indexation = 'Unsupported'
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '22P02', NULL, 'indexation rejects unsupported value');

-- -----------------------------------------------------------------------------
-- Scenario: payment_arrangement accepts only its controlled values.
-- Setup: Update the subject using every literal label, then an unsupported label.
-- Expected: Each supported value succeeds; the unsupported value fails with 22P02.
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET payment_arrangement = 'Court'
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'payment_arrangement accepts Court');
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET payment_arrangement = 'Direct'
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'payment_arrangement accepts Direct');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET payment_arrangement = 'Unsupported'
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '22P02', NULL, 'payment_arrangement rejects unsupported value');

-- -----------------------------------------------------------------------------
-- Scenario: casefile_type accepts only its controlled values.
-- Setup: Update the subject using every literal label, then an unsupported label.
-- Expected: Each supported value succeeds; the unsupported value fails with 22P02.
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET casefile_type = 'REMO In'
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'casefile_type accepts REMO In');
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET casefile_type = 'REMO Out'
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'casefile_type accepts REMO Out');
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET casefile_type = 'REMO Out (CMS)'
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'casefile_type accepts REMO Out (CMS)');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET casefile_type = 'Unsupported'
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '22P02', NULL, 'casefile_type rejects unsupported value');

-- -----------------------------------------------------------------------------
-- Scenario: business_unit_id enforces the declared parent relationship.
-- Setup: Use a captured synthetic parent and prove the missing key is absent.
-- Expected: Valid reference succeeds; missing reference and deletion of the referenced parent fail with 23503.
SELECT ok(NOT EXISTS(SELECT 1 FROM public.business_units WHERE business_unit_id = -32061),
    'business_unit_id missing fixture key is absent');
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET business_unit_id = 32062
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'business_unit_id accepts a valid parent');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET business_unit_id = -32061
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '23503', NULL, 'business_unit_id rejects a missing parent');
SELECT throws_ok($sql$DELETE FROM public.business_units WHERE business_unit_id = 32062$sql$, '23503', NULL, 'business_unit_id prevents deletion of the referenced synthetic parent');

-- -----------------------------------------------------------------------------
-- Scenario: application_id enforces the declared parent relationship.
-- Setup: Use a captured synthetic parent and prove the missing key is absent.
-- Expected: Valid reference succeeds; missing reference and deletion of the referenced parent fail with 23503.
SELECT ok(NOT EXISTS(SELECT 1 FROM public.maintenance_applications WHERE application_id = -32061),
    'application_id missing fixture key is absent');
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET application_id = (SELECT application_id FROM cv_application)
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'application_id accepts a valid parent');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET application_id = -32061
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '23503', NULL, 'application_id rejects a missing parent');
SELECT throws_ok($sql$DELETE FROM public.maintenance_applications WHERE application_id = (SELECT application_id FROM cv_application)$sql$, '23503', NULL, 'application_id prevents deletion of the referenced synthetic parent');

-- -----------------------------------------------------------------------------
-- Scenario: debtor_detail_id enforces the declared parent relationship.
-- Setup: Use a captured synthetic parent and prove the missing key is absent.
-- Expected: Valid reference succeeds; missing reference and deletion of the referenced parent fail with 23503.
SELECT ok(NOT EXISTS(SELECT 1 FROM public.debtor_detail WHERE debtor_detail_id = -990061),
    'debtor_detail_id missing fixture key is absent');
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET debtor_detail_id = (SELECT debtor_detail_id FROM cv_debtor)
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'debtor_detail_id accepts a valid parent');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET debtor_detail_id = -990061
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '23503', NULL, 'debtor_detail_id rejects a missing parent');
SELECT throws_ok($sql$DELETE FROM public.debtor_detail WHERE debtor_detail_id = (SELECT debtor_detail_id FROM cv_debtor)$sql$, '23503', NULL, 'debtor_detail_id prevents deletion of the referenced synthetic parent');

-- -----------------------------------------------------------------------------
-- Scenario: last_enforcement_result_id enforces the declared parent relationship.
-- Setup: Use a captured synthetic parent and prove the missing key is absent.
-- Expected: Valid reference succeeds; missing reference and deletion of the referenced parent fail with 23503.
SELECT ok(NOT EXISTS(SELECT 1 FROM public.results WHERE result_id = 'CVMISS'),
    'last_enforcement_result_id missing fixture key is absent');
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET last_enforcement_result_id = 'CVR001'
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'last_enforcement_result_id accepts a valid parent');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET last_enforcement_result_id = 'CVMISS'
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '23503', NULL, 'last_enforcement_result_id rejects a missing parent');
SELECT throws_ok($sql$DELETE FROM public.results WHERE result_id = 'CVR001'$sql$, '23503', NULL, 'last_enforcement_result_id prevents deletion of the referenced synthetic parent');

-- -----------------------------------------------------------------------------
-- Scenario: third_party_contact_id enforces the declared parent relationship.
-- Setup: Use a captured synthetic parent and prove the missing key is absent.
-- Expected: Valid reference succeeds; missing reference and deletion of the referenced parent fail with 23503.
SELECT ok(NOT EXISTS(SELECT 1 FROM public.third_party_contact WHERE third_party_contact_id = -990061),
    'third_party_contact_id missing fixture key is absent');
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET third_party_contact_id = (SELECT third_party_contact_id FROM cv_contact)
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'third_party_contact_id accepts a valid parent');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET third_party_contact_id = -990061
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '23503', NULL, 'third_party_contact_id rejects a missing parent');
SELECT throws_ok($sql$DELETE FROM public.third_party_contact WHERE third_party_contact_id = (SELECT third_party_contact_id FROM cv_contact)$sql$, '23503', NULL, 'third_party_contact_id prevents deletion of the referenced synthetic parent');
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET business_unit_id = 32061
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'restore owning Business Unit');

-- -----------------------------------------------------------------------------
-- Scenario: Account identity is unique within each Business Unit.
-- Setup: Create a second generated ID and attempt PK and scoped-identity collisions.
-- Expected: Duplicate IDs/pairs fail with 23505; the same number in another unit succeeds.
SELECT lives_ok($sql$WITH inserted AS (INSERT INTO public.respondent_accounts(business_unit_id, account_number, application_id, account_balance, orders_balance, orders_amount, payment_period, total_arrears, account_status, last_movement_date, date_arrears_last_updated, allow_cheques, cheque_clearance_period, credit_trans_clearance_period, casefile_type, interest_flag, indexation, payment_arrangement, version_number)
 SELECT 32061, 'CV-RESPONDENT-2', application_id, 0, 0, 0, 'Weekly', 0, 'L', TIMESTAMP '2026-01-01 12:00:00', TIMESTAMP '2026-01-01 12:00:00', true, 10, 0, 'REMO In', false, 'None', 'Court', 1 FROM cv_application
 RETURNING respondent_account_id) INSERT INTO cv_second SELECT respondent_account_id FROM inserted$sql$, 'second account generates a distinct ID');
SELECT ok((SELECT id FROM cv_subject) IS NOT NULL AND (SELECT id FROM cv_second) IS NOT NULL
    AND (SELECT id FROM cv_subject) <> (SELECT id FROM cv_second), 'generated IDs are non-null and distinct');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET respondent_account_id = (SELECT id FROM cv_subject)
 WHERE respondent_account_id = (SELECT id FROM cv_second)$sql$, '23505', NULL, 'duplicate Respondent Account primary key rejected');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET account_number = 'CV-RESPONDENT'
 WHERE respondent_account_id = (SELECT id FROM cv_second)$sql$, '23505', NULL, 'duplicate Business Unit/account-number pair rejected');
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET business_unit_id = 32062, account_number = 'CV-RESPONDENT'
 WHERE respondent_account_id = (SELECT id FROM cv_second)$sql$, 'same account number accepted in another Business Unit');

-- -----------------------------------------------------------------------------
-- Scenario: The hearing-court FK is deferred and no extra business CHECK exists.
-- Setup: Use arbitrary hearing-court ID and negative financial/clearance/version values.
-- Expected: Supplied values succeed without Courts or invented positivity/locking rules.
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET last_hearing_court_id = -990061
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'arbitrary non-null hearing-court ID accepted without deferred FK');
SELECT is((SELECT count(*) FROM pg_constraint WHERE conrelid = 'public.respondent_accounts'::regclass
    AND conname = 'ra_last_hearing_court_id_fk'), 0::bigint, 'deferred hearing-court FK absent');
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET account_balance = -12.345, orders_balance = -0.25, orders_amount = -3.5, total_arrears = -1.125, cheque_clearance_period = -1, credit_trans_clearance_period = -2, version_number = -1
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'no invented financial, clearance or version positivity CHECK');
SELECT is((SELECT jsonb_build_array(account_balance, orders_balance, orders_amount, total_arrears,
    cheque_clearance_period, credit_trans_clearance_period, version_number)
    FROM public.respondent_accounts WHERE respondent_account_id = (SELECT id FROM cv_subject)),
    '[-12.345,-0.25,-3.5,-1.125,-1,-2,-1]'::jsonb, 'fractional numeric values persist without rounding');

-- -----------------------------------------------------------------------------
-- Scenario: UTC-convention TIMESTAMP values are stored unchanged.
-- Setup: Supply explicit TIMESTAMP literals to every date column under local UTC.
-- Expected: Stored values equal the supplied timestamps without claiming timezone conversion.
SELECT lives_ok($sql$UPDATE public.respondent_accounts SET imposed_hearing_date = TIMESTAMP '2026-01-02 03:04:05.123456', last_hearing_date = TIMESTAMP '2026-01-02 03:04:05.123456', completed_date = TIMESTAMP '2026-01-02 03:04:05.123456', last_movement_date = TIMESTAMP '2026-01-02 03:04:05.123456', date_arrears_last_updated = TIMESTAMP '2026-01-02 03:04:05.123456', last_enforcement_date = TIMESTAMP '2026-01-02 03:04:05.123456'
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, 'set explicit UTC-convention dates');
SELECT is((SELECT imposed_hearing_date FROM public.respondent_accounts WHERE respondent_account_id = (SELECT id FROM cv_subject)),
    TIMESTAMP '2026-01-02 03:04:05.123456', 'imposed_hearing_date persists the supplied timestamp');
SELECT is((SELECT last_hearing_date FROM public.respondent_accounts WHERE respondent_account_id = (SELECT id FROM cv_subject)),
    TIMESTAMP '2026-01-02 03:04:05.123456', 'last_hearing_date persists the supplied timestamp');
SELECT is((SELECT completed_date FROM public.respondent_accounts WHERE respondent_account_id = (SELECT id FROM cv_subject)),
    TIMESTAMP '2026-01-02 03:04:05.123456', 'completed_date persists the supplied timestamp');
SELECT is((SELECT last_movement_date FROM public.respondent_accounts WHERE respondent_account_id = (SELECT id FROM cv_subject)),
    TIMESTAMP '2026-01-02 03:04:05.123456', 'last_movement_date persists the supplied timestamp');
SELECT is((SELECT date_arrears_last_updated FROM public.respondent_accounts WHERE respondent_account_id = (SELECT id FROM cv_subject)),
    TIMESTAMP '2026-01-02 03:04:05.123456', 'date_arrears_last_updated persists the supplied timestamp');
SELECT is((SELECT last_enforcement_date FROM public.respondent_accounts WHERE respondent_account_id = (SELECT id FROM cv_subject)),
    TIMESTAMP '2026-01-02 03:04:05.123456', 'last_enforcement_date persists the supplied timestamp');

-- -----------------------------------------------------------------------------
-- Scenario: Native physical types reject invalid input.
-- Setup: Update a valid account with malformed or overflowing values.
-- Expected: PostgreSQL returns exact native SQLSTATEs; no custom validation is implied.
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET account_balance = 'invalid'
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '22P02', NULL, 'account_balance rejects invalid native input');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET allow_cheques = 'invalid'
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '22P02', NULL, 'allow_cheques rejects invalid native input');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET interest_flag = 'invalid'
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '22P02', NULL, 'interest_flag rejects invalid native input');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET cheque_clearance_period = 32768
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '22003', NULL, 'cheque_clearance_period rejects invalid native input');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET credit_trans_clearance_period = 32768
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '22003', NULL, 'credit_trans_clearance_period rejects invalid native input');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET business_unit_id = 32768
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '22003', NULL, 'business_unit_id rejects invalid native input');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET application_id = 32768
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '22003', NULL, 'application_id rejects invalid native input');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET version_number = '9223372036854775808'
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '22003', NULL, 'version_number rejects invalid native input');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET last_hearing_court_id = 'invalid'
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '22P02', NULL, 'last_hearing_court_id rejects invalid native input');
SELECT throws_ok($sql$UPDATE public.respondent_accounts SET last_movement_date = '2026-13-01'
 WHERE respondent_account_id = (SELECT id FROM cv_subject)$sql$, '22008', NULL, 'last_movement_date rejects invalid native input');

SELECT * FROM finish();
ROLLBACK;
