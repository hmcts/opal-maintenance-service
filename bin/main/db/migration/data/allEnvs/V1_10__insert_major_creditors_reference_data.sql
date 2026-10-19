/**
 * OPAL Program
 *
 * MODULE      : V1_10__insert_major_creditors_reference_data.sql
 *
 * DESCRIPTION : Seed the ten approved RM Central Authorities, resolving Country
 *               identifiers and preserving identical records on a direct rerun.
 *
 * CHANGE HISTORY:
 *
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * 23/09/2026  Chris Larkin  PO-10296      Insert approved Central Authority data
 */

-- Execute the complete script within one caller-managed transaction.
-- Required tables and Country records must exist, with Business Unit 44 loaded.

DROP TABLE IF EXISTS pg_temp.temp_major_creditors_seed;

CREATE TEMP TABLE temp_major_creditors_seed (
    business_unit_id     SMALLINT NOT NULL DEFAULT 44,
    major_creditor_code  VARCHAR(4) NOT NULL,
    name                VARCHAR(100) NOT NULL,
    address_line_1      VARCHAR(35) NOT NULL,
    address_line_2      VARCHAR(35),
    address_line_3      VARCHAR(35),
    address_line_4      VARCHAR(35),
    address_line_5      VARCHAR(35),
    postcode            VARCHAR(10),
    country_id          BIGINT,
    contact_name        VARCHAR(35),
    contact_email       VARCHAR(254),
    active              BOOLEAN NOT NULL DEFAULT TRUE,
    central_authority   BOOLEAN NOT NULL DEFAULT TRUE,
    country_name        VARCHAR(100) NOT NULL,
    PRIMARY KEY (business_unit_id, major_creditor_code)
);

-- Omitted optional fields remain NULL, as supplied.
-- country_name is staging-only information from the source mappings.
INSERT INTO pg_temp.temp_major_creditors_seed (
    major_creditor_code,
    name,
    address_line_1,
    address_line_2,
    address_line_3,
    postcode,
    country_name
)
VALUES
    (
        '0001',
        'Urad pro mezinarodnepravni ochranu deti',
        'Silingrovo nam 3/4', 'Brno', NULL,
        '602 00', 'Czech Republic'
    ),
    (
        '0002',
        'Kansanelakelaitos',
        'Perintakeskus, PL 50', 'Helsinki', NULL,
        '00601', 'Finland'
    ),
    (
        '0003',
        'Forsakringskassan',
        'Box 1164', 'Visby', NULL,
        'SE-621 22', 'Sweden'
    ),
    (
        '0004',
        'Uzturlīdzekļu garantiju fonda administrācija',
        'Raina bulvaris 15', 'Rīga', NULL,
        'LV-1050', 'Latvia'
    ),
    (
        '0005',
        'Vasario 16-Osios G 4',
        'Mazeikiai', NULL, NULL,
        'LT-89225', 'Lithuania'
    ),
    (
        '0006',
        'Landelijk Bureau Inning Onderhoudsbijdragen',
        'Postbus 8901', 'Rotterdam', NULL,
        '3009AX', 'Netherlands'
    ),
    (
        '0007',
        'Inland Revenue Child Support Hague Convention',
        'PO Box 39010 Wellington', 'Mail Centre', 'Lower Hutt',
        '5045', 'New Zealand'
    ),
    (
        '0008',
        'The Collection Agency for Child Support and Overpaid Benefits',
        'Kirkenes', NULL, NULL,
        'NO-9917', 'Norway'
    ),
    (
        '0009',
        'Centre of International Legal Protection of Children and Youth',
        'Spitalska 8 P.O. Box 57', 'Bratislava', NULL,
        '81499', 'Slovakia'
    ),
    (
        '0010',
        'c/o Services Australia',
        'GPO Box 9815,', 'Melbourne', 'Victoria',
        '3001', 'Australia'
    );

-- Resolve exactly one Country per staged record.
DO $$
DECLARE
    v_creditor   RECORD;
    v_country_id BIGINT;
BEGIN
    FOR v_creditor IN
        SELECT business_unit_id, major_creditor_code, country_name
        FROM pg_temp.temp_major_creditors_seed
        ORDER BY major_creditor_code
    LOOP
        BEGIN
            SELECT c.country_id
            INTO STRICT v_country_id
            FROM public.countries c
            WHERE c.country_name = v_creditor.country_name;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE EXCEPTION
                    'No Country found for creditor %: %',
                    v_creditor.major_creditor_code,
                    v_creditor.country_name;

            WHEN TOO_MANY_ROWS THEN
                RAISE EXCEPTION
                    'Multiple Countries found for creditor %: %',
                    v_creditor.major_creditor_code,
                    v_creditor.country_name;
        END;

        UPDATE pg_temp.temp_major_creditors_seed
        SET country_id = v_country_id
        WHERE business_unit_id = v_creditor.business_unit_id
          AND major_creditor_code = v_creditor.major_creditor_code;
    END LOOP;
END;
$$;

-- An existing business key must have exactly the expected values.
-- IS DISTINCT FROM compares nullable fields safely.
DO $$
DECLARE
    v_conflicting_codes TEXT;
BEGIN
    SELECT STRING_AGG(
        s.major_creditor_code,
        ', ' ORDER BY s.major_creditor_code
    )
    INTO v_conflicting_codes
    FROM pg_temp.temp_major_creditors_seed s
    JOIN public.major_creditors m
      ON m.business_unit_id = s.business_unit_id
     AND m.major_creditor_code = s.major_creditor_code
    WHERE ROW(
        m.name,
        m.address_line_1,
        m.address_line_2,
        m.address_line_3,
        m.address_line_4,
        m.address_line_5,
        m.postcode,
        m.country_id,
        m.contact_name,
        m.contact_email,
        m.active,
        m.central_authority
    ) IS DISTINCT FROM ROW(
        s.name,
        s.address_line_1,
        s.address_line_2,
        s.address_line_3,
        s.address_line_4,
        s.address_line_5,
        s.postcode,
        s.country_id,
        s.contact_name,
        s.contact_email,
        s.active,
        s.central_authority
    );

    IF v_conflicting_codes IS NOT NULL THEN
        RAISE EXCEPTION
            'Existing Major Creditors differ from the supplied seed '
            'for Business Unit 44, codes: %',
            v_conflicting_codes;
    END IF;
END;
$$;

-- Insert missing records only.
-- Existing identical records retain their generated IDs.
-- Foreign keys enforce Business Unit and Country existence.
INSERT INTO public.major_creditors (
    business_unit_id,
    major_creditor_code,
    name,
    address_line_1,
    address_line_2,
    address_line_3,
    address_line_4,
    address_line_5,
    postcode,
    country_id,
    contact_name,
    contact_email,
    active,
    central_authority
)
SELECT
    s.business_unit_id,
    s.major_creditor_code,
    s.name,
    s.address_line_1,
    s.address_line_2,
    s.address_line_3,
    s.address_line_4,
    s.address_line_5,
    s.postcode,
    s.country_id,
    s.contact_name,
    s.contact_email,
    s.active,
    s.central_authority
FROM pg_temp.temp_major_creditors_seed s
WHERE NOT EXISTS (
    SELECT 1
    FROM public.major_creditors m
    WHERE m.business_unit_id = s.business_unit_id
      AND m.major_creditor_code = s.major_creditor_code
)
ORDER BY s.major_creditor_code;

DROP TABLE pg_temp.temp_major_creditors_seed;
