/**
 * OPAL Program
 *
 * MODULE      : V1_26__create_respondent_accounts_table.sql
 *
 * DESCRIPTION : Create the RM RESPONDENT_ACCOUNTS table bundle defined by the
 *               promoted Check & Validate Case TDIA.
 *
 * CHANGE HISTORY:
 *
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * 03/10/2026  Chris Larkin  PO-10657      Create the RM RESPONDENT_ACCOUNTS table bundle
 */

CREATE TYPE public.t_payment_frequency_enum AS ENUM ('Weekly', 'Fortnightly', 'Monthly', 'Quarterly', 'Yearly');

CREATE TYPE public.t_da_account_status_enum AS ENUM ('L', 'C');

CREATE TYPE public.t_indexation_enum AS ENUM ('RPI', 'CPI', 'Other', 'None');

CREATE TYPE public.t_payment_arrangement_enum AS ENUM ('Court', 'Direct');

CREATE SEQUENCE public.respondent_account_id_seq AS BIGINT START WITH 1 INCREMENT BY 1 NO CYCLE CACHE 1;

CREATE TABLE public.respondent_accounts (
    respondent_account_id         BIGINT DEFAULT nextval('public.respondent_account_id_seq'::regclass) NOT NULL,
    business_unit_id              SMALLINT                                                             NOT NULL,
    debtor_detail_id              BIGINT,
    account_number                VARCHAR(20)                                                          NOT NULL,
    application_id                SMALLINT                                                             NOT NULL,
    imposed_hearing_date          TIMESTAMP,
    last_hearing_date             TIMESTAMP,
    last_hearing_court_id         BIGINT,
    account_balance               NUMERIC                                                              NOT NULL,
    orders_balance                NUMERIC                                                              NOT NULL,
    orders_amount                 NUMERIC                                                              NOT NULL,
    payment_period                public.t_payment_frequency_enum                                      NOT NULL,
    total_arrears                 NUMERIC                                                              NOT NULL,
    account_status                public.t_da_account_status_enum                                      NOT NULL,
    completed_date                TIMESTAMP,
    last_movement_date            TIMESTAMP                                                            NOT NULL,
    date_arrears_last_updated     TIMESTAMP                                                            NOT NULL,
    last_enforcement_result_id    VARCHAR(6),
    last_enforcement_date         TIMESTAMP,
    originator_name               VARCHAR(200),
    allow_cheques                 BOOLEAN                                                              NOT NULL,
    cheque_clearance_period       SMALLINT                                                             NOT NULL,
    credit_trans_clearance_period SMALLINT                                                             NOT NULL,
    casefile_type                 public.t_casefile_type_enum                                          NOT NULL,
    third_party_contact_id        BIGINT,
    remo_reference                VARCHAR(20),
    ca_reference                  VARCHAR(50),
    interest_flag                 BOOLEAN                                                              NOT NULL,
    indexation                    public.t_indexation_enum                                             NOT NULL,
    payment_arrangement           public.t_payment_arrangement_enum                                    NOT NULL,
    account_comment               TEXT,
    version_number                BIGINT                                                               NOT NULL,
    CONSTRAINT respondent_accounts_pk PRIMARY KEY (respondent_account_id),
    CONSTRAINT ra_business_unit_id_fk
        FOREIGN KEY (business_unit_id)
        REFERENCES public.business_units (business_unit_id),
    CONSTRAINT ra_debtor_detail_id_fk
        FOREIGN KEY (debtor_detail_id)
        REFERENCES public.debtor_detail (debtor_detail_id),
    CONSTRAINT ra_application_id_fk
        FOREIGN KEY (application_id)
        REFERENCES public.maintenance_applications (application_id),
    CONSTRAINT ra_last_enforcement_result_id_fk
        FOREIGN KEY (last_enforcement_result_id)
        REFERENCES public.results (result_id),
    CONSTRAINT ra_third_party_contact_id_fk
        FOREIGN KEY (third_party_contact_id)
        REFERENCES public.third_party_contact (third_party_contact_id),
    CONSTRAINT ra_business_unit_id_account_number_uk UNIQUE (business_unit_id, account_number)
);
ALTER SEQUENCE public.respondent_account_id_seq OWNED BY public.respondent_accounts.respondent_account_id;
CREATE INDEX respondent_accounts_debtor_detail_id_idx ON public.respondent_accounts USING btree (debtor_detail_id);
CREATE INDEX respondent_accounts_application_id_idx ON public.respondent_accounts USING btree (application_id);
CREATE INDEX respondent_accounts_last_hearing_court_id_idx ON public.respondent_accounts USING btree (last_hearing_court_id);
CREATE INDEX respondent_accounts_last_enforcement_result_id_idx ON public.respondent_accounts USING btree (last_enforcement_result_id);
CREATE INDEX respondent_accounts_third_party_contact_id_idx ON public.respondent_accounts USING btree (third_party_contact_id);

COMMENT ON COLUMN public.respondent_accounts.respondent_account_id         IS 'Unique identifier of the Respondent Account';
COMMENT ON COLUMN public.respondent_accounts.business_unit_id              IS 'Identifier of the Business Unit owning the account';
COMMENT ON COLUMN public.respondent_accounts.debtor_detail_id              IS 'Identifier of the respondent Debtor Detail';
COMMENT ON COLUMN public.respondent_accounts.account_number                IS 'Account number unique within the Business Unit';
COMMENT ON COLUMN public.respondent_accounts.application_id                IS 'Identifier of the primary Maintenance Application';
COMMENT ON COLUMN public.respondent_accounts.imposed_hearing_date          IS 'Date the maintenance order was imposed';
COMMENT ON COLUMN public.respondent_accounts.last_hearing_date             IS 'Date the account was most recently heard in court';
COMMENT ON COLUMN public.respondent_accounts.last_hearing_court_id         IS 'Identifier of the court for the latest hearing';
COMMENT ON COLUMN public.respondent_accounts.account_balance               IS 'Receipts held on the account before allocation and payout';
COMMENT ON COLUMN public.respondent_accounts.orders_balance                IS 'Total balance due across the account''s order terms';
COMMENT ON COLUMN public.respondent_accounts.orders_amount                 IS 'Total periodic amount due across the account''s order terms';
COMMENT ON COLUMN public.respondent_accounts.payment_period                IS 'Payment period for the account';
COMMENT ON COLUMN public.respondent_accounts.total_arrears                 IS 'Total arrears across costs and order terms';
COMMENT ON COLUMN public.respondent_accounts.account_status                IS 'Lifecycle status of the Respondent Account';
COMMENT ON COLUMN public.respondent_accounts.completed_date                IS 'Date the account completed after all order terms expired and arrears cleared';
COMMENT ON COLUMN public.respondent_accounts.last_movement_date            IS 'Date of the most recent account movement';
COMMENT ON COLUMN public.respondent_accounts.date_arrears_last_updated     IS 'Date the account arrears were last updated. On publication, populate this from the mandatory Date arrears last updated value in the Draft Casefile’s Order Details object.';
COMMENT ON COLUMN public.respondent_accounts.last_enforcement_result_id    IS 'Identifier of the latest applicable enforcement result';
COMMENT ON COLUMN public.respondent_accounts.last_enforcement_date         IS 'Date the latest enforcement action was applied';
COMMENT ON COLUMN public.respondent_accounts.originator_name               IS 'Name of the originating court or system';
COMMENT ON COLUMN public.respondent_accounts.allow_cheques                 IS 'Whether cheque payments are accepted';
COMMENT ON COLUMN public.respondent_accounts.cheque_clearance_period       IS 'Days before cheque payments are treated as cleared';
COMMENT ON COLUMN public.respondent_accounts.credit_trans_clearance_period IS 'Days before credit-transfer payments are treated as cleared';
COMMENT ON COLUMN public.respondent_accounts.casefile_type                 IS 'REMO In, REMO Out, or REMO Out (CMS) casefile type';
COMMENT ON COLUMN public.respondent_accounts.third_party_contact_id        IS 'Identifier of the optional third-party contact';
COMMENT ON COLUMN public.respondent_accounts.remo_reference                IS 'REMO reference for the account';
COMMENT ON COLUMN public.respondent_accounts.ca_reference                  IS 'Central Authority reference for the account';
COMMENT ON COLUMN public.respondent_accounts.interest_flag                 IS 'Whether interest applies to the account';
COMMENT ON COLUMN public.respondent_accounts.indexation                    IS 'RPI, CPI, None, or Other indexation method';
COMMENT ON COLUMN public.respondent_accounts.payment_arrangement           IS 'Court or direct payment arrangement';
COMMENT ON COLUMN public.respondent_accounts.account_comment               IS 'Optional account comment displayed in Account Enquiry';
COMMENT ON COLUMN public.respondent_accounts.version_number                IS 'Optimistic-locking version of the account';
