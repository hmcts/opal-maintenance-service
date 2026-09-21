/*
 * PO-10291
 * Reconcile every approved Business Unit value, relationship, and failure outcome.
 */

BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;

CREATE TEMPORARY TABLE expected_business_units (
    business_unit_id        SMALLINT                         NOT NULL,
    business_unit_code      VARCHAR(4)                       NOT NULL,
    business_unit_name      VARCHAR(200)                     NOT NULL,
    business_unit_type      public.t_business_unit_type_enum NOT NULL,
    account_number_prefix   VARCHAR(2),
    parent_business_unit_id SMALLINT,
    opal_domain             VARCHAR(30),
    welsh_language          BOOLEAN                          NOT NULL,
    account_number_suffix   VARCHAR(2)
) ON COMMIT DROP;

COPY expected_business_units (
    business_unit_id,
    business_unit_code,
    business_unit_name,
    business_unit_type,
    account_number_prefix,
    parent_business_unit_id,
    opal_domain,
    welsh_language,
    account_number_suffix
)
FROM '/tmp/opal-db-unit-test/businessUnitsDataTest/business-units.csv'
WITH (FORMAT CSV, HEADER TRUE, NULL '');

SELECT plan(20);

-- -----------------------------------------------------------------------------
-- Scenario: The retained source contains the approved dataset shape.
-- Setup: Load the exact CSV into a typed temporary table, mapping blank fields to NULL.
-- Expected: It contains 99 rows split into 42 Areas and 57 Accounting Divisions.
-- -----------------------------------------------------------------------------
SELECT is((SELECT count(*) FROM expected_business_units), 99::bigint,
    'the approved source contains exactly 99 Business Units');
SELECT is((SELECT count(*) FROM public.business_units), 99::bigint,
    'the migration creates exactly 99 Business Units');
SELECT results_eq(
    $actual$
    SELECT business_unit_type::text, count(*)
    FROM expected_business_units
    GROUP BY business_unit_type
    ORDER BY business_unit_type::text
    $actual$,
    $expected$
    VALUES
        ('Accounting Division'::text, 57::bigint),
        ('Area'::text, 42::bigint)
    $expected$,
    'the approved source contains 42 Areas and 57 Accounting Divisions'
);

-- -----------------------------------------------------------------------------
-- Scenario: Approved and migrated business keys are complete and unique.
-- Setup: Count total and distinct identifiers and codes in each dataset.
-- Expected: Every one of the 99 identifiers and codes is populated and unique.
-- -----------------------------------------------------------------------------
SELECT ok(
    (SELECT count(*) = count(DISTINCT business_unit_id)
         AND count(*) = count(DISTINCT business_unit_code)
     FROM expected_business_units),
    'the approved source has unique Business Unit identifiers and codes'
);
SELECT ok(
    (SELECT count(*) = count(DISTINCT business_unit_id)
         AND count(*) = count(DISTINCT business_unit_code)
     FROM public.business_units),
    'the migrated dataset has unique Business Unit identifiers and codes'
);

-- -----------------------------------------------------------------------------
-- Scenario: Every parent relationship forms a valid acyclic hierarchy.
-- Setup: Resolve every non-null parent, inspect self-links, and recursively walk ancestors.
-- Expected: Every parent exists, no row is its own parent, and no cycle is present.
-- -----------------------------------------------------------------------------
SELECT is(
    (SELECT count(*)
     FROM expected_business_units AS child
     LEFT JOIN expected_business_units AS parent
       ON parent.business_unit_id = child.parent_business_unit_id
     WHERE child.parent_business_unit_id IS NOT NULL
       AND parent.business_unit_id IS NULL),
    0::bigint,
    'every approved parent Business Unit resolves within the dataset'
);
SELECT is(
    (SELECT count(*) FROM expected_business_units
     WHERE business_unit_id = parent_business_unit_id),
    0::bigint,
    'the approved hierarchy contains no self-reference'
);
SELECT is(
    (
        WITH RECURSIVE hierarchy AS (
            SELECT
                business_unit_id AS start_id,
                parent_business_unit_id AS next_id,
                ARRAY[business_unit_id] AS path,
                FALSE AS cycle_detected
            FROM expected_business_units
            WHERE parent_business_unit_id IS NOT NULL
            UNION ALL
            SELECT
                hierarchy.start_id,
                parent.parent_business_unit_id,
                hierarchy.path || parent.business_unit_id,
                parent.business_unit_id = ANY(hierarchy.path)
            FROM hierarchy
            JOIN expected_business_units AS parent
              ON parent.business_unit_id = hierarchy.next_id
            WHERE hierarchy.next_id IS NOT NULL
              AND NOT hierarchy.cycle_detected
        )
        SELECT count(*) FROM hierarchy WHERE cycle_detected
    ),
    0::bigint,
    'the approved hierarchy contains no cycle'
);

-- -----------------------------------------------------------------------------
-- Scenario: Null prefixes and text codes retain their approved representation.
-- Setup: Count null prefixes and codes beginning with zero in source and target.
-- Expected: All 99 prefixes are NULL and all 63 leading-zero codes remain textually exact.
-- -----------------------------------------------------------------------------
SELECT is((SELECT count(*) FROM expected_business_units WHERE account_number_prefix IS NULL),
    99::bigint, 'the approved source has 99 null account number prefixes');
SELECT is((SELECT count(*) FROM public.business_units WHERE account_number_prefix IS NULL),
    99::bigint, 'the migrated dataset has 99 null account number prefixes');
SELECT is((SELECT count(*) FROM expected_business_units WHERE business_unit_code LIKE '0%'),
    63::bigint, 'the approved source retains 63 leading-zero Business Unit codes');
SELECT is((SELECT count(*) FROM public.business_units WHERE business_unit_code LIKE '0%'),
    63::bigint, 'the migrated dataset retains 63 leading-zero Business Unit codes');

-- -----------------------------------------------------------------------------
-- Scenario: Migration output equals the approved source across all nine columns.
-- Setup: Compare expected and actual rows in both directions and compare parent mappings.
-- Expected: No expected row is missing, no unexpected row exists, and every parent is exact.
-- -----------------------------------------------------------------------------
SELECT is(
    (SELECT count(*) FROM (
        SELECT * FROM expected_business_units
        EXCEPT
        SELECT * FROM public.business_units
    ) AS missing_rows),
    0::bigint,
    'no approved Business Unit row is missing from the migration output'
);
SELECT is(
    (SELECT count(*) FROM (
        SELECT * FROM public.business_units
        EXCEPT
        SELECT * FROM expected_business_units
    ) AS unexpected_rows),
    0::bigint,
    'the migration output contains no unexpected Business Unit row'
);
SELECT results_eq(
    $actual$
    SELECT business_unit_id, parent_business_unit_id
    FROM public.business_units
    ORDER BY business_unit_id
    $actual$,
    $expected$
    SELECT business_unit_id, parent_business_unit_id
    FROM expected_business_units
    ORDER BY business_unit_id
    $expected$,
    'every migrated parent relationship matches the approved source'
);

-- -----------------------------------------------------------------------------
-- Scenario: Documented source exceptions remain exact.
-- Setup: Inspect Area 1035 and the three appended RM Accounting Divisions.
-- Expected: The Confiscation override and all RM-specific values remain unchanged.
-- -----------------------------------------------------------------------------
SELECT ok(
    EXISTS (
        SELECT 1 FROM expected_business_units
        WHERE business_unit_id = 1035
          AND business_unit_code = '52'
          AND business_unit_name = 'Avon and Somerset'
          AND business_unit_type = 'Area'
          AND account_number_prefix IS NULL
          AND parent_business_unit_id IS NULL
          AND opal_domain = 'Confiscation'
          AND welsh_language IS FALSE
          AND account_number_suffix IS NULL
    ),
    'Area 1035 retains the approved Confiscation exception exactly'
);
SELECT ok(
    EXISTS (
        SELECT 1 FROM expected_business_units
        WHERE business_unit_id = 44 AND business_unit_code = '0097'
          AND business_unit_name = 'MBEC England' AND business_unit_type = 'Accounting Division'
          AND account_number_prefix IS NULL AND parent_business_unit_id = 1022
          AND opal_domain = 'RM' AND welsh_language IS FALSE AND account_number_suffix IS NULL
    )
    AND EXISTS (
        SELECT 1 FROM expected_business_units
        WHERE business_unit_id = 67 AND business_unit_code = '0036'
          AND business_unit_name = 'MBEC London' AND business_unit_type = 'Accounting Division'
          AND account_number_prefix IS NULL AND parent_business_unit_id = 1001
          AND opal_domain = 'RM' AND welsh_language IS FALSE AND account_number_suffix IS NULL
    )
    AND EXISTS (
        SELECT 1 FROM expected_business_units
        WHERE business_unit_id = 111 AND business_unit_code = '0102'
          AND business_unit_name = 'MBEC Wales' AND business_unit_type = 'Accounting Division'
          AND account_number_prefix IS NULL AND parent_business_unit_id = 1035
          AND opal_domain = 'RM' AND welsh_language IS FALSE AND account_number_suffix IS NULL
    ),
    'the three appended RM Accounting Divisions retain every approved value'
);

-- -----------------------------------------------------------------------------
-- Scenario: A failed multi-row insert is atomic.
-- Setup: Insert a valid sentinel first and then conflict with seeded identifier 111.
-- Expected: PostgreSQL rejects the statement, removes the sentinel, and leaves the dataset exact.
-- -----------------------------------------------------------------------------
SELECT throws_ok(
    $sql$
    INSERT INTO public.business_units (
        business_unit_id, business_unit_code, business_unit_name,
        business_unit_type, account_number_prefix, parent_business_unit_id,
        opal_domain, welsh_language, account_number_suffix
    ) VALUES
        (32000, 'T001', 'Atomicity Sentinel', 'Area', NULL, NULL, NULL, FALSE, NULL),
        (111, 'T002', 'Deliberate Seed Conflict', 'Area', NULL, NULL, NULL, FALSE, NULL)
    $sql$,
    '23505',
    NULL,
    'a seeded-key conflict rejects the complete multi-row insert'
);
SELECT is(
    (SELECT count(*) FROM public.business_units WHERE business_unit_id = 32000),
    0::bigint,
    'the valid sentinel is rolled back with the failed multi-row insert'
);
SELECT ok(
    NOT EXISTS (
        SELECT * FROM expected_business_units
        EXCEPT
        SELECT * FROM public.business_units
    )
    AND NOT EXISTS (
        SELECT * FROM public.business_units
        EXCEPT
        SELECT * FROM expected_business_units
    ),
    'the failed insert leaves the approved 99-row dataset unchanged'
);

SELECT * FROM finish();
ROLLBACK;
