\set ON_ERROR_STOP on
-- PO-10633: catalogue and behavioural contract for the approved initial schema.
-- Applicability: fresh DB-01 path. Existing-state validation is not run under
-- the user-approved initial-schema scope exception; this is not upgrade evidence.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SET LOCAL search_path = public, pg_temp;
SET LOCAL TIME ZONE 'UTC';
SELECT plan(33);
DO $fixture$
BEGIN
    IF EXISTS (SELECT 1 FROM public.business_units
               WHERE business_unit_id IN (32061, 32062)
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
CREATE TEMP TABLE cv_generated (id bigint);

-- ---------------------------------------------------------------------------
-- Scenario: The table preserves its promoted physical contract.
-- Setup:    Read the PostgreSQL catalogue after the full fresh migration chain.
-- Expected: Columns, comments, constraints and indexes exactly match TDIA.
-- ---------------------------------------------------------------------------
SELECT has_table('public', 'account_number_index', 'public.account_number_index exists');
SELECT results_eq(
    $actual$SELECT attname::text COLLATE "C", format_type(atttypid, atttypmod) COLLATE "C", attnotnull
    FROM pg_attribute WHERE attrelid = 'public.account_number_index'::regclass
      AND attnum > 0 AND NOT attisdropped ORDER BY attnum$actual$,
    $expected$VALUES
        ('account_number_index_id' COLLATE "C", 'bigint' COLLATE "C", true),
        ('business_unit_id' COLLATE "C", 'smallint' COLLATE "C", true),
        ('account_number' COLLATE "C", 'character varying(20)' COLLATE "C", true),
        ('associated_record_type' COLLATE "C", 't_associated_record_type_enum' COLLATE "C", false)$expected$,
    'exact ordered columns, types and nullability'
);
SELECT results_eq(
    $actual$SELECT attname::text COLLATE "C", col_description(attrelid, attnum) COLLATE "C"
    FROM pg_attribute WHERE attrelid = 'public.account_number_index'::regclass
      AND attnum > 0 AND NOT attisdropped ORDER BY attnum$actual$,
    $expected$VALUES
        ('account_number_index_id' COLLATE "C", 'Unique identifier of the account-number allocation' COLLATE "C"),
        ('business_unit_id' COLLATE "C", 'Identifier of the related Business Unit' COLLATE "C"),
        ('account_number' COLLATE "C", 'Account number unique within the Business Unit' COLLATE "C"),
        ('associated_record_type' COLLATE "C", 'Type of account record receiving the allocated number' COLLATE "C")$expected$,
    'every column comment matches authoritative wording'
);
SELECT results_eq(
    $actual$SELECT c.conname::text COLLATE "C", c.contype::text COLLATE "C",
        ARRAY(SELECT a.attname::text COLLATE "C"
              FROM unnest(c.conkey) WITH ORDINALITY AS k(attnum, position)
              JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = k.attnum
              ORDER BY k.position) COLLATE "C"
    FROM pg_constraint c WHERE c.conrelid = 'public.account_number_index'::regclass
      AND c.contype IN ('p', 'f', 'u', 'c') ORDER BY c.conname$actual$,
    $expected$VALUES
        ('account_number_index_pk' COLLATE "C", 'p' COLLATE "C", ARRAY['account_number_index_id' COLLATE "C"]::text[] COLLATE "C"),
        ('ani_business_unit_id_account_number_uk' COLLATE "C", 'u' COLLATE "C", ARRAY['business_unit_id' COLLATE "C", 'account_number' COLLATE "C"]::text[] COLLATE "C"),
        ('ani_business_unit_id_fk' COLLATE "C", 'f' COLLATE "C", ARRAY['business_unit_id' COLLATE "C"]::text[] COLLATE "C")$expected$,
    'exact constraint names, kinds and ordered keys; no unexpected CHECK'
);
SELECT results_eq(
    $actual$SELECT c.conname::text COLLATE "C", n.nspname::text COLLATE "C", r.relname::text COLLATE "C",
        ARRAY(SELECT a.attname::text COLLATE "C"
              FROM unnest(c.confkey) WITH ORDINALITY AS k(attnum, position)
              JOIN pg_attribute a ON a.attrelid = c.confrelid AND a.attnum = k.attnum
              ORDER BY k.position) COLLATE "C",
        c.confupdtype::text COLLATE "C", c.confdeltype::text COLLATE "C", c.confmatchtype::text COLLATE "C",
        c.condeferrable, c.condeferred, c.convalidated
    FROM pg_constraint c JOIN pg_class r ON r.oid = c.confrelid
    JOIN pg_namespace n ON n.oid = r.relnamespace
    WHERE c.conrelid = 'public.account_number_index'::regclass AND c.contype = 'f'
    ORDER BY c.conname$actual$,
    $expected$VALUES ('ani_business_unit_id_fk' COLLATE "C", 'public' COLLATE "C", 'business_units' COLLATE "C", ARRAY['business_unit_id' COLLATE "C"]::text[] COLLATE "C",
        'a' COLLATE "C", 'a' COLLATE "C", 's' COLLATE "C", false, false, true)$expected$,
    'FK endpoint and key are validated, immediate NO ACTION'
);
SELECT results_eq(
    $actual$SELECT r.relname::text COLLATE "C",
        ARRAY(SELECT a.attname::text COLLATE "C"
              FROM unnest(i.indkey) WITH ORDINALITY AS k(attnum, position)
              JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = k.attnum
              ORDER BY k.position) COLLATE "C",
        am.amname::text COLLATE "C", i.indisunique, i.indisprimary, i.indisvalid, i.indisready,
        i.indnkeyatts::integer, i.indnatts::integer,
        i.indpred IS NULL, i.indexprs IS NULL
    FROM pg_index i JOIN pg_class r ON r.oid = i.indexrelid
    JOIN pg_am am ON am.oid = r.relam
    WHERE i.indrelid = 'public.account_number_index'::regclass ORDER BY r.relname$actual$,
    $expected$VALUES
        ('account_number_index_pk' COLLATE "C", ARRAY['account_number_index_id' COLLATE "C"]::text[] COLLATE "C", 'btree' COLLATE "C", true, true,
         true, true, 1, 1, true, true),
        ('ani_business_unit_id_account_number_uk' COLLATE "C", ARRAY['business_unit_id' COLLATE "C", 'account_number' COLLATE "C"]::text[] COLLATE "C", 'btree' COLLATE "C", true, false,
         true, true, 2, 2, true, true)$expected$,
    'exact index inventory, ordered keys, uniqueness and valid ready btree state'
);

-- ---------------------------------------------------------------------------
-- Scenario: Only the identifier is generated by an owned sequence.
-- Setup:    Inspect the default expression, identity marker and sequence metadata.
-- Expected: The owned BIGINT sequence uses start 1, increment 1, cache 1 and no cycle.
-- ---------------------------------------------------------------------------
SELECT is(pg_get_serial_sequence('public.account_number_index', 'account_number_index_id'),
    'public.account_number_index_id_seq', 'identifier sequence ownership');
SELECT is(
    (SELECT format_type(seqtypid, NULL) || ':' || seqstart || ':' || seqincrement
            || ':' || seqcache || ':' || seqcycle
     FROM pg_sequence WHERE seqrelid = 'public.account_number_index_id_seq'::regclass),
    'bigint:1:1:1:false', 'BIGINT sequence start, increment, cache and cycle'
);
SELECT is(
    (SELECT pg_get_expr(d.adbin, d.adrelid)
     FROM pg_attrdef d JOIN pg_attribute a
       ON a.attrelid = d.adrelid AND a.attnum = d.adnum
     WHERE d.adrelid = 'public.account_number_index'::regclass AND a.attname = 'account_number_index_id'),
    'nextval(''account_number_index_id_seq''::regclass)', 'identifier defaults to the owned sequence'
);
SELECT is((SELECT count(*) FROM pg_attrdef WHERE adrelid = 'public.account_number_index'::regclass),
    1::bigint, 'only the identifier has a database default');
SELECT is(
    (SELECT attidentity::text FROM pg_attribute
     WHERE attrelid = 'public.account_number_index'::regclass AND attname = 'account_number_index_id'),
    '', 'identifier is sequence-backed rather than an identity column'
);
SELECT is((SELECT count(*) FROM pg_trigger
           WHERE tgrelid = 'public.account_number_index'::regclass AND NOT tgisinternal),
    0::bigint, 'no user triggers introduce undeclared behaviour');

-- ---------------------------------------------------------------------------
-- Scenario: A minimal allocation uses its valid Business Unit and generated ID.
-- Setup:    Create a row in synthetic Business Unit 32061 and retain its generated ID.
-- Expected: The insert succeeds without an associated record type.
-- ---------------------------------------------------------------------------
SELECT lives_ok(
    $sql$WITH inserted AS (
        INSERT INTO public.account_number_index (business_unit_id, account_number)
        VALUES (32061, 'CV-ALLOCATION') RETURNING account_number_index_id
    ) INSERT INTO cv_subject SELECT account_number_index_id FROM inserted$sql$,
    'minimal valid allocation generates an identifier'
);
INSERT INTO cv_generated SELECT id FROM cv_subject;

-- ---------------------------------------------------------------------------
-- Scenario: All mandatory fields reject NULL and the associated record type is optional.
-- Setup:    Update only one column of the captured valid row in each assertion.
-- Expected: Mandatory NULLs fail with 23502; the optional enum accepts NULL.
-- ---------------------------------------------------------------------------
SELECT throws_ok(
    $sql$UPDATE public.account_number_index SET account_number_index_id = NULL
    WHERE account_number_index_id = (SELECT id FROM cv_subject)$sql$,
    '23502', NULL, 'account_number_index_id rejects NULL'
);
SELECT throws_ok(
    $sql$UPDATE public.account_number_index SET business_unit_id = NULL
    WHERE account_number_index_id = (SELECT id FROM cv_subject)$sql$,
    '23502', NULL, 'business_unit_id rejects NULL'
);
SELECT throws_ok(
    $sql$UPDATE public.account_number_index SET account_number = NULL
    WHERE account_number_index_id = (SELECT id FROM cv_subject)$sql$,
    '23502', NULL, 'account_number rejects NULL'
);
SELECT lives_ok(
    $sql$UPDATE public.account_number_index SET associated_record_type = NULL
    WHERE account_number_index_id = (SELECT id FROM cv_subject)$sql$,
    'associated_record_type accepts NULL'
);

-- ---------------------------------------------------------------------------
-- Scenario: The allocator accepts exactly the four shared record labels.
-- Setup:    Inspect the enum order and assign every permitted label to the captured allocation.
-- Expected: Each label is usable; an unsupported label fails with 22P02.
-- ---------------------------------------------------------------------------
SELECT is(
    (SELECT array_agg(enumlabel::text ORDER BY enumsortorder)
     FROM pg_enum WHERE enumtypid = 'public.t_associated_record_type_enum'::regtype),
    ARRAY['respondent_accounts', 'creditor_accounts', 'creditor_transactions', 'suspense_transactions']::text[],
    'shared enum has the exact labels in order'
);
SELECT lives_ok(
    $sql$UPDATE public.account_number_index
    SET associated_record_type = 'respondent_accounts'::public.t_associated_record_type_enum
    WHERE account_number_index_id = (SELECT id FROM cv_subject)$sql$,
    'respondent_accounts is accepted by the allocator'
);
SELECT lives_ok(
    $sql$UPDATE public.account_number_index
    SET associated_record_type = 'creditor_accounts'::public.t_associated_record_type_enum
    WHERE account_number_index_id = (SELECT id FROM cv_subject)$sql$,
    'creditor_accounts is accepted by the allocator'
);
SELECT lives_ok(
    $sql$UPDATE public.account_number_index
    SET associated_record_type = 'creditor_transactions'::public.t_associated_record_type_enum
    WHERE account_number_index_id = (SELECT id FROM cv_subject)$sql$,
    'creditor_transactions is accepted by the allocator'
);
SELECT lives_ok(
    $sql$UPDATE public.account_number_index
    SET associated_record_type = 'suspense_transactions'::public.t_associated_record_type_enum
    WHERE account_number_index_id = (SELECT id FROM cv_subject)$sql$,
    'suspense_transactions is accepted by the allocator'
);
SELECT throws_ok(
    $sql$UPDATE public.account_number_index
    SET associated_record_type = 'unsupported'::public.t_associated_record_type_enum
    WHERE account_number_index_id = (SELECT id FROM cv_subject)$sql$,
    '22P02', NULL, 'unsupported shared record label is rejected'
);

-- ---------------------------------------------------------------------------
-- Scenario: Account-number length is enforced at the declared boundary.
-- Setup:    Update the valid allocation with 20 and then 21 characters.
-- Expected: 20 characters persist; 21 characters fail with 22001.
-- ---------------------------------------------------------------------------
SELECT lives_ok(
    $sql$UPDATE public.account_number_index SET account_number = repeat('x', 20)
    WHERE account_number_index_id = (SELECT id FROM cv_subject)$sql$,
    'account_number accepts 20 characters'
);
SELECT throws_ok(
    $sql$UPDATE public.account_number_index SET account_number = repeat('x', 21)
    WHERE account_number_index_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'account_number rejects 21 characters'
);

-- ---------------------------------------------------------------------------
-- Scenario: Identifier uniqueness and Business Unit-scoped number uniqueness are distinct.
-- Setup:    Use a duplicate ID with a new number, then the existing number with generated IDs.
-- Expected: Duplicate ID and same-unit number fail with 23505; another unit may reuse the number.
-- ---------------------------------------------------------------------------
SELECT throws_ok(
    $sql$INSERT INTO public.account_number_index
        (account_number_index_id, business_unit_id, account_number)
    VALUES ((SELECT id FROM cv_subject), 32061, 'CV-NEW-NUMBER')$sql$,
    '23505', NULL, 'duplicate identifier is rejected'
);
SELECT throws_ok(
    $sql$INSERT INTO public.account_number_index (business_unit_id, account_number)
    VALUES (32061, repeat('x', 20))$sql$,
    '23505', NULL, 'duplicate Business Unit and account number is rejected'
);
SELECT lives_ok(
    $sql$WITH inserted AS (
        INSERT INTO public.account_number_index (business_unit_id, account_number)
        VALUES (32062, repeat('x', 20)) RETURNING account_number_index_id
    ) INSERT INTO cv_generated SELECT account_number_index_id FROM inserted$sql$,
    'same account number is accepted in a second Business Unit'
);
SELECT ok((SELECT bool_and(id IS NOT NULL) FROM cv_generated),
    'captured sequence-generated identifiers are non-null');
SELECT is((SELECT count(DISTINCT id) FROM cv_generated),
    2::bigint, 'separate successful inserts generate distinct identifiers');

-- ---------------------------------------------------------------------------
-- Scenario: Business Unit references are enforced and referenced parents are protected.
-- Setup:    Prove the missing key is absent; attempt an invalid reference and delete synthetic unit 32062.
-- Expected: Both relationship violations fail with native 23503.
-- ---------------------------------------------------------------------------
SELECT is((SELECT count(*) FROM public.business_units WHERE business_unit_id = -32061),
    0::bigint, 'missing Business Unit fixture key is absent');
SELECT throws_ok(
    $sql$UPDATE public.account_number_index SET business_unit_id = -32061
    WHERE account_number_index_id = (SELECT id FROM cv_subject)$sql$,
    '23503', NULL, 'missing Business Unit is rejected'
);
SELECT throws_ok(
    $sql$DELETE FROM public.business_units WHERE business_unit_id = 32062$sql$,
    '23503', NULL, 'referenced synthetic Business Unit cannot be deleted'
);
SELECT * FROM finish();
ROLLBACK;
