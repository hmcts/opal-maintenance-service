/**
 * OPAL Program
 *
 * MODULE      : V1_34__insert_major_creditors_nle_data.sql
 *
 * DESCRIPTION : Add synthetic Major Creditor reference data to non-live environments.
 *
 * CHANGE HISTORY:
 *
 * Date        Author          Ticket    Nature of Change
 * ----------  --------------  --------  ---------------------------------------------
 * 21/10/2026  Jonathan Duffy  PO-10297  Add approved non-live creditor seed.
 */

-- Flyway owns the transaction. Existing BU 44 and one Czech Republic row are required.
-- Generated IDs and unrelated creditors are preserved. Exact reruns do not write rows.
CREATE TEMP TABLE major_creditors_nle_seed ON COMMIT DROP AS
SELECT business_unit_id, major_creditor_code, name,
       address_line_1, address_line_2, address_line_3, address_line_4,
       address_line_5, postcode, country_id, contact_name, contact_email,
       active, central_authority
FROM public.major_creditors
WITH NO DATA;

DO $seed$
DECLARE
    v_country_id BIGINT;
    v_existing_count BIGINT;
BEGIN
    SELECT country_id INTO STRICT v_country_id
      FROM public.countries
     WHERE country_name = 'Czech Republic';

    INSERT INTO pg_temp.major_creditors_nle_seed (
        business_unit_id, major_creditor_code, name,
        address_line_1, address_line_2, address_line_3, address_line_4,
        address_line_5, postcode, country_id, contact_name, contact_email,
        active, central_authority
    )
    VALUES
        (44, 'T901', 'Functional Test Major Creditor',
         '1 Synthetic Test Street', 'Synthetic Test Town',
         'Synthetic Test District', 'Synthetic Test Region',
         'Synthetic Test Province', 'ZZ1 1ZZ', v_country_id,
         'Synthetic Test Contact', 'creditor@example.invalid', TRUE, FALSE),
        (44, 'T902', 'Inactive Functional Test Creditor',
         '2 Synthetic Test Street', NULL, NULL, NULL, NULL, NULL,
         v_country_id, NULL, NULL, FALSE, FALSE),
        (44, 'T903', 'Functional Test Central Authority',
         '3 Synthetic Test Street', NULL, NULL, NULL, NULL, NULL,
         v_country_id, NULL, NULL, TRUE, TRUE);

    SELECT COUNT(*) INTO v_existing_count
      FROM public.major_creditors
     WHERE business_unit_id = 44
       AND major_creditor_code IN ('T901', 'T902', 'T903');

    IF v_existing_count = 0 THEN
        INSERT INTO public.major_creditors (
            business_unit_id, major_creditor_code, name,
            address_line_1, address_line_2, address_line_3, address_line_4,
            address_line_5, postcode, country_id, contact_name, contact_email,
            active, central_authority
        )
        SELECT business_unit_id, major_creditor_code, name,
               address_line_1, address_line_2, address_line_3, address_line_4,
               address_line_5, postcode, country_id, contact_name, contact_email,
               active, central_authority
          FROM pg_temp.major_creditors_nle_seed
         ORDER BY major_creditor_code;
    ELSIF v_existing_count <> 3 OR EXISTS (
        SELECT 1 FROM pg_temp.major_creditors_nle_seed e
        LEFT JOIN public.major_creditors m
          ON m.business_unit_id = e.business_unit_id
         AND m.major_creditor_code = e.major_creditor_code
        WHERE m.major_creditor_id IS NULL
           OR ROW(m.name, m.address_line_1, m.address_line_2, m.address_line_3,
                  m.address_line_4, m.address_line_5, m.postcode, m.country_id,
                  m.contact_name, m.contact_email, m.active, m.central_authority)
              IS DISTINCT FROM
              ROW(e.name, e.address_line_1, e.address_line_2, e.address_line_3,
                  e.address_line_4, e.address_line_5, e.postcode, e.country_id,
                  e.contact_name, e.contact_email, e.active, e.central_authority)
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0001',
            MESSAGE = 'Non-live Major Creditor seed is partial or conflicts with expected data';
    END IF;
END;
$seed$;

-- Direct SQL reruns in a caller transaction must not retain this scratch table.
DROP TABLE pg_temp.major_creditors_nle_seed;
