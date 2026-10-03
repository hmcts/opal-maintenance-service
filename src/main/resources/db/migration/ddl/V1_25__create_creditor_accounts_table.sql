/**
 * OPAL Program
 *
 * MODULE      : V1_25__create_creditor_accounts_table.sql
 *
 * DESCRIPTION : Create the RM CREDITOR_ACCOUNTS table bundle defined by the
 *               promoted Check & Validate Case TDIA.
 *
 * CHANGE HISTORY:
 *
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * 03/10/2026  Chris Larkin  PO-10639      Create the RM CREDITOR_ACCOUNTS table bundle
 */

CREATE TYPE public.t_creditor_account_type_enum AS ENUM ('MN', 'MJ', 'CF');

CREATE SEQUENCE public.creditor_account_id_seq AS BIGINT START WITH 1 INCREMENT BY 1 NO CYCLE CACHE 1;

CREATE TABLE public.creditor_accounts (
    creditor_account_id     BIGINT DEFAULT nextval('public.creditor_account_id_seq'::regclass) NOT NULL,
    business_unit_id        SMALLINT                                                           NOT NULL,
    account_number          VARCHAR(20)                                                        NOT NULL,
    creditor_account_type   public.t_creditor_account_type_enum                                NOT NULL,
    major_creditor_id       BIGINT,
    minor_creditor_party_id BIGINT,
    from_suspense           BOOLEAN                                                            NOT NULL,
    hold_payout             BOOLEAN                                                            NOT NULL,
    pay_by_bacs             BOOLEAN                                                            NOT NULL,
    bank_sort_code          VARCHAR(6),
    bank_account_number     VARCHAR(10),
    bank_account_name       VARCHAR(18),
    bank_account_reference  VARCHAR(18),
    third_party_contact_id  BIGINT,
    last_changed_date       TIMESTAMP,
    non_uk_bank_detail      JSON,
    version_number          BIGINT,
    CONSTRAINT creditor_accounts_pk PRIMARY KEY (creditor_account_id),
    CONSTRAINT ca_business_unit_id_fk
        FOREIGN KEY (business_unit_id)
        REFERENCES public.business_units (business_unit_id),
    CONSTRAINT ca_major_creditor_id_fk
        FOREIGN KEY (major_creditor_id)
        REFERENCES public.major_creditors (major_creditor_id),
    CONSTRAINT ca_minor_creditor_party_id_fk
        FOREIGN KEY (minor_creditor_party_id)
        REFERENCES public.parties (party_id),
    CONSTRAINT ca_third_party_contact_id_fk
        FOREIGN KEY (third_party_contact_id)
        REFERENCES public.third_party_contact (third_party_contact_id),
    CONSTRAINT ca_business_unit_id_account_number_uk UNIQUE (business_unit_id, account_number)
);
ALTER SEQUENCE public.creditor_account_id_seq OWNED BY public.creditor_accounts.creditor_account_id;
CREATE INDEX creditor_accounts_major_creditor_id_idx ON public.creditor_accounts USING btree (major_creditor_id);
CREATE INDEX creditor_accounts_minor_creditor_party_id_idx ON public.creditor_accounts USING btree (minor_creditor_party_id);
CREATE INDEX creditor_accounts_third_party_contact_id_idx ON public.creditor_accounts USING btree (third_party_contact_id);

COMMENT ON COLUMN public.creditor_accounts.creditor_account_id     IS 'Unique identifier of the Creditor Account';
COMMENT ON COLUMN public.creditor_accounts.business_unit_id        IS 'Identifier of the related Business Unit';
COMMENT ON COLUMN public.creditor_accounts.account_number          IS 'Account number unique within the Business Unit';
COMMENT ON COLUMN public.creditor_accounts.creditor_account_type   IS 'MN Minor Creditor, MJ Major Creditor, or CF Central Fund type';
COMMENT ON COLUMN public.creditor_accounts.major_creditor_id       IS 'Identifier of the related Major Creditor';
COMMENT ON COLUMN public.creditor_accounts.minor_creditor_party_id IS 'Identifier of the person or organisation owning a Minor Creditor account';
COMMENT ON COLUMN public.creditor_accounts.from_suspense           IS 'Whether the creditor was created from a suspense transaction';
COMMENT ON COLUMN public.creditor_accounts.hold_payout             IS 'Whether payout of received monies is held';
COMMENT ON COLUMN public.creditor_accounts.pay_by_bacs             IS 'Whether the creditor is paid by BACS rather than cheque';
COMMENT ON COLUMN public.creditor_accounts.bank_sort_code          IS 'Bank sort code';
COMMENT ON COLUMN public.creditor_accounts.bank_account_number     IS 'Bank account number';
COMMENT ON COLUMN public.creditor_accounts.bank_account_name       IS 'Bank account name';
COMMENT ON COLUMN public.creditor_accounts.bank_account_reference  IS 'Bank account reference';
COMMENT ON COLUMN public.creditor_accounts.third_party_contact_id  IS 'Identifier of the optional third-party contact';
COMMENT ON COLUMN public.creditor_accounts.last_changed_date       IS 'Date the account or party was last changed';
COMMENT ON COLUMN public.creditor_accounts.non_uk_bank_detail      IS 'Structured non-UK bank account details';
COMMENT ON COLUMN public.creditor_accounts.version_number          IS 'Optimistic-locking version of the account';
