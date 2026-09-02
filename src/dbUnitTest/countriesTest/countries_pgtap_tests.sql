BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;

SELECT plan(55);

SELECT has_table('public', 'countries', 'public.countries exists');
SELECT has_sequence('public', 'country_id_seq', 'public.country_id_seq exists');
SELECT is(
    (
        SELECT array_agg(column_name::text ORDER BY ordinal_position)
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'countries'
    ),
    ARRAY[
        'country_id',
        'cjs_code',
        'international_code',
        'gov_code',
        'country_name',
        'demonym',
        'date_used_from',
        'date_used_to',
        'active'
    ]::text[],
    'countries has exactly the promoted columns in order'
);

SELECT col_type_is('public', 'countries', 'country_id', 'bigint', 'country_id is bigint');
SELECT col_type_is('public', 'countries', 'cjs_code', 'smallint', 'cjs_code is smallint');
SELECT col_type_is(
    'public', 'countries', 'international_code', 'varchar(3)',
    'international_code is varchar(3)'
);
SELECT col_type_is('public', 'countries', 'gov_code', 'varchar(2)', 'gov_code is varchar(2)');
SELECT col_type_is(
    'public', 'countries', 'country_name', 'varchar(100)',
    'country_name is varchar(100)'
);
SELECT col_type_is('public', 'countries', 'demonym', 'varchar(100)', 'demonym is varchar(100)');
SELECT col_type_is('public', 'countries', 'date_used_from', 'date', 'date_used_from is date');
SELECT col_type_is('public', 'countries', 'date_used_to', 'date', 'date_used_to is date');
SELECT col_type_is('public', 'countries', 'active', 'boolean', 'active is boolean');

SELECT col_not_null('public', 'countries', 'country_id', 'country_id is required');
SELECT col_not_null('public', 'countries', 'cjs_code', 'cjs_code is required');
SELECT col_is_null(
    'public', 'countries', 'international_code',
    'international_code is optional'
);
SELECT col_is_null('public', 'countries', 'gov_code', 'gov_code is optional');
SELECT col_not_null('public', 'countries', 'country_name', 'country_name is required');
SELECT col_is_null('public', 'countries', 'demonym', 'demonym is optional');
SELECT col_not_null('public', 'countries', 'date_used_from', 'date_used_from is required');
SELECT col_is_null('public', 'countries', 'date_used_to', 'date_used_to is optional');
SELECT col_not_null('public', 'countries', 'active', 'active is required');

SELECT has_pk('public', 'countries', 'countries has a primary key');
SELECT col_is_pk('public', 'countries', 'country_id', 'country_id is the primary key');
SELECT has_unique('public', 'countries', 'countries has a unique constraint');
SELECT col_is_unique(
    'public', 'countries', 'international_code',
    'international_code has a unique constraint'
);
SELECT ok(
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.countries'::regclass
          AND conname = 'countries_pk'
          AND contype = 'p'
    ),
    'the primary key is named countries_pk'
);
SELECT ok(
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.countries'::regclass
          AND conname = 'countries_international_code_uk'
          AND contype = 'u'
    ),
    'the international code constraint is named countries_international_code_uk'
);
SELECT has_index(
    'public',
    'countries',
    'countries_active_country_name_idx',
    ARRAY['active', 'country_name'],
    'countries_active_country_name_idx uses active then country_name'
);
SELECT index_is_type(
    'public',
    'countries',
    'countries_active_country_name_idx',
    'btree',
    'countries_active_country_name_idx is a btree index'
);
SELECT is(
    (
        SELECT index_definition.indisunique
        FROM pg_index index_definition
        JOIN pg_class index_relation ON index_relation.oid = index_definition.indexrelid
        JOIN pg_namespace index_namespace ON index_namespace.oid = index_relation.relnamespace
        WHERE index_namespace.nspname = 'public'
          AND index_relation.relname = 'countries_active_country_name_idx'
    ),
    FALSE,
    'countries_active_country_name_idx is not unique'
);

SELECT ok(
    (
        SELECT column_default LIKE 'nextval(%country_id_seq%regclass)%'
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'countries'
          AND column_name = 'country_id'
    ),
    'country_id defaults to the country_id_seq next value'
);

SELECT ok(
    EXISTS (
        SELECT 1
        FROM pg_attrdef column_default
        JOIN pg_depend default_dependency
          ON default_dependency.classid = 'pg_attrdef'::regclass
         AND default_dependency.objid = column_default.oid
         AND default_dependency.refclassid = 'pg_class'::regclass
         AND default_dependency.refobjid = 'public.country_id_seq'::regclass
        WHERE column_default.adrelid = 'public.countries'::regclass
          AND column_default.adnum = (
              SELECT attribute.attnum
              FROM pg_attribute attribute
              WHERE attribute.attrelid = 'public.countries'::regclass
                AND attribute.attname = 'country_id'
                AND attribute.attisdropped IS FALSE
          )
    ),
    'country_id default depends on country_id_seq'
);
SELECT ok(
    EXISTS (
        SELECT 1
        FROM pg_class sequence_relation
        JOIN pg_namespace sequence_namespace
          ON sequence_namespace.oid = sequence_relation.relnamespace
        JOIN pg_depend ownership_dependency
          ON ownership_dependency.classid = 'pg_class'::regclass
         AND ownership_dependency.objid = sequence_relation.oid
         AND ownership_dependency.deptype = 'a'
        JOIN pg_attribute table_attribute
          ON table_attribute.attrelid = ownership_dependency.refobjid
         AND table_attribute.attnum = ownership_dependency.refobjsubid
        WHERE sequence_relation.relkind = 'S'
          AND sequence_namespace.nspname = 'public'
          AND sequence_relation.relname = 'country_id_seq'
          AND ownership_dependency.refobjid = 'public.countries'::regclass
          AND table_attribute.attname = 'country_id'
    ),
    'country_id_seq is owned by countries.country_id'
);
SELECT is(
    (
        SELECT data_type::text
        FROM pg_sequences
        WHERE schemaname = 'public'
          AND sequencename = 'country_id_seq'
    ),
    'bigint'::text,
    'country_id_seq generates bigint values'
);
SELECT is(
    (
        SELECT start_value
        FROM pg_sequences
        WHERE schemaname = 'public'
          AND sequencename = 'country_id_seq'
    ),
    1::bigint,
    'country_id_seq starts at one'
);
SELECT is(
    (
        SELECT increment_by
        FROM pg_sequences
        WHERE schemaname = 'public'
          AND sequencename = 'country_id_seq'
    ),
    1::bigint,
    'country_id_seq increments by one'
);
SELECT is(
    (
        SELECT cycle
        FROM pg_sequences
        WHERE schemaname = 'public'
          AND sequencename = 'country_id_seq'
    ),
    FALSE,
    'country_id_seq does not cycle'
);
SELECT is(
    (
        SELECT cache_size
        FROM pg_sequences
        WHERE schemaname = 'public'
          AND sequencename = 'country_id_seq'
    ),
    1::bigint,
    'country_id_seq caches one value'
);

SELECT lives_ok(
    $sql$
    INSERT INTO public.countries (
        cjs_code,
        international_code,
        gov_code,
        country_name,
        demonym,
        date_used_from,
        date_used_to,
        active
    ) VALUES (
        30001,
        'PT1',
        'P1',
        'pgTAP Complete Country',
        'pgTAP Tester',
        DATE '2025-01-01',
        DATE '2030-12-31',
        TRUE
    )
    $sql$,
    'a complete valid country can be inserted with a generated identifier'
);
SELECT ok(
    (
        SELECT country_id IS NOT NULL
        FROM public.countries
        WHERE cjs_code = 30001
    ),
    'a valid country receives a generated country_id'
);
SELECT lives_ok(
    $sql$
    INSERT INTO public.countries (cjs_code, country_name, date_used_from, active)
    VALUES
        (30002, 'pgTAP Nullable Country One', DATE '2025-01-01', TRUE),
        (30003, 'pgTAP Nullable Country Two', DATE '2025-01-01', TRUE)
    $sql$,
    'optional country fields can be omitted from multiple rows'
);
SELECT lives_ok(
    $sql$
    INSERT INTO public.countries (
        cjs_code, international_code, country_name, date_used_from, date_used_to, active
    ) VALUES (
        30004, 'END', 'pgTAP Inactive Country', DATE '2020-01-01', DATE '2024-12-31', FALSE
    )
    $sql$,
    'an inactive country with an end date can be inserted'
);

SELECT results_eq(
    $sql$
    SELECT
        cjs_code,
        international_code,
        gov_code,
        country_name,
        demonym,
        date_used_from,
        date_used_to,
        active
    FROM public.countries
    WHERE cjs_code BETWEEN 32001 AND 32010
    ORDER BY cjs_code
    $sql$,
    $values$
    VALUES
        (32001::smallint, 'GBR'::varchar(3), NULL::varchar(2), 'United Kingdom'::varchar(100),
            NULL::varchar(100), DATE '2025-01-01', NULL::date, TRUE),
        (32002::smallint, 'IRL'::varchar(3), NULL::varchar(2), 'Ireland'::varchar(100),
            NULL::varchar(100), DATE '2025-01-01', NULL::date, TRUE),
        (32003::smallint, 'FRA'::varchar(3), NULL::varchar(2), 'France'::varchar(100),
            NULL::varchar(100), DATE '2025-01-01', NULL::date, TRUE),
        (32004::smallint, 'DEU'::varchar(3), NULL::varchar(2), 'Germany'::varchar(100),
            NULL::varchar(100), DATE '2025-01-01', NULL::date, TRUE),
        (32005::smallint, 'ESP'::varchar(3), NULL::varchar(2), 'Spain'::varchar(100),
            NULL::varchar(100), DATE '2025-01-01', NULL::date, TRUE),
        (32006::smallint, 'ITA'::varchar(3), NULL::varchar(2), 'Italy'::varchar(100),
            NULL::varchar(100), DATE '2025-01-01', NULL::date, TRUE),
        (32007::smallint, 'POL'::varchar(3), NULL::varchar(2), 'Poland'::varchar(100),
            NULL::varchar(100), DATE '2025-01-01', NULL::date, TRUE),
        (32008::smallint, 'USA'::varchar(3), NULL::varchar(2), 'United States'::varchar(100),
            NULL::varchar(100), DATE '2025-01-01', NULL::date, TRUE),
        (32009::smallint, 'IND'::varchar(3), NULL::varchar(2), 'India'::varchar(100),
            NULL::varchar(100), DATE '2025-01-01', NULL::date, TRUE),
        (32010::smallint, 'PAK'::varchar(3), NULL::varchar(2), 'Pakistan'::varchar(100),
            NULL::varchar(100), DATE '2025-01-01', NULL::date, TRUE)
    $values$,
    'the exact development country fixtures are available'
);
SELECT ok(
    (
        SELECT count(*) = 10
           AND count(DISTINCT country_id) = 10
           AND bool_and(country_id > 0)
        FROM public.countries
        WHERE cjs_code BETWEEN 32001 AND 32010
    ),
    'development country fixtures have generated identifiers'
);

INSERT INTO public.countries (
    country_id, cjs_code, international_code, country_name, date_used_from, active
) VALUES (
    990001, 30100, 'DPK', 'pgTAP Duplicate Key Seed', DATE '2025-01-01', TRUE
);
INSERT INTO public.countries (
    cjs_code, international_code, country_name, date_used_from, active
) VALUES (
    30101, 'DUI', 'pgTAP Duplicate International Seed', DATE '2025-01-01', TRUE
);

SELECT throws_ok(
    $sql$
    INSERT INTO public.countries (
        country_id, cjs_code, country_name, date_used_from, active
    ) VALUES (
        990001, 30102, 'pgTAP Duplicate Key Country', DATE '2025-01-01', TRUE
    )
    $sql$,
    '23505',
    NULL,
    'duplicate country_id is rejected'
);
SELECT throws_ok(
    $sql$
    INSERT INTO public.countries (
        cjs_code, international_code, country_name, date_used_from, active
    ) VALUES (
        30103, 'DUI', 'pgTAP Duplicate International Country', DATE '2025-01-01', TRUE
    )
    $sql$,
    '23505',
    NULL,
    'duplicate international_code is rejected'
);
SELECT throws_ok(
    $sql$
    INSERT INTO public.countries (
        country_id, cjs_code, country_name, date_used_from, active
    ) VALUES (
        NULL, 30104, 'pgTAP Null Identifier Country', DATE '2025-01-01', TRUE
    )
    $sql$,
    '23502',
    NULL,
    'null country_id is rejected'
);
SELECT throws_ok(
    $sql$
    INSERT INTO public.countries (cjs_code, country_name, date_used_from, active)
    VALUES (NULL, 'pgTAP Null CJS Country', DATE '2025-01-01', TRUE)
    $sql$,
    '23502',
    NULL,
    'null cjs_code is rejected'
);
SELECT throws_ok(
    $sql$
    INSERT INTO public.countries (cjs_code, country_name, date_used_from, active)
    VALUES (30106, NULL, DATE '2025-01-01', TRUE)
    $sql$,
    '23502',
    NULL,
    'null country_name is rejected'
);
SELECT throws_ok(
    $sql$
    INSERT INTO public.countries (cjs_code, country_name, date_used_from, active)
    VALUES (30107, 'pgTAP Null Start Country', NULL, TRUE)
    $sql$,
    '23502',
    NULL,
    'null date_used_from is rejected'
);
SELECT throws_ok(
    $sql$
    INSERT INTO public.countries (cjs_code, country_name, date_used_from, active)
    VALUES (30108, 'pgTAP Null Active Country', DATE '2025-01-01', NULL)
    $sql$,
    '23502',
    NULL,
    'null active is rejected'
);
SELECT throws_ok(
    $sql$
    INSERT INTO public.countries (
        cjs_code, international_code, country_name, date_used_from, active
    ) VALUES (
        30109, 'LONG', 'pgTAP Long International Country', DATE '2025-01-01', TRUE
    )
    $sql$,
    '22001',
    NULL,
    'international_code longer than three characters is rejected'
);
SELECT throws_ok(
    $sql$
    INSERT INTO public.countries (
        cjs_code, gov_code, country_name, date_used_from, active
    ) VALUES (
        30110, 'GOV', 'pgTAP Long Government Country', DATE '2025-01-01', TRUE
    )
    $sql$,
    '22001',
    NULL,
    'gov_code longer than two characters is rejected'
);
SELECT throws_ok(
    $sql$
    INSERT INTO public.countries (cjs_code, country_name, date_used_from, active)
    VALUES (30111, repeat('N', 101), DATE '2025-01-01', TRUE)
    $sql$,
    '22001',
    NULL,
    'country_name longer than 100 characters is rejected'
);
SELECT throws_ok(
    $sql$
    INSERT INTO public.countries (
        cjs_code, country_name, demonym, date_used_from, active
    ) VALUES (
        30112, 'pgTAP Long Demonym Country', repeat('D', 101), DATE '2025-01-01', TRUE
    )
    $sql$,
    '22001',
    NULL,
    'demonym longer than 100 characters is rejected'
);

SELECT * FROM finish();
ROLLBACK;
