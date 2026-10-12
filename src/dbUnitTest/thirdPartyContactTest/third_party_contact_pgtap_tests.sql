/**
 * OPAL Program
 *
 * MODULE      : third_party_contact_pgtap_tests.sql
 *
 * DESCRIPTION : Verify the Third Party Contact schema and integrity rules.
 *
 * CHANGE HISTORY:
 *
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * 03/10/2026  Chris Larkin  PO-10658      Initial pgTAP test suite.
 */

-- PO-10658: V1_22__create_third_party_contact_table.sql
-- Boundary applicability: fresh DB-01; direct PostgreSQL catalogue and behaviour.
-- Existing-state validation: Not run - user-approved initial-schema scope exception.
-- Initial delivery assumes no established affected account workflow; no upgrade path is claimed.
-- Expected literals were checked independently against promoted TDIA v162 and the approved plan.
\set ON_ERROR_STOP on
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SET LOCAL search_path = public, pg_temp;
SET LOCAL TIME ZONE 'UTC';
SELECT plan(60);

DO $fixture$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.countries) THEN
        RAISE EXCEPTION 'Required reference data missing';
    END IF;
END
$fixture$;
CREATE TEMP TABLE cv_reference AS SELECT (SELECT min(country_id) FROM public.countries) AS country_id;
CREATE TEMP TABLE cv_subject (id BIGINT PRIMARY KEY);
CREATE TEMP TABLE cv_created (id BIGINT PRIMARY KEY, scenario TEXT UNIQUE NOT NULL);

-- ---------------------------------------------------------------------------
-- Scenario: The promoted table has exactly the declared physical columns.
-- Setup:    Inspect the ordered column list, PostgreSQL types and nullability.
-- Expected: Every source-defined column matches, including optional fields.
-- ---------------------------------------------------------------------------

SELECT has_table('public', 'third_party_contact', 'public.third_party_contact exists');

SELECT is(
    (SELECT jsonb_agg(jsonb_build_array(
        attname::text, format_type(atttypid, atttypmod), attnotnull
    ) ORDER BY attnum)
    FROM pg_attribute
    WHERE attrelid = 'public.third_party_contact'::regclass AND attnum > 0 AND NOT attisdropped),
    '[["third_party_contact_id","bigint",true],["name_organisation","character varying(40)",true],["relationship","character varying(40)",true],["reference","character varying(40)",false],["address_line_1","character varying(35)",true],["address_line_2","character varying(35)",false],["address_line_3","character varying(35)",false],["address_line_4","character varying(35)",false],["address_line_5","character varying(35)",false],["postcode","character varying(10)",false],["country","bigint",true],["version_number","bigint",false]]'::jsonb,
    'exact ordered columns, physical types and nullability'
);

-- ---------------------------------------------------------------------------
-- Scenario: All column comments retain the promoted TDIA descriptions.
-- Setup:    Read comments in physical column order.
-- Expected: Every comment equals the independently checked source wording.
-- ---------------------------------------------------------------------------

SELECT is(
    (SELECT array_agg(col_description(attrelid, attnum) ORDER BY attnum)
     FROM pg_attribute
     WHERE attrelid = 'public.third_party_contact'::regclass AND attnum > 0 AND NOT attisdropped),
    ARRAY[
        'Unique identifier of the third-party contact',
        'Name of the third-party person or organisation',
        'Relationship between the contact and account holder',
        'Reference supplied for the third-party contact',
        'Address line 1',
        'Address line 2',
        'Address line 3',
        'Address line 4',
        'Address line 5',
        'Postcode',
        'Country',
        'Optimistic-locking version of the contact'
    ]::text[],
    'all column comments match the promoted TDIA verbatim'
);

-- ---------------------------------------------------------------------------
-- Scenario: Only the declared keys and indexes are installed.
-- Setup:    Inspect named constraints, PK columns, index keys and index properties.
-- Expected: No extra uniqueness, CHECK, index or user trigger is introduced.
-- ---------------------------------------------------------------------------

SELECT is(
    (SELECT array_agg(conname::text ORDER BY conname) FROM pg_constraint
     WHERE conrelid = 'public.third_party_contact'::regclass AND contype IN ('p', 'u', 'f', 'c')),
    ARRAY['third_party_contact_pk']::text[],
    'exact table constraint inventory, including the absence of business CHECKs'
);

SELECT col_is_pk('public', 'third_party_contact', 'third_party_contact_id', 'third_party_contact_id is the sole primary-key column');

SELECT is(
    (SELECT array_agg(indexname::text ORDER BY indexname) FROM pg_indexes
     WHERE schemaname = 'public' AND tablename = 'third_party_contact'),
    ARRAY['third_party_contact_pk']::text[],
    'exact index inventory without duplicate access paths'
);

SELECT is(
    (SELECT jsonb_agg(jsonb_build_array(
        index_relation.relname::text,
           ARRAY(SELECT attribute.attname::text
                 FROM unnest(index_definition.indkey) WITH ORDINALITY AS key_column(attnum, position)
                 JOIN pg_attribute attribute
                   ON attribute.attrelid = index_definition.indrelid
                  AND attribute.attnum = key_column.attnum
                 ORDER BY key_column.position),
           access_method.amname::text, index_definition.indisunique, index_definition.indisprimary,
           index_definition.indisvalid, index_definition.indisready,
           pg_get_expr(index_definition.indpred, index_definition.indrelid)
    ) ORDER BY index_relation.relname)
    FROM pg_index index_definition
    JOIN pg_class index_relation ON index_relation.oid = index_definition.indexrelid
    JOIN pg_am access_method ON access_method.oid = index_relation.relam
    WHERE index_definition.indrelid = 'public.third_party_contact'::regclass),
    '[["third_party_contact_pk",["third_party_contact_id"],"btree",true,true,true,true,null]]'::jsonb,
    'indexes have exact ordered keys, uniqueness, ready valid B-tree state and no predicates'
);

SELECT is(
    (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'public.third_party_contact'::regclass AND NOT tgisinternal),
    0::bigint, 'no user trigger adds behaviour to the table'
);

-- ---------------------------------------------------------------------------
-- Scenario: Identifiers use an owned BIGINT sequence and only the ID has a default.
-- Setup:    Inspect sequence configuration, dependency, nextval expression and identity flags.
-- Expected: START 1, INCREMENT 1, CACHE 1 and NO CYCLE are retained; no other default is added.
-- ---------------------------------------------------------------------------

SELECT has_sequence('public', 'third_party_contact_id_seq', 'public.third_party_contact_id_seq exists');

SELECT is(pg_get_serial_sequence('public.third_party_contact', 'third_party_contact_id'),
          'public.third_party_contact_id_seq', 'the identifier sequence is owned by the identifier column');

SELECT is(
    (SELECT seqtypid::regtype::text || ':' || seqstart || ':' || seqincrement || ':' || seqcache || ':' || seqcycle
     FROM pg_sequence WHERE seqrelid = 'public.third_party_contact_id_seq'::regclass),
    'bigint:1:1:1:false', 'exact BIGINT sequence start, increment, cache and no-cycle contract'
);

SELECT is(
    (SELECT pg_get_expr(adbin, adrelid) FROM pg_attrdef
     WHERE adrelid = 'public.third_party_contact'::regclass
       AND adnum = (SELECT attnum FROM pg_attribute
                    WHERE attrelid = 'public.third_party_contact'::regclass AND attname = 'third_party_contact_id')),
    'nextval(''third_party_contact_id_seq''::regclass)', 'the identifier default calls its exact sequence'
);

SELECT ok(
    EXISTS (SELECT 1 FROM pg_attrdef column_default
            JOIN pg_depend dependency ON dependency.classid = 'pg_attrdef'::regclass
             AND dependency.objid = column_default.oid AND dependency.refclassid = 'pg_class'::regclass
             AND dependency.refobjid = 'public.third_party_contact_id_seq'::regclass
            WHERE column_default.adrelid = 'public.third_party_contact'::regclass
              AND column_default.adnum = (SELECT attnum FROM pg_attribute
                  WHERE attrelid = 'public.third_party_contact'::regclass AND attname = 'third_party_contact_id')),
    'identifier default depends on its owned sequence'
);

SELECT ok(
    EXISTS (SELECT 1 FROM pg_depend dependency
            WHERE dependency.classid = 'pg_class'::regclass
              AND dependency.objid = 'public.third_party_contact_id_seq'::regclass
              AND dependency.refclassid = 'pg_class'::regclass
              AND dependency.refobjid = 'public.third_party_contact'::regclass
              AND dependency.refobjsubid = (SELECT attnum FROM pg_attribute
                  WHERE attrelid = 'public.third_party_contact'::regclass AND attname = 'third_party_contact_id')
              AND dependency.deptype = 'a'),
    'the sequence has the explicit OWNED BY column dependency'
);

SELECT is((SELECT count(*) FROM pg_attrdef WHERE adrelid = 'public.third_party_contact'::regclass),
          1::bigint, 'only the identifier has a database default');

SELECT is(
    (SELECT count(*) FROM pg_attribute
     WHERE attrelid = 'public.third_party_contact'::regclass AND attnum > 0 AND NOT attisdropped AND attidentity <> ''),
    0::bigint, 'no identity column replaces the explicit owned sequence'
);

-- ---------------------------------------------------------------------------
-- Scenario: A minimal source-valid row is accepted with a generated identifier.
-- Setup:    Insert only mandatory values and capture the returned ID.
-- Expected: The row supports isolated NULL, boundary and integrity checks.
-- ---------------------------------------------------------------------------

SELECT lives_ok(
    $sql$WITH inserted AS (
        INSERT INTO public.third_party_contact (name_organisation, relationship, address_line_1, country)
        SELECT 'Synthetic Contact', 'Synthetic Relationship', 'Synthetic Address', country_id FROM cv_reference
        RETURNING third_party_contact_id
    )
    INSERT INTO cv_subject SELECT third_party_contact_id FROM inserted$sql$,
    'a minimal source-valid row is inserted with its generated ID captured'
);

SELECT ok((SELECT id IS NOT NULL FROM cv_subject), 'the minimal row receives a non-null generated identifier');

-- ---------------------------------------------------------------------------
-- Scenario: Each required and optional column follows its declared NULL contract.
-- Setup:    Update the captured valid row to NULL one column at a time.
-- Expected: Required fields raise 23502; every nullable field accepts NULL.
-- ---------------------------------------------------------------------------

SELECT throws_ok(
    $sql$UPDATE public.third_party_contact SET third_party_contact_id = NULL
        WHERE third_party_contact_id = (SELECT id FROM cv_subject)$sql$,
    '23502', NULL, 'third_party_contact_id rejects NULL'
);

SELECT throws_ok(
    $sql$UPDATE public.third_party_contact SET name_organisation = NULL
        WHERE third_party_contact_id = (SELECT id FROM cv_subject)$sql$,
    '23502', NULL, 'name_organisation rejects NULL'
);

SELECT throws_ok(
    $sql$UPDATE public.third_party_contact SET relationship = NULL
        WHERE third_party_contact_id = (SELECT id FROM cv_subject)$sql$,
    '23502', NULL, 'relationship rejects NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.third_party_contact SET reference = NULL
        WHERE third_party_contact_id = (SELECT id FROM cv_subject)$sql$,
    'reference accepts NULL'
);

SELECT throws_ok(
    $sql$UPDATE public.third_party_contact SET address_line_1 = NULL
        WHERE third_party_contact_id = (SELECT id FROM cv_subject)$sql$,
    '23502', NULL, 'address_line_1 rejects NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.third_party_contact SET address_line_2 = NULL
        WHERE third_party_contact_id = (SELECT id FROM cv_subject)$sql$,
    'address_line_2 accepts NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.third_party_contact SET address_line_3 = NULL
        WHERE third_party_contact_id = (SELECT id FROM cv_subject)$sql$,
    'address_line_3 accepts NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.third_party_contact SET address_line_4 = NULL
        WHERE third_party_contact_id = (SELECT id FROM cv_subject)$sql$,
    'address_line_4 accepts NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.third_party_contact SET address_line_5 = NULL
        WHERE third_party_contact_id = (SELECT id FROM cv_subject)$sql$,
    'address_line_5 accepts NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.third_party_contact SET postcode = NULL
        WHERE third_party_contact_id = (SELECT id FROM cv_subject)$sql$,
    'postcode accepts NULL'
);

SELECT throws_ok(
    $sql$UPDATE public.third_party_contact SET country = NULL
        WHERE third_party_contact_id = (SELECT id FROM cv_subject)$sql$,
    '23502', NULL, 'country rejects NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.third_party_contact SET version_number = NULL
        WHERE third_party_contact_id = (SELECT id FROM cv_subject)$sql$,
    'version_number accepts NULL'
);

-- ---------------------------------------------------------------------------
-- Scenario: Every bounded text field accepts its limit and rejects one extra character.
-- Setup:    Update the captured row at each promoted VARCHAR boundary.
-- Expected: n characters succeed; n+1 raises native SQLSTATE 22001.
-- ---------------------------------------------------------------------------

SELECT lives_ok(
    $sql$UPDATE public.third_party_contact SET name_organisation = repeat('X', 40)
        WHERE third_party_contact_id = (SELECT id FROM cv_subject)$sql$,
    'name_organisation accepts 40 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.third_party_contact SET name_organisation = repeat('X', 41)
        WHERE third_party_contact_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'name_organisation rejects 41 characters'
);

SELECT lives_ok(
    $sql$UPDATE public.third_party_contact SET relationship = repeat('X', 40)
        WHERE third_party_contact_id = (SELECT id FROM cv_subject)$sql$,
    'relationship accepts 40 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.third_party_contact SET relationship = repeat('X', 41)
        WHERE third_party_contact_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'relationship rejects 41 characters'
);

SELECT lives_ok(
    $sql$UPDATE public.third_party_contact SET reference = repeat('X', 40)
        WHERE third_party_contact_id = (SELECT id FROM cv_subject)$sql$,
    'reference accepts 40 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.third_party_contact SET reference = repeat('X', 41)
        WHERE third_party_contact_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'reference rejects 41 characters'
);

SELECT lives_ok(
    $sql$UPDATE public.third_party_contact SET address_line_1 = repeat('X', 35)
        WHERE third_party_contact_id = (SELECT id FROM cv_subject)$sql$,
    'address_line_1 accepts 35 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.third_party_contact SET address_line_1 = repeat('X', 36)
        WHERE third_party_contact_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'address_line_1 rejects 36 characters'
);

SELECT lives_ok(
    $sql$UPDATE public.third_party_contact SET address_line_2 = repeat('X', 35)
        WHERE third_party_contact_id = (SELECT id FROM cv_subject)$sql$,
    'address_line_2 accepts 35 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.third_party_contact SET address_line_2 = repeat('X', 36)
        WHERE third_party_contact_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'address_line_2 rejects 36 characters'
);

SELECT lives_ok(
    $sql$UPDATE public.third_party_contact SET address_line_3 = repeat('X', 35)
        WHERE third_party_contact_id = (SELECT id FROM cv_subject)$sql$,
    'address_line_3 accepts 35 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.third_party_contact SET address_line_3 = repeat('X', 36)
        WHERE third_party_contact_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'address_line_3 rejects 36 characters'
);

SELECT lives_ok(
    $sql$UPDATE public.third_party_contact SET address_line_4 = repeat('X', 35)
        WHERE third_party_contact_id = (SELECT id FROM cv_subject)$sql$,
    'address_line_4 accepts 35 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.third_party_contact SET address_line_4 = repeat('X', 36)
        WHERE third_party_contact_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'address_line_4 rejects 36 characters'
);

SELECT lives_ok(
    $sql$UPDATE public.third_party_contact SET address_line_5 = repeat('X', 35)
        WHERE third_party_contact_id = (SELECT id FROM cv_subject)$sql$,
    'address_line_5 accepts 35 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.third_party_contact SET address_line_5 = repeat('X', 36)
        WHERE third_party_contact_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'address_line_5 rejects 36 characters'
);

SELECT lives_ok(
    $sql$UPDATE public.third_party_contact SET postcode = repeat('X', 10)
        WHERE third_party_contact_id = (SELECT id FROM cv_subject)$sql$,
    'postcode accepts 10 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.third_party_contact SET postcode = repeat('X', 11)
        WHERE third_party_contact_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'postcode rejects 11 characters'
);

-- ---------------------------------------------------------------------------
-- Scenario: Primary keys reject a second row with the captured identifier.
-- Setup:    Attempt an otherwise-valid insert using the minimal row ID.
-- Expected: A duplicate primary key raises SQLSTATE 23505.
-- ---------------------------------------------------------------------------

SELECT throws_ok(
    $sql$INSERT INTO public.third_party_contact (third_party_contact_id, name_organisation, relationship, address_line_1, country)
        SELECT id, 'Synthetic duplicate', 'Synthetic relationship', 'Synthetic address', country_id
        FROM cv_subject CROSS JOIN cv_reference$sql$,
    '23505', NULL, 'duplicate third_party_contact_id is rejected'
);

-- ---------------------------------------------------------------------------
-- Scenario: Country is mandatory without a Country foreign key.
-- Setup:    Assert an arbitrary Country number is absent and assign it to the captured contact.
-- Expected: The non-null value succeeds even without a corresponding Country row.
-- ---------------------------------------------------------------------------

SELECT is((SELECT count(*) FROM public.countries WHERE country_id = -20658),
          0::bigint, 'the arbitrary Third Party Contact Country number has no Country row');

SELECT lives_ok(
    $sql$UPDATE public.third_party_contact SET country = -20658
        WHERE third_party_contact_id = (SELECT id FROM cv_subject)$sql$,
    'a non-null country with no Country row is accepted without an FK'
);

SELECT is((SELECT country FROM public.third_party_contact WHERE third_party_contact_id = (SELECT id FROM cv_subject)),
          -20658::bigint, 'the arbitrary Country number persists unchanged');

-- ---------------------------------------------------------------------------
-- Scenario: Optional version values have no generated default or locking algorithm.
-- Setup:    Inspect the omitted version and set a representable explicit BIGINT version.
-- Expected: Omission leaves NULL; an explicit version persists without a database update algorithm.
-- ---------------------------------------------------------------------------

SELECT is((SELECT version_number FROM public.third_party_contact WHERE third_party_contact_id = (SELECT id FROM cv_subject)),
          NULL::bigint, 'an omitted version_number remains NULL');

SELECT lives_ok(
    $sql$UPDATE public.third_party_contact SET version_number = 9223372036854775807
        WHERE third_party_contact_id = (SELECT id FROM cv_subject)$sql$,
    'the maximum BIGINT version_number is accepted as supplied'
);

SELECT is((SELECT version_number FROM public.third_party_contact WHERE third_party_contact_id = (SELECT id FROM cv_subject)),
          9223372036854775807::bigint, 'the explicit version_number persists unchanged');

-- ---------------------------------------------------------------------------
-- Scenario: A complete contact accepts every promoted VARCHAR limit.
-- Setup:    Insert all optional text and explicit version fields at their documented boundaries.
-- Expected: The complete row receives a generated ID with all optional values present.
-- ---------------------------------------------------------------------------

SELECT lives_ok(
    $sql$WITH inserted AS (
        INSERT INTO public.third_party_contact (name_organisation, relationship, reference,
            address_line_1, address_line_2, address_line_3, address_line_4, address_line_5, postcode, country, version_number)
        SELECT repeat('N', 40), repeat('R', 40), repeat('F', 40), repeat('1', 35), repeat('2', 35),
               repeat('3', 35), repeat('4', 35), repeat('5', 35), repeat('P', 10), country_id, 1 FROM cv_reference
        RETURNING third_party_contact_id
    )
    INSERT INTO cv_created (id, scenario) SELECT third_party_contact_id, 'complete' FROM inserted$sql$,
    'a complete contact at every text boundary is accepted'
);

-- ---------------------------------------------------------------------------
-- Scenario: Native BIGINT fields reject values beyond their storage range.
-- Setup:    Update ID, Country and version with the first value above the BIGINT maximum.
-- Expected: Each overflow raises native SQLSTATE 22003.
-- ---------------------------------------------------------------------------

SELECT throws_ok(
    $sql$UPDATE public.third_party_contact SET third_party_contact_id = 9223372036854775808
        WHERE third_party_contact_id = (SELECT id FROM cv_subject)$sql$,
    '22003', NULL, 'third_party_contact_id outside BIGINT range is rejected'
);

SELECT throws_ok(
    $sql$UPDATE public.third_party_contact SET country = 9223372036854775808
        WHERE third_party_contact_id = (SELECT id FROM cv_subject)$sql$,
    '22003', NULL, 'country outside BIGINT range is rejected'
);

SELECT throws_ok(
    $sql$UPDATE public.third_party_contact SET version_number = 9223372036854775808
        WHERE third_party_contact_id = (SELECT id FROM cv_subject)$sql$,
    '22003', NULL, 'version_number outside BIGINT range is rejected'
);

-- ---------------------------------------------------------------------------
-- Scenario: Both captured contact insertions receive distinct generated IDs.
-- Setup:    Compare minimal and complete contact IDs.
-- Expected: Both generated IDs are non-null and distinct; sequence gaps are permitted.
-- ---------------------------------------------------------------------------

SELECT ok(
    (SELECT count(*) = 2 AND count(DISTINCT id) = 2 AND bool_and(id IS NOT NULL)
     FROM (SELECT id FROM cv_subject UNION ALL SELECT id FROM cv_created) generated),
    'both inserted contacts have distinct non-null generated identifiers'
);

SELECT * FROM finish();
ROLLBACK;
