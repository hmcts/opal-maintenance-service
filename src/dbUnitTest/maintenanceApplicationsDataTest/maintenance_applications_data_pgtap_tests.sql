-- PO-10293: supplied data and failure boundaries apply to fresh and predecessor upgrades.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(19);

-- Scenario: The independently retained source fixes all values and generated-field omissions.
-- Setup: Load source fields as text, with unquoted CSV blanks represented by NULL.
-- Expected: 35 unique source keys, blank generated IDs, exact group/flag/effective date.
CREATE TEMP TABLE expected_ma_raw (
    application_id TEXT, application_code TEXT, application_title TEXT,
    application_group TEXT, application_wording TEXT, application_responses TEXT,
    application_act_section TEXT, application_act_summary TEXT,
    active TEXT, date_used_from TEXT, date_used_to TEXT
);
COPY expected_ma_raw
FROM '/tmp/opal-db-unit-test/maintenanceApplicationsDataTest/maintenance-applications.csv'
WITH (FORMAT CSV, HEADER TRUE, NULL '');
SELECT is((SELECT count(*) FROM expected_ma_raw),35::bigint,'approved input has 35 records');
SELECT is((SELECT count(DISTINCT application_code) FROM expected_ma_raw),
          35::bigint,'all 35 source business codes are unique');
SELECT ok((SELECT bool_and(application_id IS NULL) FROM expected_ma_raw),
          'source supplies no generated IDs');
SELECT ok((SELECT bool_and(
    application_code ~ '^[A-Z]{2}[0-9]{5}$'
    AND application_title IS NOT NULL
    AND length(application_title) BETWEEN 1 AND 255
    AND application_group = 'Create Casefile'
    AND active = 'true' AND date_used_from = '2026-08-26'
    AND application_wording IS NOT NULL AND application_responses IS NOT NULL
    AND application_act_section IS NOT NULL AND application_act_summary IS NOT NULL
    AND date_used_to IS NULL) FROM expected_ma_raw),
    'source contract retains text codes, content, group, flags, dates and NULLs');

CREATE TEMP VIEW expected_ma_values AS
SELECT application_code, application_title, application_group, application_wording,
       application_responses, application_act_section, application_act_summary,
       active::boolean AS active, date_used_from::date AS date_used_from,
       date_used_to::date AS date_used_to
FROM expected_ma_raw;
CREATE TEMP VIEW actual_ma_values AS
SELECT m.application_code::text, m.application_title::text, m.application_group::text,
       m.application_wording, m.application_responses::text,
       m.application_act_section, m.application_act_summary,
       m.active, m.date_used_from, m.date_used_to
FROM public.maintenance_applications m
JOIN expected_ma_raw e ON e.application_code=m.application_code;
CREATE TEMP VIEW all_ma_rows AS
SELECT application_id, application_code, application_title, application_group,
       application_wording, application_responses::text AS application_responses,
       application_act_section, application_act_summary, active, date_used_from, date_used_to
FROM public.maintenance_applications;
-- JSON is converted to TEXT before any row serialization so lexical differences remain visible.
CREATE FUNCTION pg_temp.ma_rows() RETURNS TEXT[] LANGUAGE SQL AS $$
    SELECT coalesce(array_agg(row_to_json(r)::text ORDER BY application_id), ARRAY[]::text[])
    FROM all_ma_rows r
$$;
CREATE TEMP TABLE original_ma_rows AS SELECT pg_temp.ma_rows() AS row_snapshot;

-- Scenario: Seeded values match independently; generated values are tested separately.
-- Setup: Compare all ten supplied columns by business key, without JSON normalization.
-- Expected: Exact supplied values and 35 distinct positive generated SMALLINT IDs.
SELECT results_eq('SELECT * FROM actual_ma_values ORDER BY application_code',
                  'SELECT * FROM expected_ma_values ORDER BY application_code',
                  'every supplied scalar, text and JSON spelling matches the CSV');
SELECT ok((SELECT count(*)=35 AND count(DISTINCT m.application_id)=35
                  AND bool_and(m.application_id BETWEEN 1 AND 32767)
           FROM public.maintenance_applications m
           JOIN expected_ma_raw e USING(application_code)),
          '35 records have valid distinct generated identifiers without a gapless requirement');
SELECT is((SELECT count(*) FROM actual_ma_values WHERE date_used_to IS NULL),
          35::bigint,'all absent source end dates are SQL NULL');

-- Test-only sequence isolation: restart at its CURRENT next value, never at one.
-- ALTER SEQUENCE RESTART is transactional; ROLLBACK restores the original sequence state.
DO $$
DECLARE next_id BIGINT;
BEGIN
    SELECT last_value + CASE WHEN is_called THEN 1 ELSE 0 END
    INTO next_id FROM public.application_id_seq;
    EXECUTE format('ALTER SEQUENCE public.application_id_seq RESTART WITH %s', next_id);
    IF EXISTS(SELECT 1 FROM public.maintenance_applications
              WHERE application_code IN ('T9300001','T9300002','T9300003')
                 OR application_id=32767) THEN
        RAISE EXCEPTION 'Maintenance Applications data fixture collision';
    END IF;
END;
$$;
SELECT ok(NOT EXISTS(SELECT 1 FROM public.maintenance_applications
                     WHERE application_code IN ('T9300001','T9300002','T9300003')),
          'test-owned business keys are unused');
SAVEPOINT next_id_probe;
INSERT INTO public.maintenance_applications
    (application_code,application_title,application_group,active,date_used_from)
VALUES('T9300001','Generated ID probe','PO10293 Test',true,DATE '2026-09-24');
SELECT count(*)=1 AS ma_next_id_ok
FROM public.maintenance_applications WHERE application_code='T9300001'
\gset
ROLLBACK TO SAVEPOINT next_id_probe;
SELECT ok(:'ma_next_id_ok'::boolean,'the next generated identifier inserts without collision');

-- Scenario: The actual migration adds only the approved rows beside unrelated data.
-- Setup: Remove only CSV keys in this rolled-back scenario and add an unrelated sentinel.
-- Expected: 35 exact inserts and every unrelated row preserved, including JSON text and IDs.
SAVEPOINT unrelated_probe;
DELETE FROM public.maintenance_applications
WHERE application_code IN (SELECT application_code FROM expected_ma_raw);
INSERT INTO public.maintenance_applications
    (application_code,application_title,application_group,application_responses,active,date_used_from)
VALUES('T9300002','Unrelated record','Other group','{ "z": 1, "a": 2 }',false,DATE '2020-01-01');
CREATE TEMP TABLE before_candidate_rows AS TABLE all_ma_rows;
DO $$
BEGIN
    EXECUTE pg_read_file('/tmp/opal-db-migrations/data/allEnvs/V1_12__insert_maintenance_applications_reference_data.sql');
END;
$$;
-- Retain observations in psql variables; emit TAP assertions only AFTER fixture rollback.
SELECT NOT EXISTS (
    (SELECT * FROM actual_ma_values EXCEPT ALL SELECT * FROM expected_ma_values)
    UNION ALL
    (SELECT * FROM expected_ma_values EXCEPT ALL SELECT * FROM actual_ma_values)
) AS ma_values_match,
NOT EXISTS (
    (SELECT * FROM all_ma_rows
     WHERE application_code NOT IN (SELECT application_code FROM expected_ma_raw)
     EXCEPT ALL SELECT * FROM before_candidate_rows)
    UNION ALL
    (SELECT * FROM before_candidate_rows EXCEPT ALL SELECT * FROM all_ma_rows
     WHERE application_code NOT IN (SELECT application_code FROM expected_ma_raw))
) AS ma_unrelated_match,
(SELECT count(*) FROM all_ma_rows)-(SELECT count(*) FROM before_candidate_rows)=35 AS ma_added_35
\gset
ROLLBACK TO SAVEPOINT unrelated_probe;
SELECT ok(:'ma_values_match'::boolean,
          'actual candidate inserts exactly the supplied values beside unrelated data');
SELECT ok(:'ma_unrelated_match'::boolean,
          'all unrelated rows and identifiers are unchanged');
SELECT ok(:'ma_added_35'::boolean,'candidate adds exactly 35 rows');

-- Scenario: Known failures reject the actual candidate without changing any existing row.
-- Setup: Each fixture and candidate execute in nested, rolled-back subtransactions.
-- Expected: Intended SQLSTATE and constraint, exact pre/post rows, no partial inserts.
CREATE FUNCTION pg_temp.ma_failure_is_atomic(
    setup_sql TEXT, expected_state TEXT, expected_constraint TEXT
) RETURNS BOOLEAN LANGUAGE plpgsql AS $test$
DECLARE
    before_rows TEXT[];
    after_rows TEXT[];
    actual_state TEXT;
    actual_constraint TEXT;
    passed BOOLEAN := false;
BEGIN
    BEGIN
        EXECUTE setup_sql;
        before_rows := pg_temp.ma_rows();
        BEGIN
            EXECUTE pg_read_file('/tmp/opal-db-migrations/data/allEnvs/V1_12__insert_maintenance_applications_reference_data.sql');
        EXCEPTION WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS actual_state=RETURNED_SQLSTATE,
                                    actual_constraint=CONSTRAINT_NAME;
        END;
        after_rows := pg_temp.ma_rows();
        passed := coalesce(actual_state=expected_state
            AND actual_constraint=expected_constraint
            AND before_rows IS NOT DISTINCT FROM after_rows,false);
        RAISE EXCEPTION USING ERRCODE='Z1093', MESSAGE='rollback test setup';
    EXCEPTION WHEN SQLSTATE 'Z1093' THEN
        NULL;
    END;
    RETURN passed;
END;
$test$;

SELECT ok(pg_temp.ma_failure_is_atomic(
    'SELECT 1','23505','maintenance_applications_application_code_uk'),
    'direct replay of the fully loaded candidate is rejected without changing rows');
SELECT ok(pg_temp.ma_failure_is_atomic(
    $$DELETE FROM public.maintenance_applications
      WHERE application_code IN (SELECT application_code FROM expected_ma_raw)
        AND application_code <> 'MO72001'$$,
    '23505','maintenance_applications_application_code_uk'),
    'an identical pre-existing source key rejects the complete candidate');
SELECT ok(pg_temp.ma_failure_is_atomic(
    $$DELETE FROM public.maintenance_applications
      WHERE application_code IN (SELECT application_code FROM expected_ma_raw)
        AND application_code <> 'MO72001';
      UPDATE public.maintenance_applications SET application_title='Conflicting synthetic title'
      WHERE application_code='MO72001'$$,
    '23505','maintenance_applications_application_code_uk'),
    'a differing pre-existing source key rejects the complete candidate');
SELECT ok(pg_temp.ma_failure_is_atomic(
    $$DELETE FROM public.maintenance_applications
      WHERE application_code IN (SELECT application_code FROM expected_ma_raw);
      ALTER TABLE public.maintenance_applications ADD CONSTRAINT po10293_reject_last
      CHECK(application_code <> 'CV00001')$$,
    '23514','po10293_reject_last'),
    'last source-record failure leaves no partial candidate rows');
SELECT ok(pg_temp.ma_failure_is_atomic(
    $$DELETE FROM public.maintenance_applications
      WHERE application_code IN (SELECT application_code FROM expected_ma_raw);
      INSERT INTO public.maintenance_applications
        (application_id,application_code,application_title,application_group,active,date_used_from)
      SELECT (last_value+CASE WHEN is_called THEN 1 ELSE 0 END)::smallint,
             'T9300003','Synthetic ID collision','PO10293 Test',true,DATE '2026-09-24'
      FROM public.application_id_seq$$,
    '23505','maintenance_applications_pk'),
    'a desynchronised sequence fails atomically without repairing existing IDs');
SELECT ok(pg_temp.ma_failure_is_atomic(
    $$DELETE FROM public.maintenance_applications
      WHERE application_code IN (SELECT application_code FROM expected_ma_raw);
      ALTER SEQUENCE public.application_id_seq RESTART WITH 32767$$,
    '2200H',''),
    'sequence exhaustion during the candidate leaves no partial records');
SELECT is(pg_temp.ma_rows(),(SELECT row_snapshot FROM original_ma_rows),
          'all scenarios restore the original rows including exact JSON text');

SELECT * FROM finish();
ROLLBACK;
