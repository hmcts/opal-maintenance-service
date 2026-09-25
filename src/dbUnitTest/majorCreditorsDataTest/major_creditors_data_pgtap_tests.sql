/* PO-10296: Independent Central Authority data, rerun and row-scope contract.
 * Data assertions apply to fresh installation and predecessor upgrade.
 * The existing Major Creditors schema suite retains ownership of schema checks.
 */
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(19);

-- -----------------------------------------------------------------------------
-- Scenario: Approved input retains exact identifiers, defaults and flags.
-- Setup: Read the independently retained CSV; generated identifiers stay blank.
-- Expected: Ten ordered text codes, BU44, true flags and no supplied generated IDs.
-- -----------------------------------------------------------------------------
CREATE TEMP TABLE expected_major_creditors AS
SELECT major_creditor_id, business_unit_id, major_creditor_code, name,
       address_line_1, address_line_2, address_line_3, address_line_4,
       address_line_5, postcode, country_id, contact_name, contact_email,
       active, central_authority
FROM public.major_creditors WITH NO DATA;
COPY expected_major_creditors (
    major_creditor_id, business_unit_id, major_creditor_code, name,
    address_line_1, address_line_2, address_line_3, address_line_4,
    address_line_5, postcode, country_id, contact_name, contact_email,
    active, central_authority
)
FROM '/tmp/opal-db-unit-test/majorCreditorsDataTest/major-creditors.csv'
WITH (FORMAT CSV, HEADER TRUE, NULL '');

SELECT is((SELECT count(*) FROM expected_major_creditors), 10::bigint,
    'the approved source contains ten Central Authorities');
SELECT ok(
    (SELECT array_agg(major_creditor_code::text ORDER BY major_creditor_code)
        = ARRAY['0001','0002','0003','0004','0005','0006','0007','0008','0009','0010']
     AND bool_and(business_unit_id = 44 AND active AND central_authority)
     FROM expected_major_creditors),
    'source codes retain leading zeros, BU44 and both true flags');
SELECT ok(
    (SELECT bool_and(major_creditor_id IS NULL AND country_id IS NULL)
     FROM expected_major_creditors),
    'the source supplies no generated identifiers');

-- -----------------------------------------------------------------------------
-- Scenario: Documented countries resolve without guessing generated identifiers.
-- Setup: Read a separate mapping fixture taken from the approved Markdown.
-- Expected: Every creditor maps once and each name resolves to exactly one country.
-- -----------------------------------------------------------------------------
CREATE TEMP TABLE expected_major_creditor_countries (
    major_creditor_code VARCHAR(4) PRIMARY KEY,
    country_name VARCHAR(100) NOT NULL
);
COPY expected_major_creditor_countries
FROM '/tmp/opal-db-unit-test/majorCreditorsDataTest/major-creditor-countries.csv'
WITH (FORMAT CSV, HEADER TRUE);
SELECT ok(
    (SELECT count(*) = 10 FROM expected_major_creditor_countries)
    AND NOT EXISTS (
        SELECT e.major_creditor_code
        FROM expected_major_creditors e
        LEFT JOIN expected_major_creditor_countries m USING (major_creditor_code)
        LEFT JOIN public.countries c ON c.country_name = m.country_name
        GROUP BY e.major_creditor_code HAVING count(c.country_id) <> 1
    ), 'all documented country mappings resolve exactly once');
UPDATE expected_major_creditors e
SET country_id = (
    SELECT c.country_id
    FROM expected_major_creditor_countries m
    JOIN public.countries c ON c.country_name = m.country_name
    WHERE m.major_creditor_code = e.major_creditor_code
);
CREATE TEMP VIEW expected_seed_values AS
SELECT business_unit_id, major_creditor_code, name,
       address_line_1, address_line_2, address_line_3, address_line_4,
       address_line_5, postcode, country_id, contact_name, contact_email,
       active, central_authority
FROM expected_major_creditors;
CREATE TEMP VIEW actual_seed_values AS
SELECT m.business_unit_id, m.major_creditor_code, m.name,
       m.address_line_1, m.address_line_2, m.address_line_3, m.address_line_4,
       m.address_line_5, m.postcode, m.country_id, m.contact_name, m.contact_email,
       m.active, m.central_authority
FROM public.major_creditors m
JOIN expected_major_creditors e USING (business_unit_id, major_creditor_code);

-- -----------------------------------------------------------------------------
-- Scenario: Every source-controlled value and generated relationship is correct.
-- Setup: Compare all 14 non-generated target columns for the exact seed keys.
-- Expected: Exact rows including NULL/Unicode/text, unique generated IDs and FKs.
-- -----------------------------------------------------------------------------
SELECT results_eq(
    'SELECT * FROM actual_seed_values ORDER BY major_creditor_code',
    'SELECT * FROM expected_seed_values ORDER BY major_creditor_code',
    'all supplied values and resolved country IDs match independently');
SELECT is(
    (SELECT count(DISTINCT m.major_creditor_id)
     FROM public.major_creditors m
     JOIN expected_major_creditors e USING (business_unit_id, major_creditor_code)),
    10::bigint, 'all ten records have distinct generated IDs');
SELECT is(
    (SELECT count(*) FROM actual_seed_values a
     JOIN public.business_units b USING (business_unit_id)
     JOIN public.countries c USING (country_id)),
    10::bigint, 'both foreign-key relationships resolve for all ten records');
SELECT ok(to_regclass('pg_temp.temp_major_creditors_seed') IS NULL,
    'no seed staging table remains');

-- -----------------------------------------------------------------------------
-- Scenario: Direct reruns preserve identical and unrelated rows including IDs.
-- Setup: Add a test-owned unrelated key, snapshot the table, rerun actual SQL.
-- Expected: The complete table is unchanged and staging is explicitly dropped.
-- -----------------------------------------------------------------------------
INSERT INTO public.major_creditors (
    business_unit_id, major_creditor_code, name, address_line_1,
    active, central_authority
) VALUES (44, 'T999', 'PO10296 unrelated test row', 'Test address', TRUE, FALSE);
CREATE TEMP TABLE before_rerun AS TABLE public.major_creditors;
\ir /tmp/opal-db-migrations/data/allEnvs/V1_10__insert_major_creditors_reference_data.sql
SELECT results_eq(
    'SELECT * FROM public.major_creditors ORDER BY major_creditor_id',
    'SELECT * FROM before_rerun ORDER BY major_creditor_id',
    'direct rerun preserves every existing value and ID, including unrelated rows');
SELECT ok(to_regclass('pg_temp.temp_major_creditors_seed') IS NULL,
    'successful direct rerun explicitly drops staging');

-- -----------------------------------------------------------------------------
-- Scenario: A partial dataset receives only its missing record.
-- Setup: Remove code 0005 and rerun the actual SQL in this rolled-back fixture.
-- Expected: All seed values match; surviving and unrelated IDs remain unchanged.
-- -----------------------------------------------------------------------------
DELETE FROM public.major_creditors WHERE business_unit_id = 44 AND major_creditor_code = '0005';
\ir /tmp/opal-db-migrations/data/allEnvs/V1_10__insert_major_creditors_reference_data.sql
SELECT results_eq(
    'SELECT * FROM actual_seed_values ORDER BY major_creditor_code',
    'SELECT * FROM expected_seed_values ORDER BY major_creditor_code',
    'a partial rerun restores exactly the missing source record');
SELECT results_eq(
    $q$SELECT * FROM public.major_creditors
       WHERE NOT (business_unit_id = 44 AND major_creditor_code = '0005')
       ORDER BY major_creditor_id$q$,
    $q$SELECT * FROM before_rerun
       WHERE NOT (business_unit_id = 44 AND major_creditor_code = '0005')
       ORDER BY major_creditor_id$q$,
    'partial rerun preserves surviving and unrelated rows including IDs');
SELECT ok(to_regclass('pg_temp.temp_major_creditors_seed') IS NULL,
    'partial rerun explicitly drops staging');
-- -----------------------------------------------------------------------------
-- Scenario: Reference errors and conflicting data reject the complete seed.
-- Setup: Each case creates a synthetic failure inside a rolled-back subtransaction.
-- Expected: Exact SQLSTATE, matching diagnostic, unchanged rows and no staging.
-- The real migration is read from the test container, not duplicated here.
-- -----------------------------------------------------------------------------
CREATE FUNCTION pg_temp.seed_failure_is_atomic(setup_sql TEXT, expected_state TEXT, diagnostic TEXT)
RETURNS BOOLEAN LANGUAGE plpgsql AS $test$
DECLARE
    before_rows JSONB;
    after_rows JSONB;
    actual_state TEXT;
    actual_message TEXT;
    passed BOOLEAN := FALSE;
BEGIN
    BEGIN
        EXECUTE setup_sql;
        SELECT jsonb_agg(to_jsonb(m) ORDER BY major_creditor_id)
        INTO before_rows FROM public.major_creditors m;
        BEGIN
            EXECUTE pg_read_file('/tmp/opal-db-migrations/data/allEnvs/V1_10__insert_major_creditors_reference_data.sql');
        EXCEPTION WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS actual_state = RETURNED_SQLSTATE, actual_message = MESSAGE_TEXT;
        END;
        SELECT jsonb_agg(to_jsonb(m) ORDER BY major_creditor_id)
        INTO after_rows FROM public.major_creditors m;
        passed := coalesce(actual_state = expected_state
            AND position(diagnostic IN actual_message) > 0
            AND before_rows IS NOT DISTINCT FROM after_rows
            AND to_regclass('pg_temp.temp_major_creditors_seed') IS NULL, FALSE);
        -- Roll back setup even on success; PL/pgSQL variables retain their values.
        RAISE EXCEPTION USING ERRCODE = 'Z1096', MESSAGE = 'rollback test setup';
    EXCEPTION WHEN SQLSTATE 'Z1096' THEN
        NULL;
    END;
    RETURN passed;
END;
$test$;

SELECT ok(pg_temp.seed_failure_is_atomic(
    $$UPDATE public.major_creditors SET name = 'Conflicting test name'
      WHERE business_unit_id = 44 AND major_creditor_code = '0001'$$,
    'P0001', 'Existing Major Creditors differ'),
    'conflicting source values fail without changing rows or leaving staging');
SELECT ok(pg_temp.seed_failure_is_atomic(
    $$UPDATE public.major_creditors SET contact_name = 'Test contact'
      WHERE business_unit_id = 44 AND major_creditor_code = '0001'$$,
    'P0001', 'Existing Major Creditors differ'),
    'NULL versus populated conflicts fail atomically');
SELECT ok(pg_temp.seed_failure_is_atomic(
    $$UPDATE public.countries SET country_name = 'Hidden Finland' WHERE country_name = 'Finland'$$,
    'P0001', 'No Country found for creditor 0002: Finland'),
    'missing country fails atomically');
SELECT ok(pg_temp.seed_failure_is_atomic(
    $$INSERT INTO public.countries(cjs_code, country_name, date_used_from, active)
      VALUES (32000, 'Finland', DATE '2026-09-23', TRUE)$$,
    'P0001', 'Multiple Countries found for creditor 0002: Finland'),
    'ambiguous country fails atomically');
SELECT ok(pg_temp.seed_failure_is_atomic(
    $$DELETE FROM public.major_creditors WHERE business_unit_id = 44;
      DELETE FROM public.business_units WHERE business_unit_id = 44$$,
    '23503', 'mc_business_unit_id_fk'),
    'missing Business Unit rejects every seed row');
SELECT ok(pg_temp.seed_failure_is_atomic(
    $$DELETE FROM public.major_creditors WHERE business_unit_id = 44;
      ALTER TABLE public.major_creditors ADD CONSTRAINT po10296_reject_last
      CHECK (major_creditor_code <> '0010')$$,
    '23514', 'po10296_reject_last'),
    'late insert failure leaves no partial dataset');

SELECT * FROM finish();
ROLLBACK;
