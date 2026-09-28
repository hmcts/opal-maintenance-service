/**
 * OPAL Program
 *
 * MODULE      : V1_14__create_draft_casefiles_table.sql
 * DESCRIPTION : Create the RM DRAFT_CASEFILES physical table bundle.
 *
 * CHANGE HISTORY:
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * 26/09/2026  Chris Larkin  PO-10299      Create table, enums, keys, index and sequence
 */

CREATE TYPE public.t_casefile_type_enum AS ENUM (
    'REMO In', 'REMO Out', 'REMO Out (CMS)'
);

CREATE TYPE public.t_draft_casefile_status_enum AS ENUM (
    'SUBMITTED', 'DELETED', 'REJECTED', 'PUBLISHING_PENDING',
    'PUBLISHED', 'PUBLISHING_FAILED', 'RESUBMITTED'
);

CREATE SEQUENCE public.draft_casefile_id_seq
    AS BIGINT
    START WITH 1
    INCREMENT BY 1
    NO CYCLE
    CACHE 1;

CREATE TABLE public.draft_casefiles (
    draft_casefile_id       BIGINT DEFAULT nextval('public.draft_casefile_id_seq')           NOT NULL,
    business_unit_id        SMALLINT                                                         NOT NULL,
    created_date            TIMESTAMP                                                        NOT NULL,
    submitted_by            VARCHAR(20)                                                      NOT NULL,
    submitted_by_name       VARCHAR(100)                                                     NOT NULL,
    validated_date          TIMESTAMP,
    validated_by            VARCHAR(20),
    validated_by_name       VARCHAR(100),
    casefile                JSON                                                             NOT NULL,
    casefile_snapshot       JSON                                                             NOT NULL,
    casefile_type           public.t_casefile_type_enum                                      NOT NULL,
    casefile_status         public.t_draft_casefile_status_enum                              NOT NULL,
    casefile_status_date    TIMESTAMP                                                        NOT NULL,
    status_message          TEXT,
    timeline_data           JSON                                                             NOT NULL,
    account_number          VARCHAR(25),
    account_id              BIGINT,
    version_number          BIGINT,
    CONSTRAINT draft_casefiles_pk PRIMARY KEY (draft_casefile_id),
    CONSTRAINT dcf_business_unit_id_fk FOREIGN KEY (business_unit_id)
        REFERENCES public.business_units (business_unit_id),
    CONSTRAINT draft_casefiles_account_id_uk UNIQUE (account_id)
);

ALTER SEQUENCE public.draft_casefile_id_seq
    OWNED BY public.draft_casefiles.draft_casefile_id;

CREATE INDEX draft_casefiles_business_unit_id_idx
    ON public.draft_casefiles USING btree (business_unit_id);

-- dcf_account_id_fk is delivered by Check and Validate with RESPONDENT_ACCOUNTS.
COMMENT ON COLUMN public.draft_casefiles.draft_casefile_id       IS 'Primary key and unique identifier for the Draft Case file';
COMMENT ON COLUMN public.draft_casefiles.business_unit_id        IS 'Owning Business Unit';
COMMENT ON COLUMN public.draft_casefiles.created_date            IS 'Date and time at which the Draft Case file is first received for review';
COMMENT ON COLUMN public.draft_casefiles.submitted_by            IS 'Identifier of the submitting user';
COMMENT ON COLUMN public.draft_casefiles.submitted_by_name       IS 'Display name of the submitting user';
COMMENT ON COLUMN public.draft_casefiles.validated_date          IS 'Date and time the Draft Case file was validated';
COMMENT ON COLUMN public.draft_casefiles.validated_by            IS 'Identifier of the user who validated the Draft Case file';
COMMENT ON COLUMN public.draft_casefiles.validated_by_name       IS 'Display name of the user who validated the Draft Case file';
COMMENT ON COLUMN public.draft_casefiles.casefile                IS 'Complete structured RM Case file payload';
COMMENT ON COLUMN public.draft_casefiles.casefile_snapshot       IS 'Backend-generated identifying summary for worklist and checking displays';
COMMENT ON COLUMN public.draft_casefiles.casefile_type           IS 'REMO In, REMO Out, or REMO Out (CMS)';
COMMENT ON COLUMN public.draft_casefiles.casefile_status         IS 'Lifecycle status; initially SUBMITTED';
COMMENT ON COLUMN public.draft_casefiles.casefile_status_date    IS 'Date and time of the current status';
COMMENT ON COLUMN public.draft_casefiles.status_message          IS 'System status message; not accepted from the create-journey frontend';
COMMENT ON COLUMN public.draft_casefiles.timeline_data           IS 'Backend-created initial entry. Timeline label: Submitted. Database lifecycle value: SUBMITTED';
COMMENT ON COLUMN public.draft_casefiles.account_number          IS 'Account number of the Respondent Account created from the successfully published Draft Case file';
COMMENT ON COLUMN public.draft_casefiles.account_id              IS 'Nullable Respondent Account reference, populated only after successful publication';
COMMENT ON COLUMN public.draft_casefiles.version_number          IS 'Optimistic-locking version for later updates';
