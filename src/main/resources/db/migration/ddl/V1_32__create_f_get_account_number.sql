CREATE FUNCTION public.f_get_account_number(
    IN pi_business_unit_id public.account_number_index.business_unit_id%TYPE,
    IN pi_associated_record_type public.account_number_index.associated_record_type%TYPE
)
RETURNS public.account_number_index.account_number%TYPE
LANGUAGE plpgsql
AS $$
/**
 * OPAL Program
 *
 * MODULE      : f_get_account_number
 *
 * DESCRIPTION : Reserve a BU-scoped RM account number and return it, with
 *               checksum and bounded collision recovery; caller owns transaction.
 *
 * PARAMETERS  : IN pi_business_unit_id       - Business Unit receiving allocation.
 *             : IN pi_associated_record_type - Shared RM record type; NULL allowed.
 *
 * CHANGE HISTORY:
 *
 * Date        Author        Ticket    Nature of Change
 * ----------  ------------  --------  -----------------------------------------
 * 09/10/2026  Chris Larkin  PO-10642  Create the RM account-number allocator
 */
DECLARE
    c_seq_min_value CONSTANT VARCHAR(6) := '000001';
    c_seq_max_value CONSTANT VARCHAR(6) := '999999';

    v_yy             VARCHAR(2);
    v_max            public.account_number_index.account_number%TYPE;
    v_min_sequence   INTEGER;
    v_sequence       INTEGER;
    v_body           VARCHAR(8);
    v_number         public.account_number_index.account_number%TYPE;
    v_error_message  TEXT;
    v_constraint     TEXT;

BEGIN
    -- Loop until an account number is inserted into account_number_index,
    -- recalculating after collisions and allowing at most five attempts.
    FOR v_attempt IN 1..5 LOOP
        v_yy := TO_CHAR(NOW(),'YY');

        -- Find this BU's highest allocation in the current or a future year.
        SELECT MAX(a.account_number) INTO v_max
        FROM public.account_number_index a
        WHERE a.business_unit_id=pi_business_unit_id
          AND a.account_number > v_yy||c_seq_min_value;

        IF v_max IS NULL THEN
            v_sequence := c_seq_min_value::INTEGER;
        ELSE
            v_yy := LEFT(v_max,2);
            v_sequence := SUBSTRING(v_max FROM 3 FOR 6)::INTEGER;

            -- Advance the sequence until its maximum; only then reuse gaps.
            IF v_sequence < c_seq_max_value::INTEGER THEN
                v_sequence := v_sequence+1;
            ELSE
                -- Check the start of the selected year before searching interior gaps.
                SELECT MIN(SUBSTRING(a.account_number FROM 3 FOR 6)::INTEGER)
                INTO v_min_sequence
                FROM public.account_number_index a
                WHERE a.business_unit_id=pi_business_unit_id
                  AND LEFT(a.account_number,2)=v_yy;

                IF v_min_sequence > c_seq_min_value::INTEGER THEN
                    v_sequence := c_seq_min_value::INTEGER;
                ELSE
                    -- Choose the lowest unused sequence between existing allocations.
                    SELECT MIN(s.n+1) INTO v_sequence
                    FROM (
                        SELECT SUBSTRING(a.account_number FROM 3 FOR 6)::INTEGER AS n,
                               LEAD(SUBSTRING(a.account_number FROM 3 FOR 6)::INTEGER)
                                   OVER (ORDER BY a.account_number) AS following
                        FROM public.account_number_index a
                        WHERE a.business_unit_id=pi_business_unit_id
                          AND LEFT(a.account_number,2)=v_yy
                    ) s
                    WHERE s.following > s.n+1;

                    -- A full range rolls into the next year; year 99 is terminal.
                    IF v_sequence IS NULL THEN
                        IF v_yy='99' THEN
                            RAISE EXCEPTION USING
                                MESSAGE='Account number range exhausted for year 99';
                        END IF;

                        v_yy := LPAD((v_yy::INTEGER+1)::TEXT,2,'0');
                        v_sequence := c_seq_min_value::INTEGER;
                    END IF;

                END IF;
            END IF;
        END IF;

        -- Build the eight-digit body and append its calculated check letter.
        v_body := v_yy||LPAD(v_sequence::TEXT,6,'0');
        v_number := v_body||public.f_get_check_letter(v_body);

        -- Reserve the candidate; the unique constraint arbitrates competing callers.
        BEGIN
            INSERT INTO public.account_number_index
                (business_unit_id,account_number,associated_record_type)
            VALUES (pi_business_unit_id,v_number,pi_associated_record_type)
            RETURNING account_number INTO v_number;
            RETURN v_number;

        EXCEPTION WHEN unique_violation THEN
            -- Retry collisions only; report the original cause on the final attempt.
            GET STACKED DIAGNOSTICS v_constraint=CONSTRAINT_NAME;

            v_error_message := FORMAT(
                'f_get_account_number: allocation failed after five attempts; Account number = %s, BU = %s; %s: %s',
                v_number,pi_business_unit_id,SQLSTATE,SQLERRM);

            IF v_attempt=5 THEN
                RAISE EXCEPTION USING MESSAGE=v_error_message,
                    CONSTRAINT=v_constraint;
            END IF;
        END;
    END LOOP;
END;
$$;
