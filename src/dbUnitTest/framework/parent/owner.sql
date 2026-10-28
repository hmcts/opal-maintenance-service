/**
 * OPAL Program
 *
 * MODULE      : owner.sql
 *
 * DESCRIPTION : Fixed final enum-typed owning assertions for parent transitions.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket             Nature of Change
 * ----------  -------------  -----------------  ----------------------------------------
 * 18/10/2026  Frankie Moran  PO-10655           Initial fixed owning assertions.
 * 22/10/2026  Frankie Moran  PO-10655           Add fixed native owner failure controls.
 */
\set ON_ERROR_STOP 1
\if :{?opal_test_case}
\else
    \set opal_test_case good
\endif
SELECT :'opal_test_case' = 'owner-sql' AS owner_sql,
       :'opal_test_case' = 'owner-tap' AS owner_tap,
       :'opal_test_case' = 'owner-zero' AS owner_zero,
       :'opal_test_case' = 'owner-wrong-plan' AS owner_wrong_plan
\gset
BEGIN;
-- -----------------------------------------------------------------------------
-- Scenario: Fixed framework controls distinguish SQL, TAP and plan failures.
-- Setup: The native framework alone supplies one of the fixed owner test cases.
-- Expected: Each fault fails its maintained command with a distinct diagnostic.
-- -----------------------------------------------------------------------------
\if :owner_sql
    DO $failure$ BEGIN RAISE EXCEPTION 'Parent owner fixed SQL failure'; END; $failure$;
\elif :owner_tap
    SELECT plan(1);
    SELECT ok(false,'parent owner fixed TAP failure');
    SELECT * FROM finish();
    ROLLBACK;
\elif :owner_zero
    SELECT '1..0 # SKIP fixed parent owner zero-plan regression';
    ROLLBACK;
\elif :owner_wrong_plan
    SELECT plan(2);
    SELECT is(public.framework_existing('one'::public.framework_enum),2,'parent owner wrong-plan passing assertion');
    SELECT * FROM finish();
    ROLLBACK;
\else
SELECT plan(2);
-- Scenario: A retained base helper and a helper created inside the batch both reach the final body.
SELECT is(public.framework_existing('one'::public.framework_enum),2,'base enum-typed helper reaches final definition');
SELECT is(public.framework_new('two'::public.framework_enum),2,'batch-created enum-typed helper reaches final definition');
SELECT * FROM finish();
ROLLBACK;
\endif
