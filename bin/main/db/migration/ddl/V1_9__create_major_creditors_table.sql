/**
 * OPAL Program
 *
 * MODULE      : V1_9__create_major_creditors_table.sql
 *
 * DESCRIPTION : Create the RM MAJOR_CREDITORS table bundle defined by the
 *               promoted Create Draft Casefile TDIA.
 *
 * CHANGE HISTORY:
 *
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * 21/09/2026  Chris Larkin  PO-10289      Create the RM MAJOR_CREDITORS table bundle
 */

CREATE SEQUENCE public.major_creditor_id_seq
    AS BIGINT
    START WITH 1
    INCREMENT BY 1
    NO CYCLE
    CACHE 1;

CREATE TABLE public.major_creditors (
    major_creditor_id   BIGINT      DEFAULT nextval('public.major_creditor_id_seq') NOT NULL,
    business_unit_id    SMALLINT                                                    NOT NULL,
    major_creditor_code VARCHAR(4)                                                  NOT NULL,
    name                VARCHAR(100)                                                NOT NULL,
    address_line_1      VARCHAR(35)                                                 NOT NULL,
    address_line_2      VARCHAR(35),
    address_line_3      VARCHAR(35),
    address_line_4      VARCHAR(35),
    address_line_5      VARCHAR(35),
    postcode            VARCHAR(10),
    country_id          BIGINT,
    contact_name        VARCHAR(35),
    contact_email       VARCHAR(254),
    active              BOOLEAN                                                     NOT NULL,
    central_authority   BOOLEAN                                                     NOT NULL,
    CONSTRAINT major_creditors_pk PRIMARY KEY (major_creditor_id),
    CONSTRAINT mc_business_unit_id_fk
        FOREIGN KEY (business_unit_id)
        REFERENCES public.business_units (business_unit_id),
    CONSTRAINT mc_business_unit_id_major_creditor_code_uk
        UNIQUE (business_unit_id, major_creditor_code),
    CONSTRAINT mc_country_id_fk
        FOREIGN KEY (country_id)
        REFERENCES public.countries (country_id)
);

ALTER SEQUENCE public.major_creditor_id_seq
    OWNED BY public.major_creditors.major_creditor_id;

CREATE INDEX major_creditors_business_unit_id_idx
    ON public.major_creditors USING btree (business_unit_id);

CREATE INDEX major_creditors_country_id_idx
    ON public.major_creditors USING btree (country_id);

CREATE INDEX major_creditors_central_authority_active_idx
    ON public.major_creditors USING btree (central_authority, active);

COMMENT ON COLUMN public.major_creditors.major_creditor_id   IS 'Database-generated primary key';
COMMENT ON COLUMN public.major_creditors.business_unit_id    IS 'Owning RM Business Unit';
COMMENT ON COLUMN public.major_creditors.major_creditor_code IS 'Business key, unique within the Business Unit';
COMMENT ON COLUMN public.major_creditors.name                IS 'Major Creditor display name';
COMMENT ON COLUMN public.major_creditors.address_line_1      IS 'Address line 1';
COMMENT ON COLUMN public.major_creditors.address_line_2      IS 'Address line 2';
COMMENT ON COLUMN public.major_creditors.address_line_3      IS 'Address line 3';
COMMENT ON COLUMN public.major_creditors.address_line_4      IS 'Address line 4';
COMMENT ON COLUMN public.major_creditors.address_line_5      IS 'Address line 5';
COMMENT ON COLUMN public.major_creditors.postcode            IS 'Postcode';
COMMENT ON COLUMN public.major_creditors.country_id          IS 'Reference to Country';
COMMENT ON COLUMN public.major_creditors.contact_name        IS 'Named contact';
COMMENT ON COLUMN public.major_creditors.contact_email       IS 'Contact email address';
COMMENT ON COLUMN public.major_creditors.active              IS 'Whether the record is available for new selection';
COMMENT ON COLUMN public.major_creditors.central_authority   IS 'Whether the Major Creditor is also a Central Authority';
