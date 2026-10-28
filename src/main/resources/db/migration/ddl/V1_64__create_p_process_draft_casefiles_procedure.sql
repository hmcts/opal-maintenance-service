CREATE OR REPLACE PROCEDURE public.p_process_draft_casefiles(
    IN pi_draft_casefile_id public.draft_casefiles.draft_casefile_id%TYPE,
    OUT po_respondent_account_id public.respondent_accounts.respondent_account_id%TYPE,
    OUT po_account_number public.respondent_accounts.account_number%TYPE,
    OUT po_published_accounts JSON
)
LANGUAGE plpgsql
AS $$
/**
 * OPAL Program
 *
 * MODULE      : p_process_draft_casefiles
 *
 * DESCRIPTION : Publish one locked, eligible persisted Draft Casefile using the
 *               established insertion helpers. The caller owns its transaction
 *               and draft completion, snapshot, version and status updates.
 *
 * PARAMETERS  : IN pi_draft_casefile_id - Authoritative persisted Draft Casefile ID.
 *             : OUT po_respondent_account_id - Generated Respondent Account ID.
 *             : OUT po_account_number - Generated Respondent Account number.
 *             : OUT po_published_accounts - Respondent, Applicant and Minor identities.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket        Nature of Change
 * ----------  -------------  ------------  ----------------------------------------
 * 18/10/2026  Frankie Moran  PO-10655      Create single-draft publication orchestration.
 */
DECLARE
    c_whitespace CONSTANT TEXT := U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000';
    c_max_minor_sequence CONSTANT NUMERIC := 2147483647;
    v_draft public.draft_casefiles%ROWTYPE;
    v_account JSON;
    v_respondent JSON;
    v_applicant JSON;
    v_minors JSON;
    v_order_details JSON;
    v_terms JSON;
    v_role JSON;
    v_roles JSON[];
    v_role_index INTEGER;
    v_party JSON;
    v_individual JSON;
    v_debtor JSON;
    v_employer_address JSON;
    v_information TEXT;
    v_has_debtor_data BOOLEAN := FALSE;
    v_minor JSON;
    v_minor_sequence INTEGER;
    v_minor_sequences INTEGER[] := ARRAY[]::INTEGER[];
    v_sequence_number NUMERIC;
    v_term JSON;
    v_creditor_type TEXT;
    v_reference public.major_creditors%ROWTYPE;
    v_central_authority_id public.major_creditors.major_creditor_id%TYPE;
    v_major_reference_ids BIGINT[] := ARRAY[]::BIGINT[];
    v_term_major_reference_ids BIGINT[] := ARRAY[]::BIGINT[];
    v_term_major_reference_id public.major_creditors.major_creditor_id%TYPE;
    v_requires_creditor public.results.requires_creditor%TYPE;
    v_respondent_party_id public.parties.party_id%TYPE;
    v_applicant_party_id public.parties.party_id%TYPE;
    v_minor_party_id public.parties.party_id%TYPE;
    v_minor_party_ids BIGINT[] := ARRAY[]::BIGINT[];
    v_respondent_contact_id public.third_party_contact.third_party_contact_id%TYPE := NULL;
    v_applicant_contact_id public.third_party_contact.third_party_contact_id%TYPE := NULL;
    v_debtor_detail_id public.debtor_detail.debtor_detail_id%TYPE := NULL;
    v_respondent_account_id public.respondent_accounts.respondent_account_id%TYPE;
    v_respondent_account_number public.respondent_accounts.account_number%TYPE;
    v_applicant_account_id public.creditor_accounts.creditor_account_id%TYPE;
    v_applicant_account_number public.creditor_accounts.account_number%TYPE;
    v_minor_account_id public.creditor_accounts.creditor_account_id%TYPE;
    v_minor_account_number public.creditor_accounts.account_number%TYPE;
    v_minor_account_ids BIGINT[] := ARRAY[]::BIGINT[];
    v_minor_account_numbers VARCHAR[] := ARRAY[]::VARCHAR[];
    v_major_reference_id public.major_creditors.major_creditor_id%TYPE;
    v_major_account_id public.creditor_accounts.creditor_account_id%TYPE;
    v_major_account_number public.creditor_accounts.account_number%TYPE;
    v_major_account_ids BIGINT[] := ARRAY[]::BIGINT[];
    v_term_creditor_account_id public.creditor_accounts.creditor_account_id%TYPE;
    v_minor_output JSON;
    v_index INTEGER;
    v_term_index INTEGER;

BEGIN
    IF pi_draft_casefile_id IS NULL THEN
        RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: draft casefile identifier is required');
    END IF;

    -- Lock by identity alone so an existing ineligible draft is never reported absent.
    SELECT * INTO STRICT v_draft
    FROM public.draft_casefiles
    WHERE draft_casefile_id = pi_draft_casefile_id
    FOR UPDATE;

    IF v_draft.casefile_status <> 'PUBLISHING_PENDING' THEN
        RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: draft casefile is not publishing pending');
    END IF;

    IF v_draft.account_id IS NOT NULL OR v_draft.account_number IS NOT NULL THEN
        RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: draft casefile already has publication identity');
    END IF;

    IF v_draft.validated_date IS NULL OR v_draft.validated_by IS NULL
       OR v_draft.validated_by_name IS NULL
       OR TRANSLATE(v_draft.validated_by, c_whitespace, '') = ''
       OR TRANSLATE(v_draft.validated_by_name, c_whitespace, '') = '' THEN
        RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: draft casefile approval is incomplete');
    END IF;

    IF v_draft.validated_by = v_draft.submitted_by THEN
        RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: draft casefile approval is not independent');
    END IF;

    -- Check consumed decoded members before selecting original child subtrees.
    IF JSON_TYPEOF(v_draft.casefile) IS DISTINCT FROM 'object' THEN
        RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: invalid publication structure');
    END IF;

    IF EXISTS (SELECT 1 FROM JSON_EACH(v_draft.casefile)
        WHERE key IN ('respondent_account', 'applicant', 'minor_creditors')
        GROUP BY key HAVING COUNT(*) > 1) THEN
        RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: invalid publication structure');
    END IF;

    v_account := v_draft.casefile->'respondent_account';
    v_applicant := v_draft.casefile->'applicant';
    v_minors := COALESCE(v_draft.casefile->'minor_creditors', '[]'::JSON);

    IF JSON_TYPEOF(v_account) IS DISTINCT FROM 'object'
       OR JSON_TYPEOF(v_applicant) IS DISTINCT FROM 'object'
       OR JSON_TYPEOF(v_minors) IS DISTINCT FROM 'array' THEN
        RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: invalid publication structure');
    END IF;

    IF EXISTS (SELECT 1 FROM JSON_EACH(v_account)
        WHERE key IN ('respondent', 'order_details', 'notes', 'central_authority_code')
        GROUP BY key HAVING COUNT(*) > 1) THEN
        RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: invalid publication structure');
    END IF;

    v_respondent := v_account->'respondent';
    v_order_details := v_account->'order_details';

    IF JSON_TYPEOF(v_respondent) IS DISTINCT FROM 'object'
       OR JSON_TYPEOF(v_order_details) IS DISTINCT FROM 'object'
       OR (v_account->'notes' IS NOT NULL AND JSON_TYPEOF(v_account->'notes') IS DISTINCT FROM 'object') THEN
        RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: invalid publication structure');
    END IF;

    IF EXISTS (SELECT 1 FROM JSON_EACH(v_order_details)
        WHERE key = 'order_terms' GROUP BY key HAVING COUNT(*) > 1) THEN
        RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: invalid publication structure');
    END IF;

    v_terms := v_order_details->'order_terms';

    IF JSON_TYPEOF(v_terms) IS DISTINCT FROM 'array' THEN
        RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: invalid publication structure');
    END IF;

    IF JSON_ARRAY_LENGTH(v_terms) = 0 THEN
        RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: invalid publication structure');
    END IF;

    -- Validate role selection without replacing each child's field validation.
    v_roles := ARRAY[v_respondent, v_applicant] || ARRAY(SELECT value FROM JSON_ARRAY_ELEMENTS(v_minors));
    FOR v_role_index IN 1..CARDINALITY(v_roles) LOOP
        v_role := v_roles[v_role_index];

        IF JSON_TYPEOF(v_role) IS DISTINCT FROM 'object' THEN
            RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: invalid publication structure');
        END IF;

        IF EXISTS (SELECT 1 FROM JSON_EACH(v_role)
            WHERE key = 'party_details'
               OR (v_role_index <= 2 AND key = 'third_party_details')
               OR (v_role_index = 1 AND key = 'debtor_details')
               OR (v_role_index > 2 AND key = 'creditor_sequence')
            GROUP BY key HAVING COUNT(*) > 1) THEN
            RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: invalid publication structure');
        END IF;

        IF v_role_index <= 2 AND v_role->'third_party_details' IS NOT NULL
           AND JSON_TYPEOF(v_role->'third_party_details') IS DISTINCT FROM 'object' THEN
            RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: invalid publication structure');
        END IF;

        v_party := v_role->'party_details';

        IF JSON_TYPEOF(v_party) IS DISTINCT FROM 'object' THEN
            RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: invalid publication structure');
        END IF;

        IF EXISTS (SELECT 1 FROM JSON_EACH(v_party)
            WHERE key IN ('organisation', 'individual_details', 'organisation_details', 'aliases')
            GROUP BY key HAVING COUNT(*) > 1) THEN
            RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: invalid publication structure');
        END IF;

        IF JSON_TYPEOF(v_party->'organisation') IS DISTINCT FROM 'boolean'
           OR (v_party->'aliases' IS NOT NULL AND JSON_TYPEOF(v_party->'aliases') IS DISTINCT FROM 'array') THEN
            RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: invalid publication structure');
        END IF;

        IF (v_party->>'organisation')::BOOLEAN THEN
            IF JSON_TYPEOF(v_party->'organisation_details') IS DISTINCT FROM 'object'
               OR v_party->'individual_details' IS NOT NULL THEN
                RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: invalid publication structure');
            END IF;
        ELSE
            IF JSON_TYPEOF(v_party->'individual_details') IS DISTINCT FROM 'object'
               OR v_party->'organisation_details' IS NOT NULL THEN
                RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: invalid publication structure');
            END IF;
        END IF;
    END LOOP;

    -- Independent information is text; employer leaves retain the permissive child contract.
    v_individual := v_respondent #> '{party_details,individual_details}';

    IF v_individual IS NOT NULL THEN
        IF EXISTS (SELECT 1 FROM JSON_EACH(v_individual)
            WHERE key = 'other_personal_information' GROUP BY key HAVING COUNT(*) > 1)
           OR JSON_TYPEOF(v_individual->'other_personal_information') NOT IN ('string', 'null') THEN
            RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: invalid publication structure');
        END IF;
    END IF;

    v_information := v_individual->>'other_personal_information';
    v_debtor := v_respondent->'debtor_details';

    IF JSON_TYPEOF(v_debtor) NOT IN ('object', 'null') THEN
        RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: invalid publication structure');
    END IF;

    IF JSON_TYPEOF(v_debtor) = 'object' THEN
        IF EXISTS (SELECT 1 FROM JSON_EACH(v_debtor)
            WHERE key IN ('employer_name', 'employee_reference', 'employer_email_address',
                'employer_telephone_number', 'employer_address')
            GROUP BY key HAVING COUNT(*) > 1) THEN
            RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: invalid publication structure');
        END IF;

        v_employer_address := v_debtor->'employer_address';

        IF JSON_TYPEOF(v_employer_address) NOT IN ('object', 'null') THEN
            RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: invalid publication structure');
        END IF;

        IF JSON_TYPEOF(v_employer_address) = 'object' THEN
            IF EXISTS (SELECT 1 FROM JSON_EACH(v_employer_address)
                WHERE key IN ('address_line_1', 'address_line_2', 'address_line_3',
                    'address_line_4', 'address_line_5', 'postcode', 'cjs_code')
                GROUP BY key HAVING COUNT(*) > 1) THEN
                RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: invalid publication structure');
            END IF;
        END IF;
    END IF;

    v_has_debtor_data := v_information IS NOT NULL
        OR v_debtor->>'employer_name' IS NOT NULL
        OR v_debtor->>'employee_reference' IS NOT NULL
        OR v_debtor->>'employer_email_address' IS NOT NULL
        OR v_debtor->>'employer_telephone_number' IS NOT NULL
        OR v_employer_address->>'address_line_1' IS NOT NULL
        OR v_employer_address->>'address_line_2' IS NOT NULL
        OR v_employer_address->>'address_line_3' IS NOT NULL
        OR v_employer_address->>'address_line_4' IS NOT NULL
        OR v_employer_address->>'address_line_5' IS NOT NULL
        OR v_employer_address->>'postcode' IS NOT NULL
        OR v_employer_address->>'cjs_code' IS NOT NULL;

    -- Source sequences are correlations, independent of positions and generated IDs.
    FOR v_minor IN SELECT value FROM JSON_ARRAY_ELEMENTS(v_minors) LOOP
        IF JSON_TYPEOF(v_minor->'creditor_sequence') IS DISTINCT FROM 'number' THEN
            RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: invalid minor creditor correlation');
        END IF;

        -- Even valid JSON numbers beyond NUMERIC capacity are invalid int32 correlations.
        BEGIN
            v_sequence_number := (v_minor->>'creditor_sequence')::NUMERIC;
        EXCEPTION
            WHEN numeric_value_out_of_range THEN
                RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: invalid minor creditor correlation');
        END;

        IF v_sequence_number <> TRUNC(v_sequence_number)
           OR v_sequence_number < 1 OR v_sequence_number > c_max_minor_sequence THEN
            RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: invalid minor creditor correlation');
        END IF;

        v_minor_sequence := v_sequence_number::INTEGER;

        IF v_minor_sequence = ANY(v_minor_sequences) THEN
            RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: invalid minor creditor correlation');
        END IF;

        v_minor_sequences := ARRAY_APPEND(v_minor_sequences, v_minor_sequence);
    END LOOP;

    -- Resolve supplied Authority codes without hiding absent or ineligible references.
    IF v_account->'central_authority_code' IS NOT NULL THEN
        IF JSON_TYPEOF(v_account->'central_authority_code') IS DISTINCT FROM 'string' THEN
            RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: invalid publication structure');
        END IF;

        SELECT * INTO STRICT v_reference
        FROM public.major_creditors
        WHERE business_unit_id = v_draft.business_unit_id
          AND major_creditor_code = v_account->>'central_authority_code';

        IF NOT v_reference.active OR NOT v_reference.central_authority THEN
            RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: required reference is ineligible');
        END IF;

        v_central_authority_id := v_reference.major_creditor_id;
    END IF;

    -- Validate every route before any graph allocation; retain reference IDs by term.
    FOR v_term IN SELECT value FROM JSON_ARRAY_ELEMENTS(v_terms) LOOP
        IF JSON_TYPEOF(v_term) IS DISTINCT FROM 'object' THEN
            RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: invalid publication structure');
        END IF;

        IF EXISTS (SELECT 1 FROM JSON_EACH(v_term)
            WHERE key IN ('creditor_type', 'minor_creditor_sequence', 'major_creditor_code', 'result_id')
            GROUP BY key HAVING COUNT(*) > 1) THEN
            RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: invalid publication structure');
        END IF;

        IF JSON_TYPEOF(v_term->'creditor_type') IS DISTINCT FROM 'string' THEN
            RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: invalid creditor routing');
        END IF;

        v_creditor_type := v_term->>'creditor_type';
        v_term_major_reference_id := NULL;

        IF v_creditor_type = 'Applicant' THEN
            IF v_term->'minor_creditor_sequence' IS NOT NULL OR v_term->'major_creditor_code' IS NOT NULL THEN
                RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: invalid creditor routing');
            END IF;
        ELSIF v_creditor_type = 'Minor Creditor' THEN
            IF v_term->'major_creditor_code' IS NOT NULL OR v_term->'minor_creditor_sequence' IS NULL THEN
                RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: invalid creditor routing');
            END IF;

            IF JSON_TYPEOF(v_term->'minor_creditor_sequence') IS DISTINCT FROM 'number' THEN
                RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: invalid minor creditor correlation');
            END IF;

            -- Even valid JSON numbers beyond NUMERIC capacity are invalid int32 correlations.
            BEGIN
                v_sequence_number := (v_term->>'minor_creditor_sequence')::NUMERIC;
            EXCEPTION
                WHEN numeric_value_out_of_range THEN
                    RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: invalid minor creditor correlation');
            END;

            IF v_sequence_number <> TRUNC(v_sequence_number)
               OR v_sequence_number < 1 OR v_sequence_number > c_max_minor_sequence THEN
                RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: invalid minor creditor correlation');
            END IF;

            IF NOT v_sequence_number::INTEGER = ANY(v_minor_sequences) THEN
                RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: invalid minor creditor correlation');
            END IF;
        ELSIF v_creditor_type = 'Major Creditor' THEN
            IF v_term->'minor_creditor_sequence' IS NOT NULL
               OR JSON_TYPEOF(v_term->'major_creditor_code') IS DISTINCT FROM 'string'
               OR v_term->>'major_creditor_code' = '' THEN
                RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: invalid creditor routing');
            END IF;

            SELECT * INTO STRICT v_reference
            FROM public.major_creditors
            WHERE business_unit_id = v_draft.business_unit_id
              AND major_creditor_code = v_term->>'major_creditor_code';

            IF NOT v_reference.active THEN
                RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: required reference is ineligible');
            END IF;

            v_term_major_reference_id := v_reference.major_creditor_id;

            IF NOT v_term_major_reference_id = ANY(v_major_reference_ids) THEN
                v_major_reference_ids := ARRAY_APPEND(v_major_reference_ids, v_term_major_reference_id);
            END IF;
        ELSE
            RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: invalid creditor routing');
        END IF;

        SELECT requires_creditor INTO STRICT v_requires_creditor
        FROM public.results
        WHERE result_id = v_term->>'result_id';

        IF NOT v_requires_creditor THEN
            RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: unsupported creditor-free result');
        END IF;

        v_term_major_reference_ids := ARRAY_APPEND(v_term_major_reference_ids, v_term_major_reference_id);
    END LOOP;

    -- Retain role-specific identities; original source JSON remains separate from all maps.
    CALL public.p_insert_parties(v_respondent->'party_details',
        'Respondent'::public.t_party_account_type_enum, v_respondent_party_id);
    IF v_respondent_party_id IS NULL THEN
        RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: required child output is missing');
    END IF;

    IF JSON_ARRAY_LENGTH(v_respondent #> '{party_details,aliases}') > 0 THEN
        CALL public.p_insert_party_aliases(v_respondent_party_id, v_respondent #> '{party_details,aliases}');
    END IF;

    CALL public.p_insert_parties(v_applicant->'party_details',
        'Minor Creditor'::public.t_party_account_type_enum, v_applicant_party_id);
    IF v_applicant_party_id IS NULL THEN
        RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: required child output is missing');
    END IF;

    IF JSON_ARRAY_LENGTH(v_applicant #> '{party_details,aliases}') > 0 THEN
        CALL public.p_insert_party_aliases(v_applicant_party_id, v_applicant #> '{party_details,aliases}');
    END IF;

    FOR v_minor IN SELECT value FROM JSON_ARRAY_ELEMENTS(v_minors) LOOP
        v_minor_party_id := NULL;
        CALL public.p_insert_parties(v_minor->'party_details',
            'Minor Creditor'::public.t_party_account_type_enum, v_minor_party_id);
        IF v_minor_party_id IS NULL THEN
            RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: required child output is missing');
        END IF;

        v_minor_party_ids := ARRAY_APPEND(v_minor_party_ids, v_minor_party_id);
        IF JSON_ARRAY_LENGTH(v_minor #> '{party_details,aliases}') > 0 THEN
            CALL public.p_insert_party_aliases(v_minor_party_id, v_minor #> '{party_details,aliases}');
        END IF;
    END LOOP;

    IF v_respondent->'third_party_details' IS NOT NULL THEN
        CALL public.p_insert_third_party_contacts(v_respondent->'third_party_details', v_respondent_contact_id);
        IF v_respondent_contact_id IS NULL THEN
            RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: required child output is missing');
        END IF;
    END IF;

    IF v_applicant->'third_party_details' IS NOT NULL THEN
        CALL public.p_insert_third_party_contacts(v_applicant->'third_party_details', v_applicant_contact_id);
        IF v_applicant_contact_id IS NULL THEN
            RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: required child output is missing');
        END IF;
    END IF;

    IF v_has_debtor_data THEN
        CALL public.p_insert_debtor_detail(v_debtor, v_information, v_debtor_detail_id);
        IF v_debtor_detail_id IS NULL THEN
            RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: required child output is missing');
        END IF;
    END IF;

    CALL public.p_insert_respondent_account(v_draft.business_unit_id, v_draft.casefile_type,
        v_account, v_debtor_detail_id, v_respondent_contact_id,
        v_respondent_account_id, v_respondent_account_number);
    IF v_respondent_account_id IS NULL OR v_respondent_account_number IS NULL
       OR v_respondent_account_number = '' THEN
        RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: required child output is missing');
    END IF;

    CALL public.p_insert_creditor_accounts(v_draft.business_unit_id, v_applicant,
        NULL::BIGINT, v_applicant_party_id, v_applicant_contact_id,
        v_applicant_account_id, v_applicant_account_number);
    IF v_applicant_account_id IS NULL OR v_applicant_account_number IS NULL
       OR v_applicant_account_number = '' THEN
        RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: required child output is missing');
    END IF;

    v_index := 0;
    FOR v_minor IN SELECT value FROM JSON_ARRAY_ELEMENTS(v_minors) LOOP
        v_index := v_index + 1;
        v_minor_account_id := NULL;
        v_minor_account_number := NULL;
        CALL public.p_insert_creditor_accounts(v_draft.business_unit_id, v_minor,
            NULL::BIGINT, v_minor_party_ids[v_index], NULL::BIGINT,
            v_minor_account_id, v_minor_account_number);
        IF v_minor_account_id IS NULL OR v_minor_account_number IS NULL OR v_minor_account_number = '' THEN
            RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: required child output is missing');
        END IF;

        v_minor_account_ids := ARRAY_APPEND(v_minor_account_ids, v_minor_account_id);
        v_minor_account_numbers := ARRAY_APPEND(v_minor_account_numbers, v_minor_account_number);
    END LOOP;

    -- One new account per resolved reference in first-use order, scoped to this invocation.
    FOREACH v_major_reference_id IN ARRAY v_major_reference_ids LOOP
        v_major_account_id := NULL;
        v_major_account_number := NULL;
        CALL public.p_insert_creditor_accounts(v_draft.business_unit_id, NULL::JSON,
            v_major_reference_id, NULL::BIGINT, NULL::BIGINT, v_major_account_id, v_major_account_number);
        IF v_major_account_id IS NULL OR v_major_account_number IS NULL OR v_major_account_number = '' THEN
            RAISE EXCEPTION '%', FORMAT('p_process_draft_casefiles: required child output is missing');
        END IF;

        v_major_account_ids := ARRAY_APPEND(v_major_account_ids, v_major_account_id);
    END LOOP;

    v_term_index := 0;
    FOR v_term IN SELECT value FROM JSON_ARRAY_ELEMENTS(v_terms) LOOP
        v_term_index := v_term_index + 1;
        v_term_creditor_account_id := NULL;
        CASE v_term->>'creditor_type'
            WHEN 'Applicant' THEN
                v_term_creditor_account_id := v_applicant_account_id;
            WHEN 'Minor Creditor' THEN
                v_index := ARRAY_POSITION(v_minor_sequences, (v_term->>'minor_creditor_sequence')::NUMERIC::INTEGER);
                v_term_creditor_account_id := v_minor_account_ids[v_index];
            WHEN 'Major Creditor' THEN
                v_index := ARRAY_POSITION(v_major_reference_ids, v_term_major_reference_ids[v_term_index]);
                v_term_creditor_account_id := v_major_account_ids[v_index];
        END CASE;

        CALL public.p_insert_order_terms(v_respondent_account_id, v_term_creditor_account_id,
            v_draft.submitted_by, v_draft.submitted_by_name, v_term);
    END LOOP;

    IF v_account->'notes' IS NOT NULL THEN
        CALL public.p_insert_notes(v_respondent_account_id,
            v_draft.submitted_by, v_draft.submitted_by_name, v_account->'notes');
    END IF;

    -- Final fan-in preserves the three different associated-identity domains.
    CALL public.p_insert_respondent_account_parties(v_respondent_account_id,
        v_respondent_party_id, 'Respondent'::public.t_association_type_enum);
    CALL public.p_insert_respondent_account_parties(v_respondent_account_id,
        v_applicant_account_id, 'Applicant'::public.t_association_type_enum);
    IF v_central_authority_id IS NOT NULL THEN
        CALL public.p_insert_respondent_account_parties(v_respondent_account_id,
            v_central_authority_id, 'Central Authority'::public.t_association_type_enum);
    END IF;

    SELECT COALESCE(JSON_AGG(JSON_BUILD_OBJECT(
        'creditor_sequence', v_minor_sequences[ordinal],
        'account_id', v_minor_account_ids[ordinal],
        'account_number', v_minor_account_numbers[ordinal]) ORDER BY ordinal), '[]'::JSON)
    INTO v_minor_output
    FROM GENERATE_SUBSCRIPTS(v_minor_sequences, 1) AS source(ordinal);

    -- A failed child/fan-in never exposes a successful partial identity fragment.
    po_respondent_account_id := v_respondent_account_id;
    po_account_number := v_respondent_account_number;
    po_published_accounts := JSON_BUILD_OBJECT(
        'respondent_account', JSON_BUILD_OBJECT('account_id', v_respondent_account_id,
            'account_number', v_respondent_account_number),
        'applicant_account', JSON_BUILD_OBJECT('account_id', v_applicant_account_id,
            'account_number', v_applicant_account_number),
        'minor_creditor_accounts', v_minor_output);

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;
