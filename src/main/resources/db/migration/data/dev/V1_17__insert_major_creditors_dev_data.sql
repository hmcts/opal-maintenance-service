/**
 * OPAL Program
 *
 * MODULE      : V1_17__insert_major_creditors_dev_data.sql
 *
 * DESCRIPTION : Add synthetic DEV Major Creditor selection and comparison data.
 *               This data is not approved for production or staging.
 *
 * CHANGE HISTORY:
 *
 * Date        Author          Ticket        Nature of Change
 * ----------  --------------  ------------  ----------------------------------------
 * 02/10/2026  Jonathan Duffy   PO-10297      Insert synthetic DEV creditor data
 */

-- Flyway owns the transaction. Existing BU 44 and approved Country data are required.
-- Generated identifiers are intentionally omitted. Colliding keys fail without overwrite.
DO $$
DECLARE
    v_country_id BIGINT;
BEGIN
    SELECT country_id INTO STRICT v_country_id
    FROM public.countries
    WHERE country_name = 'Czech Republic';

    INSERT INTO public.major_creditors (
        business_unit_id, major_creditor_code, name, address_line_1, address_line_2,
        address_line_3, address_line_4, address_line_5,
        postcode, country_id, contact_name, contact_email, active, central_authority
    )
    VALUES
        (44, 'T901', 'Functional Test Major Creditor', '1 Synthetic Test Street',
         'Synthetic Test Town', 'Synthetic Test District', 'Synthetic Test Region',
         'Synthetic Test Province', 'ZZ1 1ZZ', v_country_id,
         'Synthetic Test Contact', 'creditor@example.invalid', TRUE, FALSE),
        (44, 'T902', 'Inactive Functional Test Creditor', '2 Synthetic Test Street',
         NULL, NULL, NULL, NULL, NULL, v_country_id, NULL, NULL, FALSE, FALSE),
        (44, 'T903', 'Functional Test Central Authority', '3 Synthetic Test Street',
         NULL, NULL, NULL, NULL, NULL, v_country_id, NULL, NULL, TRUE, TRUE);
END;
$$;
