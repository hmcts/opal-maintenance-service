/**
 * OPAL Program
 *
 * MODULE      : draft_casefiles_publication_link_pgtap_tests.sql
 *
 * DESCRIPTION : Verify the Draft Casefiles account link and publication foreign key.
 *
 * CHANGE HISTORY:
 *
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * 03/10/2026  Chris Larkin  PO-10659      Initial pgTAP test suite.
 */

-- PO-10659 / M14 / V1_28: Draft Casefile publication link integrity.
-- Fresh DB-01 only; separate existing-state validation not run under the
-- user-approved initial-schema exception. No publication procedure is invoked.
\set ON_ERROR_STOP on
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SET LOCAL search_path=public,pg_temp;
SET LOCAL TIME ZONE 'UTC';
SELECT plan(25);

-- ---------------------------------------------------------------------------
-- Scenario: The final FK preserves the existing nullable link and unique index.
-- Setup: Inspect the migrated catalogue independently of any synthetic rows.
-- Expected: Validated immediate NO ACTION FK, nullable BIGINT, original three indexes.
-- ---------------------------------------------------------------------------
SELECT is((SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conrelid='public.draft_casefiles'::regclass AND conname='dcf_account_id_fk'),'FOREIGN KEY (account_id) REFERENCES respondent_accounts(respondent_account_id)','publication FK endpoint');
SELECT is((SELECT confupdtype::text||confdeltype::text||condeferrable::text||condeferred::text||convalidated::text FROM pg_constraint WHERE conrelid='public.draft_casefiles'::regclass AND conname='dcf_account_id_fk'),'aafalsefalsetrue','validated immediate NO ACTION publication FK');
SELECT is((SELECT format_type(atttypid,atttypmod) FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='account_id'),'bigint','account link remains BIGINT');
SELECT is((SELECT attnotnull FROM pg_attribute WHERE attrelid='public.draft_casefiles'::regclass AND attname='account_id'),false,'account link remains nullable');
SELECT is((SELECT array_agg(conname::text ORDER BY conname) FROM pg_constraint WHERE conrelid='public.draft_casefiles'::regclass AND contype IN ('p','f','u','c')),ARRAY['dcf_account_id_fk','dcf_business_unit_id_fk','draft_casefiles_account_id_uk','draft_casefiles_pk']::text[],'exact four constraints after link addition');
SELECT is((SELECT array_agg(indexname::text ORDER BY indexname) FROM pg_indexes WHERE schemaname='public' AND tablename='draft_casefiles'),ARRAY['draft_casefiles_account_id_uk','draft_casefiles_business_unit_id_idx','draft_casefiles_pk']::text[],'existing three indexes retained without duplicate account index');
SELECT is((SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conrelid='public.draft_casefiles'::regclass AND conname='draft_casefiles_account_id_uk'),'UNIQUE (account_id)','existing unique link preserved');
SELECT ok((SELECT indisunique AND indisvalid AND indisready FROM pg_index WHERE indexrelid='public.draft_casefiles_account_id_uk'::regclass),'existing account unique index is valid and ready');

-- ---------------------------------------------------------------------------
-- Scenario: Own collision-free parent and draft fixtures.
-- Setup: One synthetic Business Unit, generated Respondent Account, and two generated drafts.
-- Expected: No missing fixture prerequisites; NULL and valid links are accepted.
-- ---------------------------------------------------------------------------
DO $fixture$ BEGIN
 IF EXISTS (SELECT 1 FROM public.business_units WHERE business_unit_id=32061 OR business_unit_code='CV61') THEN RAISE EXCEPTION 'Synthetic publication-link Business Unit collision'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.maintenance_applications) THEN RAISE EXCEPTION 'Required Maintenance Application reference data missing'; END IF;
END $fixture$;
INSERT INTO public.business_units(business_unit_id,business_unit_code,business_unit_name,business_unit_type,welsh_language) VALUES (32061,'CV61','Synthetic publication link unit','Area',false);
CREATE TEMP TABLE cv_respondent AS
WITH inserted AS (
 INSERT INTO public.respondent_accounts(business_unit_id,account_number,application_id,account_balance,orders_balance,orders_amount,payment_period,total_arrears,account_status,last_movement_date,date_arrears_last_updated,allow_cheques,cheque_clearance_period,credit_trans_clearance_period,casefile_type,interest_flag,indexation,payment_arrangement,version_number)
 SELECT 32061,'CV-PUBLISHED',(SELECT min(application_id) FROM public.maintenance_applications),0,0,0,'Weekly',0,'L',TIMESTAMP '2026-01-01 12:00:00',TIMESTAMP '2026-01-01 12:00:00',true,10,0,'REMO In',false,'None','Court',1 RETURNING respondent_account_id)
 SELECT respondent_account_id FROM inserted;
CREATE TEMP TABLE cv_drafts(label text PRIMARY KEY,id bigint NOT NULL);
SELECT lives_ok($s$WITH inserted AS (INSERT INTO public.draft_casefiles(business_unit_id,created_date,submitted_by,submitted_by_name,casefile,casefile_snapshot,casefile_type,casefile_status,casefile_status_date,timeline_data) VALUES (32061,TIMESTAMP '2026-01-01 12:00:00','synthetic','Synthetic','{}','{}','REMO In','SUBMITTED',TIMESTAMP '2026-01-01 12:00:00','[]') RETURNING draft_casefile_id) INSERT INTO cv_drafts SELECT 'unlinked',draft_casefile_id FROM inserted$s$,'NULL link accepted before publication');
SELECT lives_ok($s$WITH inserted AS (INSERT INTO public.draft_casefiles(business_unit_id,created_date,submitted_by,submitted_by_name,casefile,casefile_snapshot,casefile_type,casefile_status,casefile_status_date,timeline_data,account_id) SELECT 32061,TIMESTAMP '2026-01-01 12:00:00','synthetic','Synthetic','{}','{}','REMO In','PUBLISHED',TIMESTAMP '2026-01-01 12:00:00','[]',respondent_account_id FROM cv_respondent RETURNING draft_casefile_id) INSERT INTO cv_drafts SELECT 'linked',draft_casefile_id FROM inserted$s$,'valid published account link accepted');
SELECT is((SELECT account_id FROM public.draft_casefiles WHERE draft_casefile_id=(SELECT id FROM cv_drafts WHERE label='unlinked')),NULL::bigint,'unpublished draft retains NULL account');
SELECT is((SELECT account_id FROM public.draft_casefiles WHERE draft_casefile_id=(SELECT id FROM cv_drafts WHERE label='linked')),(SELECT respondent_account_id FROM cv_respondent),'published draft stores generated parent ID');
SELECT is((SELECT count(DISTINCT id) FROM cv_drafts),2::bigint,'draft identifiers present and distinct');

-- ---------------------------------------------------------------------------
-- Scenario: Missing parents and duplicate publication links fail at the real boundary.
-- Setup: Use a confirmed absent account ID and the owned existing account.
-- Expected: 23503 for missing parents/deletion, 23505 for duplicate links; failed statements preserve rows.
-- ---------------------------------------------------------------------------
SELECT is((SELECT count(*) FROM public.respondent_accounts WHERE respondent_account_id=-990061),0::bigint,'deliberate missing parent is absent');
SELECT throws_ok($s$UPDATE public.draft_casefiles SET account_id=-990061 WHERE draft_casefile_id=(SELECT id FROM cv_drafts WHERE label='unlinked')$s$,'23503',NULL,'missing account update rejected');
SELECT throws_ok($s$INSERT INTO public.draft_casefiles(business_unit_id,created_date,submitted_by,submitted_by_name,casefile,casefile_snapshot,casefile_type,casefile_status,casefile_status_date,timeline_data,account_id) VALUES (32061,TIMESTAMP '2026-01-01 12:00:00','synthetic','Synthetic','{}','{}','REMO In','SUBMITTED',TIMESTAMP '2026-01-01 12:00:00','[]',-990061)$s$,'23503',NULL,'missing account insert rejected');
SELECT throws_ok($s$UPDATE public.draft_casefiles SET account_id=(SELECT respondent_account_id FROM cv_respondent) WHERE draft_casefile_id=(SELECT id FROM cv_drafts WHERE label='unlinked')$s$,'23505',NULL,'duplicate link update rejected');
SELECT throws_ok($s$INSERT INTO public.draft_casefiles(business_unit_id,created_date,submitted_by,submitted_by_name,casefile,casefile_snapshot,casefile_type,casefile_status,casefile_status_date,timeline_data,account_id) SELECT 32061,TIMESTAMP '2026-01-01 12:00:00','synthetic','Synthetic','{}','{}','REMO In','SUBMITTED',TIMESTAMP '2026-01-01 12:00:00','[]',respondent_account_id FROM cv_respondent$s$,'23505',NULL,'duplicate link insert rejected');
SELECT throws_ok($s$DELETE FROM public.respondent_accounts WHERE respondent_account_id=(SELECT respondent_account_id FROM cv_respondent)$s$,'23503',NULL,'referenced parent protected from deletion');
SELECT is((SELECT account_id FROM public.draft_casefiles WHERE draft_casefile_id=(SELECT id FROM cv_drafts WHERE label='unlinked')),NULL::bigint,'failed updates leave unpublished draft unlinked');
SELECT is((SELECT count(*) FROM public.draft_casefiles WHERE draft_casefile_id IN (SELECT id FROM cv_drafts)),2::bigint,'failed statements preserve both owned draft rows');
SELECT is((SELECT count(*) FROM cv_respondent r JOIN public.respondent_accounts a USING(respondent_account_id)),1::bigint,'failed parent delete preserves account');

-- ---------------------------------------------------------------------------
-- Scenario: Optional links retain ordinary NULL uniqueness semantics.
-- Setup: Set the published draft link back to NULL in this transaction.
-- Expected: Multiple NULL links accepted and no orphaned non-NULL link remains.
-- ---------------------------------------------------------------------------
SELECT lives_ok($s$UPDATE public.draft_casefiles SET account_id=NULL WHERE draft_casefile_id=(SELECT id FROM cv_drafts WHERE label='linked')$s$,'published link can return to NULL');
SELECT is((SELECT count(*) FROM public.draft_casefiles WHERE draft_casefile_id IN (SELECT id FROM cv_drafts) AND account_id IS NULL),2::bigint,'multiple NULL links accepted');
SELECT is((SELECT count(*) FROM public.draft_casefiles d LEFT JOIN public.respondent_accounts r ON r.respondent_account_id=d.account_id WHERE d.account_id IS NOT NULL AND r.respondent_account_id IS NULL),0::bigint,'no orphaned links in disposable final schema');
SELECT * FROM finish();
ROLLBACK;
