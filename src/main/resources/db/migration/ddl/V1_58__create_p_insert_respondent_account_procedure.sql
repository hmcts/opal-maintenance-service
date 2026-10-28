CREATE PROCEDURE public.p_insert_respondent_account(
    IN pi_business_unit_id public.draft_casefiles.business_unit_id%TYPE,
    IN pi_casefile_type public.draft_casefiles.casefile_type%TYPE,
    IN pi_respondent_account_json JSON,
    IN pi_debtor_detail_id public.debtor_detail.debtor_detail_id%TYPE,
    IN pi_third_party_contact_id public.third_party_contact.third_party_contact_id%TYPE,
    OUT po_respondent_account_id public.respondent_accounts.respondent_account_id%TYPE,
    OUT po_account_number public.respondent_accounts.account_number%TYPE
)
LANGUAGE plpgsql
AS $$
/**
 * OPAL Program
 *
 * MODULE      : p_insert_respondent_account
 *
 * DESCRIPTION : Validate the consumed account contract, calculate exact financial
 *               values, reserve one account number and insert one account.
 *               The caller owns publication, transaction and run-status work.
 *
 * PARAMETERS  : IN  pi_business_unit_id        - Persisted Business Unit authority.
 *             : IN  pi_casefile_type           - Persisted casefile type authority.
 *             : IN  pi_respondent_account_json - One original JSON account object.
 *             : IN  pi_debtor_detail_id        - Optional Debtor Detail identifier.
 *             : IN  pi_third_party_contact_id  - Optional Third Party Contact ID.
 *             : OUT po_respondent_account_id   - Inserted account identifier.
 *             : OUT po_account_number          - Same inserted row account number.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket        Nature of Change
 * ----------  -------------  ------------  ----------------------------------------
 * 16/10/2026  Frankie Moran  PO-10650      Create the bounded account helper.
 */
DECLARE
    v_instant TIMESTAMPTZ;
    v_publication_date DATE;
    v_account JSON := pi_respondent_account_json;
    v_details JSON;
    v_term JSON;
    v_response JSON;
    v_metadata JSON;
    v_definition JSON;
    v_key TEXT;
    v_name TEXT;
    v_text TEXT;
    v_application public.maintenance_applications%ROWTYPE;
    v_result public.results%ROWTYPE;
    v_configuration public.configuration_items%ROWTYPE;
    v_ordered DATE;
    v_arrears_date DATE;
    v_payment_period public.t_payment_frequency_enum;
    v_indexation public.t_indexation_enum;
    v_arrangement public.t_payment_arrangement_enum;
    v_interest BOOLEAN;
    v_originator TEXT;
    v_remo TEXT;
    v_ca TEXT;
    v_comment TEXT;
    v_cheque SMALLINT;
    v_credit SMALLINT;
    v_count BIGINT;
    v_mandatory BOOLEAN;
    v_min NUMERIC;
    v_max NUMERIC;
    v_value NUMERIC;
    v_amount NUMERIC;
    v_arrears NUMERIC;
    v_amounts NUMERIC[] := ARRAY[]::NUMERIC[];
    v_arrears_values NUMERIC[] := ARRAY[]::NUMERIC[];
    v_orders_amount NUMERIC;
    v_total_arrears NUMERIC;
    v_orders_balance NUMERIC;
    v_months INTEGER;
    v_stride INTEGER;
    v_periods INTEGER;
    v_boundary DATE;
    v_number public.respondent_accounts.account_number%TYPE;
BEGIN
    v_instant := TRANSACTION_TIMESTAMP();
    v_publication_date := (v_instant AT TIME ZONE 'Europe/London')::DATE;

    IF pi_business_unit_id IS NULL OR pi_casefile_type IS NULL
    OR JSON_TYPEOF(v_account) IS DISTINCT FROM 'object' THEN
        RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s','p_insert_respondent_account','account input');
    END IF;

    -- Check decoded consumed keys on original JSON before any lossy conversion.
    IF EXISTS (SELECT 1 FROM JSON_EACH(v_account) e
        WHERE e.key IN ('business_unit_id','casefile_type','application_code','order_details',
            'originator_name','remo_reference','central_authority_reference','account_comment')
        GROUP BY e.key HAVING COUNT(*)>1) THEN
        RAISE EXCEPTION USING MESSAGE=FORMAT('%s: duplicate %s','p_insert_respondent_account','account member');
    END IF;

    IF JSON_TYPEOF(v_account->'business_unit_id') IS NOT NULL THEN
        IF JSON_TYPEOF(v_account->'business_unit_id') IS DISTINCT FROM 'number' THEN
            RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s','p_insert_respondent_account','business_unit_id');
        END IF;
        IF (v_account->>'business_unit_id')::NUMERIC IS DISTINCT FROM pi_business_unit_id::NUMERIC THEN
            RAISE EXCEPTION USING MESSAGE=FORMAT('%s: contradictory %s','p_insert_respondent_account','business_unit_id');
        END IF;
    END IF;

    IF JSON_TYPEOF(v_account->'casefile_type') IS NOT NULL THEN
        IF JSON_TYPEOF(v_account->'casefile_type') IS DISTINCT FROM 'string'
        OR (v_account->>'casefile_type') IS DISTINCT FROM pi_casefile_type::TEXT THEN
            RAISE EXCEPTION USING MESSAGE=FORMAT('%s: contradictory %s','p_insert_respondent_account','casefile_type');
        END IF;
    END IF;

    IF JSON_TYPEOF(v_account->'application_code') IS DISTINCT FROM 'string'
    OR CHAR_LENGTH(v_account->>'application_code') NOT BETWEEN 1 AND 8 THEN
        RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s','p_insert_respondent_account','application_code');
    END IF;
    v_details := v_account->'order_details';
    IF JSON_TYPEOF(v_details) IS DISTINCT FROM 'object' THEN
        RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s','p_insert_respondent_account','order_details');
    END IF;
    IF EXISTS (SELECT 1 FROM JSON_EACH(v_details) e
        WHERE e.key IN ('date_ordered','date_arrears_last_updated','payment_period','interest_flag',
            'indexation','payment_arrangement','order_terms') GROUP BY e.key HAVING COUNT(*)>1) THEN
        RAISE EXCEPTION USING MESSAGE=FORMAT('%s: duplicate %s','p_insert_respondent_account','order_details member');
    END IF;

    FOREACH v_key IN ARRAY ARRAY['date_ordered','date_arrears_last_updated','payment_period','indexation','payment_arrangement'] LOOP
        IF JSON_TYPEOF(v_details->v_key) IS DISTINCT FROM 'string' THEN
            RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s','p_insert_respondent_account',v_key);
        END IF;
    END LOOP;
    FOREACH v_key IN ARRAY ARRAY['date_ordered','date_arrears_last_updated'] LOOP
        IF (v_details->>v_key) !~ E'\\A[0-9]{4}-[0-9]{2}-[0-9]{2}\\Z' THEN
            RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s','p_insert_respondent_account',v_key);
        END IF;
    END LOOP;
    v_ordered := (v_details->>'date_ordered')::DATE;
    v_arrears_date := (v_details->>'date_arrears_last_updated')::DATE;
    v_payment_period := (v_details->>'payment_period')::public.t_payment_frequency_enum;
    v_indexation := (v_details->>'indexation')::public.t_indexation_enum;
    v_arrangement := (v_details->>'payment_arrangement')::public.t_payment_arrangement_enum;
    IF JSON_TYPEOF(v_details->'interest_flag') IS DISTINCT FROM 'boolean' THEN
        RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s','p_insert_respondent_account','interest_flag');
    END IF;
    v_interest := (v_details->>'interest_flag')::BOOLEAN;

    FOREACH v_key IN ARRAY ARRAY['originator_name','remo_reference','central_authority_reference','account_comment'] LOOP
        IF JSON_TYPEOF(v_account->v_key) IS NOT NULL
        AND JSON_TYPEOF(v_account->v_key) IS DISTINCT FROM 'string' THEN
            RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s','p_insert_respondent_account',v_key);
        END IF;
    END LOOP;
    v_originator := v_account->>'originator_name';
    v_remo := v_account->>'remo_reference';
    v_ca := v_account->>'central_authority_reference';
    v_comment := v_account->>'account_comment';
    IF CHAR_LENGTH(v_originator)>200 OR CHAR_LENGTH(v_remo)>20 OR CHAR_LENGTH(v_ca)>50 THEN
        RAISE EXCEPTION USING ERRCODE='22001',MESSAGE=FORMAT('%s: storage width exceeded for %s','p_insert_respondent_account','account text');
    END IF;

    SELECT * INTO STRICT v_application FROM public.maintenance_applications
    WHERE application_code=v_account->>'application_code';
    IF NOT v_application.active OR v_application.date_used_from>v_publication_date
    OR (v_application.date_used_to IS NOT NULL AND v_application.date_used_to<v_publication_date) THEN
        RAISE EXCEPTION USING MESSAGE=FORMAT('%s: ineligible %s','p_insert_respondent_account','Application');
    END IF;
    IF v_arrears_date>v_publication_date THEN
        RAISE EXCEPTION USING MESSAGE=FORMAT('%s: future %s','p_insert_respondent_account','arrears date');
    END IF;

    -- Exact global selection; native absence/conversion errors remain unchanged.
    FOREACH v_key IN ARRAY ARRAY['DEFAULT_CHEQUE_CLEARANCE_PERIOD','DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD'] LOOP
        SELECT * INTO STRICT v_configuration FROM public.configuration_items
        WHERE item_name=v_key AND business_unit_id IS NULL;
        IF v_configuration.item_value IS NULL OR v_configuration.item_values IS NOT NULL THEN
            RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s','p_insert_respondent_account',v_key);
        END IF;
        IF v_key='DEFAULT_CHEQUE_CLEARANCE_PERIOD' THEN
            v_cheque := v_configuration.item_value::SMALLINT;
            IF v_cheque<0 THEN
                RAISE EXCEPTION USING MESSAGE=FORMAT('%s: negative %s','p_insert_respondent_account',v_key);
            END IF;
        ELSE
            v_credit := v_configuration.item_value::SMALLINT;
            IF v_credit<0 THEN
                RAISE EXCEPTION USING MESSAGE=FORMAT('%s: negative %s','p_insert_respondent_account',v_key);
            END IF;
        END IF;
    END LOOP;

    IF JSON_TYPEOF(v_details->'order_terms') IS DISTINCT FROM 'array' THEN
        RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s','p_insert_respondent_account','order_terms');
    END IF;
    IF JSON_ARRAY_LENGTH(v_details->'order_terms')=0 THEN
        RAISE EXCEPTION USING MESSAGE=FORMAT('%s: empty %s','p_insert_respondent_account','order_terms');
    END IF;

    -- Validate every term and stage exact values; aggregate only after this loop.
    FOR v_term IN SELECT value FROM JSON_ARRAY_ELEMENTS(v_details->'order_terms') LOOP
        IF JSON_TYPEOF(v_term) IS DISTINCT FROM 'object' THEN
            RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s','p_insert_respondent_account','Order Term');
        END IF;
        IF EXISTS (SELECT 1 FROM JSON_EACH(v_term) e WHERE e.key IN ('result_id','result_responses')
            GROUP BY e.key HAVING COUNT(*)>1) THEN
            RAISE EXCEPTION USING MESSAGE=FORMAT('%s: duplicate %s','p_insert_respondent_account','Order Term member');
        END IF;
        IF JSON_TYPEOF(v_term->'result_id') IS DISTINCT FROM 'string'
        OR CHAR_LENGTH(v_term->>'result_id') NOT BETWEEN 1 AND 6 THEN
            RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s','p_insert_respondent_account','result_id');
        END IF;
        SELECT * INTO STRICT v_result FROM public.results WHERE result_id=v_term->>'result_id';
        IF NOT v_result.active OR NOT v_result.order_term THEN
            RAISE EXCEPTION USING MESSAGE=FORMAT('%s: ineligible %s','p_insert_respondent_account','Result');
        END IF;
        v_metadata := v_result.result_parameters;
        IF JSON_TYPEOF(v_metadata) IS DISTINCT FROM 'array'
        OR JSON_TYPEOF(v_term->'result_responses') IS DISTINCT FROM 'array' THEN
            RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid %s','p_insert_respondent_account','financial collections');
        END IF;
        IF JSON_ARRAY_LENGTH(v_term->'result_responses')=0 THEN
            RAISE EXCEPTION USING MESSAGE=FORMAT('%s: empty %s','p_insert_respondent_account','result_responses');
        END IF;

        -- Read identities safely before deciding which definitions/responses are consumed.
        FOR v_definition IN SELECT value FROM JSON_ARRAY_ELEMENTS(v_metadata) LOOP
            IF JSON_TYPEOF(v_definition) IS DISTINCT FROM 'object' THEN
                RAISE EXCEPTION USING MESSAGE=FORMAT('%s: unreadable %s','p_insert_respondent_account','metadata identity');
            END IF;
            SELECT COUNT(*) INTO v_count FROM JSON_EACH(v_definition) WHERE key='name';
            IF v_count<>1 OR JSON_TYPEOF(v_definition->'name') IS DISTINCT FROM 'string'
            OR CHAR_LENGTH(v_definition->>'name')=0 THEN
                RAISE EXCEPTION USING MESSAGE=FORMAT('%s: unreadable %s','p_insert_respondent_account','metadata identity');
            END IF;
        END LOOP;
        FOR v_response IN SELECT value FROM JSON_ARRAY_ELEMENTS(v_term->'result_responses') LOOP
            IF JSON_TYPEOF(v_response) IS DISTINCT FROM 'object' THEN
                RAISE EXCEPTION USING MESSAGE=FORMAT('%s: unreadable %s','p_insert_respondent_account','response identity');
            END IF;
            SELECT COUNT(*) INTO v_count FROM JSON_EACH(v_response) WHERE key='parameter_name';
            IF v_count<>1 OR JSON_TYPEOF(v_response->'parameter_name') IS DISTINCT FROM 'string'
            OR CHAR_LENGTH(v_response->>'parameter_name')=0 THEN
                RAISE EXCEPTION USING MESSAGE=FORMAT('%s: unreadable %s','p_insert_respondent_account','response identity');
            END IF;
        END LOOP;

        v_amount := NULL;
        v_arrears := NULL;
        FOREACH v_name IN ARRAY ARRAY['Amount','Arrears'] LOOP
            SELECT COUNT(*) INTO v_count FROM JSON_ARRAY_ELEMENTS(v_metadata) e WHERE e.value->>'name'=v_name;
            IF v_count>1 OR (v_name='Amount' AND v_count<>1) THEN
                RAISE EXCEPTION USING MESSAGE=FORMAT('%s: ambiguous or missing %s','p_insert_respondent_account',v_name);
            END IF;
            IF v_count=0 THEN
                IF EXISTS (SELECT 1 FROM JSON_ARRAY_ELEMENTS(v_term->'result_responses') e WHERE e.value->>'parameter_name'=v_name) THEN
                    RAISE EXCEPTION USING MESSAGE=FORMAT('%s: undeclared %s','p_insert_respondent_account',v_name);
                END IF;
                CONTINUE;
            END IF;
            SELECT e.value INTO STRICT v_definition FROM JSON_ARRAY_ELEMENTS(v_metadata) e WHERE e.value->>'name'=v_name;
            IF EXISTS (SELECT 1 FROM JSON_EACH(v_definition) e WHERE e.key IN ('name','type','mandatory','min','max','precision')
                GROUP BY e.key HAVING COUNT(*)>1) THEN
                RAISE EXCEPTION USING MESSAGE=FORMAT('%s: duplicate metadata for %s','p_insert_respondent_account',v_name);
            END IF;
            IF JSON_TYPEOF(v_definition->'type') IS DISTINCT FROM 'string'
            OR v_definition->>'type'<>'decimal-2dp'
            OR JSON_TYPEOF(v_definition->'mandatory') IS DISTINCT FROM 'boolean'
            OR JSON_TYPEOF(v_definition->'min') IS DISTINCT FROM 'number'
            OR JSON_TYPEOF(v_definition->'max') IS DISTINCT FROM 'number' THEN
                RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid metadata for %s','p_insert_respondent_account',v_name);
            END IF;
            IF JSON_TYPEOF(v_definition->'precision') IS NOT NULL THEN
                IF JSON_TYPEOF(v_definition->'precision') IS DISTINCT FROM 'number' THEN
                    RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid precision for %s','p_insert_respondent_account',v_name);
                END IF;
                IF (v_definition->>'precision')::NUMERIC<>2 THEN
                    RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid precision for %s','p_insert_respondent_account',v_name);
                END IF;
            END IF;
            v_mandatory := (v_definition->>'mandatory')::BOOLEAN;
            v_min := (v_definition->>'min')::NUMERIC;
            v_max := (v_definition->>'max')::NUMERIC;
            IF v_min>v_max OR (v_name='Amount' AND NOT v_mandatory) THEN
                RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid bounds or mandatory flag for %s','p_insert_respondent_account',v_name);
            END IF;
            SELECT COUNT(*) INTO v_count FROM JSON_ARRAY_ELEMENTS(v_term->'result_responses') e WHERE e.value->>'parameter_name'=v_name;
            IF v_count>1 OR (v_count=0 AND v_mandatory) THEN
                RAISE EXCEPTION USING MESSAGE=FORMAT('%s: missing or duplicate %s','p_insert_respondent_account',v_name);
            END IF;
            IF v_count=0 THEN CONTINUE; END IF;
            SELECT e.value INTO STRICT v_response FROM JSON_ARRAY_ELEMENTS(v_term->'result_responses') e WHERE e.value->>'parameter_name'=v_name;
            IF (SELECT COUNT(*) FROM JSON_EACH(v_response))<>2
            OR EXISTS (SELECT 1 FROM JSON_EACH(v_response) e GROUP BY e.key HAVING COUNT(*)>1)
            OR EXISTS (SELECT 1 FROM JSON_EACH(v_response) e WHERE e.key NOT IN ('parameter_name','response'))
            OR JSON_TYPEOF(v_response->'response') IS DISTINCT FROM 'string' THEN
                RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid response shape for %s','p_insert_respondent_account',v_name);
            END IF;
            v_text := v_response->>'response';
            IF v_text !~ E'\\A-?[0-9]+(\\.[0-9]{1,2})?\\Z' THEN
                RAISE EXCEPTION USING MESSAGE=FORMAT('%s: invalid money for %s','p_insert_respondent_account',v_name);
            END IF;
            v_value := v_text::NUMERIC;
            IF v_value<v_min OR v_value>v_max THEN
                RAISE EXCEPTION USING MESSAGE=FORMAT('%s: out of bounds %s','p_insert_respondent_account',v_name);
            END IF;
            IF v_name='Amount' THEN v_amount:=v_value; ELSE v_arrears:=v_value; END IF;
        END LOOP;
        v_amounts := ARRAY_APPEND(v_amounts,v_amount);
        IF v_arrears IS NOT NULL THEN v_arrears_values:=ARRAY_APPEND(v_arrears_values,v_arrears); END IF;
    END LOOP;

    SELECT SUM(value) INTO v_orders_amount FROM UNNEST(v_amounts) value;
    SELECT COALESCE(SUM(value),0.00::NUMERIC) INTO v_total_arrears FROM UNNEST(v_arrears_values) value;

    -- Calendar boundaries are always calculated from the original arrears date.
    IF v_payment_period='Weekly' THEN
        v_periods := (v_publication_date-v_arrears_date)/7;
    ELSIF v_payment_period='Fortnightly' THEN
        v_periods := (v_publication_date-v_arrears_date)/14;
    ELSE
        v_stride := CASE v_payment_period WHEN 'Monthly' THEN 1 WHEN 'Quarterly' THEN 3 WHEN 'Yearly' THEN 12 END;
        v_months := (EXTRACT(YEAR FROM v_publication_date)::INTEGER-EXTRACT(YEAR FROM v_arrears_date)::INTEGER)*12
            +EXTRACT(MONTH FROM v_publication_date)::INTEGER-EXTRACT(MONTH FROM v_arrears_date)::INTEGER;
        v_periods := v_months/v_stride;
        v_boundary := (v_arrears_date+MAKE_INTERVAL(months=>v_periods*v_stride))::DATE;
        IF v_boundary>v_publication_date THEN v_periods:=v_periods-1; END IF;
    END IF;
    v_orders_balance := v_total_arrears+v_orders_amount*v_periods::NUMERIC;

    -- All deliberate validation is complete before the allocator reserves one number.
    v_number := public.f_get_account_number(pi_business_unit_id,'respondent_accounts');
    INSERT INTO public.respondent_accounts (
        business_unit_id,
        debtor_detail_id,
        account_number,
        application_id,
        imposed_hearing_date,
        last_hearing_date,
        last_hearing_court_id,
        account_balance,
        orders_balance,
        orders_amount,
        payment_period,
        total_arrears,
        account_status,
        completed_date,
        last_movement_date,
        date_arrears_last_updated,
        last_enforcement_result_id,
        last_enforcement_date,
        originator_name,
        allow_cheques,
        cheque_clearance_period,
        credit_trans_clearance_period,
        casefile_type,
        third_party_contact_id,
        remo_reference,
        ca_reference,
        interest_flag,
        indexation,
        payment_arrangement,
        account_comment,
        version_number
    ) VALUES (
        pi_business_unit_id,
        pi_debtor_detail_id,
        v_number,
        v_application.application_id,
        v_ordered::TIMESTAMP,
        NULL,
        NULL,
        0.00,
        v_orders_balance,
        v_orders_amount,
        v_payment_period,
        v_total_arrears,
        'L',
        NULL,
        v_instant AT TIME ZONE 'UTC',
        v_arrears_date::TIMESTAMP,
        NULL,
        NULL,
        v_originator,
        true,
        v_cheque,
        v_credit,
        pi_casefile_type,
        pi_third_party_contact_id,
        v_remo,
        v_ca,
        v_interest,
        v_indexation,
        v_arrangement,
        v_comment,
        1
    )
    RETURNING respondent_account_id,account_number INTO po_respondent_account_id,po_account_number;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING MESSAGE=FORMAT('%s: no row inserted for %s','p_insert_respondent_account','Respondent Account');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;
