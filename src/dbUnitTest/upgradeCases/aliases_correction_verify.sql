/**
 * OPAL Program
 *
 * MODULE      : aliases_correction_verify.sql
 *
 * DESCRIPTION : Verify corrected ALIASES catalogue before functional mutations.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket                     Nature of Change
 * ----------  -------------  -------------------------  ----------------------------------------
 * 17/10/2026  Frankie Moran  aliases-schema-correction  Initial correction delivery.
 * 22/10/2026  Frankie Moran  PO-10655      Port reviewed coverage to the Stage 3 migration lineage.
 */

\set ON_ERROR_STOP 1
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SET LOCAL search_path = public, pg_catalog;
SET LOCAL TIME ZONE 'UTC';
SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '5s';
DO $target$
BEGIN
    IF CURRENT_DATABASE()<>'opal_maintenance_db_unit_test' OR CURRENT_USER<>'postgres' THEN
        RAISE EXCEPTION 'ALIASES custom verification requires its disposable harness target';
    END IF;
END;
$target$;

CREATE FUNCTION pg_temp.ac_catalogue(
    p_person_notnull BOOLEAN,
    p_organisation_type TEXT
) RETURNS SETOF TEXT
LANGUAGE plpgsql
AS $catalogue$
BEGIN
    RETURN QUERY SELECT is(
        (SELECT JSONB_BUILD_ARRAY(n.nspname::TEXT,r.relname::TEXT,r.relkind::TEXT,
            PG_GET_USERBYID(r.relowner),r.relacl::TEXT,r.reloptions::TEXT,r.relpersistence::TEXT,
            r.relrowsecurity,r.relforcerowsecurity,r.relreplident::TEXT,r.relispartition,
            OBJ_DESCRIPTION(r.oid,'pg_class'))
         FROM pg_class r JOIN pg_namespace n ON n.oid=r.relnamespace
         WHERE r.oid='public.aliases'::REGCLASS),
        JSONB_BUILD_ARRAY('public','aliases','r',CURRENT_USER::TEXT,NULL::TEXT,NULL::TEXT,
            'p',false,false,'d',false,NULL::TEXT),
        'exact alias relation ownership, ACL, options, persistence, RLS and comment');

    RETURN QUERY SELECT is(
        (SELECT JSONB_AGG(JSONB_BUILD_ARRAY(a.attnum,a.attname::TEXT,
            FORMAT_TYPE(a.atttypid,a.atttypmod),a.attnotnull,a.attidentity::TEXT,
            a.attgenerated::TEXT,a.attcollation=CASE
                WHEN a.atttypid='pg_catalog.varchar'::REGTYPE
                THEN 'pg_catalog."default"'::REGCOLLATION::OID ELSE 0::OID END,
            a.attacl::TEXT,PG_GET_EXPR(d.adbin,d.adrelid),COL_DESCRIPTION(a.attrelid,a.attnum))
            ORDER BY a.attnum)
         FROM pg_attribute a LEFT JOIN pg_attrdef d
           ON d.adrelid=a.attrelid AND d.adnum=a.attnum
         WHERE a.attrelid='public.aliases'::REGCLASS AND a.attnum>0 AND NOT a.attisdropped),
        JSONB_BUILD_ARRAY(
            JSONB_BUILD_ARRAY(1,'alias_id','bigint',true,'','',true,NULL::TEXT,
                'nextval(''alias_id_seq''::regclass)','Unique identifier of the alias'),
            JSONB_BUILD_ARRAY(2,'party_id','bigint',true,'','',true,NULL::TEXT,NULL::TEXT,
                'Identifier of the party owning the alias'),
            JSONB_BUILD_ARRAY(3,'surname','character varying(50)',p_person_notnull,'','',
                true,NULL::TEXT,NULL::TEXT,'Alias surname'),
            JSONB_BUILD_ARRAY(4,'forenames','character varying(50)',p_person_notnull,'','',
                true,NULL::TEXT,NULL::TEXT,'Alias forenames'),
            JSONB_BUILD_ARRAY(5,'organisation_name',p_organisation_type,false,'','',
                true,NULL::TEXT,NULL::TEXT,'Alias organisation name'),
            JSONB_BUILD_ARRAY(6,'sequence_number','integer',true,'','',true,NULL::TEXT,NULL::TEXT,
                'Sequence of the alias within its party')),
        'exact ordered alias columns, widths, nullability, defaults, collation, ACL and comments');

    RETURN QUERY SELECT is(
        (SELECT JSONB_AGG(JSONB_BUILD_ARRAY(c.conname::TEXT,c.contype::TEXT,
            ARRAY(SELECT a.attname::TEXT FROM UNNEST(c.conkey) WITH ORDINALITY k(attnum,position)
                JOIN pg_attribute a ON a.attrelid=c.conrelid AND a.attnum=k.attnum
                ORDER BY k.position),
            c.convalidated,c.condeferrable,c.condeferred,PG_GET_CONSTRAINTDEF(c.oid,false))
            ORDER BY c.conname COLLATE "C")
         FROM pg_constraint c WHERE c.conrelid='public.aliases'::REGCLASS),
        JSONB_BUILD_ARRAY(
            JSONB_BUILD_ARRAY('aliases_pk','p',ARRAY['alias_id'],true,false,false,
                'PRIMARY KEY (alias_id)'),
            JSONB_BUILD_ARRAY('als_party_id_fk','f',ARRAY['party_id'],true,false,false,
                'FOREIGN KEY (party_id) REFERENCES parties(party_id)')),
        'exact alias constraints and definitions; no extra CHECK or uniqueness');

    RETURN QUERY SELECT is(
        (SELECT JSONB_AGG(JSONB_BUILD_ARRAY(c.conname::TEXT,n.nspname::TEXT,r.relname::TEXT,
            ARRAY(SELECT a.attname::TEXT FROM UNNEST(c.confkey) WITH ORDINALITY k(attnum,position)
                JOIN pg_attribute a ON a.attrelid=c.confrelid AND a.attnum=k.attnum
                ORDER BY k.position),
            c.confupdtype::TEXT,c.confdeltype::TEXT,c.confmatchtype::TEXT,
            c.convalidated,c.condeferrable,c.condeferred) ORDER BY c.conname COLLATE "C")
         FROM pg_constraint c JOIN pg_class r ON r.oid=c.confrelid
         JOIN pg_namespace n ON n.oid=r.relnamespace
         WHERE c.conrelid='public.aliases'::REGCLASS AND c.contype='f'),
        JSONB_BUILD_ARRAY(JSONB_BUILD_ARRAY('als_party_id_fk','public','parties',
            ARRAY['party_id'],'a','a','s',true,false,false)),
        'exact immediate validated NO ACTION Party relationship');

    RETURN QUERY SELECT is(
        (SELECT JSONB_AGG(JSONB_BUILD_ARRAY(n.nspname::TEXT,r.relname::TEXT,
            ARRAY(SELECT a.attname::TEXT FROM UNNEST(i.indkey) WITH ORDINALITY k(attnum,position)
                JOIN pg_attribute a ON a.attrelid=i.indrelid AND a.attnum=k.attnum
                ORDER BY k.position),
            am.amname::TEXT,i.indisunique,i.indisprimary,i.indisvalid,i.indisready,i.indislive,
            i.indnkeyatts::INTEGER,i.indnatts::INTEGER,i.indpred IS NULL,i.indexprs IS NULL,
            PG_GET_INDEXDEF(i.indexrelid),PG_GET_USERBYID(r.relowner),r.relacl::TEXT,
            r.reloptions::TEXT,OBJ_DESCRIPTION(r.oid,'pg_class')) ORDER BY r.relname COLLATE "C")
         FROM pg_index i JOIN pg_class r ON r.oid=i.indexrelid
         JOIN pg_namespace n ON n.oid=r.relnamespace JOIN pg_am am ON am.oid=r.relam
         WHERE i.indrelid='public.aliases'::REGCLASS),
        JSONB_BUILD_ARRAY(
            JSONB_BUILD_ARRAY('public','aliases_party_id_idx',ARRAY['party_id'],'btree',
                false,false,true,true,true,1,1,true,true,
                'CREATE INDEX aliases_party_id_idx ON public.aliases USING btree (party_id)',
                CURRENT_USER::TEXT,NULL::TEXT,NULL::TEXT,NULL::TEXT),
            JSONB_BUILD_ARRAY('public','aliases_pk',ARRAY['alias_id'],'btree',
                true,true,true,true,true,1,1,true,true,
                'CREATE UNIQUE INDEX aliases_pk ON public.aliases USING btree (alias_id)',
                CURRENT_USER::TEXT,NULL::TEXT,NULL::TEXT,NULL::TEXT)),
        'exact alias index definitions, ownership, ACL and ready btree properties');

    RETURN QUERY SELECT is(
        (SELECT JSONB_BUILD_ARRAY(s.seqtypid::REGTYPE::TEXT,s.seqstart,s.seqincrement,
            s.seqmin,s.seqmax,s.seqcache,s.seqcycle,r.relkind::TEXT,PG_GET_USERBYID(r.relowner),
            r.relacl::TEXT,r.reloptions::TEXT,OBJ_DESCRIPTION(r.oid,'pg_class'))
         FROM pg_sequence s JOIN pg_class r ON r.oid=s.seqrelid
         WHERE s.seqrelid='public.alias_id_seq'::REGCLASS),
        JSONB_BUILD_ARRAY('bigint',1::BIGINT,1::BIGINT,1::BIGINT,
            9223372036854775807::BIGINT,1::BIGINT,false,'S',CURRENT_USER::TEXT,
            NULL::TEXT,NULL::TEXT,NULL::TEXT),
        'exact alias sequence definition, ownership role, ACL and options');

    RETURN QUERY SELECT is(PG_GET_SERIAL_SEQUENCE('public.aliases','alias_id'),
        'public.alias_id_seq','alias identifier owns the existing sequence');

    RETURN QUERY SELECT is(
        (SELECT JSONB_AGG(JSONB_BUILD_ARRAY(n.nspname::TEXT,r.relname::TEXT,a.attname::TEXT,
            d.deptype::TEXT) ORDER BY d.refobjid,d.refobjsubid,d.deptype)
         FROM pg_depend d JOIN pg_class r ON r.oid=d.refobjid
         JOIN pg_namespace n ON n.oid=r.relnamespace
         JOIN pg_attribute a ON a.attrelid=d.refobjid AND a.attnum=d.refobjsubid
         WHERE d.classid='pg_class'::REGCLASS AND d.objid='public.alias_id_seq'::REGCLASS
           AND d.refclassid='pg_class'::REGCLASS),
        JSONB_BUILD_ARRAY(JSONB_BUILD_ARRAY('public','aliases','alias_id','a')),
        'exact sequence OWNED BY dependency');

    RETURN QUERY SELECT is((SELECT COUNT(*) FROM pg_trigger
        WHERE tgrelid='public.aliases'::REGCLASS AND NOT tgisinternal),0::BIGINT,
        'no alias user triggers');
    RETURN QUERY SELECT is((SELECT COUNT(*) FROM pg_policy
        WHERE polrelid='public.aliases'::REGCLASS),0::BIGINT,'no alias RLS policies');
END;
$catalogue$;

SELECT plan(10);
-- -----------------------------------------------------------------------------
-- Scenario: Only the three approved ALIASES column properties change at C.
-- Setup: Native C migration/validation and shared row/sequence preservation passed.
-- Expected: Exact corrected catalogue passes before owning functional mutations.
-- -----------------------------------------------------------------------------
SELECT * FROM pg_temp.ac_catalogue(false,'character varying(80)');
SELECT * FROM finish();
ROLLBACK;
