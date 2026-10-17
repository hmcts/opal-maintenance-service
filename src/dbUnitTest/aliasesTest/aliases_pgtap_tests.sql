/**
 * OPAL Program
 *
 * MODULE      : aliases_pgtap_tests.sql
 *
 * DESCRIPTION : Verify current and historical corrected Aliases schema and integrity rules.
 *
 * CHANGE HISTORY:
 *
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * 03/10/2026  Chris Larkin  PO-10634      Initial pgTAP test suite.
 * 17/10/2026  Frankie Moran  aliases-schema-correction  Verify corrected names and structural upgrade.
 */

-- OPAL-DB-UPGRADE {"id":"aliases.names_correction","candidate":"ddl/V1_44__alter_aliases_name_columns.sql","scope":"both","data":"approved-synthetic","inputs":["src/main/resources/db/migration/ddl/V1_25__create_aliases_table.sql","src/main/resources/db/migration/ddl/V1_20__create_parties_table.sql","src/main/resources/db/migration/ddl/V1_2__create_countries_table.sql","src/main/resources/db/migration/ddl/V1_40__create_p_insert_parties_procedure.sql"],"contract":{"type":"data","objects":{"created":[],"replaced":[]},"preserve":{"rows":["public.aliases","public.parties","public.countries"],"tables":["public.parties","public.countries"],"routines":["public.p_insert_parties(json,public.t_party_account_type_enum)"],"enums":["public.t_party_account_type_enum"],"sequences":["public.alias_id_seq","public.party_id_seq","public.country_id_seq"]},"assertion":"aliases.corrected","custom":{"prepare":"src/dbUnitTest/upgradeCases/aliases_correction_prepare.sql","verify":"src/dbUnitTest/upgradeCases/aliases_correction_verify.sql"}}}
-- Approved data scenario: ALIASES-CORRECTION-SYNTHETIC-1; user-approved 17 October 2026.
-- Maintenance package aliases-schema-correction; related PO-10648.
-- Applicability: latest fresh and registered numerical-predecessor correction;
-- functional assertions roll back.
\set ON_ERROR_STOP 1
\if :{?opal_assertion_group}
\else
    \set opal_assertion_group aliases.current
\endif
SELECT :'opal_assertion_group' IN ('aliases.current','aliases.corrected') AS ac_valid_group \gset
\if :ac_valid_group
\else
    DO $group$ BEGIN RAISE EXCEPTION 'Unknown ALIASES assertion group'; END; $group$;
\endif

BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SET LOCAL search_path = public, pg_catalog;
SET LOCAL TIME ZONE 'UTC';
SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '5s';
SELECT plan(52);
DO $fixture$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.countries) THEN
        RAISE EXCEPTION 'Required Country reference data missing';
    END IF;
END
$fixture$;
CREATE TEMP TABLE cv_reference AS
    SELECT (SELECT min(country_id) FROM public.countries) AS country_id;
CREATE TEMP TABLE cv_subject (id bigint PRIMARY KEY);
CREATE TEMP TABLE cv_generated (id bigint);

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

-- -----------------------------------------------------------------------------
-- Scenario: Latest fresh and this historical correction share the corrected schema.
-- Setup: Read all reviewed alias relation/column/key/index/sequence properties.
-- Expected: Exactly10 catalogue assertions pass; no future helper is required.
-- -----------------------------------------------------------------------------
SELECT * FROM pg_temp.ac_catalogue(false,'character varying(80)');

CREATE TEMP TABLE cv_party AS
    WITH inserted AS (
        INSERT INTO public.parties (address_line_1, restrict_personal_information, country_id)
        SELECT 'Synthetic Address', false, country_id FROM cv_reference RETURNING party_id
    ) SELECT party_id FROM inserted;

-- ---------------------------------------------------------------------------
-- Scenario: A minimal alias references its own synthetic Party and receives a generated ID.
-- Setup:    Insert a personal alias using the generated Party key and identifier default.
-- Expected: The valid relationship and sequence default allow the row.
-- ---------------------------------------------------------------------------
SELECT lives_ok(
    $sql$WITH inserted AS (
        INSERT INTO public.aliases (party_id, surname, forenames, sequence_number)
        SELECT party_id, 'Synthetic', 'Alias', 1 FROM cv_party RETURNING alias_id
    ) INSERT INTO cv_subject SELECT alias_id FROM inserted$sql$,
    'minimal valid alias generates an identifier'
);
INSERT INTO cv_generated SELECT id FROM cv_subject;

-- -----------------------------------------------------------------------------
-- Scenario: Required identifiers remain mandatory while both personal names allow NULL.
-- Setup: Update only the captured test-owned alias; reset surname for the second name.
-- Expected: Native required-column failures persist and each name NULL is stored.
-- -----------------------------------------------------------------------------
SELECT throws_ok($sql$UPDATE public.aliases SET alias_id=NULL
    WHERE alias_id=(SELECT id FROM cv_subject)$sql$,
    '23502',NULL,'alias_id rejects NULL');
SELECT throws_ok($sql$UPDATE public.aliases SET party_id=NULL
    WHERE alias_id=(SELECT id FROM cv_subject)$sql$,
    '23502',NULL,'party_id rejects NULL');
SELECT lives_ok($sql$UPDATE public.aliases SET surname=NULL
    WHERE alias_id=(SELECT id FROM cv_subject)$sql$,'surname accepts NULL');
SELECT results_eq(
    $actual$SELECT party_id,surname::TEXT COLLATE "C",forenames::TEXT COLLATE "C"
      FROM public.aliases WHERE alias_id=(SELECT id FROM cv_subject)$actual$,
    $expected$SELECT party_id,NULL::TEXT COLLATE "C",'Alias'::TEXT COLLATE "C"
      FROM cv_party$expected$,
    'surname NULL persists without changing Party or forenames');
SELECT lives_ok($sql$UPDATE public.aliases SET surname='Synthetic',forenames=NULL
    WHERE alias_id=(SELECT id FROM cv_subject)$sql$,'forenames accepts NULL');
SELECT results_eq(
    $actual$SELECT party_id,surname::TEXT COLLATE "C",forenames::TEXT COLLATE "C"
      FROM public.aliases WHERE alias_id=(SELECT id FROM cv_subject)$actual$,
    $expected$SELECT party_id,'Synthetic'::TEXT COLLATE "C",NULL::TEXT COLLATE "C"
      FROM cv_party$expected$,
    'forenames NULL persists with surname independently restored');
SELECT throws_ok($sql$UPDATE public.aliases SET sequence_number=NULL
    WHERE alias_id=(SELECT id FROM cv_subject)$sql$,
    '23502',NULL,'sequence_number rejects NULL');
SELECT lives_ok($sql$UPDATE public.aliases SET organisation_name=NULL
    WHERE alias_id=(SELECT id FROM cv_subject)$sql$,'organisation_name remains nullable');

-- -----------------------------------------------------------------------------
-- Scenario: Individual physical widths stay50 and organisation capacity becomes80.
-- Setup: Assign exact boundary text and one-over non-space text to the owning row.
-- Expected: Full boundary values persist; over-width input raises native22001.
-- -----------------------------------------------------------------------------
SELECT lives_ok($sql$UPDATE public.aliases SET surname=REPEAT('x',50)
    WHERE alias_id=(SELECT id FROM cv_subject)$sql$,'surname accepts 50 characters');
SELECT throws_ok($sql$UPDATE public.aliases SET surname=REPEAT('x',51)
    WHERE alias_id=(SELECT id FROM cv_subject)$sql$,'22001',NULL,'surname rejects 51 characters');
SELECT lives_ok($sql$UPDATE public.aliases SET forenames=REPEAT('y',50)
    WHERE alias_id=(SELECT id FROM cv_subject)$sql$,'forenames accepts 50 characters');
SELECT throws_ok($sql$UPDATE public.aliases SET forenames=REPEAT('y',51)
    WHERE alias_id=(SELECT id FROM cv_subject)$sql$,'22001',NULL,'forenames rejects 51 characters');
SELECT lives_ok($sql$UPDATE public.aliases SET organisation_name=REPEAT('z',80)
    WHERE alias_id=(SELECT id FROM cv_subject)$sql$,'organisation_name accepts 80 characters');
SELECT results_eq(
    $actual$SELECT organisation_name::TEXT COLLATE "C",CHAR_LENGTH(organisation_name)
      FROM public.aliases WHERE alias_id=(SELECT id FROM cv_subject)$actual$,
    $expected$VALUES (REPEAT('z',80) COLLATE "C",80)$expected$,
    'all80 organisation characters are stored unchanged');
SELECT throws_ok($sql$UPDATE public.aliases SET organisation_name=REPEAT('z',81)
    WHERE alias_id=(SELECT id FROM cv_subject)$sql$,'22001',NULL,
    'organisation_name rejects 81 characters');

-- ---------------------------------------------------------------------------
-- Scenario: Identifier uniqueness and Party referential integrity are enforced.
-- Setup:    Prove the missing Party key is absent, then attempt duplicate ID and missing Party.
-- Expected: Duplicate ID fails with 23505 and missing Party fails with 23503.
-- ---------------------------------------------------------------------------
SELECT is((SELECT count(*) FROM public.parties WHERE party_id = -32061),
    0::bigint, 'missing Party fixture key is absent');
SELECT throws_ok(
    $sql$INSERT INTO public.aliases (alias_id, party_id, surname, forenames, sequence_number)
    SELECT (SELECT id FROM cv_subject), party_id, 'Synthetic', 'Duplicate', 2 FROM cv_party$sql$,
    '23505', NULL, 'duplicate alias identifier is rejected'
);
SELECT throws_ok(
    $sql$UPDATE public.aliases SET party_id = -32061
    WHERE alias_id = (SELECT id FROM cv_subject)$sql$,
    '23503', NULL, 'missing Party reference is rejected'
);

-- ---------------------------------------------------------------------------
-- Scenario: Deleting the referenced synthetic Party is protected by the alias FK.
-- Setup:    Attempt to delete the Party created only for this suite and its alias.
-- Expected: The declared Party relationship rejects the delete with 23503.
-- ---------------------------------------------------------------------------
SELECT throws_ok(
    $sql$DELETE FROM public.parties WHERE party_id = (SELECT party_id FROM cv_party)$sql$,
    '23503', NULL, 'referenced synthetic Party cannot be deleted'
);

-- ---------------------------------------------------------------------------
-- Scenario: Alias count and sequence ordering remain caller responsibilities.
-- Setup:    Create another sequence-1 alias and five more for the same synthetic Party.
-- Expected: Duplicate sequence values and seven aliases succeed without extra business rules.
-- ---------------------------------------------------------------------------
SELECT lives_ok(
    $sql$WITH inserted AS (
        INSERT INTO public.aliases (party_id, surname, forenames, sequence_number)
        SELECT party_id, 'Synthetic', 'Second alias', 1 FROM cv_party RETURNING alias_id
    ) INSERT INTO cv_generated SELECT alias_id FROM inserted$sql$,
    'duplicate sequence_number is accepted and generates another identifier'
);
SELECT lives_ok(
    $sql$INSERT INTO public.aliases (party_id, surname, forenames, sequence_number)
    SELECT p.party_id, 'Synthetic', 'Additional alias', 1
    FROM cv_party p CROSS JOIN generate_series(1, 5)$sql$,
    'more than five aliases for one Party are accepted'
);
SELECT is((SELECT count(*) FROM public.aliases WHERE party_id = (SELECT party_id FROM cv_party)),
    7::bigint, 'all seven test-owned aliases persist with duplicate sequence numbers');
SELECT lives_ok(
    $sql$UPDATE public.aliases SET sequence_number = -1
    WHERE alias_id = (SELECT id FROM cv_subject)$sql$,
    'sequence_number has no invented positivity or ordering CHECK'
);
SELECT lives_ok(
    $sql$UPDATE public.aliases SET organisation_name = 'Synthetic organisation'
    WHERE alias_id = (SELECT id FROM cv_subject)$sql$,
    'organisation_name may coexist with personal names'
);
SELECT ok((SELECT bool_and(id IS NOT NULL) FROM cv_generated),
    'captured sequence-generated alias identifiers are non-null');
SELECT is((SELECT count(DISTINCT id) FROM cv_generated),
    2::bigint, 'separate successful alias inserts generate distinct identifiers');
-- -----------------------------------------------------------------------------
-- Scenario: The relaxed table stores organisation-only and incomplete physical shapes.
-- Setup: Change only the captured alias after all existing integrity/count assertions.
-- Expected: NULLs persist exactly; no new table-wide business shape rule appears.
-- -----------------------------------------------------------------------------
SELECT lives_ok($sql$UPDATE public.aliases
    SET surname=NULL,forenames=NULL,organisation_name='Synthetic Organisation'
    WHERE alias_id=(SELECT id FROM cv_subject)$sql$,'organisation-only physical row succeeds');
SELECT results_eq(
    $actual$SELECT party_id,surname::TEXT COLLATE "C",forenames::TEXT COLLATE "C",
        organisation_name::TEXT COLLATE "C" FROM public.aliases
      WHERE alias_id=(SELECT id FROM cv_subject)$actual$,
    $expected$SELECT party_id,NULL::TEXT COLLATE "C",NULL::TEXT COLLATE "C",
        'Synthetic Organisation'::TEXT COLLATE "C" FROM cv_party$expected$,
    'organisation-only row stores SQL NULL personal names and correct Party');
SELECT lives_ok($sql$UPDATE public.aliases
    SET surname=NULL,forenames=NULL,organisation_name=NULL
    WHERE alias_id=(SELECT id FROM cv_subject)$sql$,'all-name-NULL physical row remains permitted');
SELECT results_eq(
    $actual$SELECT surname::TEXT,forenames::TEXT,organisation_name::TEXT FROM public.aliases
      WHERE alias_id=(SELECT id FROM cv_subject)$actual$,
    $expected$VALUES (NULL::TEXT,NULL::TEXT,NULL::TEXT)$expected$,
    'all-name-NULL state is stored without filler');
SELECT lives_ok($sql$UPDATE public.aliases
    SET surname='Synthetic',forenames=NULL,organisation_name=NULL
    WHERE alias_id=(SELECT id FROM cv_subject)$sql$,'partial physical name remains permitted');
SELECT results_eq(
    $actual$SELECT surname::TEXT COLLATE "C",forenames::TEXT,organisation_name::TEXT
      FROM public.aliases WHERE alias_id=(SELECT id FROM cv_subject)$actual$,
    $expected$VALUES ('Synthetic'::TEXT COLLATE "C",NULL::TEXT,NULL::TEXT)$expected$,
    'partial name readback proves no new shape CHECK');

-- -----------------------------------------------------------------------------
-- Scenario: Physical character limits preserve multibyte and supplementary text.
-- Setup: Assign50 personal characters and80 organisation characters, then one over.
-- Expected: Full text/character lengths persist; native22001 rejects51/81 characters.
-- -----------------------------------------------------------------------------
SELECT lives_ok($sql$UPDATE public.aliases
    SET surname=REPEAT(U&'\00E9',50),
        forenames=REPEAT(U&'\+01F600',50),
        organisation_name=REPEAT(U&'\00E9',40)||REPEAT(U&'\+01F600',40)
    WHERE alias_id=(SELECT id FROM cv_subject)$sql$,'multibyte physical boundary text succeeds');
SELECT results_eq(
    $actual$SELECT surname::TEXT COLLATE "C",forenames::TEXT COLLATE "C",
        organisation_name::TEXT COLLATE "C",CHAR_LENGTH(surname),CHAR_LENGTH(forenames),
        CHAR_LENGTH(organisation_name) FROM public.aliases
      WHERE alias_id=(SELECT id FROM cv_subject)$actual$,
    $expected$VALUES (REPEAT(U&'\00E9',50) COLLATE "C",REPEAT(U&'\+01F600',50) COLLATE "C",
        (REPEAT(U&'\00E9',40)||REPEAT(U&'\+01F600',40)) COLLATE "C",50,50,80)$expected$,
    'complete multibyte text and character lengths are unchanged');
SELECT throws_ok($sql$UPDATE public.aliases SET organisation_name=REPEAT(U&'\+01F600',81)
    WHERE alias_id=(SELECT id FROM cv_subject)$sql$,'22001',NULL,'multibyte organisation81 fails');
SELECT throws_ok($sql$UPDATE public.aliases SET surname=REPEAT(U&'\00E9',51)
    WHERE alias_id=(SELECT id FROM cv_subject)$sql$,'22001',NULL,'multibyte surname51 fails');
SELECT throws_ok($sql$UPDATE public.aliases SET forenames=REPEAT(U&'\+01F600',51)
    WHERE alias_id=(SELECT id FROM cv_subject)$sql$,'22001',NULL,'supplementary forenames51 fails');

-- -----------------------------------------------------------------------------
-- Scenario: Accepted storage performs neither trimming nor Unicode normalization.
-- Setup: Assign exact padded text, then composed/supplementary/decomposed literals.
-- Expected: Independent full-text comparisons retain every supplied character.
-- -----------------------------------------------------------------------------
SELECT lives_ok($sql$UPDATE public.aliases
    SET surname=' Padded ',forenames='Synthetic ',organisation_name='  Synthetic Organisation  '
    WHERE alias_id=(SELECT id FROM cv_subject)$sql$,'padded text succeeds unchanged');
SELECT results_eq(
    $actual$SELECT surname::TEXT COLLATE "C",forenames::TEXT COLLATE "C",
        organisation_name::TEXT COLLATE "C" FROM public.aliases
      WHERE alias_id=(SELECT id FROM cv_subject)$actual$,
    $expected$VALUES (' Padded '::TEXT COLLATE "C",'Synthetic '::TEXT COLLATE "C",
        '  Synthetic Organisation  '::TEXT COLLATE "C")$expected$,
    'padding is stored without trimming');
SELECT lives_ok($sql$UPDATE public.aliases
    SET surname=U&'\00E9',forenames=U&'\+01F600e\0301',organisation_name=E'\tSynthetic text'
    WHERE alias_id=(SELECT id FROM cv_subject)$sql$,'supplementary and decomposed text succeeds');
SELECT results_eq(
    $actual$SELECT surname::TEXT COLLATE "C",forenames::TEXT COLLATE "C",
        organisation_name::TEXT COLLATE "C" FROM public.aliases
      WHERE alias_id=(SELECT id FROM cv_subject)$actual$,
    $expected$VALUES (U&'\00E9'::TEXT COLLATE "C",U&'\+01F600e\0301'::TEXT COLLATE "C",
        E'\tSynthetic text'::TEXT COLLATE "C")$expected$,
    'composed, supplementary and decomposed strings remain exact');
SELECT * FROM finish();
ROLLBACK;
