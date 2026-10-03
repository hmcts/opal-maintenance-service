\set ON_ERROR_STOP on
-- PO-10634: catalogue and behavioural contract for the approved initial schema.
-- Applicability: fresh DB-01 path. Existing-state validation is not run under
-- the user-approved initial-schema scope exception; this is not upgrade evidence.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SET LOCAL search_path = public, pg_temp;
SET LOCAL TIME ZONE 'UTC';
SELECT plan(36);
DO $fixture$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.countries) THEN
        RAISE EXCEPTION 'Required Country reference data missing';
    END IF;
END
$fixture$;
CREATE TEMP TABLE cv_reference AS
    SELECT (SELECT min(country_id) FROM public.countries) AS country_id;
CREATE TEMP TABLE cv_subject (id bigint PRIMARY KEY);
CREATE TEMP TABLE cv_generated (id bigint);

-- ---------------------------------------------------------------------------
-- Scenario: The table preserves its promoted physical contract.
-- Setup:    Read the PostgreSQL catalogue after the full fresh migration chain.
-- Expected: Columns, comments, constraints and indexes exactly match TDIA.
-- ---------------------------------------------------------------------------
SELECT has_table('public', 'aliases', 'public.aliases exists');
SELECT results_eq(
    $actual$SELECT attname::text COLLATE "C", format_type(atttypid, atttypmod) COLLATE "C", attnotnull
    FROM pg_attribute WHERE attrelid = 'public.aliases'::regclass
      AND attnum > 0 AND NOT attisdropped ORDER BY attnum$actual$,
    $expected$VALUES
        ('alias_id' COLLATE "C", 'bigint' COLLATE "C", true),
        ('party_id' COLLATE "C", 'bigint' COLLATE "C", true),
        ('surname' COLLATE "C", 'character varying(50)' COLLATE "C", true),
        ('forenames' COLLATE "C", 'character varying(50)' COLLATE "C", true),
        ('organisation_name' COLLATE "C", 'character varying(50)' COLLATE "C", false),
        ('sequence_number' COLLATE "C", 'integer' COLLATE "C", true)$expected$,
    'exact ordered columns, types and nullability'
);
SELECT results_eq(
    $actual$SELECT attname::text COLLATE "C", col_description(attrelid, attnum) COLLATE "C"
    FROM pg_attribute WHERE attrelid = 'public.aliases'::regclass
      AND attnum > 0 AND NOT attisdropped ORDER BY attnum$actual$,
    $expected$VALUES
        ('alias_id' COLLATE "C", 'Unique identifier of the alias' COLLATE "C"),
        ('party_id' COLLATE "C", 'Identifier of the party owning the alias' COLLATE "C"),
        ('surname' COLLATE "C", 'Alias surname' COLLATE "C"),
        ('forenames' COLLATE "C", 'Alias forenames' COLLATE "C"),
        ('organisation_name' COLLATE "C", 'Alias organisation name' COLLATE "C"),
        ('sequence_number' COLLATE "C", 'Sequence of the alias within its party' COLLATE "C")$expected$,
    'every column comment matches authoritative wording'
);
SELECT results_eq(
    $actual$SELECT c.conname::text COLLATE "C", c.contype::text COLLATE "C",
        ARRAY(SELECT a.attname::text COLLATE "C"
              FROM unnest(c.conkey) WITH ORDINALITY AS k(attnum, position)
              JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = k.attnum
              ORDER BY k.position) COLLATE "C"
    FROM pg_constraint c WHERE c.conrelid = 'public.aliases'::regclass
      AND c.contype IN ('p', 'f', 'u', 'c') ORDER BY c.conname$actual$,
    $expected$VALUES
        ('aliases_pk' COLLATE "C", 'p' COLLATE "C", ARRAY['alias_id' COLLATE "C"]::text[] COLLATE "C"),
        ('als_party_id_fk' COLLATE "C", 'f' COLLATE "C", ARRAY['party_id' COLLATE "C"]::text[] COLLATE "C")$expected$,
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
    WHERE c.conrelid = 'public.aliases'::regclass AND c.contype = 'f'
    ORDER BY c.conname$actual$,
    $expected$VALUES ('als_party_id_fk' COLLATE "C", 'public' COLLATE "C", 'parties' COLLATE "C", ARRAY['party_id' COLLATE "C"]::text[] COLLATE "C",
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
    WHERE i.indrelid = 'public.aliases'::regclass ORDER BY r.relname$actual$,
    $expected$VALUES
        ('aliases_party_id_idx' COLLATE "C", ARRAY['party_id' COLLATE "C"]::text[] COLLATE "C", 'btree' COLLATE "C", false, false,
         true, true, 1, 1, true, true),
        ('aliases_pk' COLLATE "C", ARRAY['alias_id' COLLATE "C"]::text[] COLLATE "C", 'btree' COLLATE "C", true, true,
         true, true, 1, 1, true, true)$expected$,
    'exact index inventory, ordered keys, uniqueness and valid ready btree state'
);

-- ---------------------------------------------------------------------------
-- Scenario: Only the identifier is generated by an owned sequence.
-- Setup:    Inspect the default expression, identity marker and sequence metadata.
-- Expected: The owned BIGINT sequence uses start 1, increment 1, cache 1 and no cycle.
-- ---------------------------------------------------------------------------
SELECT is(pg_get_serial_sequence('public.aliases', 'alias_id'),
    'public.alias_id_seq', 'identifier sequence ownership');
SELECT is(
    (SELECT format_type(seqtypid, NULL) || ':' || seqstart || ':' || seqincrement
            || ':' || seqcache || ':' || seqcycle
     FROM pg_sequence WHERE seqrelid = 'public.alias_id_seq'::regclass),
    'bigint:1:1:1:false', 'BIGINT sequence start, increment, cache and cycle'
);
SELECT is(
    (SELECT pg_get_expr(d.adbin, d.adrelid)
     FROM pg_attrdef d JOIN pg_attribute a
       ON a.attrelid = d.adrelid AND a.attnum = d.adnum
     WHERE d.adrelid = 'public.aliases'::regclass AND a.attname = 'alias_id'),
    'nextval(''alias_id_seq''::regclass)', 'identifier defaults to the owned sequence'
);
SELECT is((SELECT count(*) FROM pg_attrdef WHERE adrelid = 'public.aliases'::regclass),
    1::bigint, 'only the identifier has a database default');
SELECT is(
    (SELECT attidentity::text FROM pg_attribute
     WHERE attrelid = 'public.aliases'::regclass AND attname = 'alias_id'),
    '', 'identifier is sequence-backed rather than an identity column'
);
SELECT is((SELECT count(*) FROM pg_trigger
           WHERE tgrelid = 'public.aliases'::regclass AND NOT tgisinternal),
    0::bigint, 'no user triggers introduce undeclared behaviour');

CREATE TEMP TABLE cv_party AS
    WITH inserted AS (
        INSERT INTO public.parties (address_line_1, restrict_personal_information, country_id)
        SELECT 'Synthetic Address', false, country_id FROM cv_reference RETURNING party_id
    ) SELECT party_id FROM inserted;

-- ---------------------------------------------------------------------------
-- Scenario: A minimal alias references its own synthetic Party and receives a generated ID.
-- Setup:    Insert only required alias fields using the generated Party key.
-- Expected: The valid relationship and sequence default allow the row.
-- ---------------------------------------------------------------------------
SELECT lives_ok(
    $sql$WITH inserted AS (
        INSERT INTO public.aliases (party_id, surname, forenames, sequence_number)
        SELECT party_id, 'Synthetic', 'Alias', 1 FROM cv_party RETURNING alias_id
    ) INSERT INTO cv_subject SELECT alias_id FROM inserted$sql$,
    'minimal valid alias generates an identifier'
);
INSERT INTO cv_generated SELECT id FROM cv_subject;

-- ---------------------------------------------------------------------------
-- Scenario: All mandatory alias fields reject NULL and organisation name is optional.
-- Setup:    Update only one column of the captured alias in each assertion.
-- Expected: Mandatory NULLs fail with 23502; organisation_name accepts NULL.
-- ---------------------------------------------------------------------------
SELECT throws_ok(
    $sql$UPDATE public.aliases SET alias_id = NULL
    WHERE alias_id = (SELECT id FROM cv_subject)$sql$,
    '23502', NULL, 'alias_id rejects NULL'
);
SELECT throws_ok(
    $sql$UPDATE public.aliases SET party_id = NULL
    WHERE alias_id = (SELECT id FROM cv_subject)$sql$,
    '23502', NULL, 'party_id rejects NULL'
);
SELECT throws_ok(
    $sql$UPDATE public.aliases SET surname = NULL
    WHERE alias_id = (SELECT id FROM cv_subject)$sql$,
    '23502', NULL, 'surname rejects NULL'
);
SELECT throws_ok(
    $sql$UPDATE public.aliases SET forenames = NULL
    WHERE alias_id = (SELECT id FROM cv_subject)$sql$,
    '23502', NULL, 'forenames rejects NULL'
);
SELECT throws_ok(
    $sql$UPDATE public.aliases SET sequence_number = NULL
    WHERE alias_id = (SELECT id FROM cv_subject)$sql$,
    '23502', NULL, 'sequence_number rejects NULL'
);
SELECT lives_ok(
    $sql$UPDATE public.aliases SET organisation_name = NULL
    WHERE alias_id = (SELECT id FROM cv_subject)$sql$,
    'organisation_name accepts NULL independently of required person fields'
);

-- ---------------------------------------------------------------------------
-- Scenario: All three alias name fields enforce the promoted VARCHAR boundary.
-- Setup:    Update one name field at a time to 50 and then 51 characters.
-- Expected: 50 characters are accepted; 51 characters fail with 22001.
-- ---------------------------------------------------------------------------
SELECT lives_ok(
    $sql$UPDATE public.aliases SET surname = repeat('x', 50)
    WHERE alias_id = (SELECT id FROM cv_subject)$sql$,
    'surname accepts 50 characters'
);
SELECT throws_ok(
    $sql$UPDATE public.aliases SET surname = repeat('x', 51)
    WHERE alias_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'surname rejects 51 characters'
);
SELECT lives_ok(
    $sql$UPDATE public.aliases SET forenames = repeat('x', 50)
    WHERE alias_id = (SELECT id FROM cv_subject)$sql$,
    'forenames accepts 50 characters'
);
SELECT throws_ok(
    $sql$UPDATE public.aliases SET forenames = repeat('x', 51)
    WHERE alias_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'forenames rejects 51 characters'
);
SELECT lives_ok(
    $sql$UPDATE public.aliases SET organisation_name = repeat('x', 50)
    WHERE alias_id = (SELECT id FROM cv_subject)$sql$,
    'organisation_name accepts 50 characters'
);
SELECT throws_ok(
    $sql$UPDATE public.aliases SET organisation_name = repeat('x', 51)
    WHERE alias_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'organisation_name rejects 51 characters'
);

-- ---------------------------------------------------------------------------
-- Scenario: Identifier uniqueness and Party referential integrity are enforced.
-- Setup:    Prove the missing Party key is absent, then attempt duplicate ID and missing Party.
-- Expected: Duplicate ID fails with 23505 and missing Party fails with 23503.
-- ---------------------------------------------------------------------------
SELECT is((SELECT count(*) FROM public.parties WHERE party_id = -32061),
    0::bigint, 'missing Party fixture key is absent');
SELECT throws_ok(
    $sql$INSERT INTO public.aliases (alias_id, party_id, surname, forenames, sequence_number)
    SELECT (SELECT id FROM cv_subject), party_id, 'Synthetic', 'Duplicate', 2 FROM cv_party$sql$,
    '23505', NULL, 'duplicate alias identifier is rejected'
);
SELECT throws_ok(
    $sql$UPDATE public.aliases SET party_id = -32061
    WHERE alias_id = (SELECT id FROM cv_subject)$sql$,
    '23503', NULL, 'missing Party reference is rejected'
);

-- ---------------------------------------------------------------------------
-- Scenario: Deleting the referenced synthetic Party is protected by the alias FK.
-- Setup:    Attempt to delete the Party created only for this suite and its alias.
-- Expected: The declared Party relationship rejects the delete with 23503.
-- ---------------------------------------------------------------------------
SELECT throws_ok(
    $sql$DELETE FROM public.parties WHERE party_id = (SELECT party_id FROM cv_party)$sql$,
    '23503', NULL, 'referenced synthetic Party cannot be deleted'
);

-- ---------------------------------------------------------------------------
-- Scenario: Alias count and sequence ordering remain caller responsibilities.
-- Setup:    Create another sequence-1 alias and five more for the same synthetic Party.
-- Expected: Duplicate sequence values and seven aliases succeed without extra business rules.
-- ---------------------------------------------------------------------------
SELECT lives_ok(
    $sql$WITH inserted AS (
        INSERT INTO public.aliases (party_id, surname, forenames, sequence_number)
        SELECT party_id, 'Synthetic', 'Second alias', 1 FROM cv_party RETURNING alias_id
    ) INSERT INTO cv_generated SELECT alias_id FROM inserted$sql$,
    'duplicate sequence_number is accepted and generates another identifier'
);
SELECT lives_ok(
    $sql$INSERT INTO public.aliases (party_id, surname, forenames, sequence_number)
    SELECT p.party_id, 'Synthetic', 'Additional alias', 1
    FROM cv_party p CROSS JOIN generate_series(1, 5)$sql$,
    'more than five aliases for one Party are accepted'
);
SELECT is((SELECT count(*) FROM public.aliases WHERE party_id = (SELECT party_id FROM cv_party)),
    7::bigint, 'all seven test-owned aliases persist with duplicate sequence numbers');
SELECT lives_ok(
    $sql$UPDATE public.aliases SET sequence_number = -1
    WHERE alias_id = (SELECT id FROM cv_subject)$sql$,
    'sequence_number has no invented positivity or ordering CHECK'
);
SELECT lives_ok(
    $sql$UPDATE public.aliases SET organisation_name = 'Synthetic organisation'
    WHERE alias_id = (SELECT id FROM cv_subject)$sql$,
    'organisation_name may coexist with required surname and forenames'
);
SELECT ok((SELECT bool_and(id IS NOT NULL) FROM cv_generated),
    'captured sequence-generated alias identifiers are non-null');
SELECT is((SELECT count(DISTINCT id) FROM cv_generated),
    2::bigint, 'separate successful alias inserts generate distinct identifiers');
SELECT * FROM finish();
ROLLBACK;
