-- PO-10639: V1_25__create_creditor_accounts_table.sql
-- DB-04 contract: columns, comments, owned enum/sequence, defaults, keys and indexes;
-- required/nullable fields, boundaries, generated IDs and native integrity failures.
-- DB-01 fresh path: applicable. This is initial-schema delivery before account use.
-- Existing-state validation: Not run - user-approved initial-schema scope exception.
-- No Country/allocator FK or account-type-to-identity CHECK; banking/version fields stay nullable.
\set ON_ERROR_STOP on
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SET LOCAL search_path = public, pg_temp;
SET LOCAL TIME ZONE 'UTC';
SELECT plan(75);
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
CREATE TEMP TABLE cv_party AS WITH inserted AS (
    INSERT INTO public.parties(address_line_1, restrict_personal_information, country_id)
    SELECT 'Synthetic Address', false, country_id FROM cv_reference RETURNING party_id
) SELECT party_id FROM inserted;
CREATE TEMP TABLE cv_major AS WITH inserted AS (
    INSERT INTO public.major_creditors(business_unit_id, major_creditor_code, name,
        address_line_1, country_id, active, central_authority)
    SELECT 32061, 'CVMC', 'Synthetic Major Creditor', 'Synthetic Address', country_id, true, false
    FROM cv_reference RETURNING major_creditor_id
) SELECT major_creditor_id FROM inserted;

-- -----------------------------------------------------------------------------
-- Scenario: The delivered schema matches the promoted TDIA.
-- Setup: Read the PostgreSQL catalogues against independent literal expectations.
-- Expected: Exact columns, comments, keys, indexes, enum labels and owned sequence; no extra rules.
SELECT has_table('public', 'creditor_accounts', 'creditor_accounts exists');
SELECT is((SELECT jsonb_agg(jsonb_build_array(attname::text,
        format_type(atttypid, atttypmod), attnotnull,
        col_description(attrelid, attnum)) ORDER BY attnum)
    FROM pg_attribute WHERE attrelid = 'public.creditor_accounts'::regclass
      AND attnum > 0 AND NOT attisdropped),
    '[
        ["creditor_account_id","bigint",true,"Unique identifier of the Creditor Account"],
        ["business_unit_id","smallint",true,"Identifier of the related Business Unit"],
        ["account_number","character varying(20)",true,"Account number unique within the Business Unit"],
        ["creditor_account_type","t_creditor_account_type_enum",true,"MN Minor Creditor, MJ Major Creditor, or CF Central Fund type"],
        ["major_creditor_id","bigint",false,"Identifier of the related Major Creditor"],
        ["minor_creditor_party_id","bigint",false,"Identifier of the person or organisation owning a Minor Creditor account"],
        ["from_suspense","boolean",true,"Whether the creditor was created from a suspense transaction"],
        ["hold_payout","boolean",true,"Whether payout of received monies is held"],
        ["pay_by_bacs","boolean",true,"Whether the creditor is paid by BACS rather than cheque"],
        ["bank_sort_code","character varying(6)",false,"Bank sort code"],
        ["bank_account_number","character varying(10)",false,"Bank account number"],
        ["bank_account_name","character varying(18)",false,"Bank account name"],
        ["bank_account_reference","character varying(18)",false,"Bank account reference"],
        ["third_party_contact_id","bigint",false,"Identifier of the optional third-party contact"],
        ["last_changed_date","timestamp without time zone",false,"Date the account or party was last changed"],
        ["non_uk_bank_detail","json",false,"Structured non-UK bank account details"],
        ["version_number","bigint",false,"Optimistic-locking version of the account"]
    ]'::jsonb,
    'exact ordered columns, physical types, nullability and source comments');
SELECT is((SELECT jsonb_agg(jsonb_build_array(conname::text, contype::text,
        ARRAY(SELECT a.attname::text FROM unnest(c.conkey) WITH ORDINALITY k(attnum, ord)
              JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = k.attnum ORDER BY k.ord),
        condeferrable, condeferred, convalidated) ORDER BY conname::text COLLATE "C")
    FROM pg_constraint c WHERE conrelid = 'public.creditor_accounts'::regclass
      AND contype IN ('p', 'f', 'u', 'c')),
    '[
        ["ca_business_unit_id_account_number_uk","u",["business_unit_id","account_number"],false,false,true],
        ["ca_business_unit_id_fk","f",["business_unit_id"],false,false,true],
        ["ca_major_creditor_id_fk","f",["major_creditor_id"],false,false,true],
        ["ca_minor_creditor_party_id_fk","f",["minor_creditor_party_id"],false,false,true],
        ["ca_third_party_contact_id_fk","f",["third_party_contact_id"],false,false,true],
        ["creditor_accounts_pk","p",["creditor_account_id"],false,false,true]
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
    WHERE c.conrelid = 'public.creditor_accounts'::regclass AND c.contype = 'f'),
    '[
        ["ca_business_unit_id_fk","public","business_units",["business_unit_id"],"a","a","s"],
        ["ca_major_creditor_id_fk","public","major_creditors",["major_creditor_id"],"a","a","s"],
        ["ca_minor_creditor_party_id_fk","public","parties",["party_id"],"a","a","s"],
        ["ca_third_party_contact_id_fk","public","third_party_contact",["third_party_contact_id"],"a","a","s"]
    ]'::jsonb,
    'exact FK endpoints and keys with NO ACTION update/delete and SIMPLE matching');
SELECT is((SELECT jsonb_agg(jsonb_build_array(r.relname::text, am.amname::text,
        i.indisunique, i.indisprimary, i.indisvalid, i.indisready, i.indnkeyatts, i.indnatts,
        ARRAY(SELECT pg_get_indexdef(i.indexrelid, k, true)
              FROM generate_series(1, i.indnkeyatts) k),
        i.indpred IS NULL, i.indexprs IS NULL, i.indnullsnotdistinct)
        ORDER BY r.relname::text COLLATE "C")
    FROM pg_index i JOIN pg_class r ON r.oid = i.indexrelid
    JOIN pg_am am ON am.oid = r.relam WHERE i.indrelid = 'public.creditor_accounts'::regclass),
    '[
        ["ca_business_unit_id_account_number_uk","btree",true,false,true,true,2,2,["business_unit_id","account_number"],true,true,false],
        ["creditor_accounts_major_creditor_id_idx","btree",false,false,true,true,1,1,["major_creditor_id"],true,true,false],
        ["creditor_accounts_minor_creditor_party_id_idx","btree",false,false,true,true,1,1,["minor_creditor_party_id"],true,true,false],
        ["creditor_accounts_pk","btree",true,true,true,true,1,1,["creditor_account_id"],true,true,false],
        ["creditor_accounts_third_party_contact_id_idx","btree",false,false,true,true,1,1,["third_party_contact_id"],true,true,false]
    ]'::jsonb,
    'exact indexes, ordered keys, uniqueness and valid ready btree properties');
SELECT is(pg_get_serial_sequence('public.creditor_accounts', 'creditor_account_id'),
    'public.creditor_account_id_seq', 'sequence is owned by the identifier column');
SELECT is((SELECT jsonb_build_array(seqtypid::regtype::text, seqstart, seqmin,
        seqmax, seqincrement, seqcache, seqcycle)
    FROM pg_sequence WHERE seqrelid = 'public.creditor_account_id_seq'::regclass),
    '["bigint",1,1,9223372036854775807,1,1,false]'::jsonb,
    'BIGINT sequence starts at one with increment/cache one and no cycle');
SELECT is((SELECT jsonb_agg(jsonb_build_array(a.attname::text,
        pg_get_expr(d.adbin, d.adrelid)) ORDER BY a.attnum)
    FROM pg_attrdef d JOIN pg_attribute a ON a.attrelid = d.adrelid AND a.attnum = d.adnum
    WHERE d.adrelid = 'public.creditor_accounts'::regclass),
    '[
        ["creditor_account_id","nextval(''creditor_account_id_seq''::regclass)"]
    ]'::jsonb,
    'only the identifier has a nextval default; other values are supplied explicitly');
SELECT is((SELECT count(*) FROM pg_trigger
    WHERE tgrelid = 'public.creditor_accounts'::regclass AND NOT tgisinternal),
    0::bigint, 'no user trigger introduces extra behaviour');
SELECT is((SELECT jsonb_agg(enumlabel::text ORDER BY enumsortorder)
    FROM pg_enum WHERE enumtypid = 'public.t_creditor_account_type_enum'::regtype),
    '["MN","MJ","CF"]'::jsonb, 't_creditor_account_type_enum exact labels and order');

-- -----------------------------------------------------------------------------
-- Scenario: All three creditor types create accounts without type/identity coupling.
-- Setup: Insert MN, MJ and CF accounts with optional identity fields omitted.
-- Expected: Each insert succeeds and uses its owned generated identifier.
SELECT lives_ok($sql$WITH inserted AS (INSERT INTO public.creditor_accounts
 (business_unit_id, account_number, creditor_account_type, from_suspense, hold_payout, pay_by_bacs)
 VALUES (32061, 'CV-CREDITOR-MN', 'MN', false, false, false) RETURNING creditor_account_id)
 INSERT INTO cv_subject SELECT creditor_account_id FROM inserted$sql$, 'MN creditor account succeeds without mandatory identity pairing');
SELECT lives_ok($sql$WITH inserted AS (INSERT INTO public.creditor_accounts
 (business_unit_id, account_number, creditor_account_type, from_suspense, hold_payout, pay_by_bacs)
 VALUES (32061, 'CV-CREDITOR-MJ', 'MJ', false, false, false) RETURNING creditor_account_id)
 INSERT INTO cv_second SELECT creditor_account_id FROM inserted$sql$, 'MJ creditor account succeeds without mandatory identity pairing');
CREATE TEMP TABLE cv_cf (id bigint PRIMARY KEY);
SELECT lives_ok($sql$WITH inserted AS (INSERT INTO public.creditor_accounts
 (business_unit_id, account_number, creditor_account_type, from_suspense, hold_payout, pay_by_bacs)
 VALUES (32061, 'CV-CREDITOR-CF', 'CF', false, false, false) RETURNING creditor_account_id)
 INSERT INTO cv_cf SELECT creditor_account_id FROM inserted$sql$, 'CF creditor account succeeds without mandatory identity pairing');
SELECT is((SELECT count(DISTINCT id) FROM (SELECT id FROM cv_subject UNION ALL
    SELECT id FROM cv_second UNION ALL SELECT id FROM cv_cf) ids WHERE id IS NOT NULL),
    3::bigint, 'three generated creditor identifiers are non-null and distinct');

-- -----------------------------------------------------------------------------
-- Scenario: Each column preserves its declared NULL contract.
-- Setup: Update the captured minimal valid row one column at a time.
-- Expected: Required columns reject NULL with 23502; nullable columns accept NULL.
SELECT throws_ok($sql$UPDATE public.creditor_accounts SET creditor_account_id = NULL
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, '23502', NULL, 'creditor_account_id rejects NULL');
SELECT throws_ok($sql$UPDATE public.creditor_accounts SET business_unit_id = NULL
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, '23502', NULL, 'business_unit_id rejects NULL');
SELECT throws_ok($sql$UPDATE public.creditor_accounts SET account_number = NULL
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, '23502', NULL, 'account_number rejects NULL');
SELECT throws_ok($sql$UPDATE public.creditor_accounts SET creditor_account_type = NULL
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, '23502', NULL, 'creditor_account_type rejects NULL');
SELECT lives_ok($sql$UPDATE public.creditor_accounts SET major_creditor_id = NULL
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, 'major_creditor_id accepts NULL');
SELECT lives_ok($sql$UPDATE public.creditor_accounts SET minor_creditor_party_id = NULL
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, 'minor_creditor_party_id accepts NULL');
SELECT throws_ok($sql$UPDATE public.creditor_accounts SET from_suspense = NULL
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, '23502', NULL, 'from_suspense rejects NULL');
SELECT throws_ok($sql$UPDATE public.creditor_accounts SET hold_payout = NULL
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, '23502', NULL, 'hold_payout rejects NULL');
SELECT throws_ok($sql$UPDATE public.creditor_accounts SET pay_by_bacs = NULL
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, '23502', NULL, 'pay_by_bacs rejects NULL');
SELECT lives_ok($sql$UPDATE public.creditor_accounts SET bank_sort_code = NULL
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, 'bank_sort_code accepts NULL');
SELECT lives_ok($sql$UPDATE public.creditor_accounts SET bank_account_number = NULL
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, 'bank_account_number accepts NULL');
SELECT lives_ok($sql$UPDATE public.creditor_accounts SET bank_account_name = NULL
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, 'bank_account_name accepts NULL');
SELECT lives_ok($sql$UPDATE public.creditor_accounts SET bank_account_reference = NULL
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, 'bank_account_reference accepts NULL');
SELECT lives_ok($sql$UPDATE public.creditor_accounts SET third_party_contact_id = NULL
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, 'third_party_contact_id accepts NULL');
SELECT lives_ok($sql$UPDATE public.creditor_accounts SET last_changed_date = NULL
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, 'last_changed_date accepts NULL');
SELECT lives_ok($sql$UPDATE public.creditor_accounts SET non_uk_bank_detail = NULL
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, 'non_uk_bank_detail accepts NULL');
SELECT lives_ok($sql$UPDATE public.creditor_accounts SET version_number = NULL
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, 'version_number accepts NULL');

-- -----------------------------------------------------------------------------
-- Scenario: account_number accepts its exact length and rejects overflow.
-- Setup: Use the valid subject and isolate the VARCHAR boundary.
-- Expected: 20 characters succeed; 21 characters fail with 22001.
SELECT lives_ok($sql$UPDATE public.creditor_accounts SET account_number = repeat('x', 20)
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, 'account_number accepts 20 characters');
SELECT throws_ok($sql$UPDATE public.creditor_accounts SET account_number = repeat('x', 21)
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, '22001', NULL, 'account_number rejects 21 characters');

-- -----------------------------------------------------------------------------
-- Scenario: bank_sort_code accepts its exact length and rejects overflow.
-- Setup: Use the valid subject and isolate the VARCHAR boundary.
-- Expected: 6 characters succeed; 7 characters fail with 22001.
SELECT lives_ok($sql$UPDATE public.creditor_accounts SET bank_sort_code = repeat('x', 6)
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, 'bank_sort_code accepts 6 characters');
SELECT throws_ok($sql$UPDATE public.creditor_accounts SET bank_sort_code = repeat('x', 7)
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, '22001', NULL, 'bank_sort_code rejects 7 characters');

-- -----------------------------------------------------------------------------
-- Scenario: bank_account_number accepts its exact length and rejects overflow.
-- Setup: Use the valid subject and isolate the VARCHAR boundary.
-- Expected: 10 characters succeed; 11 characters fail with 22001.
SELECT lives_ok($sql$UPDATE public.creditor_accounts SET bank_account_number = repeat('x', 10)
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, 'bank_account_number accepts 10 characters');
SELECT throws_ok($sql$UPDATE public.creditor_accounts SET bank_account_number = repeat('x', 11)
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, '22001', NULL, 'bank_account_number rejects 11 characters');

-- -----------------------------------------------------------------------------
-- Scenario: bank_account_name accepts its exact length and rejects overflow.
-- Setup: Use the valid subject and isolate the VARCHAR boundary.
-- Expected: 18 characters succeed; 19 characters fail with 22001.
SELECT lives_ok($sql$UPDATE public.creditor_accounts SET bank_account_name = repeat('x', 18)
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, 'bank_account_name accepts 18 characters');
SELECT throws_ok($sql$UPDATE public.creditor_accounts SET bank_account_name = repeat('x', 19)
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, '22001', NULL, 'bank_account_name rejects 19 characters');

-- -----------------------------------------------------------------------------
-- Scenario: bank_account_reference accepts its exact length and rejects overflow.
-- Setup: Use the valid subject and isolate the VARCHAR boundary.
-- Expected: 18 characters succeed; 19 characters fail with 22001.
SELECT lives_ok($sql$UPDATE public.creditor_accounts SET bank_account_reference = repeat('x', 18)
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, 'bank_account_reference accepts 18 characters');
SELECT throws_ok($sql$UPDATE public.creditor_accounts SET bank_account_reference = repeat('x', 19)
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, '22001', NULL, 'bank_account_reference rejects 19 characters');
SELECT lives_ok($sql$UPDATE public.creditor_accounts SET account_number = 'CV-CREDITOR-MN'
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, 'restore creditor account identity after length boundary');

-- -----------------------------------------------------------------------------
-- Scenario: creditor_account_type accepts only its controlled values.
-- Setup: Update the subject using every literal label, then an unsupported label.
-- Expected: Each supported value succeeds; the unsupported value fails with 22P02.
SELECT lives_ok($sql$UPDATE public.creditor_accounts SET creditor_account_type = 'MN'
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, 'creditor_account_type accepts MN');
SELECT lives_ok($sql$UPDATE public.creditor_accounts SET creditor_account_type = 'MJ'
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, 'creditor_account_type accepts MJ');
SELECT lives_ok($sql$UPDATE public.creditor_accounts SET creditor_account_type = 'CF'
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, 'creditor_account_type accepts CF');
SELECT throws_ok($sql$UPDATE public.creditor_accounts SET creditor_account_type = 'Unsupported'
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, '22P02', NULL, 'creditor_account_type rejects unsupported value');

-- -----------------------------------------------------------------------------
-- Scenario: business_unit_id enforces the declared parent relationship.
-- Setup: Use a captured synthetic parent and prove the missing key is absent.
-- Expected: Valid reference succeeds; missing reference and deletion of the referenced parent fail with 23503.
SELECT ok(NOT EXISTS(SELECT 1 FROM public.business_units WHERE business_unit_id = -32061),
    'business_unit_id missing fixture key is absent');
SELECT lives_ok($sql$UPDATE public.creditor_accounts SET business_unit_id = 32062
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, 'business_unit_id accepts a valid parent');
SELECT throws_ok($sql$UPDATE public.creditor_accounts SET business_unit_id = -32061
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, '23503', NULL, 'business_unit_id rejects a missing parent');
SELECT throws_ok($sql$DELETE FROM public.business_units WHERE business_unit_id = 32062$sql$, '23503', NULL, 'business_unit_id prevents deletion of the referenced synthetic parent');

-- -----------------------------------------------------------------------------
-- Scenario: major_creditor_id enforces the declared parent relationship.
-- Setup: Use a captured synthetic parent and prove the missing key is absent.
-- Expected: Valid reference succeeds; missing reference and deletion of the referenced parent fail with 23503.
SELECT ok(NOT EXISTS(SELECT 1 FROM public.major_creditors WHERE major_creditor_id = -990061),
    'major_creditor_id missing fixture key is absent');
SELECT lives_ok($sql$UPDATE public.creditor_accounts SET major_creditor_id = (SELECT major_creditor_id FROM cv_major)
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, 'major_creditor_id accepts a valid parent');
SELECT throws_ok($sql$UPDATE public.creditor_accounts SET major_creditor_id = -990061
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, '23503', NULL, 'major_creditor_id rejects a missing parent');
SELECT throws_ok($sql$DELETE FROM public.major_creditors WHERE major_creditor_id = (SELECT major_creditor_id FROM cv_major)$sql$, '23503', NULL, 'major_creditor_id prevents deletion of the referenced synthetic parent');

-- -----------------------------------------------------------------------------
-- Scenario: minor_creditor_party_id enforces the declared parent relationship.
-- Setup: Use a captured synthetic parent and prove the missing key is absent.
-- Expected: Valid reference succeeds; missing reference and deletion of the referenced parent fail with 23503.
SELECT ok(NOT EXISTS(SELECT 1 FROM public.parties WHERE party_id = -990061),
    'minor_creditor_party_id missing fixture key is absent');
SELECT lives_ok($sql$UPDATE public.creditor_accounts SET minor_creditor_party_id = (SELECT party_id FROM cv_party)
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, 'minor_creditor_party_id accepts a valid parent');
SELECT throws_ok($sql$UPDATE public.creditor_accounts SET minor_creditor_party_id = -990061
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, '23503', NULL, 'minor_creditor_party_id rejects a missing parent');
SELECT throws_ok($sql$DELETE FROM public.parties WHERE party_id = (SELECT party_id FROM cv_party)$sql$, '23503', NULL, 'minor_creditor_party_id prevents deletion of the referenced synthetic parent');

-- -----------------------------------------------------------------------------
-- Scenario: third_party_contact_id enforces the declared parent relationship.
-- Setup: Use a captured synthetic parent and prove the missing key is absent.
-- Expected: Valid reference succeeds; missing reference and deletion of the referenced parent fail with 23503.
SELECT ok(NOT EXISTS(SELECT 1 FROM public.third_party_contact WHERE third_party_contact_id = -990061),
    'third_party_contact_id missing fixture key is absent');
SELECT lives_ok($sql$UPDATE public.creditor_accounts SET third_party_contact_id = (SELECT third_party_contact_id FROM cv_contact)
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, 'third_party_contact_id accepts a valid parent');
SELECT throws_ok($sql$UPDATE public.creditor_accounts SET third_party_contact_id = -990061
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, '23503', NULL, 'third_party_contact_id rejects a missing parent');
SELECT throws_ok($sql$DELETE FROM public.third_party_contact WHERE third_party_contact_id = (SELECT third_party_contact_id FROM cv_contact)$sql$, '23503', NULL, 'third_party_contact_id prevents deletion of the referenced synthetic parent');
SELECT lives_ok($sql$UPDATE public.creditor_accounts SET business_unit_id = 32061
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, 'restore creditor owning Business Unit');

-- -----------------------------------------------------------------------------
-- Scenario: Creditor identities follow only the declared primary/scoped unique keys.
-- Setup: Reuse subject IDs/numbers and then move the second account to another unit.
-- Expected: Same IDs/pairs fail 23505; the same number in another unit succeeds.
SELECT throws_ok($sql$UPDATE public.creditor_accounts SET creditor_account_id = (SELECT id FROM cv_subject)
 WHERE creditor_account_id = (SELECT id FROM cv_second)$sql$, '23505', NULL, 'duplicate creditor primary key rejected');
SELECT throws_ok($sql$UPDATE public.creditor_accounts SET account_number = 'CV-CREDITOR-MN'
 WHERE creditor_account_id = (SELECT id FROM cv_second)$sql$, '23505', NULL, 'duplicate creditor Business Unit/account number rejected');
SELECT lives_ok($sql$UPDATE public.creditor_accounts SET business_unit_id = 32062, account_number = 'CV-CREDITOR-MN'
 WHERE creditor_account_id = (SELECT id FROM cv_second)$sql$, 'same creditor number succeeds in another Business Unit');

-- -----------------------------------------------------------------------------
-- Scenario: Optional bank details and identity fields remain independent.
-- Setup: The subject already has both Major Creditor and Minor Party references; supply JSON, date and flags.
-- Expected: No mutual-exclusion/type pairing rule; structured JSON and UTC-convention values persist.
SELECT lives_ok($sql$UPDATE public.creditor_accounts SET creditor_account_type = 'CF', from_suspense = true, hold_payout = true, pay_by_bacs = true, non_uk_bank_detail = '{"bank":"Synthetic bank","routing":["x",null]}', version_number = -1, last_changed_date = TIMESTAMP '2026-01-02 03:04:05.123456'
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, 'both identity references and nullable banking/version fields accepted for CF');
SELECT is((SELECT non_uk_bank_detail::jsonb FROM public.creditor_accounts
    WHERE creditor_account_id = (SELECT id FROM cv_subject)),
    '{"bank":"Synthetic bank","routing":["x",null]}'::jsonb, 'structured non-UK bank JSON preserved');
SELECT is((SELECT last_changed_date FROM public.creditor_accounts
    WHERE creditor_account_id = (SELECT id FROM cv_subject)),
    TIMESTAMP '2026-01-02 03:04:05.123456', 'last_changed_date preserves supplied UTC-convention TIMESTAMP');

-- -----------------------------------------------------------------------------
-- Scenario: Native creditor types reject malformed and overflowing input.
-- Setup: Update the valid captured row one field at a time.
-- Expected: Physical types return 22P02 or 22003 without custom business validation.
SELECT throws_ok($sql$UPDATE public.creditor_accounts SET non_uk_bank_detail = '{invalid}'
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, '22P02', NULL, 'non_uk_bank_detail rejects invalid native input');
SELECT throws_ok($sql$UPDATE public.creditor_accounts SET from_suspense = 'invalid'
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, '22P02', NULL, 'from_suspense rejects invalid native input');
SELECT throws_ok($sql$UPDATE public.creditor_accounts SET hold_payout = 'invalid'
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, '22P02', NULL, 'hold_payout rejects invalid native input');
SELECT throws_ok($sql$UPDATE public.creditor_accounts SET pay_by_bacs = 'invalid'
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, '22P02', NULL, 'pay_by_bacs rejects invalid native input');
SELECT throws_ok($sql$UPDATE public.creditor_accounts SET business_unit_id = 32768
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, '22003', NULL, 'business_unit_id rejects invalid native input');
SELECT throws_ok($sql$UPDATE public.creditor_accounts SET version_number = '9223372036854775808'
 WHERE creditor_account_id = (SELECT id FROM cv_subject)$sql$, '22003', NULL, 'version_number rejects invalid native input');

SELECT * FROM finish();
ROLLBACK;
