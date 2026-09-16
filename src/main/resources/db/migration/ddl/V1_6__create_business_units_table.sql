/**
 * OPAL Program
 *
 * MODULE      : V1_6__create_business_units_table.sql
 *
 * DESCRIPTION : Create the RM BUSINESS_UNITS table bundle defined by the
 *               promoted Create Draft Casefile TDIA.
 *
 * CHANGE HISTORY:
 *
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * 16/09/2026  Chris Larkin  PO-10274      Create the RM BUSINESS_UNITS table bundle
 */

CREATE TYPE public.t_business_unit_type_enum AS ENUM (
    'Area',
    'Accounting Division'
);

CREATE TABLE public.business_units (
    business_unit_id SMALLINT NOT NULL,
    business_unit_code VARCHAR(4) NOT NULL,
    business_unit_name VARCHAR(200) NOT NULL,
    business_unit_type public.t_business_unit_type_enum NOT NULL,
    account_number_prefix VARCHAR(2) NOT NULL,
    parent_business_unit_id SMALLINT,
    opal_domain VARCHAR(30),
    welsh_language BOOLEAN NOT NULL,
    account_number_suffix VARCHAR(2),
    CONSTRAINT business_units_pk PRIMARY KEY (business_unit_id),
    CONSTRAINT business_units_business_unit_code_uk UNIQUE (business_unit_code),
    CONSTRAINT bu_parent_business_unit_id_fk
        FOREIGN KEY (parent_business_unit_id)
        REFERENCES public.business_units (business_unit_id)
);

CREATE INDEX business_units_parent_business_unit_id_idx
    ON public.business_units USING btree (parent_business_unit_id);

COMMENT ON COLUMN public.business_units.business_unit_id IS
    'Primary key supplied by the authoritative Business Unit catalogue';
COMMENT ON COLUMN public.business_units.business_unit_code IS
    'Unique Business Unit code';
COMMENT ON COLUMN public.business_units.business_unit_name IS
    'Business Unit display name';
COMMENT ON COLUMN public.business_units.business_unit_type IS
    'Area or Accounting Division';
COMMENT ON COLUMN public.business_units.account_number_prefix IS
    'Accounting Division prefix used before account numbers';
COMMENT ON COLUMN public.business_units.parent_business_unit_id IS
    'Self-reference to the parent Business Unit';
COMMENT ON COLUMN public.business_units.opal_domain IS
    'When business unit type is Accounting Division, then this value is the opal domain that the business unit is owned by';
COMMENT ON COLUMN public.business_units.welsh_language IS
    'Whether Welsh-language operation applies';
COMMENT ON COLUMN public.business_units.account_number_suffix IS
    'The Accounting Division suffix used with Account Numbers';
