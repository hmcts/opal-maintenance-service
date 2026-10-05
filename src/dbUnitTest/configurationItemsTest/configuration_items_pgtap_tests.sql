/**
 * OPAL Program
 *
 * MODULE      : configuration_items_pgtap_tests.sql
 *
 * DESCRIPTION : Verify the Configuration Items schema and integrity rules.
 *
 * CHANGE HISTORY:
 *
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * 03/10/2026  Chris Larkin  PO-10638      Initial pgTAP test suite.
 */

-- Check & Validate: PO-10638 / M02 / V1_18
-- Fresh DB-01; existing-state validation not run: user-approved initial-schema exception.
-- All fixtures synthetic and rolled back; no shared or deployed target.

\set ON_ERROR_STOP on
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SET LOCAL search_path=public,pg_temp;
SET LOCAL TIME ZONE 'UTC';
SELECT plan(34);
DO $fixture$
BEGIN
 IF EXISTS (SELECT 1 FROM public.business_units WHERE business_unit_id IN (32061,32062)
            OR business_unit_code IN ('CV61','CV62')) THEN
  RAISE EXCEPTION 'Synthetic Business Unit fixture collision';
 END IF;
END
$fixture$;
INSERT INTO public.business_units
 (business_unit_id,business_unit_code,business_unit_name,business_unit_type,welsh_language)
VALUES (32061,'CV61','Synthetic test unit A','Area',false),
       (32062,'CV62','Synthetic test unit B','Area',false);
CREATE TEMP TABLE cv_subject (id bigint PRIMARY KEY);

-- ---------------------------------------------------------------------------
-- Scenario: Physical configuration table contract.
-- Setup: Migrations applied with synthetic Business Units.
-- Expected: Exact columns, constraints, indexes and owned ID sequence.
-- ---------------------------------------------------------------------------
SELECT is((SELECT jsonb_agg(jsonb_build_array(attname::text,format_type(atttypid,atttypmod),attnotnull) ORDER BY attnum) FROM pg_attribute WHERE attrelid='public.configuration_items'::regclass AND attnum>0 AND NOT attisdropped), '[["configuration_item_id","bigint",true],["item_name","character varying(50)",true],["business_unit_id","smallint",false],["item_value","text",false],["item_values","json",false]]'::jsonb, 'exact columns/types/nullability');
SELECT is((SELECT array_agg(conname::text ORDER BY conname) FROM pg_constraint WHERE conrelid='public.configuration_items'::regclass AND contype IN ('p','u','f','c')),ARRAY['ci_business_unit_id_fk','configuration_items_item_name_business_unit_id_uk','configuration_items_pk']::text[],'exact constraint inventory');
SELECT is((SELECT array_agg(indexname::text ORDER BY indexname) FROM pg_indexes WHERE schemaname='public' AND tablename='configuration_items'),ARRAY['ci_business_unit_id_idx','configuration_items_item_name_business_unit_id_uk','configuration_items_pk']::text[],'exact index inventory');
SELECT is(pg_get_serial_sequence('public.configuration_items','configuration_item_id'),'public.configuration_item_id_seq','owned sequence');
SELECT is((SELECT count(*) FROM pg_attrdef WHERE adrelid='public.configuration_items'::regclass),1::bigint,'only identifier default');
-- ---------------------------------------------------------------------------
-- Scenario: Required and optional inputs.
-- Setup: Create one global item with a generated identifier.
-- Expected: Required NULLs rejected (23502), optional NULLs accepted.
-- ---------------------------------------------------------------------------
SELECT lives_ok($s$WITH inserted AS (INSERT INTO public.configuration_items(item_name) VALUES ('CV_SYNTHETIC_GLOBAL') RETURNING configuration_item_id) INSERT INTO cv_subject SELECT configuration_item_id FROM inserted$s$,'minimal valid row');
SELECT throws_ok($s$UPDATE public.configuration_items SET configuration_item_id=NULL WHERE configuration_item_id=(SELECT id FROM cv_subject)$s$,'23502',NULL,'configuration_item_id required');
SELECT throws_ok($s$UPDATE public.configuration_items SET item_name=NULL WHERE configuration_item_id=(SELECT id FROM cv_subject)$s$,'23502',NULL,'item_name required');
SELECT lives_ok($s$UPDATE public.configuration_items SET business_unit_id=NULL WHERE configuration_item_id=(SELECT id FROM cv_subject)$s$,'business_unit_id nullable');
SELECT lives_ok($s$UPDATE public.configuration_items SET item_value=NULL WHERE configuration_item_id=(SELECT id FROM cv_subject)$s$,'item_value nullable');
SELECT lives_ok($s$UPDATE public.configuration_items SET item_values=NULL WHERE configuration_item_id=(SELECT id FROM cv_subject)$s$,'item_values nullable');

-- ---------------------------------------------------------------------------
-- Scenario: Sequence, defaults, keys and authoritative column documentation.
-- Setup: Inspect the migrated catalogue against independently recorded TDIA expectations.
-- Expected: BIGINT owned sequence, only its ID default, exact column comments and keys.
-- ---------------------------------------------------------------------------
SELECT is((SELECT seqtypid::regtype::text||':'||seqstart||':'||seqincrement||':'||seqcache||':'||seqcycle FROM pg_sequence WHERE seqrelid='public.configuration_item_id_seq'::regclass),'bigint:1:1:1:false','identifier sequence properties');
SELECT is((SELECT pg_get_expr(adbin,adrelid) FROM pg_attrdef WHERE adrelid='public.configuration_items'::regclass), 'nextval(''configuration_item_id_seq''::regclass)','identifier nextval default');
SELECT is((SELECT jsonb_agg(jsonb_build_array(attname::text,col_description(attrelid,attnum)) ORDER BY attnum) FROM pg_attribute WHERE attrelid='public.configuration_items'::regclass AND attnum>0 AND NOT attisdropped), '[["configuration_item_id","RM-generated configuration-item identifier"],["item_name","Configuration-item name, unique within its global or Business Unit scope"],["business_unit_id","Identifier of the related Business Unit, or NULL for a global value"],["item_value","Single text value"],["item_values","Multiple or structured values"]]'::jsonb, 'exact TDIA column comments');
SELECT is((SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname='configuration_items_pk' AND conrelid='public.configuration_items'::regclass),'PRIMARY KEY (configuration_item_id)','primary key columns');
SELECT is((SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname='ci_business_unit_id_fk' AND conrelid='public.configuration_items'::regclass),'FOREIGN KEY (business_unit_id) REFERENCES business_units(business_unit_id)','Business Unit FK endpoints');
SELECT is((SELECT confupdtype::text||confdeltype::text||condeferrable::text||condeferred::text FROM pg_constraint WHERE conname='ci_business_unit_id_fk' AND conrelid='public.configuration_items'::regclass),'aafalsefalse','immediate NO ACTION FK');
SELECT is((SELECT jsonb_agg(jsonb_build_array(i.relname::text,pg_get_indexdef(i.oid,1,true),pg_get_indexdef(i.oid,2,true),x.indisunique,x.indisvalid,x.indisready,am.amname::text) ORDER BY i.relname) FROM pg_index x JOIN pg_class i ON i.oid=x.indexrelid JOIN pg_am am ON am.oid=i.relam WHERE x.indrelid='public.configuration_items'::regclass), '[["ci_business_unit_id_idx","business_unit_id","",false,true,true,"btree"],["configuration_items_item_name_business_unit_id_uk","item_name","business_unit_id",true,true,true,"btree"],["configuration_items_pk","configuration_item_id","",true,true,true,"btree"]]'::jsonb, 'exact index columns, uniqueness, validity and btree method');
SELECT is_empty($s$SELECT i.indexrelid FROM pg_index i WHERE i.indrelid='public.configuration_items'::regclass AND (i.indnkeyatts <> CASE WHEN i.indexrelid='public.configuration_items_item_name_business_unit_id_uk'::regclass THEN 2 ELSE 1 END OR i.indnatts<>i.indnkeyatts OR i.indpred IS NOT NULL OR i.indexprs IS NOT NULL)$s$,'indexes have exact key counts with no included columns, expressions or predicates');
SELECT ok((SELECT indnullsnotdistinct FROM pg_index WHERE indexrelid='public.configuration_items_item_name_business_unit_id_uk'::regclass),'global identity treats NULL Business Unit as equal');
SELECT is((SELECT count(*) FROM pg_trigger WHERE tgrelid='public.configuration_items'::regclass AND NOT tgisinternal),0::bigint,'no business triggers');
SELECT throws_ok($s$INSERT INTO public.configuration_items(configuration_item_id,item_name) SELECT id,'CV_OTHER_ID' FROM cv_subject$s$,'23505',NULL,'duplicate primary key rejected');
SELECT ok((SELECT id IS NOT NULL FROM cv_subject),'generated identifier is present');

-- ---------------------------------------------------------------------------
-- Scenario: Global and per-Business Unit identities and optional JSON/scalar data.
-- Setup: Same item name in two Business Units and global scope.
-- Expected: Distinct scopes succeed; duplicates fail 23505; unknown parent fails 23503.
-- ---------------------------------------------------------------------------
SELECT lives_ok($s$INSERT INTO public.configuration_items(item_name,business_unit_id,item_value,item_values) VALUES ('CV_SCOPED',32061,'literal','{"synthetic":true}'),('CV_SCOPED',32062,NULL,NULL),('CV_SCOPED',NULL,NULL,NULL)$s$,'same name accepted across distinct scopes');
SELECT is((SELECT count(DISTINCT configuration_item_id) FROM public.configuration_items WHERE item_name='CV_SCOPED'),3::bigint,'scope rows receive distinct generated IDs');
SELECT is((SELECT item_values::text FROM public.configuration_items WHERE item_name='CV_SCOPED' AND business_unit_id=32061),'{"synthetic":true}','JSON retained without transformation');
SELECT throws_ok($s$INSERT INTO public.configuration_items(item_name,business_unit_id) VALUES ('CV_SCOPED',32061)$s$,'23505',NULL,'duplicate scoped identity rejected');
SELECT throws_ok($s$INSERT INTO public.configuration_items(item_name) VALUES ('CV_SCOPED')$s$,'23505',NULL,'duplicate global identity rejected');
SELECT is((SELECT count(*) FROM public.business_units WHERE business_unit_id=31999),0::bigint,'deliberate missing Business Unit is absent');
SELECT throws_ok($s$UPDATE public.configuration_items SET business_unit_id=31999 WHERE configuration_item_id=(SELECT id FROM cv_subject)$s$,'23503',NULL,'absent Business Unit rejected');
SELECT lives_ok($s$UPDATE public.configuration_items SET business_unit_id=32061 WHERE configuration_item_id=(SELECT id FROM cv_subject)$s$,'valid Business Unit accepted');
SELECT throws_ok($s$DELETE FROM public.business_units WHERE business_unit_id=32061$s$,'23503',NULL,'referenced synthetic Business Unit protected from deletion');

-- ---------------------------------------------------------------------------
-- Scenario: Declared item-name length.
-- Setup: Update the isolated subject at the exact 50-character boundary and beyond it.
-- Expected: 50 accepted; 51 rejected with 22001.
-- ---------------------------------------------------------------------------
SELECT lives_ok($s$UPDATE public.configuration_items SET item_name=repeat('X',50) WHERE configuration_item_id=(SELECT id FROM cv_subject)$s$,'50-character name accepted');
SELECT throws_ok($s$UPDATE public.configuration_items SET item_name=repeat('X',51) WHERE configuration_item_id=(SELECT id FROM cv_subject)$s$,'22001',NULL,'overlength name rejected');

SELECT * FROM finish();
ROLLBACK;
