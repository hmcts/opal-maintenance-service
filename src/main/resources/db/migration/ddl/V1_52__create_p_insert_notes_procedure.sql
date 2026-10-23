CREATE PROCEDURE public.p_insert_notes(
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
 * DESCRIPTION : Insert one standard publication Note with exact validated input
 *               and sanitized propagation; caller owns transaction and lifecycle.
 *
 * PARAMETERS  : IN pi_respondent_account_id - Existing Respondent Account identifier.
 *             : IN pi_posted_by             - Original saved submitter identifier.
 *             : IN pi_posted_by_name        - Original saved submitter display name.
 *             : IN pi_note_json             - One JSON string member named note_text.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket        Nature of Change
 * ----------  -------------  ------------  ----------------------------------------
 * 13/10/2026  Frankie Moran  PO-10645      Create publication Notes procedure.
 * 22/10/2026  Frankie Moran  PO-10655  Reissue unchanged behavior under the approved F3 lineage.
 */
DECLARE
    c_whitespace CONSTANT TEXT :=
        CHR(9)||CHR(10)||CHR(11)||CHR(12)||CHR(13)||CHR(32)||CHR(133)||CHR(160)||CHR(5760)
        ||CHR(8192)||CHR(8193)||CHR(8194)||CHR(8195)||CHR(8196)||CHR(8197)||CHR(8198)
        ||CHR(8199)||CHR(8200)||CHR(8201)||CHR(8202)||CHR(8232)||CHR(8233)||CHR(8239)
        ||CHR(8287)||CHR(12288);
    c_posted_by_limit CONSTANT INTEGER := 20;
    c_posted_by_name_limit CONSTANT INTEGER := 100;
    v_member_count INTEGER;
    v_note_value JSON;
    v_note_text TEXT;
    v_operation TEXT := 'input processing';
    v_deliberate BOOLEAN := false;
    v_state TEXT;
    v_schema TEXT;
    v_table TEXT;
    v_column TEXT;
    v_constraint TEXT;

BEGIN
    IF pi_respondent_account_id IS NULL THEN
        v_deliberate := true;
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = FORMAT('%s: %s','p_insert_notes','respondent_account_id is required');
    END IF;

    IF pi_note_json IS NULL OR JSON_TYPEOF(pi_note_json) IS DISTINCT FROM 'object' THEN
        v_deliberate := true;
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = FORMAT('%s: %s','p_insert_notes','note_json must contain only string note_text');
    END IF;

    -- Enumerate JSON before extraction so duplicate decoded keys cannot disappear.
    SELECT COUNT(*) INTO v_member_count FROM JSON_EACH(pi_note_json);

    IF v_member_count <> 1 THEN
        v_deliberate := true;
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = FORMAT('%s: %s','p_insert_notes','note_json must contain only string note_text');
    END IF;

    SELECT value INTO v_note_value FROM JSON_EACH(pi_note_json)
    WHERE key COLLATE "C" = 'note_text' COLLATE "C";

    IF v_note_value IS NULL OR JSON_TYPEOF(v_note_value) IS DISTINCT FROM 'string' THEN
        v_deliberate := true;
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = FORMAT('%s: %s','p_insert_notes','note_json must contain only string note_text');
    END IF;

    v_note_text := v_note_value #>> '{}';

    IF TRANSLATE(v_note_text,c_whitespace,'') = '' THEN
        v_deliberate := true;
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = FORMAT('%s: %s','p_insert_notes','note_text must be nonblank');
    END IF;

    IF pi_posted_by IS NULL THEN
        v_deliberate := true;
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = FORMAT('%s: %s','p_insert_notes','posted_by is required');
    END IF;

    IF CHAR_LENGTH(pi_posted_by) > c_posted_by_limit THEN
        v_deliberate := true;
        RAISE EXCEPTION USING ERRCODE = '22001',
            MESSAGE = FORMAT('%s: %s','p_insert_notes','posted_by exceeds 20 characters');
    END IF;

    IF TRANSLATE(pi_posted_by,c_whitespace,'') = '' THEN
        v_deliberate := true;
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = FORMAT('%s: %s','p_insert_notes','posted_by must be nonblank');
    END IF;

    IF pi_posted_by_name IS NULL THEN
        v_deliberate := true;
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = FORMAT('%s: %s','p_insert_notes','posted_by_name is required');
    END IF;

    IF CHAR_LENGTH(pi_posted_by_name) > c_posted_by_name_limit THEN
        v_deliberate := true;
        RAISE EXCEPTION USING ERRCODE = '22001',
            MESSAGE = FORMAT('%s: %s','p_insert_notes','posted_by_name exceeds 100 characters');
    END IF;

    IF TRANSLATE(pi_posted_by_name,c_whitespace,'') = '' THEN
        v_deliberate := true;
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = FORMAT('%s: %s','p_insert_notes','posted_by_name must be nonblank');
    END IF;

    v_operation := 'target lookup';

    IF NOT EXISTS(SELECT 1 FROM public.respondent_accounts
                  WHERE respondent_account_id = pi_respondent_account_id) THEN
        v_deliberate := true;
        RAISE EXCEPTION USING
            MESSAGE = FORMAT('%s: %s','p_insert_notes','respondent_account target does not exist');
    END IF;

    v_operation := 'insert';
    INSERT INTO public.notes(
        note_type,associated_record_type,associated_record_id,note_text,
        posted_date,posted_by,posted_by_name
    ) VALUES (
        'NT','respondent_accounts',pi_respondent_account_id::TEXT,v_note_text,
        TRANSACTION_TIMESTAMP() AT TIME ZONE 'UTC',pi_posted_by,pi_posted_by_name
    );

EXCEPTION WHEN query_canceled OR assert_failure OR OTHERS THEN
    IF v_deliberate AND SQLSTATE IN ('22023','22001','P0001') THEN
        RAISE;
    END IF;

    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_schema = SCHEMA_NAME,
        v_table = TABLE_NAME, v_column = COLUMN_NAME, v_constraint = CONSTRAINT_NAME;

    -- Keep only an exact Notes catalogue tuple; arbitrary RAISE fields are unsafe.
    IF v_schema COLLATE "C" IS DISTINCT FROM 'public' COLLATE "C"
       OR v_table COLLATE "C" IS DISTINCT FROM 'notes' COLLATE "C" THEN
        v_schema := '';
        v_table := '';
        v_column := '';
        v_constraint := '';
    ELSE
        IF v_column IS NULL OR v_column COLLATE "C" NOT IN (
            'note_id','note_type','associated_record_type','associated_record_id',
            'note_text','posted_date','posted_by','posted_by_name'
        ) THEN
            v_column := '';
        END IF;

        IF v_constraint COLLATE "C" IS DISTINCT FROM 'notes_pk' COLLATE "C" THEN
            v_constraint := '';
        END IF;
    END IF;

    RAISE EXCEPTION USING ERRCODE = v_state,
        MESSAGE = FORMAT('p_insert_notes: %s failed',v_operation),
        SCHEMA = v_schema, TABLE = v_table, COLUMN = v_column, CONSTRAINT = v_constraint;
END;
$$;

COMMENT ON PROCEDURE public.p_insert_notes(BIGINT,VARCHAR,VARCHAR,JSON)
IS 'Insert one standard publication Note for an existing Respondent Account; caller owns transaction and lifecycle.';
