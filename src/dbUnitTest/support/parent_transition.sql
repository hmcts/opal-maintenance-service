/**
 * OPAL Program
 *
 * MODULE      : parent_transition.sql
 *
 * DESCRIPTION : Exact retained-target batch history and application-state preservation.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket             Nature of Change
 * ----------  -------------  -----------------  ----------------------------------------
 * 18/10/2026  Frankie Moran  PO-10655           Initial shared batch verification.
 * 22/10/2026  Frankie Moran  PO-10655           Port preservation onto current shared lifecycle.
 */
\set ON_ERROR_STOP 1
\ir upgrade_contract.sql
\if :{?opal_parent_repeat}
\else
    \set opal_parent_repeat false
\endif

-- One fixed search path makes enum/domain argument identities identical in every phase.
CREATE OR REPLACE FUNCTION pg_temp.opal_parent_routine_identity(target OID) RETURNS TEXT
LANGUAGE SQL SET search_path = pg_catalog, pg_temp AS $identity$
    SELECT FORMAT('public.%I(%s)',proname,OIDVECTORTYPES(proargtypes)) FROM pg_proc WHERE oid=target;
$identity$;

CREATE OR REPLACE FUNCTION pg_temp.opal_parent_snapshot(original JSONB DEFAULT NULL) RETURNS JSONB
LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp AS $snapshot$
DECLARE item RECORD; identity TEXT; columns_sql TEXT; value JSONB; result JSONB :=
    '{"tables":{},"rows":{},"routines":{},"enums":{},"sequences":{}}';
BEGIN
    -- Public application objects only; extension-owned routines/relations are test infrastructure.
    FOR item IN SELECT c.oid,c.relname,c.relkind FROM pg_class c
        WHERE c.relnamespace='public'::REGNAMESPACE AND c.relkind IN ('r','p','v','m','S')
          AND c.relname<>'flyway_schema_history'
          AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.classid='pg_class'::REGCLASS
                          AND d.objid=c.oid AND d.deptype='e') ORDER BY c.relname LOOP
        identity := FORMAT('public.%I',item.relname);
        IF item.relkind='S' THEN
            result := JSONB_SET(result,ARRAY['sequences',identity],pg_temp.opal_contract_object('sequence',identity)
                || JSONB_BUILD_OBJECT('comment',OBJ_DESCRIPTION(item.oid,'pg_class')));
        ELSE
            value := pg_temp.opal_contract_object(CASE WHEN item.relkind IN ('v','m') THEN 'view' ELSE 'table' END,identity);
            value := value || JSONB_BUILD_OBJECT(
                'storage',(SELECT JSONB_BUILD_OBJECT('access_method',relam,'tablespace',reltablespace)
                    FROM pg_class WHERE oid=item.oid),
                'constraint_comments',(SELECT COALESCE(JSONB_OBJECT_AGG(conname,OBJ_DESCRIPTION(oid,'pg_constraint')),'{}')
                    FROM pg_constraint WHERE conrelid=item.oid),
                'index_properties',(SELECT COALESCE(JSONB_AGG(TO_JSONB(i) ORDER BY indexrelid),'[]') FROM (
                    SELECT x.indexrelid,TO_JSONB(x)-'indcheckxmin' AS semantic_properties,
                           c.relowner,c.relacl,c.reloptions,c.relam,c.reltablespace,
                           OBJ_DESCRIPTION(x.indexrelid,'pg_class') AS comment
                    FROM pg_index x JOIN pg_class c ON c.oid=x.indexrelid WHERE x.indrelid=item.oid) i),
                'triggers',(SELECT COALESCE(JSONB_AGG(TO_JSONB(t) ORDER BY tgname),'[]') FROM (
                    SELECT tgname,tgenabled,tgisinternal,PG_GET_TRIGGERDEF(oid,false) AS definition,
                           OBJ_DESCRIPTION(oid,'pg_trigger') AS comment FROM pg_trigger
                    WHERE tgrelid=item.oid) t),
                'policies',(SELECT COALESCE(JSONB_AGG(TO_JSONB(p) ORDER BY polname),'[]') FROM (
                    SELECT polname,polcmd,polpermissive,polroles,PG_GET_EXPR(polqual,polrelid) AS qualification,
                           PG_GET_EXPR(polwithcheck,polrelid) AS check_expression,OBJ_DESCRIPTION(oid,'pg_policy') AS comment
                    FROM pg_policy WHERE polrelid=item.oid) p));
            result := JSONB_SET(result,ARRAY['tables',identity],value);
            IF item.relkind IN ('r','p') THEN
                -- Project precisely the original columns: retain JSON spelling/duplicates and multiplicity.
                SELECT STRING_AGG(FORMAT('t.%I',c->>'attname'),',' ORDER BY (c->>'attnum')::INTEGER)
                INTO columns_sql FROM JSONB_ARRAY_ELEMENTS(COALESCE(original->'tables'->identity->'columns',value->'columns')) c;
                EXECUTE FORMAT('SELECT COALESCE(JSONB_AGG(value ORDER BY value),''[]''::JSONB)
                    FROM (SELECT ROW_TO_JSON(projected)::TEXT AS value FROM
                         (SELECT %s FROM %s t) projected) rows',columns_sql,item.oid::REGCLASS) INTO value;
                result := JSONB_SET(result,ARRAY['rows',identity],value);
            END IF;
        END IF;
    END LOOP;
    FOR item IN SELECT p.oid,pg_temp.opal_parent_routine_identity(p.oid) AS identity
        FROM pg_proc p WHERE p.pronamespace='public'::REGNAMESPACE AND p.prokind IN ('f','p')
        AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.classid='pg_proc'::REGCLASS AND d.objid=p.oid AND d.deptype='e') LOOP
        value := pg_temp.opal_contract_object('routine',item.identity);
        value := JSONB_SET(value,'{metadata}',value->'metadata' ||
            (SELECT JSONB_BUILD_OBJECT('prosupport',prosupport) FROM pg_proc WHERE oid=item.oid));
        result := JSONB_SET(result,ARRAY['routines',item.identity],value);
    END LOOP;
    FOR item IN SELECT oid,FORMAT('public.%I',typname) AS identity FROM pg_type
        WHERE typnamespace='public'::REGNAMESPACE AND typtype='e' LOOP
        result := JSONB_SET(result,ARRAY['enums',item.identity],pg_temp.opal_contract_object('enum',item.identity)
            || JSONB_BUILD_OBJECT('comment',OBJ_DESCRIPTION(item.oid,'pg_type')));
    END LOOP;
    RETURN result;
END;
$snapshot$;

CREATE OR REPLACE FUNCTION pg_temp.opal_parent_expected(original JSONB, delta JSONB) RETURNS JSONB
LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp AS $expected$
DECLARE result JSONB := original; columns_value JSONB; constraints_value JSONB;
BEGIN
    IF delta->>'aliases'='true' THEN
        SELECT JSONB_AGG(CASE WHEN c->>'attname' IN ('surname','forenames')
            THEN JSONB_SET(c,'{attnotnull}','false') WHEN c->>'attname'='organisation_name'
            THEN JSONB_SET(c,'{type}','"character varying(80)"') ELSE c END ORDER BY (c->>'attnum')::INTEGER)
        INTO columns_value FROM JSONB_ARRAY_ELEMENTS(original->'tables'->'public.aliases'->'columns') c;
        IF columns_value IS NULL THEN RAISE EXCEPTION 'Aliases transition lacks predecessor table'; END IF;
        result := JSONB_SET(result,'{tables,public.aliases,columns}',columns_value);
    END IF;
    IF delta->>'responses'='true' THEN
        columns_value := original->'tables'->'public.order_terms'->'columns';
        IF columns_value IS NULL THEN RAISE EXCEPTION 'Response transition lacks predecessor table'; END IF;
        columns_value := columns_value || JSONB_BUILD_ARRAY(JSONB_BUILD_OBJECT(
            'attnum',(SELECT MAX((c->>'attnum')::INTEGER)+1 FROM JSONB_ARRAY_ELEMENTS(columns_value) c),
            'attname','result_responses','type','json','attnotnull',false,'attidentity','',
            'attgenerated','','attcollation',0::OID,'attacl',NULL,'default_expression',NULL,
            'comment','Result-response JSON array captured for the Order Term; NULL when not captured or unavailable.'));
        constraints_value := (original->'tables'->'public.order_terms'->'constraints') || JSONB_BUILD_ARRAY(
            JSONB_BUILD_OBJECT('conname','ot_result_responses_array_ck','contype','c','convalidated',true,
                'condeferrable',false,'condeferred',false,
                'definition','CHECK (((result_responses IS NULL) OR (json_typeof(result_responses) = ''array''::text)))'));
        SELECT JSONB_AGG(c ORDER BY c->>'conname') INTO constraints_value FROM JSONB_ARRAY_ELEMENTS(constraints_value) c;
        result := JSONB_SET(result,'{tables,public.order_terms,columns}',columns_value);
        result := JSONB_SET(result,'{tables,public.order_terms,constraints}',constraints_value);
        result := JSONB_SET(result,'{tables,public.order_terms,constraint_comments}',
            (original->'tables'->'public.order_terms'->'constraint_comments') ||
            JSONB_BUILD_OBJECT('ot_result_responses_array_ck',NULL));
    END IF;
    RETURN result;
END;
$expected$;

BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SET LOCAL search_path=public,pg_catalog;
SET LOCAL TIME ZONE 'UTC';
SET LOCAL statement_timeout='60s';
SELECT pg_temp.opal_upgrade_require_identity(:'opal_scenario_id',:'opal_candidate_version',:'opal_predecessor_version');
-- -----------------------------------------------------------------------------
-- Scenario: Capture or compare one real parent-to-candidate retained database.
-- Setup: Native Flyway owns migration; registered metadata declares bounded changes.
-- Expected: Exact histories, rows and catalogues; only declared deltas are accepted.
-- -----------------------------------------------------------------------------
\if :opal_parent_repeat
    SELECT plan(1);
    SELECT is((SELECT JSONB_AGG(TO_JSONB(h) ORDER BY installed_rank) FROM flyway_schema_history h),
        pg_temp.opal_upgrade_load(:'opal_scenario_id',:'opal_candidate_version',:'opal_predecessor_version')->'final_history',
        'native repeat preserves every complete final history field');
    SELECT * FROM finish();
    ROLLBACK;
\elif :is_prepare
    SELECT plan(3);
    SELECT is((SELECT JSONB_AGG(JSONB_BUILD_OBJECT('version',version,'script',script) ORDER BY installed_rank)
        FROM flyway_schema_history),:'opal_expected_history'::JSONB,'parent history equals exact selected prefix');
    SELECT ok((SELECT BOOL_AND(success AND type='SQL' AND checksum IS NOT NULL) FROM flyway_schema_history),
        'parent migrations are successful checksummed SQL');
    SELECT pg_temp.opal_upgrade_save(:'opal_scenario_id',:'opal_candidate_version',:'opal_predecessor_version',
        JSONB_BUILD_OBJECT('snapshot',pg_temp.opal_parent_snapshot(),'delta',:'opal_parent_delta'::JSONB,
            'history',(SELECT JSONB_AGG(TO_JSONB(h) ORDER BY installed_rank) FROM flyway_schema_history h)));
    SELECT ok(pg_temp.opal_upgrade_load(:'opal_scenario_id',:'opal_candidate_version',:'opal_predecessor_version')
        ->'snapshot'=pg_temp.opal_parent_snapshot(),'durable parent snapshot matches actual state');
    SELECT * FROM finish();
    COMMIT;
\elif :is_verify
    SELECT pg_temp.opal_upgrade_load(:'opal_scenario_id',:'opal_candidate_version',:'opal_predecessor_version') AS saved \gset
    SELECT pg_temp.opal_parent_snapshot(:'saved'::JSONB->'snapshot') AS actual \gset
    SELECT pg_temp.opal_parent_expected(:'saved'::JSONB->'snapshot',:'opal_parent_delta'::JSONB) AS expected \gset
    SELECT plan(8 + JSONB_ARRAY_LENGTH(:'opal_parent_delta'::JSONB->'routines')
        + CASE WHEN :'opal_parent_delta'::JSONB->>'responses'='true' THEN 1 ELSE 0 END);
    SELECT :'opal_parent_delta'::JSONB->>'responses'='true' AS check_responses \gset
    \if :check_responses
        SELECT ok(NOT EXISTS (SELECT 1 FROM public.order_terms WHERE result_responses IS NOT NULL),
            'new response column is NULL for every retained row');
    \endif
    SELECT is(:'saved'::JSONB->'delta',:'opal_parent_delta'::JSONB,'batch delta provenance unchanged');
    SELECT is((SELECT JSONB_AGG(JSONB_BUILD_OBJECT('version',version,'script',script) ORDER BY installed_rank)
        FROM flyway_schema_history),:'opal_expected_history'::JSONB,'batch history equals exact final inventory');
    SELECT is((SELECT JSONB_AGG(TO_JSONB(h) ORDER BY installed_rank) FROM flyway_schema_history h
        WHERE installed_rank<=JSONB_ARRAY_LENGTH(:'saved'::JSONB->'history')),
        :'saved'::JSONB->'history','every complete parent history row preserved');
    SELECT ok((SELECT BOOL_AND(success AND type='SQL' AND checksum IS NOT NULL) FROM flyway_schema_history),
        'batch migrations are successful checksummed SQL');
    SELECT is(:'actual'::JSONB->'rows',:'expected'::JSONB->'rows','all original row text and multiplicity preserved');
    SELECT is(:'actual'::JSONB-'routines'-'rows',:'expected'::JSONB-'routines'-'rows',
        'all application catalogue and sequence state matches exact allowed delta');
    -- Resolve canonical identities in this backend so metadata spelling cannot bypass comparison.
    CREATE TEMP TABLE parent_changed_routines AS SELECT p.oid,
        pg_temp.opal_parent_routine_identity(p.oid) AS identity
        FROM JSONB_ARRAY_ELEMENTS_TEXT(:'opal_parent_delta'::JSONB->'routines') r
        LEFT JOIN pg_proc p ON p.oid=TO_REGPROCEDURE(r);
    SELECT ok(oid IS NOT NULL,'declared final routine exists') FROM parent_changed_routines;
    SELECT is((:'actual'::JSONB->'routines')-ARRAY(SELECT identity FROM parent_changed_routines WHERE identity IS NOT NULL),
        (:'expected'::JSONB->'routines')-ARRAY(SELECT identity FROM parent_changed_routines WHERE identity IS NOT NULL),
        'undeclared routines cannot be added removed or changed');
    SELECT ok(NOT EXISTS(SELECT 1 FROM parent_changed_routines r
        WHERE :'expected'::JSONB->'routines' ? r.identity AND
        :'expected'::JSONB->'routines'->r.identity->'metadata' IS DISTINCT FROM
        :'actual'::JSONB->'routines'->r.identity->'metadata'),
        'base routine identities properties comments and privileges preserved');
    -- Capture history after preservation; repeat compares it after rolled-back owning assertions.
    UPDATE opal_test_upgrade_observation.observation SET payload=payload || JSONB_BUILD_OBJECT(
        'final_history',(SELECT JSONB_AGG(TO_JSONB(h) ORDER BY installed_rank) FROM flyway_schema_history h));
    SELECT * FROM finish();
    COMMIT;
\elif :is_cleanup
    SELECT plan(1);
    SELECT pg_temp.opal_upgrade_remove(:'opal_scenario_id',:'opal_candidate_version',:'opal_predecessor_version');
    COMMIT;
    BEGIN;
    SELECT ok(pg_temp.opal_upgrade_absent_from_new_backend(),'parent observation absence confirmed by distinct backend');
    SELECT * FROM finish();
    ROLLBACK;
\else
    DO $phase$ BEGIN RAISE EXCEPTION 'Parent transition requires prepare verify or cleanup'; END; $phase$;
\endif
