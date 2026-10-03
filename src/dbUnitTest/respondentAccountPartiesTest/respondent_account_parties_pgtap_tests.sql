-- PO-10656: V1_26__create_respondent_account_parties_table.sql
-- DB-04 contract: columns, comments, owned enum/sequence, defaults, keys and indexes;
-- required/nullable fields, boundaries, generated IDs and native integrity failures.
-- DB-01 fresh path: applicable. This is initial-schema delivery before account use.
-- Existing-state validation: Not run - user-approved initial-schema scope exception.
-- associated_account_id is deliberately polymorphic; p_insert_respondent_account_parties is out of scope.
\set ON_ERROR_STOP on
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SET LOCAL search_path = public, pg_temp;
SET LOCAL TIME ZONE 'UTC';
SELECT plan(31);
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
    IF NOT EXISTS (SELECT 1 FROM public.maintenance_applications) THEN
        RAISE EXCEPTION 'Required Maintenance Application reference data missing';
    END IF;
END $fixture$;
CREATE TEMP TABLE cv_application AS SELECT min(application_id) AS application_id
    FROM public.maintenance_applications;
CREATE TEMP TABLE cv_respondent AS WITH inserted AS (
 INSERT INTO public.respondent_accounts(business_unit_id, account_number, application_id, account_balance, orders_balance, orders_amount, payment_period, total_arrears, account_status, last_movement_date, date_arrears_last_updated, allow_cheques, cheque_clearance_period, credit_trans_clearance_period, casefile_type, interest_flag, indexation, payment_arrangement, version_number)
 SELECT 32061, 'CV-RESPONDENT', application_id, 0, 0, 0, 'Weekly', 0, 'L', TIMESTAMP '2026-01-01 12:00:00', TIMESTAMP '2026-01-01 12:00:00', true, 10, 0, 'REMO In', false, 'None', 'Court', 1 FROM cv_application RETURNING respondent_account_id
) SELECT respondent_account_id FROM inserted;
CREATE TEMP TABLE cv_central (id bigint PRIMARY KEY);

-- -----------------------------------------------------------------------------
-- Scenario: The delivered schema matches the promoted TDIA.
-- Setup: Read the PostgreSQL catalogues against independent literal expectations.
-- Expected: Exact columns, comments, keys, indexes, enum labels and owned sequence; no extra rules.
SELECT has_table('public', 'respondent_account_parties', 'respondent_account_parties exists');
SELECT is((SELECT jsonb_agg(jsonb_build_array(attname::text,
        format_type(atttypid, atttypmod), attnotnull,
        col_description(attrelid, attnum)) ORDER BY attnum)
    FROM pg_attribute WHERE attrelid = 'public.respondent_account_parties'::regclass
      AND attnum > 0 AND NOT attisdropped),
    '[
        ["respondent_account_party_id","bigint",true,"Unique identifier of the account association"],
        ["respondent_account_id","bigint",true,"Identifier of the Respondent Account"],
        ["associated_account_id","bigint",true,"Identifier of the associated party, creditor account, or Major Creditor according to association type"],
        ["association_type","t_association_type_enum",true,"Respondent, Applicant, or Central Authority association type"]
    ]'::jsonb,
    'exact ordered columns, physical types, nullability and source comments');
SELECT is((SELECT jsonb_agg(jsonb_build_array(conname::text, contype::text,
        ARRAY(SELECT a.attname::text FROM unnest(c.conkey) WITH ORDINALITY k(attnum, ord)
              JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = k.attnum ORDER BY k.ord),
        condeferrable, condeferred, convalidated) ORDER BY conname::text COLLATE "C")
    FROM pg_constraint c WHERE conrelid = 'public.respondent_account_parties'::regclass
      AND contype IN ('p', 'f', 'u', 'c')),
    '[
        ["rap_respondent_account_id_fk","f",["respondent_account_id"],false,false,true],
        ["respondent_account_parties_pk","p",["respondent_account_party_id"],false,false,true]
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
    WHERE c.conrelid = 'public.respondent_account_parties'::regclass AND c.contype = 'f'),
    '[
        ["rap_respondent_account_id_fk","public","respondent_accounts",["respondent_account_id"],"a","a","s"]
    ]'::jsonb,
    'exact FK endpoints and keys with NO ACTION update/delete and SIMPLE matching');
SELECT is((SELECT jsonb_agg(jsonb_build_array(r.relname::text, am.amname::text,
        i.indisunique, i.indisprimary, i.indisvalid, i.indisready, i.indnkeyatts, i.indnatts,
        ARRAY(SELECT pg_get_indexdef(i.indexrelid, k, true)
              FROM generate_series(1, i.indnkeyatts) k),
        i.indpred IS NULL, i.indexprs IS NULL, i.indnullsnotdistinct)
        ORDER BY r.relname::text COLLATE "C")
    FROM pg_index i JOIN pg_class r ON r.oid = i.indexrelid
    JOIN pg_am am ON am.oid = r.relam WHERE i.indrelid = 'public.respondent_account_parties'::regclass),
    '[
        ["respondent_account_parties_pk","btree",true,true,true,true,1,1,["respondent_account_party_id"],true,true,false],
        ["respondent_account_parties_respondent_account_id_idx","btree",false,false,true,true,1,1,["respondent_account_id"],true,true,false]
    ]'::jsonb,
    'exact indexes, ordered keys, uniqueness and valid ready btree properties');
SELECT is(pg_get_serial_sequence('public.respondent_account_parties', 'respondent_account_party_id'),
    'public.respondent_account_party_id_seq', 'sequence is owned by the identifier column');
SELECT is((SELECT jsonb_build_array(seqtypid::regtype::text, seqstart, seqmin,
        seqmax, seqincrement, seqcache, seqcycle)
    FROM pg_sequence WHERE seqrelid = 'public.respondent_account_party_id_seq'::regclass),
    '["bigint",1,1,9223372036854775807,1,1,false]'::jsonb,
    'BIGINT sequence starts at one with increment/cache one and no cycle');
SELECT is((SELECT jsonb_agg(jsonb_build_array(a.attname::text,
        pg_get_expr(d.adbin, d.adrelid)) ORDER BY a.attnum)
    FROM pg_attrdef d JOIN pg_attribute a ON a.attrelid = d.adrelid AND a.attnum = d.adnum
    WHERE d.adrelid = 'public.respondent_account_parties'::regclass),
    '[
        ["respondent_account_party_id","nextval(''respondent_account_party_id_seq''::regclass)"]
    ]'::jsonb,
    'only the identifier has a nextval default; other values are supplied explicitly');
SELECT is((SELECT count(*) FROM pg_trigger
    WHERE tgrelid = 'public.respondent_account_parties'::regclass AND NOT tgisinternal),
    0::bigint, 'no user trigger introduces extra behaviour');
SELECT is((SELECT jsonb_agg(enumlabel::text ORDER BY enumsortorder)
    FROM pg_enum WHERE enumtypid = 'public.t_association_type_enum'::regtype),
    '["Respondent","Applicant","Central Authority"]'::jsonb, 't_association_type_enum exact labels and order');

-- -----------------------------------------------------------------------------
-- Scenario: Every association label accepts an unconstrained polymorphic target.
-- Setup: Use a synthetic Respondent Account and a negative ID absent from all possible target tables.
-- Expected: Each association inserts; this proves no polymorphic FK while the later helper remains out of scope.
SELECT ok(NOT EXISTS (SELECT 1 FROM public.parties WHERE party_id = -990061)
    AND NOT EXISTS (SELECT 1 FROM public.creditor_accounts WHERE creditor_account_id = -990061)
    AND NOT EXISTS (SELECT 1 FROM public.major_creditors WHERE major_creditor_id = -990061),
    'polymorphic target fixture is absent from every candidate target');
SELECT lives_ok($sql$WITH inserted AS (INSERT INTO public.respondent_account_parties
    (respondent_account_id, associated_account_id, association_type)
    SELECT respondent_account_id, -990061, 'Respondent' FROM cv_respondent
    RETURNING respondent_account_party_id) INSERT INTO cv_subject SELECT respondent_account_party_id FROM inserted$sql$, 'Respondent association accepts absent polymorphic target');
SELECT lives_ok($sql$WITH inserted AS (INSERT INTO public.respondent_account_parties
    (respondent_account_id, associated_account_id, association_type)
    SELECT respondent_account_id, -990061, 'Applicant' FROM cv_respondent
    RETURNING respondent_account_party_id) INSERT INTO cv_second SELECT respondent_account_party_id FROM inserted$sql$, 'Applicant association accepts absent polymorphic target');
SELECT lives_ok($sql$WITH inserted AS (INSERT INTO public.respondent_account_parties
    (respondent_account_id, associated_account_id, association_type)
    SELECT respondent_account_id, -990061, 'Central Authority' FROM cv_respondent
    RETURNING respondent_account_party_id) INSERT INTO cv_central SELECT respondent_account_party_id FROM inserted$sql$, 'Central Authority association accepts absent polymorphic target');
SELECT is((SELECT count(DISTINCT id) FROM (SELECT id FROM cv_subject UNION ALL
    SELECT id FROM cv_second UNION ALL SELECT id FROM cv_central) ids WHERE id IS NOT NULL),
    3::bigint, 'association IDs are generated, non-null and distinct');

-- -----------------------------------------------------------------------------
-- Scenario: Each column preserves its declared NULL contract.
-- Setup: Update the captured minimal valid row one column at a time.
-- Expected: Required columns reject NULL with 23502; nullable columns accept NULL.
SELECT throws_ok($sql$UPDATE public.respondent_account_parties SET respondent_account_party_id = NULL
 WHERE respondent_account_party_id = (SELECT id FROM cv_subject)$sql$, '23502', NULL, 'respondent_account_party_id rejects NULL');
SELECT throws_ok($sql$UPDATE public.respondent_account_parties SET respondent_account_id = NULL
 WHERE respondent_account_party_id = (SELECT id FROM cv_subject)$sql$, '23502', NULL, 'respondent_account_id rejects NULL');
SELECT throws_ok($sql$UPDATE public.respondent_account_parties SET associated_account_id = NULL
 WHERE respondent_account_party_id = (SELECT id FROM cv_subject)$sql$, '23502', NULL, 'associated_account_id rejects NULL');
SELECT throws_ok($sql$UPDATE public.respondent_account_parties SET association_type = NULL
 WHERE respondent_account_party_id = (SELECT id FROM cv_subject)$sql$, '23502', NULL, 'association_type rejects NULL');

-- -----------------------------------------------------------------------------
-- Scenario: association_type accepts only its controlled values.
-- Setup: Update the subject using every literal label, then an unsupported label.
-- Expected: Each supported value succeeds; the unsupported value fails with 22P02.
SELECT lives_ok($sql$UPDATE public.respondent_account_parties SET association_type = 'Respondent'
 WHERE respondent_account_party_id = (SELECT id FROM cv_subject)$sql$, 'association_type accepts Respondent');
SELECT lives_ok($sql$UPDATE public.respondent_account_parties SET association_type = 'Applicant'
 WHERE respondent_account_party_id = (SELECT id FROM cv_subject)$sql$, 'association_type accepts Applicant');
SELECT lives_ok($sql$UPDATE public.respondent_account_parties SET association_type = 'Central Authority'
 WHERE respondent_account_party_id = (SELECT id FROM cv_subject)$sql$, 'association_type accepts Central Authority');
SELECT throws_ok($sql$UPDATE public.respondent_account_parties SET association_type = 'Unsupported'
 WHERE respondent_account_party_id = (SELECT id FROM cv_subject)$sql$, '22P02', NULL, 'association_type rejects unsupported value');

-- -----------------------------------------------------------------------------
-- Scenario: respondent_account_id enforces the declared parent relationship.
-- Setup: Use a captured synthetic parent and prove the missing key is absent.
-- Expected: Valid reference succeeds; missing reference and deletion of the referenced parent fail with 23503.
SELECT ok(NOT EXISTS(SELECT 1 FROM public.respondent_accounts WHERE respondent_account_id = -990061),
    'respondent_account_id missing fixture key is absent');
SELECT lives_ok($sql$UPDATE public.respondent_account_parties SET respondent_account_id = (SELECT respondent_account_id FROM cv_respondent)
 WHERE respondent_account_party_id = (SELECT id FROM cv_subject)$sql$, 'respondent_account_id accepts a valid parent');
SELECT throws_ok($sql$UPDATE public.respondent_account_parties SET respondent_account_id = -990061
 WHERE respondent_account_party_id = (SELECT id FROM cv_subject)$sql$, '23503', NULL, 'respondent_account_id rejects a missing parent');
SELECT throws_ok($sql$DELETE FROM public.respondent_accounts WHERE respondent_account_id = (SELECT respondent_account_id FROM cv_respondent)$sql$, '23503', NULL, 'respondent_account_id prevents deletion of the referenced synthetic parent');

-- -----------------------------------------------------------------------------
-- Scenario: The association table enforces its PK without inventing scoped uniqueness.
-- Setup: Attempt a duplicate ID, then insert a repeated association with a generated ID.
-- Expected: The ID collision fails 23505; the repeated association succeeds.
SELECT throws_ok($sql$UPDATE public.respondent_account_parties SET respondent_account_party_id = (SELECT id FROM cv_subject)
 WHERE respondent_account_party_id = (SELECT id FROM cv_second)$sql$, '23505', NULL, 'duplicate association primary key rejected');
SELECT lives_ok($sql$INSERT INTO public.respondent_account_parties(respondent_account_id, associated_account_id, association_type)
 SELECT respondent_account_id, -990061, 'Central Authority' FROM cv_respondent$sql$, 'no undeclared uniqueness rule on repeated associations');

-- -----------------------------------------------------------------------------
-- Scenario: Association identifiers retain native BIGINT input validation.
-- Setup: Update a valid association with malformed or overflowing identifiers.
-- Expected: Native casts reject malformed input with 22P02 and overflow with 22003.
SELECT throws_ok($sql$UPDATE public.respondent_account_parties SET associated_account_id = 'invalid'
 WHERE respondent_account_party_id = (SELECT id FROM cv_subject)$sql$, '22P02', NULL, 'associated ID rejects malformed BIGINT');
SELECT throws_ok($sql$UPDATE public.respondent_account_parties SET associated_account_id = '9223372036854775808'
 WHERE respondent_account_party_id = (SELECT id FROM cv_subject)$sql$, '22003', NULL, 'associated ID rejects BIGINT overflow');

SELECT * FROM finish();
ROLLBACK;
