/**
 * OPAL Program
 *
 * MODULE      : V1_24__create_notes_table.sql
 *
 * DESCRIPTION : Create the RM NOTES physical table bundle.
 *
 * CHANGE HISTORY:
 *
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * 03/10/2026  Chris Larkin  PO-10652      Create note table, enum, key and owned sequence
 */

CREATE TYPE public.t_note_type_enum AS ENUM ('NT', 'MN');

CREATE SEQUENCE public.note_id_seq
    AS BIGINT
    START WITH 1
    INCREMENT BY 1
    NO CYCLE
    CACHE 1;

CREATE TABLE public.notes (
    note_id                BIGINT DEFAULT nextval('public.note_id_seq'::regclass) NOT NULL,
    note_type              public.t_note_type_enum                                NOT NULL,
    associated_record_type public.t_associated_record_type_enum                   NOT NULL,
    associated_record_id   VARCHAR(30)                                            NOT NULL,
    note_text              TEXT                                                   NOT NULL,
    posted_date            TIMESTAMP                                              NOT NULL,
    posted_by              VARCHAR(20),
    posted_by_name         VARCHAR(100),
    CONSTRAINT notes_pk PRIMARY KEY (note_id)
);

ALTER SEQUENCE public.note_id_seq OWNED BY public.notes.note_id;

COMMENT ON COLUMN public.notes.note_id                IS 'Unique identifier of the note';
COMMENT ON COLUMN public.notes.note_type              IS 'NT Standard Note, or MN Maintenance System Note type';
COMMENT ON COLUMN public.notes.associated_record_type IS 'Type of live record to which the note relates';
COMMENT ON COLUMN public.notes.associated_record_id   IS 'Identifier of the live record to which the note relates';
COMMENT ON COLUMN public.notes.note_text              IS 'Note text';
COMMENT ON COLUMN public.notes.posted_date            IS 'Date the note was posted';
COMMENT ON COLUMN public.notes.posted_by              IS 'Identifier of the posting user';
COMMENT ON COLUMN public.notes.posted_by_name         IS 'Display name of the posting user';
