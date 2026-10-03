/**
 * OPAL Program
 *
 * MODULE      : V1_26__create_respondent_account_parties_table.sql
 *
 * DESCRIPTION : Create the RM RESPONDENT_ACCOUNT_PARTIES table bundle defined
 *               by the promoted Check & Validate Case TDIA.
 *
 * CHANGE HISTORY:
 *
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * 03/10/2026  Chris Larkin  PO-10656      Create the RM RESPONDENT_ACCOUNT_PARTIES table bundle
 */

CREATE TYPE public.t_association_type_enum AS ENUM ('Respondent', 'Applicant', 'Central Authority');

CREATE SEQUENCE public.respondent_account_party_id_seq AS BIGINT START WITH 1 INCREMENT BY 1 NO CYCLE CACHE 1;

CREATE TABLE public.respondent_account_parties (
    respondent_account_party_id BIGINT DEFAULT nextval('public.respondent_account_party_id_seq'::regclass) NOT NULL,
    respondent_account_id       BIGINT                                                                     NOT NULL,
    associated_account_id       BIGINT                                                                     NOT NULL,
    association_type            public.t_association_type_enum                                             NOT NULL,
    CONSTRAINT respondent_account_parties_pk PRIMARY KEY (respondent_account_party_id),
    CONSTRAINT rap_respondent_account_id_fk
        FOREIGN KEY (respondent_account_id)
        REFERENCES public.respondent_accounts (respondent_account_id)
);
ALTER SEQUENCE public.respondent_account_party_id_seq OWNED BY public.respondent_account_parties.respondent_account_party_id;
CREATE INDEX respondent_account_parties_respondent_account_id_idx ON public.respondent_account_parties USING btree (respondent_account_id);

COMMENT ON COLUMN public.respondent_account_parties.respondent_account_party_id IS 'Unique identifier of the account association';
COMMENT ON COLUMN public.respondent_account_parties.respondent_account_id       IS 'Identifier of the Respondent Account';
COMMENT ON COLUMN public.respondent_account_parties.associated_account_id       IS 'Identifier of the associated party, creditor account, or Major Creditor according to association type';
COMMENT ON COLUMN public.respondent_account_parties.association_type            IS 'Respondent, Applicant, or Central Authority association type';
