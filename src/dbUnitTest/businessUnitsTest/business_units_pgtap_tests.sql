BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;

SELECT plan(61);

-- ---------------------------------------------------------------------------
-- Scenario: The promoted Business Unit enum is available.
-- Setup:    Inspect the migrated PostgreSQL type and its ordered labels.
-- Expected: An enum exists with exactly Area and Accounting Division.
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- Scenario: The table matches the promoted column contract.
-- Setup:    Inspect table existence, column order, types and nullability.
-- Expected: Exactly nine approved columns; active is absent.
-- ---------------------------------------------------------------------------
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
SELECT col_is_null(
    'public', 'business_units', 'account_number_prefix',
    'account_number_prefix is optional'
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
-- ---------------------------------------------------------------------------
-- Scenario: Business Unit identifiers are supplied, not generated locally.
-- Setup:    Inspect the identifier default, identity flag and owned sequences.
-- Expected: No default, identity generation or owned sequence.
-- ---------------------------------------------------------------------------
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
SELECT is(
    (
        SELECT is_identity
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'business_units'
          AND column_name = 'business_unit_id'
    ),
    'NO',
    'business_unit_id is not an identity column'
);
SELECT ok(
    NOT EXISTS (
        SELECT 1
        FROM pg_depend ownership_dependency
        JOIN pg_class sequence_relation ON sequence_relation.oid = ownership_dependency.objid
        WHERE ownership_dependency.classid = 'pg_class'::regclass
          AND ownership_dependency.refclassid = 'pg_class'::regclass
          AND ownership_dependency.refobjid = 'public.business_units'::regclass
          AND ownership_dependency.deptype IN ('a', 'i')
          AND sequence_relation.relkind = 'S'
    ),
    'business_units owns no sequence'
);
-- ---------------------------------------------------------------------------
-- Scenario: Column comments preserve the authoritative descriptions.
-- Setup:    Read every column comment in physical column order.
-- Expected: All nine descriptions match the TDIA verbatim.
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- Scenario: Business Unit identifiers are protected by the primary key.
-- Setup:    Inspect primary-key columns and the constraint name.
-- Expected: business_units_pk protects business_unit_id.
-- ---------------------------------------------------------------------------
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
-- ---------------------------------------------------------------------------
-- Scenario: Business Unit codes must be unique.
-- Setup:    Inspect unique-constraint columns and the constraint name.
-- Expected: business_units_business_unit_code_uk protects business_unit_code.
-- ---------------------------------------------------------------------------
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
-- ---------------------------------------------------------------------------
-- Scenario: Parent relationships reference another Business Unit.
-- Setup:    Inspect the named foreign key and both ends of its mapping.
-- Expected: parent_business_unit_id references business_unit_id on this table.
-- ---------------------------------------------------------------------------
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
-- ---------------------------------------------------------------------------
-- Scenario: Parent Business Unit lookups have the intended index.
-- Setup:    Inspect indexed columns, access method and uniqueness.
-- Expected: A non-unique btree index covers parent_business_unit_id.
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- Scenario: Reserved schema-test fixture identifiers are available.
-- Setup:    Count persisted rows in the synthetic identifier range 31001 to 31115.
-- Expected: The reference seed does not use identifiers reserved by this suite.
-- ---------------------------------------------------------------------------
SELECT is(
    (
        SELECT count(*)
        FROM public.business_units
        WHERE business_unit_id BETWEEN 31001 AND 31115
    ),
    0::bigint,
    'reserved Business Unit schema-test fixture identifiers are absent'
);

-- ---------------------------------------------------------------------------
-- Scenario: A root Business Unit may have no parent or optional values.
-- Setup:    Insert Area 31001 with optional columns NULL and Welsh flag FALSE.
-- Expected: The insert succeeds; this row is reused by dependent scenarios.
-- ---------------------------------------------------------------------------
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
-- ---------------------------------------------------------------------------
-- Scenario: An Accounting Division may reference an existing parent.
-- Setup:    Insert child 31002 referencing root 31001, with optional values set.
-- Expected: The insert succeeds and the stored parent remains 31001.
-- ---------------------------------------------------------------------------
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
-- ---------------------------------------------------------------------------
-- Scenario: Text values at their declared length limits are accepted.
-- Setup:    Insert code/name/prefix/domain/suffix lengths 4/200/2/30/2.
-- Expected: The insert succeeds without truncation errors.
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- Scenario: An unrecognised Business Unit type is rejected.
-- Setup:    Insert type Court, which is not an enum label.
-- Expected: Invalid enum input raises SQLSTATE 22P02.
-- ---------------------------------------------------------------------------
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
-- ---------------------------------------------------------------------------
-- Scenario: An existing Business Unit identifier cannot be reused.
-- Setup:    Insert a second row with the root identifier 31001.
-- Expected: The primary key rejects the insert with SQLSTATE 23505.
-- ---------------------------------------------------------------------------
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
-- ---------------------------------------------------------------------------
-- Scenario: An existing Business Unit code cannot be reused.
-- Setup:    Insert a new identifier using the root code R001.
-- Expected: The unique constraint rejects the insert with SQLSTATE 23505.
-- ---------------------------------------------------------------------------
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
-- ---------------------------------------------------------------------------
-- Scenario: A Business Unit refers to a parent that does not exist.
-- Setup:    Insert a child with parent_business_unit_id = 31999, which is absent.
-- Expected: The foreign key rejects the insert with SQLSTATE 23503.
-- ---------------------------------------------------------------------------
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
-- ---------------------------------------------------------------------------
-- Scenario: A Business Unit must have an explicit non-null identifier.
-- Setup:    Insert NULL into business_unit_id.
-- Expected: The NOT NULL constraint rejects the insert with SQLSTATE 23502.
-- ---------------------------------------------------------------------------
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
-- ---------------------------------------------------------------------------
-- Scenario: Omitting an identifier must not generate one automatically.
-- Setup:    Insert a row without supplying business_unit_id.
-- Expected: The insert fails with SQLSTATE 23502 instead of generating an ID.
-- ---------------------------------------------------------------------------
SELECT throws_ok(
    $sql$
    INSERT INTO public.business_units (
        business_unit_code, business_unit_name,
        business_unit_type, account_number_prefix, welsh_language
    ) VALUES (
        'M001', 'pgTAP Missing Identifier', 'Area', 'MI', FALSE
    )
    $sql$,
    '23502',
    NULL,
    'omitting business_unit_id is rejected rather than generating an identifier'
);
-- ---------------------------------------------------------------------------
-- Scenario: business_unit_code is required.
-- Setup:    Insert an otherwise valid row with business_unit_code set to NULL.
-- Expected: The NOT NULL constraint rejects the insert with SQLSTATE 23502.
-- ---------------------------------------------------------------------------
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
-- ---------------------------------------------------------------------------
-- Scenario: business_unit_name is required.
-- Setup:    Insert an otherwise valid row with business_unit_name set to NULL.
-- Expected: The NOT NULL constraint rejects the insert with SQLSTATE 23502.
-- ---------------------------------------------------------------------------
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
-- ---------------------------------------------------------------------------
-- Scenario: business_unit_type is required.
-- Setup:    Insert an otherwise valid row with business_unit_type set to NULL.
-- Expected: The NOT NULL constraint rejects the insert with SQLSTATE 23502.
-- ---------------------------------------------------------------------------
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
-- ---------------------------------------------------------------------------
-- Scenario: A Business Unit may have no account number prefix.
-- Setup:    Insert an otherwise valid row with account_number_prefix set to NULL.
-- Expected: The insert succeeds and the stored prefix remains NULL.
-- ---------------------------------------------------------------------------
SELECT lives_ok(
    $sql$
    INSERT INTO public.business_units (
        business_unit_id, business_unit_code, business_unit_name,
        business_unit_type, account_number_prefix, welsh_language
    ) VALUES (
        31108, 'N008', 'pgTAP Null Prefix', 'Area', NULL, FALSE
    )
    $sql$,
    'a null account_number_prefix is accepted'
);
SELECT results_eq(
    'SELECT account_number_prefix FROM public.business_units WHERE business_unit_id = 31108',
    'VALUES (NULL::varchar)',
    'an explicitly null account_number_prefix is stored as NULL'
);
-- ---------------------------------------------------------------------------
-- Scenario: An Accounting Division may omit its account number prefix.
-- Setup:    Insert an otherwise valid row without the prefix column.
-- Expected: The insert succeeds and the stored prefix is NULL, not fabricated.
-- ---------------------------------------------------------------------------
SELECT lives_ok(
    $sql$
    INSERT INTO public.business_units (
        business_unit_id, business_unit_code, business_unit_name,
        business_unit_type, welsh_language
    ) VALUES (
        31115, 'O015', 'pgTAP Omitted Prefix', 'Accounting Division', FALSE
    )
    $sql$,
    'omitting account_number_prefix is accepted'
);
SELECT results_eq(
    'SELECT account_number_prefix FROM public.business_units WHERE business_unit_id = 31115',
    'VALUES (NULL::varchar)',
    'an omitted account_number_prefix is stored as NULL'
);
-- ---------------------------------------------------------------------------
-- Scenario: welsh_language is required.
-- Setup:    Insert an otherwise valid row with welsh_language set to NULL.
-- Expected: The NOT NULL constraint rejects the insert with SQLSTATE 23502.
-- ---------------------------------------------------------------------------
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
-- ---------------------------------------------------------------------------
-- Scenario: business_unit_code cannot exceed its declared length.
-- Setup:    Insert 5 characters into business_unit_code, whose limit is 4.
-- Expected: The insert fails with string-length SQLSTATE 22001.
-- ---------------------------------------------------------------------------
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
-- ---------------------------------------------------------------------------
-- Scenario: business_unit_name cannot exceed its declared length.
-- Setup:    Insert 201 characters into business_unit_name, whose limit is 200.
-- Expected: The insert fails with string-length SQLSTATE 22001.
-- ---------------------------------------------------------------------------
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
-- ---------------------------------------------------------------------------
-- Scenario: account_number_prefix cannot exceed its declared length.
-- Setup:    Insert 3 characters into account_number_prefix, whose limit is 2.
-- Expected: The insert fails with string-length SQLSTATE 22001.
-- ---------------------------------------------------------------------------
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
-- ---------------------------------------------------------------------------
-- Scenario: opal_domain cannot exceed its declared length.
-- Setup:    Insert 31 characters into opal_domain, whose limit is 30.
-- Expected: The insert fails with string-length SQLSTATE 22001.
-- ---------------------------------------------------------------------------
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
-- ---------------------------------------------------------------------------
-- Scenario: account_number_suffix cannot exceed its declared length.
-- Setup:    Insert 3 characters into account_number_suffix, whose limit is 2.
-- Expected: The insert fails with string-length SQLSTATE 22001.
-- ---------------------------------------------------------------------------
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

-- Verify the assertion plan, then roll back all test fixtures.
SELECT * FROM finish();
ROLLBACK;
