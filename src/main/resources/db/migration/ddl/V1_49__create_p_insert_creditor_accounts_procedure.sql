CREATE PROCEDURE public.p_insert_creditor_accounts(
    IN  pi_business_unit_id       public.draft_casefiles.business_unit_id%TYPE,
    IN  pi_creditor_account_json  JSON,
    IN  pi_major_creditor_id      public.major_creditors.major_creditor_id%TYPE,
    IN  pi_party_id               public.parties.party_id%TYPE,
    IN  pi_third_party_contact_id public.third_party_contact.third_party_contact_id%TYPE,
    OUT po_creditor_account_id    public.creditor_accounts.creditor_account_id%TYPE,
    OUT po_account_number        public.creditor_accounts.account_number%TYPE
)
LANGUAGE plpgsql
AS $$
/**
 * OPAL Program
 *
 * MODULE      : p_insert_creditor_accounts
 *
 * DESCRIPTION : Create one creditor account from validated input; allocate once
 *               and return its ID and number. Caller owns publication transaction.
 *
 * PARAMETERS  : IN  pi_business_unit_id       - Owning Business Unit
 *             : IN  pi_creditor_account_json  - Validated Applicant/Minor object; SQL NULL for Major
 *             : IN  pi_major_creditor_id      - Resolved Major reference; SQL NULL for Party path
 *             : IN  pi_party_id               - Existing Minor Creditor Party; SQL NULL for Major
 *             : IN  pi_third_party_contact_id - Optional contact; SQL NULL for Major
 *             : OUT po_creditor_account_id    - Generated ID from the inserted row
 *             : OUT po_account_number         - Allocated number from that same row
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket    Nature of Change
 * ----------  -------------  --------  -----------------------------------------
 * 13/10/2026  Frankie Moran  PO-10643  Create the creditor account insertion procedure
 */
DECLARE
    v_creditor_account_type public.creditor_accounts.creditor_account_type%TYPE;
    v_party_account_type public.parties.account_type%TYPE;
    v_major_business_unit_id public.major_creditors.business_unit_id%TYPE;
    v_bank_account_details JSON;
    v_bank_account_name TEXT;
    v_bank_sort_code TEXT;
    v_bank_account_number TEXT;
    v_bank_account_reference TEXT;
    v_non_uk_bank_detail JSON;
    v_pay_by_bacs BOOLEAN := false;
    v_account_number TEXT;

BEGIN
    po_creditor_account_id := NULL;
    po_account_number := NULL;

    -- The separate foreign keys cannot express exclusive creditor identity.
    IF (pi_party_id IS NULL) = (pi_major_creditor_id IS NULL) THEN
        RAISE EXCEPTION USING MESSAGE = FORMAT(
            'p_insert_creditor_accounts: identity selection failed; Party = %s, Major Creditor = %s',
            pi_party_id,pi_major_creditor_id);
    END IF;

    IF pi_major_creditor_id IS NOT NULL THEN
        IF pi_creditor_account_json IS NOT NULL OR pi_third_party_contact_id IS NOT NULL THEN
            RAISE EXCEPTION USING MESSAGE = FORMAT(
                'p_insert_creditor_accounts: Major Creditor inputs failed; Major Creditor = %s',
                pi_major_creditor_id);
        END IF;

        -- Check existing reference ownership; absence remains native FK protection.
        SELECT m.business_unit_id INTO v_major_business_unit_id
        FROM public.major_creditors m WHERE m.major_creditor_id=pi_major_creditor_id;

        IF FOUND AND v_major_business_unit_id<>pi_business_unit_id THEN
            RAISE EXCEPTION USING MESSAGE = FORMAT(
                'p_insert_creditor_accounts: Major Creditor pairing failed; Major Creditor = %s, BU = %s',
                pi_major_creditor_id,pi_business_unit_id);
        END IF;

        v_creditor_account_type := 'MJ';
    ELSE
        SELECT p.account_type INTO v_party_account_type
        FROM public.parties p WHERE p.party_id=pi_party_id;

        IF FOUND AND v_party_account_type IS DISTINCT FROM 'Minor Creditor'::public.t_party_account_type_enum THEN
            RAISE EXCEPTION USING MESSAGE = FORMAT(
                'p_insert_creditor_accounts: Party classification failed; Party = %s',pi_party_id);
        END IF;

        v_creditor_account_type := 'MN';
        v_bank_account_details := pi_creditor_account_json->'bank_account_details';

        -- Select storage mapping for the canonical object already validated upstream.
        CASE v_bank_account_details->>'bank_account_type'
            WHEN 'UK Bank' THEN
                v_pay_by_bacs := true;
                v_bank_account_name := v_bank_account_details->'uk_bank_details'->>'account_name';
                v_bank_sort_code := v_bank_account_details->'uk_bank_details'->>'sort_code';
                v_bank_account_number := v_bank_account_details->'uk_bank_details'->>'account_number';
                v_bank_account_reference := v_bank_account_details->'uk_bank_details'->>'payment_reference';
            WHEN 'Non-UK Bank' THEN
                v_pay_by_bacs := true;
                v_non_uk_bank_detail := v_bank_account_details->'non_uk_bank_details';
            WHEN 'None or not applicable' THEN
                v_pay_by_bacs := false;
        END CASE;
    END IF;

    -- The real allocator owns reservation, checksum and bounded collision recovery.
    v_account_number := public.f_get_account_number(
        pi_business_unit_id,'creditor_accounts'::public.t_associated_record_type_enum);

    INSERT INTO public.creditor_accounts (
        business_unit_id,
        account_number,
        creditor_account_type,
        major_creditor_id,
        minor_creditor_party_id,
        from_suspense,
        hold_payout,
        pay_by_bacs,
        bank_sort_code,
        bank_account_number,
        bank_account_name,
        bank_account_reference,
        third_party_contact_id,
        non_uk_bank_detail
    ) VALUES (
        pi_business_unit_id,
        v_account_number,
        v_creditor_account_type,
        pi_major_creditor_id,
        pi_party_id,
        false,
        false,
        v_pay_by_bacs,
        v_bank_sort_code,
        v_bank_account_number,
        v_bank_account_name,
        v_bank_account_reference,
        pi_third_party_contact_id,
        v_non_uk_bank_detail
    ) RETURNING creditor_account_id,account_number INTO po_creditor_account_id,po_account_number;

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;
COMMENT ON PROCEDURE public.p_insert_creditor_accounts(SMALLINT,JSON,BIGINT,BIGINT,BIGINT)
    IS 'Create one creditor account from validated input; allocate once and return its ID and number. Caller owns transaction and publication.';
