DO $countries_unit_tests$
DECLARE
    actual_columns TEXT[];
    actual_default TEXT;
    actual_constraint_columns TEXT[];
    actual_index_columns TEXT[];
    actual_index_method TEXT;
    actual_index_unique BOOLEAN;
    actual_sequence_owner TEXT;
    actual_start_value BIGINT;
    actual_increment_by BIGINT;
    actual_cycle BOOLEAN;
    actual_cache_size BIGINT;
    actual_sequence_data_type TEXT;
    actual_default_sequence_dependency BOOLEAN;
    generated_country_id BIGINT;
BEGIN
    ASSERT to_regclass('public.countries') IS NOT NULL,
        'public.countries must exist';

    SELECT array_agg(format('%s|%s|%s|%s', column_name, udt_name, is_nullable,
        coalesce(character_maximum_length::TEXT, '')) ORDER BY ordinal_position)
    INTO actual_columns
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'countries';

    ASSERT actual_columns = ARRAY[
        'country_id|int8|NO|',
        'cjs_code|int2|NO|',
        'international_code|varchar|YES|3',
        'gov_code|varchar|YES|2',
        'country_name|varchar|NO|100',
        'demonym|varchar|YES|100',
        'date_used_from|date|NO|',
        'date_used_to|date|YES|',
        'active|bool|NO|'
    ]::TEXT[], format('Unexpected COUNTRIES columns: %s', actual_columns);

    SELECT column_default INTO actual_default
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'countries' AND column_name = 'country_id';

    ASSERT actual_default LIKE 'nextval(%country_id_seq%regclass)%',
        format('Unexpected country_id default: %s', actual_default);

    SELECT EXISTS (
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
    )
    INTO actual_default_sequence_dependency;

    ASSERT actual_default_sequence_dependency IS TRUE,
        'country_id default must depend on public.country_id_seq';

    SELECT array_agg(attribute.attname ORDER BY key_position.ordinality)
    INTO actual_constraint_columns
    FROM pg_constraint constraint_definition
    CROSS JOIN LATERAL unnest(constraint_definition.conkey)
        WITH ORDINALITY AS key_position(attnum, ordinality)
    JOIN pg_attribute attribute
      ON attribute.attrelid = constraint_definition.conrelid
     AND attribute.attnum = key_position.attnum
    WHERE constraint_definition.conrelid = 'public.countries'::regclass
      AND constraint_definition.conname = 'countries_pk'
      AND constraint_definition.contype = 'p';

    ASSERT actual_constraint_columns = ARRAY['country_id']::TEXT[],
        format('Unexpected countries_pk columns: %s', actual_constraint_columns);

    SELECT array_agg(attribute.attname ORDER BY key_position.ordinality)
    INTO actual_constraint_columns
    FROM pg_constraint constraint_definition
    CROSS JOIN LATERAL unnest(constraint_definition.conkey)
        WITH ORDINALITY AS key_position(attnum, ordinality)
    JOIN pg_attribute attribute
      ON attribute.attrelid = constraint_definition.conrelid
     AND attribute.attnum = key_position.attnum
    WHERE constraint_definition.conrelid = 'public.countries'::regclass
      AND constraint_definition.conname = 'countries_international_code_uk'
      AND constraint_definition.contype = 'u';

    ASSERT actual_constraint_columns = ARRAY['international_code']::TEXT[],
        format('Unexpected countries_international_code_uk columns: %s', actual_constraint_columns);

    SELECT array_agg(attribute.attname ORDER BY key_position.ordinality),
           access_method.amname, index_definition.indisunique
    INTO actual_index_columns, actual_index_method, actual_index_unique
    FROM pg_index index_definition
    JOIN pg_class index_relation ON index_relation.oid = index_definition.indexrelid
    JOIN pg_namespace index_namespace ON index_namespace.oid = index_relation.relnamespace
    JOIN pg_am access_method ON access_method.oid = index_relation.relam
    CROSS JOIN LATERAL unnest(index_definition.indkey)
        WITH ORDINALITY AS key_position(attnum, ordinality)
    JOIN pg_attribute attribute
      ON attribute.attrelid = index_definition.indrelid
     AND attribute.attnum = key_position.attnum
    WHERE index_namespace.nspname = 'public'
      AND index_relation.relname = 'countries_active_country_name_idx'
      AND index_definition.indrelid = 'public.countries'::regclass
    GROUP BY access_method.amname, index_definition.indisunique;

    ASSERT actual_index_columns = ARRAY['active', 'country_name']::TEXT[],
        format('Unexpected COUNTRIES index columns: %s', actual_index_columns);
    ASSERT actual_index_method = 'btree',
        format('Unexpected COUNTRIES index method: %s', actual_index_method);
    ASSERT actual_index_unique IS FALSE,
        'countries_active_country_name_idx must not be unique';

    SELECT format('%I.%I.%I', table_namespace.nspname, table_relation.relname,
                  table_attribute.attname)
    INTO actual_sequence_owner
    FROM pg_class sequence_relation
    JOIN pg_namespace sequence_namespace
      ON sequence_namespace.oid = sequence_relation.relnamespace
    JOIN pg_depend ownership_dependency
      ON ownership_dependency.classid = 'pg_class'::regclass
     AND ownership_dependency.objid = sequence_relation.oid
     AND ownership_dependency.deptype = 'a'
    JOIN pg_class table_relation ON table_relation.oid = ownership_dependency.refobjid
    JOIN pg_namespace table_namespace ON table_namespace.oid = table_relation.relnamespace
    JOIN pg_attribute table_attribute
      ON table_attribute.attrelid = table_relation.oid
     AND table_attribute.attnum = ownership_dependency.refobjsubid
    WHERE sequence_relation.relkind = 'S'
      AND sequence_namespace.nspname = 'public'
      AND sequence_relation.relname = 'country_id_seq';

    ASSERT actual_sequence_owner = 'public.countries.country_id',
        format('Unexpected country_id_seq owner: %s', actual_sequence_owner);

    SELECT data_type, start_value, increment_by, cycle, cache_size
    INTO actual_sequence_data_type, actual_start_value, actual_increment_by,
         actual_cycle, actual_cache_size
    FROM pg_sequences
    WHERE schemaname = 'public' AND sequencename = 'country_id_seq';

    ASSERT actual_sequence_data_type = 'bigint',
        format('Unexpected country_id_seq data type: %s', actual_sequence_data_type);
    ASSERT actual_start_value = 1, format('Unexpected country_id_seq start: %s', actual_start_value);
    ASSERT actual_increment_by = 1, format('Unexpected country_id_seq increment: %s', actual_increment_by);
    ASSERT actual_cycle IS FALSE, format('Unexpected country_id_seq cycle setting: %s', actual_cycle);
    ASSERT actual_cache_size = 1, format('Unexpected country_id_seq cache: %s', actual_cache_size);

    INSERT INTO public.countries (cjs_code, international_code, gov_code, country_name, demonym,
        date_used_from, date_used_to, active)
    VALUES (31001, 'T01', 'T1', 'Contract Test Country', 'Contract Tester', DATE '2025-01-01', NULL, TRUE)
    RETURNING country_id INTO generated_country_id;

    ASSERT generated_country_id IS NOT NULL, 'country_id must be generated by country_id_seq';

    INSERT INTO public.countries (cjs_code, country_name, date_used_from, active)
    VALUES (31002, 'Nullable Contract Country One', DATE '2025-01-01', TRUE);
    INSERT INTO public.countries (cjs_code, country_name, date_used_from, active)
    VALUES (31003, 'Nullable Contract Country Two', DATE '2025-01-01', TRUE);

    BEGIN
        INSERT INTO public.countries (country_id, cjs_code, country_name, date_used_from, active)
        VALUES (generated_country_id, 31004, 'Duplicate Identifier Country', DATE '2025-01-01', TRUE);
        ASSERT FALSE, 'Duplicate country_id must fail';
    EXCEPTION WHEN unique_violation THEN
        ASSERT SQLSTATE = '23505' AND SQLERRM LIKE '%countries_pk%',
            format('Unexpected duplicate country_id error: %s', SQLERRM);
    END;

    BEGIN
        INSERT INTO public.countries (cjs_code, international_code, country_name, date_used_from, active)
        VALUES (31005, 'DUP', 'Duplicate International Country One', DATE '2025-01-01', TRUE);
        INSERT INTO public.countries (cjs_code, international_code, country_name, date_used_from, active)
        VALUES (31006, 'DUP', 'Duplicate International Country Two', DATE '2025-01-01', TRUE);
        ASSERT FALSE, 'Duplicate international_code must fail';
    EXCEPTION WHEN unique_violation THEN
        ASSERT SQLSTATE = '23505' AND SQLERRM LIKE '%countries_international_code_uk%',
            format('Unexpected duplicate international_code error: %s', SQLERRM);
    END;

    BEGIN
        INSERT INTO public.countries (country_id, cjs_code, country_name, date_used_from, active)
        VALUES (NULL, 31101, 'Null Identifier Country', DATE '2025-01-01', TRUE);
        ASSERT FALSE, 'Null country_id must fail';
    EXCEPTION WHEN not_null_violation THEN
        ASSERT SQLSTATE = '23502', format('Unexpected null country_id error: %s', SQLERRM);
    END;

    BEGIN
        INSERT INTO public.countries (cjs_code, country_name, date_used_from, active)
        VALUES (NULL, 'Null CJS Code Country', DATE '2025-01-01', TRUE);
        ASSERT FALSE, 'Null cjs_code must fail';
    EXCEPTION WHEN not_null_violation THEN
        ASSERT SQLSTATE = '23502', format('Unexpected null cjs_code error: %s', SQLERRM);
    END;

    BEGIN
        INSERT INTO public.countries (cjs_code, country_name, date_used_from, active)
        VALUES (31103, NULL, DATE '2025-01-01', TRUE);
        ASSERT FALSE, 'Null country_name must fail';
    EXCEPTION WHEN not_null_violation THEN
        ASSERT SQLSTATE = '23502', format('Unexpected null country_name error: %s', SQLERRM);
    END;

    BEGIN
        INSERT INTO public.countries (cjs_code, country_name, date_used_from, active)
        VALUES (31104, 'Null Start Date Country', NULL, TRUE);
        ASSERT FALSE, 'Null date_used_from must fail';
    EXCEPTION WHEN not_null_violation THEN
        ASSERT SQLSTATE = '23502', format('Unexpected null date_used_from error: %s', SQLERRM);
    END;

    BEGIN
        INSERT INTO public.countries (cjs_code, country_name, date_used_from, active)
        VALUES (31105, 'Null Active Country', DATE '2025-01-01', NULL);
        ASSERT FALSE, 'Null active must fail';
    EXCEPTION WHEN not_null_violation THEN
        ASSERT SQLSTATE = '23502', format('Unexpected null active error: %s', SQLERRM);
    END;

    BEGIN
        INSERT INTO public.countries (cjs_code, international_code, country_name, date_used_from, active)
        VALUES (31201, 'LONG', 'Oversized International Code Country', DATE '2025-01-01', TRUE);
        ASSERT FALSE, 'international_code longer than three characters must fail';
    EXCEPTION WHEN string_data_right_truncation THEN
        ASSERT SQLSTATE = '22001', format('Unexpected international_code length error: %s', SQLERRM);
    END;

    BEGIN
        INSERT INTO public.countries (cjs_code, gov_code, country_name, date_used_from, active)
        VALUES (31202, 'GOV', 'Oversized Government Code Country', DATE '2025-01-01', TRUE);
        ASSERT FALSE, 'gov_code longer than two characters must fail';
    EXCEPTION WHEN string_data_right_truncation THEN
        ASSERT SQLSTATE = '22001', format('Unexpected gov_code length error: %s', SQLERRM);
    END;

    BEGIN
        INSERT INTO public.countries (cjs_code, country_name, date_used_from, active)
        VALUES (31203, repeat('N', 101), DATE '2025-01-01', TRUE);
        ASSERT FALSE, 'country_name longer than 100 characters must fail';
    EXCEPTION WHEN string_data_right_truncation THEN
        ASSERT SQLSTATE = '22001', format('Unexpected country_name length error: %s', SQLERRM);
    END;

    BEGIN
        INSERT INTO public.countries (cjs_code, country_name, demonym, date_used_from, active)
        VALUES (31204, 'Oversized Demonym Country', repeat('D', 101), DATE '2025-01-01', TRUE);
        ASSERT FALSE, 'demonym longer than 100 characters must fail';
    EXCEPTION WHEN string_data_right_truncation THEN
        ASSERT SQLSTATE = '22001', format('Unexpected demonym length error: %s', SQLERRM);
    END;

    INSERT INTO public.countries (cjs_code, international_code, country_name, date_used_from,
        date_used_to, active)
    VALUES (31301, 'END', 'Inactive Contract Country', DATE '2020-01-01', DATE '2024-12-31', FALSE);
END;
$countries_unit_tests$;
