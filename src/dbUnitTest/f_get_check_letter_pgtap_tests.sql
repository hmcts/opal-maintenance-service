/**
 * OPAL Program
 *
 * MODULE      : f_get_check_letter_pgtap_tests.sql
 *
 * DESCRIPTION : Verify the RM checksum contract with independent known answers.
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
SELECT plan(51);

-- ---------------------------------------------------------------------------
-- Scenario H01: published helper interface.
-- Setup: prerequisite migrations; function under delivery.
-- Expected: one VARCHAR argument/result, required argument, invoker/null semantics.
-- ---------------------------------------------------------------------------
SELECT ok(TO_REGPROCEDURE('public.f_get_check_letter(character varying)') IS NOT NULL,
          'H01 helper is present');
SELECT is((SELECT PG_GET_FUNCTION_RESULT(oid) FROM pg_proc
           WHERE oid=TO_REGPROCEDURE('public.f_get_check_letter(character varying)')),
          'character varying', 'H01 return type');
SELECT is((SELECT proargnames FROM pg_proc WHERE oid=
           TO_REGPROCEDURE('public.f_get_check_letter(character varying)')),
          ARRAY['pi_account_number']::text[], 'H01 parameter name');
SELECT ok((SELECT NOT proisstrict AND NOT prosecdef AND pronargdefaults=0 AND provolatile='v'
           FROM pg_proc WHERE oid=TO_REGPROCEDURE('public.f_get_check_letter(character varying)')),
          'H01 called on NULL, invoker, no default');

-- ---------------------------------------------------------------------------
-- Scenario H02: independent known answers, all 23 modulo outcomes and positional weights.
-- Setup: literals established independently by weighted-sum/modulo arithmetic.
-- Expected: exact letters, never computed by the production helper as oracle.
-- ---------------------------------------------------------------------------
SELECT is(public.f_get_check_letter(body::varchar), letter::varchar, 'H02 '||body)
FROM (VALUES
 ('00000000','A'),('00000006','W'),('00000016','V'),('00000026','U'),
 ('00000001','T'),('00000007','S'),('00000017','R'),('00000027','Q'),
 ('00000002','P'),('00000008','O'),('00000018','N'),('00000028','M'),
 ('00000003','L'),('00000009','K'),('00000019','J'),('00000029','I'),
 ('00000004','H'),('00000014','G'),('00000024','F'),('00000034','E'),
 ('00000005','D'),('00000015','C'),('00000025','B'),
 ('25000001','E'),('26000001','D'),('26000002','W'),('27000001','C'),
 ('27999999','G'),('12345678','H'),('99999999','P'),
 ('10000000','S'),('01000000','W'),('00100000','T'),('00010000','V'),
 ('00001000','Q'),('00000100','S'),('00000010','W')
) AS vectors(body,letter);

-- ---------------------------------------------------------------------------
-- Scenario H03: compatible NULL, suffix and malformed-prefix behaviour.
-- Setup: explicit VARCHAR arguments, including invalid first eight positions.
-- Expected: NULL propagates, suffix ignored, malformed prefix raises 22P02.
-- ---------------------------------------------------------------------------
SELECT is(public.f_get_check_letter(NULL::varchar),NULL::varchar,'H03 NULL');
SELECT is(public.f_get_check_letter('26000001D'::varchar),'D'::varchar,'H03 full number');
SELECT is(public.f_get_check_letter('26000001xyz'::varchar),'D'::varchar,'H03 suffix');
SELECT throws_ok($$SELECT public.f_get_check_letter(''::varchar)$$,'22P02',NULL,'H03 empty');
SELECT throws_ok($$SELECT public.f_get_check_letter('1234567'::varchar)$$,'22P02',NULL,'H03 short');
SELECT throws_ok($$SELECT public.f_get_check_letter('1234x678'::varchar)$$,'22P02',NULL,'H03 invalid');
SELECT throws_ok($$SELECT public.f_get_check_letter()$$,'42883',NULL,'H03 missing argument');
SELECT is(public.f_get_check_letter('26000001'::varchar),
          public.f_get_check_letter('26000001'::varchar),'H03 repeat deterministic');

-- ---------------------------------------------------------------------------
-- Scenario H04: Checksum calculation requires no application-table privileges.
-- Setup:    A transaction-owned caller has only schema and routine access.
-- Expected: No table read/write privilege; 26000001 still returns D.
-- ---------------------------------------------------------------------------
CREATE ROLE po10642_checksum_caller NOLOGIN;
GRANT USAGE ON SCHEMA public TO po10642_checksum_caller;
GRANT EXECUTE ON FUNCTION public.f_get_check_letter(VARCHAR) TO po10642_checksum_caller;
SELECT ok(NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relkind='r' AND
      HAS_TABLE_PRIVILEGE('po10642_checksum_caller',c.oid,'SELECT,INSERT,UPDATE,DELETE')),
    'H04 helper caller has no application-table read/write privileges');
SET LOCAL ROLE po10642_checksum_caller;
SELECT public.f_get_check_letter('26000001'::varchar) AS pure_result \gset
RESET ROLE;
SELECT is(:'pure_result'::TEXT,'D'::TEXT,'H04 caller with no application-table privileges');

SELECT * FROM finish();
ROLLBACK;
