/**
 * OPAL Program
 *
 * MODULE      : p_insert_respondent_account_parties_pgtap_tests.sql
 *
 * DESCRIPTION : Verify selected-domain association insertion, native and deliberate
 *               errors, row scope and compatible fresh/predecessor contracts.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket        Nature of Change
 * ----------  -------------  ------------  ----------------------------------------
 * 16/10/2026  Frankie Moran  PO-10649      Initial pgTAP test suite.
 */

-- OPAL-DB-UPGRADE {"id":"p_insert_respondent_account_parties.create","candidate":"ddl/V1_41__create_p_insert_respondent_account_parties_procedure.sql","scope":"both","data":"migration-created-only","inputs":["src/main/resources/db/migration/ddl/V1_2__create_countries_table.sql","src/main/resources/db/migration/ddl/V1_6__create_business_units_table.sql","src/main/resources/db/migration/ddl/V1_9__create_major_creditors_table.sql","src/main/resources/db/migration/ddl/V1_11__create_maintenance_applications_table.sql","src/main/resources/db/migration/ddl/V1_14__create_draft_casefiles_table.sql","src/main/resources/db/migration/ddl/V1_20__create_parties_table.sql","src/main/resources/db/migration/ddl/V1_26__create_respondent_accounts_table.sql","src/main/resources/db/migration/ddl/V1_27__create_creditor_accounts_table.sql","src/main/resources/db/migration/ddl/V1_28__create_respondent_account_parties_table.sql","src/main/resources/db/migration/ddl/V1_30__add_draft_casefiles_account_id_foreign_key.sql"],"contract":{"type":"additive","objects":{"created":[{"kind":"routine","identity":"public.p_insert_respondent_account_parties(bigint,bigint,public.t_association_type_enum)"}],"replaced":[]},"preserve":{"rows":["public.respondent_account_parties","public.respondent_accounts","public.creditor_accounts","public.parties","public.major_creditors"],"tables":["public.respondent_account_parties","public.respondent_accounts","public.creditor_accounts","public.parties","public.major_creditors"],"routines":[],"enums":["public.t_association_type_enum","public.t_creditor_account_type_enum","public.t_party_account_type_enum"],"sequences":["public.respondent_account_party_id_seq"]},"assertion":"respondent_account_parties.create"}}

\set ON_ERROR_STOP 1
\if :{?opal_assertion_group}
\else
    \set opal_assertion_group respondent_account_parties.current
\endif
SELECT :'opal_assertion_group' IN
    ('respondent_account_parties.current','respondent_account_parties.create') AS rap_valid_group \gset
\if :rap_valid_group
\else
    DO $group$ BEGIN RAISE EXCEPTION 'Unknown association assertion group'; END; $group$;
\endif
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SET LOCAL search_path = public, pg_catalog;
SET LOCAL TIME ZONE 'UTC';
SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '5s';

-- -----------------------------------------------------------------------------
-- Scenario: Reserve isolated synthetic fixtures with valid native relationships.
-- Setup: Explicit IDs avoid consuming provider sequences; unique codes are guarded.
-- Expected: No existing row is replaced, deleted or used as mutable fixture state.
-- -----------------------------------------------------------------------------
DO $guard$
DECLARE v_table TEXT; v_key TEXT; v_hit BOOLEAN;
BEGIN
    FOR v_table,v_key IN SELECT * FROM (VALUES
        ('countries','country_id'),('parties','party_id'),
        ('respondent_accounts','respondent_account_id'),('creditor_accounts','creditor_account_id'),
        ('major_creditors','major_creditor_id'),('respondent_account_parties','respondent_account_party_id'),
        ('draft_casefiles','draft_casefile_id')) AS reserved(table_name,key_name)
    LOOP
        EXECUTE FORMAT('SELECT EXISTS(SELECT 1 FROM public.%I WHERE %I BETWEEN -1064999 AND -1064901
            OR %I IN (-5000000001,-5000000002,-5000000100))',v_table,v_key,v_key) INTO v_hit;
        IF v_hit THEN RAISE EXCEPTION 'Association synthetic ID collision'; END IF;
    END LOOP;
    IF EXISTS(SELECT 1 FROM public.business_units WHERE business_unit_id=32049 OR business_unit_code='P049')
       OR EXISTS(SELECT 1 FROM public.maintenance_applications WHERE application_id=-32049 OR application_code='P049')
       OR EXISTS(SELECT 1 FROM public.countries WHERE cjs_code=31049)
       OR EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='po10649_association_diagnostics') THEN
        RAISE EXCEPTION 'Association synthetic fixture collision';
    END IF;
END;
$guard$;
INSERT INTO public.countries (
    country_id,
    cjs_code,
    country_name,
    date_used_from,
    active
) VALUES (
    -1064901,
    31049,
    'Synthetic association Country',
    DATE '2000-01-01',
    true
);
INSERT INTO public.business_units (
    business_unit_id,
    business_unit_code,
    business_unit_name,
    business_unit_type,
    welsh_language
) VALUES (
    32049,
    'P049',
    'Synthetic association area',
    'Area',
    false
);
INSERT INTO public.maintenance_applications (
    application_id,
    application_code,
    application_title,
    application_group,
    active,
    date_used_from
) VALUES (
    -32049,
    'P049',
    'Synthetic association application',
    'Synthetic',
    true,
    DATE '2000-01-01'
);
INSERT INTO public.parties (
    party_id,
    organisation,
    surname,
    address_line_1,
    restrict_personal_information,
    country_id,
    account_type
)
SELECT
    f.id,
    false,
    'Synthetic association',
    'Synthetic Road',
    false,
    -1064901,
    f.classification::public.t_party_account_type_enum
FROM (VALUES
    (-1064911::BIGINT,'Respondent'),
    (-1064912,'Minor Creditor'),
    (-1064913,NULL),
    (-1064961,'Minor Creditor'),
    (-1064962,'Respondent'),
    (-5000000001,'Respondent')
) AS f(id,classification);
INSERT INTO public.respondent_accounts (
    respondent_account_id,
    business_unit_id,
    account_number,
    application_id,
    account_balance,
    orders_balance,
    orders_amount,
    payment_period,
    total_arrears,
    account_status,
    last_movement_date,
    date_arrears_last_updated,
    allow_cheques,
    cheque_clearance_period,
    credit_trans_clearance_period,
    casefile_type,
    interest_flag,
    indexation,
    payment_arrangement,
    version_number
)
SELECT
    f.id,
    32049,
    f.number,
    -32049,
    0,
    0,
    0,
    'Monthly'::public.t_payment_frequency_enum,
    0,
    'L'::public.t_da_account_status_enum,
    TIMESTAMP '2026-01-01',
    TIMESTAMP '2026-01-01',
    false,
    0,
    0,
    'REMO In'::public.t_casefile_type_enum,
    false,
    'None'::public.t_indexation_enum,
    'Court'::public.t_payment_arrangement_enum,
    0
FROM (VALUES
    (-1064901::BIGINT,'SYN-RAP-A'),
    (-1064902,'SYN-RAP-B'),
    (-5000000100,'SYN-RAP-WIDE')
) AS f(id,number);
INSERT INTO public.major_creditors (
    major_creditor_id,
    business_unit_id,
    major_creditor_code,
    name,
    address_line_1,
    active,
    central_authority
)
SELECT
    f.id,
    32049,
    f.code,
    'Synthetic authority',
    'Synthetic Road',
    f.active,
    f.is_ca
FROM (VALUES
    (-1064931::BIGINT,'A931',true,true),
    (-1064932,'A932',true,false),
    (-1064933,'A933',false,true),
    (-1064961,'A961',true,false),
    (-1064962,'A962',true,true)
) AS f(id,code,active,is_ca);
INSERT INTO public.creditor_accounts (
    creditor_account_id,
    business_unit_id,
    account_number,
    creditor_account_type,
    major_creditor_id,
    minor_creditor_party_id,
    from_suspense,
    hold_payout,
    pay_by_bacs
)
SELECT
    f.id,
    32049,
    'SYN-RAP-' || f.label,
    f.kind::public.t_creditor_account_type_enum,
    f.major_id,
    f.party_id,
    false,
    false,
    false
FROM (VALUES
    (-1064921::BIGINT,'MN','MN',NULL::BIGINT,-1064912::BIGINT),
    (-1064922,'MJ','MJ',-1064932,NULL),
    (-1064923,'CF','CF',NULL,NULL),
    (-1064924,'MAJOR','MN',-1064931,NULL),
    (-1064925,'BOTH','MN',-1064931,-1064912),
    (-1064926,'NEITHER','MN',NULL,NULL),
    (-1064927,'RESP','MN',NULL,-1064911),
    (-1064928,'NULLCLASS','MN',NULL,-1064913),
    (-1064929,'CA-ROUTE','MJ',-1064931,NULL),
    (-1064940,'OTHER-MN','MN',NULL,-1064912),
    (-1064961,'OVERLAP-MN','MN',NULL,-1064912),
    (-1064962,'OVERLAP-MJ','MJ',-1064931,NULL),
    (-5000000002,'WIDE-MN','MN',NULL,-1064912)
) AS f(id,label,kind,major_id,party_id);
INSERT INTO public.respondent_account_parties (
    respondent_account_party_id,
    respondent_account_id,
    associated_account_id,
    association_type
) VALUES (
    -1064999,
    -1064902,
    -1064911,
    'Respondent'
);
INSERT INTO public.draft_casefiles (
    draft_casefile_id,
    business_unit_id,
    created_date,
    submitted_by,
    submitted_by_name,
    casefile,
    casefile_snapshot,
    casefile_type,
    casefile_status,
    casefile_status_date,
    timeline_data
) VALUES (
    -1064901,
    32049,
    TIMESTAMP '2026-01-01',
    'synthetic',
    'Synthetic fixture',
    '{"synthetic":"input"}',
    '{"synthetic":"snapshot"}',
    'REMO In',
    'PUBLISHING_PENDING',
    TIMESTAMP '2026-01-01',
    '[{"synthetic":"timeline"}]'
);

CREATE TEMP TABLE rap_cases (
    label TEXT PRIMARY KEY,
    parent_id TEXT,
    target_id TEXT,
    association TEXT,
    expected_state TEXT NOT NULL,
    semantic_message TEXT,
    mode TEXT NOT NULL DEFAULT 'normal'
);
CREATE TEMP TABLE rap_outputs (label TEXT PRIMARY KEY,id BIGINT NOT NULL);

-- -----------------------------------------------------------------------------
-- Scenario: Accept all three domains, wide identifiers, repeats and another eligible MN.
-- Setup: Negative and >32-bit IDs obey native keys; inactive CA remains classified CA.
-- Expected: Exact supplied triples, one generated identity per call, no role inference.
-- -----------------------------------------------------------------------------
INSERT INTO rap_cases (
    label,
    parent_id,
    target_id,
    association,
    expected_state
)
SELECT
    v.label,
    v.parent_id,
    v.target_id,
    v.association,
    '00000'
FROM (VALUES
    ('respondent-valid','-1064901','-1064911','Respondent'),
    ('applicant-valid','-1064901','-1064921','Applicant'),
    ('authority-valid','-1064901','-1064931','Central Authority'),
    ('authority-inactive','-1064901','-1064933','Central Authority'),
    ('respondent-wide','-5000000100','-5000000001','Respondent'),
    ('applicant-wide','-5000000100','-5000000002','Applicant'),
    ('other-eligible-mn','-1064901','-1064940','Applicant'),
    ('repeat-a','-1064901','-1064911','Respondent'),
    ('repeat-b','-1064901','-1064911','Respondent'),
    ('overlap-applicant-valid','-1064901','-1064961','Applicant'),
    ('overlap-respondent-valid','-1064901','-1064962','Respondent'),
    ('overlap-authority-valid','-1064901','-1064962','Central Authority')
) AS v(label,parent_id,target_id,association);

-- -----------------------------------------------------------------------------
-- Scenario: Reject missing or wrongly classified Respondent targets.
-- Setup: Minor/NULL Party classifications and numbers present only outside Parties.
-- Expected: Fixed safe Respondent validation P0001; no inserted or changed row.
-- -----------------------------------------------------------------------------
INSERT INTO rap_cases (
    label,
    parent_id,
    target_id,
    association,
    expected_state,
    semantic_message
)
SELECT
    v.label,
    '-1064901',
    v.target_id,
    'Respondent',
    'P0001',
    'p_insert_respondent_account_parties: validate Respondent target failed'
FROM (VALUES
    ('respondent-missing','-1064998'),
    ('respondent-minor','-1064912'),
    ('respondent-null-class','-1064913'),
    ('respondent-creditor-only','-1064921'),
    ('respondent-major-only','-1064931'),
    ('overlap-respondent-invalid','-1064961'),
    ('respondent-bigint-limit-missing','9223372036854775807')
) AS v(label,target_id);

-- -----------------------------------------------------------------------------
-- Scenario: Reject wrong Creditor classifications and schema-permitted MN reference pairs.
-- Setup: MJ/CF, MN Major-only/both/neither, linked Respondent or NULL-classified Party.
-- Expected: Applicant P0001; missing linked Party uses NULL and preserves existing FKs.
-- -----------------------------------------------------------------------------
INSERT INTO rap_cases (
    label,
    parent_id,
    target_id,
    association,
    expected_state,
    semantic_message
)
SELECT
    v.label,
    '-1064901',
    v.target_id,
    'Applicant',
    'P0001',
    'p_insert_respondent_account_parties: validate Applicant target failed'
FROM (VALUES
    ('applicant-missing','-1064998'),
    ('applicant-mj','-1064922'),
    ('applicant-cf','-1064923'),
    ('applicant-major-only','-1064924'),
    ('applicant-both-references','-1064925'),
    ('applicant-no-linked-party','-1064926'),
    ('applicant-linked-respondent','-1064927'),
    ('applicant-linked-null-class','-1064928'),
    ('applicant-party-only','-1064911'),
    ('applicant-major-only-domain','-1064931'),
    ('overlap-applicant-invalid','-1064962')
) AS v(label,target_id);

-- -----------------------------------------------------------------------------
-- Scenario: Resolve Central Authority directly in Major Creditors despite numeric overlap.
-- Setup: Non-CA/missing Major IDs; a Creditor Account points to a CA under another ID.
-- Expected: CA P0001; no indirect Creditor lookup or cross-domain rescue.
-- -----------------------------------------------------------------------------
INSERT INTO rap_cases (
    label,
    parent_id,
    target_id,
    association,
    expected_state,
    semantic_message
)
SELECT
    v.label,
    '-1064901',
    v.target_id,
    'Central Authority',
    'P0001',
    'p_insert_respondent_account_parties: validate Central Authority target failed'
FROM (VALUES
    ('authority-missing','-1064998'),
    ('authority-false','-1064932'),
    ('authority-creditor-indirection','-1064929'),
    ('authority-party-only','-1064911'),
    ('overlap-authority-invalid','-1064961')
) AS v(label,target_id);

-- -----------------------------------------------------------------------------
-- Scenario: Retain each native nullability, parent-FK and parameter conversion failure.
-- Setup: Exactly one input is invalid per case; all semantic targets otherwise qualify.
-- Expected: Original 23502/23503/22P02/22003 diagnostics, with no semantic replacement.
-- -----------------------------------------------------------------------------
INSERT INTO rap_cases (
    label,
    parent_id,
    target_id,
    association,
    expected_state
)
SELECT
    v.label,
    v.parent_id,
    v.target_id,
    v.association,
    v.state
FROM (VALUES
    ('native-null-parent',NULL,'-1064911','Respondent','23502'),
    ('native-null-target','-1064901',NULL,'Respondent','23502'),
    ('native-null-type','-1064901','-1064911',NULL,'23502'),
    ('native-parent-fk','-1064998','-1064911','Respondent','23503'),
    ('native-unsupported-type','-1064901','-1064911','Guardian','22P02'),
    ('native-type-case','-1064901','-1064911','respondent','22P02'),
    ('native-type-space','-1064901','-1064911','Respondent ','22P02'),
    ('native-invalid-bigint','-1064901','not-an-id','Respondent','22P02'),
    ('native-overflow-bigint','9223372036854775808','-1064911','Respondent','22003')
) AS v(label,parent_id,target_id,association,state);

-- -----------------------------------------------------------------------------
-- Scenario: Observe row scope and unchanged original diagnostics without a wrapper contract.
-- Setup: Snapshot business rows and capture CALL or direct native INSERT errors in SQL.
-- Expected: Direct native comparisons differ only in stack context and test-only result keys.
-- -----------------------------------------------------------------------------
CREATE FUNCTION pg_temp.rap_rows() RETURNS JSONB LANGUAGE plpgsql AS $rows$
DECLARE v_table TEXT; v_values JSONB; v_result JSONB := '{}';
BEGIN
    FOREACH v_table IN ARRAY ARRAY[
        'respondent_account_parties','respondent_accounts','creditor_accounts','parties',
        'major_creditors','draft_casefiles','countries','business_units','maintenance_applications',
        'results','configuration_items','debtor_detail','third_party_contact','account_number_index',
        'notes','aliases','order_terms'
    ] LOOP
        EXECUTE FORMAT('SELECT COALESCE(JSONB_AGG(value ORDER BY value),''[]''::JSONB)
            FROM (SELECT ROW_TO_JSON(t)::TEXT AS value FROM public.%I t) r',v_table) INTO v_values;
        v_result := v_result || JSONB_BUILD_OBJECT(v_table,v_values);
    END LOOP;
    RETURN v_result;
END;
$rows$;
CREATE FUNCTION pg_temp.rap_probe(
    p_parent TEXT,p_target TEXT,p_type TEXT,p_direct BOOLEAN DEFAULT false,p_id BIGINT DEFAULT NULL
) RETURNS JSONB LANGUAGE plpgsql AS $probe$
DECLARE v_id BIGINT; v_state TEXT; v_message TEXT; v_detail TEXT; v_hint TEXT;
        v_schema TEXT; v_table TEXT; v_column TEXT; v_constraint TEXT; v_context TEXT; v_datatype TEXT;
BEGIN
    IF p_direct THEN
        INSERT INTO public.respondent_account_parties (
            respondent_account_party_id,
            respondent_account_id,
            associated_account_id,
            association_type
        ) VALUES (
            p_id,
            p_parent::BIGINT,
            p_target::BIGINT,
            p_type::public.t_association_type_enum
        );
        v_id := p_id;
    ELSE
        CALL public.p_insert_respondent_account_parties(
            p_parent::BIGINT,p_target::BIGINT,p_type::public.t_association_type_enum);
        v_id := CURRVAL('public.respondent_account_party_id_seq');
    END IF;
    RETURN JSONB_BUILD_OBJECT('state','00000','succeeded',true,'id',v_id);
EXCEPTION WHEN query_canceled OR assert_failure OR OTHERS THEN
    GET STACKED DIAGNOSTICS v_state=RETURNED_SQLSTATE,v_message=MESSAGE_TEXT,
        v_detail=PG_EXCEPTION_DETAIL,v_hint=PG_EXCEPTION_HINT,v_schema=SCHEMA_NAME,
        v_table=TABLE_NAME,v_column=COLUMN_NAME,v_constraint=CONSTRAINT_NAME,
        v_context=PG_EXCEPTION_CONTEXT,v_datatype=PG_DATATYPE_NAME;

    RETURN JSONB_BUILD_OBJECT('state',v_state,'succeeded',false,'id',NULL,
        'message',v_message,'detail',v_detail,'hint',v_hint,'schema',v_schema,
        'table',v_table,'column',v_column,'constraint',v_constraint,'context',v_context,'datatype',v_datatype);
END;
$probe$;

-- -----------------------------------------------------------------------------
-- Scenario: Propagate late native PK and supplied diagnostics through the common rethrow.
-- Setup: Gated BEFORE trigger counts helper attempts and injects fixed synthetic failures.
-- Expected: Exact SQLSTATE/message/detail/hint/object fields, useful context and atomic rows.
-- -----------------------------------------------------------------------------
CREATE SEQUENCE pg_temp.rap_attempts START 1;
CREATE FUNCTION pg_temp.rap_inject() RETURNS TRIGGER LANGUAGE plpgsql AS $inject$
DECLARE v_mode TEXT := CURRENT_SETTING('opal.rap_test_mode',true);
BEGIN
    IF v_mode IS NULL OR v_mode='normal' THEN RETURN NEW; END IF;
    PERFORM NEXTVAL('pg_temp.rap_attempts');
    IF v_mode='native-pk' THEN
        NEW.respondent_account_party_id := -1064999;
        RETURN NEW;
    END IF;
    RAISE EXCEPTION USING ERRCODE=SUBSTRING(v_mode FROM 8),
        MESSAGE='synthetic association diagnostic',DETAIL='synthetic association detail',
        HINT='synthetic association hint',SCHEMA='public',TABLE='respondent_account_parties',
        COLUMN='associated_account_id',CONSTRAINT='rap_synthetic_diagnostic',DATATYPE='int8';
END;
$inject$;
CREATE TRIGGER po10649_association_diagnostics BEFORE INSERT ON public.respondent_account_parties
    FOR EACH ROW EXECUTE FUNCTION pg_temp.rap_inject();
INSERT INTO rap_cases (
    label,
    parent_id,
    target_id,
    association,
    expected_state,
    mode
) VALUES (
    'late-native-pk',
    '-1064901',
    '-1064911',
    'Respondent',
    '23505',
    'native-pk'
);
INSERT INTO rap_cases (
    label,
    parent_id,
    target_id,
    association,
    expected_state,
    mode
)
SELECT
    'late-injected-' || v.state,
    '-1064901',
    '-1064911',
    'Respondent',
    v.state,
    'inject:' || v.state
FROM (VALUES
    ('22001'),('23502'),('23503'),('23505'),('40001'),('40P01'),('P0001'),('57014'),('P0004')
) AS v(state);

CREATE FUNCTION pg_temp.rap_run_cases() RETURNS SETOF TEXT LANGUAGE plpgsql AS $cases$
DECLARE c rap_cases%ROWTYPE; b JSONB; a JSONB; r JSONB; expected_diag JSONB;
        n BIGINT; new_id BIGINT; native_id BIGINT; seq_before BIGINT; seq_called BOOLEAN;
        late_ok BOOLEAN; context_ok BOOLEAN;
BEGIN
    FOR c IN SELECT * FROM rap_cases ORDER BY label LOOP
        b := pg_temp.rap_rows();
        SELECT COUNT(*) INTO n FROM public.respondent_account_parties;
        PERFORM SET_CONFIG('opal.rap_test_mode',c.mode,true);
        PERFORM SETVAL('pg_temp.rap_attempts',1,false);
        SELECT last_value,is_called INTO seq_before,seq_called FROM public.respondent_account_party_id_seq;
        r := pg_temp.rap_probe(c.parent_id,c.target_id,c.association);
        a := pg_temp.rap_rows();
        RETURN NEXT is(r->>'state',c.expected_state,c.label || ': SQLSTATE');
        IF c.expected_state='00000' THEN
            new_id := (r->>'id')::BIGINT;
            IF new_id IS NOT NULL THEN
                INSERT INTO rap_outputs (
                    label,
                    id
                ) VALUES (
                    c.label,
                    new_id
                );
            END IF;
            RETURN NEXT ok(CASE WHEN new_id IS NULL THEN false ELSE
                r->'succeeded'='true'::JSONB
                AND (SELECT COUNT(*) FROM public.respondent_account_parties)=n+1
                AND (SELECT COUNT(*) FROM public.respondent_account_parties
                     WHERE respondent_account_party_id=new_id)=1
                AND new_id=CURRVAL('public.respondent_account_party_id_seq') END,
                c.label || ': one row and existing default-generated identity');
            RETURN NEXT is((SELECT TO_JSONB(t)-'respondent_account_party_id'
                FROM public.respondent_account_parties t WHERE respondent_account_party_id=new_id),
                JSONB_BUILD_OBJECT('respondent_account_id',c.parent_id::BIGINT,
                    'associated_account_id',c.target_id::BIGINT,'association_type',c.association),
                c.label || ': exact stored input triple');
            RETURN NEXT ok((b-'respondent_account_parties') IS NOT DISTINCT FROM (a-'respondent_account_parties')
                AND NOT EXISTS(SELECT 1 FROM JSONB_ARRAY_ELEMENTS_TEXT(b->'respondent_account_parties') old
                    WHERE NOT EXISTS(SELECT 1 FROM public.respondent_account_parties t
                        WHERE ROW_TO_JSON(t)::TEXT=old.value)),
                c.label || ': prior associations and other scoped rows/status unchanged');
        ELSE
            RETURN NEXT ok(r->'succeeded'='false'::JSONB AND r->'id'='null'::JSONB AND a=b,
                c.label || ': no success or partial row mutation');
            late_ok := c.mode='normal' OR (
                (SELECT last_value=1 AND is_called FROM pg_temp.rap_attempts)
                AND (SELECT last_value=CASE WHEN seq_called THEN seq_before+1 ELSE seq_before END AND is_called
                     FROM public.respondent_account_party_id_seq));
            context_ok := CASE
                WHEN c.mode LIKE 'inject:%' THEN
                    r->>'context' LIKE '%rap_inject()%'
                    AND r->>'context' LIKE '%p_insert_respondent_account_parties%'
                WHEN c.mode='native-pk'
                     OR c.expected_state IN ('23502','23503','P0001') THEN
                    r->>'context' LIKE '%p_insert_respondent_account_parties%'
                ELSE LENGTH(r->>'context')>0
            END;
            IF c.mode LIKE 'inject:%' THEN
                expected_diag := JSONB_BUILD_OBJECT('state',c.expected_state,
                    'message','synthetic association diagnostic','detail','synthetic association detail',
                    'hint','synthetic association hint','schema','public','table','respondent_account_parties',
                    'column','associated_account_id','constraint','rap_synthetic_diagnostic','datatype','int8');
            ELSIF c.expected_state='P0001' THEN
                expected_diag := JSONB_BUILD_OBJECT('state','P0001','message',c.semantic_message,
                    'detail','','hint','','schema','','table','','column','','constraint','','datatype','');
            ELSE
                SELECT last_value INTO native_id FROM public.respondent_account_party_id_seq;
                expected_diag := pg_temp.rap_probe(c.parent_id,c.target_id,c.association,true,native_id)
                    - ARRAY['succeeded','id','context'];
            END IF;
            RETURN NEXT is(r-ARRAY['succeeded','id','context'],expected_diag,
                c.label || ': exact original or deliberate diagnostic fields');
            RETURN NEXT ok(late_ok AND context_ok
                AND (c.label<>'native-parent-fk' OR r->>'constraint'='rap_respondent_account_id_fk')
                AND (c.label<>'late-native-pk' OR r->>'constraint'='respondent_account_parties_pk')
                AND (c.label<>'native-null-parent' OR r->>'column'='respondent_account_id')
                AND (c.label<>'native-null-target' OR r->>'column'='associated_account_id')
                AND (c.label<>'native-null-type' OR r->>'column'='association_type'),
                c.label || ': original context, native field identity and one late attempt');
        END IF;
    END LOOP;
    PERFORM SET_CONFIG('opal.rap_test_mode','normal',true);
END;
$cases$;

-- -----------------------------------------------------------------------------
-- Scenario: Verify the exact three-IN procedure, effective invocation properties and schema.
-- Setup: Inspect the single typed identity, argument arrays, ownership/default and comment.
-- Expected: No output/default/overload or invented polymorphic FK; native sequence remains owned.
-- -----------------------------------------------------------------------------
SELECT plan(14 + 4*(SELECT COUNT(*)::INTEGER FROM rap_cases));
SELECT ok((SELECT prokind='p' AND pronargs=3 AND prorettype='void'::REGTYPE AND NOT proretset
    FROM pg_proc WHERE oid=TO_REGPROCEDURE(
        'public.p_insert_respondent_account_parties(bigint,bigint,public.t_association_type_enum)')),
    'exact procedure identity has three inputs and void catalogue result');
SELECT ok((SELECT proargnames=ARRAY['pi_respondent_account_id','pi_associated_account_id','pi_association_type']
    AND proargmodes IS NULL AND proallargtypes IS NULL
    AND proargtypes[0]='bigint'::REGTYPE AND proargtypes[1]='bigint'::REGTYPE
    AND proargtypes[2]='public.t_association_type_enum'::REGTYPE
    FROM pg_proc WHERE oid=TO_REGPROCEDURE(
        'public.p_insert_respondent_account_parties(bigint,bigint,public.t_association_type_enum)')),
    'ordered column-derived effective types and names, all IN without OUT');
SELECT is((SELECT JSONB_BUILD_ARRAY(l.lanname::TEXT,p.prosecdef,p.proisstrict,p.provolatile::TEXT,
        p.proparallel::TEXT,p.pronargdefaults,p.proconfig)
    FROM pg_proc p JOIN pg_language l ON l.oid=p.prolang
    WHERE p.oid=TO_REGPROCEDURE(
        'public.p_insert_respondent_account_parties(bigint,bigint,public.t_association_type_enum)')),
    '["plpgsql",false,false,"v","u",0,null]'::JSONB,
    'effective invoker defaults and no parameter defaults');
SELECT is(OBJ_DESCRIPTION(TO_REGPROCEDURE(
    'public.p_insert_respondent_account_parties(bigint,bigint,public.t_association_type_enum)'),'pg_proc'),
    'Insert one validated Respondent Account association using its existing identity default. Caller owns transaction, Applicant provenance and complete association cardinality.',
    'comment records one-row identity and caller ownership');
SELECT is((SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.proname='p_insert_respondent_account_parties'),1::BIGINT,
    'one public overload');
SELECT is(PG_GET_SERIAL_SEQUENCE('public.respondent_account_parties','respondent_account_party_id'),
    'public.respondent_account_party_id_seq','existing association identity sequence remains owned');
SELECT ok(NOT EXISTS(SELECT 1 FROM pg_constraint c JOIN pg_attribute a
    ON a.attrelid=c.conrelid AND a.attnum=ANY(c.conkey)
    WHERE c.conrelid='public.respondent_account_parties'::REGCLASS AND c.contype='f'
    AND a.attname='associated_account_id'),'no invented polymorphic foreign key');

-- -----------------------------------------------------------------------------
-- Scenario: Execute the independently specified input and diagnostic matrix.
-- Setup: One buffered statement observes each call before the following case can mutate rows.
-- Expected: Four assertions per case with no successful fallback or internal retry.
-- -----------------------------------------------------------------------------
SELECT * FROM pg_temp.rap_run_cases();

-- -----------------------------------------------------------------------------
-- Scenario: Repeat calls insert distinct rows and caller rollback removes its own insertion.
-- Setup: Equal repeat cases plus a savepoint whose observations use psql variables.
-- Expected: Distinct identities, row visibility then removal, restored rows and allowed ID gap.
-- -----------------------------------------------------------------------------
SELECT ok((SELECT a.id<>b.id FROM rap_outputs a CROSS JOIN rap_outputs b
    WHERE a.label='repeat-a' AND b.label='repeat-b'),
    'identical successful calls insert distinct associations');
SELECT pg_temp.rap_rows()::TEXT AS rap_before_rollback \gset
SAVEPOINT rap_caller_owned;
SELECT pg_temp.rap_probe('-1064901','-1064911','Respondent')::TEXT AS rap_rollback_result \gset
SELECT EXISTS(SELECT 1 FROM public.respondent_account_parties
    WHERE respondent_account_party_id=(:'rap_rollback_result'::JSONB->>'id')::BIGINT)
    AS rap_visible_before_rollback \gset
ROLLBACK TO SAVEPOINT rap_caller_owned;
RELEASE SAVEPOINT rap_caller_owned;
SELECT ok(:'rap_visible_before_rollback'::BOOLEAN,'successful row is visible inside caller savepoint');
SELECT ok(NOT EXISTS(SELECT 1 FROM public.respondent_account_parties
    WHERE respondent_account_party_id=(:'rap_rollback_result'::JSONB->>'id')::BIGINT),
    'caller rollback removes the successful association');
SELECT is(pg_temp.rap_rows(),:'rap_before_rollback'::JSONB,'caller rollback restores scoped rows and status');
SELECT ok((SELECT last_value=(:'rap_rollback_result'::JSONB->>'id')::BIGINT AND is_called
    FROM public.respondent_account_party_id_seq),'caller rollback may retain the consumed identity');

-- -----------------------------------------------------------------------------
-- Scenario: Remove only owned injection objects before owner rollback.
-- Setup: Drop collision-guarded trigger and its temporary trigger function explicitly.
-- Expected: Both objects absent; remaining fixtures/helpers roll back with the owner transaction.
-- -----------------------------------------------------------------------------
DROP TRIGGER po10649_association_diagnostics ON public.respondent_account_parties;
DROP FUNCTION pg_temp.rap_inject();
SELECT ok(NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.respondent_account_parties'::REGCLASS
    AND tgname='po10649_association_diagnostics'),'owned injection trigger removed');
SELECT ok(TO_REGPROCEDURE('pg_temp.rap_inject()') IS NULL,'owned injection function removed');
SELECT * FROM finish();
ROLLBACK;
