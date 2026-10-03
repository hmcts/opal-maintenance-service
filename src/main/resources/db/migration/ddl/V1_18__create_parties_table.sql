/**
 * OPAL Program
 *
 * MODULE      : V1_18__create_parties_table.sql
 * DESCRIPTION : Create the RM PARTIES table, account type enum, keys, index and owned sequence.
 *
 * CHANGE HISTORY:
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * 03/10/2026  Chris Larkin  PO-10654      Create the approved table-owned database objects
 */

CREATE TYPE public.t_party_account_type_enum AS ENUM ('Respondent', 'Minor Creditor');

CREATE SEQUENCE public.party_id_seq AS BIGINT START WITH 1 INCREMENT BY 1 NO CYCLE CACHE 1;

CREATE TABLE public.parties (
    party_id                      BIGINT DEFAULT nextval('public.party_id_seq'::regclass) NOT NULL,
    organisation                  BOOLEAN,
    organisation_name             VARCHAR(80),
    foreign_authority_reference   TEXT,
    surname                       VARCHAR(50),
    forenames                     VARCHAR(50),
    title                         VARCHAR(20),
    birth_date                    DATE,
    national_insurance_number     VARCHAR(10),
    address_line_1                VARCHAR(35)                                             NOT NULL,
    address_line_2                VARCHAR(35),
    address_line_3                VARCHAR(35),
    address_line_4                VARCHAR(35),
    address_line_5                VARCHAR(35),
    postcode                      VARCHAR(10),
    telephone_home                VARCHAR(35),
    telephone_business            VARCHAR(35),
    telephone_mobile              VARCHAR(35),
    email_1                       VARCHAR(80),
    email_2                       VARCHAR(80),
    restrict_personal_information BOOLEAN                                                 NOT NULL,
    restriction_reason            TEXT,
    country_id                    BIGINT                                                  NOT NULL,
    account_type                  public.t_party_account_type_enum,
    last_changed_date             TIMESTAMP,
    CONSTRAINT parties_pk PRIMARY KEY (party_id),
    CONSTRAINT parties_country_id_fk FOREIGN KEY (country_id) REFERENCES public.countries (country_id)
);
ALTER SEQUENCE public.party_id_seq OWNED BY public.parties.party_id;
CREATE INDEX parties_country_id_idx ON public.parties USING btree (country_id);

COMMENT ON COLUMN public.parties.party_id                      IS 'Unique identifier of the party';
COMMENT ON COLUMN public.parties.organisation                  IS 'Whether the party is an organisation rather than a person';
COMMENT ON COLUMN public.parties.organisation_name             IS 'Organisation name; null for a person';
COMMENT ON COLUMN public.parties.foreign_authority_reference   IS 'Reference supplied if the party is an organisation';
COMMENT ON COLUMN public.parties.surname                       IS 'Person surname; null for an organisation';
COMMENT ON COLUMN public.parties.forenames                     IS 'Person forenames; null for an organisation';
COMMENT ON COLUMN public.parties.title                         IS 'Person title; null for an organisation';
COMMENT ON COLUMN public.parties.birth_date                    IS 'Person date of birth';
COMMENT ON COLUMN public.parties.national_insurance_number     IS 'Person National Insurance number';
COMMENT ON COLUMN public.parties.address_line_1                IS 'Address line 1';
COMMENT ON COLUMN public.parties.address_line_2                IS 'Address line 2';
COMMENT ON COLUMN public.parties.address_line_3                IS 'Address line 3';
COMMENT ON COLUMN public.parties.address_line_4                IS 'Address line 4';
COMMENT ON COLUMN public.parties.address_line_5                IS 'Address line 5';
COMMENT ON COLUMN public.parties.postcode                      IS 'Postcode';
COMMENT ON COLUMN public.parties.telephone_home                IS 'Home telephone number';
COMMENT ON COLUMN public.parties.telephone_business            IS 'Business telephone number';
COMMENT ON COLUMN public.parties.telephone_mobile              IS 'Mobile telephone number';
COMMENT ON COLUMN public.parties.email_1                       IS 'Primary email address';
COMMENT ON COLUMN public.parties.email_2                       IS 'Secondary email address';
COMMENT ON COLUMN public.parties.restrict_personal_information IS 'Whether access to the party''s personal information is restricted';
COMMENT ON COLUMN public.parties.restriction_reason            IS 'Reason personal information is restricted; mandatory only when the restriction flag is selected';
COMMENT ON COLUMN public.parties.country_id                    IS 'Country where the party resides';
COMMENT ON COLUMN public.parties.account_type                  IS 'Account type boundary used to prevent cross-account party merging';
COMMENT ON COLUMN public.parties.last_changed_date             IS 'Date the party was last changed';
