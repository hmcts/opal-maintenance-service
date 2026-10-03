/**
 * OPAL Program
 *
 * MODULE      : V1_20__create_third_party_contact_table.sql
 * DESCRIPTION : Create the RM THIRD_PARTY_CONTACT table, primary key and owned sequence.
 *
 * CHANGE HISTORY:
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * 03/10/2026  Chris Larkin  PO-10658      Create the approved table-owned database objects
 */

CREATE SEQUENCE public.third_party_contact_id_seq AS BIGINT START WITH 1 INCREMENT BY 1 NO CYCLE CACHE 1;

CREATE TABLE public.third_party_contact (
    third_party_contact_id BIGINT DEFAULT nextval('public.third_party_contact_id_seq'::regclass) NOT NULL,
    name_organisation      VARCHAR(40)                                                           NOT NULL,
    relationship           VARCHAR(40)                                                           NOT NULL,
    reference              VARCHAR(40),
    address_line_1         VARCHAR(35)                                                           NOT NULL,
    address_line_2         VARCHAR(35),
    address_line_3         VARCHAR(35),
    address_line_4         VARCHAR(35),
    address_line_5         VARCHAR(35),
    postcode               VARCHAR(10),
    country                BIGINT                                                                NOT NULL,
    version_number         BIGINT,
    CONSTRAINT third_party_contact_pk PRIMARY KEY (third_party_contact_id)
);
ALTER SEQUENCE public.third_party_contact_id_seq OWNED BY public.third_party_contact.third_party_contact_id;

COMMENT ON COLUMN public.third_party_contact.third_party_contact_id IS 'Unique identifier of the third-party contact';
COMMENT ON COLUMN public.third_party_contact.name_organisation      IS 'Name of the third-party person or organisation';
COMMENT ON COLUMN public.third_party_contact.relationship           IS 'Relationship between the contact and account holder';
COMMENT ON COLUMN public.third_party_contact.reference              IS 'Reference supplied for the third-party contact';
COMMENT ON COLUMN public.third_party_contact.address_line_1         IS 'Address line 1';
COMMENT ON COLUMN public.third_party_contact.address_line_2         IS 'Address line 2';
COMMENT ON COLUMN public.third_party_contact.address_line_3         IS 'Address line 3';
COMMENT ON COLUMN public.third_party_contact.address_line_4         IS 'Address line 4';
COMMENT ON COLUMN public.third_party_contact.address_line_5         IS 'Address line 5';
COMMENT ON COLUMN public.third_party_contact.postcode               IS 'Postcode';
COMMENT ON COLUMN public.third_party_contact.country                IS 'Country';
COMMENT ON COLUMN public.third_party_contact.version_number         IS 'Optimistic-locking version of the contact';
