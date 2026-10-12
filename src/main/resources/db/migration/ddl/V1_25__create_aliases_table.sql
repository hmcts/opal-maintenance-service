/**
 * OPAL Program
 *
 * MODULE      : V1_25__create_aliases_table.sql
 *
 * DESCRIPTION : Create the RM ALIASES physical table bundle.
 *
 * CHANGE HISTORY:
 *
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * 03/10/2026  Chris Larkin  PO-10634      Create alias table, keys, index and owned sequence
 */

CREATE SEQUENCE public.alias_id_seq
    AS BIGINT
    START WITH 1
    INCREMENT BY 1
    NO CYCLE
    CACHE 1;

CREATE TABLE public.aliases (
    alias_id          BIGINT DEFAULT nextval('public.alias_id_seq'::regclass) NOT NULL,
    party_id          BIGINT                                                  NOT NULL,
    surname           VARCHAR(50)                                             NOT NULL,
    forenames         VARCHAR(50)                                             NOT NULL,
    organisation_name VARCHAR(50),
    sequence_number   INTEGER                                                 NOT NULL,
    CONSTRAINT aliases_pk PRIMARY KEY (alias_id),
    CONSTRAINT als_party_id_fk FOREIGN KEY (party_id) REFERENCES public.parties (party_id)
);

ALTER SEQUENCE public.alias_id_seq OWNED BY public.aliases.alias_id;
CREATE INDEX aliases_party_id_idx ON public.aliases USING btree (party_id);

COMMENT ON COLUMN public.aliases.alias_id          IS 'Unique identifier of the alias';
COMMENT ON COLUMN public.aliases.party_id          IS 'Identifier of the party owning the alias';
COMMENT ON COLUMN public.aliases.surname           IS 'Alias surname';
COMMENT ON COLUMN public.aliases.forenames         IS 'Alias forenames';
COMMENT ON COLUMN public.aliases.organisation_name IS 'Alias organisation name';
COMMENT ON COLUMN public.aliases.sequence_number   IS 'Sequence of the alias within its party';
