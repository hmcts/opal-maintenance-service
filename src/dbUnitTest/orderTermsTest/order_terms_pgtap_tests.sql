/**
 * OPAL Program
 *
 * MODULE      : order_terms_pgtap_tests.sql
 *
 * DESCRIPTION : Verify the Order Terms schema, integrity rules and account interactions.
 *
 * CHANGE HISTORY:
 *
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * 03/10/2026  Chris Larkin  PO-10653      Initial pgTAP test suite.
 */

-- PO-10653: V1_27__create_order_terms_table.sql; Tasks 14 and 16.
-- Boundary applicability: fresh DB-01; direct PostgreSQL catalogue and behaviour.
-- Existing-state validation: Not run - user-approved initial-schema scope exception.
-- Initial delivery assumes no established affected account workflow; no upgrade path is claimed.
-- Table expectations were independently checked against promoted TDIA v162 and the approved plan.
-- Graph checks prove database transaction participation; backend orchestration/status is outside scope.
\set ON_ERROR_STOP on
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SET LOCAL search_path = public, pg_temp;
SET LOCAL TIME ZONE 'UTC';
SELECT plan(141);

-- ---------------------------------------------------------------------------
-- Scenario: The promoted table has exactly the declared physical columns.
-- Setup:    Inspect the ordered column list, PostgreSQL types and nullability.
-- Expected: Every source-defined column matches, including optional fields.
-- ---------------------------------------------------------------------------

SELECT has_table('public', 'order_terms', 'public.order_terms exists');

SELECT is(
    (SELECT jsonb_agg(jsonb_build_array(
        attname::text, format_type(atttypid, atttypmod), attnotnull
    ) ORDER BY attnum)
    FROM pg_attribute
    WHERE attrelid = 'public.order_terms'::regclass AND attnum > 0 AND NOT attisdropped),
    '[["order_terms_id","bigint",true],["respondent_account_id","bigint",true],["creditor_account_id","bigint",true],["result_id","character varying(6)",true],["posted_date","timestamp without time zone",true],["posted_by","character varying(20)",false],["posted_by_name","character varying(100)",false],["original_posted_date","timestamp without time zone",false],["imposed_date","timestamp without time zone",true],["imposed_amount","numeric",true],["arrears_amount","numeric",false],["completed","boolean",true],["child_name","character varying(100)",false],["child_birth_date","timestamp without time zone",false],["expiry_date","timestamp without time zone",false],["expiry_terms","boolean",false],["remitted_amount","numeric",false]]'::jsonb,
    'exact ordered columns, physical types and nullability'
);

-- ---------------------------------------------------------------------------
-- Scenario: All column comments retain the promoted TDIA descriptions.
-- Setup:    Read comments in physical column order.
-- Expected: Every comment equals the independently checked source wording.
-- ---------------------------------------------------------------------------

SELECT is(
    (SELECT array_agg(col_description(attrelid, attnum) ORDER BY attnum)
     FROM pg_attribute
     WHERE attrelid = 'public.order_terms'::regclass AND attnum > 0 AND NOT attisdropped),
    ARRAY[
        'Unique identifier of the Order Terms',
        'Identifier of the related Respondent Account',
        'Identifier of the Creditor Account receiving allocated payments',
        'Identifier of the court result defining the order-term type',
        'Date the order term was posted',
        'Identifier of the posting user',
        'Display name of the posting user',
        'Original posting date where the order term duplicates a written-off legacy imposition',
        'Date the maintenance order was imposed',
        'Amount imposed by the court',
        'Arrears amount for the order term',
        'Whether the order term has been paid in full',
        'Child name for the payable maintenance component',
        'Child birth date for the payable maintenance component',
        'Expiry date of the payable maintenance component',
        'Whether further-education expiry terms apply',
        'Remitted arrears or order-term amount; null until a remittance is recorded'
    ]::text[],
    'all column comments match the promoted TDIA verbatim'
);

-- ---------------------------------------------------------------------------
-- Scenario: Only the declared keys and indexes are installed.
-- Setup:    Inspect named constraints, PK columns, index keys and index properties.
-- Expected: No extra uniqueness, CHECK, index or user trigger is introduced.
-- ---------------------------------------------------------------------------

SELECT is(
    (SELECT array_agg(conname::text ORDER BY conname) FROM pg_constraint
     WHERE conrelid = 'public.order_terms'::regclass AND contype IN ('p', 'u', 'f', 'c')),
    ARRAY['order_terms_pk', 'ot_creditor_account_id_fk', 'ot_respondent_account_id_fk', 'ot_result_id_fk']::text[],
    'exact table constraint inventory, including the absence of business CHECKs'
);

SELECT col_is_pk('public', 'order_terms', 'order_terms_id', 'order_terms_id is the sole primary-key column');

SELECT is(
    (SELECT array_agg(indexname::text ORDER BY indexname) FROM pg_indexes
     WHERE schemaname = 'public' AND tablename = 'order_terms'),
    ARRAY['order_terms_creditor_account_id_idx', 'order_terms_pk', 'order_terms_respondent_account_id_idx', 'order_terms_result_id_idx']::text[],
    'exact index inventory without duplicate access paths'
);

SELECT is(
    (SELECT jsonb_agg(jsonb_build_array(
        index_relation.relname::text,
           ARRAY(SELECT attribute.attname::text
                 FROM unnest(index_definition.indkey) WITH ORDINALITY AS key_column(attnum, position)
                 JOIN pg_attribute attribute
                   ON attribute.attrelid = index_definition.indrelid
                  AND attribute.attnum = key_column.attnum
                 ORDER BY key_column.position),
           access_method.amname::text, index_definition.indisunique, index_definition.indisprimary,
           index_definition.indisvalid, index_definition.indisready,
           pg_get_expr(index_definition.indpred, index_definition.indrelid)
    ) ORDER BY index_relation.relname)
    FROM pg_index index_definition
    JOIN pg_class index_relation ON index_relation.oid = index_definition.indexrelid
    JOIN pg_am access_method ON access_method.oid = index_relation.relam
    WHERE index_definition.indrelid = 'public.order_terms'::regclass),
    '[["order_terms_creditor_account_id_idx",["creditor_account_id"],"btree",false,false,true,true,null],["order_terms_pk",["order_terms_id"],"btree",true,true,true,true,null],["order_terms_respondent_account_id_idx",["respondent_account_id"],"btree",false,false,true,true,null],["order_terms_result_id_idx",["result_id"],"btree",false,false,true,true,null]]'::jsonb,
    'indexes have exact ordered keys, uniqueness, ready valid B-tree state and no predicates'
);

SELECT is(
    (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'public.order_terms'::regclass AND NOT tgisinternal),
    0::bigint, 'no user trigger adds behaviour to the table'
);

-- ---------------------------------------------------------------------------
-- Scenario: All three FKs have declared endpoints and immediate NO ACTION behaviour.
-- Setup:    Inspect referencing and referenced columns and FK action flags.
-- Expected: The FKs reference Respondent Accounts, Creditor Accounts and Results immediately.
-- ---------------------------------------------------------------------------

SELECT is(
    (SELECT jsonb_agg(jsonb_build_array(
        constraint_definition.conname::text,
           ARRAY(SELECT attribute.attname::text
                 FROM unnest(constraint_definition.conkey) WITH ORDINALITY AS key_column(attnum, position)
                 JOIN pg_attribute attribute
                   ON attribute.attrelid = constraint_definition.conrelid
                  AND attribute.attnum = key_column.attnum
                 ORDER BY key_column.position),
           parent_namespace.nspname::text, parent_relation.relname::text,
           ARRAY(SELECT attribute.attname::text
                 FROM unnest(constraint_definition.confkey) WITH ORDINALITY AS key_column(attnum, position)
                 JOIN pg_attribute attribute
                   ON attribute.attrelid = constraint_definition.confrelid
                  AND attribute.attnum = key_column.attnum
                 ORDER BY key_column.position),
           constraint_definition.confupdtype::text, constraint_definition.confdeltype::text,
           constraint_definition.confmatchtype::text, constraint_definition.condeferrable,
           constraint_definition.condeferred, constraint_definition.convalidated
    ) ORDER BY constraint_definition.conname)
    FROM pg_constraint constraint_definition
    JOIN pg_class parent_relation ON parent_relation.oid = constraint_definition.confrelid
    JOIN pg_namespace parent_namespace ON parent_namespace.oid = parent_relation.relnamespace
    WHERE constraint_definition.conrelid = 'public.order_terms'::regclass
      AND constraint_definition.contype = 'f'),
    '[["ot_creditor_account_id_fk",["creditor_account_id"],"public","creditor_accounts",["creditor_account_id"],"a","a","s",false,false,true],["ot_respondent_account_id_fk",["respondent_account_id"],"public","respondent_accounts",["respondent_account_id"],"a","a","s",false,false,true],["ot_result_id_fk",["result_id"],"public","results",["result_id"],"a","a","s",false,false,true]]'::jsonb,
    'all FK endpoints and immediate NO ACTION properties match the contract'
);

-- ---------------------------------------------------------------------------
-- Scenario: Identifiers use an owned BIGINT sequence and only the ID has a default.
-- Setup:    Inspect sequence configuration, dependency, nextval expression and identity flags.
-- Expected: START 1, INCREMENT 1, CACHE 1 and NO CYCLE are retained; no other default is added.
-- ---------------------------------------------------------------------------

SELECT has_sequence('public', 'order_terms_id_seq', 'public.order_terms_id_seq exists');

SELECT is(pg_get_serial_sequence('public.order_terms', 'order_terms_id'),
          'public.order_terms_id_seq', 'the identifier sequence is owned by the identifier column');

SELECT is(
    (SELECT seqtypid::regtype::text || ':' || seqstart || ':' || seqincrement || ':' || seqcache || ':' || seqcycle
     FROM pg_sequence WHERE seqrelid = 'public.order_terms_id_seq'::regclass),
    'bigint:1:1:1:false', 'exact BIGINT sequence start, increment, cache and no-cycle contract'
);

SELECT is(
    (SELECT pg_get_expr(adbin, adrelid) FROM pg_attrdef
     WHERE adrelid = 'public.order_terms'::regclass
       AND adnum = (SELECT attnum FROM pg_attribute
                    WHERE attrelid = 'public.order_terms'::regclass AND attname = 'order_terms_id')),
    'nextval(''order_terms_id_seq''::regclass)', 'the identifier default calls its exact sequence'
);

SELECT ok(
    EXISTS (SELECT 1 FROM pg_attrdef column_default
            JOIN pg_depend dependency ON dependency.classid = 'pg_attrdef'::regclass
             AND dependency.objid = column_default.oid AND dependency.refclassid = 'pg_class'::regclass
             AND dependency.refobjid = 'public.order_terms_id_seq'::regclass
            WHERE column_default.adrelid = 'public.order_terms'::regclass
              AND column_default.adnum = (SELECT attnum FROM pg_attribute
                  WHERE attrelid = 'public.order_terms'::regclass AND attname = 'order_terms_id')),
    'identifier default depends on its owned sequence'
);

SELECT ok(
    EXISTS (SELECT 1 FROM pg_depend dependency
            WHERE dependency.classid = 'pg_class'::regclass
              AND dependency.objid = 'public.order_terms_id_seq'::regclass
              AND dependency.refclassid = 'pg_class'::regclass
              AND dependency.refobjid = 'public.order_terms'::regclass
              AND dependency.refobjsubid = (SELECT attnum FROM pg_attribute
                  WHERE attrelid = 'public.order_terms'::regclass AND attname = 'order_terms_id')
              AND dependency.deptype = 'a'),
    'the sequence has the explicit OWNED BY column dependency'
);

SELECT is((SELECT count(*) FROM pg_attrdef WHERE adrelid = 'public.order_terms'::regclass),
          1::bigint, 'only the identifier has a database default');

SELECT is(
    (SELECT count(*) FROM pg_attribute
     WHERE attrelid = 'public.order_terms'::regclass AND attnum > 0 AND NOT attisdropped AND attidentity <> ''),
    0::bigint, 'no identity column replaces the explicit owned sequence'
);


-- ---------------------------------------------------------------------------
-- Scenario: Synthetic prerequisites are isolated and source-valid.
-- Setup:    Insert suite-owned Business Units and a dedicated Result; capture account IDs.
-- Expected: No existing fixture is overwritten; all fixtures roll back with this suite.
-- ---------------------------------------------------------------------------
DO $fixture$
BEGIN
    IF EXISTS (SELECT 1 FROM public.business_units
               WHERE business_unit_id IN (32061, 32062) OR business_unit_code IN ('CV61', 'CV62')) THEN
        RAISE EXCEPTION 'Synthetic Business Unit fixture collision';
    END IF;
    IF EXISTS (SELECT 1 FROM public.results WHERE result_id = 'CVOT53') THEN
        RAISE EXCEPTION 'Synthetic Order Terms Result fixture collision';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.countries)
       OR NOT EXISTS (SELECT 1 FROM public.maintenance_applications)
       OR NOT EXISTS (SELECT 1 FROM public.results) THEN
        RAISE EXCEPTION 'Required reference data missing';
    END IF;
    IF (SELECT count(*) FROM public.configuration_items
        WHERE business_unit_id IS NULL AND item_name IN
            ('DEFAULT_CHEQUE_CLEARANCE_PERIOD', 'DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD')) <> 2 THEN
        RAISE EXCEPTION 'Required global configuration missing';
    END IF;
END
$fixture$;
INSERT INTO public.business_units (
    business_unit_id, business_unit_code, business_unit_name, business_unit_type, welsh_language
)
VALUES (32061, 'CV61', 'Synthetic test unit A', 'Area', FALSE),
       (32062, 'CV62', 'Synthetic test unit B', 'Area', FALSE);
CREATE TEMP TABLE cv_reference AS
SELECT (SELECT min(country_id) FROM public.countries) AS country_id,
       (SELECT min(application_id) FROM public.maintenance_applications) AS application_id,
       (SELECT min(result_id) FROM public.results) AS result_id;
INSERT INTO public.results (
    result_id, result_title, order_term, enforcement_result, case_result, active, order_accruing,
    requires_creditor, enforcement_hold, requires_enforcer, generates_hearing, generates_warrant,
    lists_monies, requires_employment_data, allow_additional_action, enf_next_permitted_actions,
    manual_enforcement, auto_enforcement
)
VALUES ('CVOT53', 'Synthetic Order Terms Result', TRUE, FALSE, FALSE, TRUE, FALSE, FALSE,
        FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, '', FALSE, FALSE);
CREATE TEMP TABLE cv_subject (id BIGINT PRIMARY KEY);
CREATE TEMP TABLE cv_created (id BIGINT PRIMARY KEY, scenario TEXT UNIQUE NOT NULL);
CREATE TEMP TABLE cv_respondent AS
WITH inserted AS (
    INSERT INTO public.respondent_accounts (
        business_unit_id, account_number, application_id, account_balance, orders_balance, orders_amount,
        payment_period, total_arrears, account_status, last_movement_date, date_arrears_last_updated,
        allow_cheques, cheque_clearance_period, credit_trans_clearance_period, casefile_type, interest_flag,
        indexation, payment_arrangement, version_number
    )
    SELECT 32061, 'CV-RESPONDENT', application_id, 0, 0, 0, 'Weekly', 0, 'L',
           TIMESTAMP '2026-01-01 12:00:00', TIMESTAMP '2026-01-01 12:00:00',
           TRUE, 10, 0, 'REMO In', FALSE, 'None', 'Court', 1
    FROM cv_reference
    RETURNING respondent_account_id
) SELECT respondent_account_id FROM inserted;
CREATE TEMP TABLE cv_creditor AS
WITH inserted AS (
    INSERT INTO public.creditor_accounts (
        business_unit_id, account_number, creditor_account_type, from_suspense, hold_payout, pay_by_bacs
    ) VALUES (32061, 'CV-CREDITOR', 'MN', FALSE, FALSE, FALSE)
    RETURNING creditor_account_id
) SELECT creditor_account_id FROM inserted;

-- ---------------------------------------------------------------------------
-- Scenario: A minimal Order Term accepts real parent references and omitted optional fields.
-- Setup:    Insert the mandatory values and capture the generated identifier.
-- Expected: The ID is generated and nullable remittance/child/expiry fields are absent.
-- ---------------------------------------------------------------------------

SELECT lives_ok(
    $sql$WITH inserted AS (
        INSERT INTO public.order_terms (respondent_account_id, creditor_account_id, result_id,
                                    posted_date, imposed_date, imposed_amount, completed)
        SELECT r.respondent_account_id, c.creditor_account_id, f.result_id,
               TIMESTAMP '2026-01-01 12:00:00', TIMESTAMP '2026-01-01 12:00:00', 12.34, FALSE
        FROM cv_respondent r CROSS JOIN cv_creditor c CROSS JOIN cv_reference f
        RETURNING order_terms_id
    ) INSERT INTO cv_subject SELECT order_terms_id FROM inserted$sql$,
    'a minimal Order Term is accepted with a captured generated ID'
);

SELECT ok((SELECT id IS NOT NULL FROM cv_subject), 'the minimal Order Term receives a non-null generated ID');

SELECT ok((SELECT remitted_amount IS NULL AND child_name IS NULL AND child_birth_date IS NULL
                   AND expiry_date IS NULL AND expiry_terms IS NULL
       FROM public.order_terms WHERE order_terms_id = (SELECT id FROM cv_subject)),
     'ordinary publication leaves remittance and optional child/expiry metadata NULL');

-- ---------------------------------------------------------------------------
-- Scenario: Every column enforces its independently checked NULL contract.
-- Setup:    Update the captured valid row to NULL one column at a time.
-- Expected: Required values raise 23502 and every optional value accepts NULL.
-- ---------------------------------------------------------------------------

SELECT throws_ok(
    $sql$UPDATE public.order_terms SET order_terms_id = NULL
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    '23502', NULL, 'order_terms_id rejects NULL'
);

SELECT throws_ok(
    $sql$UPDATE public.order_terms SET respondent_account_id = NULL
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    '23502', NULL, 'respondent_account_id rejects NULL'
);

SELECT throws_ok(
    $sql$UPDATE public.order_terms SET creditor_account_id = NULL
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    '23502', NULL, 'creditor_account_id rejects NULL'
);

SELECT throws_ok(
    $sql$UPDATE public.order_terms SET result_id = NULL
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    '23502', NULL, 'result_id rejects NULL'
);

SELECT throws_ok(
    $sql$UPDATE public.order_terms SET posted_date = NULL
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    '23502', NULL, 'posted_date rejects NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.order_terms SET posted_by = NULL
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    'posted_by accepts NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.order_terms SET posted_by_name = NULL
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    'posted_by_name accepts NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.order_terms SET original_posted_date = NULL
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    'original_posted_date accepts NULL'
);

SELECT throws_ok(
    $sql$UPDATE public.order_terms SET imposed_date = NULL
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    '23502', NULL, 'imposed_date rejects NULL'
);

SELECT throws_ok(
    $sql$UPDATE public.order_terms SET imposed_amount = NULL
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    '23502', NULL, 'imposed_amount rejects NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.order_terms SET arrears_amount = NULL
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    'arrears_amount accepts NULL'
);

SELECT throws_ok(
    $sql$UPDATE public.order_terms SET completed = NULL
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    '23502', NULL, 'completed rejects NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.order_terms SET child_name = NULL
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    'child_name accepts NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.order_terms SET child_birth_date = NULL
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    'child_birth_date accepts NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.order_terms SET expiry_date = NULL
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    'expiry_date accepts NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.order_terms SET expiry_terms = NULL
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    'expiry_terms accepts NULL'
);

SELECT lives_ok(
    $sql$UPDATE public.order_terms SET remitted_amount = NULL
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    'remitted_amount accepts NULL'
);

-- ---------------------------------------------------------------------------
-- Scenario: All VARCHAR lengths are enforced without changing other integrity requirements.
-- Setup:    Use an existing six-character Result key and n/n+1 values for other text fields.
-- Expected: Exact limits are accepted; one extra character raises native 22001.
-- ---------------------------------------------------------------------------

SELECT lives_ok(
    $sql$UPDATE public.order_terms SET result_id = 'CVOT53'
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    'result_id accepts 6 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.order_terms SET result_id = repeat('X', 7)
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'result_id rejects 7 characters'
);

SELECT lives_ok(
    $sql$UPDATE public.order_terms SET posted_by = repeat('X', 20)
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    'posted_by accepts 20 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.order_terms SET posted_by = repeat('X', 21)
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'posted_by rejects 21 characters'
);

SELECT lives_ok(
    $sql$UPDATE public.order_terms SET posted_by_name = repeat('X', 100)
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    'posted_by_name accepts 100 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.order_terms SET posted_by_name = repeat('X', 101)
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'posted_by_name rejects 101 characters'
);

SELECT lives_ok(
    $sql$UPDATE public.order_terms SET child_name = repeat('X', 100)
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    'child_name accepts 100 characters'
);

SELECT throws_ok(
    $sql$UPDATE public.order_terms SET child_name = repeat('X', 101)
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'child_name rejects 101 characters'
);

-- ---------------------------------------------------------------------------
-- Scenario: Every supplied FK must name an existing parent.
-- Setup:    Prove the chosen missing keys are absent, then try valid and absent references.
-- Expected: Existing references succeed and each missing parent raises 23503.
-- ---------------------------------------------------------------------------

SELECT is((SELECT count(*) FROM public.respondent_accounts WHERE respondent_account_id = -20653),
     0::bigint, 'missing respondent_account_id fixture key is absent');

SELECT lives_ok(
    $sql$UPDATE public.order_terms SET respondent_account_id = (SELECT respondent_account_id FROM cv_respondent)
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    'an existing respondent_account_id reference is accepted'
);

SELECT throws_ok(
    $sql$UPDATE public.order_terms SET respondent_account_id = -20653
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    '23503', NULL, 'a missing respondent_account_id parent is rejected'
);

SELECT is((SELECT count(*) FROM public.creditor_accounts WHERE creditor_account_id = -30653),
     0::bigint, 'missing creditor_account_id fixture key is absent');

SELECT lives_ok(
    $sql$UPDATE public.order_terms SET creditor_account_id = (SELECT creditor_account_id FROM cv_creditor)
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    'an existing creditor_account_id reference is accepted'
);

SELECT throws_ok(
    $sql$UPDATE public.order_terms SET creditor_account_id = -30653
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    '23503', NULL, 'a missing creditor_account_id parent is rejected'
);

SELECT is((SELECT count(*) FROM public.results WHERE result_id = 'CVNONE'),
     0::bigint, 'missing result_id fixture key is absent');

SELECT lives_ok(
    $sql$UPDATE public.order_terms SET result_id = (SELECT result_id FROM cv_reference)
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    'an existing result_id reference is accepted'
);

SELECT throws_ok(
    $sql$UPDATE public.order_terms SET result_id = 'CVNONE'
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    '23503', NULL, 'a missing result_id parent is rejected'
);

-- ---------------------------------------------------------------------------
-- Scenario: Dedicated parent rows are protected only by this suite's Order Terms.
-- Setup:    Reference the synthetic Result; delete each suite-owned account or Result parent.
-- Expected: The three Order Terms FKs each raise 23503 without seeded-parent interference.
-- ---------------------------------------------------------------------------

SELECT lives_ok(
    $sql$WITH inserted AS (
        INSERT INTO public.order_terms (respondent_account_id, creditor_account_id, result_id,
                                    posted_date, imposed_date, imposed_amount, completed)
        SELECT r.respondent_account_id, c.creditor_account_id, 'CVOT53',
               TIMESTAMP '2026-01-01 12:00:00', TIMESTAMP '2026-01-01 12:00:00', 12.34, FALSE
        FROM cv_respondent r CROSS JOIN cv_creditor c CROSS JOIN cv_reference f
        RETURNING order_terms_id
    ) INSERT INTO cv_created (id, scenario) SELECT order_terms_id, 'result-child' FROM inserted$sql$,
    'a second Order Term refers to the dedicated synthetic Result'
);

SELECT throws_ok(
    $sql$DELETE FROM public.respondent_accounts WHERE respondent_account_id = (SELECT respondent_account_id FROM cv_respondent)$sql$,
    '23503', NULL, 'deleting the dedicated referenced Respondent Account is rejected'
);

SELECT throws_ok(
    $sql$DELETE FROM public.creditor_accounts WHERE creditor_account_id = (SELECT creditor_account_id FROM cv_creditor)$sql$,
    '23503', NULL, 'deleting the dedicated referenced Creditor Account is rejected'
);

SELECT throws_ok(
    $sql$DELETE FROM public.results WHERE result_id = 'CVOT53'$sql$,
    '23503', NULL, 'deleting the dedicated referenced Result is rejected'
);

-- ---------------------------------------------------------------------------
-- Scenario: A duplicate Order Terms primary key is rejected.
-- Setup:    Reuse the captured ID in an otherwise-valid insert.
-- Expected: The primary key raises native SQLSTATE 23505.
-- ---------------------------------------------------------------------------

SELECT throws_ok(
    $sql$INSERT INTO public.order_terms (order_terms_id, respondent_account_id, creditor_account_id, result_id,
                                    posted_date, imposed_date, imposed_amount, completed)
        SELECT s.id, r.respondent_account_id, c.creditor_account_id, f.result_id,
               TIMESTAMP '2026-01-01 12:00:00', TIMESTAMP '2026-01-01 12:00:00', 12.34, FALSE
        FROM cv_subject s CROSS JOIN cv_respondent r CROSS JOIN cv_creditor c CROSS JOIN cv_reference f$sql$,
    '23505', NULL, 'duplicate order_terms_id is rejected'
);

-- ---------------------------------------------------------------------------
-- Scenario: NUMERIC values retain exact fractional values and have no positivity CHECK.
-- Setup:    Write fractional and negative amounts to each numeric column.
-- Expected: Values persist exactly; malformed numeric inputs raise 22P02.
-- ---------------------------------------------------------------------------

SELECT lives_ok(
    $sql$UPDATE public.order_terms SET imposed_amount = 123456789012345678901234567890.12345678901234567890
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    'imposed_amount accepts an exact large fractional NUMERIC'
);

SELECT is((SELECT imposed_amount FROM public.order_terms WHERE order_terms_id = (SELECT id FROM cv_subject)),
     123456789012345678901234567890.12345678901234567890::numeric, 'imposed_amount retains the complete fractional value');

SELECT lives_ok(
    $sql$UPDATE public.order_terms SET imposed_amount = -12.34
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    'imposed_amount accepts a negative value without an invented positivity CHECK'
);

SELECT throws_ok(
    $sql$UPDATE public.order_terms SET imposed_amount = 'not-a-number'
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    '22P02', NULL, 'imposed_amount rejects malformed NUMERIC input'
);

SELECT lives_ok(
    $sql$UPDATE public.order_terms SET arrears_amount = 123456789012345678901234567890.12345678901234567890
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    'arrears_amount accepts an exact large fractional NUMERIC'
);

SELECT is((SELECT arrears_amount FROM public.order_terms WHERE order_terms_id = (SELECT id FROM cv_subject)),
     123456789012345678901234567890.12345678901234567890::numeric, 'arrears_amount retains the complete fractional value');

SELECT lives_ok(
    $sql$UPDATE public.order_terms SET arrears_amount = -12.34
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    'arrears_amount accepts a negative value without an invented positivity CHECK'
);

SELECT throws_ok(
    $sql$UPDATE public.order_terms SET arrears_amount = 'not-a-number'
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    '22P02', NULL, 'arrears_amount rejects malformed NUMERIC input'
);

SELECT lives_ok(
    $sql$UPDATE public.order_terms SET remitted_amount = 123456789012345678901234567890.12345678901234567890
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    'remitted_amount accepts an exact large fractional NUMERIC'
);

SELECT is((SELECT remitted_amount FROM public.order_terms WHERE order_terms_id = (SELECT id FROM cv_subject)),
     123456789012345678901234567890.12345678901234567890::numeric, 'remitted_amount retains the complete fractional value');

SELECT lives_ok(
    $sql$UPDATE public.order_terms SET remitted_amount = -12.34
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    'remitted_amount accepts a negative value without an invented positivity CHECK'
);

SELECT throws_ok(
    $sql$UPDATE public.order_terms SET remitted_amount = 'not-a-number'
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    '22P02', NULL, 'remitted_amount rejects malformed NUMERIC input'
);

-- ---------------------------------------------------------------------------
-- Scenario: Every TIMESTAMP field preserves a supplied UTC convention value.
-- Setup:    Write timestamps with time-of-day and fractional seconds, including child birth date.
-- Expected: Stored TIMESTAMP values are unchanged; malformed inputs raise native 22007.
-- ---------------------------------------------------------------------------

SELECT lives_ok(
    $sql$UPDATE public.order_terms SET posted_date = TIMESTAMP '2026-10-03 12:34:56.123456'
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    'posted_date accepts a TIMESTAMP with fractional seconds'
);

SELECT is((SELECT posted_date FROM public.order_terms WHERE order_terms_id = (SELECT id FROM cv_subject)),
     TIMESTAMP '2026-10-03 12:34:56.123456', 'posted_date retains the UTC convention value unchanged');

SELECT throws_ok(
    $sql$UPDATE public.order_terms SET posted_date = 'not-a-timestamp'
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    '22007', NULL, 'posted_date rejects malformed timestamp input'
);

SELECT lives_ok(
    $sql$UPDATE public.order_terms SET original_posted_date = TIMESTAMP '2026-10-03 12:34:56.123456'
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    'original_posted_date accepts a TIMESTAMP with fractional seconds'
);

SELECT is((SELECT original_posted_date FROM public.order_terms WHERE order_terms_id = (SELECT id FROM cv_subject)),
     TIMESTAMP '2026-10-03 12:34:56.123456', 'original_posted_date retains the UTC convention value unchanged');

SELECT throws_ok(
    $sql$UPDATE public.order_terms SET original_posted_date = 'not-a-timestamp'
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    '22007', NULL, 'original_posted_date rejects malformed timestamp input'
);

SELECT lives_ok(
    $sql$UPDATE public.order_terms SET imposed_date = TIMESTAMP '2026-10-03 12:34:56.123456'
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    'imposed_date accepts a TIMESTAMP with fractional seconds'
);

SELECT is((SELECT imposed_date FROM public.order_terms WHERE order_terms_id = (SELECT id FROM cv_subject)),
     TIMESTAMP '2026-10-03 12:34:56.123456', 'imposed_date retains the UTC convention value unchanged');

SELECT throws_ok(
    $sql$UPDATE public.order_terms SET imposed_date = 'not-a-timestamp'
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    '22007', NULL, 'imposed_date rejects malformed timestamp input'
);

SELECT lives_ok(
    $sql$UPDATE public.order_terms SET child_birth_date = TIMESTAMP '2026-10-03 12:34:56.123456'
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    'child_birth_date accepts a TIMESTAMP with fractional seconds'
);

SELECT is((SELECT child_birth_date FROM public.order_terms WHERE order_terms_id = (SELECT id FROM cv_subject)),
     TIMESTAMP '2026-10-03 12:34:56.123456', 'child_birth_date retains the UTC convention value unchanged');

SELECT throws_ok(
    $sql$UPDATE public.order_terms SET child_birth_date = 'not-a-timestamp'
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    '22007', NULL, 'child_birth_date rejects malformed timestamp input'
);

SELECT lives_ok(
    $sql$UPDATE public.order_terms SET expiry_date = TIMESTAMP '2026-10-03 12:34:56.123456'
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    'expiry_date accepts a TIMESTAMP with fractional seconds'
);

SELECT is((SELECT expiry_date FROM public.order_terms WHERE order_terms_id = (SELECT id FROM cv_subject)),
     TIMESTAMP '2026-10-03 12:34:56.123456', 'expiry_date retains the UTC convention value unchanged');

SELECT throws_ok(
    $sql$UPDATE public.order_terms SET expiry_date = 'not-a-timestamp'
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    '22007', NULL, 'expiry_date rejects malformed timestamp input'
);

-- ---------------------------------------------------------------------------
-- Scenario: Native BOOLEAN and BIGINT fields reject invalid inputs.
-- Setup:    Try malformed flags and the first integer above the BIGINT maximum.
-- Expected: Invalid booleans raise 22P02; overflow identifiers raise 22003.
-- ---------------------------------------------------------------------------

SELECT throws_ok(
    $sql$UPDATE public.order_terms SET completed = 'not-a-boolean'
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    '22P02', NULL, 'completed rejects malformed BOOLEAN input'
);

SELECT throws_ok(
    $sql$UPDATE public.order_terms SET expiry_terms = 'not-a-boolean'
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    '22P02', NULL, 'expiry_terms rejects malformed BOOLEAN input'
);

SELECT throws_ok(
    $sql$UPDATE public.order_terms SET order_terms_id = 9223372036854775808
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    '22003', NULL, 'order_terms_id rejects BIGINT overflow'
);

SELECT throws_ok(
    $sql$UPDATE public.order_terms SET respondent_account_id = 9223372036854775808
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    '22003', NULL, 'respondent_account_id rejects BIGINT overflow'
);

SELECT throws_ok(
    $sql$UPDATE public.order_terms SET creditor_account_id = 9223372036854775808
        WHERE order_terms_id = (SELECT id FROM cv_subject)$sql$,
    '22003', NULL, 'creditor_account_id rejects BIGINT overflow'
);

-- ---------------------------------------------------------------------------
-- Scenario: Independent successful insertions generate distinct Order Terms IDs.
-- Setup:    Compare the minimal and dedicated-Result child identifiers.
-- Expected: Both captured IDs are non-null and distinct; sequence gaps are allowed.
-- ---------------------------------------------------------------------------

SELECT ok((SELECT count(*) = 2 AND count(DISTINCT id) = 2 AND bool_and(id IS NOT NULL)
       FROM (SELECT id FROM cv_subject UNION ALL SELECT id FROM cv_created) generated),
     'both Order Terms have distinct non-null sequence-generated identifiers');

-- ---------------------------------------------------------------------------
-- Scenario: The caller can see a complete live graph before choosing to roll it back.
-- Setup:    Capture counts and reference/config before-images; use only plain DML inside one savepoint.
-- Expected: Generated IDs form the declared FK graph; observations survive rollback in psql variables.
-- ---------------------------------------------------------------------------

SELECT
    (SELECT count(*) FROM public.parties) AS parties,
    (SELECT count(*) FROM public.debtor_detail) AS debtor_detail,
    (SELECT count(*) FROM public.third_party_contact) AS third_party_contact,
    (SELECT count(*) FROM public.account_number_index) AS account_number_index,
    (SELECT count(*) FROM public.respondent_accounts) AS respondent_accounts,
    (SELECT count(*) FROM public.creditor_accounts) AS creditor_accounts,
    (SELECT count(*) FROM public.respondent_account_parties) AS respondent_account_parties,
    (SELECT count(*) FROM public.order_terms) AS order_terms,
    (SELECT count(*) FROM public.notes) AS notes,
    (SELECT count(*) FROM public.draft_casefiles) AS draft_casefiles,
    (SELECT count(*) FROM public.business_units) AS business_units,
    (SELECT count(*) FROM public.countries) AS countries,
    (SELECT count(*) FROM public.maintenance_applications) AS maintenance_applications,
    (SELECT count(*) FROM public.results) AS results,
    (SELECT count(*) FROM public.major_creditors) AS major_creditors,
    (SELECT count(*) FROM public.configuration_items) AS configuration_items
\gset cv_before_

SELECT
    (SELECT COALESCE(jsonb_agg(to_jsonb(reference_row) ORDER BY reference_row.business_unit_id), '[]'::jsonb)::text
     FROM public.business_units reference_row) AS business_units,
    (SELECT COALESCE(jsonb_agg(to_jsonb(reference_row) ORDER BY reference_row.country_id), '[]'::jsonb)::text
     FROM public.countries reference_row) AS countries,
    (SELECT COALESCE(jsonb_agg(to_jsonb(reference_row) ORDER BY reference_row.application_id), '[]'::jsonb)::text
     FROM public.maintenance_applications reference_row) AS maintenance_applications,
    (SELECT COALESCE(jsonb_agg(to_jsonb(reference_row) ORDER BY reference_row.result_id), '[]'::jsonb)::text
     FROM public.results reference_row) AS results,
    (SELECT COALESCE(jsonb_agg(to_jsonb(reference_row) ORDER BY reference_row.major_creditor_id), '[]'::jsonb)::text
     FROM public.major_creditors reference_row) AS major_creditors,
    (SELECT COALESCE(jsonb_agg(to_jsonb(reference_row) ORDER BY reference_row.configuration_item_id), '[]'::jsonb)::text
     FROM public.configuration_items reference_row) AS configuration_items
\gset cv_ref_before_

SELECT item_value::smallint AS cheque_clearance_period
FROM public.configuration_items
WHERE item_name = 'DEFAULT_CHEQUE_CLEARANCE_PERIOD' AND business_unit_id IS NULL
\gset cv_config_
SELECT item_value::smallint AS credit_trans_clearance_period
FROM public.configuration_items
WHERE item_name = 'DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD' AND business_unit_id IS NULL
\gset cv_config_
SAVEPOINT cv_live_graph;

INSERT INTO public.parties (address_line_1, restrict_personal_information, country_id)
SELECT 'Synthetic rollback address', FALSE, country_id FROM cv_reference
RETURNING party_id
\gset cv_graph_

INSERT INTO public.debtor_detail (employer_name, employer_address_line_1, employer_country_id, other_personal_information)
SELECT 'Synthetic graph employer', 'Synthetic employer address', country_id, 'Synthetic graph information'
FROM cv_reference
RETURNING debtor_detail_id
\gset cv_graph_

INSERT INTO public.third_party_contact (name_organisation, relationship, address_line_1, country)
SELECT 'Synthetic graph contact', 'Synthetic graph relationship', 'Synthetic graph address', country_id
FROM cv_reference
RETURNING third_party_contact_id
\gset cv_graph_

INSERT INTO public.account_number_index (business_unit_id, account_number, associated_record_type)
VALUES (32061, 'CV-LIVE-GRAPH', 'respondent_accounts')
RETURNING account_number_index_id
\gset cv_graph_

INSERT INTO public.respondent_accounts (
    business_unit_id, debtor_detail_id, account_number, application_id, account_balance,
    orders_balance, orders_amount, payment_period, total_arrears, account_status,
    last_movement_date, date_arrears_last_updated, allow_cheques, cheque_clearance_period,
    credit_trans_clearance_period, casefile_type, third_party_contact_id, interest_flag,
    indexation, payment_arrangement, version_number
)
SELECT 32061, :'cv_graph_debtor_detail_id'::bigint, 'CV-LIVE-GRAPH', application_id, 0,
       0, 0, 'Weekly', 0, 'L', TIMESTAMP '2026-01-01 12:00:00',
       TIMESTAMP '2026-01-01 12:00:00', TRUE, :'cv_config_cheque_clearance_period'::smallint,
       :'cv_config_credit_trans_clearance_period'::smallint, 'REMO In',
       :'cv_graph_third_party_contact_id'::bigint, FALSE, 'None', 'Court', 1
FROM cv_reference
RETURNING respondent_account_id
\gset cv_graph_

INSERT INTO public.creditor_accounts (
    business_unit_id, account_number, creditor_account_type, minor_creditor_party_id,
    from_suspense, hold_payout, pay_by_bacs, third_party_contact_id, version_number
)
VALUES (32061, 'CV-LIVE-GRAPH', 'MN', :'cv_graph_party_id'::bigint, FALSE, FALSE, FALSE,
        :'cv_graph_third_party_contact_id'::bigint, 1)
RETURNING creditor_account_id
\gset cv_graph_

INSERT INTO public.respondent_account_parties (respondent_account_id, associated_account_id, association_type)
VALUES (:'cv_graph_respondent_account_id'::bigint, :'cv_graph_party_id'::bigint, 'Respondent')
RETURNING respondent_account_party_id
\gset cv_graph_

INSERT INTO public.order_terms (
    respondent_account_id, creditor_account_id, result_id, posted_date, imposed_date, imposed_amount, completed
)
SELECT :'cv_graph_respondent_account_id'::bigint, :'cv_graph_creditor_account_id'::bigint, result_id,
       TIMESTAMP '2026-01-01 12:00:00', TIMESTAMP '2026-01-01 12:00:00', 12.34, FALSE
FROM cv_reference
RETURNING order_terms_id
\gset cv_graph_

INSERT INTO public.notes (
    note_type, associated_record_type, associated_record_id, note_text, posted_date
)
VALUES ('NT', 'respondent_accounts', :'cv_graph_respondent_account_id',
        'Synthetic graph note', TIMESTAMP '2026-01-01 12:00:00')
RETURNING note_id
\gset cv_graph_

INSERT INTO public.draft_casefiles (
    business_unit_id, created_date, submitted_by, submitted_by_name, casefile, casefile_snapshot,
    casefile_type, casefile_status, casefile_status_date, timeline_data, account_number, account_id, version_number
)
VALUES (32061, TIMESTAMP '2026-01-01 12:00:00', 'Synthetic user', 'Synthetic submitter', '{}', '{}',
        'REMO In', 'PUBLISHED', TIMESTAMP '2026-01-01 12:00:00', '[]', 'CV-LIVE-GRAPH',
        :'cv_graph_respondent_account_id'::bigint, 1)
RETURNING draft_casefile_id
\gset cv_graph_

SELECT
    (SELECT count(*) = 1 FROM public.parties WHERE party_id = :'cv_graph_party_id'::bigint) AS parties,
    (SELECT count(*) = 1 FROM public.debtor_detail WHERE debtor_detail_id = :'cv_graph_debtor_detail_id'::bigint) AS debtor_detail,
    (SELECT count(*) = 1 FROM public.third_party_contact WHERE third_party_contact_id = :'cv_graph_third_party_contact_id'::bigint) AS third_party_contact,
    (SELECT count(*) = 1 FROM public.account_number_index WHERE account_number_index_id = :'cv_graph_account_number_index_id'::bigint) AS account_number_index,
    (SELECT count(*) = 1 FROM public.respondent_accounts WHERE respondent_account_id = :'cv_graph_respondent_account_id'::bigint) AS respondent_accounts,
    (SELECT count(*) = 1 FROM public.creditor_accounts WHERE creditor_account_id = :'cv_graph_creditor_account_id'::bigint) AS creditor_accounts,
    (SELECT count(*) = 1 FROM public.respondent_account_parties WHERE respondent_account_party_id = :'cv_graph_respondent_account_party_id'::bigint) AS respondent_account_parties,
    (SELECT count(*) = 1 FROM public.order_terms WHERE order_terms_id = :'cv_graph_order_terms_id'::bigint) AS order_terms,
    (SELECT count(*) = 1 FROM public.notes WHERE note_id = :'cv_graph_note_id'::bigint) AS notes,
    (SELECT count(*) = 1 FROM public.draft_casefiles WHERE draft_casefile_id = :'cv_graph_draft_casefile_id'::bigint) AS draft_casefiles
\gset cv_visible_

SELECT
    (SELECT count(*) = 1
     FROM public.order_terms term
     JOIN public.respondent_accounts respondent ON respondent.respondent_account_id = term.respondent_account_id
     JOIN public.creditor_accounts creditor ON creditor.creditor_account_id = term.creditor_account_id
     JOIN public.results result ON result.result_id = term.result_id
     JOIN public.debtor_detail detail ON detail.debtor_detail_id = respondent.debtor_detail_id
     JOIN public.third_party_contact respondent_contact
       ON respondent_contact.third_party_contact_id = respondent.third_party_contact_id
     JOIN public.third_party_contact creditor_contact
       ON creditor_contact.third_party_contact_id = creditor.third_party_contact_id
     JOIN public.parties party ON party.party_id = creditor.minor_creditor_party_id
     JOIN public.countries country ON country.country_id = party.country_id
     JOIN public.countries employer_country ON employer_country.country_id = detail.employer_country_id
     JOIN public.business_units unit ON unit.business_unit_id = respondent.business_unit_id
     JOIN public.business_units creditor_unit ON creditor_unit.business_unit_id = creditor.business_unit_id
     JOIN public.maintenance_applications application ON application.application_id = respondent.application_id
     JOIN public.respondent_account_parties association
       ON association.respondent_account_id = respondent.respondent_account_id
     JOIN public.draft_casefiles casefile ON casefile.account_id = respondent.respondent_account_id
     WHERE term.order_terms_id = :'cv_graph_order_terms_id'::bigint
       AND detail.debtor_detail_id = :'cv_graph_debtor_detail_id'::bigint
       AND party.party_id = :'cv_graph_party_id'::bigint
       AND respondent_contact.third_party_contact_id = :'cv_graph_third_party_contact_id'::bigint
       AND creditor_contact.third_party_contact_id = :'cv_graph_third_party_contact_id'::bigint
       AND association.respondent_account_party_id = :'cv_graph_respondent_account_party_id'::bigint
       AND casefile.draft_casefile_id = :'cv_graph_draft_casefile_id'::bigint) AS declared_fk_graph,
    (SELECT respondent.account_number = creditor.account_number
     FROM public.respondent_accounts respondent CROSS JOIN public.creditor_accounts creditor
     WHERE respondent.respondent_account_id = :'cv_graph_respondent_account_id'::bigint
       AND creditor.creditor_account_id = :'cv_graph_creditor_account_id'::bigint) AS same_account_number,
    (SELECT cheque_clearance_period = :'cv_config_cheque_clearance_period'::smallint
        AND credit_trans_clearance_period = :'cv_config_credit_trans_clearance_period'::smallint
     FROM public.respondent_accounts WHERE respondent_account_id = :'cv_graph_respondent_account_id'::bigint)
        AS supplied_configuration,
    (SELECT allocation.business_unit_id = respondent.business_unit_id
        AND allocation.account_number = respondent.account_number
        AND allocation.associated_record_type = 'respondent_accounts'
        AND note.associated_record_type = 'respondent_accounts'
        AND note.associated_record_id = respondent.respondent_account_id::text
        AND association.associated_account_id = :'cv_graph_party_id'::bigint
     FROM public.account_number_index allocation CROSS JOIN public.respondent_accounts respondent
     CROSS JOIN public.notes note CROSS JOIN public.respondent_account_parties association
     WHERE allocation.account_number_index_id = :'cv_graph_account_number_index_id'::bigint
       AND respondent.respondent_account_id = :'cv_graph_respondent_account_id'::bigint
       AND note.note_id = :'cv_graph_note_id'::bigint
       AND association.respondent_account_party_id = :'cv_graph_respondent_account_party_id'::bigint)
        AS unconstrained_correlations,
    EXISTS (SELECT 1 FROM pg_constraint
            WHERE conrelid = 'public.draft_casefiles'::regclass AND conname = 'dcf_account_id_fk'
              AND contype = 'f' AND confrelid = 'public.respondent_accounts'::regclass) AS casefile_fk
\gset cv_observed_

ROLLBACK TO SAVEPOINT cv_live_graph;
RELEASE SAVEPOINT cv_live_graph;

-- ---------------------------------------------------------------------------
-- Scenario: Only post-rollback TAP reports the saved graph observations.
-- Setup:    Use psql variables captured before ROLLBACK TO; TAP state was never changed inside the savepoint.
-- Expected: The caller saw all rows and declared relationships before its rollback.
-- ---------------------------------------------------------------------------

SELECT ok(:'cv_visible_parties'::boolean, 'the caller saw its uncommitted parties row');

SELECT ok(:'cv_visible_debtor_detail'::boolean, 'the caller saw its uncommitted debtor_detail row');

SELECT ok(:'cv_visible_third_party_contact'::boolean, 'the caller saw its uncommitted third_party_contact row');

SELECT ok(:'cv_visible_account_number_index'::boolean, 'the caller saw its uncommitted account_number_index row');

SELECT ok(:'cv_visible_respondent_accounts'::boolean, 'the caller saw its uncommitted respondent_accounts row');

SELECT ok(:'cv_visible_creditor_accounts'::boolean, 'the caller saw its uncommitted creditor_accounts row');

SELECT ok(:'cv_visible_respondent_account_parties'::boolean, 'the caller saw its uncommitted respondent_account_parties row');

SELECT ok(:'cv_visible_order_terms'::boolean, 'the caller saw its uncommitted order_terms row');

SELECT ok(:'cv_visible_notes'::boolean, 'the caller saw its uncommitted notes row');

SELECT ok(:'cv_visible_draft_casefiles'::boolean, 'the caller saw its uncommitted draft_casefiles row');

SELECT ok(:'cv_observed_declared_fk_graph'::boolean, 'captured generated IDs join through the actual declared FK graph');

SELECT ok(:'cv_observed_same_account_number'::boolean, 'Respondent and Creditor Accounts accept the same account-number text');

SELECT ok(:'cv_observed_supplied_configuration'::boolean, 'the fixture explicitly supplied both approved global clearance values');

SELECT ok(:'cv_observed_unconstrained_correlations'::boolean, 'ANI and polymorphic targets retain the supplied correlations without an invented FK');

SELECT ok(:'cv_observed_casefile_fk'::boolean, 'the linked Draft Casefile uses the delivered Respondent Account FK');

-- ---------------------------------------------------------------------------
-- Scenario: Caller rollback removes each generated graph row.
-- Setup:    Check every captured ID and restore each pre-savepoint table count.
-- Expected: All ten graph rows disappear; previously present rows remain.
-- ---------------------------------------------------------------------------

SELECT is((SELECT count(*) FROM public.parties WHERE party_id = :'cv_graph_party_id'::bigint),
     0::bigint, 'caller rollback removed the generated parties row');

SELECT is((SELECT count(*) FROM public.parties), :'cv_before_parties'::bigint,
     'caller rollback restored the parties before count');

SELECT is((SELECT count(*) FROM public.debtor_detail WHERE debtor_detail_id = :'cv_graph_debtor_detail_id'::bigint),
     0::bigint, 'caller rollback removed the generated debtor_detail row');

SELECT is((SELECT count(*) FROM public.debtor_detail), :'cv_before_debtor_detail'::bigint,
     'caller rollback restored the debtor_detail before count');

SELECT is((SELECT count(*) FROM public.third_party_contact WHERE third_party_contact_id = :'cv_graph_third_party_contact_id'::bigint),
     0::bigint, 'caller rollback removed the generated third_party_contact row');

SELECT is((SELECT count(*) FROM public.third_party_contact), :'cv_before_third_party_contact'::bigint,
     'caller rollback restored the third_party_contact before count');

SELECT is((SELECT count(*) FROM public.account_number_index WHERE account_number_index_id = :'cv_graph_account_number_index_id'::bigint),
     0::bigint, 'caller rollback removed the generated account_number_index row');

SELECT is((SELECT count(*) FROM public.account_number_index), :'cv_before_account_number_index'::bigint,
     'caller rollback restored the account_number_index before count');

SELECT is((SELECT count(*) FROM public.respondent_accounts WHERE respondent_account_id = :'cv_graph_respondent_account_id'::bigint),
     0::bigint, 'caller rollback removed the generated respondent_accounts row');

SELECT is((SELECT count(*) FROM public.respondent_accounts), :'cv_before_respondent_accounts'::bigint,
     'caller rollback restored the respondent_accounts before count');

SELECT is((SELECT count(*) FROM public.creditor_accounts WHERE creditor_account_id = :'cv_graph_creditor_account_id'::bigint),
     0::bigint, 'caller rollback removed the generated creditor_accounts row');

SELECT is((SELECT count(*) FROM public.creditor_accounts), :'cv_before_creditor_accounts'::bigint,
     'caller rollback restored the creditor_accounts before count');

SELECT is((SELECT count(*) FROM public.respondent_account_parties WHERE respondent_account_party_id = :'cv_graph_respondent_account_party_id'::bigint),
     0::bigint, 'caller rollback removed the generated respondent_account_parties row');

SELECT is((SELECT count(*) FROM public.respondent_account_parties), :'cv_before_respondent_account_parties'::bigint,
     'caller rollback restored the respondent_account_parties before count');

SELECT is((SELECT count(*) FROM public.order_terms WHERE order_terms_id = :'cv_graph_order_terms_id'::bigint),
     0::bigint, 'caller rollback removed the generated order_terms row');

SELECT is((SELECT count(*) FROM public.order_terms), :'cv_before_order_terms'::bigint,
     'caller rollback restored the order_terms before count');

SELECT is((SELECT count(*) FROM public.notes WHERE note_id = :'cv_graph_note_id'::bigint),
     0::bigint, 'caller rollback removed the generated notes row');

SELECT is((SELECT count(*) FROM public.notes), :'cv_before_notes'::bigint,
     'caller rollback restored the notes before count');

SELECT is((SELECT count(*) FROM public.draft_casefiles WHERE draft_casefile_id = :'cv_graph_draft_casefile_id'::bigint),
     0::bigint, 'caller rollback removed the generated draft_casefiles row');

SELECT is((SELECT count(*) FROM public.draft_casefiles), :'cv_before_draft_casefiles'::bigint,
     'caller rollback restored the draft_casefiles before count');

-- ---------------------------------------------------------------------------
-- Scenario: Caller rollback preserves reference and configuration state exactly.
-- Setup:    Compare pre-savepoint row counts and JSONB before-images for all six untouched relations.
-- Expected: Existing reference/configuration keys, identifiers and values are unchanged.
-- ---------------------------------------------------------------------------

SELECT is((SELECT count(*) FROM public.business_units), :'cv_before_business_units'::bigint,
     'business_units reference/configuration row count is unchanged');

SELECT is((SELECT COALESCE(jsonb_agg(to_jsonb(reference_row) ORDER BY reference_row.business_unit_id), '[]'::jsonb)
      FROM public.business_units reference_row), :'cv_ref_before_business_units'::jsonb,
     'business_units reference/configuration before-image is unchanged');

SELECT is((SELECT count(*) FROM public.countries), :'cv_before_countries'::bigint,
     'countries reference/configuration row count is unchanged');

SELECT is((SELECT COALESCE(jsonb_agg(to_jsonb(reference_row) ORDER BY reference_row.country_id), '[]'::jsonb)
      FROM public.countries reference_row), :'cv_ref_before_countries'::jsonb,
     'countries reference/configuration before-image is unchanged');

SELECT is((SELECT count(*) FROM public.maintenance_applications), :'cv_before_maintenance_applications'::bigint,
     'maintenance_applications reference/configuration row count is unchanged');

SELECT is((SELECT COALESCE(jsonb_agg(to_jsonb(reference_row) ORDER BY reference_row.application_id), '[]'::jsonb)
      FROM public.maintenance_applications reference_row), :'cv_ref_before_maintenance_applications'::jsonb,
     'maintenance_applications reference/configuration before-image is unchanged');

SELECT is((SELECT count(*) FROM public.results), :'cv_before_results'::bigint,
     'results reference/configuration row count is unchanged');

SELECT is((SELECT COALESCE(jsonb_agg(to_jsonb(reference_row) ORDER BY reference_row.result_id), '[]'::jsonb)
      FROM public.results reference_row), :'cv_ref_before_results'::jsonb,
     'results reference/configuration before-image is unchanged');

SELECT is((SELECT count(*) FROM public.major_creditors), :'cv_before_major_creditors'::bigint,
     'major_creditors reference/configuration row count is unchanged');

SELECT is((SELECT COALESCE(jsonb_agg(to_jsonb(reference_row) ORDER BY reference_row.major_creditor_id), '[]'::jsonb)
      FROM public.major_creditors reference_row), :'cv_ref_before_major_creditors'::jsonb,
     'major_creditors reference/configuration before-image is unchanged');

SELECT is((SELECT count(*) FROM public.configuration_items), :'cv_before_configuration_items'::bigint,
     'configuration_items reference/configuration row count is unchanged');

SELECT is((SELECT COALESCE(jsonb_agg(to_jsonb(reference_row) ORDER BY reference_row.configuration_item_id), '[]'::jsonb)
      FROM public.configuration_items reference_row), :'cv_ref_before_configuration_items'::jsonb,
     'configuration_items reference/configuration before-image is unchanged');

-- ---------------------------------------------------------------------------
-- Scenario: A failed child insert leaves prior fixtures intact until caller rollback.
-- Setup:    Capture account and Order Terms before-images, then inject a known-missing Respondent parent.
-- Expected: The insert raises 23503 and changes none of the previously inserted fixture rows.
-- ---------------------------------------------------------------------------

CREATE TEMP TABLE cv_failure_before AS
SELECT jsonb_build_object(
    'respondent', (SELECT to_jsonb(fixture_row) FROM public.respondent_accounts fixture_row
                   WHERE respondent_account_id = (SELECT respondent_account_id FROM cv_respondent)),
    'creditor', (SELECT to_jsonb(fixture_row) FROM public.creditor_accounts fixture_row
                 WHERE creditor_account_id = (SELECT creditor_account_id FROM cv_creditor)),
    'terms', (SELECT jsonb_agg(to_jsonb(fixture_row) ORDER BY order_terms_id) FROM public.order_terms fixture_row
              WHERE order_terms_id IN (SELECT id FROM cv_subject UNION ALL SELECT id FROM cv_created))
) AS image;

SELECT throws_ok(
    $sql$INSERT INTO public.order_terms (
        respondent_account_id, creditor_account_id, result_id, posted_date, imposed_date, imposed_amount, completed
    )
    SELECT -20653, c.creditor_account_id, f.result_id,
           TIMESTAMP '2026-01-01 12:00:00', TIMESTAMP '2026-01-01 12:00:00', 12.34, FALSE
    FROM cv_creditor c CROSS JOIN cv_reference f$sql$,
    '23503', NULL, 'an injected missing Order Terms parent is rejected'
);

SELECT is(
    jsonb_build_object(
        'respondent', (SELECT to_jsonb(fixture_row) FROM public.respondent_accounts fixture_row
                       WHERE respondent_account_id = (SELECT respondent_account_id FROM cv_respondent)),
        'creditor', (SELECT to_jsonb(fixture_row) FROM public.creditor_accounts fixture_row
                     WHERE creditor_account_id = (SELECT creditor_account_id FROM cv_creditor)),
        'terms', (SELECT jsonb_agg(to_jsonb(fixture_row) ORDER BY order_terms_id) FROM public.order_terms fixture_row
                  WHERE order_terms_id IN (SELECT id FROM cv_subject UNION ALL SELECT id FROM cv_created))
    ),
    (SELECT image FROM cv_failure_before),
    'the failed Order Terms statement preserves all previously inserted fixture rows'
);

SELECT * FROM finish();
ROLLBACK;
