/**
 * OPAL Program
 *
 * MODULE      : f_get_account_number_pgtap_tests.sql
 *
 * DESCRIPTION : Verify RM allocations, exact persisted rows and caller contracts.
 *
 * CHANGE HISTORY:
 *
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * 09/10/2026  Chris Larkin  PO-10642      Initial pgTAP test suite.
 */

\set ON_ERROR_STOP on
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SET LOCAL search_path = public, pg_catalog;
SET LOCAL TIME ZONE 'UTC';
SELECT plan(90);

-- Independent oracle: row-wise dot product and alphabet lookup, checked below.
CREATE FUNCTION pg_temp.expected_account_number(body TEXT)
RETURNS VARCHAR LANGUAGE SQL IMMUTABLE AS $oracle$
    SELECT (body || SUBSTR('ABCDEFGHIJKLMNOPQRSTUVW',
        1 + ((23 - SUM(SUBSTR(body,p,1)::INTEGER *
                          (ARRAY[5,1,4,2,7,5,1,4])[p]) % 23) % 23)::INTEGER, 1))::VARCHAR
    FROM GENERATE_SERIES(1,8) AS positions(p)
$oracle$;
SELECT is(pg_temp.expected_account_number('26000001'),'26000001D'::VARCHAR,'Oracle: D');
SELECT is(pg_temp.expected_account_number('26000002'),'26000002W'::VARCHAR,'Oracle: W');
SELECT is(pg_temp.expected_account_number('00000000'),'00000000A'::VARCHAR,'Oracle: A');
SELECT is(pg_temp.expected_account_number('12345678'),'12345678H'::VARCHAR,'Oracle: H');

-- ---------------------------------------------------------------------------
-- Scenario C01-C03: Real concurrent callers commit, roll back or use separate BUs.
-- Setup:    Disposable-only dblink sessions, bounded asynchronous waits and owned fixtures.
-- Expected: Observable blocking, exact complete values/rows and verified cleanup.
-- ---------------------------------------------------------------------------
DO $gate$
BEGIN
  IF CURRENT_DATABASE() NOT IN ('opal_maintenance_db_unit_test','opal_po10642_upgrade')
     OR current_user <> 'postgres' THEN
    RAISE EXCEPTION 'Concurrency tests require the harness-owned disposable database';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_available_extensions WHERE name='dblink') THEN
    RAISE EXCEPTION 'SQL-only concurrency tooling unavailable: dblink extension files missing';
  END IF;
END;
$gate$;
CREATE EXTENSION IF NOT EXISTS dblink WITH SCHEMA public;
DO $namespace$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension
                 WHERE extname='dblink' AND extnamespace='public'::regnamespace) THEN
    RAISE EXCEPTION 'Expected test dblink functions in public schema';
  END IF;
END;
$namespace$;

CREATE FUNCTION pg_temp.account_allocation_race(mode TEXT)
RETURNS VOID LANGUAGE plpgsql AS $race$
DECLARE
  connection TEXT;
  name TEXT;
  fixture_owned BOOLEAN := false;
  failed_state TEXT;
  failed_message TEXT;
  a_pid INTEGER;
  b_pid INTEGER;
  b_bu SMALLINT;
  yy TEXT;
  b_yy TEXT;
  a_number VARCHAR;
  b_number VARCHAR;
  expected_b VARCHAR;
  deadline TIMESTAMPTZ;
  row_count BIGINT;
  expected_rows INTEGER;
  still_in_transaction BOOLEAN;
BEGIN
  IF mode NOT IN ('commit','rollback','independent') OR mode IS NULL THEN
    RAISE EXCEPTION 'Unknown concurrency test mode';
  END IF;

  IF COALESCE(public.DBLINK_GET_CONNECTIONS(),ARRAY[]::text[]) &&
      ARRAY['po10642_fixture','po10642_a','po10642_b']::text[] THEN
    RAISE EXCEPTION 'Concurrency connection-name collision';
  END IF;

  connection := FORMAT(
    'host=127.0.0.1 port=5432 dbname=%L user=postgres connect_timeout=5 options=%L',
    CURRENT_DATABASE(),
    '-csearch_path=pg_catalog,public -cstatement_timeout=20000 -clock_timeout=15000 -ctimezone=UTC -cidle_in_transaction_session_timeout=30000');
  BEGIN
    PERFORM public.DBLINK_CONNECT('po10642_fixture',connection);

    -- One remote transaction: a fixture collision cannot partially claim ownership.
    PERFORM public.DBLINK_EXEC('po10642_fixture',$setup$
      BEGIN;
      DO $guard$ BEGIN

        IF EXISTS(SELECT 1 FROM public.business_units
                  WHERE business_unit_id IN (31891,31892)
                     OR business_unit_code IN ('C891','C892')) THEN
          RAISE EXCEPTION 'Concurrent Business Unit fixture collision';
        END IF;
      END; $guard$;
      INSERT INTO public.business_units
        (business_unit_id,business_unit_code,business_unit_name,business_unit_type,welsh_language)
      VALUES (31891,'C891','Synthetic concurrent unit A','Area',false),
             (31892,'C892','Synthetic concurrent unit B','Area',false);
      COMMIT;
    $setup$);
    fixture_owned := true;
    PERFORM public.DBLINK_CONNECT('po10642_a',connection);
    PERFORM public.DBLINK_CONNECT('po10642_b',connection);
    SELECT pid INTO a_pid FROM public.DBLINK('po10642_a','SELECT PG_BACKEND_PID()') AS x(pid integer);
    SELECT pid INTO b_pid FROM public.DBLINK('po10642_b','SELECT PG_BACKEND_PID()') AS x(pid integer);
    PERFORM public.DBLINK_EXEC('po10642_a','BEGIN ISOLATION LEVEL READ COMMITTED');
    SELECT year,number INTO yy,a_number FROM public.DBLINK('po10642_a',
      $a$SELECT TO_CHAR(NOW(),'YY'),public.f_get_account_number(31891::smallint,
         'respondent_accounts'::public.t_associated_record_type_enum)$a$)
      AS x(year text,number varchar);
    PERFORM public.DBLINK_EXEC('po10642_b','BEGIN ISOLATION LEVEL READ COMMITTED');
    SELECT year INTO b_yy FROM public.DBLINK('po10642_b',
      $year$SELECT TO_CHAR(NOW(),'YY')$year$) AS x(year text);

    IF b_yy IS DISTINCT FROM yy THEN
      RAISE EXCEPTION 'Concurrency test crossed the transaction-year boundary; rerun';
    END IF;

    b_bu := CASE WHEN mode='independent' THEN 31892 ELSE 31891 END;

    IF public.DBLINK_SEND_QUERY('po10642_b',FORMAT(
      'SELECT public.f_get_account_number(%s::smallint,''creditor_accounts''::public.t_associated_record_type_enum)',b_bu)) <> 1 THEN
      RAISE EXCEPTION 'Second allocation was not dispatched';
    END IF;

    deadline := CLOCK_TIMESTAMP()+interval '10 seconds';

    IF mode='independent' THEN
      WHILE public.DBLINK_IS_BUSY('po10642_b')=1 LOOP
        IF CLOCK_TIMESTAMP()>deadline THEN RAISE EXCEPTION 'Independent BU did not complete'; END IF;
        PERFORM PG_SLEEP(0.01);
      END LOOP;
      SELECT value INTO still_in_transaction FROM public.DBLINK('po10642_a',
        'SELECT PG_CURRENT_XACT_ID_IF_ASSIGNED() IS NOT NULL') AS x(value boolean);

      IF still_in_transaction IS DISTINCT FROM true THEN
        RAISE EXCEPTION 'First transaction was not still open';
      END IF;
    ELSE
      WHILE NOT (a_pid=ANY(PG_BLOCKING_PIDS(b_pid))) LOOP
        IF public.DBLINK_IS_BUSY('po10642_b')=0 OR CLOCK_TIMESTAMP()>deadline THEN
          RAISE EXCEPTION 'Second allocation did not demonstrably block on first';
        END IF;

        PERFORM PG_SLEEP(0.01);
      END LOOP;
      PERFORM public.DBLINK_EXEC('po10642_a',CASE WHEN mode='rollback' THEN 'ROLLBACK' ELSE 'COMMIT' END);
    END IF;

    -- Exactly one SELECT was dispatched. Collect its row and then its empty result.
    SELECT number INTO b_number FROM public.DBLINK_GET_RESULT('po10642_b') AS x(number varchar);
    PERFORM number FROM public.DBLINK_GET_RESULT('po10642_b') AS x(number varchar);
    PERFORM public.DBLINK_EXEC('po10642_b','COMMIT');

    IF mode='independent' THEN PERFORM public.DBLINK_EXEC('po10642_a','COMMIT'); END IF;

    expected_b := pg_temp.expected_account_number(yy||CASE WHEN mode='commit' THEN '000002' ELSE '000001' END);

    IF a_number IS DISTINCT FROM pg_temp.expected_account_number(yy||'000001')
       OR b_number IS DISTINCT FROM expected_b THEN
      RAISE EXCEPTION 'Returned complete number differs from independent expectation';
    END IF;

    expected_rows := CASE WHEN mode='rollback' THEN 1 ELSE 2 END;
    SELECT COUNT(*) INTO row_count FROM public.account_number_index WHERE business_unit_id IN (31891,31892);

    IF row_count<>expected_rows THEN RAISE EXCEPTION 'Wrong committed allocation row count'; END IF;

    IF NOT EXISTS(SELECT 1 FROM public.account_number_index WHERE business_unit_id=b_bu
         AND account_number=b_number AND associated_record_type='creditor_accounts') THEN
      RAISE EXCEPTION 'Second returned value and persisted allocation differ';
    END IF;

    IF mode<>'rollback' AND NOT EXISTS(SELECT 1 FROM public.account_number_index
         WHERE business_unit_id=31891 AND account_number=a_number AND associated_record_type='respondent_accounts') THEN
      RAISE EXCEPTION 'First returned value and persisted allocation differ';
    END IF;

    IF EXISTS(SELECT 1 FROM public.account_number_index WHERE business_unit_id IN (31891,31892)
              GROUP BY business_unit_id,account_number HAVING COUNT(*)>1) THEN
      RAISE EXCEPTION 'Duplicate BU/account number observed';
    END IF;

  EXCEPTION
    WHEN query_canceled THEN failed_state := SQLSTATE; failed_message := SQLERRM;
    WHEN OTHERS THEN failed_state := SQLSTATE; failed_message := SQLERRM;
  END;

  -- Closing a worker connection rolls back any still-open remote transaction.
  -- Do not issue another command on a connection with undrained async results.
  FOREACH name IN ARRAY ARRAY['po10642_a','po10642_b'] LOOP
    IF name=ANY(COALESCE(public.DBLINK_GET_CONNECTIONS(),ARRAY[]::text[])) THEN
      PERFORM public.DBLINK_DISCONNECT(name);
    END IF;
  END LOOP;

  IF 'po10642_fixture'=ANY(COALESCE(public.DBLINK_GET_CONNECTIONS(),ARRAY[]::text[])) THEN
    -- A failed remote fixture setup may have left this connection aborted.
    IF NOT fixture_owned THEN
      PERFORM public.DBLINK_EXEC('po10642_fixture','ROLLBACK');
    END IF;

    IF fixture_owned THEN
      PERFORM public.DBLINK_EXEC('po10642_fixture',$cleanup$
        BEGIN;
        DELETE FROM public.account_number_index WHERE business_unit_id IN (31891,31892);
        DELETE FROM public.business_units WHERE business_unit_id IN (31891,31892)
          AND business_unit_code IN ('C891','C892');
        COMMIT;
      $cleanup$);
      SELECT value INTO row_count FROM public.DBLINK('po10642_fixture',
        'SELECT COUNT(*) FROM public.business_units WHERE business_unit_id IN (31891,31892)') AS x(value bigint);

      IF row_count<>0 THEN RAISE EXCEPTION 'Concurrency fixture cleanup incomplete'; END IF;
    END IF;

    PERFORM public.DBLINK_DISCONNECT('po10642_fixture');
  END IF;

  IF failed_state IS NOT NULL THEN
    RAISE EXCEPTION USING ERRCODE=failed_state,MESSAGE=failed_message;
  END IF;
END;
$race$;

CREATE FUNCTION pg_temp.assert_account_race_clean()
RETURNS VOID LANGUAGE plpgsql AS $clean$
BEGIN
  IF COALESCE(public.DBLINK_GET_CONNECTIONS(),ARRAY[]::text[]) &&
      ARRAY['po10642_fixture','po10642_a','po10642_b']::text[]
     OR EXISTS(SELECT 1 FROM public.business_units
               WHERE business_unit_id IN (31891,31892)
                  OR business_unit_code IN ('C891','C892'))
     OR EXISTS(SELECT 1 FROM public.account_number_index
               WHERE business_unit_id IN (31891,31892)) THEN
    RAISE EXCEPTION 'Concurrency cleanup uncertain; stop and destroy disposable database';
  END IF;
END;
$clean$;

SET LOCAL statement_timeout='50s';
SELECT lives_ok($q$SELECT pg_temp.account_allocation_race('commit')$q$,
 'C01 committed winner: distinct complete numbers and matching reservations');
DO $verify$ BEGIN PERFORM pg_temp.assert_account_race_clean(); END; $verify$;
SELECT lives_ok($q$SELECT pg_temp.account_allocation_race('rollback')$q$,
 'C02 rolled-back winner: waiting allocation uses released candidate');
DO $verify$ BEGIN PERFORM pg_temp.assert_account_race_clean(); END; $verify$;
SELECT lives_ok($q$SELECT pg_temp.account_allocation_race('independent')$q$,
 'C03 different BU completes while first transaction remains open');
DO $verify$ BEGIN PERFORM pg_temp.assert_account_race_clean(); END; $verify$;
SET LOCAL statement_timeout='30s';

DO $fixture$
BEGIN
    IF EXISTS (SELECT 1 FROM public.business_units
               WHERE business_unit_id BETWEEN 31901 AND 31906 OR business_unit_id=-31901
                  OR business_unit_code IN ('A900','A901','A902','A903','A904','A905','A906')) THEN
        RAISE EXCEPTION 'PO-10642 synthetic Business Unit fixture collision';
    END IF;

    IF TO_CHAR(NOW(),'YY')::INTEGER NOT BETWEEN 1 AND 97 THEN
        RAISE EXCEPTION 'PO-10642 fixed past-year and 98/99 fixtures require test maintenance';
    END IF;
END;
$fixture$;
INSERT INTO public.business_units
    (business_unit_id,business_unit_code,business_unit_name,business_unit_type,welsh_language)
SELECT n::SMALLINT, 'A'||(n-31000)::TEXT, 'Synthetic account-number unit '||n, 'Area', false
FROM GENERATE_SERIES(31901,31906) n;
INSERT INTO public.business_units
    (business_unit_id,business_unit_code,business_unit_name,business_unit_type,welsh_language)
VALUES (-31901,'A900','Synthetic negative identifier unit','Area',false);
CREATE TEMP TABLE account_results(label TEXT PRIMARY KEY, number VARCHAR);
CREATE TEMP TABLE seeded_rows AS SELECT * FROM public.account_number_index WHERE false;
CREATE TEMP TABLE unrelated_allocations AS SELECT * FROM public.account_number_index;

CREATE FUNCTION pg_temp.application_digests() RETURNS jsonb LANGUAGE plpgsql AS $snap$
DECLARE r record; digest text; answer jsonb := '{}'::jsonb;
BEGIN
  FOR r IN SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
           WHERE n.nspname='public' AND c.relkind='r' AND c.relpersistence='p'
             AND c.relname NOT IN ('account_number_index','flyway_schema_history')
           ORDER BY c.relname LOOP
    EXECUTE FORMAT('SELECT MD5(COALESCE(STRING_AGG(j,E''\\n'' ORDER BY j),'''')) FROM '
                   '(SELECT TO_JSONB(t)::text j FROM public.%I t) s',r.relname) INTO digest;
    answer := answer || JSONB_BUILD_OBJECT(r.relname,digest);
  END LOOP;
  RETURN answer;
END;
$snap$;
CREATE TEMP TABLE unchanged_application_rows AS SELECT pg_temp.application_digests() AS value;

-- ---------------------------------------------------------------------------
-- Scenario A01: Published allocator interface.
-- Setup:    Inspect the migrated routine's exact catalogue entry.
-- Expected: Required SMALLINT/enum arguments, VARCHAR, invoker and NULL defaults.
-- ---------------------------------------------------------------------------
SELECT ok(TO_REGPROCEDURE('public.f_get_account_number(smallint,public.t_associated_record_type_enum)')
          IS NOT NULL,'A01 allocator exists');
SELECT ok((SELECT proargnames=ARRAY['pi_business_unit_id','pi_associated_record_type']::TEXT[]
                  AND prorettype='varchar'::regtype AND pronargdefaults=0
                  AND NOT proisstrict AND NOT prosecdef AND provolatile='v'
           FROM pg_proc WHERE oid=TO_REGPROCEDURE(
             'public.f_get_account_number(smallint,public.t_associated_record_type_enum)')),
          'A01 exact allocator parameters, return and default attributes');

-- ---------------------------------------------------------------------------
-- Scenario A02: First and repeated allocation share the Business Unit sequence.
-- Setup:    Call once per type on an empty synthetic Business Unit.
-- Expected: Exact consecutive complete numbers and one matching row per call.
-- ---------------------------------------------------------------------------
INSERT INTO account_results VALUES ('first',public.f_get_account_number(
    31901::SMALLINT,'respondent_accounts'::public.t_associated_record_type_enum));
SELECT is((SELECT number FROM account_results WHERE label='first'),
    pg_temp.expected_account_number(TO_CHAR(NOW(),'YY')||'000001'),'A02 complete first number');
SELECT is((SELECT COUNT(*) FROM public.account_number_index WHERE business_unit_id=31901),
          1::BIGINT,'A02 exactly one reservation');
SELECT is((SELECT COUNT(*) FROM public.account_number_index a JOIN account_results r
    ON r.label='first' AND r.number=a.account_number
    WHERE a.business_unit_id=31901 AND a.associated_record_type='respondent_accounts'),
    1::BIGINT,'A02 persisted number, BU and type match first return');
SELECT ok((SELECT number ~ '^[0-9]{8}[A-W]$' AND LENGTH(number)=9
           FROM account_results WHERE label='first'),'A02 exact nine-character format');
INSERT INTO account_results VALUES ('second',public.f_get_account_number(
    31901::SMALLINT,'creditor_accounts'::public.t_associated_record_type_enum));
SELECT is((SELECT number FROM account_results WHERE label='second'),
    pg_temp.expected_account_number(TO_CHAR(NOW(),'YY')||'000002'),'A02 complete second number');
SELECT is((SELECT COUNT(*) FROM public.account_number_index WHERE business_unit_id=31901),
          2::BIGINT,'A02 exactly two reservations');
SELECT is((SELECT COUNT(*) FROM public.account_number_index a JOIN account_results r
    ON r.label='second' AND r.number=a.account_number
    WHERE a.business_unit_id=31901 AND a.associated_record_type='creditor_accounts'),
    1::BIGINT,'A02 persisted number, BU and type match second return');
SELECT ok(EXISTS(SELECT 1 FROM public.account_number_index a JOIN account_results r
    ON r.label='first' AND r.number=a.account_number
    WHERE a.business_unit_id=31901 AND a.associated_record_type='respondent_accounts'),
    'A02 first allocation retained');
SELECT isnt((SELECT number FROM account_results WHERE label='first'),
            (SELECT number FROM account_results WHERE label='second'),'A02 repeat returns a distinct number');

-- ---------------------------------------------------------------------------
-- Scenario A03: Business Units have independent allocation ranges.
-- Setup:    Allocate in another BU and attempt a duplicate in the first BU.
-- Expected: Same first number is allowed across BUs; type cannot bypass uniqueness.
-- ---------------------------------------------------------------------------
INSERT INTO account_results VALUES ('other-bu',public.f_get_account_number(
    31902::SMALLINT,'respondent_accounts'::public.t_associated_record_type_enum));
SELECT is((SELECT number FROM account_results WHERE label='other-bu'),
          (SELECT number FROM account_results WHERE label='first'),'A03 other BU starts independently');
SELECT is((SELECT COUNT(*) FROM public.account_number_index a JOIN account_results r
    ON r.label='other-bu' AND r.number=a.account_number
    WHERE a.business_unit_id=31902 AND a.associated_record_type='respondent_accounts'),
    1::BIGINT,'A03 exact other-BU persisted allocation');
SELECT is((SELECT COUNT(*) FROM public.account_number_index WHERE business_unit_id=31901),
          2::BIGINT,'A03 original BU count unchanged');
SELECT throws_ok($q$INSERT INTO public.account_number_index
    (business_unit_id,account_number,associated_record_type)
    SELECT 31901,number,'creditor_accounts' FROM account_results WHERE label='first'$q$,
    '23505',NULL,'A03 duplicate BU and number rejected across types');

-- ---------------------------------------------------------------------------
-- Scenario A04: Each RM enum value and explicit NULL is accepted unchanged.
-- Setup:    Allocate in deterministic enum order on a fresh BU.
-- Expected: Five consecutive complete numbers and five matching record types.
-- ---------------------------------------------------------------------------
CREATE TEMP TABLE type_cases(ordinal INTEGER, record_type public.t_associated_record_type_enum);
INSERT INTO type_cases VALUES (1,'respondent_accounts'),(2,'creditor_accounts'),
    (3,'creditor_transactions'),(4,'suspense_transactions'),(5,NULL);
DO $types$
DECLARE
    test_case RECORD;
BEGIN
    FOR test_case IN SELECT * FROM type_cases ORDER BY ordinal LOOP
        INSERT INTO account_results VALUES ('type-'||test_case.ordinal,
            public.f_get_account_number(31903::SMALLINT,test_case.record_type));
    END LOOP;
END;
$types$;
SELECT is(r.number,pg_temp.expected_account_number(TO_CHAR(NOW(),'YY')||LPAD(c.ordinal::TEXT,6,'0')),
          'A04 full number for type position '||c.ordinal)
FROM type_cases c JOIN account_results r ON r.label='type-'||c.ordinal ORDER BY c.ordinal;
SELECT is((SELECT COUNT(*) FROM public.account_number_index a WHERE a.business_unit_id=31903
              AND a.account_number=r.number AND a.associated_record_type IS NOT DISTINCT FROM c.record_type),
          1::BIGINT,'A04 exact stored type for position '||c.ordinal)
FROM type_cases c JOIN account_results r ON r.label='type-'||c.ordinal ORDER BY c.ordinal;
SELECT is((SELECT COUNT(*) FROM public.account_number_index WHERE business_unit_id=31903),
          5::BIGINT,'A04 exactly five reservations');

-- ---------------------------------------------------------------------------
-- Scenario A05: Previous-year allocations do not advance the current year.
-- Setup:    Seed the previous year's maximum on a dedicated BU.
-- Expected: Current year starts at one; seeded row remains unchanged.
-- ---------------------------------------------------------------------------
WITH inserted AS (INSERT INTO public.account_number_index
    (business_unit_id,account_number,associated_record_type)
    VALUES (31904,pg_temp.expected_account_number(LPAD((TO_CHAR(NOW(),'YY')::INTEGER-1)::TEXT,2,'0')||'999999'),NULL)
    RETURNING *) INSERT INTO seeded_rows SELECT * FROM inserted;
INSERT INTO account_results VALUES ('past-year',public.f_get_account_number(
    31904::SMALLINT,'respondent_accounts'::public.t_associated_record_type_enum));
SELECT is((SELECT number FROM account_results WHERE label='past-year'),
          pg_temp.expected_account_number(TO_CHAR(NOW(),'YY')||'000001'),'A05 current year starts at one');
SELECT is((SELECT COUNT(*) FROM public.account_number_index a JOIN account_results r
    ON r.label='past-year' AND a.account_number=r.number
    WHERE a.business_unit_id=31904 AND a.associated_record_type='respondent_accounts'),
    1::BIGINT,'A05 full return matches new row');
SELECT ok(NOT EXISTS(SELECT 1 FROM seeded_rows s WHERE s.business_unit_id=31904
    AND NOT EXISTS(SELECT 1 FROM public.account_number_index a WHERE TO_JSONB(a)=TO_JSONB(s))),
    'A05 original earlier-year row unchanged');

-- ---------------------------------------------------------------------------
-- Scenario A06: Allocations already in a future year continue that year.
-- Setup:    Seed year 99 at sequence one in another BU.
-- Expected: Return 99000002 with its letter; seed remains unchanged.
-- ---------------------------------------------------------------------------
WITH inserted AS (INSERT INTO public.account_number_index
    (business_unit_id,account_number,associated_record_type)
    VALUES (31905,pg_temp.expected_account_number('99000001'),'respondent_accounts')
    RETURNING *) INSERT INTO seeded_rows SELECT * FROM inserted;
INSERT INTO account_results VALUES ('future-year',public.f_get_account_number(
    31905::SMALLINT,'creditor_accounts'::public.t_associated_record_type_enum));
SELECT is((SELECT number FROM account_results WHERE label='future-year'),
          pg_temp.expected_account_number('99000002'),'A06 highest existing future year continues');
SELECT is((SELECT COUNT(*) FROM public.account_number_index a JOIN account_results r
    ON r.label='future-year' AND a.account_number=r.number
    WHERE a.business_unit_id=31905 AND a.associated_record_type='creditor_accounts'),
    1::BIGINT,'A06 full return matches new row');
SELECT ok(NOT EXISTS(SELECT 1 FROM seeded_rows s WHERE s.business_unit_id=31905
    AND NOT EXISTS(SELECT 1 FROM public.account_number_index a WHERE TO_JSONB(a)=TO_JSONB(s))),
    'A06 future-year seed unchanged');

-- ---------------------------------------------------------------------------
-- Scenario A07: Gaps are reused only after the selected sequence reaches maximum.
-- Setup:    Seed sequences one and three in the current year.
-- Expected: Allocate four, preserving both seeds.
-- ---------------------------------------------------------------------------
WITH inserted AS (INSERT INTO public.account_number_index
    (business_unit_id,account_number,associated_record_type)
    SELECT 31906,pg_temp.expected_account_number(TO_CHAR(NOW(),'YY')||LPAD(n::TEXT,6,'0')),NULL
    FROM (VALUES (1),(3)) AS numbers(n) RETURNING *) INSERT INTO seeded_rows SELECT * FROM inserted;
INSERT INTO account_results VALUES ('before-maximum',public.f_get_account_number(
    31906::SMALLINT,NULL::public.t_associated_record_type_enum));
SELECT is((SELECT number FROM account_results WHERE label='before-maximum'),
          pg_temp.expected_account_number(TO_CHAR(NOW(),'YY')||'000004'),'A07 increment before gap reuse');
SELECT is((SELECT COUNT(*) FROM public.account_number_index a JOIN account_results r
    ON r.label='before-maximum' AND a.account_number=r.number
    WHERE a.business_unit_id=31906 AND a.associated_record_type IS NULL),
    1::BIGINT,'A07 full return matches new row');
SELECT ok(NOT EXISTS(SELECT 1 FROM seeded_rows s WHERE s.business_unit_id=31906
    AND NOT EXISTS(SELECT 1 FROM public.account_number_index a WHERE TO_JSONB(a)=TO_JSONB(s))),
    'A07 both seeded rows unchanged');

-- ---------------------------------------------------------------------------
-- Scenario A08: The caller owns the allocation's transaction boundary.
-- Setup:    Allocate alongside caller work, roll back a savepoint and call again.
-- Expected: Both effects roll back; number is reusable, surrogate ID is not rewound.
-- ---------------------------------------------------------------------------
CREATE TEMP TABLE caller_marker(id INTEGER);
SAVEPOINT caller_unit;
INSERT INTO caller_marker VALUES (1);
SELECT public.f_get_account_number(31902::SMALLINT,NULL::public.t_associated_record_type_enum)
       AS rolled_back_number \gset
SELECT account_number_index_id AS rolled_back_id FROM public.account_number_index
WHERE business_unit_id=31902 AND account_number=:'rolled_back_number' \gset
ROLLBACK TO SAVEPOINT caller_unit;
RELEASE SAVEPOINT caller_unit;
SELECT is((SELECT COUNT(*) FROM caller_marker),0::BIGINT,'A08 caller work rolled back');
SELECT is((SELECT COUNT(*) FROM public.account_number_index
           WHERE business_unit_id=31902 AND account_number=:'rolled_back_number'),
          0::BIGINT,'A08 reservation rolled back');
INSERT INTO account_results VALUES ('reused',public.f_get_account_number(
    31902::SMALLINT,NULL::public.t_associated_record_type_enum));
SELECT is((SELECT number FROM account_results WHERE label='reused'),
          :'rolled_back_number'::VARCHAR,'A08 rolled-back number reusable');
SELECT is((SELECT COUNT(*) FROM public.account_number_index a JOIN account_results r
    ON r.label='reused' AND r.number=a.account_number
    WHERE a.business_unit_id=31902 AND a.associated_record_type IS NULL),
    1::BIGINT,'A08 reused return matches persisted allocation');
SELECT ok((SELECT a.account_number_index_id > :'rolled_back_id'::BIGINT
    FROM public.account_number_index a JOIN account_results r
    ON r.label='reused' AND r.number=a.account_number WHERE a.business_unit_id=31902),
    'A08 production surrogate sequence was not rewound');

-- ---------------------------------------------------------------------------
-- Scenario A09: Database and call-resolution failures propagate unchanged.
-- Setup:    Invalid BU, enum, argument count and range; valid negative BU.
-- Expected: Native states, no failed reservation, no invented positive-ID rule.
-- ---------------------------------------------------------------------------
SELECT ok(NOT EXISTS(SELECT 1 FROM public.business_units WHERE business_unit_id=31899),
    'A09 missing BU fixture is genuinely absent');
CREATE TEMP TABLE ledger_before_failures AS
SELECT MD5(COALESCE(STRING_AGG(TO_JSONB(a)::TEXT,E'\n' ORDER BY account_number_index_id),'')) AS value
FROM public.account_number_index a;
SELECT throws_ok($q$SELECT public.f_get_account_number(NULL::SMALLINT,
  'respondent_accounts'::public.t_associated_record_type_enum)$q$,
  '23502',NULL,'A09 NULL BU');
SELECT throws_ok($q$SELECT public.f_get_account_number(31899::SMALLINT,
  'respondent_accounts'::public.t_associated_record_type_enum)$q$,
  '23503',NULL,'A09 missing BU');
SELECT throws_ok($q$SELECT public.f_get_account_number(31901::SMALLINT,
  'defendant_accounts'::public.t_associated_record_type_enum)$q$,
  '22P02',NULL,'A09 unsupported enum rejected before routine');
SELECT throws_ok($q$SELECT public.f_get_account_number(31901::SMALLINT)$q$,
  '42883',NULL,'A09 missing type argument');
SELECT throws_ok($q$SELECT public.f_get_account_number(40000::SMALLINT,
  NULL::public.t_associated_record_type_enum)$q$,
  '22003',NULL,'A09 BU numeric overflow before routine');
SELECT is((SELECT MD5(COALESCE(STRING_AGG(TO_JSONB(a)::TEXT,E'\n' ORDER BY account_number_index_id),''))
           FROM public.account_number_index a),
          (SELECT value FROM ledger_before_failures),'A09 failed calls preserve every ledger row');
INSERT INTO account_results VALUES ('negative-bu',public.f_get_account_number(
    (-31901)::SMALLINT,'respondent_accounts'::public.t_associated_record_type_enum));
SELECT is((SELECT number FROM account_results WHERE label='negative-bu'),
          pg_temp.expected_account_number(TO_CHAR(NOW(),'YY')||'000001'),'A09 existing negative BU accepted');
SELECT is((SELECT COUNT(*) FROM public.account_number_index a JOIN account_results r
    ON r.label='negative-bu' AND r.number=a.account_number
    WHERE a.business_unit_id=-31901 AND a.associated_record_type='respondent_accounts'),
    1::BIGINT,'A09 exact negative-BU persisted allocation');

-- ---------------------------------------------------------------------------
-- Scenario A10: Four uniqueness collisions recover on the fifth total attempt.
-- Setup:    BU-scoped test trigger and a nontransactional test-only counter.
-- Expected: Five attempts, exact complete candidate, one row, other rows unchanged.
-- ---------------------------------------------------------------------------
SAVEPOINT retry_fixture;
CREATE SEQUENCE pg_temp.collision_attempts START 1;
CREATE FUNCTION pg_temp.inject_account_collision() RETURNS trigger LANGUAGE plpgsql AS $trigger$
BEGIN
    IF NEW.business_unit_id=31906 AND
       NEXTVAL('pg_temp.collision_attempts') <= CURRENT_SETTING('po10642.collisions')::INTEGER THEN
        RAISE EXCEPTION USING ERRCODE=CURRENT_SETTING('po10642.injected_state'),
            MESSAGE='synthetic allocation collision', CONSTRAINT='po10642_synthetic_collision';
    END IF;

    RETURN NEW;
END;
$trigger$;
CREATE TRIGGER po10642_inject_collision BEFORE INSERT ON public.account_number_index
    FOR EACH ROW EXECUTE FUNCTION pg_temp.inject_account_collision();
SET LOCAL po10642.collisions='4';
SET LOCAL po10642.injected_state='23505';
CREATE TEMP TABLE retry_before AS SELECT COUNT(*) AS row_count FROM public.account_number_index WHERE business_unit_id=31906;
CREATE TEMP TABLE retry_other_rows AS SELECT * FROM public.account_number_index WHERE business_unit_id<>31906;
SELECT public.f_get_account_number(31906::SMALLINT,NULL::public.t_associated_record_type_enum)
       AS retry_number \gset
SELECT is((SELECT last_value FROM pg_temp.collision_attempts),5::BIGINT,'A10 fifth attempt succeeds');
SELECT is((SELECT COUNT(*) FROM public.account_number_index
           WHERE business_unit_id=31906 AND account_number=:'retry_number' AND associated_record_type IS NULL),
          1::BIGINT,'A10 one exact successful row');
SELECT is(:'retry_number'::VARCHAR,pg_temp.expected_account_number(TO_CHAR(NOW(),'YY')||'000005'),
          'A10 complete fifth-sequence number');
SELECT is((SELECT COUNT(*) FROM public.account_number_index WHERE business_unit_id=31906),
          (SELECT row_count+1 FROM retry_before),'A10 exactly one-row delta');
SELECT results_eq($q$SELECT TO_JSONB(a)::TEXT FROM public.account_number_index a
                       WHERE business_unit_id<>31906 ORDER BY account_number_index_id$q$,
                  $q$SELECT TO_JSONB(a)::TEXT FROM retry_other_rows a ORDER BY account_number_index_id$q$,
                  'A10 other BUs unchanged');

-- ---------------------------------------------------------------------------
-- Scenario A11: Retry exhaustion preserves diagnostics; other failures propagate.
-- Setup:    Five 23505 errors, then injected serialization and deadlock failures.
-- Expected: P0001 after five attempts with candidate/BU/cause/constraint; no other retries.
-- ---------------------------------------------------------------------------
CREATE TEMP TABLE retry_ledger_before AS SELECT * FROM public.account_number_index;
ALTER SEQUENCE pg_temp.collision_attempts RESTART WITH 1;
SET LOCAL po10642.collisions='5';
SELECT throws_ok($q$SELECT public.f_get_account_number(31906::SMALLINT,
    NULL::public.t_associated_record_type_enum)$q$,'P0001',NULL,'A11 fifth conflict fails');
SELECT is((SELECT last_value FROM pg_temp.collision_attempts),5::BIGINT,'A11 no sixth attempt');
SELECT results_eq($q$SELECT TO_JSONB(a)::TEXT FROM public.account_number_index a ORDER BY account_number_index_id$q$,
                  $q$SELECT TO_JSONB(a)::TEXT FROM retry_ledger_before a ORDER BY account_number_index_id$q$,
                  'A11 retry exhaustion preserves every ledger row');
CREATE FUNCTION pg_temp.capture_failure() RETURNS JSONB LANGUAGE plpgsql AS $capture$
DECLARE
    failure_constraint TEXT;
BEGIN
    PERFORM public.f_get_account_number(31906::SMALLINT,NULL::public.t_associated_record_type_enum);
    RETURN JSONB_BUILD_OBJECT('state','unexpected success');

EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS failure_constraint=CONSTRAINT_NAME;

    RETURN JSONB_BUILD_OBJECT('state',SQLSTATE,'message',SQLERRM,'constraint',failure_constraint);
END;
$capture$;
ALTER SEQUENCE pg_temp.collision_attempts RESTART WITH 1;
CREATE TEMP TABLE failure_diagnostic AS SELECT pg_temp.capture_failure() AS value;
SELECT ok((SELECT value->>'state'='P0001'
             AND value->>'message' LIKE '%23505:%synthetic allocation collision%'
             AND POSITION('Account number = ' || pg_temp.expected_account_number(
                   LEFT(:'retry_number',2) || LPAD(
                     (SUBSTRING(:'retry_number' FROM 3 FOR 6)::INTEGER+1)::TEXT,6,'0'))
                   || ', BU = 31906;' IN value->>'message') > 0
           FROM failure_diagnostic),'A11 terminal diagnostic identifies candidate and BU and preserves cause');
SELECT is((SELECT value->>'constraint' FROM failure_diagnostic),'po10642_synthetic_collision'::TEXT,
          'A11 terminal exception retains structured constraint metadata');
ALTER SEQUENCE pg_temp.collision_attempts RESTART WITH 1;
SET LOCAL po10642.injected_state='40001';
SELECT throws_ok($q$SELECT public.f_get_account_number(31906::SMALLINT,
 NULL::public.t_associated_record_type_enum)$q$,'40001',NULL,'A11 serialization failure propagates');
SELECT is((SELECT last_value FROM pg_temp.collision_attempts),1::BIGINT,'A11 no serialization retry');
ALTER SEQUENCE pg_temp.collision_attempts RESTART WITH 1;
SET LOCAL po10642.injected_state='40P01';
SELECT throws_ok($q$SELECT public.f_get_account_number(31906::SMALLINT,
 NULL::public.t_associated_record_type_enum)$q$,'40P01',NULL,'A11 deadlock failure propagates');
SELECT is((SELECT last_value FROM pg_temp.collision_attempts),1::BIGINT,'A11 no deadlock retry');
DROP TRIGGER po10642_inject_collision ON public.account_number_index;
RELEASE SAVEPOINT retry_fixture;

-- ---------------------------------------------------------------------------
-- Scenario A12: Allocation changes only the intended ledger rows.
-- Setup:    Compare all permanent application-table and unrelated ledger snapshots.
-- Expected: No account, casefile, run-status or other Business Unit row changes.
-- ---------------------------------------------------------------------------
SELECT is(pg_temp.application_digests(),(SELECT value FROM unchanged_application_rows),
          'A12 allocator does not change unrelated application tables');
SELECT results_eq($q$SELECT TO_JSONB(a)::TEXT FROM public.account_number_index a
                     WHERE business_unit_id NOT BETWEEN 31901 AND 31906 AND business_unit_id<>-31901
                     ORDER BY account_number_index_id$q$,
                  $q$SELECT TO_JSONB(a)::TEXT FROM unrelated_allocations a ORDER BY account_number_index_id$q$,
                  'A12 pre-existing ledger rows unchanged');

-- ---------------------------------------------------------------------------
-- Scenario B01: Full selected sequences reuse the lowest available gap.
-- Setup:    Mixed years, missing first number and interior gaps on an owned BU.
-- Expected: Selected-year minimum, then lowest gap; exact return/row and one-row delta.
-- ---------------------------------------------------------------------------
DELETE FROM public.account_number_index WHERE business_unit_id=31904;
INSERT INTO public.account_number_index(business_unit_id,account_number,associated_record_type)
VALUES (31904,pg_temp.expected_account_number(TO_CHAR(NOW(),'YY')||'000001'),'respondent_accounts'),
       (31904,pg_temp.expected_account_number('99000001'),'creditor_accounts'),
       (31904,pg_temp.expected_account_number('99999999'),NULL);
INSERT INTO account_results VALUES ('mixed-year',public.f_get_account_number(
    31904::SMALLINT,'respondent_accounts'::public.t_associated_record_type_enum));
SELECT is((SELECT number FROM account_results WHERE label='mixed-year'),
          pg_temp.expected_account_number('99000002'),'B01 gap belongs to selected year');
SELECT is((SELECT COUNT(*) FROM public.account_number_index a JOIN account_results r
    ON r.label='mixed-year' AND a.account_number=r.number
    WHERE a.business_unit_id=31904 AND a.associated_record_type='respondent_accounts'),
    1::BIGINT,'B01 mixed-year return matches persisted row');
SELECT is((SELECT COUNT(*) FROM public.account_number_index WHERE business_unit_id=31904),
          4::BIGINT,'B01 mixed-year one-row delta');

DELETE FROM public.account_number_index WHERE business_unit_id=31904;
INSERT INTO public.account_number_index(business_unit_id,account_number,associated_record_type)
VALUES (31904,pg_temp.expected_account_number('99999999'),NULL);
INSERT INTO account_results VALUES ('minimum-gap',public.f_get_account_number(
    31904::SMALLINT,NULL::public.t_associated_record_type_enum));
SELECT is((SELECT number FROM account_results WHERE label='minimum-gap'),
          pg_temp.expected_account_number('99000001'),'B01 missing first sequence reused');
SELECT is((SELECT COUNT(*) FROM public.account_number_index a JOIN account_results r
    ON r.label='minimum-gap' AND a.account_number=r.number
    WHERE a.business_unit_id=31904 AND a.associated_record_type IS NULL),
    1::BIGINT,'B01 minimum-gap return matches persisted row');
SELECT is((SELECT COUNT(*) FROM public.account_number_index WHERE business_unit_id=31904),
          2::BIGINT,'B01 minimum-gap one-row delta');

DELETE FROM public.account_number_index WHERE business_unit_id=31904;
INSERT INTO public.account_number_index(business_unit_id,account_number,associated_record_type)
SELECT 31904,pg_temp.expected_account_number('99'||LPAD(n::TEXT,6,'0')),NULL
FROM (VALUES (1),(2),(4),(999999)) AS numbers(n);
INSERT INTO account_results VALUES ('interior-gap',public.f_get_account_number(
    31904::SMALLINT,'creditor_accounts'::public.t_associated_record_type_enum));
SELECT is((SELECT number FROM account_results WHERE label='interior-gap'),
          pg_temp.expected_account_number('99000003'),'B01 lowest interior gap reused');
SELECT is((SELECT COUNT(*) FROM public.account_number_index a JOIN account_results r
    ON r.label='interior-gap' AND a.account_number=r.number
    WHERE a.business_unit_id=31904 AND a.associated_record_type='creditor_accounts'),
    1::BIGINT,'B01 interior-gap return matches persisted row');
SELECT is((SELECT COUNT(*) FROM public.account_number_index WHERE business_unit_id=31904),
          5::BIGINT,'B01 interior-gap one-row delta');

-- ---------------------------------------------------------------------------
-- Scenario B02: An actually full year rolls into the following two-digit year.
-- Setup:    Generate all 999999 positions for year 98 using the independent oracle.
-- Expected: Full 99000001 return and matching new row; all year-98 rows unchanged.
-- ---------------------------------------------------------------------------
SET LOCAL statement_timeout='180s';
DELETE FROM public.account_number_index WHERE business_unit_id=31905;
INSERT INTO public.account_number_index(business_unit_id,account_number,associated_record_type)
SELECT 31905,pg_temp.expected_account_number('98'||LPAD(n::TEXT,6,'0')),NULL
FROM GENERATE_SERIES(1,999999) n;
CREATE TEMP TABLE full_year_before AS
SELECT MD5(STRING_AGG(TO_JSONB(a)::TEXT,E'\n' ORDER BY account_number_index_id)) AS value
FROM public.account_number_index a WHERE business_unit_id=31905;
SELECT is((SELECT COUNT(*) FROM public.account_number_index WHERE business_unit_id=31905),
          999999::BIGINT,'B02 genuinely full selected year');
INSERT INTO account_results VALUES ('rollover',public.f_get_account_number(
    31905::SMALLINT,NULL::public.t_associated_record_type_enum));
SELECT is((SELECT number FROM account_results WHERE label='rollover'),
          pg_temp.expected_account_number('99000001'),'B02 rollover full return');
SELECT is((SELECT COUNT(*) FROM public.account_number_index WHERE business_unit_id=31905),
          1000000::BIGINT,'B02 exactly one rollover row');
SELECT is((SELECT COUNT(*) FROM public.account_number_index a JOIN account_results r
    ON r.label='rollover' AND a.account_number=r.number
    WHERE a.business_unit_id=31905 AND a.associated_record_type IS NULL),
    1::BIGINT,'B02 rollover return matches persisted row');
SELECT is((SELECT MD5(STRING_AGG(TO_JSONB(a)::TEXT,E'\n' ORDER BY account_number_index_id))
           FROM public.account_number_index a WHERE business_unit_id=31905 AND LEFT(account_number,2)='98'),
          (SELECT value FROM full_year_before),'B02 previous full year rows unchanged');

-- ---------------------------------------------------------------------------
-- Scenario B03: A fully exhausted year 99 fails without a malformed year or row.
-- Setup:    Generate every position for year 99 and snapshot its complete rows.
-- Expected: Exact P0001 range error and unchanged ledger, with nine-character values.
-- ---------------------------------------------------------------------------
DELETE FROM public.account_number_index WHERE business_unit_id=31905;
INSERT INTO public.account_number_index(business_unit_id,account_number,associated_record_type)
SELECT 31905,pg_temp.expected_account_number('99'||LPAD(n::TEXT,6,'0')),NULL
FROM GENERATE_SERIES(1,999999) n;
CREATE TEMP TABLE terminal_year_before AS
SELECT MD5(STRING_AGG(TO_JSONB(a)::TEXT,E'\n' ORDER BY account_number_index_id)) AS value
FROM public.account_number_index a WHERE business_unit_id=31905;
SELECT throws_ok($q$SELECT public.f_get_account_number(31905::SMALLINT,
 NULL::public.t_associated_record_type_enum)$q$,'P0001',
 'Account number range exhausted for year 99','B03 terminal year range failure');
SELECT is((SELECT COUNT(*) FROM public.account_number_index WHERE business_unit_id=31905),
          999999::BIGINT,'B03 no extra allocation');
SELECT ok(NOT EXISTS(SELECT 1 FROM public.account_number_index
  WHERE business_unit_id=31905 AND LENGTH(account_number)<>9),'B03 no three-digit year');
SELECT is((SELECT MD5(STRING_AGG(TO_JSONB(a)::TEXT,E'\n' ORDER BY account_number_index_id))
           FROM public.account_number_index a WHERE business_unit_id=31905),
          (SELECT value FROM terminal_year_before),'B03 failed call preserves every terminal-year row');
DELETE FROM public.account_number_index WHERE business_unit_id=31905;
SET LOCAL statement_timeout='30s';

SELECT * FROM finish();
ROLLBACK;
