CREATE PROCEDURE public.p_insert_party_aliases(
    IN pi_party_id public.parties.party_id%TYPE,
    IN pi_aliases_json JSON
)
LANGUAGE plpgsql
AS $$
/**
 * OPAL Program
 *
 * MODULE      : p_insert_party_aliases
 *
 * DESCRIPTION : Insert zero-to-five aliases; preserve names and supplied sequences.
 *
 * PARAMETERS  : IN pi_party_id     - Existing owning Party identifier.
 *             : IN pi_aliases_json - Original zero-to-five alias JSON collection.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket        Nature of Change
 * ----------  -------------  ------------  ----------------------------------------
 * 17/10/2026  Frankie Moran  PO-10648      Create Party alias insertion helper.
 */
DECLARE
    c_max_aliases CONSTANT INTEGER := 5;
    c_min_sequence CONSTANT INTEGER := 1;
    c_max_sequence CONSTANT INTEGER := 5;
    c_person_name_max CONSTANT INTEGER := 40;
    c_organisation_name_max CONSTANT INTEGER := 80;
    c_white_space CONSTANT TEXT := CHR(9)||CHR(10)||CHR(11)||CHR(12)||CHR(13)||CHR(32)
        ||CHR(133)||CHR(160)||CHR(5760)||CHR(8192)||CHR(8193)||CHR(8194)||CHR(8195)
        ||CHR(8196)||CHR(8197)||CHR(8198)||CHR(8199)||CHR(8200)||CHR(8201)||CHR(8202)
        ||CHR(8232)||CHR(8233)||CHR(8239)||CHR(8287)||CHR(12288);
    v_count INTEGER;
    v_inserted BIGINT;
    v_entry RECORD;
    v_field RECORD;
    v_individual BOOLEAN;
    v_text TEXT;
    v_sequence NUMERIC;

BEGIN
    -- Distinguish absence from an explicitly supplied non-array value.
    IF pi_aliases_json IS NULL THEN
        v_count := 0;
    ELSE
        IF JSON_TYPEOF(pi_aliases_json) IS DISTINCT FROM 'array' THEN
            RAISE EXCEPTION USING MESSAGE=FORMAT('%s: %s','p_insert_party_aliases','validate collection: array required');
        END IF;

        v_count := JSON_ARRAY_LENGTH(pi_aliases_json);
    END IF;

    IF v_count > c_max_aliases THEN
        RAISE EXCEPTION USING MESSAGE=FORMAT('%s: %s','p_insert_party_aliases','validate collection: too many aliases');
    END IF;

    -- No inserted row invokes integrity constraints on the empty path.
    IF v_count=0 THEN
        IF pi_party_id IS NULL OR NOT EXISTS(SELECT 1 FROM public.parties WHERE party_id=pi_party_id) THEN
            RAISE EXCEPTION USING MESSAGE=FORMAT('%s: %s','p_insert_party_aliases','validate target: existing Party required');
        END IF;

        RETURN;
    END IF;

    -- Validate all original members and values before any write or ID allocation.
    FOR v_entry IN SELECT value,ordinality FROM JSON_ARRAY_ELEMENTS(pi_aliases_json) WITH ORDINALITY LOOP
        IF JSON_TYPEOF(v_entry.value) IS DISTINCT FROM 'object' THEN
            RAISE EXCEPTION USING MESSAGE=FORMAT('%s: validate alias %s: object required','p_insert_party_aliases',v_entry.ordinality);
        END IF;

        IF EXISTS(SELECT 1 FROM JSON_EACH(v_entry.value)
                WHERE key NOT IN ('sequence_number','surname','forenames','organisation_name'))
              OR EXISTS(SELECT 1 FROM JSON_EACH(v_entry.value) GROUP BY key HAVING COUNT(*)>1) THEN
            RAISE EXCEPTION USING MESSAGE=FORMAT('%s: validate alias %s: invalid members','p_insert_party_aliases',v_entry.ordinality);
        END IF;

        v_individual := v_entry.value->'surname' IS NOT NULL OR v_entry.value->'forenames' IS NOT NULL;

        IF v_individual THEN
            IF JSON_TYPEOF(v_entry.value->'surname') IS DISTINCT FROM 'string'
                  OR JSON_TYPEOF(v_entry.value->'forenames') IS DISTINCT FROM 'string'
                  OR v_entry.value->'organisation_name' IS NOT NULL THEN
                RAISE EXCEPTION USING MESSAGE=FORMAT('%s: validate alias %s: individual shape invalid','p_insert_party_aliases',v_entry.ordinality);
            END IF;
        ELSE
            IF JSON_TYPEOF(v_entry.value->'organisation_name') IS DISTINCT FROM 'string' THEN
                RAISE EXCEPTION USING MESSAGE=FORMAT('%s: validate alias %s: organisation shape invalid','p_insert_party_aliases',v_entry.ordinality);
            END IF;
        END IF;

        FOR v_field IN SELECT * FROM (VALUES
            ('surname',v_individual,c_person_name_max),
            ('forenames',v_individual,c_person_name_max),
            ('organisation_name',NOT v_individual,c_organisation_name_max)
        ) AS fields(label,required,max_length) WHERE required LOOP
            v_text := v_entry.value->>v_field.label;

            IF CHAR_LENGTH(v_text)>v_field.max_length OR TRANSLATE(v_text,c_white_space,'')='' THEN
                RAISE EXCEPTION USING MESSAGE=FORMAT('%s: validate alias %s: %s blank or over length',
                    'p_insert_party_aliases',v_entry.ordinality,v_field.label);
            END IF;
        END LOOP;

        IF JSON_TYPEOF(v_entry.value->'sequence_number') IS DISTINCT FROM 'number' THEN
            RAISE EXCEPTION USING MESSAGE=FORMAT('%s: validate alias %s: sequence_number must be numeric',
                'p_insert_party_aliases',v_entry.ordinality);
        END IF;

        v_sequence := (v_entry.value->>'sequence_number')::NUMERIC;

        IF v_sequence<>TRUNC(v_sequence) OR v_sequence NOT BETWEEN c_min_sequence AND c_max_sequence THEN
            RAISE EXCEPTION USING MESSAGE=FORMAT('%s: validate alias %s: sequence_number must be integral in range',
                'p_insert_party_aliases',v_entry.ordinality);
        END IF;
    END LOOP;

    -- Insert the validated batch using the owned default and supplied values.
    INSERT INTO public.aliases (
        party_id,
        surname,
        forenames,
        organisation_name,
        sequence_number
    ) SELECT
        pi_party_id,
        value->>'surname',
        value->>'forenames',
        value->>'organisation_name',
        (value->>'sequence_number')::NUMERIC::INTEGER
    FROM JSON_ARRAY_ELEMENTS(pi_aliases_json);
    GET DIAGNOSTICS v_inserted = ROW_COUNT;

    IF v_inserted<>v_count THEN
        RAISE EXCEPTION USING MESSAGE=FORMAT('%s: %s','p_insert_party_aliases','insert batch: incomplete insertion');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;
COMMENT ON PROCEDURE public.p_insert_party_aliases(BIGINT,JSON)
IS 'Insert zero-to-five aliases for one existing Party with exact names and supplied sequences; caller owns transaction and publication.';
