CREATE OR REPLACE PROCEDURE public.p_insert_notes(
    IN pi_respondent_account_id public.respondent_accounts.respondent_account_id%TYPE,
    IN pi_posted_by             public.notes.posted_by%TYPE,
    IN pi_posted_by_name        public.notes.posted_by_name%TYPE,
    IN pi_note_json             JSON
)
LANGUAGE plpgsql
AS $$
/**
 * OPAL Program
 *
 * MODULE      : p_insert_notes
 *
 * DESCRIPTION : Insert one standard publication Note from backend-validated input
 *               preserving original author values; caller owns the transaction.
 *
 * PARAMETERS  : IN pi_respondent_account_id - Existing Respondent Account identifier.
 *             : IN pi_posted_by             - Original submitter identifier; nullable, at most 20 characters.
 *             : IN pi_posted_by_name        - Original submitter name; nullable, at most 100 characters.
 *             : IN pi_note_json             - Validated Note object with string note_text.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket        Nature of Change
 * ----------  -------------  ------------  ----------------------------------------
 * 13/10/2026  Frankie Moran  PO-10645      Create publication Notes procedure.
 * 23/10/2026  Frankie Moran  PO-10645      Reject original author overflow before Note allocation.
 */
DECLARE
    c_posted_by_limit      CONSTANT INTEGER := 20;
    c_posted_by_name_limit CONSTANT INTEGER := 100;
BEGIN
    -- Protect the polymorphic association, which has no respondent-account foreign key.
    IF NOT EXISTS(SELECT 1 FROM public.respondent_accounts
                  WHERE respondent_account_id = pi_respondent_account_id) THEN
        RAISE EXCEPTION USING
            MESSAGE = FORMAT('%s: %s','p_insert_notes','respondent_account target does not exist');
    END IF;

    -- Check the original arguments before table assignment can discard excess spaces.
    -- NULL, empty and in-range whitespace values retain the existing contract.
    IF CHAR_LENGTH(pi_posted_by) > c_posted_by_limit THEN
        RAISE EXCEPTION USING
            ERRCODE = '22001',
            MESSAGE = FORMAT('%s: %s','p_insert_notes','posted_by exceeds 20 characters');
    END IF;

    IF CHAR_LENGTH(pi_posted_by_name) > c_posted_by_name_limit THEN
        RAISE EXCEPTION USING
            ERRCODE = '22001',
            MESSAGE = FORMAT('%s: %s','p_insert_notes','posted_by_name exceeds 100 characters');
    END IF;

    -- Persist the standard Note and original author values in the caller's transaction.
    INSERT INTO public.notes (
        note_type,
        associated_record_type,
        associated_record_id,
        note_text,
        posted_date,
        posted_by,
        posted_by_name
    ) VALUES (
        'NT',
        'respondent_accounts',
        pi_respondent_account_id::TEXT,
        pi_note_json->>'note_text',
        TRANSACTION_TIMESTAMP() AT TIME ZONE 'UTC',
        pi_posted_by,
        pi_posted_by_name
    );

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;

COMMENT ON PROCEDURE public.p_insert_notes(BIGINT,VARCHAR,VARCHAR,JSON)
IS 'Insert one standard publication Note for an existing Respondent Account; caller owns transaction and lifecycle.';
