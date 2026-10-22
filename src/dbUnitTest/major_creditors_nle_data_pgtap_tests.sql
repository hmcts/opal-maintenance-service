/**
 * OPAL Program
 *
 * MODULE      : major_creditors_nle_data_pgtap_tests.sql
 *
 * DESCRIPTION : Verify the synthetic Major Creditor seed in fresh non-live databases,
 *               including exact data, repeat safety, row scope and atomic failures.
 *
 * CHANGE HISTORY:
 *
 * Date        Author          Ticket    Nature of Change
 * ----------  --------------  --------  ---------------------------------------------
 * 21/10/2026  Jonathan Duffy  PO-10297  Initial pgTAP test suite.
 * 22/10/2026  Frankie Moran  PO-10643  Verify compact seed observations through shared dispatch.
 */
-- OPAL-DB-UPGRADE {"id":"major-creditors.nle-seed","candidate":"data/nle/V1_34__insert_major_creditors_nle_data.sql","scope":"both","data":"migration-created-only","contract":{"type":"data","objects":{"created":[],"replaced":[]},"preserve":{"rows":["public.countries","public.business_units"],"tables":["public.major_creditors","public.countries","public.business_units"],"routines":["public.f_get_check_letter(character varying)","public.f_get_account_number(smallint,public.t_associated_record_type_enum)"],"enums":["public.t_business_unit_type_enum","public.t_associated_record_type_enum"],"sequences":["public.country_id_seq","public.account_number_index_id_seq"]},"observe":{"rows":["public.major_creditors"],"sequences":["public.major_creditor_id_seq"]},"assertion":"major-creditors.nle-seed","custom":{"verify":"owner"}}}

-- PO-10297 / V1_34: fresh DB-01 contract for DEV and common NLE profiles.
-- Assertions apply to both fresh DB-01 and registered DB-03 upgrade paths.
\set ON_ERROR_STOP 1
\ir support/upgrade_contract.sql
SELECT :'opal_phase' IN ('fresh', 'verify') AS supported_owner_phase \gset
\if :supported_owner_phase
\else
    DO $phase$ BEGIN RAISE EXCEPTION 'Compact seed owner supports only fresh and custom verify phases'; END; $phase$;
\endif
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SET LOCAL search_path = public, pg_catalog;
SET LOCAL TIME ZONE 'UTC';
SET LOCAL statement_timeout = '30s';
\if :is_verify
    SELECT plan(6);
    DO $predecessor$
    BEGIN
        IF CURRENT_SETTING('opal.upgrade_predecessor') NOT IN ('1.32', '1.33') THEN
            RAISE EXCEPTION 'NLE seed requires its selected 1.32 or 1.33 predecessor';
        END IF;
    END;
    $predecessor$;
    SELECT pg_temp.opal_upgrade_require_identity('major-creditors.nle-seed', '1.34', :'opal_predecessor_version');
    SELECT CASE WHEN :'opal_predecessor_version' = '1.33' THEN 0 ELSE 3 END AS seed_insert_count \gset
    \if :{?opal_assertion_group}
        SELECT :'opal_assertion_group' = 'major-creditors.nle-seed' AS valid_seed_assertion_group \gset
    \else
        DO $group$ BEGIN RAISE EXCEPTION 'Compact seed verification requires its assertion group'; END; $group$;
    \endif
    \if :valid_seed_assertion_group
    \else
        DO $group$ BEGIN RAISE EXCEPTION 'Unknown compact seed assertion group'; END; $group$;
    \endif
    -- -------------------------------------------------------------------------
    -- Scenario: Interpret the shared observation without rewriting its row text.
    -- Setup: Shared preservation passed; exact predecessor data crossed sessions.
    -- Expected: Only a parsed copy classifies keys; original strings retain IDs,
    --           representation and multiplicity for every preservation comparison.
    -- -------------------------------------------------------------------------
    CREATE FUNCTION pg_temp.major_creditor_seed_upgrade_rows(original_rows JSONB, seed_keys BOOLEAN)
    RETURNS JSONB LANGUAGE sql AS $rows$
        SELECT COALESCE(JSONB_AGG(row_text ORDER BY row_text), '[]'::JSONB)
          FROM JSONB_ARRAY_ELEMENTS_TEXT(original_rows) AS observed(row_text)
         WHERE ((row_text::JSONB->>'business_unit_id')::SMALLINT = 44
                AND row_text::JSONB->>'major_creditor_code' IN ('T901', 'T902', 'T903')) = seed_keys;
    $rows$;
    SELECT pg_temp.opal_contract_load(:'opal_contract_json'::JSONB, 'major-creditors.nle-seed', '1.34', :'opal_predecessor_version') AS seed_saved \gset
    SELECT :'seed_saved'::JSONB->'observed'->'rows'->'public.major_creditors' AS seed_before_rows,
           :'seed_saved'::JSONB->'observed'->'sequences'->'public.major_creditor_id_seq' AS seed_before_sequence
    \gset
    SELECT COALESCE(JSONB_AGG(ROW_TO_JSON(m)::TEXT ORDER BY ROW_TO_JSON(m)::TEXT), '[]'::JSONB) AS seed_after_rows
      FROM public.major_creditors m \gset
    SELECT pg_temp.opal_contract_object('sequence', 'public.major_creditor_id_seq') AS seed_after_sequence \gset
    -- -------------------------------------------------------------------------
    -- Scenario: Verify the precise candidate data delta before functional probes.
    -- Setup: The selected candidate alone migrated after the captured predecessor.
    -- Expected: Exact unrelated rows, seed IDs and allowed three-row or no-op delta;
    --           only three generated allocations may change creditor sequence state.
    -- -------------------------------------------------------------------------
    SELECT is(JSONB_ARRAY_LENGTH(pg_temp.major_creditor_seed_upgrade_rows(:'seed_before_rows'::JSONB, TRUE)),
              3 - :seed_insert_count, 'predecessor has exactly its selected-profile seed keys');
    SELECT is(pg_temp.major_creditor_seed_upgrade_rows(:'seed_after_rows'::JSONB, FALSE),
              pg_temp.major_creditor_seed_upgrade_rows(:'seed_before_rows'::JSONB, FALSE),
        'candidate preserves every unrelated creditor row text and its multiplicity');
    SELECT ok(CASE WHEN :seed_insert_count = 0 THEN
                  pg_temp.major_creditor_seed_upgrade_rows(:'seed_after_rows'::JSONB, TRUE)
                      = pg_temp.major_creditor_seed_upgrade_rows(:'seed_before_rows'::JSONB, TRUE)
              ELSE JSONB_ARRAY_LENGTH(pg_temp.major_creditor_seed_upgrade_rows(:'seed_after_rows'::JSONB, TRUE)) = 3 END,
        'candidate inserts three seed keys or preserves exact existing row text and IDs');
    SELECT is(JSONB_ARRAY_LENGTH(:'seed_after_rows'::JSONB),
              JSONB_ARRAY_LENGTH(:'seed_before_rows'::JSONB) + :seed_insert_count,
        'candidate changes the total creditor count only by the declared seed delta');
    SELECT is(:'seed_after_sequence'::JSONB - 'value', :'seed_before_sequence'::JSONB - 'value',
        'candidate preserves creditor sequence definition, ownership and privileges');
    SELECT ok((:'seed_before_sequence'::JSONB->'value'->>1)::BOOLEAN
              AND (:'seed_before_sequence'::JSONB->'definition'->>'seqincrement')::BIGINT = 1
              AND :'seed_after_sequence'::JSONB->'value' = JSONB_BUILD_ARRAY(
                  (:'seed_before_sequence'::JSONB->'value'->>0)::BIGINT + :seed_insert_count, TRUE),
        'candidate creditor sequence advances exactly three or remains an exact no-op');
    SELECT * FROM finish();
    ROLLBACK;
\else
    SELECT plan(23);

CREATE TEMP TABLE expected_nle_major_creditors (
    business_unit_id SMALLINT,
    major_creditor_code VARCHAR(4),
    name VARCHAR(100),
    address_line_1 VARCHAR(35),
    address_line_2 VARCHAR(35),
    address_line_3 VARCHAR(35),
    address_line_4 VARCHAR(35),
    address_line_5 VARCHAR(35),
    postcode VARCHAR(10),
    country_id BIGINT,
    contact_name VARCHAR(35),
    contact_email VARCHAR(254),
    active BOOLEAN,
    central_authority BOOLEAN
) ON COMMIT DROP;

INSERT INTO expected_nle_major_creditors
SELECT e.business_unit_id, e.major_creditor_code, e.name,
       e.address_line_1, e.address_line_2, e.address_line_3,
       e.address_line_4, e.address_line_5, e.postcode, c.country_id,
       e.contact_name, e.contact_email, e.active, e.central_authority
FROM (
    VALUES
      (44::SMALLINT, 'T901', 'Functional Test Major Creditor',
       '1 Synthetic Test Street', 'Synthetic Test Town',
       'Synthetic Test District', 'Synthetic Test Region',
       'Synthetic Test Province', 'ZZ1 1ZZ',
       'Synthetic Test Contact', 'creditor@example.invalid', TRUE, FALSE),
      (44::SMALLINT, 'T902', 'Inactive Functional Test Creditor',
       '2 Synthetic Test Street', NULL, NULL, NULL, NULL, NULL,
       NULL, NULL, FALSE, FALSE),
      (44::SMALLINT, 'T903', 'Functional Test Central Authority',
       '3 Synthetic Test Street', NULL, NULL, NULL, NULL, NULL,
       NULL, NULL, TRUE, TRUE)
) AS e(business_unit_id, major_creditor_code, name,
       address_line_1, address_line_2, address_line_3, address_line_4,
       address_line_5, postcode, contact_name, contact_email, active,
       central_authority)
CROSS JOIN public.countries c
WHERE c.country_name = 'Czech Republic';

CREATE FUNCTION pg_temp.nle_matches_expected()
RETURNS BOOLEAN LANGUAGE sql AS $test$
SELECT
    (SELECT COUNT(*) = 3 AND COUNT(DISTINCT major_creditor_id) = 3
                 AND BOOL_AND(major_creditor_id > 0)
       FROM public.major_creditors
      WHERE business_unit_id = 44
        AND major_creditor_code IN ('T901', 'T902', 'T903'))
    AND (SELECT COUNT(*) = 3 FROM pg_temp.expected_nle_major_creditors)
    AND NOT EXISTS (
        SELECT 1
          FROM pg_temp.expected_nle_major_creditors e
          LEFT JOIN public.major_creditors m
            ON m.business_unit_id = e.business_unit_id
           AND m.major_creditor_code = e.major_creditor_code
         WHERE m.major_creditor_id IS NULL
            OR ROW(m.business_unit_id, m.major_creditor_code, m.name,
                   m.address_line_1, m.address_line_2, m.address_line_3,
                   m.address_line_4, m.address_line_5, m.postcode, m.country_id,
                   m.contact_name, m.contact_email, m.active, m.central_authority)
               IS DISTINCT FROM
               ROW(e.business_unit_id, e.major_creditor_code, e.name,
                   e.address_line_1, e.address_line_2, e.address_line_3,
                   e.address_line_4, e.address_line_5, e.postcode, e.country_id,
                   e.contact_name, e.contact_email, e.active, e.central_authority)
    )
    AND (SELECT ARRAY_AGG(major_creditor_code ORDER BY major_creditor_code)
           FROM public.major_creditors
          WHERE business_unit_id = 44 AND active AND NOT central_authority)
        = ARRAY['T901'::VARCHAR];
$test$;

CREATE FUNCTION pg_temp.apply_nle_seed()
RETURNS VOID LANGUAGE plpgsql AS $test$
BEGIN
    EXECUTE pg_read_file(
        '/tmp/opal-db-migrations/data/nle/V1_34__insert_major_creditors_nle_data.sql'
    );
END;
$test$;

CREATE FUNCTION pg_temp.nle_failure_is_atomic(setup_sql TEXT, expected_state TEXT)
RETURNS BOOLEAN LANGUAGE plpgsql AS $test$
DECLARE
    before_rows JSONB;
    after_rows JSONB;
    actual_state TEXT;
    passed BOOLEAN := FALSE;
BEGIN
    BEGIN
        EXECUTE setup_sql;
        SELECT JSONB_AGG(TO_JSONB(m) ORDER BY major_creditor_id)
          INTO before_rows FROM public.major_creditors m;
        BEGIN
            PERFORM pg_temp.apply_nle_seed();
        EXCEPTION WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS actual_state = RETURNED_SQLSTATE;
        END;
        SELECT JSONB_AGG(TO_JSONB(m) ORDER BY major_creditor_id)
          INTO after_rows FROM public.major_creditors m;
        passed := COALESCE(actual_state = expected_state
            AND before_rows IS NOT DISTINCT FROM after_rows, FALSE);
        RAISE EXCEPTION USING ERRCODE = 'Z1097', MESSAGE = 'rollback test setup';
    EXCEPTION WHEN SQLSTATE 'Z1097' THEN
        NULL;
    END;
    RETURN passed;
END;
$test$;

CREATE FUNCTION pg_temp.nle_insert_case(extra_sql TEXT)
RETURNS BOOLEAN LANGUAGE plpgsql AS $test$
DECLARE
    other_rows_before JSONB;
    other_rows_after JSONB;
    passed BOOLEAN := FALSE;
BEGIN
    BEGIN
        DELETE FROM public.major_creditors
         WHERE business_unit_id = 44
           AND major_creditor_code IN ('T901', 'T902', 'T903');
        EXECUTE extra_sql;
        SELECT JSONB_AGG(TO_JSONB(m) ORDER BY major_creditor_id)
          INTO other_rows_before
          FROM public.major_creditors m
         WHERE NOT (business_unit_id = 44
                    AND major_creditor_code IN ('T901', 'T902', 'T903'));
        PERFORM pg_temp.apply_nle_seed();
        SELECT JSONB_AGG(TO_JSONB(m) ORDER BY major_creditor_id)
          INTO other_rows_after
          FROM public.major_creditors m
         WHERE NOT (business_unit_id = 44
                    AND major_creditor_code IN ('T901', 'T902', 'T903'));
        passed := pg_temp.nle_matches_expected()
            AND other_rows_before IS NOT DISTINCT FROM other_rows_after;
        RAISE EXCEPTION USING ERRCODE = 'Z1097', MESSAGE = 'rollback test setup';
    EXCEPTION WHEN SQLSTATE 'Z1097' THEN
        NULL;
    END;
    RETURN passed;
END;
$test$;

-- -----------------------------------------------------------------------------
-- Scenario: Fresh Flyway state has the exact three approved BU 44 records.
-- Setup: The selected DEV or common NLE profile has completed migration.
-- Expected: All fourteen non-ID fields, generated IDs and selection agree.
-- -----------------------------------------------------------------------------
SELECT ok(pg_temp.nle_matches_expected(),
    'NLE seed has exact fields, generated identifiers and T901-only selection');

-- -----------------------------------------------------------------------------
-- Scenario: Exact existing data makes a direct migration rerun a no-op.
-- Setup: Snapshot every creditor row and the sequence state before rerun.
-- Expected: Neither application rows nor sequence state changes.
-- -----------------------------------------------------------------------------
CREATE TEMP TABLE nle_baseline AS
SELECT (SELECT JSONB_AGG(TO_JSONB(m) ORDER BY major_creditor_id)
          FROM public.major_creditors m) AS creditor_rows,
       (SELECT JSONB_BUILD_OBJECT('last_value', last_value, 'is_called', is_called)
          FROM public.major_creditor_id_seq) AS sequence_state;
SELECT pg_temp.apply_nle_seed();
SELECT ok(
    (SELECT creditor_rows FROM pg_temp.nle_baseline) IS NOT DISTINCT FROM
        (SELECT JSONB_AGG(TO_JSONB(m) ORDER BY major_creditor_id)
           FROM public.major_creditors m)
    AND (SELECT sequence_state FROM pg_temp.nle_baseline) IS NOT DISTINCT FROM
        (SELECT JSONB_BUILD_OBJECT('last_value', last_value, 'is_called', is_called)
           FROM public.major_creditor_id_seq),
    'exact rerun preserves creditor rows and sequence state');

-- -----------------------------------------------------------------------------
-- Scenario: An empty BU 44 fixture set is inserted and caller rollback restores it.
-- Setup: Delete only the three fixture keys inside a rolled-back subtransaction.
-- Expected: Exact new set, other rows untouched, then original rows restored.
-- -----------------------------------------------------------------------------
SELECT ok(pg_temp.nle_insert_case('SELECT 1'),
    'missing fixture set inserts exactly three rows and preserves other creditors');
SELECT ok(
    (SELECT creditor_rows FROM pg_temp.nle_baseline) IS NOT DISTINCT FROM
        (SELECT JSONB_AGG(TO_JSONB(m) ORDER BY major_creditor_id)
           FROM public.major_creditors m),
    'successful test invocation rolls back to the original creditor rows');

-- -----------------------------------------------------------------------------
-- Scenario: One or two existing fixture keys are partial data.
-- Setup: Remove the remaining fixture keys in rolled-back subtransactions.
-- Expected: P0001 and no application-row changes in either case.
-- -----------------------------------------------------------------------------
SELECT ok(pg_temp.nle_failure_is_atomic(
    $$DELETE FROM public.major_creditors
       WHERE business_unit_id = 44 AND major_creditor_code IN ('T902', 'T903')$$,
    'P0001'), 'one existing key is rejected without changing creditor rows');
SELECT ok(pg_temp.nle_failure_is_atomic(
    $$DELETE FROM public.major_creditors
       WHERE business_unit_id = 44 AND major_creditor_code = 'T903'$$,
    'P0001'), 'two existing keys are rejected without changing creditor rows');

-- -----------------------------------------------------------------------------
-- Scenario: Every independently specified field mismatch is a conflict.
-- Setup: Update one T901 field in each rolled-back subtransaction.
-- Expected: All twelve calls raise P0001 without application-row changes.
-- -----------------------------------------------------------------------------
SELECT ok(
    pg_temp.nle_failure_is_atomic(
        FORMAT('UPDATE public.major_creditors SET %I = %s WHERE business_unit_id = 44 AND major_creditor_code = %L',
               field_name, replacement, 'T901'),
        'P0001'),
    'conflicting ' || field_name || ' is rejected without changing creditor rows')
FROM (VALUES
    ('name', '''Different synthetic name'''),
    ('address_line_1', '''Different address 1'''),
    ('address_line_2', '''Different address 2'''),
    ('address_line_3', '''Different address 3'''),
    ('address_line_4', '''Different address 4'''),
    ('address_line_5', '''Different address 5'''),
    ('postcode', '''ZZ9 9ZZ'''),
    ('country_id', 'NULL'),
    ('contact_name', '''Different contact'''),
    ('contact_email', '''different@example.invalid'''),
    ('active', 'FALSE'),
    ('central_authority', 'TRUE')
) AS conflicts(field_name, replacement);

-- -----------------------------------------------------------------------------
-- Scenario: NULL and empty text have different reference-data meaning.
-- Setup: Replace T902's NULL optional address line 2 with empty text.
-- Expected: P0001 and no creditor-row changes.
-- -----------------------------------------------------------------------------
SELECT ok(pg_temp.nle_failure_is_atomic(
    $$UPDATE public.major_creditors SET address_line_2 = ''
       WHERE business_unit_id = 44 AND major_creditor_code = 'T902'$$,
    'P0001'), 'empty optional address differs from NULL without changing rows');

-- -----------------------------------------------------------------------------
-- Scenario: The named Country must resolve to one existing row.
-- Setup: Hide its name or add a second synthetic row with a free CJS code.
-- Expected: Native P0002 or P0003 and no creditor-row changes.
-- -----------------------------------------------------------------------------
SELECT ok(pg_temp.nle_failure_is_atomic(
    $$UPDATE public.countries SET country_name = 'Hidden Czech Republic'
       WHERE country_name = 'Czech Republic'$$,
    'P0002'), 'missing Czech Republic raises P0002 without changing creditors');
SELECT ok(pg_temp.nle_failure_is_atomic(
    $$INSERT INTO public.countries (cjs_code, country_name, date_used_from, active)
      VALUES (32000, 'Czech Republic', DATE '2026-10-21', TRUE)$$,
    'P0003'), 'ambiguous Czech Republic raises P0003 without changing creditors');

-- -----------------------------------------------------------------------------
-- Scenario: Creditor codes are scoped by Business Unit.
-- Setup: Delete BU 44 fixtures and insert the same code under valid BU 67.
-- Expected: BU 44 is seeded exactly and the other BU row is untouched.
-- -----------------------------------------------------------------------------
SELECT ok(pg_temp.nle_insert_case(
    $$INSERT INTO public.major_creditors
          (business_unit_id, major_creditor_code, name, address_line_1,
           active, central_authority)
      VALUES (67, 'T901', 'Other BU synthetic creditor',
              '67 Synthetic Test Street', TRUE, FALSE)$$),
    'same code under another valid BU is preserved and does not satisfy BU 44');

-- -----------------------------------------------------------------------------
-- Scenario: A later insertion error rolls back earlier inserted rows.
-- Setup: A test-only BEFORE INSERT trigger rejects T902 after T901 is attempted.
-- Expected: P0001 and no partial creditor writes; trigger setup rolls back.
-- -----------------------------------------------------------------------------
SELECT ok(pg_temp.nle_failure_is_atomic(
    $setup$DELETE FROM public.major_creditors
               WHERE business_unit_id = 44
                 AND major_creditor_code IN ('T901', 'T902', 'T903');
            CREATE FUNCTION pg_temp.reject_nle_t902()
            RETURNS TRIGGER LANGUAGE plpgsql AS $trigger$
            BEGIN
                IF NEW.business_unit_id = 44 AND NEW.major_creditor_code = 'T902' THEN
                    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'test-only T902 rejection';
                END IF;
                RETURN NEW;
            END;
            $trigger$;
            CREATE TRIGGER reject_nle_t902_before_insert
            BEFORE INSERT ON public.major_creditors
            FOR EACH ROW EXECUTE FUNCTION pg_temp.reject_nle_t902()$setup$,
    'P0001'), 'later insert failure leaves no partial creditor writes');

SELECT * FROM finish();
ROLLBACK;
\endif
