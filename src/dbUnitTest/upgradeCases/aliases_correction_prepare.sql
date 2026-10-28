/**
 * OPAL Program
 *
 * MODULE      : aliases_correction_prepare.sql
 *
 * DESCRIPTION : Verify predecessor schema and prepare approved synthetic aliases.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket                     Nature of Change
 * ----------  -------------  -------------------------  ----------------------------------------
 * 17/10/2026  Frankie Moran  PO-10648                   Initial correction delivery.
 */

-- Approved data scenario: ALIASES-CORRECTION-SYNTHETIC-1; user-approved 17 October 2026.
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
        RAISE EXCEPTION 'ALIASES custom preparation requires its disposable harness target';
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

SELECT plan(26);

-- -----------------------------------------------------------------------------
-- Scenario: The actual predecessor retains required personal names and width50.
-- Setup: Read the complete reviewed catalogue before creating approved test rows.
-- Expected: All10 independent predecessor catalogue assertions pass.
-- -----------------------------------------------------------------------------
SELECT * FROM pg_temp.ac_catalogue(true,'character varying(50)');

CREATE TEMP TABLE ac_preparation_sequence_state ON COMMIT DROP AS
SELECT JSONB_BUILD_ARRAY(
    (SELECT JSONB_BUILD_ARRAY(last_value,is_called) FROM public.alias_id_seq),
    (SELECT JSONB_BUILD_ARRAY(last_value,is_called) FROM public.party_id_seq),
    (SELECT JSONB_BUILD_ARRAY(last_value,is_called) FROM public.country_id_seq)
) AS value;

-- -----------------------------------------------------------------------------
-- Scenario: Only the approved deterministic existing-row shapes are prepared.
-- Setup: Fail on occupied explicit Country/CJS, Party or alias identifiers.
-- Expected: One Country, two Parties and exact A1-A7 rows use no sequence default.
-- -----------------------------------------------------------------------------
DO $guard$
BEGIN
    IF EXISTS (SELECT 1 FROM public.countries
               WHERE country_id=-32501 OR cjs_code=-32501)
       OR EXISTS (SELECT 1 FROM public.parties WHERE party_id IN (-32511,-32512))
       OR EXISTS (SELECT 1 FROM public.aliases WHERE alias_id BETWEEN -32527 AND -32521) THEN
        RAISE EXCEPTION 'ALIASES correction synthetic identifiers are occupied';
    END IF;
END;
$guard$;

INSERT INTO public.countries (
    country_id,
    cjs_code,
    international_code,
    gov_code,
    country_name,
    date_used_from,
    active
) VALUES (
    -32501,
    -32501,
    NULL,
    NULL,
    'Aliases correction synthetic Country',
    DATE '2026-01-01',
    true
);
INSERT INTO public.parties (
    party_id,
    organisation,
    surname,
    forenames,
    address_line_1,
    restrict_personal_information,
    country_id,
    account_type
) VALUES (
    -32511,
    false,
    'Synthetic',
    'First',
    'Synthetic correction address 1',
    false,
    -32501,
    'Respondent'
), (
    -32512,
    false,
    'Synthetic',
    'Second',
    'Synthetic correction address 2',
    false,
    -32501,
    'Respondent'
);
INSERT INTO public.aliases (
    alias_id,
    party_id,
    surname,
    forenames,
    organisation_name,
    sequence_number
) VALUES (
    -32521,
    -32511,
    'Synthetic',
    'Alias',
    NULL,
    1
), (
    -32522,
    -32511,
    REPEAT('x',50),
    REPEAT('y',50),
    REPEAT('z',50),
    1
), (
    -32523,
    -32511,
    'Both',
    'Names',
    'Synthetic Organisation',
    -1
), (
    -32524,
    -32511,
    '',
    '',
    '',
    0
), (
    -32525,
    -32511,
    ' Padded ',
    'Synthetic ',
    NULL,
    5
), (
    -32526,
    -32511,
    U&'\00E9',
    U&'\+01F600e\0301',
    E'\tSynthetic text',
    9
), (
    -32527,
    -32512,
    'Second',
    'Party',
    NULL,
    1
);
SELECT is((SELECT COUNT(*) FROM public.countries
           WHERE country_id=-32501 AND cjs_code=-32501),1::BIGINT,
          'one explicit synthetic Country');
SELECT is((SELECT COUNT(*) FROM public.parties
           WHERE party_id IN (-32511,-32512) AND country_id=-32501),2::BIGINT,
          'two explicit synthetic Parties');
SELECT is((SELECT COUNT(*) FROM public.aliases
           WHERE alias_id BETWEEN -32527 AND -32521),7::BIGINT,
          'seven explicit predecessor aliases');
SELECT is((SELECT COUNT(*) FROM public.aliases WHERE party_id=-32511),6::BIGINT,
          'first Party retains six predecessor-permitted aliases');
SELECT is((SELECT COUNT(*) FROM public.aliases WHERE party_id=-32512),1::BIGINT,
          'second Party has its independent alias');
SELECT results_eq(
    $actual$SELECT alias_id,party_id,surname::TEXT COLLATE "C",forenames::TEXT COLLATE "C",
        organisation_name::TEXT COLLATE "C",sequence_number
      FROM public.aliases WHERE alias_id BETWEEN -32527 AND -32521 ORDER BY alias_id DESC$actual$,
    $expected$VALUES
      (-32521::BIGINT,-32511::BIGINT,'Synthetic'::TEXT COLLATE "C",
       'Alias'::TEXT COLLATE "C",NULL::TEXT COLLATE "C",1),
      (-32522::BIGINT,-32511::BIGINT,REPEAT('x',50) COLLATE "C",
       REPEAT('y',50) COLLATE "C",REPEAT('z',50) COLLATE "C",1),
      (-32523::BIGINT,-32511::BIGINT,'Both'::TEXT COLLATE "C",
       'Names'::TEXT COLLATE "C",'Synthetic Organisation'::TEXT COLLATE "C",-1),
      (-32524::BIGINT,-32511::BIGINT,''::TEXT COLLATE "C",
       ''::TEXT COLLATE "C",''::TEXT COLLATE "C",0),
      (-32525::BIGINT,-32511::BIGINT,' Padded '::TEXT COLLATE "C",
       'Synthetic '::TEXT COLLATE "C",NULL::TEXT COLLATE "C",5),
      (-32526::BIGINT,-32511::BIGINT,U&'\00E9'::TEXT COLLATE "C",
       U&'\+01F600e\0301'::TEXT COLLATE "C",E'\tSynthetic text'::TEXT COLLATE "C",9),
      (-32527::BIGINT,-32512::BIGINT,'Second'::TEXT COLLATE "C",
       'Party'::TEXT COLLATE "C",NULL::TEXT COLLATE "C",1)$expected$,
    'approved A1-A7 predecessor rows are exact');

-- -----------------------------------------------------------------------------
-- Scenario: P native NULL/50-character boundaries reject only invalid assignments.
-- Setup: Update existing A2; successful probes assign its unchanged approved text.
-- Expected: 23502/22001 remain native; no probe consumes a generated identifier.
-- -----------------------------------------------------------------------------
SELECT throws_ok($sql$UPDATE public.aliases SET surname=NULL WHERE alias_id=-32522$sql$,
    '23502',NULL,'P requires surname');
SELECT throws_ok($sql$UPDATE public.aliases SET forenames=NULL WHERE alias_id=-32522$sql$,
    '23502',NULL,'P requires forenames');
SELECT lives_ok($sql$UPDATE public.aliases SET surname=REPEAT('x',50)
    WHERE alias_id=-32522$sql$,'P accepts surname50');
SELECT throws_ok($sql$UPDATE public.aliases SET surname=REPEAT('x',51)
    WHERE alias_id=-32522$sql$,'22001',NULL,'P rejects surname51');
SELECT lives_ok($sql$UPDATE public.aliases SET forenames=REPEAT('y',50)
    WHERE alias_id=-32522$sql$,'P accepts forenames50');
SELECT throws_ok($sql$UPDATE public.aliases SET forenames=REPEAT('y',51)
    WHERE alias_id=-32522$sql$,'22001',NULL,'P rejects forenames51');
SELECT lives_ok($sql$UPDATE public.aliases SET organisation_name=REPEAT('z',50)
    WHERE alias_id=-32522$sql$,'P accepts organisation50');
SELECT throws_ok($sql$UPDATE public.aliases SET organisation_name=REPEAT('z',51)
    WHERE alias_id=-32522$sql$,'22001',NULL,'P rejects organisation51');
SELECT results_eq(
    $actual$SELECT surname::TEXT COLLATE "C",forenames::TEXT COLLATE "C",
        organisation_name::TEXT COLLATE "C" FROM public.aliases WHERE alias_id=-32522$actual$,
    $expected$VALUES (REPEAT('x',50) COLLATE "C",REPEAT('y',50) COLLATE "C",
        REPEAT('z',50) COLLATE "C")$expected$,
    'P native probes preserve A2 exactly');
SELECT is(JSONB_BUILD_ARRAY(
    (SELECT JSONB_BUILD_ARRAY(last_value,is_called) FROM public.alias_id_seq),
    (SELECT JSONB_BUILD_ARRAY(last_value,is_called) FROM public.party_id_seq),
    (SELECT JSONB_BUILD_ARRAY(last_value,is_called) FROM public.country_id_seq)),
    (SELECT value FROM pg_temp.ac_preparation_sequence_state),
    'approved preparation leaves all three sequence states unchanged');
SELECT * FROM finish();
COMMIT;
