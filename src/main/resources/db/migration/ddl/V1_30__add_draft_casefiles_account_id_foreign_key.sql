/**
 * OPAL Program
 *
 * MODULE      : V1_30__add_draft_casefiles_account_id_foreign_key.sql
 *
 * DESCRIPTION : Add the nullable Draft Casefile publication link to
 *               Respondent Accounts, retaining the existing unique index.
 *
 * CHANGE HISTORY:
 *
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * 03/10/2026  Chris Larkin  PO-10659      Enforce published Respondent Account link.
 */

ALTER TABLE public.draft_casefiles
    ADD CONSTRAINT dcf_account_id_fk
    FOREIGN KEY (account_id)
    REFERENCES public.respondent_accounts (respondent_account_id);
