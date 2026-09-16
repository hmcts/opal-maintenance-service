BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;

SELECT plan(56);

SELECT ok(
    EXISTS (
        SELECT 1
        FROM pg_type data_type
        JOIN pg_namespace type_namespace ON type_namespace.oid = data_type.typnamespace
        WHERE type_namespace.nspname = 'public'
          AND data_type.typname = 't_business_unit_type_enum'
          AND data_type.typtype = 'e'
    ),
    'public.t_business_unit_type_enum exists as an enum'
);
SELECT is(
    (
        SELECT array_agg(enum_value.enumlabel::text ORDER BY enum_value.enumsortorder)
        FROM pg_enum enum_value
        JOIN pg_type data_type ON data_type.oid = enum_value.enumtypid
        JOIN pg_namespace type_namespace ON type_namespace.oid = data_type.typnamespace
        WHERE type_namespace.nspname = 'public'
          AND data_type.typname = 't_business_unit_type_enum'
    ),
    ARRAY['Area', 'Accounting Division']::text[],
    't_business_unit_type_enum has exactly the promoted values in order'
);

SELECT has_table('public', 'business_units', 'public.business_units exists');
SELECT is(
    (
        SELECT array_agg(column_name::text ORDER BY ordinal_position)
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'business_units'
    ),
    ARRAY[
        'business_unit_id',
        'business_unit_code',
        'business_unit_name',
        'business_unit_type',
        'account_number_prefix',
        'parent_business_unit_id',
        'opal_domain',
        'welsh_language',
        'account_number_suffix'
    ]::text[],
    'business_units has exactly the promoted columns in order'
);

SELECT col_type_is('public', 'business_units', 'business_unit_id', 'smallint', 'business_unit_id is smallint');
SELECT col_type_is('public', 'business_units', 'business_unit_code', 'varchar(4)', 'business_unit_code is varchar(4)');
SELECT col_type_is('public', 'business_units', 'business_unit_name', 'varchar(200)', 'business_unit_name is varchar(200)');
SELECT col_type_is(
    'public', 'business_units', 'business_unit_type', 't_business_unit_type_enum',
    'business_unit_type uses t_business_unit_type_enum'
);
SELECT col_type_is(
    'public', 'business_units', 'account_number_prefix', 'varchar(2)',
    'account_number_prefix is varchar(2)'
);
SELECT col_type_is(
    'public', 'business_units', 'parent_business_unit_id', 'smallint',
    'parent_business_unit_id is smallint'
);
SELECT col_type_is('public', 'business_units', 'opal_domain', 'varchar(30)', 'opal_domain is varchar(30)');
SELECT col_type_is('public', 'business_units', 'welsh_language', 'boolean', 'welsh_language is boolean');
SELECT col_type_is(
    'public', 'business_units', 'account_number_suffix', 'varchar(2)',
    'account_number_suffix is varchar(2)'
);

SELECT col_not_null('public', 'business_units', 'business_unit_id', 'business_unit_id is required');
SELECT col_not_null('public', 'business_units', 'business_unit_code', 'business_unit_code is required');
SELECT col_not_null('public', 'business_units', 'business_unit_name', 'business_unit_name is required');
SELECT col_not_null('public', 'business_units', 'business_unit_type', 'business_unit_type is required');
SELECT col_not_null(
    'public', 'business_units', 'account_number_prefix',
    'account_number_prefix is required'
);
SELECT col_is_null(
    'public', 'business_units', 'parent_business_unit_id',
    'parent_business_unit_id is optional'
);
SELECT col_is_null('public', 'business_units', 'opal_domain', 'opal_domain is optional');
SELECT col_not_null('public', 'business_units', 'welsh_language', 'welsh_language is required');
SELECT col_is_null(
    'public', 'business_units', 'account_number_suffix',
    'account_number_suffix is optional'
);

SELECT is(
    (
        SELECT count(*)
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'business_units'
          AND column_name = 'active'
    ),
    0::bigint,
    'business_units does not contain active'
);
SELECT is(
    (
        SELECT column_default
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'business_units'
          AND column_name = 'business_unit_id'
    ),
    NULL,
    'business_unit_id has no generated default'
);
SELECT ok(
    NOT EXISTS (
        SELECT 1
        FROM pg_depend ownership_dependency
        JOIN pg_class sequence_relation ON sequence_relation.oid = ownership_dependency.objid
        WHERE ownership_dependency.classid = 'pg_class'::regclass
          AND ownership_dependency.refclassid = 'pg_class'::regclass
          AND ownership_dependency.refobjid = 'public.business_units'::regclass
          AND ownership_dependency.deptype = 'a'
          AND sequence_relation.relkind = 'S'
    ),
    'business_units owns no sequence'
);
SELECT is(
    (
        SELECT array_agg(
            col_description(table_attribute.attrelid, table_attribute.attnum)
            ORDER BY table_attribute.attnum
        )
        FROM pg_attribute table_attribute
        WHERE table_attribute.attrelid = 'public.business_units'::regclass
          AND table_attribute.attnum > 0
          AND table_attribute.attisdropped IS FALSE
    ),
    ARRAY[
        'Primary key supplied by the authoritative Business Unit catalogue',
        'Unique Business Unit code',
        'Business Unit display name',
        'Area or Accounting Division',
        'Accounting Division prefix used before account numbers',
        'Self-reference to the parent Business Unit',
        'When business unit type is Accounting Division, then this value is the opal domain that the business unit is owned by',
        'Whether Welsh-language operation applies',
        'The Accounting Division suffix used with Account Numbers'
    ]::text[],
    'column comments match the verbatim TDIA descriptions in column order'
);

SELECT has_pk('public', 'business_units', 'business_units has a primary key');
SELECT col_is_pk(
    'public', 'business_units', 'business_unit_id',
    'business_unit_id is the primary key'
);
SELECT ok(
    EXISTS (
        SELECT 1
        FROM pg_constraint table_constraint
        WHERE table_constraint.conrelid = 'public.business_units'::regclass
          AND table_constraint.conname = 'business_units_pk'
          AND table_constraint.contype = 'p'
    ),
    'the primary key is named business_units_pk'
);
SELECT has_unique('public', 'business_units', 'business_units has a unique constraint');
SELECT col_is_unique(
    'public', 'business_units', 'business_unit_code',
    'business_unit_code has a unique constraint'
);
SELECT ok(
    EXISTS (
        SELECT 1
        FROM pg_constraint table_constraint
        WHERE table_constraint.conrelid = 'public.business_units'::regclass
          AND table_constraint.conname = 'business_units_business_unit_code_uk'
          AND table_constraint.contype = 'u'
    ),
    'the business unit code constraint has the promoted name'
);
SELECT ok(
    EXISTS (
        SELECT 1
        FROM pg_constraint table_constraint
        WHERE table_constraint.conrelid = 'public.business_units'::regclass
          AND table_constraint.confrelid = 'public.business_units'::regclass
          AND table_constraint.conname = 'bu_parent_business_unit_id_fk'
          AND table_constraint.contype = 'f'
          AND table_constraint.conkey = ARRAY[
              (
                  SELECT table_attribute.attnum
                  FROM pg_attribute table_attribute
                  WHERE table_attribute.attrelid = 'public.business_units'::regclass
                    AND table_attribute.attname = 'parent_business_unit_id'
                    AND table_attribute.attisdropped IS FALSE
              )
          ]::smallint[]
          AND table_constraint.confkey = ARRAY[
              (
                  SELECT table_attribute.attnum
                  FROM pg_attribute table_attribute
                  WHERE table_attribute.attrelid = 'public.business_units'::regclass
                    AND table_attribute.attname = 'business_unit_id'
                    AND table_attribute.attisdropped IS FALSE
              )
          ]::smallint[]
    ),
    'bu_parent_business_unit_id_fk is the promoted self-reference'
);
SELECT has_index(
    'public',
    'business_units',
    'business_units_parent_business_unit_id_idx',
    ARRAY['parent_business_unit_id'],
    'the parent business unit index uses parent_business_unit_id'
);
SELECT index_is_type(
    'public',
    'business_units',
    'business_units_parent_business_unit_id_idx',
    'btree',
    'the parent business unit index is a btree index'
);
SELECT is(
    (
        SELECT index_definition.indisunique
        FROM pg_index index_definition
        JOIN pg_class index_relation ON index_relation.oid = index_definition.indexrelid
        JOIN pg_namespace index_namespace ON index_namespace.oid = index_relation.relnamespace
        WHERE index_namespace.nspname = 'public'
          AND index_relation.relname = 'business_units_parent_business_unit_id_idx'
    ),
    FALSE,
    'the parent business unit index is not unique'
);

-- Check before any test fixtures: this migration must not load Business Unit data.
SELECT is(
    (SELECT count(*) FROM public.business_units),
    0::bigint,
    'business_units is empty after migration and before test fixtures'
);

SELECT lives_ok(
    $sql$
    INSERT INTO public.business_units (
        business_unit_id,
        business_unit_code,
        business_unit_name,
        business_unit_type,
        account_number_prefix,
        parent_business_unit_id,
        opal_domain,
        welsh_language,
        account_number_suffix
    ) VALUES (
        31001,
        'R001',
        'pgTAP Root Business Unit',
        'Area',
        'RT',
        NULL,
        NULL,
        FALSE,
        NULL
    )
    $sql$,
    'a valid root business unit can be inserted'
);
SELECT lives_ok(
    $sql$
    INSERT INTO public.business_units (
        business_unit_id,
        business_unit_code,
        business_unit_name,
        business_unit_type,
        account_number_prefix,
        parent_business_unit_id,
        opal_domain,
        welsh_language,
        account_number_suffix
    ) VALUES (
        31002,
        'A001',
        'pgTAP Accounting Division',
        'Accounting Division',
        'AD',
        31001,
        'opal-maintenance',
        TRUE,
        '01'
    )
    $sql$,
    'a valid child accounting division can be inserted'
);
SELECT is(
    (
        SELECT parent_business_unit_id
        FROM public.business_units
        WHERE business_unit_id = 31002
    ),
    31001::smallint,
    'the child retains its parent relationship'
);
SELECT lives_ok(
    $sql$
    INSERT INTO public.business_units (
        business_unit_id,
        business_unit_code,
        business_unit_name,
        business_unit_type,
        account_number_prefix,
        opal_domain,
        welsh_language,
        account_number_suffix
    ) VALUES (
        31003,
        'B001',
        repeat('N', 200),
        'Accounting Division',
        'BP',
        repeat('D', 30),
        FALSE,
        '99'
    )
    $sql$,
    'declared varchar boundary lengths can be inserted'
);

SELECT throws_ok(
    $sql$
    INSERT INTO public.business_units (
        business_unit_id, business_unit_code, business_unit_name,
        business_unit_type, account_number_prefix, welsh_language
    ) VALUES (
        31100, 'E001', 'pgTAP Invalid Enum', 'Court', 'IE', FALSE
    )
    $sql$,
    '22P02',
    NULL,
    'an unrecognised business unit type is rejected'
);
SELECT throws_ok(
    $sql$
    INSERT INTO public.business_units (
        business_unit_id, business_unit_code, business_unit_name,
        business_unit_type, account_number_prefix, welsh_language
    ) VALUES (
        31001, 'D001', 'pgTAP Duplicate Identifier', 'Area', 'DI', FALSE
    )
    $sql$,
    '23505',
    NULL,
    'a duplicate business_unit_id is rejected'
);
SELECT throws_ok(
    $sql$
    INSERT INTO public.business_units (
        business_unit_id, business_unit_code, business_unit_name,
        business_unit_type, account_number_prefix, welsh_language
    ) VALUES (
        31102, 'R001', 'pgTAP Duplicate Code', 'Area', 'DC', FALSE
    )
    $sql$,
    '23505',
    NULL,
    'a duplicate business_unit_code is rejected'
);
SELECT throws_ok(
    $sql$
    INSERT INTO public.business_units (
        business_unit_id, business_unit_code, business_unit_name,
        business_unit_type, account_number_prefix, parent_business_unit_id,
        welsh_language
    ) VALUES (
        31103, 'P001', 'pgTAP Missing Parent', 'Area', 'MP', 31999, FALSE
    )
    $sql$,
    '23503',
    NULL,
    'an unknown parent_business_unit_id is rejected'
);
SELECT throws_ok(
    $sql$
    INSERT INTO public.business_units (
        business_unit_id, business_unit_code, business_unit_name,
        business_unit_type, account_number_prefix, welsh_language
    ) VALUES (
        NULL, 'N001', 'pgTAP Null Identifier', 'Area', 'NI', FALSE
    )
    $sql$,
    '23502',
    NULL,
    'a null business_unit_id is rejected'
);
SELECT throws_ok(
    $sql$
    INSERT INTO public.business_units (
        business_unit_id, business_unit_code, business_unit_name,
        business_unit_type, account_number_prefix, welsh_language
    ) VALUES (
        31105, NULL, 'pgTAP Null Code', 'Area', 'NC', FALSE
    )
    $sql$,
    '23502',
    NULL,
    'a null business_unit_code is rejected'
);
SELECT throws_ok(
    $sql$
    INSERT INTO public.business_units (
        business_unit_id, business_unit_code, business_unit_name,
        business_unit_type, account_number_prefix, welsh_language
    ) VALUES (
        31106, 'N006', NULL, 'Area', 'NN', FALSE
    )
    $sql$,
    '23502',
    NULL,
    'a null business_unit_name is rejected'
);
SELECT throws_ok(
    $sql$
    INSERT INTO public.business_units (
        business_unit_id, business_unit_code, business_unit_name,
        business_unit_type, account_number_prefix, welsh_language
    ) VALUES (
        31107, 'N007', 'pgTAP Null Type', NULL, 'NT', FALSE
    )
    $sql$,
    '23502',
    NULL,
    'a null business_unit_type is rejected'
);
SELECT throws_ok(
    $sql$
    INSERT INTO public.business_units (
        business_unit_id, business_unit_code, business_unit_name,
        business_unit_type, account_number_prefix, welsh_language
    ) VALUES (
        31108, 'N008', 'pgTAP Null Prefix', 'Area', NULL, FALSE
    )
    $sql$,
    '23502',
    NULL,
    'a null account_number_prefix is rejected'
);
SELECT throws_ok(
    $sql$
    INSERT INTO public.business_units (
        business_unit_id, business_unit_code, business_unit_name,
        business_unit_type, account_number_prefix, welsh_language
    ) VALUES (
        31109, 'N009', 'pgTAP Null Welsh Flag', 'Area', 'NW', NULL
    )
    $sql$,
    '23502',
    NULL,
    'a null welsh_language value is rejected'
);
SELECT throws_ok(
    $sql$
    INSERT INTO public.business_units (
        business_unit_id, business_unit_code, business_unit_name,
        business_unit_type, account_number_prefix, welsh_language
    ) VALUES (
        31110, 'LONG1', 'pgTAP Long Code', 'Area', 'LC', FALSE
    )
    $sql$,
    '22001',
    NULL,
    'a business_unit_code longer than four characters is rejected'
);
SELECT throws_ok(
    $sql$
    INSERT INTO public.business_units (
        business_unit_id, business_unit_code, business_unit_name,
        business_unit_type, account_number_prefix, welsh_language
    ) VALUES (
        31111, 'L011', repeat('N', 201), 'Area', 'LN', FALSE
    )
    $sql$,
    '22001',
    NULL,
    'a business_unit_name longer than 200 characters is rejected'
);
SELECT throws_ok(
    $sql$
    INSERT INTO public.business_units (
        business_unit_id, business_unit_code, business_unit_name,
        business_unit_type, account_number_prefix, welsh_language
    ) VALUES (
        31112, 'L012', 'pgTAP Long Prefix', 'Area', 'LNG', FALSE
    )
    $sql$,
    '22001',
    NULL,
    'an account_number_prefix longer than two characters is rejected'
);
SELECT throws_ok(
    $sql$
    INSERT INTO public.business_units (
        business_unit_id, business_unit_code, business_unit_name,
        business_unit_type, account_number_prefix, opal_domain, welsh_language
    ) VALUES (
        31113, 'L013', 'pgTAP Long Domain', 'Area', 'LD', repeat('D', 31), FALSE
    )
    $sql$,
    '22001',
    NULL,
    'an opal_domain longer than 30 characters is rejected'
);
SELECT throws_ok(
    $sql$
    INSERT INTO public.business_units (
        business_unit_id, business_unit_code, business_unit_name,
        business_unit_type, account_number_prefix, welsh_language,
        account_number_suffix
    ) VALUES (
        31114, 'L014', 'pgTAP Long Suffix', 'Area', 'LS', FALSE, 'LNG'
    )
    $sql$,
    '22001',
    NULL,
    'an account_number_suffix longer than two characters is rejected'
);

SELECT * FROM finish();
ROLLBACK;
