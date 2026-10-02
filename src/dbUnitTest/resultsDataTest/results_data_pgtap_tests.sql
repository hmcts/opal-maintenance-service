BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(11);

-- -----------------------------------------------------------------------------
-- Scenario: independently supplied data and exact final values.
-- Setup: retain CSV bytes; load all fields as text before explicit conversion.
-- Expected: exact keys, 86 parameters, all 20 fields including JSON text match.
-- -----------------------------------------------------------------------------
CREATE TEMP TABLE expected_results_raw (
    result_id text, result_title text, order_term text, enforcement_result text,
    case_result text, case_result_type text, active text, order_accruing text,
    requires_creditor text, enforcement_hold text, requires_enforcer text,
    generates_hearing text, generates_warrant text, lists_monies text,
    result_parameters text, requires_employment_data text, allow_additional_action text,
    enf_next_permitted_actions text, manual_enforcement text, auto_enforcement text
);
COPY expected_results_raw FROM '/tmp/opal-db-unit-test/resultsDataTest/results.csv'
WITH (FORMAT CSV, HEADER TRUE, NULL '');
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
CREATE FUNCTION pg_temp.results_snapshot() RETURNS text[] LANGUAGE SQL AS $f$
    SELECT coalesce(array_agg(row_to_json(r)::text ORDER BY result_id), ARRAY[]::text[])
    FROM all_results_values r
$f$;
CREATE TEMP TABLE before_suite AS SELECT pg_temp.results_snapshot() AS rows;
SELECT is((SELECT count(*) FROM expected_results_raw),22::bigint,'22 source rows');
SELECT results_eq('SELECT result_id FROM expected_results_raw ORDER BY result_id',
 $$SELECT unnest(ARRAY['MAT','MCHILD','MLUMP','MNSTD','MSUMM','MNENF','MADJ',
 'MPAY','MTEMP','MAEO','MWDN','MREMT','MBAIL','MCMTP','MTPDA','MTPDO',
 'MCOO','MCON','MWOC','MWCN','MWOA','MWAN']::text[]) ORDER BY 1$$,
 'exact unique source keys');
SELECT is((SELECT sum(json_array_length(result_parameters::json))::bigint
           FROM expected_results_raw),86::bigint,'86 supplied parameters');
SELECT results_eq('SELECT * FROM actual_results_values ORDER BY result_id',
                  'SELECT * FROM expected_results_values ORDER BY result_id',
                  'all 20 fields match supplied values including JSON text');
SELECT is((SELECT count(*) FROM actual_results_values
           WHERE enf_next_permitted_actions IS NULL),22::bigint,'all 22 actions are SQL NULL');

CREATE TEMP TABLE candidate_sql AS
SELECT pg_read_file('/tmp/opal-db-migrations/data/allEnvs/V1_16__refresh_results_reference_data.sql') AS sql;

-- -----------------------------------------------------------------------------
-- Scenario: repeat the actual refresh over changed target values and unrelated data.
-- Setup: synthetic unrelated key and non-target target-column change; subtransaction.
-- Expected: only approved fields change; replay preserves final values; fixtures roll back.
-- -----------------------------------------------------------------------------
CREATE FUNCTION pg_temp.refresh_preserves_scope() RETURNS boolean LANGUAGE plpgsql AS $f$
DECLARE
    before_other jsonb;
    before_unrelated text[];
    after_first text[];
    passed boolean := false;
BEGIN
    BEGIN
        IF EXISTS (SELECT 1 FROM public.results WHERE result_id='T94001') THEN
            RAISE EXCEPTION 'Results fixture T94001 is already in use';
        END IF;
        INSERT INTO public.results VALUES
          ('T94001','Unrelated synthetic Result',false,false,true,'Ancillary',
           false,false,false,false,false,false,false,false,
           '{ "z": 1, "a": 2 }'::json,false,false,'All',false,false);
        UPDATE public.results SET result_title='Synthetic preserved title',
          order_term=false, result_parameters='[]'::json, enf_next_permitted_actions='All'
          WHERE result_id='MAT';
        SELECT jsonb_agg(to_jsonb(r)-'order_term'-'result_parameters'-'enf_next_permitted_actions'
                         ORDER BY result_id) INTO before_other FROM actual_results_values r;
        SELECT array_agg(row_to_json(r)::text ORDER BY result_id) INTO before_unrelated
          FROM all_results_values r WHERE result_id NOT IN (SELECT result_id FROM expected_results_raw);
        EXECUTE (SELECT sql FROM candidate_sql);
        passed := before_other IS NOT DISTINCT FROM
          (SELECT jsonb_agg(to_jsonb(r)-'order_term'-'result_parameters'-'enf_next_permitted_actions'
                            ORDER BY result_id) FROM actual_results_values r)
          AND before_unrelated IS NOT DISTINCT FROM
          (SELECT array_agg(row_to_json(r)::text ORDER BY result_id) FROM all_results_values r
            WHERE result_id NOT IN (SELECT result_id FROM expected_results_raw))
          AND NOT EXISTS (
            SELECT 1 FROM actual_results_values a JOIN expected_results_values e USING(result_id)
            WHERE (a.order_term,a.result_parameters,a.enf_next_permitted_actions)
              IS DISTINCT FROM (e.order_term,e.result_parameters,e.enf_next_permitted_actions));
        after_first := pg_temp.results_snapshot();
        EXECUTE (SELECT sql FROM candidate_sql);
        passed := passed AND after_first=pg_temp.results_snapshot();
        RAISE EXCEPTION USING ERRCODE='ZX094', MESSAGE='rollback synthetic success scenario';
    EXCEPTION WHEN SQLSTATE 'ZX094' THEN NULL;
    END;
    RETURN passed;
END;
$f$;
SELECT ok(pg_temp.refresh_preserves_scope(),'actual refresh preserves scope and replay values');

-- -----------------------------------------------------------------------------
-- Scenario: actual candidate failures are atomic.
-- Setup: vary an early target row and reject the last UPDATE with a test constraint.
-- Expected: SQLSTATE 23514 and unchanged pre-attempt rows; all earlier updates roll back.
-- -----------------------------------------------------------------------------
CREATE FUNCTION pg_temp.refresh_failure(setup_sql text, expected_state text,
                                         candidate_override text DEFAULT NULL)
RETURNS boolean LANGUAGE plpgsql AS $f$
DECLARE
    before_rows text[];
    actual_state text;
    passed boolean := false;
BEGIN
    BEGIN
        EXECUTE setup_sql;
        before_rows := pg_temp.results_snapshot();
        BEGIN
            EXECUTE coalesce(candidate_override,(SELECT sql FROM candidate_sql));
        EXCEPTION WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS actual_state=RETURNED_SQLSTATE;
        END;
        passed := coalesce(actual_state=expected_state
            AND before_rows=pg_temp.results_snapshot(),false);
        RAISE EXCEPTION USING ERRCODE='ZX094', MESSAGE='rollback synthetic failure scenario';
    EXCEPTION WHEN SQLSTATE 'ZX094' THEN NULL;
    END;
    RETURN passed;
END;
$f$;
SELECT ok(pg_temp.refresh_failure(
 $$UPDATE public.results SET order_term=false,result_parameters='[]',
     enf_next_permitted_actions='All' WHERE result_id='MAT';
   UPDATE public.results SET enf_next_permitted_actions='All' WHERE result_id='MWAN';
   ALTER TABLE public.results ADD CONSTRAINT results_refresh_reject
     CHECK(result_id <> 'MWAN' OR enf_next_permitted_actions IS NOT NULL)$$,
 '23514'),'late SQL error rolls back all earlier updates');
-- -----------------------------------------------------------------------------
-- Scenario: immutable original seed still rejects duplicate existing keys.
-- Setup: run the original INSERT in the same rollback-protected failure helper.
-- Expected: unique violation, with no overwritten rows or filled missing keys.
-- -----------------------------------------------------------------------------
SELECT ok(pg_temp.refresh_failure('SELECT 1','23505',
 pg_read_file('/tmp/opal-db-migrations/data/allEnvs/V1_13__insert_results_reference_data.sql')),
 'original seed rejects existing keys');
SELECT ok(pg_temp.refresh_failure(
 $$UPDATE public.results SET result_title='Synthetic differing title' WHERE result_id='MAT'$$,
 '23505',
 pg_read_file('/tmp/opal-db-migrations/data/allEnvs/V1_13__insert_results_reference_data.sql')),
 'original seed does not overwrite differing rows');
SELECT ok(pg_temp.refresh_failure(
 $$DELETE FROM public.results WHERE result_id <> 'MWAN'
   AND result_id IN (SELECT result_id FROM expected_results_raw)$$,
 '23505',
 pg_read_file('/tmp/opal-db-migrations/data/allEnvs/V1_13__insert_results_reference_data.sql')),
 'original seed late duplicate leaves no partial inserted rows');
SELECT is(pg_temp.results_snapshot(),(SELECT rows FROM before_suite),'all fixtures restored');
SELECT * FROM finish();
ROLLBACK;
