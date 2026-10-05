/**
 * OPAL Program
 *
 * MODULE      : debtor_detail_pgtap_tests.sql
 *
 * DESCRIPTION : Verify the Debtor Detail schema and approved employer nullability.
 *
 * CHANGE HISTORY:
 *
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * 03/10/2026  Chris Larkin  PO-10641      Initial pgTAP test suite.
 */

-- PO-10641: V1_19__create_debtor_detail_table.sql
-- Boundary applicability: fresh DB-01; direct PostgreSQL catalogue and behaviour.
-- Existing-state validation: Not run - user-approved initial-schema scope exception.
-- Initial delivery assumes no established affected account workflow; no upgrade path is claimed.
-- Expected literals were checked independently against promoted TDIA v162 and the approved plan.
\set ON_ERROR_STOP on
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SET LOCAL search_path = public, pg_temp;
SET LOCAL TIME ZONE 'UTC';
SELECT plan(69);

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

SELECT has_table('public', 'debtor_detail', 'public.debtor_detail exists');

SELECT is(
    (SELECT jsonb_agg(jsonb_build_array(
        attname::text, format_type(atttypid, atttypmod), attnotnull
    ) ORDER BY attnum)
    FROM pg_attribute
    WHERE attrelid = 'public.debtor_detail'::regclass AND attnum > 0 AND NOT attisdropped),
    '[["debtor_detail_id","bigint",true],["employer_name","character varying(50)",false],["employer_address_line_1","character varying(35)",false],["employer_address_line_2","character varying(35)",false],["employer_address_line_3","character varying(35)",false],["employer_address_line_4","character varying(35)",false],["employer_address_line_5","character varying(35)",false],["employer_postcode","character varying(10)",false],["employer_country_id","bigint",false],["employee_reference","character varying(35)",false],["employer_telephone","character varying(35)",false],["employer_email","character varying(80)",false],["other_personal_information","character varying(200)",false]]'::jsonb,
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
     WHERE attrelid = 'public.debtor_detail'::regclass AND attnum > 0 AND NOT attisdropped),
    ARRAY[
        'Unique identifier of the Debtor Detail',
        'Employer name',
        'Employer address line 1',
        'Employer address line 2',
        'Employer address line 3',
        'Employer address line 4',
        'Employer address line 5',
        'Employer postcode',
        'Employer country',
        'Employee reference number',
        'Employer telephone number',
        'Employer email address',
        'Optional additional respondent details'
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
     WHERE conrelid = 'public.debtor_detail'::regclass AND contype IN ('p', 'u', 'f', 'c')),
    ARRAY['dd_employer_country_id_fk', 'debtor_detail_pk']::text[],
    'exact table constraint inventory, including the absence of business CHECKs'
);

SELECT col_is_pk('public', 'debtor_detail', 'debtor_detail_id', 'debtor_detail_id is the sole primary-key column');

SELECT is(
    (SELECT array_agg(indexname::text ORDER BY indexname) FROM pg_indexes
     WHERE schemaname = 'public' AND tablename = 'debtor_detail'),
    ARRAY['debtor_detail_employer_country_id_idx', 'debtor_detail_pk']::text[],
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
    WHERE index_definition.indrelid = 'public.debtor_detail'::regclass),
    '[["debtor_detail_employer_country_id_idx",["employer_country_id"],"btree",false,false,true,true,null],["debtor_detail_pk",["debtor_detail_id"],"btree",true,true,true,true,null]]'::jsonb,
    'indexes have exact ordered keys, uniqueness, ready valid B-tree state and no predicates'
);

SELECT is(
    (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'public.debtor_detail'::regclass AND NOT tgisinternal),
    0::bigint, 'no user trigger adds behaviour to the table'
);

-- ---------------------------------------------------------------------------
-- Scenario: The Country FK has the declared endpoint and immediate NO ACTION behaviour.
-- Setup:    Inspect referencing and referenced columns and FK action flags.
-- Expected: The named FK references public.countries.country_id without deferred enforcement.
-- ---------------------------------------------------------------------------

SELECT is(
    (SELECT jsonb_agg(jsonb_build_array(
        constraint_definition.conname::text,
           ARRAY(SELECT attribute.attname::text
                 FROM unnest(constraint_definition.conkey) WITH ORDINALITY AS key_column(attnum, position)
                 JOIN pg_attribute attribute
                   ON attribute.attrelid = constraint_definition.conrelid
                  AND attribute.attnum = key_column.attnum
                 ORDER BY key_column.position),
           parent_namespace.nspname::text, parent_relation.relname::text,
           ARRAY(SELECT attribute.attname::text
                 FROM unnest(constraint_definition.confkey) WITH ORDINALITY AS key_column(attnum, position)
                 JOIN pg_attribute attribute
                   ON attribute.attrelid = constraint_definition.confrelid
                  AND attribute.attnum = key_column.attnum
                 ORDER BY key_column.position),
           constraint_definition.confupdtype::text, constraint_definition.confdeltype::text,
           constraint_definition.confmatchtype::text, constraint_definition.condeferrable,
           constraint_definition.condeferred, constraint_definition.convalidated
    ) ORDER BY constraint_definition.conname)
    FROM pg_constraint constraint_definition
    JOIN pg_class parent_relation ON parent_relation.oid = constraint_definition.confrelid
    JOIN pg_namespace parent_namespace ON parent_namespace.oid = parent_relation.relnamespace
    WHERE constraint_definition.conrelid = 'public.debtor_detail'::regclass
      AND constraint_definition.contype = 'f'),
    '[["dd_employer_country_id_fk",["employer_country_id"],"public","countries",["country_id"],"a","a","s",false,false,true]]'::jsonb,
    'Country FK endpoint and immediate NO ACTION properties match the contract'
);

-- ---------------------------------------------------------------------------
-- Scenario: Identifiers use an owned BIGINT sequence and only the ID has a default.
-- Setup:    Inspect sequence configuration, dependency, nextval expression and identity flags.
-- Expected: START 1, INCREMENT 1, CACHE 1 and NO CYCLE are retained; no other default is added.
-- ---------------------------------------------------------------------------

SELECT has_sequence('public', 'debtor_detail_id_seq', 'public.debtor_detail_id_seq exists');

SELECT is(pg_get_serial_sequence('public.debtor_detail', 'debtor_detail_id'),
          'public.debtor_detail_id_seq', 'the identifier sequence is owned by the identifier column');

SELECT is(
    (SELECT seqtypid::regtype::text || ':' || seqstart || ':' || seqincrement || ':' || seqcache || ':' || seqcycle
     FROM pg_sequence WHERE seqrelid = 'public.debtor_detail_id_seq'::regclass),
    'bigint:1:1:1:false', 'exact BIGINT sequence start, increment, cache and no-cycle contract'
);

SELECT is(
    (SELECT pg_get_expr(adbin, adrelid) FROM pg_attrdef
     WHERE adrelid = 'public.debtor_detail'::regclass
       AND adnum = (SELECT attnum FROM pg_attribute
                    WHERE attrelid = 'public.debtor_detail'::regclass AND attname = 'debtor_detail_id')),
    'nextval(''debtor_detail_id_seq''::regclass)', 'the identifier default calls its exact sequence'
);

SELECT ok(
    EXISTS (SELECT 1 FROM pg_attrdef column_default
            JOIN pg_depend dependency ON dependency.classid = 'pg_attrdef'::regclass
             AND dependency.objid = column_default.oid AND dependency.refclassid = 'pg_class'::regclass
             AND dependency.refobjid = 'public.debtor_detail_id_seq'::regclass
            WHERE column_default.adrelid = 'public.debtor_detail'::regclass
              AND column_default.adnum = (SELECT attnum FROM pg_attribute
                  WHERE attrelid = 'public.debtor_detail'::regclass AND attname = 'debtor_detail_id')),
    'identifier default depends on its owned sequence'
);

SELECT ok(
    EXISTS (SELECT 1 FROM pg_depend dependency
            WHERE dependency.classid = 'pg_class'::regclass
              AND dependency.objid = 'public.debtor_detail_id_seq'::regclass
              AND dependency.refclassid = 'pg_class'::regclass
              AND dependency.refobjid = 'public.debtor_detail'::regclass
              AND dependency.refobjsubid = (SELECT attnum FROM pg_attribute
                  WHERE attrelid = 'public.debtor_detail'::regclass AND attname = 'debtor_detail_id')
              AND dependency.deptype = 'a'),
    'the sequence has the explicit OWNED BY column dependency'
);

SELECT is((SELECT count(*) FROM pg_attrdef WHERE adrelid = 'public.debtor_detail'::regclass),
          1::bigint, 'only the identifier has a database default');

SELECT is(
    (SELECT count(*) FROM pg_attribute
     WHERE attrelid = 'public.debtor_detail'::regclass AND attnum > 0 AND NOT attisdropped AND attidentity <> ''),
    0::bigint, 'no identity column replaces the explicit owned sequence'
);

-- ---------------------------------------------------------------------------
-- Scenario: A minimal source-valid row is accepted with a generated identifier.
-- Setup:    Insert only mandatory values and capture the returned ID.
-- Expected: The row supports isolated NULL, boundary and integrity checks.
-- ---------------------------------------------------------------------------

SELECT lives_ok(
    $sql$WITH inserted AS (
        INSERT INTO public.debtor_detail (other_personal_information)
        VALUES ('Synthetic additional information only')
        RETURNING debtor_detail_id
    )
    INSERT INTO cv_subject SELECT debtor_detail_id FROM inserted$sql$,
    'a minimal source-valid row is inserted with its generated ID captured'
);

SELECT ok((SELECT id IS NOT NULL FROM cv_subject), 'the minimal row receives a non-null generated identifier');

-- ---------------------------------------------------------------------------
-- Scenario: Each required and optional column follows its declared NULL contract.
-- Setup:    Update the captured valid row to NULL one column at a time.
-- Expected: Required fields raise 23502; every nullable field accepts NULL.
-- ---------------------------------------------------------------------------

SELECT throws_ok(
    $sql$UPDATE public.debtor_detail SET debtor_detail_id = NULL
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    '23502', NULL, 'debtor_detail_id rejects NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.debtor_detail SET employer_name = NULL
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    'employer_name accepts NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.debtor_detail SET employer_address_line_1 = NULL
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    'employer_address_line_1 accepts NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.debtor_detail SET employer_address_line_2 = NULL
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    'employer_address_line_2 accepts NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.debtor_detail SET employer_address_line_3 = NULL
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    'employer_address_line_3 accepts NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.debtor_detail SET employer_address_line_4 = NULL
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    'employer_address_line_4 accepts NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.debtor_detail SET employer_address_line_5 = NULL
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    'employer_address_line_5 accepts NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.debtor_detail SET employer_postcode = NULL
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    'employer_postcode accepts NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.debtor_detail SET employer_country_id = NULL
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    'employer_country_id accepts NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.debtor_detail SET employee_reference = NULL
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    'employee_reference accepts NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.debtor_detail SET employer_telephone = NULL
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    'employer_telephone accepts NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.debtor_detail SET employer_email = NULL
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    'employer_email accepts NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.debtor_detail SET other_personal_information = NULL
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    'other_personal_information accepts NULL'
);

-- ---------------------------------------------------------------------------
-- Scenario: Every bounded text field accepts its limit and rejects one extra character.
-- Setup:    Update the captured row at each promoted VARCHAR boundary.
-- Expected: n characters succeed; n+1 raises native SQLSTATE 22001.
-- ---------------------------------------------------------------------------

SELECT lives_ok(
    $sql$UPDATE public.debtor_detail SET employer_name = repeat('X', 50)
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    'employer_name accepts 50 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.debtor_detail SET employer_name = repeat('X', 51)
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'employer_name rejects 51 characters'
);

SELECT lives_ok(
    $sql$UPDATE public.debtor_detail SET employer_address_line_1 = repeat('X', 35)
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    'employer_address_line_1 accepts 35 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.debtor_detail SET employer_address_line_1 = repeat('X', 36)
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'employer_address_line_1 rejects 36 characters'
);

SELECT lives_ok(
    $sql$UPDATE public.debtor_detail SET employer_address_line_2 = repeat('X', 35)
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    'employer_address_line_2 accepts 35 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.debtor_detail SET employer_address_line_2 = repeat('X', 36)
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'employer_address_line_2 rejects 36 characters'
);

SELECT lives_ok(
    $sql$UPDATE public.debtor_detail SET employer_address_line_3 = repeat('X', 35)
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    'employer_address_line_3 accepts 35 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.debtor_detail SET employer_address_line_3 = repeat('X', 36)
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'employer_address_line_3 rejects 36 characters'
);

SELECT lives_ok(
    $sql$UPDATE public.debtor_detail SET employer_address_line_4 = repeat('X', 35)
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    'employer_address_line_4 accepts 35 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.debtor_detail SET employer_address_line_4 = repeat('X', 36)
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'employer_address_line_4 rejects 36 characters'
);

SELECT lives_ok(
    $sql$UPDATE public.debtor_detail SET employer_address_line_5 = repeat('X', 35)
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    'employer_address_line_5 accepts 35 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.debtor_detail SET employer_address_line_5 = repeat('X', 36)
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'employer_address_line_5 rejects 36 characters'
);

SELECT lives_ok(
    $sql$UPDATE public.debtor_detail SET employer_postcode = repeat('X', 10)
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    'employer_postcode accepts 10 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.debtor_detail SET employer_postcode = repeat('X', 11)
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'employer_postcode rejects 11 characters'
);

SELECT lives_ok(
    $sql$UPDATE public.debtor_detail SET employee_reference = repeat('X', 35)
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    'employee_reference accepts 35 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.debtor_detail SET employee_reference = repeat('X', 36)
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'employee_reference rejects 36 characters'
);

SELECT lives_ok(
    $sql$UPDATE public.debtor_detail SET employer_telephone = repeat('X', 35)
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    'employer_telephone accepts 35 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.debtor_detail SET employer_telephone = repeat('X', 36)
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'employer_telephone rejects 36 characters'
);

SELECT lives_ok(
    $sql$UPDATE public.debtor_detail SET employer_email = repeat('X', 80)
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    'employer_email accepts 80 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.debtor_detail SET employer_email = repeat('X', 81)
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'employer_email rejects 81 characters'
);

SELECT lives_ok(
    $sql$UPDATE public.debtor_detail SET other_personal_information = repeat('X', 200)
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    'other_personal_information accepts 200 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.debtor_detail SET other_personal_information = repeat('X', 201)
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'other_personal_information rejects 201 characters'
);

-- ---------------------------------------------------------------------------
-- Scenario: Primary keys reject a second row with the captured identifier.
-- Setup:    Attempt an otherwise-valid insert using the minimal row ID.
-- Expected: A duplicate primary key raises SQLSTATE 23505.
-- ---------------------------------------------------------------------------

SELECT throws_ok(
    $sql$INSERT INTO public.debtor_detail (debtor_detail_id)
        SELECT id FROM cv_subject$sql$,
    '23505', NULL, 'duplicate debtor_detail_id is rejected'
);

-- ---------------------------------------------------------------------------
-- Scenario: Only valid supplied Country references are accepted.
-- Setup:    Assert the missing key is absent, then update the captured row to it.
-- Expected: A nonexistent Country raises 23503; an existing reference succeeds.
-- ---------------------------------------------------------------------------

SELECT is((SELECT count(*) FROM public.countries WHERE country_id = -20641),
          0::bigint, 'the missing Country fixture key is absent');

SELECT lives_ok(
    $sql$UPDATE public.debtor_detail SET employer_country_id = (SELECT country_id FROM cv_reference)
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    'an existing Country reference is accepted'
);

SELECT throws_ok(
    $sql$UPDATE public.debtor_detail SET employer_country_id = -20641
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    '23503', NULL, 'a missing Country reference is rejected'
);

-- ---------------------------------------------------------------------------
-- Scenario: A referenced synthetic Country cannot be deleted.
-- Setup:    Create one dedicated Country and a child that refers only to that parent.
-- Expected: The object's own Country FK raises 23503 without relying on other reference relationships.
-- ---------------------------------------------------------------------------

SELECT lives_ok(
    $sql$INSERT INTO public.countries (country_id, cjs_code, country_name, date_used_from, active)
        VALUES (-10641, 31541, 'Synthetic debtor_detail Country', DATE '2026-01-01', TRUE)$sql$,
    'a dedicated synthetic Country is inserted without changing existing rows'
);

SELECT lives_ok(
    $sql$WITH inserted AS (
        INSERT INTO public.debtor_detail (employer_country_id)
        VALUES (-10641)
        RETURNING debtor_detail_id
    )
    INSERT INTO cv_created (id, scenario) SELECT debtor_detail_id, 'country-child' FROM inserted$sql$,
    'a Debtor Detail references the dedicated synthetic Country'
);

SELECT throws_ok(
    $sql$DELETE FROM public.countries WHERE country_id = -10641$sql$,
    '23503', NULL, 'deleting the dedicated referenced Country is rejected'
);

-- ---------------------------------------------------------------------------
-- Scenario: Employment, additional-only, empty and partial details are valid storage shapes.
-- Setup:    Insert complete employment, DEFAULT VALUES and contact-only employment rows.
-- Expected: The nullable employer triplet adds no conditional CHECK; UI completeness is outside this suite.
-- ---------------------------------------------------------------------------

SELECT lives_ok(
    $sql$WITH inserted AS (
        INSERT INTO public.debtor_detail (employer_name, employer_address_line_1, employer_address_line_2,
            employer_address_line_3, employer_address_line_4, employer_address_line_5, employer_postcode,
            employer_country_id, employee_reference, employer_telephone, employer_email, other_personal_information)
        SELECT 'Synthetic employer', 'Synthetic employer address one', 'Synthetic address two',
               'Synthetic address three', 'Synthetic address four', 'Synthetic address five', 'SYNTHETIC',
               country_id, 'Synthetic employee reference', 'Synthetic telephone',
               'synthetic@example.invalid', 'Synthetic additional information' FROM cv_reference
        RETURNING debtor_detail_id
    )
    INSERT INTO cv_created (id, scenario) SELECT debtor_detail_id, 'full-employment' FROM inserted$sql$,
    'complete employment with nullable contact and additional fields is accepted'
);

SELECT lives_ok(
    $sql$WITH inserted AS (
        INSERT INTO public.debtor_detail DEFAULT VALUES
        RETURNING debtor_detail_id
    )
    INSERT INTO cv_created (id, scenario) SELECT debtor_detail_id, 'all-null' FROM inserted$sql$,
    'a row omitting every optional field is accepted'
);

SELECT lives_ok(
    $sql$WITH inserted AS (
        INSERT INTO public.debtor_detail (employee_reference, employer_telephone, employer_email)
        VALUES ('Synthetic employee reference', 'Synthetic telephone', 'synthetic@example.invalid')
        RETURNING debtor_detail_id
    )
    INSERT INTO cv_created (id, scenario) SELECT debtor_detail_id, 'partial-employment' FROM inserted$sql$,
    'partial employment is accepted because the database has no completeness CHECK'
);

SELECT results_eq(
    $actual$SELECT employer_name, employer_address_line_1, employer_country_id,
                    employee_reference, employer_telephone, employer_email
    FROM public.debtor_detail WHERE debtor_detail_id = (SELECT id FROM cv_created WHERE scenario = 'partial-employment')$actual$,
    $expected$VALUES (NULL::varchar, NULL::varchar, NULL::bigint, 'Synthetic employee reference'::varchar,
                     'Synthetic telephone'::varchar, 'synthetic@example.invalid'::varchar)$expected$,
    'partial employment retains contacts with the nullable employer triplet absent'
);

SELECT ok(
    (SELECT employer_name IS NULL AND employer_address_line_1 IS NULL AND employer_country_id IS NULL
     FROM public.debtor_detail WHERE debtor_detail_id = (SELECT id FROM cv_created WHERE scenario = 'all-null')),
    'omitting optional fields leaves the employer triplet NULL'
);

-- ---------------------------------------------------------------------------
-- Scenario: Native BIGINT fields reject overflow before accepting invalid identifiers.
-- Setup:    Update the captured row with a value beyond the BIGINT limit.
-- Expected: Identifier and employer Country overflow raise native SQLSTATE 22003.
-- ---------------------------------------------------------------------------

SELECT throws_ok(
    $sql$UPDATE public.debtor_detail SET debtor_detail_id = 9223372036854775808
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    '22003', NULL, 'debtor_detail_id outside BIGINT range is rejected'
);

SELECT throws_ok(
    $sql$UPDATE public.debtor_detail SET employer_country_id = 9223372036854775808
        WHERE debtor_detail_id = (SELECT id FROM cv_subject)$sql$,
    '22003', NULL, 'employer_country_id outside BIGINT range is rejected'
);

-- ---------------------------------------------------------------------------
-- Scenario: Every captured insertion receives a distinct generated Debtor Detail ID.
-- Setup:    Compare additional-only, Country-child, complete, empty and partial row IDs.
-- Expected: Five non-null generated IDs are distinct; sequence gaps are permitted.
-- ---------------------------------------------------------------------------

SELECT ok(
    (SELECT count(*) = 5 AND count(DISTINCT id) = 5 AND bool_and(id IS NOT NULL)
     FROM (SELECT id FROM cv_subject UNION ALL SELECT id FROM cv_created) generated),
    'all five inserted Debtor Details have distinct non-null generated identifiers'
);

SELECT * FROM finish();
ROLLBACK;
