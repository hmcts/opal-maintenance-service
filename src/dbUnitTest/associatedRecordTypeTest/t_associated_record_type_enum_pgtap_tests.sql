/**
 * OPAL Program
 *
 * MODULE      : t_associated_record_type_enum_pgtap_tests.sql
 *
 * DESCRIPTION : Verify the shared associated record type enum labels, order,
 *               accepted values and rejection of unsupported values.
 *
 * CHANGE HISTORY:
 *
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * 03/10/2026  Chris Larkin  PO-10635      Initial pgTAP test suite.
 */

-- Check & Validate: PO-10635 / M01 / V1_15
-- Fresh DB-01; existing-state validation not run: user-approved initial-schema exception.
-- All fixtures synthetic and rolled back; no shared or deployed target.

\set ON_ERROR_STOP on
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SET LOCAL search_path = public, pg_temp;
SET LOCAL TIME ZONE 'UTC';
SELECT plan(6);

-- ---------------------------------------------------------------------------
-- Scenario: Exact shared record types and invalid input.
-- Setup: Type created by migration; cast each approved label.
-- Expected: Four labels accepted in source order; unsupported label raises 22P02.
-- ---------------------------------------------------------------------------
SELECT is((SELECT array_agg(enumlabel::text ORDER BY enumsortorder)
           FROM pg_enum WHERE enumtypid='public.t_associated_record_type_enum'::regtype),
 ARRAY['respondent_accounts','creditor_accounts','creditor_transactions','suspense_transactions']::text[],
 'shared enum exact labels and order');
SELECT lives_ok(format('SELECT %L::public.t_associated_record_type_enum',label),label||' accepted')
FROM (VALUES ('respondent_accounts'),('creditor_accounts'),('creditor_transactions'),('suspense_transactions')) v(label);
SELECT throws_ok($s$SELECT 'invalid'::public.t_associated_record_type_enum$s$,
 '22P02',NULL,'invalid record type rejected');
SELECT * FROM finish();
ROLLBACK;
