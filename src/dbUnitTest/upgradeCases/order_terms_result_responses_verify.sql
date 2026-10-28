/**
 * OPAL Program
 *
 * MODULE      : order_terms_result_responses_verify.sql
 *
 * DESCRIPTION : Verify exact original-row preservation and the approved response schema expansion.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket        Nature of Change
 * ----------  -------------  ------------  ----------------------------------------
 * 17/10/2026  Frankie Moran  PO-10646      Verify the approved S10 structural transition.
 */

\set ON_ERROR_STOP 1
\set ot_bu_id 32070
\set ot_bu_code OT46
\set ot_result_id OTRR46
\set ot_respondent_id -604601
\set ot_creditor_id -604602
\set ot_min_id -604603
\set ot_full_id -604604

-- -----------------------------------------------------------------------------
-- Scenario: The approved transition runs only on its disposable target.
-- Setup: The maintained runner supplies the real P1.61 or C1.62 phase and PostgreSQL role.
-- Expected: UTC/ISO observations, bounded statements and exactly 12 assertions per case.
-- -----------------------------------------------------------------------------
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SET LOCAL search_path=public,pg_catalog;
SET LOCAL TIME ZONE 'UTC';
SET LOCAL DateStyle='ISO, YMD';
SET LOCAL statement_timeout='30s';
DO $guard$ BEGIN
    IF CURRENT_DATABASE()<>'opal_maintenance_db_unit_test' OR CURRENT_USER<>'postgres' THEN
        RAISE EXCEPTION 'Order Terms transition requires its disposable database and role';
    END IF;
END; $guard$;
SELECT :'opal_phase'='prepare' AS ot_prepare, :'opal_phase'='verify' AS ot_verify \gset
SELECT plan(12);

-- -----------------------------------------------------------------------------
-- Scenario: Independent literals define every original row and catalogue property.
-- Setup: Recreate phase-local TEMP expectations from the approved V1_29 contract.
-- Expected: The oracle is independent of migrated business rows and is never transported.
-- -----------------------------------------------------------------------------
CREATE TEMP TABLE ot_expected_rows AS
SELECT * FROM (VALUES
(:ot_min_id::BIGINT,:ot_respondent_id::BIGINT,:ot_creditor_id::BIGINT,:'ot_result_id'::VARCHAR(6),
 TIMESTAMP '2026-01-02 03:04:05.123456',NULL::VARCHAR(20),NULL::VARCHAR(100),NULL::TIMESTAMP,
 TIMESTAMP '2025-12-31 23:59:58.654321',12.34::NUMERIC,NULL::NUMERIC,FALSE,
 NULL::VARCHAR(100),NULL::TIMESTAMP,NULL::TIMESTAMP,NULL::BOOLEAN,NULL::NUMERIC),
(:ot_full_id::BIGINT,:ot_respondent_id::BIGINT,:ot_creditor_id::BIGINT,:'ot_result_id'::VARCHAR(6),
 TIMESTAMP '2026-06-07 08:09:10.234567','Synthetic author','Synthetic schema owner',
 TIMESTAMP '2025-01-02 03:04:05.345678',TIMESTAMP '2024-02-29 12:13:14.456789',
 9999999999.99::NUMERIC,123456.78::NUMERIC,TRUE,'Synthetic child',
 TIMESTAMP '2012-02-29 01:02:03.567890',TIMESTAMP '2030-12-31 23:59:59.678901',FALSE,9876.54::NUMERIC)
) expected(order_terms_id,respondent_account_id,creditor_account_id,result_id,
    posted_date,posted_by,posted_by_name,original_posted_date,imposed_date,imposed_amount,
    arrears_amount,completed,child_name,child_birth_date,expiry_date,expiry_terms,remitted_amount);

CREATE TEMP TABLE ot_expected_columns(
    position SMALLINT,name TEXT,type TEXT,required BOOLEAN,default_expression TEXT,comment TEXT);
INSERT INTO ot_expected_columns (
    position,
    name,
    type,
    required,
    default_expression,
    comment
) VALUES
    (
        1,
        'order_terms_id',
        'bigint',
        TRUE,
        'nextval(''order_terms_id_seq''::regclass)',
        'Unique identifier of the Order Terms'
    ),
    (
        2,
        'respondent_account_id',
        'bigint',
        TRUE,
        NULL,
        'Identifier of the related Respondent Account'
    ),
    (
        3,
        'creditor_account_id',
        'bigint',
        TRUE,
        NULL,
        'Identifier of the Creditor Account receiving allocated payments'
    ),
    (
        4,
        'result_id',
        'character varying(6)',
        TRUE,
        NULL,
        'Identifier of the court result defining the order-term type'
    ),
    (
        5,
        'posted_date',
        'timestamp without time zone',
        TRUE,
        NULL,
        'Date the order term was posted'
    ),
    (
        6,
        'posted_by',
        'character varying(20)',
        FALSE,
        NULL,
        'Identifier of the posting user'
    ),
    (
        7,
        'posted_by_name',
        'character varying(100)',
        FALSE,
        NULL,
        'Display name of the posting user'
    ),
    (
        8,
        'original_posted_date',
        'timestamp without time zone',
        FALSE,
        NULL,
        'Original posting date where the order term duplicates a written-off legacy imposition'
    ),
    (
        9,
        'imposed_date',
        'timestamp without time zone',
        TRUE,
        NULL,
        'Date the maintenance order was imposed'
    ),
    (
        10,
        'imposed_amount',
        'numeric',
        TRUE,
        NULL,
        'Amount imposed by the court'
    ),
    (
        11,
        'arrears_amount',
        'numeric',
        FALSE,
        NULL,
        'Arrears amount for the order term'
    ),
    (
        12,
        'completed',
        'boolean',
        TRUE,
        NULL,
        'Whether the order term has been paid in full'
    ),
    (
        13,
        'child_name',
        'character varying(100)',
        FALSE,
        NULL,
        'Child name for the payable maintenance component'
    ),
    (
        14,
        'child_birth_date',
        'timestamp without time zone',
        FALSE,
        NULL,
        'Child birth date for the payable maintenance component'
    ),
    (
        15,
        'expiry_date',
        'timestamp without time zone',
        FALSE,
        NULL,
        'Expiry date of the payable maintenance component'
    ),
    (
        16,
        'expiry_terms',
        'boolean',
        FALSE,
        NULL,
        'Whether further-education expiry terms apply'
    ),
    (
        17,
        'remitted_amount',
        'numeric',
        FALSE,
        NULL,
        'Remitted arrears or order-term amount; null until a remittance is recorded'
    );
CREATE TEMP TABLE ot_expected_constraints(
    name TEXT,kind TEXT,definition TEXT,validated BOOLEAN,deferrable_flag BOOLEAN,deferred_flag BOOLEAN);
INSERT INTO ot_expected_constraints (
    name,
    kind,
    definition,
    validated,
    deferrable_flag,
    deferred_flag
) VALUES
    (
        'order_terms_pk',
        'p',
        'PRIMARY KEY (order_terms_id)',
        TRUE,
        FALSE,
        FALSE
    ),
    (
        'ot_creditor_account_id_fk',
        'f',
        'FOREIGN KEY (creditor_account_id) REFERENCES creditor_accounts(creditor_account_id)',
        TRUE,
        FALSE,
        FALSE
    ),
    (
        'ot_respondent_account_id_fk',
        'f',
        'FOREIGN KEY (respondent_account_id) REFERENCES respondent_accounts(respondent_account_id)',
        TRUE,
        FALSE,
        FALSE
    ),
    (
        'ot_result_id_fk',
        'f',
        'FOREIGN KEY (result_id) REFERENCES results(result_id)',
        TRUE,
        FALSE,
        FALSE
    );
\if :ot_verify
    INSERT INTO ot_expected_columns (
        position,
        name,
        type,
        required,
        default_expression,
        comment
    ) VALUES (
        18,
        'result_responses',
        'json',
        FALSE,
        NULL,
        'Result-response JSON array captured for the Order Term; NULL when not captured or unavailable.'
    );
    INSERT INTO ot_expected_constraints (
        name,
        kind,
        definition,
        validated,
        deferrable_flag,
        deferred_flag
    ) VALUES (
        'ot_result_responses_array_ck',
        'c',
        '((result_responses IS NULL) OR (json_typeof(result_responses) = ''array''::text))',
        TRUE,
        FALSE,
        FALSE
    );
\endif

-- -----------------------------------------------------------------------------
-- Scenario: Both approved predecessor rows preserve every original value.
-- Setup: Project all 17 original columns and compare with independent literal rows.
-- Expected: Both IDs, exact multiplicity, NULLs, numerics and fractional timestamps agree.
-- -----------------------------------------------------------------------------
SELECT results_eq($actual$SELECT order_terms_id,respondent_account_id,creditor_account_id,result_id,
    posted_date,posted_by,posted_by_name,original_posted_date,imposed_date,imposed_amount,
    arrears_amount,completed,child_name,child_birth_date,expiry_date,expiry_terms,remitted_amount
    FROM public.order_terms ORDER BY order_terms_id$actual$,
    $expected$SELECT * FROM ot_expected_rows ORDER BY order_terms_id$expected$,
    'both original rows equal every independent literal value');
SELECT is((SELECT COUNT(*) FROM public.order_terms),2::BIGINT,'exactly two predecessor rows survive');
SELECT is((SELECT COUNT(DISTINCT order_terms_id) FROM public.order_terms),2::BIGINT,
    'both predecessor identities retain exact multiplicity');

-- -----------------------------------------------------------------------------
-- Scenario: Existing rows gain SQL NULL without reconstruction or a default.
-- Setup: The candidate ALTER has run before any owner-suite fixture mutation.
-- Expected: Both preserved rows expose SQL NULL in the appended response column.
-- -----------------------------------------------------------------------------
SELECT is((SELECT COUNT(*) FROM public.order_terms WHERE result_responses IS NULL),2::BIGINT,
    'both preserved rows expose SQL NULL rather than a default or reconstructed response');

-- -----------------------------------------------------------------------------
-- Scenario: Only the approved response column and CHECK expand the catalogue.
-- Setup: Read native columns, constraints, indexes, relation properties and sequence ownership.
-- Expected: Every existing definition, privilege, collation, comment and access path is exact.
-- -----------------------------------------------------------------------------
SELECT is((SELECT JSONB_AGG(JSONB_BUILD_ARRAY(a.attnum,a.attname::TEXT,
    FORMAT_TYPE(a.atttypid,a.atttypmod),a.attnotnull,PG_GET_EXPR(d.adbin,d.adrelid),
    a.attidentity::TEXT,a.attgenerated::TEXT,a.attacl::TEXT,
    CASE WHEN a.attcollation=0 THEN NULL ELSE cn.nspname||'.'||c.collname END,
    COL_DESCRIPTION(a.attrelid,a.attnum)) ORDER BY a.attnum)
    FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum
    LEFT JOIN pg_collation c ON c.oid=a.attcollation LEFT JOIN pg_namespace cn ON cn.oid=c.collnamespace
    WHERE a.attrelid='public.order_terms'::REGCLASS AND a.attnum>0 AND NOT a.attisdropped),
    (SELECT JSONB_AGG(JSONB_BUILD_ARRAY(position,name,type,required,default_expression,
        ''::TEXT,''::TEXT,NULL::TEXT,CASE WHEN type LIKE 'character varying%' THEN 'pg_catalog.default' ELSE NULL END,
        comment) ORDER BY position) FROM ot_expected_columns),
    'exact columns defaults comments collation ACL and generated properties');
SELECT is((SELECT JSONB_AGG(JSONB_BUILD_ARRAY(conname::TEXT,contype::TEXT,
        CASE WHEN contype='c' THEN PG_GET_EXPR(conbin,conrelid) ELSE PG_GET_CONSTRAINTDEF(oid,FALSE) END,
        convalidated,condeferrable,condeferred) ORDER BY conname)
    FROM pg_constraint WHERE conrelid='public.order_terms'::REGCLASS),
    (SELECT JSONB_AGG(JSONB_BUILD_ARRAY(name,kind,definition,validated,deferrable_flag,deferred_flag)
        ORDER BY name) FROM ot_expected_constraints),
    'exact keys references actions CHECK and immediate validated properties');
SELECT is((SELECT JSONB_AGG(JSONB_BUILD_ARRAY(r.relname::TEXT,PG_GET_INDEXDEF(i.indexrelid),
        i.indisunique,i.indisprimary,i.indisvalid,i.indisready,PG_GET_EXPR(i.indpred,i.indrelid)) ORDER BY r.relname)
    FROM pg_index i JOIN pg_class r ON r.oid=i.indexrelid WHERE i.indrelid='public.order_terms'::REGCLASS),
    '[
      ["order_terms_creditor_account_id_idx","CREATE INDEX order_terms_creditor_account_id_idx ON public.order_terms USING btree (creditor_account_id)",false,false,true,true,null],
      ["order_terms_pk","CREATE UNIQUE INDEX order_terms_pk ON public.order_terms USING btree (order_terms_id)",true,true,true,true,null],
      ["order_terms_respondent_account_id_idx","CREATE INDEX order_terms_respondent_account_id_idx ON public.order_terms USING btree (respondent_account_id)",false,false,true,true,null],
      ["order_terms_result_id_idx","CREATE INDEX order_terms_result_id_idx ON public.order_terms USING btree (result_id)",false,false,true,true,null]
    ]'::JSONB,'exact existing index definitions properties and access paths');
SELECT is((SELECT JSONB_BUILD_ARRAY(c.relname::TEXT,n.nspname::TEXT,c.relkind::TEXT,
        PG_GET_USERBYID(c.relowner),c.relacl::TEXT,c.reloptions,c.relpersistence::TEXT,
        c.relrowsecurity,c.relforcerowsecurity,c.relreplident::TEXT,c.relispartition,
        OBJ_DESCRIPTION(c.oid,'pg_class'))
    FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE c.oid='public.order_terms'::REGCLASS),
    '["order_terms","public","r","postgres",null,null,"p",false,false,"d",false,null]'::JSONB,
    'relation owner privileges options security and comment are unchanged');
SELECT is(JSONB_BUILD_ARRAY(
    (SELECT COUNT(*) FROM pg_trigger WHERE tgrelid='public.order_terms'::REGCLASS AND NOT tgisinternal),
    (SELECT COUNT(*) FROM pg_policy WHERE polrelid='public.order_terms'::REGCLASS),
    (SELECT COUNT(*) FROM pg_rewrite WHERE ev_class='public.order_terms'::REGCLASS)),
    '[0,0,0]'::JSONB,'no user trigger RLS policy or rule is introduced');
SELECT is(JSONB_BUILD_ARRAY(PG_GET_SERIAL_SEQUENCE('public.order_terms','order_terms_id'),
    EXISTS(SELECT 1 FROM pg_depend d WHERE d.classid='pg_class'::REGCLASS
        AND d.objid='public.order_terms_id_seq'::REGCLASS AND d.refclassid='pg_class'::REGCLASS
        AND d.refobjid='public.order_terms'::REGCLASS AND d.refobjsubid=1 AND d.deptype='a')),
    '["public.order_terms_id_seq",true]'::JSONB,'original sequence remains owned by the same first column');

-- -----------------------------------------------------------------------------
-- Scenario: The candidate adds the exact approved response-only metadata.
-- Setup: Inspect the appended column comment and the named validated column-18 CHECK.
-- Expected: Only top-level JSON array shape is constrained; verification mutations roll back.
-- -----------------------------------------------------------------------------
SELECT is(COL_DESCRIPTION('public.order_terms'::REGCLASS,18),
    'Result-response JSON array captured for the Order Term; NULL when not captured or unavailable.',
    'new column alone receives the approved new comment');
SELECT is((SELECT JSONB_BUILD_ARRAY(conkey::SMALLINT[],contype::TEXT,convalidated,
        condeferrable,condeferred,PG_GET_EXPR(conbin,conrelid)) FROM pg_constraint
    WHERE conrelid='public.order_terms'::REGCLASS AND conname='ot_result_responses_array_ck'),
    '[[18],"c",true,false,false,"((result_responses IS NULL) OR (json_typeof(result_responses) = ''array''::text))"]'::JSONB,
    'new CHECK constrains only response top-level shape at the candidate');
SELECT * FROM finish();
ROLLBACK;
