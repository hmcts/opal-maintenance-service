CREATE PROCEDURE public.p_insert_debtor_detail(
    IN pi_debtor_detail_json JSON,
    IN pi_other_personal_information public.debtor_detail.other_personal_information%TYPE,
    OUT po_debtor_detail_id public.debtor_detail.debtor_detail_id%TYPE
)
LANGUAGE plpgsql
AS $$
/**
 * OPAL Program
 *
 * MODULE      : p_insert_debtor_detail
 *
 * DESCRIPTION : Map nullable canonical debtor input and insert exactly one detail row.
 *
 * PARAMETERS  : IN  pi_debtor_detail_json - Validated Debtor Details object or null.
 *             : IN  pi_other_personal_information - Independently sourced optional information.
 *             : OUT po_debtor_detail_id - Generated identifier of the inserted row.
 *
 * CHANGE HISTORY:
 *
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * 13/10/2026  Frankie Moran  PO-10644  Create debtor detail insertion procedure.
 */
DECLARE
    v_country_code TEXT;
    v_country_id public.countries.country_id%TYPE;

BEGIN
    v_country_code := pi_debtor_detail_json #>> '{employer_address,cjs_code}';

    -- Resolve a supplied code exactly once; native conversion/cardinality errors propagate.
    IF v_country_code IS NOT NULL THEN
        SELECT country_id INTO STRICT v_country_id
        FROM public.countries
        WHERE cjs_code=v_country_code::SMALLINT;
    END IF;

    -- Persist the canonical fields and separate information using the existing default and FK.
    INSERT INTO public.debtor_detail(
        employer_name,employee_reference,employer_email,employer_telephone,
        employer_address_line_1,employer_address_line_2,employer_address_line_3,
        employer_address_line_4,employer_address_line_5,employer_postcode,
        employer_country_id,other_personal_information
    ) VALUES (
        pi_debtor_detail_json->>'employer_name',pi_debtor_detail_json->>'employee_reference',
        pi_debtor_detail_json->>'employer_email_address',pi_debtor_detail_json->>'employer_telephone_number',
        pi_debtor_detail_json #>> '{employer_address,address_line_1}',
        pi_debtor_detail_json #>> '{employer_address,address_line_2}',
        pi_debtor_detail_json #>> '{employer_address,address_line_3}',
        pi_debtor_detail_json #>> '{employer_address,address_line_4}',
        pi_debtor_detail_json #>> '{employer_address,address_line_5}',
        pi_debtor_detail_json #>> '{employer_address,postcode}',
        v_country_id,pi_other_personal_information
    ) RETURNING debtor_detail_id INTO po_debtor_detail_id;
END;
$$;
COMMENT ON PROCEDURE public.p_insert_debtor_detail(JSON,VARCHAR)
IS 'Insert one nullable Debtor Detail row and return its generated identifier; caller owns the transaction';
