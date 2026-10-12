/**
 * OPAL Program
 *
 * MODULE      : parties_pgtap_tests.sql
 *
 * DESCRIPTION : Verify the Parties schema and integrity rules.
 *
 * CHANGE HISTORY:
 *
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * 03/10/2026  Chris Larkin  PO-10654      Initial pgTAP test suite.
 */

-- PO-10654: V1_20__create_parties_table.sql
-- Boundary applicability: fresh DB-01; direct PostgreSQL catalogue and behaviour.
-- Existing-state validation: Not run - user-approved initial-schema scope exception.
-- Initial delivery assumes no established affected account workflow; no upgrade path is claimed.
-- Expected literals were checked independently against promoted TDIA v162 and the approved plan.
\set ON_ERROR_STOP on
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SET LOCAL search_path = public, pg_temp;
SET LOCAL TIME ZONE 'UTC';
SELECT plan(105);

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

SELECT has_table('public', 'parties', 'public.parties exists');

SELECT is(
    (SELECT jsonb_agg(jsonb_build_array(
        attname::text, format_type(atttypid, atttypmod), attnotnull
    ) ORDER BY attnum)
    FROM pg_attribute
    WHERE attrelid = 'public.parties'::regclass AND attnum > 0 AND NOT attisdropped),
    '[["party_id","bigint",true],["organisation","boolean",false],["organisation_name","character varying(80)",false],["foreign_authority_reference","text",false],["surname","character varying(50)",false],["forenames","character varying(50)",false],["title","character varying(20)",false],["birth_date","date",false],["national_insurance_number","character varying(10)",false],["address_line_1","character varying(35)",true],["address_line_2","character varying(35)",false],["address_line_3","character varying(35)",false],["address_line_4","character varying(35)",false],["address_line_5","character varying(35)",false],["postcode","character varying(10)",false],["telephone_home","character varying(35)",false],["telephone_business","character varying(35)",false],["telephone_mobile","character varying(35)",false],["email_1","character varying(80)",false],["email_2","character varying(80)",false],["restrict_personal_information","boolean",true],["restriction_reason","text",false],["country_id","bigint",true],["account_type","t_party_account_type_enum",false],["last_changed_date","timestamp without time zone",false]]'::jsonb,
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
     WHERE attrelid = 'public.parties'::regclass AND attnum > 0 AND NOT attisdropped),
    ARRAY[
        'Unique identifier of the party',
        'Whether the party is an organisation rather than a person',
        'Organisation name; null for a person',
        'Reference supplied if the party is an organisation',
        'Person surname; null for an organisation',
        'Person forenames; null for an organisation',
        'Person title; null for an organisation',
        'Person date of birth',
        'Person National Insurance number',
        'Address line 1',
        'Address line 2',
        'Address line 3',
        'Address line 4',
        'Address line 5',
        'Postcode',
        'Home telephone number',
        'Business telephone number',
        'Mobile telephone number',
        'Primary email address',
        'Secondary email address',
        'Whether access to the party''s personal information is restricted',
        'Reason personal information is restricted; mandatory only when the restriction flag is selected',
        'Country where the party resides',
        'Account type boundary used to prevent cross-account party merging',
        'Date the party was last changed'
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
     WHERE conrelid = 'public.parties'::regclass AND contype IN ('p', 'u', 'f', 'c')),
    ARRAY['parties_country_id_fk', 'parties_pk']::text[],
    'exact table constraint inventory, including the absence of business CHECKs'
);

SELECT col_is_pk('public', 'parties', 'party_id', 'party_id is the sole primary-key column');

SELECT is(
    (SELECT array_agg(indexname::text ORDER BY indexname) FROM pg_indexes
     WHERE schemaname = 'public' AND tablename = 'parties'),
    ARRAY['parties_country_id_idx', 'parties_pk']::text[],
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
    WHERE index_definition.indrelid = 'public.parties'::regclass),
    '[["parties_country_id_idx",["country_id"],"btree",false,false,true,true,null],["parties_pk",["party_id"],"btree",true,true,true,true,null]]'::jsonb,
    'indexes have exact ordered keys, uniqueness, ready valid B-tree state and no predicates'
);

SELECT is(
    (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'public.parties'::regclass AND NOT tgisinternal),
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
    WHERE constraint_definition.conrelid = 'public.parties'::regclass
      AND constraint_definition.contype = 'f'),
    '[["parties_country_id_fk",["country_id"],"public","countries",["country_id"],"a","a","s",false,false,true]]'::jsonb,
    'Country FK endpoint and immediate NO ACTION properties match the contract'
);

-- ---------------------------------------------------------------------------
-- Scenario: Identifiers use an owned BIGINT sequence and only the ID has a default.
-- Setup:    Inspect sequence configuration, dependency, nextval expression and identity flags.
-- Expected: START 1, INCREMENT 1, CACHE 1 and NO CYCLE are retained; no other default is added.
-- ---------------------------------------------------------------------------

SELECT has_sequence('public', 'party_id_seq', 'public.party_id_seq exists');

SELECT is(pg_get_serial_sequence('public.parties', 'party_id'),
          'public.party_id_seq', 'the identifier sequence is owned by the identifier column');

SELECT is(
    (SELECT seqtypid::regtype::text || ':' || seqstart || ':' || seqincrement || ':' || seqcache || ':' || seqcycle
     FROM pg_sequence WHERE seqrelid = 'public.party_id_seq'::regclass),
    'bigint:1:1:1:false', 'exact BIGINT sequence start, increment, cache and no-cycle contract'
);

SELECT is(
    (SELECT pg_get_expr(adbin, adrelid) FROM pg_attrdef
     WHERE adrelid = 'public.parties'::regclass
       AND adnum = (SELECT attnum FROM pg_attribute
                    WHERE attrelid = 'public.parties'::regclass AND attname = 'party_id')),
    'nextval(''party_id_seq''::regclass)', 'the identifier default calls its exact sequence'
);

SELECT ok(
    EXISTS (SELECT 1 FROM pg_attrdef column_default
            JOIN pg_depend dependency ON dependency.classid = 'pg_attrdef'::regclass
             AND dependency.objid = column_default.oid AND dependency.refclassid = 'pg_class'::regclass
             AND dependency.refobjid = 'public.party_id_seq'::regclass
            WHERE column_default.adrelid = 'public.parties'::regclass
              AND column_default.adnum = (SELECT attnum FROM pg_attribute
                  WHERE attrelid = 'public.parties'::regclass AND attname = 'party_id')),
    'identifier default depends on its owned sequence'
);

SELECT ok(
    EXISTS (SELECT 1 FROM pg_depend dependency
            WHERE dependency.classid = 'pg_class'::regclass
              AND dependency.objid = 'public.party_id_seq'::regclass
              AND dependency.refclassid = 'pg_class'::regclass
              AND dependency.refobjid = 'public.parties'::regclass
              AND dependency.refobjsubid = (SELECT attnum FROM pg_attribute
                  WHERE attrelid = 'public.parties'::regclass AND attname = 'party_id')
              AND dependency.deptype = 'a'),
    'the sequence has the explicit OWNED BY column dependency'
);

SELECT is((SELECT count(*) FROM pg_attrdef WHERE adrelid = 'public.parties'::regclass),
          1::bigint, 'only the identifier has a database default');

SELECT is(
    (SELECT count(*) FROM pg_attribute
     WHERE attrelid = 'public.parties'::regclass AND attnum > 0 AND NOT attisdropped AND attidentity <> ''),
    0::bigint, 'no identity column replaces the explicit owned sequence'
);

-- ---------------------------------------------------------------------------
-- Scenario: A minimal source-valid row is accepted with a generated identifier.
-- Setup:    Insert only mandatory values and capture the returned ID.
-- Expected: The row supports isolated NULL, boundary and integrity checks.
-- ---------------------------------------------------------------------------

SELECT lives_ok(
    $sql$WITH inserted AS (
        INSERT INTO public.parties (address_line_1, restrict_personal_information, country_id)
        SELECT 'Synthetic Address', FALSE, country_id FROM cv_reference
        RETURNING party_id
    )
    INSERT INTO cv_subject SELECT party_id FROM inserted$sql$,
    'a minimal source-valid row is inserted with its generated ID captured'
);

SELECT ok((SELECT id IS NOT NULL FROM cv_subject), 'the minimal row receives a non-null generated identifier');

-- ---------------------------------------------------------------------------
-- Scenario: Each required and optional column follows its declared NULL contract.
-- Setup:    Update the captured valid row to NULL one column at a time.
-- Expected: Required fields raise 23502; every nullable field accepts NULL.
-- ---------------------------------------------------------------------------

SELECT throws_ok(
    $sql$UPDATE public.parties SET party_id = NULL
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    '23502', NULL, 'party_id rejects NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET organisation = NULL
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'organisation accepts NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET organisation_name = NULL
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'organisation_name accepts NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET foreign_authority_reference = NULL
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'foreign_authority_reference accepts NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET surname = NULL
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'surname accepts NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET forenames = NULL
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'forenames accepts NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET title = NULL
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'title accepts NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET birth_date = NULL
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'birth_date accepts NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET national_insurance_number = NULL
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'national_insurance_number accepts NULL'
);

SELECT throws_ok(
    $sql$UPDATE public.parties SET address_line_1 = NULL
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    '23502', NULL, 'address_line_1 rejects NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET address_line_2 = NULL
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'address_line_2 accepts NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET address_line_3 = NULL
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'address_line_3 accepts NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET address_line_4 = NULL
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'address_line_4 accepts NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET address_line_5 = NULL
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'address_line_5 accepts NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET postcode = NULL
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'postcode accepts NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET telephone_home = NULL
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'telephone_home accepts NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET telephone_business = NULL
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'telephone_business accepts NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET telephone_mobile = NULL
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'telephone_mobile accepts NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET email_1 = NULL
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'email_1 accepts NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET email_2 = NULL
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'email_2 accepts NULL'
);

SELECT throws_ok(
    $sql$UPDATE public.parties SET restrict_personal_information = NULL
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    '23502', NULL, 'restrict_personal_information rejects NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET restriction_reason = NULL
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'restriction_reason accepts NULL'
);

SELECT throws_ok(
    $sql$UPDATE public.parties SET country_id = NULL
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    '23502', NULL, 'country_id rejects NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET account_type = NULL
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'account_type accepts NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET last_changed_date = NULL
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'last_changed_date accepts NULL'
);

-- ---------------------------------------------------------------------------
-- Scenario: Every bounded text field accepts its limit and rejects one extra character.
-- Setup:    Update the captured row at each promoted VARCHAR boundary.
-- Expected: n characters succeed; n+1 raises native SQLSTATE 22001.
-- ---------------------------------------------------------------------------

SELECT lives_ok(
    $sql$UPDATE public.parties SET organisation_name = repeat('X', 80)
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'organisation_name accepts 80 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.parties SET organisation_name = repeat('X', 81)
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'organisation_name rejects 81 characters'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET surname = repeat('X', 50)
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'surname accepts 50 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.parties SET surname = repeat('X', 51)
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'surname rejects 51 characters'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET forenames = repeat('X', 50)
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'forenames accepts 50 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.parties SET forenames = repeat('X', 51)
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'forenames rejects 51 characters'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET title = repeat('X', 20)
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'title accepts 20 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.parties SET title = repeat('X', 21)
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'title rejects 21 characters'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET national_insurance_number = repeat('X', 10)
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'national_insurance_number accepts 10 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.parties SET national_insurance_number = repeat('X', 11)
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'national_insurance_number rejects 11 characters'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET address_line_1 = repeat('X', 35)
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'address_line_1 accepts 35 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.parties SET address_line_1 = repeat('X', 36)
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'address_line_1 rejects 36 characters'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET address_line_2 = repeat('X', 35)
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'address_line_2 accepts 35 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.parties SET address_line_2 = repeat('X', 36)
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'address_line_2 rejects 36 characters'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET address_line_3 = repeat('X', 35)
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'address_line_3 accepts 35 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.parties SET address_line_3 = repeat('X', 36)
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'address_line_3 rejects 36 characters'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET address_line_4 = repeat('X', 35)
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'address_line_4 accepts 35 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.parties SET address_line_4 = repeat('X', 36)
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'address_line_4 rejects 36 characters'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET address_line_5 = repeat('X', 35)
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'address_line_5 accepts 35 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.parties SET address_line_5 = repeat('X', 36)
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'address_line_5 rejects 36 characters'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET postcode = repeat('X', 10)
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'postcode accepts 10 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.parties SET postcode = repeat('X', 11)
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'postcode rejects 11 characters'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET telephone_home = repeat('X', 35)
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'telephone_home accepts 35 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.parties SET telephone_home = repeat('X', 36)
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'telephone_home rejects 36 characters'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET telephone_business = repeat('X', 35)
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'telephone_business accepts 35 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.parties SET telephone_business = repeat('X', 36)
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'telephone_business rejects 36 characters'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET telephone_mobile = repeat('X', 35)
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'telephone_mobile accepts 35 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.parties SET telephone_mobile = repeat('X', 36)
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'telephone_mobile rejects 36 characters'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET email_1 = repeat('X', 80)
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'email_1 accepts 80 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.parties SET email_1 = repeat('X', 81)
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'email_1 rejects 81 characters'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET email_2 = repeat('X', 80)
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'email_2 accepts 80 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.parties SET email_2 = repeat('X', 81)
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'email_2 rejects 81 characters'
);

-- ---------------------------------------------------------------------------
-- Scenario: Primary keys reject a second row with the captured identifier.
-- Setup:    Attempt an otherwise-valid insert using the minimal row ID.
-- Expected: A duplicate primary key raises SQLSTATE 23505.
-- ---------------------------------------------------------------------------

SELECT throws_ok(
    $sql$INSERT INTO public.parties (party_id, address_line_1, restrict_personal_information, country_id)
        SELECT id, 'Synthetic duplicate', FALSE, country_id FROM cv_subject CROSS JOIN cv_reference$sql$,
    '23505', NULL, 'duplicate party_id is rejected'
);

-- ---------------------------------------------------------------------------
-- Scenario: Only valid supplied Country references are accepted.
-- Setup:    Assert the missing key is absent, then update the captured row to it.
-- Expected: A nonexistent Country raises 23503; an existing reference succeeds.
-- ---------------------------------------------------------------------------

SELECT is((SELECT count(*) FROM public.countries WHERE country_id = -20654),
          0::bigint, 'the missing Country fixture key is absent');

SELECT lives_ok(
    $sql$UPDATE public.parties SET country_id = (SELECT country_id FROM cv_reference)
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'an existing Country reference is accepted'
);

SELECT throws_ok(
    $sql$UPDATE public.parties SET country_id = -20654
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    '23503', NULL, 'a missing Country reference is rejected'
);

-- ---------------------------------------------------------------------------
-- Scenario: A referenced synthetic Country cannot be deleted.
-- Setup:    Create one dedicated Country and a child that refers only to that parent.
-- Expected: The object's own Country FK raises 23503 without relying on other reference relationships.
-- ---------------------------------------------------------------------------

SELECT lives_ok(
    $sql$INSERT INTO public.countries (country_id, cjs_code, country_name, date_used_from, active)
        VALUES (-10654, 31554, 'Synthetic parties Country', DATE '2026-01-01', TRUE)$sql$,
    'a dedicated synthetic Country is inserted without changing existing rows'
);

SELECT lives_ok(
    $sql$WITH inserted AS (
        INSERT INTO public.parties (address_line_1, restrict_personal_information, country_id)
        VALUES ('Synthetic Country relationship', FALSE, -10654)
        RETURNING party_id
    )
    INSERT INTO cv_created (id, scenario) SELECT party_id, 'country-child' FROM inserted$sql$,
    'a Party references the dedicated synthetic Country'
);

SELECT throws_ok(
    $sql$DELETE FROM public.countries WHERE country_id = -10654$sql$,
    '23503', NULL, 'deleting the dedicated referenced Country is rejected'
);

-- ---------------------------------------------------------------------------
-- Scenario: Every Party account-type label is usable and unsupported labels fail.
-- Setup:    Inspect enum labels in order, cast each approved value and assign both to the valid row.
-- Expected: Only Respondent and Minor Creditor are accepted; an unsupported label raises 22P02.
-- ---------------------------------------------------------------------------

SELECT is(
    (SELECT array_agg(enumlabel::text ORDER BY enumsortorder) FROM pg_enum
     WHERE enumtypid = 'public.t_party_account_type_enum'::regtype),
    ARRAY['Respondent', 'Minor Creditor']::text[], 'exact Party account-type enum labels in source order'
);

SELECT lives_ok(
    $sql$SELECT 'Respondent'::public.t_party_account_type_enum$sql$,
    'Respondent casts to the Party account-type enum'
);

SELECT lives_ok(
    $sql$SELECT 'Minor Creditor'::public.t_party_account_type_enum$sql$,
    'Minor Creditor casts to the Party account-type enum'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET account_type = 'Respondent'
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'a Party accepts Respondent account_type'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET account_type = 'Minor Creditor'
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'a Party accepts Minor Creditor account_type'
);

SELECT throws_ok(
    $sql$UPDATE public.parties SET account_type = 'Unsupported'
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    '22P02', NULL, 'unsupported Party account_type is rejected'
);

-- ---------------------------------------------------------------------------
-- Scenario: People, organisations and unspecified identity fields use the nullable contract.
-- Setup:    Insert a person and organisation; exercise mixed fields on the captured minimal row.
-- Expected: All are accepted without a person/organisation pairing CHECK.
-- ---------------------------------------------------------------------------

SELECT lives_ok(
    $sql$WITH inserted AS (
        INSERT INTO public.parties (organisation, surname, forenames, address_line_1,
                                    restrict_personal_information, country_id, account_type)
        SELECT FALSE, 'Synthetic surname', 'Synthetic forenames', 'Synthetic person address',
               FALSE, country_id, 'Respondent' FROM cv_reference
        RETURNING party_id
    )
    INSERT INTO cv_created (id, scenario) SELECT party_id, 'person' FROM inserted$sql$,
    'a person row with surname and forenames is accepted'
);

SELECT lives_ok(
    $sql$WITH inserted AS (
        INSERT INTO public.parties (organisation, organisation_name, address_line_1,
                                    restrict_personal_information, country_id, account_type)
        SELECT TRUE, 'Synthetic organisation', 'Synthetic organisation address',
               TRUE, country_id, 'Minor Creditor' FROM cv_reference
        RETURNING party_id
    )
    INSERT INTO cv_created (id, scenario) SELECT party_id, 'organisation' FROM inserted$sql$,
    'an organisation row with organisation_name is accepted'
);

SELECT lives_ok(
    $sql$UPDATE public.parties SET organisation = TRUE, surname = 'Synthetic mixed surname', forenames = 'Synthetic mixed forenames', organisation_name = NULL
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'mixed or absent person/organisation fields are accepted without a pairing CHECK'
);

-- ---------------------------------------------------------------------------
-- Scenario: The restriction flag and optional reason are independent database fields.
-- Setup:    Set TRUE without a reason and FALSE with a supplied reason on the same valid row.
-- Expected: Both values persist; the table adds no reason-completeness CHECK.
-- ---------------------------------------------------------------------------

SELECT lives_ok(
    $sql$UPDATE public.parties SET restrict_personal_information = TRUE, restriction_reason = NULL
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'TRUE restriction flag accepts a NULL reason'
);

SELECT results_eq($actual$SELECT restrict_personal_information, restriction_reason FROM public.parties
                   WHERE party_id = (SELECT id FROM cv_subject)$actual$,
                  $expected$VALUES (true, NULL::text)$expected$, 'TRUE flag and NULL reason persist');

SELECT lives_ok(
    $sql$UPDATE public.parties SET restrict_personal_information = FALSE, restriction_reason = 'Synthetic optional reason'
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'FALSE restriction flag accepts a supplied reason'
);

SELECT results_eq($actual$SELECT restrict_personal_information, restriction_reason FROM public.parties
                   WHERE party_id = (SELECT id FROM cv_subject)$actual$,
                  $expected$VALUES (false, 'Synthetic optional reason'::text)$expected$, 'FALSE flag and optional reason persist');

-- ---------------------------------------------------------------------------
-- Scenario: Dates and timestamp values are stored under the UTC convention.
-- Setup:    Supply a DATE and TIMESTAMP without time zone, then try malformed typed values.
-- Expected: Stored values are unchanged; malformed inputs raise native 22007.
-- ---------------------------------------------------------------------------

SELECT lives_ok(
    $sql$UPDATE public.parties SET birth_date = DATE '2000-01-02', last_changed_date = TIMESTAMP '2026-10-03 12:34:56.123456'
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    'valid DATE and UTC timestamp values are accepted'
);

SELECT results_eq($actual$SELECT birth_date, last_changed_date FROM public.parties
                   WHERE party_id = (SELECT id FROM cv_subject)$actual$,
                  $expected$VALUES (DATE '2000-01-02', TIMESTAMP '2026-10-03 12:34:56.123456')$expected$,
                  'date and timestamp values persist unchanged without timezone conversion');

SELECT throws_ok(
    $sql$UPDATE public.parties SET birth_date = 'not-a-date'
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    '22007', NULL, 'malformed birth_date is rejected'
);

SELECT throws_ok(
    $sql$UPDATE public.parties SET last_changed_date = 'not-a-timestamp'
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    '22007', NULL, 'malformed last_changed_date is rejected'
);

-- ---------------------------------------------------------------------------
-- Scenario: Native BIGINT and BOOLEAN types reject unrepresentable or malformed inputs.
-- Setup:    Update the isolated row with overflow IDs and invalid boolean input.
-- Expected: BIGINT overflow raises 22003; malformed boolean raises 22P02.
-- ---------------------------------------------------------------------------

SELECT throws_ok(
    $sql$UPDATE public.parties SET party_id = 9223372036854775808
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    '22003', NULL, 'party_id outside BIGINT range is rejected'
);

SELECT throws_ok(
    $sql$UPDATE public.parties SET country_id = 9223372036854775808
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    '22003', NULL, 'country_id outside BIGINT range is rejected'
);

SELECT throws_ok(
    $sql$UPDATE public.parties SET organisation = 'not-a-boolean'
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    '22P02', NULL, 'malformed organisation boolean is rejected'
);

SELECT throws_ok(
    $sql$UPDATE public.parties SET restrict_personal_information = 'not-a-boolean'
        WHERE party_id = (SELECT id FROM cv_subject)$sql$,
    '22P02', NULL, 'malformed restriction boolean is rejected'
);

-- ---------------------------------------------------------------------------
-- Scenario: Every captured insertion receives a distinct generated Party ID.
-- Setup:    Compare the minimal, person, organisation and dedicated-Country child IDs.
-- Expected: Four non-null generated IDs are distinct; sequence gaps are permitted.
-- ---------------------------------------------------------------------------

SELECT ok(
    (SELECT count(*) = 4 AND count(DISTINCT id) = 4 AND bool_and(id IS NOT NULL)
     FROM (SELECT id FROM cv_subject UNION ALL SELECT id FROM cv_created) generated),
    'all four inserted Parties have distinct non-null generated identifiers'
);

SELECT * FROM finish();
ROLLBACK;
