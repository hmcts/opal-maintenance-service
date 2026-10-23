CREATE PROCEDURE public.p_insert_third_party_contacts(
    IN pi_third_party_contact_json JSON,
    OUT po_third_party_contact_id
        public.third_party_contact.third_party_contact_id%TYPE
)
LANGUAGE plpgsql
AS $$
/**
 * OPAL Program
 *
 * MODULE      : p_insert_third_party_contacts
 *
 * DESCRIPTION : Validate and insert one neutral contact with original values
 *               and a resolved Country ID; return the generated contact ID.
 *
 * PARAMETERS  : IN  pi_third_party_contact_json - One contact JSON object.
 *             : OUT po_third_party_contact_id   - Generated BIGINT contact ID.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket        Nature of Change
 * ----------  -------------  ------------  ----------------------------------------
 * 17/10/2026  Frankie Moran  PO-10651      Create contact insertion procedure.
 * 22/10/2026  Frankie Moran  PO-10655  Reissue unchanged behavior under the approved F3 lineage.
 */
DECLARE
    c_whitespace CONSTANT TEXT :=
        CHR(9)||CHR(10)||CHR(11)||CHR(12)||CHR(13)||CHR(32)||CHR(133)
        ||CHR(160)||CHR(5760)||CHR(8192)||CHR(8193)||CHR(8194)
        ||CHR(8195)||CHR(8196)||CHR(8197)||CHR(8198)||CHR(8199)
        ||CHR(8200)||CHR(8201)||CHR(8202)||CHR(8232)||CHR(8233)
        ||CHR(8239)||CHR(8287)||CHR(12288);
    c_text_limit CONSTANT INTEGER := 40;
    c_address_limit CONSTANT INTEGER := 30;
    c_postcode_limit CONSTANT INTEGER := 10;
    c_cjs_min CONSTANT INTEGER := -32768;
    c_cjs_max CONSTANT INTEGER := 32767;
    v_address JSON;
    v_field RECORD;
    v_text TEXT;
    v_cjs_numeric NUMERIC;
    v_country_id public.countries.country_id%TYPE;
    v_rows BIGINT;

BEGIN
    IF JSON_TYPEOF(pi_third_party_contact_json) IS DISTINCT FROM 'object' THEN
        RAISE EXCEPTION USING MESSAGE = FORMAT(
            '%s: %s', 'p_insert_third_party_contacts', 'contact must be an object');
    END IF;

    -- Enumerate decoded original members before extraction can discard duplicates.
    IF EXISTS (SELECT 1 FROM JSON_EACH(pi_third_party_contact_json)
               WHERE key COLLATE "C" <> ALL (ARRAY['name','relationship','reference','address']::TEXT[]))
       OR EXISTS (SELECT 1 FROM JSON_EACH(pi_third_party_contact_json)
                  GROUP BY key COLLATE "C" HAVING COUNT(*) > 1) THEN
        RAISE EXCEPTION USING MESSAGE = FORMAT(
            '%s: %s', 'p_insert_third_party_contacts', 'contact has invalid members');
    END IF;

    IF JSON_TYPEOF(pi_third_party_contact_json->'address') IS DISTINCT FROM 'object' THEN
        RAISE EXCEPTION USING MESSAGE = FORMAT(
            '%s: %s', 'p_insert_third_party_contacts', 'address must be an object');
    END IF;

    v_address := pi_third_party_contact_json->'address';

    IF EXISTS (SELECT 1 FROM JSON_EACH(v_address)
               WHERE key COLLATE "C" <> ALL (ARRAY[
                   'address_line_1','address_line_2','address_line_3','address_line_4',
                   'address_line_5','postcode','cjs_code']::TEXT[]))
       OR EXISTS (SELECT 1 FROM JSON_EACH(v_address)
                  GROUP BY key COLLATE "C" HAVING COUNT(*) > 1) THEN
        RAISE EXCEPTION USING MESSAGE = FORMAT(
            '%s: %s', 'p_insert_third_party_contacts', 'address has invalid members');
    END IF;

    -- Validate full decoded TEXT before any bounded storage assignment.
    FOR v_field IN
        SELECT * FROM (VALUES
            ('name', pi_third_party_contact_json->'name', true, c_text_limit),
            ('relationship', pi_third_party_contact_json->'relationship', true, c_text_limit),
            ('reference', pi_third_party_contact_json->'reference', false, c_text_limit),
            ('address.address_line_1', v_address->'address_line_1', true, c_address_limit),
            ('address.address_line_2', v_address->'address_line_2', false, c_address_limit),
            ('address.address_line_3', v_address->'address_line_3', false, c_address_limit),
            ('address.address_line_4', v_address->'address_line_4', false, c_address_limit),
            ('address.address_line_5', v_address->'address_line_5', false, c_address_limit),
            ('address.postcode', v_address->'postcode', false, c_postcode_limit)
        ) AS fields(path, value, required, max_length)
    LOOP
        IF v_field.value IS NULL THEN
            IF v_field.required THEN
                RAISE EXCEPTION USING MESSAGE = FORMAT(
                    '%s: %s is required', 'p_insert_third_party_contacts', v_field.path);
            END IF;
        ELSE
            IF JSON_TYPEOF(v_field.value) IS DISTINCT FROM 'string' THEN
                RAISE EXCEPTION USING MESSAGE = FORMAT(
                    '%s: %s must be a string', 'p_insert_third_party_contacts', v_field.path);
            END IF;

            v_text := v_field.value #>> '{}';

            IF CHAR_LENGTH(v_text) > v_field.max_length THEN
                RAISE EXCEPTION USING MESSAGE = FORMAT(
                    '%s: %s length is invalid', 'p_insert_third_party_contacts', v_field.path);
            END IF;

            IF v_field.required AND TRANSLATE(v_text, c_whitespace, '') = '' THEN
                RAISE EXCEPTION USING MESSAGE = FORMAT(
                    '%s: %s must be nonblank', 'p_insert_third_party_contacts', v_field.path);
            END IF;
        END IF;
    END LOOP;

    IF JSON_TYPEOF(v_address->'cjs_code') IS DISTINCT FROM 'number' THEN
        RAISE EXCEPTION USING MESSAGE = FORMAT(
            '%s: %s', 'p_insert_third_party_contacts', 'address.cjs_code must be an integer number');
    END IF;

    -- Check the exact numeric value before narrowing to SMALLINT.
    v_cjs_numeric := (v_address->>'cjs_code')::NUMERIC;

    IF v_cjs_numeric <> TRUNC(v_cjs_numeric) OR v_cjs_numeric NOT BETWEEN c_cjs_min AND c_cjs_max THEN
        RAISE EXCEPTION USING MESSAGE = FORMAT(
            '%s: %s', 'p_insert_third_party_contacts',
            'address.cjs_code must be an integer within SMALLINT range');
    END IF;

    -- Resolve all-row cardinality; active selection and provenance belong upstream.
    SELECT country_id INTO STRICT v_country_id
    FROM public.countries
    WHERE cjs_code = v_cjs_numeric::SMALLINT;

    -- Store original text and the Country ID, omitting the generated ID and version.
    INSERT INTO public.third_party_contact (
        name_organisation,
        relationship,
        reference,
        address_line_1,
        address_line_2,
        address_line_3,
        address_line_4,
        address_line_5,
        postcode,
        country
    ) VALUES (
        pi_third_party_contact_json->>'name',
        pi_third_party_contact_json->>'relationship',
        pi_third_party_contact_json->>'reference',
        v_address->>'address_line_1',
        v_address->>'address_line_2',
        v_address->>'address_line_3',
        v_address->>'address_line_4',
        v_address->>'address_line_5',
        v_address->>'postcode',
        v_country_id
    )
    RETURNING third_party_contact_id INTO po_third_party_contact_id;
    GET DIAGNOSTICS v_rows = ROW_COUNT;

    IF v_rows <> 1 OR po_third_party_contact_id IS NULL THEN
        RAISE EXCEPTION USING MESSAGE = FORMAT(
            '%s: %s', 'p_insert_third_party_contacts', 'insert did not create exactly one contact');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;

COMMENT ON PROCEDURE public.p_insert_third_party_contacts(JSON) IS
    'Insert one neutral contact with original values and resolved Country ID; return its generated ID. Caller owns transaction and publication.';
