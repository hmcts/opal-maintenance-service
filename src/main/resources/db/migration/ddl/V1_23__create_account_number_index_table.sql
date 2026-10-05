/**
 * OPAL Program
 *
 * MODULE      : V1_23__create_account_number_index_table.sql
 *
 * DESCRIPTION : Create the RM ACCOUNT_NUMBER_INDEX physical table bundle.
 *
 * CHANGE HISTORY:
 *
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * 03/10/2026  Chris Larkin  PO-10633      Create allocation table, keys and owned sequence
 */

CREATE SEQUENCE public.account_number_index_id_seq
    AS BIGINT
    START WITH 1
    INCREMENT BY 1
    NO CYCLE
    CACHE 1;

CREATE TABLE public.account_number_index (
    account_number_index_id BIGINT DEFAULT nextval('public.account_number_index_id_seq'::regclass) NOT NULL,
    business_unit_id        SMALLINT                                                               NOT NULL,
    account_number          VARCHAR(20)                                                            NOT NULL,
    associated_record_type  public.t_associated_record_type_enum,
    CONSTRAINT account_number_index_pk PRIMARY KEY (account_number_index_id),
    CONSTRAINT ani_business_unit_id_fk FOREIGN KEY (business_unit_id) REFERENCES public.business_units (business_unit_id),
    CONSTRAINT ani_business_unit_id_account_number_uk UNIQUE (business_unit_id, account_number)
);

ALTER SEQUENCE public.account_number_index_id_seq OWNED BY public.account_number_index.account_number_index_id;

COMMENT ON COLUMN public.account_number_index.account_number_index_id IS 'Unique identifier of the account-number allocation';
COMMENT ON COLUMN public.account_number_index.business_unit_id        IS 'Identifier of the related Business Unit';
COMMENT ON COLUMN public.account_number_index.account_number          IS 'Account number unique within the Business Unit';
COMMENT ON COLUMN public.account_number_index.associated_record_type  IS 'Type of account record receiving the allocated number';
