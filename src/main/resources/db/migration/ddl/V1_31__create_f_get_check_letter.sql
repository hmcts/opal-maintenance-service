CREATE FUNCTION public.f_get_check_letter(IN pi_account_number VARCHAR)
RETURNS VARCHAR
LANGUAGE plpgsql
AS $$
/**
 * OPAL Program
 *
 * MODULE      : f_get_check_letter
 *
 * DESCRIPTION : Calculate the account-number check letter from eight digits;
 *               no database record access. Adapted from the Fines routine.
 *
 * PARAMETERS  : IN pi_account_number - First eight numeric characters.
 *
 * CHANGE HISTORY:
 *
 * Date        Author        Ticket    Nature of Change
 * ----------  ------------  --------  -----------------------------------------
 * 09/10/2026  Chris Larkin  PO-10642  Create the RM checksum helper
 */
DECLARE
    v_sum INTEGER;
    v_letter_index INTEGER;

BEGIN
    -- Apply the positional weights to the eight-digit numeric part.
    v_sum := SUBSTR(pi_account_number,1,1)::INTEGER * 5
           + SUBSTR(pi_account_number,2,1)::INTEGER * 1
           + SUBSTR(pi_account_number,3,1)::INTEGER * 4
           + SUBSTR(pi_account_number,4,1)::INTEGER * 2
           + SUBSTR(pi_account_number,5,1)::INTEGER * 7
           + SUBSTR(pi_account_number,6,1)::INTEGER * 5
           + SUBSTR(pi_account_number,7,1)::INTEGER * 1
           + SUBSTR(pi_account_number,8,1)::INTEGER * 4;

    -- Calculate the complement of the weighted total's remainder modulo 23.
    v_letter_index := 23 - (v_sum - (TRUNC(v_sum / 23) * 23));

    -- Map an exact multiple of 23 to the first letter's zero-based index.
    v_letter_index := CASE v_letter_index WHEN 23 THEN 0 ELSE v_letter_index END;

    -- Convert the zero-based index to its uppercase check letter.
    RETURN CHR(v_letter_index + 65);
END;
$$;
