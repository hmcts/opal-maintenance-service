/**
 * OPAL Program
 *
 * MODULE      : framework_contract_verify.sql
 *
 * DESCRIPTION : Direct check of the framework-only prepared synthetic row.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket        Nature of Change
 * ----------  -------------  ------------  ----------------------------------------
 * 15/10/2026  Frankie Moran  PO-10643      Verify optional custom candidate assertions.
 */
\set ON_ERROR_STOP 1
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(1);
-- -----------------------------------------------------------------------------
-- Scenario: An exceptional data case adds direct checks after shared preservation.
-- Setup: Approved custom predecessor row was captured before native candidate migration.
-- Expected: Candidate view preserves the exact synthetic custom row.
-- -----------------------------------------------------------------------------
SELECT is((SELECT label FROM public.framework_candidate WHERE id=10),'synthetic custom predecessor',
    'candidate preserves approved custom business assertion');
SELECT * FROM finish();
ROLLBACK;
