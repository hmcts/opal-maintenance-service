-- PO-10285 / V1_11: catalogue and behavioral assertions apply to fresh and predecessor-upgrade paths.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(41);

-- -----------------------------------------------------------------------------
-- Scenario: The migration exposes the exact TDIA physical contract.
-- Setup: Inspect the migrated PostgreSQL catalogues directly.
-- Expected: Eleven columns, required keys/index/sequence, comments and no extra rules.
SELECT has_table('public', 'maintenance_applications', 'table exists');
SELECT has_sequence('public', 'application_id_seq', 'identifier sequence exists');
SELECT results_eq(
    $$SELECT a.attname::text COLLATE "default", format_type(a.atttypid, a.atttypmod), a.attnotnull
      FROM pg_attribute a
      WHERE a.attrelid = 'public.maintenance_applications'::regclass
        AND a.attnum > 0 AND NOT a.attisdropped ORDER BY a.attnum$$,
    $$VALUES
      ('application_id'::text, 'smallint'::text, true),
      ('application_code', 'character varying(8)', true),
      ('application_title', 'character varying(255)', true),
      ('application_group', 'character varying(20)', true),
      ('application_wording', 'text', false),
      ('application_responses', 'json', false),
      ('application_act_section', 'text', false),
      ('application_act_summary', 'text', false),
      ('active', 'boolean', true),
      ('date_used_from', 'date', true),
      ('date_used_to', 'date', false)$$,
    'exact eleven columns, order, widths, JSON type and nullability');
SELECT results_eq(
    $$SELECT conname::text COLLATE "default", pg_get_constraintdef(oid)
      FROM pg_constraint WHERE conrelid = 'public.maintenance_applications'::regclass
        AND contype IN ('p', 'u') ORDER BY conname$$,
    $$VALUES
      ('maintenance_applications_application_code_uk'::text, 'UNIQUE (application_code)'::text),
      ('maintenance_applications_pk', 'PRIMARY KEY (application_id)')$$,
    'exact named primary and unique keys');
SELECT has_index('public', 'maintenance_applications',
    'maintenance_applications_application_group_active_idx',
    ARRAY['application_group', 'active'], 'filter index has the required column order');
SELECT index_is_type('public', 'maintenance_applications',
    'maintenance_applications_application_group_active_idx', 'btree',
    'repository-chosen filter index method is btree');
SELECT ok((SELECT indisvalid AND indisready AND NOT indisunique
                   AND indpred IS NULL AND indexprs IS NULL
                   AND indnkeyatts = 2 AND indnatts = 2
           FROM pg_index
           WHERE indexrelid = 'public.maintenance_applications_application_group_active_idx'::regclass),
          'filter index is usable, nonunique, full and contains only the two keys');
SELECT results_eq(
    $$SELECT data_type::text, start_value, increment_by, min_value, max_value, cache_size, cycle
      FROM pg_sequences WHERE schemaname = 'public' AND sequencename = 'application_id_seq'$$,
    $$VALUES ('smallint'::text, 1::bigint, 1::bigint, 1::bigint, 32767::bigint, 1::bigint, false)$$,
    'sequence storage range and required settings');
SELECT is(pg_get_serial_sequence('public.maintenance_applications', 'application_id'),
          'public.application_id_seq', 'sequence is owned by application_id');
SELECT ok(EXISTS (
    SELECT 1 FROM pg_attrdef d JOIN pg_depend dep
      ON dep.classid = 'pg_attrdef'::regclass AND dep.objid = d.oid
    JOIN pg_attribute a ON a.attrelid = d.adrelid AND a.attnum = d.adnum
    WHERE d.adrelid = 'public.maintenance_applications'::regclass
      AND a.attname = 'application_id'
      AND dep.refclassid = 'pg_class'::regclass
      AND dep.refobjid = 'public.application_id_seq'::regclass),
    'identifier default is wired to the named sequence');
SELECT is((SELECT count(*) FROM pg_attribute
           WHERE attrelid = 'public.maintenance_applications'::regclass
             AND attnum > 0 AND NOT attisdropped
             AND NULLIF(btrim(col_description(attrelid, attnum)), '') IS NOT NULL),
          11::bigint, 'every column has a descriptive comment');
SELECT is((SELECT count(*) FROM pg_constraint
           WHERE conrelid = 'public.maintenance_applications'::regclass AND contype IN ('f', 'c')),
          0::bigint, 'no unevidenced foreign key or business CHECK constraint');
SELECT is((SELECT count(*) FROM pg_attrdef
           WHERE adrelid = 'public.maintenance_applications'::regclass),
          1::bigint, 'only application_id has a default');

-- Synthetic test records only. ALTER SEQUENCE RESTART rolls back with this transaction.
-- -----------------------------------------------------------------------------
-- Scenario: The table is created without seed data.
-- Setup: Query the new table before adding synthetic test records.
-- Expected: No rows exist.
SELECT is((SELECT count(*) FROM public.maintenance_applications), 0::bigint,
          'table creation loads no application records');
-- -----------------------------------------------------------------------------
-- Scenario: Generated identifiers and complete application records are accepted.
-- Setup: Restart the disposable sequence and insert valid boundary-length fields.
-- Expected: Identifier starts at one; JSON, text and dates are stored correctly.
ALTER SEQUENCE public.application_id_seq RESTART WITH 1;
SELECT lives_ok($$
    INSERT INTO public.maintenance_applications
        (application_code, application_title, application_group, application_wording,
         application_responses, application_act_section, application_act_summary,
         active, date_used_from, date_used_to)
    VALUES ('TEST0001', repeat('T',255), 'Create Casefile', repeat('W',1024),
            '{"prompts":[{"name":"test","required":true}]}', repeat('L',1024), repeat('S',1024),
            true, DATE '2024-02-29', DATE '2030-12-31')$$,
    'complete record accepts title boundary, long text, valid JSON and dates');
SELECT is((SELECT application_id::integer FROM public.maintenance_applications
           WHERE application_code = 'TEST0001'), 1, 'omitted identifier uses the named sequence');
SELECT ok((SELECT application_responses->'prompts'->0->>'name' = 'test'
                  AND length(application_wording)=1024 AND length(application_act_section)=1024
                  AND length(application_act_summary)=1024
           FROM public.maintenance_applications WHERE application_code='TEST0001'),
          'JSON structure and unbounded text are preserved');
-- -----------------------------------------------------------------------------
-- Scenario: Optional fields and journey filtering preserve their contract.
-- Setup: Insert inactive and wrong-group records alongside the active matching record.
-- Expected: Optional fields remain NULL and only the matching active record is selected.
SELECT lives_ok($$
    INSERT INTO public.maintenance_applications
        (application_code,application_title,application_group,active,date_used_from)
    VALUES ('TEST0002','Optional fields omitted',repeat('G',20),false,DATE '2024-01-01'),
           ('TEST0003','Same group but inactive','Create Casefile',false,DATE '2024-01-01'),
           ('TEST0004','Active but another group','Other group',true,DATE '2024-01-01')$$,
    'minimal inactive record accepts group boundary and all optional nulls');
SELECT ok((SELECT application_id=2 AND application_wording IS NULL AND application_responses IS NULL
                  AND application_act_section IS NULL AND application_act_summary IS NULL
                  AND date_used_to IS NULL
           FROM public.maintenance_applications WHERE application_code='TEST0002'),
          'generated values increment and all five nullable fields remain null');
SELECT results_eq(
    $$SELECT application_code::text FROM public.maintenance_applications
      WHERE application_group='Create Casefile' AND active ORDER BY application_code$$,
    $$VALUES ('TEST0001'::text)$$, 'intended filter returns only the matching active record');
-- -----------------------------------------------------------------------------
-- Scenario: Primary and business keys reject duplicates.
-- Setup: Reuse identifier 1, then TEST0001 in another group.
-- Expected: Both conflicts raise SQLSTATE 23505 without inserting rows.
SELECT throws_ok($$INSERT INTO public.maintenance_applications
    (application_id,application_code,application_title,application_group,active,date_used_from)
    VALUES (1,'DUPEID','Duplicate id','Test',true,DATE '2024-01-01')$$,
    '23505',NULL,'duplicate primary key is rejected');
SELECT throws_ok($$INSERT INTO public.maintenance_applications
    (application_id,application_code,application_title,application_group,active,date_used_from)
    VALUES (100,'TEST0001','Duplicate code','Other group',true,DATE '2024-01-01')$$,
    '23505',NULL,'business code is globally unique, not unique only per group');

-- -----------------------------------------------------------------------------
-- Scenario: Every mandatory field rejects explicit NULL.
-- Setup: Set one of six required fields to NULL per insert; other values are valid.
-- Expected: Each insert raises SQLSTATE 23502.
-- Six independent negative assertions; NULL is assigned to one required field per attempt.
SELECT throws_ok(format($q$
    INSERT INTO public.maintenance_applications
      (application_id,application_code,application_title,application_group,active,date_used_from)
    SELECT %s,%s,%s,%s,%s,%s$q$,
    CASE WHEN n='application_id' THEN 'NULL' ELSE '101' END,
    CASE WHEN n='application_code' THEN 'NULL' ELSE quote_literal('NULLTEST') END,
    CASE WHEN n='application_title' THEN 'NULL' ELSE quote_literal('Null test') END,
    CASE WHEN n='application_group' THEN 'NULL' ELSE quote_literal('Test') END,
    CASE WHEN n='active' THEN 'NULL' ELSE 'true' END,
    CASE WHEN n='date_used_from' THEN 'NULL' ELSE 'DATE ''2024-01-01''' END),
    '23502',NULL,n || ' rejects explicit null')
FROM (VALUES ('application_id'),('application_code'),('application_title'),
             ('application_group'),('active'),('date_used_from')) AS required(n);

-- -----------------------------------------------------------------------------
-- Scenario: Character limits reject overlength values.
-- Setup: Exceed each VARCHAR width by one, without a truncating cast.
-- Expected: Each insert raises SQLSTATE 22001.
-- Three independent overlength assertions; insert through the real table to avoid cast truncation.
SELECT throws_ok(format($q$
    INSERT INTO public.maintenance_applications
      (application_id,application_code,application_title,application_group,active,date_used_from)
    VALUES (102,%s,%s,%s,true,DATE '2024-01-01')$q$,
    CASE WHEN n='application_code' THEN 'repeat(''C'',9)' ELSE quote_literal('WIDTH') END,
    CASE WHEN n='application_title' THEN 'repeat(''T'',256)' ELSE quote_literal('Width test') END,
    CASE WHEN n='application_group' THEN 'repeat(''G'',21)' ELSE quote_literal('Test') END),
    '22001',NULL,n || ' rejects overlength value')
FROM (VALUES ('application_code'),('application_title'),('application_group')) AS widths(n);
-- -----------------------------------------------------------------------------
-- Scenario: JSON and identifier type boundaries reject invalid input.
-- Setup: Insert malformed JSON, then identifiers outside the SMALLINT range.
-- Expected: SQLSTATE 22P02 or 22003 is raised; existing rows are unchanged.
SELECT throws_ok($$INSERT INTO public.maintenance_applications
    (application_code,application_title,application_group,application_responses,active,date_used_from)
    VALUES ('BADJSON','Invalid JSON','Test','{',true,DATE '2024-01-01')$$,
    '22P02',NULL,'malformed JSON is rejected');
SELECT throws_ok($$INSERT INTO public.maintenance_applications
    (application_id,application_code,application_title,application_group,active,date_used_from)
    VALUES (32768,'OVERFLOW','Outside smallint','Test',true,DATE '2024-01-01')$$,
    '22003',NULL,'identifier above SMALLINT range is rejected');
SELECT throws_ok($$INSERT INTO public.maintenance_applications
    (application_id,application_code,application_title,application_group,active,date_used_from)
    VALUES (-32769,'UNDERFLW','Outside smallint','Test',true,DATE '2024-01-01')$$,
    '22003',NULL,'identifier below SMALLINT range is rejected');
SELECT is((SELECT count(*) FROM public.maintenance_applications),4::bigint,
          'failed inserts leave no partial records');

-- -----------------------------------------------------------------------------
-- Scenario: The caller owns transaction rollback.
-- Setup: Insert a synthetic row after a savepoint and roll back to it.
-- Expected: The inserted row is absent.
SAVEPOINT rollback_probe;
INSERT INTO public.maintenance_applications
  (application_id,application_code,application_title,application_group,active,date_used_from)
VALUES (200,'ROLLBACK','Rollback probe','Test',true,DATE '2024-01-01');
ROLLBACK TO SAVEPOINT rollback_probe;
SELECT is((SELECT count(*) FROM public.maintenance_applications WHERE application_code='ROLLBACK'),
          0::bigint,'caller-controlled rollback removes test write');

-- -----------------------------------------------------------------------------
-- Scenario: The owned sequence stops at its SMALLINT maximum.
-- Setup: Restart at 32767, insert once, then request another value.
-- Expected: The final identifier is usable and exhaustion raises SQLSTATE 2200H.
ALTER SEQUENCE public.application_id_seq RESTART WITH 32767;
SELECT lives_ok($$INSERT INTO public.maintenance_applications
    (application_code,application_title,application_group,active,date_used_from)
    VALUES ('LASTID','Last generated smallint','Test',true,DATE '2024-01-01')$$,
    'last positive SMALLINT sequence value is usable');
SELECT is((SELECT application_id::integer FROM public.maintenance_applications
           WHERE application_code='LASTID'),32767,'sequence reaches its configured maximum');
SELECT throws_ok($$SELECT nextval('public.application_id_seq')$$,'2200H',NULL,
                 'sequence exhaustion raises instead of cycling');
SELECT is((SELECT count(*) FROM public.maintenance_applications),5::bigint,
          'successful rows remain intact after failures');
-- -----------------------------------------------------------------------------
-- Scenario: Explicit identifiers retain the full SMALLINT domain.
-- Setup: Insert -32768 explicitly after exhausting generated identifiers.
-- Expected: The insert succeeds without an invented positive-only CHECK.
SELECT lives_ok($$INSERT INTO public.maintenance_applications
    (application_id,application_code,application_title,application_group,active,date_used_from)
    VALUES (-32768,'MINID','Explicit smallint minimum','Test',false,DATE '2024-01-01')$$,
    'column permits full SMALLINT domain without an invented positive-id check');
SELECT * FROM finish();
ROLLBACK;
