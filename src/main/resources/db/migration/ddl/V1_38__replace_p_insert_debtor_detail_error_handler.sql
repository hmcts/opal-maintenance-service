CREATE OR REPLACE PROCEDURE public.p_insert_debtor_detail(
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
 * DESCRIPTION : Insert nullable debtor detail with strict widths and unchanged error propagation.
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
 * 13/10/2026  Frankie Moran  PO-10644  Reject over-width text including excess spaces.
 * 15/10/2026  Frankie Moran  PO-10644  Add common rethrow block and clarify INSERT mapping.
 */
DECLARE
    c_name_width CONSTANT INTEGER := 50;
    c_reference_width CONSTANT INTEGER := 35;
    c_email_width CONSTANT INTEGER := 80;
    c_telephone_width CONSTANT INTEGER := 35;
    c_address_width CONSTANT INTEGER := 35;
    c_postcode_width CONSTANT INTEGER := 10;
    c_information_width CONSTANT INTEGER := 200;
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

    -- Reject excess spaces too; native VARCHAR assignment would silently discard them.
    IF CHAR_LENGTH(pi_debtor_detail_json->>'employer_name') > c_name_width
       OR CHAR_LENGTH(pi_debtor_detail_json->>'employee_reference') > c_reference_width
       OR CHAR_LENGTH(pi_debtor_detail_json->>'employer_email_address') > c_email_width
       OR CHAR_LENGTH(pi_debtor_detail_json->>'employer_telephone_number') > c_telephone_width
       OR CHAR_LENGTH(pi_debtor_detail_json #>> '{employer_address,address_line_1}') > c_address_width
       OR CHAR_LENGTH(pi_debtor_detail_json #>> '{employer_address,address_line_2}') > c_address_width
       OR CHAR_LENGTH(pi_debtor_detail_json #>> '{employer_address,address_line_3}') > c_address_width
       OR CHAR_LENGTH(pi_debtor_detail_json #>> '{employer_address,address_line_4}') > c_address_width
       OR CHAR_LENGTH(pi_debtor_detail_json #>> '{employer_address,address_line_5}') > c_address_width
       OR CHAR_LENGTH(pi_debtor_detail_json #>> '{employer_address,postcode}') > c_postcode_width
       OR CHAR_LENGTH(pi_other_personal_information) > c_information_width THEN
        RAISE EXCEPTION 'p_insert_debtor_detail: mapped value exceeds its storage width'
            USING ERRCODE = '22001';
    END IF;

    -- Persist the canonical fields and separate information using the existing default and FK.
    INSERT INTO public.debtor_detail (
        employer_name,
        employee_reference,
        employer_email,
        employer_telephone,
        employer_address_line_1,
        employer_address_line_2,
        employer_address_line_3,
        employer_address_line_4,
        employer_address_line_5,
        employer_postcode,
        employer_country_id,
        other_personal_information
    ) VALUES (
        pi_debtor_detail_json->>'employer_name',
        pi_debtor_detail_json->>'employee_reference',
        pi_debtor_detail_json->>'employer_email_address',
        pi_debtor_detail_json->>'employer_telephone_number',
        pi_debtor_detail_json #>> '{employer_address,address_line_1}',
        pi_debtor_detail_json #>> '{employer_address,address_line_2}',
        pi_debtor_detail_json #>> '{employer_address,address_line_3}',
        pi_debtor_detail_json #>> '{employer_address,address_line_4}',
        pi_debtor_detail_json #>> '{employer_address,address_line_5}',
        pi_debtor_detail_json #>> '{employer_address,postcode}',
        v_country_id,
        pi_other_personal_information
    )
    RETURNING debtor_detail_id INTO po_debtor_detail_id;

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;
COMMENT ON PROCEDURE public.p_insert_debtor_detail(JSON,VARCHAR)
IS 'Insert one nullable Debtor Detail row and return its generated identifier; caller owns the transaction';
