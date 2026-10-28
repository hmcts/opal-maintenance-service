/**
 * OPAL Program
 *
 * MODULE      : framework_contract_prepare.sql
 *
 * DESCRIPTION : Approved synthetic preparation for the shared framework regression.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket        Nature of Change
 * ----------  -------------  ------------  ----------------------------------------
 * 15/10/2026  Frankie Moran  PO-10643      Verify optional custom preparation.
 */
-- Approved data scenario: fixed framework-only synthetic custom preparation regression.
\set ON_ERROR_STOP 1
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(2);
-- -----------------------------------------------------------------------------
-- Scenario: A rare data-dependent contract prepares synthetic rows before capture.
-- Setup: The disposable fixed framework target has only migration-created rows.
-- Expected: One guarded synthetic row commits; fixed failure control remains an error.
-- -----------------------------------------------------------------------------
DO $guard$
BEGIN
    IF CURRENT_DATABASE()<>'opal_maintenance_db_unit_test' OR CURRENT_USER<>'postgres' THEN
        RAISE EXCEPTION 'Custom framework preparation requires disposable identity';
    END IF;
    IF EXISTS(SELECT 1 FROM public.framework_reference WHERE id=10) THEN
        RAISE EXCEPTION 'Custom framework synthetic fixture collision';
    END IF;
END;
$guard$;
INSERT INTO public.framework_reference VALUES (10,'synthetic custom predecessor');
SELECT is((SELECT COUNT(*) FROM public.framework_reference WHERE id=10),1::BIGINT,
    'approved synthetic custom row exists before shared capture');
SELECT ok(TO_REGCLASS('public.framework_candidate') IS NULL,'custom preparation stays at predecessor');
\if :{?opal_test_case}
    SELECT :'opal_test_case'='contract-custom-prepare-error' AS fail_custom_preparation \gset
    \if :fail_custom_preparation
        DO $failure$ BEGIN RAISE EXCEPTION 'fixed shared custom preparation failure'; END; $failure$;
    \endif
\endif
SELECT * FROM finish();
COMMIT;
