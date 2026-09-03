/*
 * PO-10292
 * Reconcile every approved country value and the generated identifier contract.
 */

BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;

CREATE TEMPORARY TABLE expected_countries (
    country_id BIGINT,
    cjs_code SMALLINT,
    international_code VARCHAR(3),
    gov_code VARCHAR(2),
    country_name VARCHAR(100),
    demonym VARCHAR(100),
    date_used_from DATE,
    date_used_to DATE,
    active BOOLEAN
) ON COMMIT DROP;

COPY expected_countries (
    country_id,
    cjs_code,
    international_code,
    gov_code,
    country_name,
    demonym,
    date_used_from,
    date_used_to,
    active
)
FROM '/tmp/opal-db-unit-test/countriesDataTest/countries.csv'
WITH (FORMAT CSV, HEADER TRUE, NULL '');

SELECT plan(8);

SELECT is(
    (SELECT count(*) FROM expected_countries),
    353::bigint,
    'the approved source contains 353 countries'
);
SELECT is(
    (SELECT count(*) FROM public.countries),
    353::bigint,
    'the migration creates exactly 353 countries'
);
SELECT is(
    (SELECT count(*) FROM public.countries WHERE active),
    192::bigint,
    'the migration creates exactly 192 active countries'
);
SELECT is(
    (SELECT count(*) FROM public.countries WHERE NOT active),
    161::bigint,
    'the migration creates exactly 161 inactive countries'
);
SELECT results_eq(
    $actual$
    SELECT
        cjs_code,
        international_code,
        gov_code,
        country_name,
        demonym,
        date_used_from,
        date_used_to,
        active
    FROM public.countries
    ORDER BY cjs_code
    $actual$,
    $expected$
    SELECT
        cjs_code,
        international_code,
        gov_code,
        country_name,
        demonym,
        date_used_from,
        date_used_to,
        active
    FROM expected_countries
    ORDER BY cjs_code
    $expected$,
    'every migrated country value matches the approved source'
);
SELECT ok(
    (
        SELECT count(*) = 353
           AND count(country_id) = 0
        FROM expected_countries
    ),
    'the approved source delegates every country identifier to PostgreSQL'
);
SELECT ok(
    (
        SELECT count(*) = 353
           AND count(DISTINCT country_id) = 353
           AND bool_and(country_id > 0)
        FROM public.countries
    ),
    'every migrated country has a distinct positive generated identifier'
);
SELECT is(
    (
        SELECT count(*)
        FROM public.countries
        WHERE cjs_code BETWEEN 32001 AND 32011
    ),
    0::bigint,
    'obsolete development fixtures are not retained'
);

SELECT * FROM finish();
ROLLBACK;
