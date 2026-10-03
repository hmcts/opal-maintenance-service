/**
 * OPAL Program
 *
 * MODULE      : V1_19__create_debtor_detail_table.sql
 * DESCRIPTION : Create the RM DEBTOR_DETAIL table, Country FK, index and owned sequence.
 *
 * CHANGE HISTORY:
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * 03/10/2026  Chris Larkin  PO-10641      Create the approved table-owned database objects
 */

CREATE SEQUENCE public.debtor_detail_id_seq AS BIGINT START WITH 1 INCREMENT BY 1 NO CYCLE CACHE 1;

CREATE TABLE public.debtor_detail (
    debtor_detail_id           BIGINT DEFAULT nextval('public.debtor_detail_id_seq'::regclass) NOT NULL,
    employer_name              VARCHAR(50),
    employer_address_line_1    VARCHAR(35),
    employer_address_line_2    VARCHAR(35),
    employer_address_line_3    VARCHAR(35),
    employer_address_line_4    VARCHAR(35),
    employer_address_line_5    VARCHAR(35),
    employer_postcode          VARCHAR(10),
    employer_country_id        BIGINT,
    employee_reference         VARCHAR(35),
    employer_telephone         VARCHAR(35),
    employer_email             VARCHAR(80),
    other_personal_information VARCHAR(200),
    CONSTRAINT debtor_detail_pk PRIMARY KEY (debtor_detail_id),
    CONSTRAINT dd_employer_country_id_fk FOREIGN KEY (employer_country_id) REFERENCES public.countries (country_id)
);
ALTER SEQUENCE public.debtor_detail_id_seq OWNED BY public.debtor_detail.debtor_detail_id;
CREATE INDEX debtor_detail_employer_country_id_idx ON public.debtor_detail USING btree (employer_country_id);

COMMENT ON COLUMN public.debtor_detail.debtor_detail_id           IS 'Unique identifier of the Debtor Detail';
COMMENT ON COLUMN public.debtor_detail.employer_name              IS 'Employer name';
COMMENT ON COLUMN public.debtor_detail.employer_address_line_1    IS 'Employer address line 1';
COMMENT ON COLUMN public.debtor_detail.employer_address_line_2    IS 'Employer address line 2';
COMMENT ON COLUMN public.debtor_detail.employer_address_line_3    IS 'Employer address line 3';
COMMENT ON COLUMN public.debtor_detail.employer_address_line_4    IS 'Employer address line 4';
COMMENT ON COLUMN public.debtor_detail.employer_address_line_5    IS 'Employer address line 5';
COMMENT ON COLUMN public.debtor_detail.employer_postcode          IS 'Employer postcode';
COMMENT ON COLUMN public.debtor_detail.employer_country_id        IS 'Employer country';
COMMENT ON COLUMN public.debtor_detail.employee_reference         IS 'Employee reference number';
COMMENT ON COLUMN public.debtor_detail.employer_telephone         IS 'Employer telephone number';
COMMENT ON COLUMN public.debtor_detail.employer_email             IS 'Employer email address';
COMMENT ON COLUMN public.debtor_detail.other_personal_information IS 'Optional additional respondent details';
