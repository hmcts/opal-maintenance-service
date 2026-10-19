/**
 * OPAL Program
 *
 * MODULE      : V1_11__create_maintenance_applications_table.sql
 * DESCRIPTION : Create the RM MAINTENANCE_APPLICATIONS physical table bundle.
 *
 * CHANGE HISTORY:
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * 22/09/2026  Chris Larkin  PO-10285      Create table, keys, filter index and sequence
 */

CREATE SEQUENCE public.application_id_seq
    AS SMALLINT
    START WITH 1
    INCREMENT BY 1
    NO CYCLE
    CACHE 1;

CREATE TABLE public.maintenance_applications (
    application_id          SMALLINT DEFAULT nextval('public.application_id_seq'::regclass) NOT NULL,
    application_code        VARCHAR(8) NOT NULL,
    application_title       VARCHAR(255) NOT NULL,
    application_group       VARCHAR(20) NOT NULL,
    application_wording     TEXT,
    application_responses   JSON,
    application_act_section TEXT,
    application_act_summary TEXT,
    active                  BOOLEAN NOT NULL,
    date_used_from          DATE NOT NULL,
    date_used_to            DATE,
    CONSTRAINT maintenance_applications_pk PRIMARY KEY (application_id),
    CONSTRAINT maintenance_applications_application_code_uk UNIQUE (application_code)
);

ALTER SEQUENCE public.application_id_seq
    OWNED BY public.maintenance_applications.application_id;

CREATE INDEX maintenance_applications_application_group_active_idx
    ON public.maintenance_applications USING btree (application_group, active);

COMMENT ON COLUMN public.maintenance_applications.application_id          IS 'Database-generated primary key';
COMMENT ON COLUMN public.maintenance_applications.application_code        IS 'Unique business code';
COMMENT ON COLUMN public.maintenance_applications.application_title       IS 'Application title displayed with the code';
COMMENT ON COLUMN public.maintenance_applications.application_group       IS 'Used to filter applications for different journeys';
COMMENT ON COLUMN public.maintenance_applications.application_wording     IS 'Wording containing parameter placeholders';
COMMENT ON COLUMN public.maintenance_applications.application_responses   IS 'Structured prompts/responses';
COMMENT ON COLUMN public.maintenance_applications.application_act_section IS 'Full legislation text/reference';
COMMENT ON COLUMN public.maintenance_applications.application_act_summary IS 'Legislation summary';
COMMENT ON COLUMN public.maintenance_applications.active                  IS 'Whether the record is available for new selection.';
COMMENT ON COLUMN public.maintenance_applications.date_used_from          IS 'Start date that this Maintenance Application can be used from';
COMMENT ON COLUMN public.maintenance_applications.date_used_to            IS 'Last date on which the Maintenance Application can be referenced';
