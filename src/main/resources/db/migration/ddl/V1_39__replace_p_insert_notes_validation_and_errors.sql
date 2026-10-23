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
 *               with unchanged error propagation; caller owns the transaction.
 *
 * PARAMETERS  : IN pi_respondent_account_id - Existing Respondent Account identifier.
 *             : IN pi_posted_by             - Validated original saved submitter identifier.
 *             : IN pi_posted_by_name        - Validated original saved submitter display name.
 *             : IN pi_note_json             - Validated Note object with string note_text.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket        Nature of Change
 * ----------  -------------  ------------  ----------------------------------------
 * 13/10/2026  Frankie Moran  PO-10645      Create publication Notes procedure.
 * 15/10/2026  Frankie Moran  PO-10645      Move request validation to backend and rethrow unchanged.
 */
BEGIN
    -- Protect the polymorphic association, which has no respondent-account foreign key.
    IF NOT EXISTS(SELECT 1 FROM public.respondent_accounts
                  WHERE respondent_account_id = pi_respondent_account_id) THEN
        RAISE EXCEPTION USING
            MESSAGE = FORMAT('%s: %s','p_insert_notes','respondent_account target does not exist');
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
