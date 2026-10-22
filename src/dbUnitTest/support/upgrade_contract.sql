/**
 * OPAL Program
 *
 * MODULE      : upgrade_contract.sql
 *
 * DESCRIPTION : Shared exact row and native catalogue preservation for declared scope.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket        Nature of Change
 * ----------  -------------  ------------  ----------------------------------------
 * 15/10/2026  Frankie Moran  PO-10643      Add shared declared preservation checks.
 * 22/10/2026  Frankie Moran  PO-10643      Capture bounded data contract observations.
 */
\ir ../framework/upgrade_lifecycle.sql

CREATE OR REPLACE FUNCTION pg_temp.opal_contract_require(contract JSONB) RETURNS VOID
LANGUAGE plpgsql SECURITY INVOKER SET search_path = pg_catalog, pg_temp AS $guard$
DECLARE category TEXT;
BEGIN
    IF CURRENT_DATABASE() <> 'opal_maintenance_db_unit_test' OR CURRENT_USER <> 'postgres' THEN
        RAISE EXCEPTION 'Shared contract requires its disposable harness database and role';
    END IF;
    IF JSONB_TYPEOF(contract) IS DISTINCT FROM 'object'
       OR JSONB_TYPEOF(contract->'objects') IS DISTINCT FROM 'object'
       OR JSONB_TYPEOF(contract->'preserve') IS DISTINCT FROM 'object'
       OR JSONB_TYPEOF(contract->'assertion') IS DISTINCT FROM 'string'
       OR JSONB_TYPEOF(contract->'objects'->'created') IS DISTINCT FROM 'array'
       OR JSONB_TYPEOF(contract->'objects'->'replaced') IS DISTINCT FROM 'array' THEN
        RAISE EXCEPTION 'Malformed shared preservation contract';
    END IF;
    FOREACH category IN ARRAY ARRAY['rows','tables','routines','enums','sequences'] LOOP
        IF JSONB_TYPEOF(contract->'preserve'->category) IS DISTINCT FROM 'array' THEN
            RAISE EXCEPTION 'Malformed shared preservation scope';
        END IF;
    END LOOP;
END;
$guard$;

CREATE OR REPLACE FUNCTION pg_temp.opal_contract_table(identity TEXT) RETURNS JSONB
LANGUAGE plpgsql SECURITY INVOKER SET search_path = pg_catalog, pg_temp AS $table$
DECLARE target OID := TO_REGCLASS(identity); result JSONB;
BEGIN
    IF target IS NULL THEN RETURN NULL; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_class WHERE oid=target AND relkind IN ('r','p','v','m')) THEN
        RAISE EXCEPTION 'Declared relation has incompatible kind';
    END IF;
    SELECT JSONB_BUILD_OBJECT(
        'relation',(SELECT TO_JSONB(r) FROM (
            SELECT oid,relname,relnamespace,relkind,relowner,relacl,reloptions,relpersistence,
                relrowsecurity,relforcerowsecurity,relreplident,relispartition
            FROM pg_class WHERE oid=target
        ) r),
        'columns',(SELECT COALESCE(JSONB_AGG(TO_JSONB(c) ORDER BY attnum),'[]'::JSONB) FROM (
            SELECT a.attnum,a.attname,FORMAT_TYPE(a.atttypid,a.atttypmod) AS type,
                a.attnotnull,a.attidentity,a.attgenerated,a.attcollation,a.attacl,
                PG_GET_EXPR(d.adbin,d.adrelid) AS default_expression,
                COL_DESCRIPTION(a.attrelid,a.attnum) AS comment
            FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum
            WHERE a.attrelid=target AND a.attnum>0 AND NOT a.attisdropped
        ) c),
        'constraints',(SELECT COALESCE(JSONB_AGG(TO_JSONB(c) ORDER BY conname),'[]'::JSONB) FROM (
            SELECT conname,contype,convalidated,condeferrable,condeferred,
                PG_GET_CONSTRAINTDEF(oid,false) AS definition
            FROM pg_constraint WHERE conrelid=target
        ) c),
        'indexes',(SELECT COALESCE(JSONB_AGG(TO_JSONB(i) ORDER BY indexrelid),'[]'::JSONB) FROM (
            SELECT indexrelid,indisvalid,indisready,PG_GET_INDEXDEF(indexrelid) AS definition
            FROM pg_index WHERE indrelid=target
        ) i),
        'comment',OBJ_DESCRIPTION(target,'pg_class')
    ) INTO result;
    RETURN result;
END;
$table$;

CREATE OR REPLACE FUNCTION pg_temp.opal_contract_object(kind TEXT, identity TEXT) RETURNS JSONB
LANGUAGE plpgsql SECURITY INVOKER SET search_path = pg_catalog, pg_temp AS $object$
DECLARE target OID; result JSONB; value JSONB;
BEGIN
    IF kind='routine' THEN
        BEGIN
            target := TO_REGPROCEDURE(identity);
        EXCEPTION WHEN undefined_object THEN
            target := NULL;
        END;
        IF target IS NULL THEN RETURN NULL; END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE oid=target AND prokind IN ('f','p')) THEN
            RAISE EXCEPTION 'Declared routine has incompatible kind';
        END IF;
        SELECT JSONB_BUILD_OBJECT('definition',PG_GET_FUNCTIONDEF(target),'metadata',TO_JSONB(p))
        INTO result FROM (
            SELECT oid,proname,pronamespace,proowner,prolang,procost,prorows,provariadic,prokind,
                prosecdef,proleakproof,proisstrict,proretset,provolatile,proparallel,pronargs,
                pronargdefaults,prorettype,proargtypes::TEXT,proallargtypes::TEXT,
                proargmodes::TEXT,proargnames::TEXT,proargdefaults::TEXT,protrftypes::TEXT,
                probin,proconfig,proacl,OBJ_DESCRIPTION(oid,'pg_proc') AS comment
            FROM pg_proc WHERE oid=target
        ) p;
    ELSIF kind IN ('table','view') THEN
        target := TO_REGCLASS(identity);
        IF target IS NULL THEN RETURN NULL; END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_class WHERE oid=target
            AND ((kind='table' AND relkind IN ('r','p')) OR (kind='view' AND relkind IN ('v','m')))) THEN
            RAISE EXCEPTION 'Declared relation has incompatible kind';
        END IF;
        result := pg_temp.opal_contract_table(identity);
        IF kind='view' THEN result := result || JSONB_BUILD_OBJECT('definition',PG_GET_VIEWDEF(target,false)); END IF;
    ELSIF kind='enum' THEN
        target := TO_REGTYPE(identity);
        IF target IS NULL THEN RETURN NULL; END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_type WHERE oid=target AND typtype='e') THEN
            RAISE EXCEPTION 'Declared enum has incompatible kind';
        END IF;
        SELECT JSONB_BUILD_OBJECT('type',(SELECT TO_JSONB(t) FROM (
            SELECT oid,typname,typnamespace,typowner,typacl FROM pg_type WHERE oid=target
        ) t),'labels',(SELECT JSONB_AGG(TO_JSONB(e) ORDER BY enumsortorder) FROM pg_enum e WHERE enumtypid=target))
        INTO result;
    ELSIF kind='sequence' THEN
        target := TO_REGCLASS(identity);
        IF target IS NULL THEN RETURN NULL; END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_class WHERE oid=target AND relkind='S') THEN
            RAISE EXCEPTION 'Declared sequence has incompatible kind';
        END IF;
        EXECUTE FORMAT('SELECT JSONB_BUILD_ARRAY(last_value,is_called) FROM %s',target::REGCLASS) INTO value;
        SELECT JSONB_BUILD_OBJECT('definition',(SELECT TO_JSONB(s) FROM pg_sequence s WHERE seqrelid=target),
            'relation',(SELECT TO_JSONB(r) FROM (
                SELECT oid,relname,relkind,relowner,relacl,reloptions FROM pg_class WHERE oid=target
            ) r),'ownership',(SELECT COALESCE(JSONB_AGG(TO_JSONB(d) ORDER BY objid,refobjid,refobjsubid,deptype),'[]'::JSONB)
                FROM pg_depend d WHERE classid='pg_class'::REGCLASS AND objid=target AND refclassid='pg_class'::REGCLASS),
            'value',value) INTO result;
    ELSE
        RAISE EXCEPTION 'Unsupported declared object kind';
    END IF;
    RETURN result;
END;
$object$;

CREATE OR REPLACE FUNCTION pg_temp.opal_contract_snapshot(contract JSONB) RETURNS JSONB
LANGUAGE plpgsql SECURITY INVOKER SET search_path = pg_catalog, pg_temp AS $snapshot$
DECLARE category TEXT; identity TEXT; kind TEXT; target OID; value JSONB;
        entries JSONB; result JSONB := '{}'::JSONB;
BEGIN
    PERFORM pg_temp.opal_contract_require(contract);
    FOREACH category IN ARRAY ARRAY['rows','tables','routines','enums','sequences'] LOOP
        entries := '{}'::JSONB;
        FOR identity IN SELECT JSONB_ARRAY_ELEMENTS_TEXT(contract->'preserve'->category) LOOP
            IF category='rows' THEN
                target := TO_REGCLASS(identity);
                IF target IS NULL OR NOT EXISTS (SELECT 1 FROM pg_class WHERE oid=target AND relkind IN ('r','p')) THEN
                    RAISE EXCEPTION 'Missing or incompatible declared row table';
                END IF;
                EXECUTE FORMAT('SELECT COALESCE(JSONB_AGG(value ORDER BY value),''[]''::JSONB)
                    FROM (SELECT ROW_TO_JSON(t)::TEXT AS value FROM %s t) observed',target::REGCLASS) INTO value;
            ELSE
                kind := CASE category WHEN 'tables' THEN 'table' WHEN 'routines' THEN 'routine'
                    WHEN 'enums' THEN 'enum' WHEN 'sequences' THEN 'sequence' END;
                value := pg_temp.opal_contract_object(kind,identity);
                IF value IS NULL THEN RAISE EXCEPTION 'Missing declared preservation object'; END IF;
            END IF;
            entries := entries || JSONB_BUILD_OBJECT(identity,value);
        END LOOP;
        result := result || JSONB_BUILD_OBJECT(category,entries);
    END LOOP;
    RETURN result;
END;
$snapshot$;

CREATE OR REPLACE FUNCTION pg_temp.opal_contract_observe(contract JSONB) RETURNS JSONB
LANGUAGE plpgsql SECURITY INVOKER SET search_path = pg_catalog, pg_temp AS $observe$
DECLARE category TEXT; entry JSONB; identity TEXT; scope JSONB;
BEGIN
    PERFORM pg_temp.opal_contract_require(contract);
    IF NOT (contract ? 'observe') THEN RETURN '{}'::JSONB; END IF;
    scope := contract->'observe';
    IF contract->>'type' IS DISTINCT FROM 'data'
       OR JSONB_TYPEOF(scope) IS DISTINCT FROM 'object' THEN
        RAISE EXCEPTION 'Observations require a bounded data contract';
    END IF;
    IF (SELECT ARRAY_AGG(key ORDER BY key) FROM JSONB_OBJECT_KEYS(scope) key)
           IS DISTINCT FROM ARRAY['rows','sequences']::TEXT[]
       OR JSONB_TYPEOF(scope->'rows') IS DISTINCT FROM 'array'
       OR JSONB_TYPEOF(scope->'sequences') IS DISTINCT FROM 'array' THEN
        RAISE EXCEPTION 'Malformed data observation scope';
    END IF;
    IF JSONB_ARRAY_LENGTH(scope->'rows') + JSONB_ARRAY_LENGTH(scope->'sequences') = 0 THEN
        RAISE EXCEPTION 'Data observation scope must be nonempty';
    END IF;
    FOREACH category IN ARRAY ARRAY['rows','sequences'] LOOP
        IF (SELECT COUNT(*) <> COUNT(DISTINCT value) FROM JSONB_ARRAY_ELEMENTS(scope->category)) THEN
            RAISE EXCEPTION 'Duplicate data observation identity';
        END IF;
        FOR entry IN SELECT JSONB_ARRAY_ELEMENTS(scope->category) LOOP
            identity := entry #>> '{}';
            IF JSONB_TYPEOF(entry) IS DISTINCT FROM 'string'
               OR identity !~ '^[a-z_][a-z0-9_]*[.][a-z_][a-z0-9_]*$'
               OR SPLIT_PART(identity,'.',1) IN ('pg_catalog','information_schema')
               OR SPLIT_PART(identity,'.',1) LIKE 'pg_%'
               OR SPLIT_PART(identity,'.',1) LIKE 'opal_test_%'
               OR SPLIT_PART(identity,'.',2) = 'flyway_schema_history'
               OR (contract->'preserve'->category) ? identity THEN
                RAISE EXCEPTION 'Invalid or overlapping data observation identity';
            END IF;
        END LOOP;
    END LOOP;
    RETURN pg_temp.opal_contract_snapshot(JSONB_SET(contract,'{preserve}',JSONB_BUILD_OBJECT(
        'rows',scope->'rows','tables','[]'::JSONB,'routines','[]'::JSONB,
        'enums','[]'::JSONB,'sequences',scope->'sequences')));
END;
$observe$;

CREATE OR REPLACE FUNCTION pg_temp.opal_contract_changed_objects(contract JSONB) RETURNS JSONB
LANGUAGE plpgsql SECURITY INVOKER SET search_path = pg_catalog, pg_temp AS $changes$
DECLARE change TEXT; object JSONB; entries JSONB; result JSONB := '{}'::JSONB;
BEGIN
    PERFORM pg_temp.opal_contract_require(contract);
    FOREACH change IN ARRAY ARRAY['created','replaced'] LOOP
        entries := '{}'::JSONB;
        FOR object IN SELECT JSONB_ARRAY_ELEMENTS(contract->'objects'->change) LOOP
            entries := entries || JSONB_BUILD_OBJECT((object->>'kind')||':'||(object->>'identity'),
                pg_temp.opal_contract_object(object->>'kind',object->>'identity'));
        END LOOP;
        result := result || JSONB_BUILD_OBJECT(change,entries);
    END LOOP;
    RETURN result;
END;
$changes$;

CREATE OR REPLACE FUNCTION pg_temp.opal_contract_load(
    contract JSONB, expected_scenario TEXT, expected_candidate TEXT, expected_predecessor TEXT
) RETURNS JSONB
LANGUAGE plpgsql SECURITY INVOKER SET search_path = pg_catalog, pg_temp AS $load$
DECLARE observation JSONB;
BEGIN
    PERFORM pg_temp.opal_contract_require(contract);
    observation := pg_temp.opal_upgrade_load(expected_scenario,expected_candidate,expected_predecessor);
    IF observation->'contract' IS DISTINCT FROM contract THEN
        RAISE EXCEPTION 'Stored preservation contract provenance mismatch';
    END IF;
    RETURN observation;
END;
$load$;

CREATE OR REPLACE FUNCTION pg_temp.opal_contract_remove(
    contract JSONB, expected_scenario TEXT, expected_candidate TEXT, expected_predecessor TEXT
) RETURNS VOID
LANGUAGE plpgsql SECURITY INVOKER SET search_path = pg_catalog, pg_temp AS $remove$
BEGIN
    PERFORM pg_temp.opal_contract_load(contract,expected_scenario,expected_candidate,expected_predecessor);
    PERFORM pg_temp.opal_upgrade_remove(expected_scenario,expected_candidate,expected_predecessor);
END;
$remove$;
