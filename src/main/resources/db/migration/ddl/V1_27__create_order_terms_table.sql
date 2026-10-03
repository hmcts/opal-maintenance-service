/**
 * OPAL Program
 *
 * MODULE      : V1_27__create_order_terms_table.sql
 * DESCRIPTION : Create the RM ORDER_TERMS table, account and Result FKs, indexes and owned sequence.
 *
 * CHANGE HISTORY:
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * 03/10/2026  Chris Larkin  PO-10653      Create the approved Order Terms table-owned objects
 */

CREATE SEQUENCE public.order_terms_id_seq AS BIGINT START WITH 1 INCREMENT BY 1 NO CYCLE CACHE 1;

CREATE TABLE public.order_terms (
    order_terms_id        BIGINT DEFAULT nextval('public.order_terms_id_seq'::regclass) NOT NULL,
    respondent_account_id BIGINT                                                        NOT NULL,
    creditor_account_id   BIGINT                                                        NOT NULL,
    result_id             VARCHAR(6)                                                    NOT NULL,
    posted_date           TIMESTAMP                                                     NOT NULL,
    posted_by             VARCHAR(20),
    posted_by_name        VARCHAR(100),
    original_posted_date  TIMESTAMP,
    imposed_date          TIMESTAMP                                                     NOT NULL,
    imposed_amount        NUMERIC                                                       NOT NULL,
    arrears_amount        NUMERIC,
    completed             BOOLEAN                                                       NOT NULL,
    child_name            VARCHAR(100),
    child_birth_date      TIMESTAMP,
    expiry_date           TIMESTAMP,
    expiry_terms          BOOLEAN,
    remitted_amount       NUMERIC,
    CONSTRAINT order_terms_pk PRIMARY KEY (order_terms_id),
    CONSTRAINT ot_respondent_account_id_fk FOREIGN KEY (respondent_account_id) REFERENCES public.respondent_accounts (respondent_account_id),
    CONSTRAINT ot_creditor_account_id_fk FOREIGN KEY (creditor_account_id) REFERENCES public.creditor_accounts (creditor_account_id),
    CONSTRAINT ot_result_id_fk FOREIGN KEY (result_id) REFERENCES public.results (result_id)
);
ALTER SEQUENCE public.order_terms_id_seq OWNED BY public.order_terms.order_terms_id;
CREATE INDEX order_terms_respondent_account_id_idx ON public.order_terms USING btree (respondent_account_id);
CREATE INDEX order_terms_creditor_account_id_idx ON public.order_terms USING btree (creditor_account_id);
CREATE INDEX order_terms_result_id_idx ON public.order_terms USING btree (result_id);

COMMENT ON COLUMN public.order_terms.order_terms_id        IS 'Unique identifier of the Order Terms';
COMMENT ON COLUMN public.order_terms.respondent_account_id IS 'Identifier of the related Respondent Account';
COMMENT ON COLUMN public.order_terms.creditor_account_id   IS 'Identifier of the Creditor Account receiving allocated payments';
COMMENT ON COLUMN public.order_terms.result_id             IS 'Identifier of the court result defining the order-term type';
COMMENT ON COLUMN public.order_terms.posted_date           IS 'Date the order term was posted';
COMMENT ON COLUMN public.order_terms.posted_by             IS 'Identifier of the posting user';
COMMENT ON COLUMN public.order_terms.posted_by_name        IS 'Display name of the posting user';
COMMENT ON COLUMN public.order_terms.original_posted_date  IS 'Original posting date where the order term duplicates a written-off legacy imposition';
COMMENT ON COLUMN public.order_terms.imposed_date          IS 'Date the maintenance order was imposed';
COMMENT ON COLUMN public.order_terms.imposed_amount        IS 'Amount imposed by the court';
COMMENT ON COLUMN public.order_terms.arrears_amount        IS 'Arrears amount for the order term';
COMMENT ON COLUMN public.order_terms.completed             IS 'Whether the order term has been paid in full';
COMMENT ON COLUMN public.order_terms.child_name            IS 'Child name for the payable maintenance component';
COMMENT ON COLUMN public.order_terms.child_birth_date      IS 'Child birth date for the payable maintenance component';
COMMENT ON COLUMN public.order_terms.expiry_date           IS 'Expiry date of the payable maintenance component';
COMMENT ON COLUMN public.order_terms.expiry_terms          IS 'Whether further-education expiry terms apply';
COMMENT ON COLUMN public.order_terms.remitted_amount       IS 'Remitted arrears or order-term amount; null until a remittance is recorded';
