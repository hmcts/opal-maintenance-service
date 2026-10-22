CREATE PROCEDURE public.p_insert_parties(
    IN pi_party_json JSON,
    IN pi_account_type public.parties.account_type%TYPE,
    OUT po_party_id public.parties.party_id%TYPE
)
LANGUAGE plpgsql
AS $$
/**
 * OPAL Program
 *
 * MODULE      : p_insert_parties
 *
 * DESCRIPTION : Insert one Party with exact mapped values and resolved Country;
 *               return its generated ID. Caller owns transaction and publication.
 *
 * PARAMETERS  : IN pi_party_json   - One Party Details object with original JSON types.
 *             : IN pi_account_type - Physical Respondent or Minor Creditor account type.
 *             : OUT po_party_id    - Generated identifier of the single inserted Party.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket        Nature of Change
 * ----------  -------------  ------------  ----------------------------------------
 * 16/10/2026  Frankie Moran  PO-10647      Create one-Party insertion helper.
 * 22/10/2026  Frankie Moran  PO-10655  Reissue unchanged behavior under the approved F3 lineage.
 */
DECLARE
    v_organisation BOOLEAN;
    v_individual JSON := '{}';
    v_organisation_details JSON := '{}';
    v_address JSON;
    v_contact JSON := '{}';
    v_field RECORD;
    v_text TEXT;
    v_cjs_numeric NUMERIC;
    v_country_id public.countries.country_id%TYPE;
    v_birth_date public.parties.birth_date%TYPE;
    v_restrict BOOLEAN := false;

BEGIN
    -- Protect the original wire shape before extracting or coercing any values.
    IF JSON_TYPEOF(pi_party_json) IS DISTINCT FROM 'object' OR pi_account_type IS NULL THEN
        RAISE EXCEPTION USING MESSAGE=FORMAT('%s: %s','p_insert_parties','Party object and account type are required');
    END IF;

    IF JSON_TYPEOF(pi_party_json->'organisation') IS DISTINCT FROM 'boolean' THEN
        RAISE EXCEPTION USING MESSAGE=FORMAT('%s: %s','p_insert_parties','organisation must be Boolean');
    END IF;

    v_organisation := (pi_party_json->>'organisation')::BOOLEAN;

    IF v_organisation THEN
        IF JSON_TYPEOF(pi_party_json->'organisation_details') IS DISTINCT FROM 'object'
           OR pi_party_json->'individual_details' IS NOT NULL THEN
            RAISE EXCEPTION USING MESSAGE=FORMAT('%s: %s','p_insert_parties','organisation branch is invalid');
        END IF;

        v_organisation_details := pi_party_json->'organisation_details';
    ELSE
        IF JSON_TYPEOF(pi_party_json->'individual_details') IS DISTINCT FROM 'object'
           OR pi_party_json->'organisation_details' IS NOT NULL THEN
            RAISE EXCEPTION USING MESSAGE=FORMAT('%s: %s','p_insert_parties','individual branch is invalid');
        END IF;

        v_individual := pi_party_json->'individual_details';
    END IF;

    IF JSON_TYPEOF(pi_party_json->'address') IS DISTINCT FROM 'object' THEN
        RAISE EXCEPTION USING MESSAGE=FORMAT('%s: %s','p_insert_parties','address object is required');
    END IF;

    v_address := pi_party_json->'address';

    IF pi_party_json->'contact_details' IS NOT NULL THEN
        IF JSON_TYPEOF(pi_party_json->'contact_details') IS DISTINCT FROM 'object' THEN
            RAISE EXCEPTION USING MESSAGE=FORMAT('%s: %s','p_insert_parties','contact_details must be an object');
        END IF;

        v_contact := pi_party_json->'contact_details';
    END IF;

    -- Validate each owned string before any narrowing assignment or INSERT.
    FOR v_field IN SELECT * FROM (VALUES
        ('organisation_details.organisation_name',v_organisation_details->'organisation_name',1,80,v_organisation),
        ('organisation_details.foreign_authority_reference',v_organisation_details->'foreign_authority_reference',0,40,false),
        ('individual_details.surname',v_individual->'surname',1,50,NOT v_organisation),
        ('individual_details.forenames',v_individual->'forenames',1,50,false),
        ('individual_details.title',v_individual->'title',0,20,false),
        ('individual_details.national_insurance_number',v_individual->'national_insurance_number',0,9,false),
        ('address.address_line_1',v_address->'address_line_1',1,35,true),
        ('address.address_line_2',v_address->'address_line_2',0,35,false),
        ('address.address_line_3',v_address->'address_line_3',0,35,false),
        ('address.address_line_4',v_address->'address_line_4',0,35,false),
        ('address.address_line_5',v_address->'address_line_5',0,35,false),
        ('address.postcode',v_address->'postcode',0,10,false),
        ('contact_details.main_telephone_number',v_contact->'main_telephone_number',0,35,false),
        ('contact_details.other_telephone_number',v_contact->'other_telephone_number',0,35,false),
        ('contact_details.primary_email_address',v_contact->'primary_email_address',0,76,false),
        ('contact_details.secondary_email_address',v_contact->'secondary_email_address',0,76,false),
        ('individual_details.restriction_reason',v_individual->'restriction_reason',0,250,false)
    ) AS f(path,value,min_length,max_length,required) LOOP
        IF v_field.value IS NULL THEN
            IF v_field.required THEN
                RAISE EXCEPTION USING MESSAGE=FORMAT('%s: %s is required','p_insert_parties',v_field.path);
            END IF;
        ELSE
            IF JSON_TYPEOF(v_field.value) IS DISTINCT FROM 'string' THEN
                RAISE EXCEPTION USING MESSAGE=FORMAT('%s: %s must be a string','p_insert_parties',v_field.path);
            END IF;

            v_text := v_field.value #>> '{}';

            IF CHAR_LENGTH(v_text)<v_field.min_length OR CHAR_LENGTH(v_text)>v_field.max_length THEN
                RAISE EXCEPTION USING MESSAGE=FORMAT('%s: %s length is invalid','p_insert_parties',v_field.path);
            END IF;
        END IF;
    END LOOP;

    IF v_organisation_details->>'foreign_authority_reference' ~ '[^[:alnum:]]' THEN
        RAISE EXCEPTION USING MESSAGE=FORMAT('%s: %s','p_insert_parties','foreign_authority_reference must be alphanumeric');
    END IF;

    -- Restriction defaults and nonblank checks never alter accepted reason text.
    IF v_individual->'restrict_personal_information' IS NOT NULL THEN
        IF JSON_TYPEOF(v_individual->'restrict_personal_information') IS DISTINCT FROM 'boolean' THEN
            RAISE EXCEPTION USING MESSAGE=FORMAT('%s: %s','p_insert_parties','restrict_personal_information must be Boolean');
        END IF;

        v_restrict := (v_individual->>'restrict_personal_information')::BOOLEAN;
    END IF;

    IF v_restrict AND (v_individual->>'restriction_reason' IS NULL
        OR v_individual->>'restriction_reason' !~ '[^[:space:]]') THEN
        RAISE EXCEPTION USING MESSAGE=FORMAT('%s: %s','p_insert_parties','restriction_reason must be nonblank when restricted');
    END IF;

    -- Enforce the ISO wire representation, then retain native calendar conversion.
    IF v_individual->'date_of_birth' IS NOT NULL THEN
        IF JSON_TYPEOF(v_individual->'date_of_birth') IS DISTINCT FROM 'string'
           OR v_individual->>'date_of_birth' !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN
            RAISE EXCEPTION USING MESSAGE=FORMAT('%s: %s','p_insert_parties','date_of_birth must be an ISO date string');
        END IF;

        v_birth_date := (v_individual->>'date_of_birth')::DATE;
    END IF;

    -- A supplied numeric CJS code must resolve uniquely across all Country rows.
    IF JSON_TYPEOF(v_address->'cjs_code') IS DISTINCT FROM 'number' THEN
        RAISE EXCEPTION USING MESSAGE=FORMAT('%s: %s','p_insert_parties','cjs_code must be an integer number');
    END IF;

    v_cjs_numeric := (v_address->>'cjs_code')::NUMERIC;

    IF v_cjs_numeric<>TRUNC(v_cjs_numeric) OR v_cjs_numeric NOT BETWEEN -32768 AND 32767 THEN
        RAISE EXCEPTION USING MESSAGE=FORMAT('%s: %s','p_insert_parties','cjs_code must be an integer within SMALLINT range');
    END IF;

    SELECT country_id INTO STRICT v_country_id
      FROM public.countries
     WHERE cjs_code=v_cjs_numeric::SMALLINT;

    -- Insert one Party with exact original mapped strings and the existing ID default.
    INSERT INTO public.parties (
        organisation,
        organisation_name,
        foreign_authority_reference,
        surname,
        forenames,
        title,
        birth_date,
        national_insurance_number,
        address_line_1,
        address_line_2,
        address_line_3,
        address_line_4,
        address_line_5,
        postcode,
        telephone_home,
        telephone_business,
        telephone_mobile,
        email_1,
        email_2,
        restrict_personal_information,
        restriction_reason,
        country_id,
        account_type,
        last_changed_date
    ) VALUES (
        v_organisation,
        v_organisation_details->>'organisation_name',
        v_organisation_details->>'foreign_authority_reference',
        v_individual->>'surname',
        v_individual->>'forenames',
        v_individual->>'title',
        v_birth_date,
        v_individual->>'national_insurance_number',
        v_address->>'address_line_1',
        v_address->>'address_line_2',
        v_address->>'address_line_3',
        v_address->>'address_line_4',
        v_address->>'address_line_5',
        v_address->>'postcode',
        v_contact->>'main_telephone_number',
        NULL,
        v_contact->>'other_telephone_number',
        v_contact->>'primary_email_address',
        v_contact->>'secondary_email_address',
        v_restrict,
        v_individual->>'restriction_reason',
        v_country_id,
        pi_account_type,
        NULL
    ) RETURNING party_id INTO po_party_id;

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;
COMMENT ON PROCEDURE public.p_insert_parties(JSON,public.t_party_account_type_enum)
IS 'Insert one Party with exact mapped values and resolved Country; return its generated ID. Caller owns transaction and publication.';
