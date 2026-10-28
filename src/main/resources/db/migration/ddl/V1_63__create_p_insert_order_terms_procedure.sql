CREATE PROCEDURE public.p_insert_order_terms(
    IN pi_respondent_account_id public.respondent_accounts.respondent_account_id%TYPE,
    IN pi_creditor_account_id public.creditor_accounts.creditor_account_id%TYPE,
    IN pi_posted_by public.order_terms.posted_by%TYPE,
    IN pi_posted_by_name public.order_terms.posted_by_name%TYPE,
    IN pi_order_term_json JSON
)
LANGUAGE plpgsql
AS $$
/**
 * OPAL Program
 *
 * MODULE      : p_insert_order_terms
 *
 * DESCRIPTION : Validate and append one Order Term with original Result responses
 *               and typed projections, within the caller's transaction.
 *
 * PARAMETERS  : IN pi_respondent_account_id - Required Respondent Account ID.
 *             : IN pi_creditor_account_id   - Required Creditor Account ID.
 *             : IN pi_posted_by             - Nullable original submitter, at most 20 characters.
 *             : IN pi_posted_by_name        - Nullable original submitter name, at most 100 characters.
 *             : IN pi_order_term_json       - One term object with Result ID and response array.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket        Nature of Change
 * ----------  -------------  ------------  ----------------------------------------
 * 18/10/2026  Frankie Moran  PO-10646      Create validated single-term insertion procedure.
 */
DECLARE
    v_instant TIMESTAMPTZ;
    v_london_date DATE;
    v_responses JSON;
    v_entry JSON;
    v_definition JSON;
    v_metadata JSON;
    v_result_id TEXT;
    v_result_active BOOLEAN;
    v_result_order_term BOOLEAN;
    v_requires_creditor BOOLEAN;
    v_imposed_date public.respondent_accounts.imposed_hearing_date%TYPE;
    v_payment_period public.respondent_accounts.payment_period%TYPE;
    v_from_suspense public.creditor_accounts.from_suspense%TYPE;
    v_response_names TEXT[] := ARRAY[]::TEXT[];
    v_response_values TEXT[] := ARRAY[]::TEXT[];
    v_metadata_names TEXT[] := ARRAY[]::TEXT[];
    v_allowed_keys TEXT[];
    v_options TEXT[];
    v_selections TEXT[];
    v_name TEXT;
    v_type TEXT;
    v_value TEXT;
    v_mandatory BOOLEAN;
    v_min NUMERIC;
    v_max NUMERIC;
    v_min_date DATE;
    v_max_date DATE;
    v_date DATE;
    v_date_in_past BOOLEAN;
    v_date_today BOOLEAN;
    v_date_in_future BOOLEAN;
    v_checkbox JSON;
    v_position INTEGER;
    v_member_count BIGINT;
    v_distinct_count BIGINT;
    v_selection_count BIGINT;
    v_amount_found BOOLEAN := FALSE;
    v_amount NUMERIC;
    v_arrears NUMERIC;
    v_child_name TEXT;
    v_child_birth_date TIMESTAMP;
    v_expiry_date TIMESTAMP;
    v_expiry_terms BOOLEAN;
    v_numeric_value NUMERIC;
    v_inserted_rows BIGINT;

BEGIN
    -- One transaction-start reference supplies both the London date and UTC posting.
    v_instant := TRANSACTION_TIMESTAMP();
    v_london_date := (v_instant AT TIME ZONE 'Europe/London')::DATE;

    IF pi_respondent_account_id IS NULL THEN
        RAISE EXCEPTION USING MESSAGE=FORMAT('%s: required %s', 'p_insert_order_terms', 'pi_respondent_account_id');
    END IF;

    IF pi_creditor_account_id IS NULL THEN
        RAISE EXCEPTION USING MESSAGE=FORMAT('%s: required %s', 'p_insert_order_terms', 'pi_creditor_account_id');
    END IF;

    -- Check original character lengths before any bounded assignment can truncate spaces.
    IF CHAR_LENGTH(pi_posted_by) > 20 THEN
        RAISE EXCEPTION USING ERRCODE='22001',
            MESSAGE=FORMAT('%s: storage width exceeded for %s', 'p_insert_order_terms', 'pi_posted_by');
    END IF;

    IF CHAR_LENGTH(pi_posted_by_name) > 100 THEN
        RAISE EXCEPTION USING ERRCODE='22001',
            MESSAGE=FORMAT('%s: storage width exceeded for %s', 'p_insert_order_terms', 'pi_posted_by_name');
    END IF;

    IF JSON_TYPEOF(pi_order_term_json) IS DISTINCT FROM 'object' THEN
        RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s', 'p_insert_order_terms', 'Order Term object');
    END IF;

    IF EXISTS (SELECT 1 FROM JSON_EACH(pi_order_term_json) GROUP BY key HAVING COUNT(*) > 1) THEN
        RAISE EXCEPTION USING MESSAGE=FORMAT('%s: duplicate %s', 'p_insert_order_terms', 'Order Term member');
    END IF;

    IF JSON_TYPEOF(pi_order_term_json->'result_id') IS DISTINCT FROM 'string'
        OR CHAR_LENGTH(pi_order_term_json->>'result_id') NOT BETWEEN 1 AND 6 THEN
        RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s', 'p_insert_order_terms', 'result_id');
    END IF;

    IF JSON_TYPEOF(pi_order_term_json->'result_responses') IS DISTINCT FROM 'array' THEN
        RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s', 'p_insert_order_terms', 'result_responses');
    END IF;

    v_result_id := pi_order_term_json->>'result_id';
    v_responses := pi_order_term_json->'result_responses';

    -- Decode validation copies only; the original JSON array remains the INSERT source.
    FOR v_entry IN SELECT value FROM JSON_ARRAY_ELEMENTS(v_responses) LOOP
        IF JSON_TYPEOF(v_entry) IS DISTINCT FROM 'object' THEN
            RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s', 'p_insert_order_terms', 'response object');
        END IF;

        SELECT COUNT(*), COUNT(DISTINCT key) INTO v_member_count, v_distinct_count FROM JSON_EACH(v_entry);

        IF v_member_count <> 2 OR v_distinct_count <> 2
            OR JSON_TYPEOF(v_entry->'parameter_name') IS DISTINCT FROM 'string'
            OR JSON_TYPEOF(v_entry->'response') IS DISTINCT FROM 'string'
            OR CHAR_LENGTH(v_entry->>'parameter_name') NOT BETWEEN 1 AND 50 THEN
            RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s', 'p_insert_order_terms', 'response members');
        END IF;

        v_name := v_entry->>'parameter_name';

        IF v_name = ANY(v_response_names) THEN
            RAISE EXCEPTION USING MESSAGE=FORMAT('%s: duplicate %s', 'p_insert_order_terms', 'response name');
        END IF;

        v_response_names := ARRAY_APPEND(v_response_names, v_name);
        v_response_values := ARRAY_APPEND(v_response_values, v_entry->>'response');
    END LOOP;

    -- Strict identity reads preserve native missing-row errors and capture observed state once.
    SELECT a.imposed_hearing_date, a.payment_period INTO STRICT v_imposed_date, v_payment_period
    FROM public.respondent_accounts a WHERE a.respondent_account_id = pi_respondent_account_id;

    IF v_imposed_date IS NULL THEN
        RAISE EXCEPTION USING MESSAGE=FORMAT('%s: missing %s', 'p_insert_order_terms', 'parent imposed date');
    END IF;

    SELECT a.from_suspense INTO STRICT v_from_suspense
    FROM public.creditor_accounts a WHERE a.creditor_account_id = pi_creditor_account_id;

    IF v_from_suspense THEN
        RAISE EXCEPTION USING MESSAGE=FORMAT('%s: ineligible %s', 'p_insert_order_terms', 'suspense Creditor Account');
    END IF;

    SELECT r.active, r.order_term, r.requires_creditor, r.result_parameters
    INTO STRICT v_result_active, v_result_order_term, v_requires_creditor, v_metadata
    FROM public.results r WHERE r.result_id = v_result_id;

    IF NOT v_result_active OR NOT v_result_order_term THEN
        RAISE EXCEPTION USING MESSAGE=FORMAT('%s: ineligible %s', 'p_insert_order_terms', 'Result');
    END IF;

    IF NOT v_requires_creditor THEN
        RAISE EXCEPTION USING MESSAGE=FORMAT('%s: unsupported %s', 'p_insert_order_terms', 'creditor-free Result');
    END IF;

    IF JSON_TYPEOF(v_metadata) IS DISTINCT FROM 'array' THEN
        RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s', 'p_insert_order_terms', 'Result metadata');
    END IF;

    -- Validate every captured definition, including omitted optional parameters, exactly once.
    FOR v_definition IN SELECT value FROM JSON_ARRAY_ELEMENTS(v_metadata) LOOP
        IF JSON_TYPEOF(v_definition) IS DISTINCT FROM 'object' THEN
            RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s', 'p_insert_order_terms', 'metadata definition');
        END IF;

        IF EXISTS (SELECT 1 FROM JSON_EACH(v_definition) GROUP BY key HAVING COUNT(*) > 1) THEN
            RAISE EXCEPTION USING MESSAGE=FORMAT('%s: duplicate %s', 'p_insert_order_terms', 'metadata member');
        END IF;

        IF JSON_TYPEOF(v_definition->'name') IS DISTINCT FROM 'string'
            OR CHAR_LENGTH(v_definition->>'name') NOT BETWEEN 1 AND 50
            OR JSON_TYPEOF(v_definition->'type') IS DISTINCT FROM 'string'
            OR JSON_TYPEOF(v_definition->'mandatory') IS DISTINCT FROM 'boolean'
            OR JSON_TYPEOF(v_definition->'language_dependent') IS DISTINCT FROM 'boolean'
            OR v_definition->>'language_dependent' <> 'false' THEN
            RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s', 'p_insert_order_terms', 'metadata properties');
        END IF;

        v_name := v_definition->>'name';
        v_type := v_definition->>'type';
        v_mandatory := (v_definition->>'mandatory')::BOOLEAN;
        v_options := NULL;

        IF v_name = ANY(v_metadata_names) THEN
            RAISE EXCEPTION USING MESSAGE=FORMAT('%s: duplicate %s', 'p_insert_order_terms', 'metadata name');
        END IF;

        v_metadata_names := ARRAY_APPEND(v_metadata_names, v_name);

        IF v_type NOT IN ('text-60', 'text-1000', 'decimal-2dp', 'date', 'menu-checkbox', 'menu-radio', 'read-only') THEN
            RAISE EXCEPTION USING MESSAGE=FORMAT('%s: unsupported %s', 'p_insert_order_terms', 'metadata type');
        END IF;

        v_allowed_keys := ARRAY['name', 'type', 'mandatory', 'min', 'max', 'language_dependent', 'prompt', 'hint'];

        IF v_type = 'date' THEN
            v_allowed_keys := v_allowed_keys || ARRAY['date_in_past', 'date_today', 'date_in_future'];
        ELSIF v_type IN ('menu-checkbox', 'menu-radio', 'read-only') THEN
            v_allowed_keys := ARRAY_APPEND(v_allowed_keys, 'options');
        END IF;

        IF EXISTS (SELECT 1 FROM JSON_EACH(v_definition) WHERE NOT(key = ANY(v_allowed_keys)))
            OR (v_definition->'prompt' IS NOT NULL AND JSON_TYPEOF(v_definition->'prompt') IS DISTINCT FROM 'string')
            OR (v_definition->'hint' IS NOT NULL AND JSON_TYPEOF(v_definition->'hint') IS DISTINCT FROM 'string') THEN
            RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s', 'p_insert_order_terms', 'metadata members');
        END IF;

        -- Exact numeric counts/cents are checked before any narrowing or response conversion.
        IF v_type = 'date' THEN
            IF JSON_TYPEOF(v_definition->'min') IS DISTINCT FROM 'string'
                OR JSON_TYPEOF(v_definition->'max') IS DISTINCT FROM 'string'
                OR CHAR_LENGTH(v_definition->>'min') <> 10 OR CHAR_LENGTH(v_definition->>'max') <> 10
                OR v_definition->>'min' !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
                OR v_definition->>'max' !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
                OR JSON_TYPEOF(v_definition->'date_in_past') IS DISTINCT FROM 'boolean'
                OR JSON_TYPEOF(v_definition->'date_today') IS DISTINCT FROM 'boolean'
                OR JSON_TYPEOF(v_definition->'date_in_future') IS DISTINCT FROM 'boolean' THEN
                RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s', 'p_insert_order_terms', 'date metadata');
            END IF;

            v_min_date := (v_definition->>'min')::DATE;
            v_max_date := (v_definition->>'max')::DATE;
            v_date_in_past := (v_definition->>'date_in_past')::BOOLEAN;
            v_date_today := (v_definition->>'date_today')::BOOLEAN;
            v_date_in_future := (v_definition->>'date_in_future')::BOOLEAN;

            IF v_min_date > v_max_date OR NOT(v_date_in_past OR v_date_today OR v_date_in_future) THEN
                RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s', 'p_insert_order_terms', 'date metadata bounds');
            END IF;
        ELSE
            IF JSON_TYPEOF(v_definition->'min') IS DISTINCT FROM 'number'
                OR JSON_TYPEOF(v_definition->'max') IS DISTINCT FROM 'number' THEN
                RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s', 'p_insert_order_terms', 'numeric metadata bounds');
            END IF;

            v_min := (v_definition->>'min')::NUMERIC;
            v_max := (v_definition->>'max')::NUMERIC;

            IF v_min > v_max THEN
                RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s', 'p_insert_order_terms', 'metadata bounds');
            END IF;

            IF v_type = 'decimal-2dp' THEN
                IF TRUNC(v_min, 2) <> v_min OR TRUNC(v_max, 2) <> v_max THEN
                    RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s', 'p_insert_order_terms', 'decimal metadata cents');
                END IF;
            ELSE
                IF v_min < 0 OR TRUNC(v_min) <> v_min OR TRUNC(v_max) <> v_max THEN
                    RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s', 'p_insert_order_terms', 'metadata counts');
                END IF;

                IF v_type IN ('text-60', 'text-1000')
                    AND v_max > (CASE WHEN v_type = 'text-60' THEN 60 ELSE 1000 END) THEN
                    RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s', 'p_insert_order_terms', 'text metadata capacity');
                END IF;
            END IF;
        END IF;

        IF v_type IN ('menu-checkbox', 'menu-radio', 'read-only') THEN
            IF JSON_TYPEOF(v_definition->'options') IS DISTINCT FROM 'array' THEN
                RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s', 'p_insert_order_terms', 'metadata options');
            END IF;

            IF JSON_ARRAY_LENGTH(v_definition->'options') = 0
                OR EXISTS (SELECT 1 FROM JSON_ARRAY_ELEMENTS(v_definition->'options')
                    WHERE JSON_TYPEOF(value) IS DISTINCT FROM 'string') THEN
                RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s', 'p_insert_order_terms', 'metadata options');
            END IF;

            v_options := ARRAY(SELECT JSON_ARRAY_ELEMENTS_TEXT(v_definition->'options'));

            IF EXISTS (SELECT 1 FROM UNNEST(v_options) AS o(value) WHERE CHAR_LENGTH(value) = 0)
                OR EXISTS (SELECT 1 FROM UNNEST(v_options) AS o(value) GROUP BY value HAVING COUNT(*) > 1)
                OR v_max > CARDINALITY(v_options) THEN
                RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s', 'p_insert_order_terms', 'metadata option counts');
            END IF;

            IF v_type IN ('menu-radio', 'read-only') AND (v_min NOT IN (0, 1) OR v_max <> 1) THEN
                RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s', 'p_insert_order_terms', 'single-choice metadata');
            END IF;
        END IF;

        -- Stable named bindings apply even when an optional value was not supplied.
        IF (v_name IN ('Amount', 'Arrears') AND v_type <> 'decimal-2dp')
            OR (v_name = 'Beneficiary' AND v_type <> 'text-60')
            OR (v_name IN ('ChildDOB', 'Expiry') AND v_type <> 'date')
            OR (v_name = 'Education' AND (v_type <> 'menu-checkbox'
                OR v_options IS DISTINCT FROM ARRAY['Additional terms affect order expiry']::TEXT[]))
            OR (v_name = 'Frequency' AND v_type <> 'read-only') THEN
            RAISE EXCEPTION USING MESSAGE=FORMAT('%s: incompatible %s', 'p_insert_order_terms', 'named mapping');
        END IF;

        IF v_name = 'Frequency' AND EXISTS (SELECT 1 FROM UNNEST(v_options) AS o(value)
            WHERE NOT(value = ANY(ENUM_RANGE(NULL::public.t_payment_frequency_enum)::TEXT[]))) THEN
            RAISE EXCEPTION USING MESSAGE=FORMAT('%s: incompatible %s', 'p_insert_order_terms', 'Frequency options');
        END IF;

        IF v_name = 'Amount' THEN
            v_amount_found := TRUE;
        END IF;

        v_position := ARRAY_POSITION(v_response_names, v_name);

        IF v_position IS NULL THEN
            IF v_mandatory OR v_name = 'Amount' THEN
                RAISE EXCEPTION USING MESSAGE=FORMAT('%s: missing %s', 'p_insert_order_terms', 'required response');
            END IF;

            CONTINUE;
        END IF;

        v_value := v_response_values[v_position];

        -- Convert only the validated string copy, never the persisted response document.
        CASE v_type
            WHEN 'decimal-2dp' THEN
                IF v_value !~ '^-?[0-9]+([.][0-9]{1,2})?$' OR v_value ~ '[^0-9.-]' THEN
                    RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s', 'p_insert_order_terms', 'decimal response');
                END IF;

                v_numeric_value := v_value::NUMERIC;

                IF v_numeric_value < v_min OR v_numeric_value > v_max THEN
                    RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s', 'p_insert_order_terms', 'decimal response bounds');
                END IF;
            WHEN 'date' THEN
                IF CHAR_LENGTH(v_value) <> 10 OR v_value !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN
                    RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s', 'p_insert_order_terms', 'date response');
                END IF;

                v_date := v_value::DATE;

                IF v_date < v_min_date OR v_date > v_max_date
                    OR (v_date < v_london_date AND NOT v_date_in_past)
                    OR (v_date = v_london_date AND NOT v_date_today)
                    OR (v_date > v_london_date AND NOT v_date_in_future) THEN
                    RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s', 'p_insert_order_terms', 'date response bounds');
                END IF;
            WHEN 'text-60', 'text-1000' THEN
                IF CHAR_LENGTH(v_value) < v_min OR CHAR_LENGTH(v_value) > v_max THEN
                    RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s', 'p_insert_order_terms', 'text response bounds');
                END IF;
            WHEN 'menu-radio', 'read-only' THEN
                IF NOT(v_value = ANY(v_options)) OR 1 < v_min OR 1 > v_max THEN
                    RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s', 'p_insert_order_terms', 'choice response');
                END IF;
            WHEN 'menu-checkbox' THEN
                v_checkbox := v_value::JSON;

                IF JSON_TYPEOF(v_checkbox) IS DISTINCT FROM 'array' THEN
                    RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s', 'p_insert_order_terms', 'checkbox response');
                END IF;

                IF EXISTS (SELECT 1 FROM JSON_ARRAY_ELEMENTS(v_checkbox)
                    WHERE JSON_TYPEOF(value) IS DISTINCT FROM 'string') THEN
                    RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s', 'p_insert_order_terms', 'checkbox selections');
                END IF;

                v_selections := ARRAY(SELECT JSON_ARRAY_ELEMENTS_TEXT(v_checkbox));
                v_selection_count := CARDINALITY(v_selections);

                IF EXISTS (SELECT 1 FROM UNNEST(v_selections) AS s(value) GROUP BY value HAVING COUNT(*) > 1)
                    OR NOT(v_selections <@ v_options) OR v_selection_count < v_min OR v_selection_count > v_max THEN
                    RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s', 'p_insert_order_terms', 'checkbox selection bounds');
                END IF;
        END CASE;

        IF v_name = 'Frequency' AND v_value <> v_payment_period::TEXT THEN
            RAISE EXCEPTION USING MESSAGE=FORMAT('%s: inconsistent %s', 'p_insert_order_terms', 'Frequency response');
        END IF;

        CASE v_name
            WHEN 'Amount' THEN v_amount := v_numeric_value;
            WHEN 'Arrears' THEN v_arrears := v_numeric_value;
            WHEN 'Beneficiary' THEN v_child_name := v_value;
            WHEN 'ChildDOB' THEN v_child_birth_date := v_date::TIMESTAMP;
            WHEN 'Expiry' THEN v_expiry_date := v_date::TIMESTAMP;
            WHEN 'Education' THEN v_expiry_terms := v_selection_count = 1;
            ELSE NULL;
        END CASE;
    END LOOP;

    IF NOT v_amount_found THEN
        RAISE EXCEPTION USING MESSAGE=FORMAT('%s: missing %s', 'p_insert_order_terms', 'Amount definition');
    END IF;

    IF NOT(v_response_names <@ v_metadata_names) THEN
        RAISE EXCEPTION USING MESSAGE=FORMAT('%s: unknown %s', 'p_insert_order_terms', 'response name');
    END IF;

    -- The single write stores generic and typed values from the same validated input.
    INSERT INTO public.order_terms (
        respondent_account_id,
        creditor_account_id,
        result_id,
        posted_date,
        posted_by,
        posted_by_name,
        original_posted_date,
        imposed_date,
        imposed_amount,
        arrears_amount,
        completed,
        child_name,
        child_birth_date,
        expiry_date,
        expiry_terms,
        remitted_amount,
        result_responses
    ) VALUES (
        pi_respondent_account_id,
        pi_creditor_account_id,
        v_result_id,
        v_instant AT TIME ZONE 'UTC',
        pi_posted_by,
        pi_posted_by_name,
        NULL,
        v_imposed_date,
        v_amount,
        v_arrears,
        FALSE,
        v_child_name,
        v_child_birth_date,
        v_expiry_date,
        v_expiry_terms,
        NULL,
        v_responses
    );
    GET DIAGNOSTICS v_inserted_rows = ROW_COUNT;

    IF v_inserted_rows <> 1 THEN
        RAISE EXCEPTION USING MESSAGE=FORMAT('%s: unexpected %s', 'p_insert_order_terms', 'inserted-row count');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;
