-- PO-10295: exact input, replay, conflict and row-preservation contract.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(17);

-- -----------------------------------------------------------------------------
-- Scenario: independent approved source shape and representations.
-- Setup: load the retained CSV as text, with no normalization.
-- Expected: 22 complete unique source keys and all exact supplied representations.
CREATE TEMP TABLE expected_results_raw (
    result_id TEXT, result_title TEXT, order_term TEXT, enforcement_result TEXT,
    case_result TEXT, case_result_type TEXT, active TEXT, order_accruing TEXT,
    requires_creditor TEXT, enforcement_hold TEXT, requires_enforcer TEXT,
    generates_hearing TEXT, generates_warrant TEXT, lists_monies TEXT,
    result_parameters TEXT, requires_employment_data TEXT, allow_additional_action TEXT,
    enf_next_permitted_actions TEXT, manual_enforcement TEXT, auto_enforcement TEXT
);
COPY expected_results_raw
FROM '/tmp/opal-db-unit-test/resultsDataTest/results.csv'
WITH (FORMAT CSV, HEADER TRUE, NULL '');
SELECT is((SELECT count(*) FROM expected_results_raw), 22::bigint,
    'independent source contains 22 rows');
SELECT results_eq(
    'SELECT result_id FROM expected_results_raw ORDER BY result_id',
    $$SELECT unnest(ARRAY['MAT','MCHILD','MLUMP','MNSTD','MSUMM','MNENF','MADJ',
      'MPAY','MTEMP','MAEO','MWDN','MREMT','MBAIL','MCMTP','MTPDA','MTPDO',
      'MCOO','MCON','MWOC','MWCN','MWOA','MWAN']::text[]) ORDER BY 1$$,
    'independent source has exactly the 22 supplied text IDs');
SELECT ok(
    NOT EXISTS (SELECT 1 FROM expected_results_raw r,
        LATERAL json_each_text(row_to_json(r)) f WHERE f.value IS NULL OR f.value = '')
    AND NOT EXISTS (
        SELECT 1 FROM expected_results_raw r,
        LATERAL json_each_text(row_to_json(r)) f
        WHERE f.key NOT IN ('result_id','result_title','case_result_type',
                           'result_parameters','enf_next_permitted_actions')
          AND f.value NOT IN ('true','false'))
    AND (SELECT bool_and(length(result_id) BETWEEN 1 AND 6
        AND length(result_title) BETWEEN 1 AND 60
        AND case_result_type IN ('Ancillary','Interim','Final')
        AND active = 'true' AND case_result = 'true'
        AND manual_enforcement = 'false' AND auto_enforcement = 'false'
        AND enf_next_permitted_actions = 'TBC'
        AND json_typeof(result_parameters::json) = 'array') FROM expected_results_raw)
    AND (SELECT result_parameters = '[]' FROM expected_results_raw WHERE result_id='MWDN'),
    'source preserves complete values, valid representations and accepted TBC');

CREATE TEMP VIEW expected_results_values AS
SELECT result_id, result_title, order_term::boolean, enforcement_result::boolean,
       case_result::boolean, case_result_type, active::boolean, order_accruing::boolean,
       requires_creditor::boolean, enforcement_hold::boolean, requires_enforcer::boolean,
       generates_hearing::boolean, generates_warrant::boolean, lists_monies::boolean,
       result_parameters, requires_employment_data::boolean, allow_additional_action::boolean,
       enf_next_permitted_actions, manual_enforcement::boolean, auto_enforcement::boolean
FROM expected_results_raw;
CREATE TEMP VIEW all_results_values AS
SELECT result_id::text, result_title::text, order_term, enforcement_result,
       case_result, case_result_type::text, active, order_accruing,
       requires_creditor, enforcement_hold, requires_enforcer,
       generates_hearing, generates_warrant, lists_monies,
       result_parameters::text, requires_employment_data, allow_additional_action,
       enf_next_permitted_actions::text, manual_enforcement, auto_enforcement
FROM public.results;
CREATE TEMP VIEW actual_results_values AS
SELECT r.* FROM all_results_values r JOIN expected_results_raw e USING(result_id);
CREATE FUNCTION pg_temp.results_snapshot() RETURNS TEXT[] LANGUAGE SQL AS $f$
    SELECT coalesce(array_agg(row_to_json(r)::text ORDER BY result_id), ARRAY[]::text[])
    FROM all_results_values r
$f$;
CREATE TEMP TABLE original_results_snapshot AS SELECT pg_temp.results_snapshot() AS rows;

-- -----------------------------------------------------------------------------
-- Scenario: seeded data matches the independently retained expected input.
-- Setup: compare every column at supplied keys; convert JSON to text first.
-- Expected: exact 22 rows; no migration staging object remains.
SELECT results_eq('SELECT * FROM actual_results_values ORDER BY result_id',
                  'SELECT * FROM expected_results_values ORDER BY result_id',
                  'all 20 supplied fields match exactly, including JSON text');
SELECT ok(to_regclass('pg_temp.temp_results_seed') IS NULL,
          'successful migration leaves no staging object');

DO $guard$
BEGIN
    IF EXISTS (SELECT 1 FROM public.results WHERE result_id='T95001') THEN
        RAISE EXCEPTION 'Results data fixture key is already in use';
    END IF;
END;
$guard$;

-- -----------------------------------------------------------------------------
-- Scenario: direct replay, missing row and fresh seed beside unrelated rows.
-- Setup: isolate fixtures under a savepoint and rerun the actual candidate.
-- Expected: exact seed values; all other rows retain their exact text and flags.
SAVEPOINT success_scenarios;
INSERT INTO public.results
SELECT 'T95001', 'Unrelated synthetic Result', false, false, true,
       'Ancillary'::public.t_case_result_type_enum, false, false, false, false,
       false, false, false, false, '{ "z": 1, "a": 2 }'::json,
       false, false, 'All', false, false;
CREATE TEMP TABLE before_direct_replay AS SELECT pg_temp.results_snapshot() AS rows;
\ir /tmp/opal-db-migrations/data/allEnvs/V1_13__insert_results_reference_data.sql
SELECT pg_temp.results_snapshot() = (SELECT rows FROM before_direct_replay)
       AND to_regclass('pg_temp.temp_results_seed') IS NULL AS replay_ok
\gset
CREATE TEMP TABLE before_partial AS SELECT * FROM all_results_values WHERE result_id <> 'MAT';
DELETE FROM public.results WHERE result_id='MAT';
\ir /tmp/opal-db-migrations/data/allEnvs/V1_13__insert_results_reference_data.sql
SELECT NOT EXISTS (
    (SELECT * FROM actual_results_values EXCEPT ALL SELECT * FROM expected_results_values)
    UNION ALL
    (SELECT * FROM expected_results_values EXCEPT ALL SELECT * FROM actual_results_values)
) AS partial_exact,
NOT EXISTS (
    (SELECT * FROM all_results_values WHERE result_id <> 'MAT' EXCEPT ALL SELECT * FROM before_partial)
    UNION ALL
    (SELECT * FROM before_partial EXCEPT ALL SELECT * FROM all_results_values WHERE result_id <> 'MAT')
) AS partial_untouched
\gset
DELETE FROM public.results WHERE result_id IN (SELECT result_id FROM expected_results_raw);
CREATE TEMP TABLE before_fresh AS TABLE all_results_values;
\ir /tmp/opal-db-migrations/data/allEnvs/V1_13__insert_results_reference_data.sql
SELECT NOT EXISTS (
    (SELECT * FROM actual_results_values EXCEPT ALL SELECT * FROM expected_results_values)
    UNION ALL
    (SELECT * FROM expected_results_values EXCEPT ALL SELECT * FROM actual_results_values)
) AS fresh_exact,
NOT EXISTS (
    (SELECT * FROM all_results_values WHERE result_id NOT IN (SELECT result_id FROM expected_results_raw)
     EXCEPT ALL SELECT * FROM before_fresh)
    UNION ALL
    (SELECT * FROM before_fresh EXCEPT ALL
     SELECT * FROM all_results_values WHERE result_id NOT IN (SELECT result_id FROM expected_results_raw))
) AS fresh_untouched,
(SELECT count(*) FROM all_results_values) - (SELECT count(*) FROM before_fresh) = 22 AS added_22
\gset
ROLLBACK TO SAVEPOINT success_scenarios;
-- Emit TAP only after rollback so pgTAP assertion counters do not roll back.
SELECT ok(:'replay_ok'::boolean, 'direct replay preserves identical and unrelated rows');
SELECT ok(:'partial_exact'::boolean, 'partial seed receives its missing row exactly');
SELECT ok(:'partial_untouched'::boolean, 'partial seed preserves every surviving row');
SELECT ok(:'fresh_exact'::boolean, 'actual candidate inserts all exact source values');
SELECT ok(:'fresh_untouched'::boolean, 'actual candidate preserves unrelated rows');
SELECT ok(:'added_22'::boolean, 'empty seed scope adds exactly 22 records');

-- -----------------------------------------------------------------------------
-- Scenario: actual candidate failure preserves its pre-attempt database state.
-- Setup: scenario fixtures are outer-subtransaction changes; candidate is inner.
-- Expected: intended error, identical rows, no staging; fixtures also rolled back.
CREATE FUNCTION pg_temp.results_failure_is_atomic(
    setup_sql TEXT, expected_state TEXT, expected_message TEXT, expected_constraint TEXT
) RETURNS BOOLEAN LANGUAGE plpgsql AS $test$
DECLARE
    before_rows TEXT[];
    actual_state TEXT;
    actual_message TEXT;
    actual_constraint TEXT;
    passed BOOLEAN := false;
BEGIN
    BEGIN
        EXECUTE setup_sql;
        before_rows := pg_temp.results_snapshot();
        BEGIN
            EXECUTE pg_read_file('/tmp/opal-db-migrations/data/allEnvs/V1_13__insert_results_reference_data.sql');
        EXCEPTION WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS actual_state=RETURNED_SQLSTATE,
                actual_message=MESSAGE_TEXT, actual_constraint=CONSTRAINT_NAME;
        END;
        passed := coalesce(actual_state=expected_state
            AND (expected_message IS NULL OR actual_message=expected_message)
            AND (expected_constraint IS NULL OR actual_constraint=expected_constraint)
            AND pg_temp.results_snapshot()=before_rows
            AND to_regclass('pg_temp.temp_results_seed') IS NULL, false);
        RAISE EXCEPTION USING ERRCODE='ZX095', MESSAGE='rollback Results test fixture';
    EXCEPTION WHEN SQLSTATE 'ZX095' THEN
        NULL;
    END;
    RETURN passed;
END;
$test$;
SELECT ok(pg_temp.results_failure_is_atomic(
    $$DELETE FROM public.results WHERE result_id='MAT';
      UPDATE public.results SET result_title='Conflicting title' WHERE result_id='MWDN'$$,
    'P0001','PO-10295 conflicting Results: MWDN',NULL),
    'scalar conflict rejects the actual candidate without filling a missing row');
SELECT ok(pg_temp.results_failure_is_atomic(
    $$DELETE FROM public.results WHERE result_id='MAT';
      UPDATE public.results SET result_parameters='[ ]'::json WHERE result_id='MWDN'$$,
    'P0001','PO-10295 conflicting Results: MWDN',NULL),
    'lexically different but equivalent JSON is a conflict');
SELECT ok(pg_temp.results_failure_is_atomic(
    $$DELETE FROM public.results WHERE result_id='MAT';
      UPDATE public.results SET case_result_type=NULL WHERE result_id='MWDN'$$,
    'P0001','PO-10295 conflicting Results: MWDN',NULL),
    'NULL differs from a supplied enum and cannot be silently accepted');
SELECT ok(pg_temp.results_failure_is_atomic(
    $$DELETE FROM public.results WHERE result_id IN (SELECT result_id FROM expected_results_raw);
      ALTER TABLE public.results ADD CONSTRAINT po10295_reject_last CHECK(result_id <> 'MWOC')$$,
    '23514',NULL,'po10295_reject_last'),
    'late-row rejection leaves no partial candidate rows');
SELECT is(pg_temp.results_snapshot(), (SELECT rows FROM original_results_snapshot),
          'all successful and failing scenarios restore the original full dataset');
SELECT ok(to_regclass('pg_temp.temp_results_seed') IS NULL,
          'all scenarios leave no staging object');
SELECT * FROM finish();
ROLLBACK;
