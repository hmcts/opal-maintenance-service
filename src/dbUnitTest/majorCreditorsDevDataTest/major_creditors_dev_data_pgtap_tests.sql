-- PO-10297 / V1_17: DEV reference data boundary contract.
-- Assertions apply to both fresh DB-01 and predecessor-to-candidate DB-03 paths.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(9);

-- -----------------------------------------------------------------------------
-- Scenario: DEV seed supplies exactly three independent synthetic business keys.
-- Setup: Normal Flyway ddl, allEnvs and dev migrations have completed.
-- Expected: Exact details and flags, generated positive IDs and existing Country FK.
-- -----------------------------------------------------------------------------
SELECT results_eq(
    $q$SELECT major_creditor_code::TEXT, name::TEXT, address_line_1::TEXT,
              address_line_2::TEXT, postcode::TEXT, contact_name::TEXT, contact_email::TEXT,
              active, central_authority, address_line_3::TEXT, address_line_4::TEXT, address_line_5::TEXT
       FROM public.major_creditors
       WHERE business_unit_id = 44 AND major_creditor_code IN ('T901', 'T902', 'T903')
       ORDER BY major_creditor_code$q$,
    $q$VALUES
       ('T901', 'Functional Test Major Creditor', '1 Synthetic Test Street',
        'Synthetic Test Town', 'ZZ1 1ZZ', 'Synthetic Test Contact', 'creditor@example.invalid',
        TRUE, FALSE, 'Synthetic Test District', 'Synthetic Test Region', 'Synthetic Test Province'),
       ('T902', 'Inactive Functional Test Creditor', '2 Synthetic Test Street',
        NULL, NULL, NULL, NULL, FALSE, FALSE, NULL, NULL, NULL),
       ('T903', 'Functional Test Central Authority', '3 Synthetic Test Street',
        NULL, NULL, NULL, NULL, TRUE, TRUE, NULL, NULL, NULL)$q$,
    'DEV business keys contain exactly the expected synthetic details and selection flags');
SELECT ok((SELECT count(*) = 3 AND count(DISTINCT major_creditor_id) = 3
                  AND bool_and(major_creditor_id > 0)
           FROM public.major_creditors WHERE business_unit_id = 44
             AND major_creditor_code IN ('T901', 'T902', 'T903')),
    'three DEV creditors have unique positive generated identifiers');
SELECT is((SELECT count(*) FROM public.major_creditors m
           JOIN public.countries c ON c.country_id = m.country_id
           WHERE m.business_unit_id = 44 AND m.major_creditor_code IN ('T901', 'T902', 'T903')
             AND c.country_name = 'Czech Republic'), 3::BIGINT,
    'all DEV Country relationships resolve to the existing Czech Republic');

-- -----------------------------------------------------------------------------
-- Scenario: DEV extension preserves approved Authorities and selects only T901.
-- Setup: Both approved allEnvs seed and synthetic DEV seed are present.
-- Expected: Ten approved keys remain active Authorities; only T901 qualifies.
-- Existing majorCreditorsDataTest independently verifies all approved details.
-- -----------------------------------------------------------------------------
SELECT is((SELECT count(*) FROM public.major_creditors
           WHERE business_unit_id = 44 AND active AND central_authority
             AND major_creditor_code IN ('0001', '0002', '0003', '0004', '0005',
                                        '0006', '0007', '0008', '0009', '0010')),
          10::BIGINT, 'all ten approved Central Authority business keys remain present');
SELECT results_eq(
    $q$SELECT major_creditor_code::TEXT FROM public.major_creditors
       WHERE business_unit_id = 44 AND active AND NOT central_authority
       ORDER BY major_creditor_code$q$,
    $$VALUES ('T901'::TEXT)$$,
    'active non-Central Authority selection includes T901 and excludes both comparator rows');

-- -----------------------------------------------------------------------------
-- Scenario: Reruns, collisions and invalid Country prerequisites fail atomically.
-- Setup: Run the actual migration in rolled-back PL/pgSQL subtransactions.
-- Expected: Precise SQLSTATE and unchanged creditor rows; never overwrite or skip.
-- Sequence gaps from attempted inserts are permitted; IDs are not hard-coded.
-- -----------------------------------------------------------------------------
CREATE FUNCTION pg_temp.dev_seed_failure_is_atomic(setup_sql TEXT, expected_state TEXT)
RETURNS BOOLEAN LANGUAGE plpgsql AS $test$
DECLARE
    before_rows JSONB;
    after_rows JSONB;
    actual_state TEXT;
    passed BOOLEAN := FALSE;
BEGIN
    BEGIN
        EXECUTE setup_sql;
        SELECT jsonb_agg(to_jsonb(m) ORDER BY major_creditor_id)
        INTO before_rows FROM public.major_creditors m;
        BEGIN
            EXECUTE pg_read_file('/tmp/opal-db-migrations/data/dev/V1_17__insert_major_creditors_dev_data.sql');
        EXCEPTION WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS actual_state = RETURNED_SQLSTATE;
        END;
        SELECT jsonb_agg(to_jsonb(m) ORDER BY major_creditor_id)
        INTO after_rows FROM public.major_creditors m;
        passed := coalesce(actual_state = expected_state
            AND before_rows IS NOT DISTINCT FROM after_rows, FALSE);
        RAISE EXCEPTION USING ERRCODE = 'Z1097', MESSAGE = 'rollback test setup';
    EXCEPTION WHEN SQLSTATE 'Z1097' THEN
        NULL;
    END;
    RETURN passed;
END;
$test$;
SELECT ok(pg_temp.dev_seed_failure_is_atomic('SELECT 1', '23505'),
    'direct migration rerun rejects duplicate keys without overwriting any creditor');
SELECT ok(pg_temp.dev_seed_failure_is_atomic(
    $$DELETE FROM public.major_creditors WHERE business_unit_id = 44
          AND major_creditor_code IN ('T901', 'T902', 'T903');
      INSERT INTO public.major_creditors
          (business_unit_id, major_creditor_code, name, address_line_1, active, central_authority)
      VALUES (44, 'T902', 'Synthetic collision', 'Synthetic collision address', TRUE, FALSE)$$,
    '23505'), 'a middle-row key collision rolls back the complete insert and preserves the existing row');
SELECT ok(pg_temp.dev_seed_failure_is_atomic(
    $$DELETE FROM public.major_creditors WHERE business_unit_id = 44
          AND major_creditor_code IN ('T901', 'T902', 'T903');
      UPDATE public.countries SET country_name = 'Hidden Czech Republic'
          WHERE country_name = 'Czech Republic'$$,
    'P0002'), 'missing Czech Republic fails before inserting any DEV creditor');
SELECT ok(pg_temp.dev_seed_failure_is_atomic(
    $$DELETE FROM public.major_creditors WHERE business_unit_id = 44
          AND major_creditor_code IN ('T901', 'T902', 'T903');
      INSERT INTO public.countries (cjs_code, country_name, date_used_from, active)
      VALUES (32000, 'Czech Republic', DATE '2026-10-02', TRUE)$$,
    'P0003'), 'ambiguous Czech Republic fails before inserting any DEV creditor');

SELECT * FROM finish();
ROLLBACK;
