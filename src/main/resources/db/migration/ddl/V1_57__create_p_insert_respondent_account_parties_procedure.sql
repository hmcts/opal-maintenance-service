CREATE PROCEDURE public.p_insert_respondent_account_parties (
    IN pi_respondent_account_id public.respondent_account_parties.respondent_account_id%TYPE,
    IN pi_associated_account_id public.respondent_account_parties.associated_account_id%TYPE,
    IN pi_association_type public.respondent_account_parties.association_type%TYPE
)
LANGUAGE plpgsql
AS $$
/**
 * OPAL Program
 *
 * MODULE      : p_insert_respondent_account_parties
 *
 * DESCRIPTION : Validate one selected-domain target and insert one association.
 *               Caller owns transaction, Applicant provenance and complete cardinality.
 *
 * PARAMETERS  : IN pi_respondent_account_id - Existing Respondent Account identifier.
 *             : IN pi_associated_account_id - Party, Creditor Account or Major Creditor ID.
 *             : IN pi_association_type - Respondent, Applicant or Central Authority.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket        Nature of Change
 * ----------  -------------  ------------  ----------------------------------------
 * 16/10/2026  Frankie Moran  PO-10649      Create single-association insertion helper.
 * 22/10/2026  Frankie Moran  PO-10655  Reissue unchanged behavior under the approved F3 lineage.
 */
BEGIN
    -- Preserve native NOT NULL failures when either polymorphic input is NULL.
    IF pi_associated_account_id IS NOT NULL AND pi_association_type IS NOT NULL THEN
        CASE pi_association_type
            WHEN 'Respondent' THEN
                IF NOT EXISTS (
                    SELECT 1
                    FROM public.parties p
                    WHERE p.party_id=pi_associated_account_id
                      AND p.account_type='Respondent'
                ) THEN
                    RAISE EXCEPTION USING MESSAGE=FORMAT(
                        'p_insert_respondent_account_parties: validate %s target failed','Respondent');
                END IF;
            WHEN 'Applicant' THEN
                IF NOT EXISTS (
                    SELECT 1
                    FROM public.creditor_accounts c
                    JOIN public.parties p ON p.party_id=c.minor_creditor_party_id
                    WHERE c.creditor_account_id=pi_associated_account_id
                      AND c.creditor_account_type='MN'
                      AND c.major_creditor_id IS NULL
                      AND p.account_type='Minor Creditor'
                ) THEN
                    RAISE EXCEPTION USING MESSAGE=FORMAT(
                        'p_insert_respondent_account_parties: validate %s target failed','Applicant');
                END IF;
            WHEN 'Central Authority' THEN
                IF NOT EXISTS (
                    SELECT 1
                    FROM public.major_creditors m
                    WHERE m.major_creditor_id=pi_associated_account_id
                      AND m.central_authority IS TRUE
                ) THEN
                    RAISE EXCEPTION USING MESSAGE=FORMAT(
                        'p_insert_respondent_account_parties: validate %s target failed','Central Authority');
                END IF;
            ELSE
                RAISE EXCEPTION USING MESSAGE=FORMAT(
                    '%s: validate association type failed','p_insert_respondent_account_parties');
        END CASE;
    END IF;

    -- Insert exactly the accepted inputs; the existing default owns identity allocation.
    INSERT INTO public.respondent_account_parties (
        respondent_account_id,
        associated_account_id,
        association_type
    ) VALUES (
        pi_respondent_account_id,
        pi_associated_account_id,
        pi_association_type
    );

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;
COMMENT ON PROCEDURE public.p_insert_respondent_account_parties(BIGINT,BIGINT,public.t_association_type_enum)
IS 'Insert one validated Respondent Account association using its existing identity default. Caller owns transaction, Applicant provenance and complete association cardinality.';
