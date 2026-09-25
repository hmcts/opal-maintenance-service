BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;

SELECT plan(91);

-- All assertions apply to fresh DB-01; catalog and behavioural assertions also
-- describe the required post-upgrade state, but the current Gradle dbUnitTest task does not execute DB-03.

-- ---------------------------------------------------------------------------
-- Scenario: The public schema and promoted Result enum are available.
-- Setup:    Inspect the schema, enum object, and its ordered labels.
-- Expected: public contains t_case_result_type_enum with the promoted values.
-- ---------------------------------------------------------------------------
SELECT has_schema('public', 'public schema exists');
SELECT ok(
    EXISTS (
        SELECT 1
        FROM pg_type
        JOIN pg_namespace ON pg_namespace.oid = pg_type.typnamespace
        WHERE pg_namespace.nspname = 'public'
          AND pg_type.typname = 't_case_result_type_enum'
          AND pg_type.typtype = 'e'
    ),
    'public.t_case_result_type_enum exists as an enum'
);
SELECT is(
    (
        SELECT array_agg(pg_enum.enumlabel::text ORDER BY pg_enum.enumsortorder)
        FROM pg_enum
        JOIN pg_type ON pg_type.oid = pg_enum.enumtypid
        JOIN pg_namespace ON pg_namespace.oid = pg_type.typnamespace
        WHERE pg_namespace.nspname = 'public'
          AND pg_type.typname = 't_case_result_type_enum'
    ),
    ARRAY['Ancillary', 'Interim', 'Final']::text[],
    't_case_result_type_enum has exactly the promoted values in order'
);

-- ---------------------------------------------------------------------------
-- Scenario: The Result table matches the promoted physical contract.
-- Setup:    Inspect its existence, ordered columns, types, and nullability.
-- Expected: Exactly 20 columns match the promoted schema.
-- ---------------------------------------------------------------------------
SELECT has_table('public', 'results', 'public.results exists');
SELECT is(
    (
        SELECT array_agg(column_name::text ORDER BY ordinal_position)
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'results'
    ),
    ARRAY[
        'result_id', 'result_title', 'order_term', 'enforcement_result',
        'case_result', 'case_result_type', 'active', 'order_accruing',
        'requires_creditor', 'enforcement_hold', 'requires_enforcer',
        'generates_hearing', 'generates_warrant', 'lists_monies',
        'result_parameters', 'requires_employment_data',
        'allow_additional_action', 'enf_next_permitted_actions',
        'manual_enforcement', 'auto_enforcement'
    ]::text[],
    'results has exactly the promoted columns in order'
);
SELECT col_type_is('public', 'results', 'result_id', 'varchar(6)', 'result_id is varchar(6)');
SELECT col_type_is('public', 'results', 'result_title', 'varchar(60)', 'result_title is varchar(60)');
SELECT col_type_is('public', 'results', 'order_term', 'boolean', 'order_term is boolean');
SELECT col_type_is('public', 'results', 'enforcement_result', 'boolean', 'enforcement_result is boolean');
SELECT col_type_is('public', 'results', 'case_result', 'boolean', 'case_result is boolean');
SELECT col_type_is('public', 'results', 'case_result_type', 't_case_result_type_enum', 'case_result_type uses t_case_result_type_enum');
SELECT col_type_is('public', 'results', 'active', 'boolean', 'active is boolean');
SELECT col_type_is('public', 'results', 'order_accruing', 'boolean', 'order_accruing is boolean');
SELECT col_type_is('public', 'results', 'requires_creditor', 'boolean', 'requires_creditor is boolean');
SELECT col_type_is('public', 'results', 'enforcement_hold', 'boolean', 'enforcement_hold is boolean');
SELECT col_type_is('public', 'results', 'requires_enforcer', 'boolean', 'requires_enforcer is boolean');
SELECT col_type_is('public', 'results', 'generates_hearing', 'boolean', 'generates_hearing is boolean');
SELECT col_type_is('public', 'results', 'generates_warrant', 'boolean', 'generates_warrant is boolean');
SELECT col_type_is('public', 'results', 'lists_monies', 'boolean', 'lists_monies is boolean');
SELECT col_type_is('public', 'results', 'result_parameters', 'json', 'result_parameters is json');
SELECT col_type_is('public', 'results', 'requires_employment_data', 'boolean', 'requires_employment_data is boolean');
SELECT col_type_is('public', 'results', 'allow_additional_action', 'boolean', 'allow_additional_action is boolean');
SELECT col_type_is('public', 'results', 'enf_next_permitted_actions', 'varchar(100)', 'enf_next_permitted_actions is varchar(100)');
SELECT col_type_is('public', 'results', 'manual_enforcement', 'boolean', 'manual_enforcement is boolean');
SELECT col_type_is('public', 'results', 'auto_enforcement', 'boolean', 'auto_enforcement is boolean');
SELECT col_not_null('public', 'results', 'result_id', 'result_id is not nullable');
SELECT col_not_null('public', 'results', 'result_title', 'result_title is not nullable');
SELECT col_not_null('public', 'results', 'order_term', 'order_term is not nullable');
SELECT col_not_null('public', 'results', 'enforcement_result', 'enforcement_result is not nullable');
SELECT col_not_null('public', 'results', 'case_result', 'case_result is not nullable');
SELECT col_is_null('public', 'results', 'case_result_type', 'case_result_type is nullable');
SELECT col_not_null('public', 'results', 'active', 'active is not nullable');
SELECT col_not_null('public', 'results', 'order_accruing', 'order_accruing is not nullable');
SELECT col_not_null('public', 'results', 'requires_creditor', 'requires_creditor is not nullable');
SELECT col_not_null('public', 'results', 'enforcement_hold', 'enforcement_hold is not nullable');
SELECT col_not_null('public', 'results', 'requires_enforcer', 'requires_enforcer is not nullable');
SELECT col_not_null('public', 'results', 'generates_hearing', 'generates_hearing is not nullable');
SELECT col_not_null('public', 'results', 'generates_warrant', 'generates_warrant is not nullable');
SELECT col_not_null('public', 'results', 'lists_monies', 'lists_monies is not nullable');
SELECT col_is_null('public', 'results', 'result_parameters', 'result_parameters is nullable');
SELECT col_not_null('public', 'results', 'requires_employment_data', 'requires_employment_data is not nullable');
SELECT col_not_null('public', 'results', 'allow_additional_action', 'allow_additional_action is not nullable');
SELECT col_not_null('public', 'results', 'enf_next_permitted_actions', 'enf_next_permitted_actions is not nullable');
SELECT col_not_null('public', 'results', 'manual_enforcement', 'manual_enforcement is not nullable');
SELECT col_not_null('public', 'results', 'auto_enforcement', 'auto_enforcement is not nullable');

-- ---------------------------------------------------------------------------
-- Scenario: Result comments and identifiers retain the TDIA contract.
-- Setup:    Inspect comments, identifier generation, and owned sequences.
-- Expected: Verbatim comments; result_id is supplied and no sequence is owned.
-- ---------------------------------------------------------------------------
SELECT is(
    (
        SELECT array_agg(
            col_description(table_attribute.attrelid, table_attribute.attnum)
            ORDER BY table_attribute.attnum
        )
        FROM pg_attribute table_attribute
        WHERE table_attribute.attrelid = 'public.results'::regclass
          AND table_attribute.attnum > 0
          AND table_attribute.attisdropped IS FALSE
    ),
    ARRAY[
        'Primary/business key for the Result',
        'Result title presented for selection',
        'Whether the Result creates or affects an Order Term',
        'Whether the record is an enforcement action',
        'Classifies whether the record is a hearing result',
        'Case-lifecycle classification: Ancillary, Interim or Final',
        'Whether the Result can be selected for new accounts',
        'Whether the Order Term accrues over time',
        'Indicates that on applying the result, a creditor must be selected',
        'Indicates if this action places a hold on enforcement',
        'Whether the user must also specify an enforcer',
        'Whether applying the action can schedule an enforcement hearing',
        'Indicates if a warrant needs to be generated as part of this result',
        'This result will cause the account to be reported on List Monies Under Warrant if a payment is received while this is the last enforcement action on the account',
        'Metadata for the dynamic fields required when applying the Result',
        'Flag to state that the enforcement action requires employment data to exist on the account in order to apply the action',
        'Flag to state which enforcement actions allow the user to add another enforcement action in the same journey as applying the action (WDN) or removing the action (NOENF)',
        'A comma separated list of result_ids of permitted next actions for each active manual enforcement action. If value is “All”, then allow all result_ids.',
        'Flag to state that the result can be used as a manual enforcement',
        'Flag to state that the result can be used as an auto-enforcement on an [Enforcement Path]'
    ]::text[],
    'column comments match the verbatim TDIA descriptions in column order'
);
SELECT is((SELECT column_default FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'results' AND column_name = 'result_id'), NULL, 'result_id has no generated default');
SELECT is((SELECT is_identity FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'results' AND column_name = 'result_id'), 'NO', 'result_id is not an identity column');
SELECT ok(NOT EXISTS (SELECT 1 FROM pg_depend JOIN pg_class ON pg_class.oid = pg_depend.objid WHERE pg_depend.classid = 'pg_class'::regclass AND pg_depend.refclassid = 'pg_class'::regclass AND pg_depend.refobjid = 'public.results'::regclass AND pg_depend.deptype IN ('a', 'i') AND pg_class.relkind = 'S'), 'results owns no sequence');

-- ---------------------------------------------------------------------------
-- Scenario: Result keys and lookup index have the approved shape.
-- Setup:    Inspect constraints and the named index catalog entries.
-- Expected: results_pk, one non-unique ordered lookup index, and no FK.
-- ---------------------------------------------------------------------------
SELECT has_pk('public', 'results', 'results has a primary key');
SELECT col_is_pk('public', 'results', 'result_id', 'result_id is the primary key');
SELECT ok(EXISTS (SELECT 1 FROM pg_constraint table_constraint WHERE table_constraint.conrelid = 'public.results'::regclass AND table_constraint.conname = 'results_pk' AND table_constraint.contype = 'p'), 'the primary key is named results_pk');
SELECT has_index('public', 'results', 'results_order_term_active_idx', ARRAY['order_term', 'active'], 'the results filter index covers order_term then active');
SELECT is((SELECT index_definition.indisunique FROM pg_index index_definition JOIN pg_class index_relation ON index_relation.oid = index_definition.indexrelid JOIN pg_namespace index_namespace ON index_namespace.oid = index_relation.relnamespace WHERE index_namespace.nspname = 'public' AND index_relation.relname = 'results_order_term_active_idx'), FALSE, 'the results filter index is not unique');
SELECT is((SELECT count(*) FROM pg_constraint WHERE conrelid = 'public.results'::regclass AND contype = 'f'), 0::bigint, 'results has no foreign key');
-- ---------------------------------------------------------------------------
-- Scenario: Schema fixtures coexist with seeded and unrelated Results.
-- Setup:    Check only the synthetic keys used by this suite.
-- Expected: Fixture keys are unused; supplied reference rows are allowed.
SELECT is(
    (SELECT count(*) FROM public.results WHERE result_id IN (
        'BASE01', 'TYPE00', 'ENUM01', 'ENUM02', 'ENUM03', 'ENUM04',
        'JSON00', 'JSON01', 'JSON02', 'ID0001', 'TITLE1', 'TITLE2', 'NEXT01', 'NEXT02'
    )),
    0::bigint,
    'Results schema fixture keys are unused before fixtures'
);

CREATE FUNCTION pg_temp.insert_result(
    p_result_id                    VARCHAR DEFAULT 'BASE01',
    p_result_title                 VARCHAR DEFAULT 'pgTAP Result',
    p_order_term                   BOOLEAN DEFAULT TRUE,
    p_enforcement_result           BOOLEAN DEFAULT FALSE,
    p_case_result                  BOOLEAN DEFAULT TRUE,
    p_case_result_type             public.t_case_result_type_enum DEFAULT 'Ancillary',
    p_active                       BOOLEAN DEFAULT TRUE,
    p_order_accruing               BOOLEAN DEFAULT FALSE,
    p_requires_creditor            BOOLEAN DEFAULT FALSE,
    p_enforcement_hold             BOOLEAN DEFAULT FALSE,
    p_requires_enforcer            BOOLEAN DEFAULT FALSE,
    p_generates_hearing            BOOLEAN DEFAULT FALSE,
    p_generates_warrant            BOOLEAN DEFAULT FALSE,
    p_lists_monies                 BOOLEAN DEFAULT FALSE,
    p_result_parameters            JSON DEFAULT NULL,
    p_requires_employment_data     BOOLEAN DEFAULT FALSE,
    p_allow_additional_action      BOOLEAN DEFAULT FALSE,
    p_enf_next_permitted_actions  VARCHAR DEFAULT 'All',
    p_manual_enforcement           BOOLEAN DEFAULT TRUE,
    p_auto_enforcement             BOOLEAN DEFAULT FALSE
) RETURNS VOID
LANGUAGE SQL
AS $function$
    INSERT INTO public.results (
        result_id,
        result_title,
        order_term,
        enforcement_result,
        case_result,
        case_result_type,
        active,
        order_accruing,
        requires_creditor,
        enforcement_hold,
        requires_enforcer,
        generates_hearing,
        generates_warrant,
        lists_monies,
        result_parameters,
        requires_employment_data,
        allow_additional_action,
        enf_next_permitted_actions,
        manual_enforcement,
        auto_enforcement
    ) VALUES (
        p_result_id,
        p_result_title,
        p_order_term,
        p_enforcement_result,
        p_case_result,
        p_case_result_type,
        p_active,
        p_order_accruing,
        p_requires_creditor,
        p_enforcement_hold,
        p_requires_enforcer,
        p_generates_hearing,
        p_generates_warrant,
        p_lists_monies,
        p_result_parameters,
        p_requires_employment_data,
        p_allow_additional_action,
        p_enf_next_permitted_actions,
        p_manual_enforcement,
        p_auto_enforcement
    );
$function$;

-- ---------------------------------------------------------------------------
-- Scenario: Valid Results are stored and database constraints reject invalid rows.
-- Setup:    Insert a baseline result, then exercise primary-key and NOT NULL rules.
-- Expected: Valid insert succeeds; duplicates and required NULLs are rejected.
-- ---------------------------------------------------------------------------
SELECT lives_ok('SELECT pg_temp.insert_result()', 'a valid result can be inserted');
SELECT throws_ok('SELECT pg_temp.insert_result()', '23505', NULL, 'a duplicate result_id is rejected');
SELECT throws_ok('SELECT pg_temp.insert_result(p_result_id => NULL)', '23502', NULL, 'a null result_id is rejected');
SELECT throws_ok('SELECT pg_temp.insert_result(p_result_title => NULL)', '23502', NULL, 'a null result_title is rejected');
SELECT throws_ok('SELECT pg_temp.insert_result(p_order_term => NULL)', '23502', NULL, 'a null order_term is rejected');
SELECT throws_ok('SELECT pg_temp.insert_result(p_enforcement_result => NULL)', '23502', NULL, 'a null enforcement_result is rejected');
SELECT throws_ok('SELECT pg_temp.insert_result(p_case_result => NULL)', '23502', NULL, 'a null case_result is rejected');
SELECT throws_ok('SELECT pg_temp.insert_result(p_active => NULL)', '23502', NULL, 'a null active is rejected');
SELECT throws_ok('SELECT pg_temp.insert_result(p_order_accruing => NULL)', '23502', NULL, 'a null order_accruing is rejected');
SELECT throws_ok('SELECT pg_temp.insert_result(p_requires_creditor => NULL)', '23502', NULL, 'a null requires_creditor is rejected');
SELECT throws_ok('SELECT pg_temp.insert_result(p_enforcement_hold => NULL)', '23502', NULL, 'a null enforcement_hold is rejected');
SELECT throws_ok('SELECT pg_temp.insert_result(p_requires_enforcer => NULL)', '23502', NULL, 'a null requires_enforcer is rejected');
SELECT throws_ok('SELECT pg_temp.insert_result(p_generates_hearing => NULL)', '23502', NULL, 'a null generates_hearing is rejected');
SELECT throws_ok('SELECT pg_temp.insert_result(p_generates_warrant => NULL)', '23502', NULL, 'a null generates_warrant is rejected');
SELECT throws_ok('SELECT pg_temp.insert_result(p_lists_monies => NULL)', '23502', NULL, 'a null lists_monies is rejected');
SELECT throws_ok('SELECT pg_temp.insert_result(p_requires_employment_data => NULL)', '23502', NULL, 'a null requires_employment_data is rejected');
SELECT throws_ok('SELECT pg_temp.insert_result(p_allow_additional_action => NULL)', '23502', NULL, 'a null allow_additional_action is rejected');
SELECT throws_ok('SELECT pg_temp.insert_result(p_enf_next_permitted_actions => NULL)', '23502', NULL, 'a null enf_next_permitted_actions is rejected');
SELECT throws_ok('SELECT pg_temp.insert_result(p_manual_enforcement => NULL)', '23502', NULL, 'a null manual_enforcement is rejected');
SELECT throws_ok('SELECT pg_temp.insert_result(p_auto_enforcement => NULL)', '23502', NULL, 'a null auto_enforcement is rejected');

-- ---------------------------------------------------------------------------
-- Scenario: Optional enum values accept promoted labels and reject others.
-- Setup:    Insert NULL and each promoted label, then attempt an unknown label.
-- Expected: NULL and promoted labels succeed; invalid enum input raises 22P02.
-- ---------------------------------------------------------------------------
SELECT lives_ok('SELECT pg_temp.insert_result(p_result_id => ''TYPE00'', p_case_result_type => NULL)', 'a null case_result_type is accepted');
SELECT lives_ok('SELECT pg_temp.insert_result(p_result_id => ''ENUM01'', p_case_result_type => ''Ancillary'')', 'Ancillary case_result_type is accepted');
SELECT lives_ok('SELECT pg_temp.insert_result(p_result_id => ''ENUM02'', p_case_result_type => ''Interim'')', 'Interim case_result_type is accepted');
SELECT lives_ok('SELECT pg_temp.insert_result(p_result_id => ''ENUM03'', p_case_result_type => ''Final'')', 'Final case_result_type is accepted');
SELECT throws_ok($sql$SELECT pg_temp.insert_result(p_result_id => 'ENUM04', p_case_result_type => 'Unknown'::public.t_case_result_type_enum)$sql$, '22P02', NULL, 'an unrecognised case_result_type is rejected');

-- ---------------------------------------------------------------------------
-- Scenario: JSON is optional, round-trips faithfully, and malformed input fails.
-- Setup:    Insert NULL and representative JSON, then cast malformed JSON.
-- Expected: Valid JSON stores without business-schema validation; malformed JSON raises 22P02.
-- ---------------------------------------------------------------------------
SELECT lives_ok('SELECT pg_temp.insert_result(p_result_id => ''JSON00'', p_result_parameters => NULL)', 'a null result_parameters is accepted');
SELECT lives_ok($sql$SELECT pg_temp.insert_result(p_result_id => 'JSON01', p_result_parameters => '{"example":"value","enabled":true,"count":2}'::json)$sql$, 'representative valid JSON can be stored');
SELECT is((SELECT result_parameters::jsonb FROM public.results WHERE result_id = 'JSON01'), '{"example":"value","enabled":true,"count":2}'::jsonb, 'representative JSON is retrieved without semantic loss');
SELECT throws_ok($sql$SELECT pg_temp.insert_result(p_result_id => 'JSON02', p_result_parameters => '{"example":'::json)$sql$, '22P02', NULL, 'malformed JSON is rejected by PostgreSQL');

-- ---------------------------------------------------------------------------
-- Scenario: Varchar columns enforce their promoted length boundaries.
-- Setup:    Insert exact limits and values one character longer.
-- Expected: Exact limits succeed; overflows raise SQLSTATE 22001.
-- ---------------------------------------------------------------------------
SELECT lives_ok('SELECT pg_temp.insert_result(p_result_id => ''ID0001'')', 'a six-character result_id is accepted');
SELECT throws_ok('SELECT pg_temp.insert_result(p_result_id => ''ID00001'')', '22001', NULL, 'a seven-character result_id is rejected');
SELECT lives_ok('SELECT pg_temp.insert_result(p_result_id => ''TITLE1'', p_result_title => repeat(''T'', 60))', 'a sixty-character result_title is accepted');
SELECT throws_ok('SELECT pg_temp.insert_result(p_result_id => ''TITLE2'', p_result_title => repeat(''T'', 61))', '22001', NULL, 'a sixty-one-character result_title is rejected');
SELECT lives_ok('SELECT pg_temp.insert_result(p_result_id => ''NEXT01'', p_enf_next_permitted_actions => repeat(''A'', 100))', 'a one-hundred-character enf_next_permitted_actions value is accepted');
SELECT throws_ok('SELECT pg_temp.insert_result(p_result_id => ''NEXT02'', p_enf_next_permitted_actions => repeat(''A'', 101))', '22001', NULL, 'a one-hundred-and-one-character enf_next_permitted_actions value is rejected');

SELECT * FROM finish();
ROLLBACK;
