-- PO-10636 / M03 / V1_17: two approved global configuration records.
-- Source: rm/common/reference-data/configuration-items.csv; independent literal expectations.
-- Fresh DB-01, plus actual-file replay inside this rolled-back synthetic transaction.
-- This is not predecessor/upgrade evidence; unrelated scopes must remain unchanged.
\set ON_ERROR_STOP on
\set cv_configuration_migration /tmp/opal-db-migrations/data/allEnvs/V1_17__insert_configuration_items_data.sql
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SET LOCAL search_path=public,pg_temp;
SET LOCAL TIME ZONE 'UTC';
SELECT plan(28);

-- Scenario: Source/target agreement and generated identifiers.
-- Setup: Load an independent two-row expected relation from the approved CSV contract.
-- Expected: Exact selected rows in both directions, distinct generated IDs, scalar values and NULL JSON.
CREATE TEMP TABLE cv_expected_config(item_name text,business_unit_id smallint,item_value text,item_values text);
INSERT INTO cv_expected_config VALUES
 ('DEFAULT_CHEQUE_CLEARANCE_PERIOD',NULL,'10',NULL),
 ('DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD',NULL,'0',NULL);
SELECT is((SELECT count(*) FROM cv_expected_config),2::bigint,'approved source count');
SELECT is((SELECT count(*) FROM public.configuration_items WHERE business_unit_id IS NULL AND item_name IN (SELECT item_name FROM cv_expected_config)),2::bigint,'selected target count');
SELECT is_empty($s$SELECT item_name,business_unit_id,item_value,item_values FROM cv_expected_config EXCEPT SELECT item_name,business_unit_id,item_value,item_values::text FROM public.configuration_items WHERE business_unit_id IS NULL AND item_name IN (SELECT item_name FROM cv_expected_config)$s$,'no source row missing or changed in selected target');
SELECT is_empty($s$SELECT item_name,business_unit_id,item_value,item_values::text FROM public.configuration_items WHERE business_unit_id IS NULL AND item_name IN (SELECT item_name FROM cv_expected_config) EXCEPT SELECT item_name,business_unit_id,item_value,item_values FROM cv_expected_config$s$,'no unexplained selected target row');
SELECT is((SELECT count(DISTINCT configuration_item_id) FROM public.configuration_items WHERE business_unit_id IS NULL AND item_name IN (SELECT item_name FROM cv_expected_config)),2::bigint,'generated identifiers present and distinct');
SELECT is_empty($s$SELECT configuration_item_id FROM public.configuration_items WHERE business_unit_id IS NULL AND item_name IN (SELECT item_name FROM cv_expected_config) AND configuration_item_id IN (60000000000012,60000000000013)$s$,'Fines identifiers are not copied');
SELECT ok((SELECT bool_and(item_values IS NULL) FROM public.configuration_items WHERE business_unit_id IS NULL AND item_name IN (SELECT item_name FROM cv_expected_config)),'both structured values remain SQL NULL');
SELECT is(pg_typeof((SELECT item_value FROM public.configuration_items WHERE item_name='DEFAULT_CHEQUE_CLEARANCE_PERIOD' AND business_unit_id IS NULL))::text,'text','scalar value is stored as text');
SELECT is((SELECT count(*) FROM public.flyway_schema_history WHERE script='V1_17__insert_configuration_items_data.sql' AND success),1::bigint,'allocated allEnvs file appears in successful Flyway history');
CREATE TEMP TABLE cv_original AS SELECT item_name,configuration_item_id,xmin::text AS xmin_value FROM public.configuration_items WHERE business_unit_id IS NULL AND item_name IN (SELECT item_name FROM cv_expected_config);

-- Scenario: Replay preserves unrelated data and Business Unit overrides.
-- Setup: One synthetic Business Unit, one unrelated global JSON key and two overrides.
-- Expected: Replaying the real migration writes no unchanged target rows and preserves every other row.
DO $fixture$ BEGIN
 IF EXISTS (SELECT 1 FROM public.business_units WHERE business_unit_id=32061 OR business_unit_code='CV61') THEN RAISE EXCEPTION 'Synthetic configuration-test Business Unit collision'; END IF;
 IF EXISTS (SELECT 1 FROM public.configuration_items WHERE item_name='CV_UNRELATED') THEN RAISE EXCEPTION 'Synthetic configuration key collision'; END IF;
END $fixture$;
INSERT INTO public.business_units(business_unit_id,business_unit_code,business_unit_name,business_unit_type,welsh_language) VALUES (32061,'CV61','Synthetic configuration test unit','Area',false);
INSERT INTO public.configuration_items(item_name,business_unit_id,item_value,item_values) VALUES
 ('CV_UNRELATED',NULL,'preserve','{"synthetic":true}'),
 ('DEFAULT_CHEQUE_CLEARANCE_PERIOD',32061,'77','{"override":1}'),
 ('DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD',32061,'88',NULL);
CREATE TEMP TABLE cv_unrelated AS SELECT configuration_item_id,to_jsonb(c) AS row_value FROM public.configuration_items c WHERE NOT (business_unit_id IS NULL AND item_name IN (SELECT item_name FROM cv_expected_config));
\i :cv_configuration_migration
\set cv_affected :ROW_COUNT
SELECT is(:'cv_affected'::bigint,0::bigint,'unchanged replay writes zero rows');
SELECT is_empty($s$SELECT o.configuration_item_id FROM cv_original o JOIN public.configuration_items c USING(item_name,configuration_item_id) WHERE c.business_unit_id IS NULL AND c.xmin::text IS DISTINCT FROM o.xmin_value$s$,'unchanged target row versions preserved');
SELECT is((SELECT count(*) FROM cv_original o JOIN public.configuration_items c USING(item_name,configuration_item_id) WHERE c.business_unit_id IS NULL),2::bigint,'both target IDs preserved after replay');
SELECT is_empty($s$SELECT configuration_item_id,row_value FROM cv_unrelated EXCEPT SELECT configuration_item_id,to_jsonb(c) FROM public.configuration_items c WHERE NOT (business_unit_id IS NULL AND item_name IN (SELECT item_name FROM cv_expected_config))$s$,'no unrelated before-image changed after replay');
SELECT is_empty($s$SELECT configuration_item_id,to_jsonb(c) FROM public.configuration_items c WHERE NOT (business_unit_id IS NULL AND item_name IN (SELECT item_name FROM cv_expected_config)) EXCEPT SELECT configuration_item_id,row_value FROM cv_unrelated$s$,'no unexplained unrelated row after replay');

-- Scenario: Correct only the approved target values.
-- Setup: Change one scalar to 99 and the other structured value to a non-NULL object.
-- Expected: Real-file replay corrects exactly two rows, preserving IDs and all unrelated rows.
UPDATE public.configuration_items SET item_value='99' WHERE item_name='DEFAULT_CHEQUE_CLEARANCE_PERIOD' AND business_unit_id IS NULL;
UPDATE public.configuration_items SET item_values='{}'::json WHERE item_name='DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD' AND business_unit_id IS NULL;
\i :cv_configuration_migration
\set cv_affected :ROW_COUNT
SELECT is(:'cv_affected'::bigint,2::bigint,'correction replay writes exactly two rows');
SELECT is_empty($s$SELECT item_name,business_unit_id,item_value,item_values FROM cv_expected_config EXCEPT SELECT item_name,business_unit_id,item_value,item_values::text FROM public.configuration_items WHERE business_unit_id IS NULL AND item_name IN (SELECT item_name FROM cv_expected_config)$s$,'both corrected target values match source');
SELECT is_empty($s$SELECT item_name,business_unit_id,item_value,item_values::text FROM public.configuration_items WHERE business_unit_id IS NULL AND item_name IN (SELECT item_name FROM cv_expected_config) EXCEPT SELECT item_name,business_unit_id,item_value,item_values FROM cv_expected_config$s$,'correction adds no unexpected selected values');
SELECT is((SELECT count(*) FROM cv_original o JOIN public.configuration_items c USING(item_name,configuration_item_id) WHERE c.business_unit_id IS NULL),2::bigint,'correction preserves both identifiers');
SELECT is_empty($s$SELECT configuration_item_id,row_value FROM cv_unrelated EXCEPT SELECT configuration_item_id,to_jsonb(c) FROM public.configuration_items c WHERE NOT (business_unit_id IS NULL AND item_name IN (SELECT item_name FROM cv_expected_config))$s$,'correction preserves unrelated before-images');
SELECT is_empty($s$SELECT configuration_item_id,to_jsonb(c) FROM public.configuration_items c WHERE NOT (business_unit_id IS NULL AND item_name IN (SELECT item_name FROM cv_expected_config)) EXCEPT SELECT configuration_item_id,row_value FROM cv_unrelated$s$,'correction creates no unexplained unrelated data');

-- Scenario: Restore a missing approved key without copying identifiers.
-- Setup: Delete one selected global row in this transaction, retaining the other and all overrides.
-- Expected: Replay inserts exactly one generated row; another replay is a no-op.
DELETE FROM public.configuration_items WHERE item_name='DEFAULT_CHEQUE_CLEARANCE_PERIOD' AND business_unit_id IS NULL;
\i :cv_configuration_migration
\set cv_affected :ROW_COUNT
SELECT is(:'cv_affected'::bigint,1::bigint,'missing-row replay writes exactly one row');
SELECT is((SELECT count(*) FROM public.configuration_items WHERE business_unit_id IS NULL AND item_name IN (SELECT item_name FROM cv_expected_config)),2::bigint,'missing global row restored');
SELECT ok((SELECT c.configuration_item_id IS NOT NULL AND c.configuration_item_id<>o.configuration_item_id FROM public.configuration_items c JOIN cv_original o USING(item_name) WHERE c.item_name='DEFAULT_CHEQUE_CLEARANCE_PERIOD' AND c.business_unit_id IS NULL),'restored row receives a new generated identifier');
SELECT is((SELECT c.configuration_item_id FROM public.configuration_items c WHERE c.item_name='DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD' AND c.business_unit_id IS NULL),(SELECT configuration_item_id FROM cv_original WHERE item_name='DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD'),'other target ID preserved');
SELECT is_empty($s$SELECT configuration_item_id,row_value FROM cv_unrelated EXCEPT SELECT configuration_item_id,to_jsonb(c) FROM public.configuration_items c WHERE NOT (business_unit_id IS NULL AND item_name IN (SELECT item_name FROM cv_expected_config))$s$,'restore preserves unrelated rows');
SELECT is_empty($s$SELECT configuration_item_id,to_jsonb(c) FROM public.configuration_items c WHERE NOT (business_unit_id IS NULL AND item_name IN (SELECT item_name FROM cv_expected_config)) EXCEPT SELECT configuration_item_id,row_value FROM cv_unrelated$s$,'restore creates no unrelated row');
\i :cv_configuration_migration
\set cv_affected :ROW_COUNT
SELECT is(:'cv_affected'::bigint,0::bigint,'repeat after restore writes zero rows');
SELECT is_empty($s$SELECT item_name,business_unit_id,item_value,item_values FROM cv_expected_config EXCEPT SELECT item_name,business_unit_id,item_value,item_values::text FROM public.configuration_items WHERE business_unit_id IS NULL AND item_name IN (SELECT item_name FROM cv_expected_config)$s$,'restored set remains exact');
SELECT * FROM finish();
ROLLBACK;
