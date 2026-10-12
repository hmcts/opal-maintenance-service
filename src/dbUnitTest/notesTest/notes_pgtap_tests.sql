/**
 * OPAL Program
 *
 * MODULE      : notes_pgtap_tests.sql
 *
 * DESCRIPTION : Verify the Notes schema, shared record type and integrity rules.
 *
 * CHANGE HISTORY:
 *
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * 03/10/2026  Chris Larkin  PO-10652      Initial pgTAP test suite.
 */

\set ON_ERROR_STOP on
-- PO-10652: catalogue and behavioural contract for the approved initial schema.
-- Applicability: fresh DB-01 path. Existing-state validation is not run under
-- the user-approved initial-schema scope exception; this is not upgrade evidence.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SET LOCAL search_path = public, pg_temp;
SET LOCAL TIME ZONE 'UTC';
SELECT plan(43);
CREATE TEMP TABLE cv_subject (id bigint PRIMARY KEY);
CREATE TEMP TABLE cv_generated (id bigint);

-- ---------------------------------------------------------------------------
-- Scenario: The table preserves its promoted physical contract.
-- Setup:    Read the PostgreSQL catalogue after the full fresh migration chain.
-- Expected: Columns, comments, constraints and indexes exactly match TDIA.
-- ---------------------------------------------------------------------------
SELECT has_table('public', 'notes', 'public.notes exists');
SELECT results_eq(
    $actual$SELECT attname::text COLLATE "C", format_type(atttypid, atttypmod) COLLATE "C", attnotnull
    FROM pg_attribute WHERE attrelid = 'public.notes'::regclass
      AND attnum > 0 AND NOT attisdropped ORDER BY attnum$actual$,
    $expected$VALUES
        ('note_id' COLLATE "C", 'bigint' COLLATE "C", true),
        ('note_type' COLLATE "C", 't_note_type_enum' COLLATE "C", true),
        ('associated_record_type' COLLATE "C", 't_associated_record_type_enum' COLLATE "C", true),
        ('associated_record_id' COLLATE "C", 'character varying(30)' COLLATE "C", true),
        ('note_text' COLLATE "C", 'text' COLLATE "C", true),
        ('posted_date' COLLATE "C", 'timestamp without time zone' COLLATE "C", true),
        ('posted_by' COLLATE "C", 'character varying(20)' COLLATE "C", false),
        ('posted_by_name' COLLATE "C", 'character varying(100)' COLLATE "C", false)$expected$,
    'exact ordered columns, types and nullability'
);
SELECT results_eq(
    $actual$SELECT attname::text COLLATE "C", col_description(attrelid, attnum) COLLATE "C"
    FROM pg_attribute WHERE attrelid = 'public.notes'::regclass
      AND attnum > 0 AND NOT attisdropped ORDER BY attnum$actual$,
    $expected$VALUES
        ('note_id' COLLATE "C", 'Unique identifier of the note' COLLATE "C"),
        ('note_type' COLLATE "C", 'NT Standard Note, or MN Maintenance System Note type' COLLATE "C"),
        ('associated_record_type' COLLATE "C", 'Type of live record to which the note relates' COLLATE "C"),
        ('associated_record_id' COLLATE "C", 'Identifier of the live record to which the note relates' COLLATE "C"),
        ('note_text' COLLATE "C", 'Note text' COLLATE "C"),
        ('posted_date' COLLATE "C", 'Date the note was posted' COLLATE "C"),
        ('posted_by' COLLATE "C", 'Identifier of the posting user' COLLATE "C"),
        ('posted_by_name' COLLATE "C", 'Display name of the posting user' COLLATE "C")$expected$,
    'every column comment matches authoritative wording'
);
SELECT results_eq(
    $actual$SELECT c.conname::text COLLATE "C", c.contype::text COLLATE "C",
        ARRAY(SELECT a.attname::text COLLATE "C"
              FROM unnest(c.conkey) WITH ORDINALITY AS k(attnum, position)
              JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = k.attnum
              ORDER BY k.position) COLLATE "C"
    FROM pg_constraint c WHERE c.conrelid = 'public.notes'::regclass
      AND c.contype IN ('p', 'f', 'u', 'c') ORDER BY c.conname$actual$,
    $expected$VALUES
        ('notes_pk' COLLATE "C", 'p' COLLATE "C", ARRAY['note_id' COLLATE "C"]::text[] COLLATE "C")$expected$,
    'exact constraint names, kinds and ordered keys; no unexpected CHECK'
);
SELECT results_eq(
    $actual$SELECT r.relname::text COLLATE "C",
        ARRAY(SELECT a.attname::text COLLATE "C"
              FROM unnest(i.indkey) WITH ORDINALITY AS k(attnum, position)
              JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = k.attnum
              ORDER BY k.position) COLLATE "C",
        am.amname::text COLLATE "C", i.indisunique, i.indisprimary, i.indisvalid, i.indisready,
        i.indnkeyatts::integer, i.indnatts::integer,
        i.indpred IS NULL, i.indexprs IS NULL
    FROM pg_index i JOIN pg_class r ON r.oid = i.indexrelid
    JOIN pg_am am ON am.oid = r.relam
    WHERE i.indrelid = 'public.notes'::regclass ORDER BY r.relname$actual$,
    $expected$VALUES
        ('notes_pk' COLLATE "C", ARRAY['note_id' COLLATE "C"]::text[] COLLATE "C", 'btree' COLLATE "C", true, true,
         true, true, 1, 1, true, true)$expected$,
    'exact index inventory, ordered keys, uniqueness and valid ready btree state'
);

-- ---------------------------------------------------------------------------
-- Scenario: Only the identifier is generated by an owned sequence.
-- Setup:    Inspect the default expression, identity marker and sequence metadata.
-- Expected: The owned BIGINT sequence uses start 1, increment 1, cache 1 and no cycle.
-- ---------------------------------------------------------------------------
SELECT is(pg_get_serial_sequence('public.notes', 'note_id'),
    'public.note_id_seq', 'identifier sequence ownership');
SELECT is(
    (SELECT format_type(seqtypid, NULL) || ':' || seqstart || ':' || seqincrement
            || ':' || seqcache || ':' || seqcycle
     FROM pg_sequence WHERE seqrelid = 'public.note_id_seq'::regclass),
    'bigint:1:1:1:false', 'BIGINT sequence start, increment, cache and cycle'
);
SELECT is(
    (SELECT pg_get_expr(d.adbin, d.adrelid)
     FROM pg_attrdef d JOIN pg_attribute a
       ON a.attrelid = d.adrelid AND a.attnum = d.adnum
     WHERE d.adrelid = 'public.notes'::regclass AND a.attname = 'note_id'),
    'nextval(''note_id_seq''::regclass)', 'identifier defaults to the owned sequence'
);
SELECT is((SELECT count(*) FROM pg_attrdef WHERE adrelid = 'public.notes'::regclass),
    1::bigint, 'only the identifier has a database default');
SELECT is(
    (SELECT attidentity::text FROM pg_attribute
     WHERE attrelid = 'public.notes'::regclass AND attname = 'note_id'),
    '', 'identifier is sequence-backed rather than an identity column'
);
SELECT is((SELECT count(*) FROM pg_trigger
           WHERE tgrelid = 'public.notes'::regclass AND NOT tgisinternal),
    0::bigint, 'no user triggers introduce undeclared behaviour');

-- ---------------------------------------------------------------------------
-- Scenario: Note and record enums retain their exact labels and shared type identity.
-- Setup:    Read enum metadata and the type OIDs of both associated-record consumer columns.
-- Expected: Note labels are NT/MN, shared labels are exact, and ANI/Notes use the same enum OID.
-- ---------------------------------------------------------------------------
SELECT is(
    (SELECT array_agg(enumlabel::text ORDER BY enumsortorder)
     FROM pg_enum WHERE enumtypid = 'public.t_note_type_enum'::regtype),
    ARRAY['NT', 'MN']::text[], 'note enum has exactly NT then MN'
);
SELECT is(
    (SELECT array_agg(enumlabel::text ORDER BY enumsortorder)
     FROM pg_enum WHERE enumtypid = 'public.t_associated_record_type_enum'::regtype),
    ARRAY['respondent_accounts', 'creditor_accounts', 'creditor_transactions', 'suspense_transactions']::text[],
    'shared enum has the exact labels in order'
);
SELECT is(
    (SELECT atttypid FROM pg_attribute
     WHERE attrelid = 'public.account_number_index'::regclass AND attname = 'associated_record_type'),
    (SELECT atttypid FROM pg_attribute
     WHERE attrelid = 'public.notes'::regclass AND attname = 'associated_record_type'),
    'ANI and Notes consume the same shared enum OID'
);

-- ---------------------------------------------------------------------------
-- Scenario: A Standard Note persists caller-supplied posting time without a target FK.
-- Setup:    Insert NT with a text target that cannot identify a BIGINT live account and capture the ID.
-- Expected: The row succeeds, generated ID is available, and the supplied UTC timestamp is unchanged.
-- ---------------------------------------------------------------------------
SELECT lives_ok(
    $sql$WITH inserted AS (
        INSERT INTO public.notes
            (note_type, associated_record_type, associated_record_id, note_text, posted_date)
        VALUES ('NT', 'respondent_accounts', 'synthetic-target', 'Synthetic note',
                TIMESTAMP '2026-01-01 12:00:00')
        RETURNING note_id
    ) INSERT INTO cv_subject SELECT note_id FROM inserted$sql$,
    'Standard Note accepts a syntactically valid target without a corresponding account'
);
INSERT INTO cv_generated SELECT id FROM cv_subject;
SELECT is((SELECT posted_date FROM public.notes WHERE note_id = (SELECT id FROM cv_subject)),
    TIMESTAMP '2026-01-01 12:00:00', 'caller-supplied UTC timestamp persists unchanged');

-- ---------------------------------------------------------------------------
-- Scenario: Required note fields reject NULL and posting user metadata remains optional.
-- Setup:    Change one column of the captured valid row per assertion.
-- Expected: Required NULLs fail with 23502 and both posting user fields accept NULL.
-- ---------------------------------------------------------------------------
SELECT throws_ok(
    $sql$UPDATE public.notes SET note_id = NULL
    WHERE note_id = (SELECT id FROM cv_subject)$sql$,
    '23502', NULL, 'note_id rejects NULL'
);
SELECT throws_ok(
    $sql$UPDATE public.notes SET note_type = NULL
    WHERE note_id = (SELECT id FROM cv_subject)$sql$,
    '23502', NULL, 'note_type rejects NULL'
);
SELECT throws_ok(
    $sql$UPDATE public.notes SET associated_record_type = NULL
    WHERE note_id = (SELECT id FROM cv_subject)$sql$,
    '23502', NULL, 'associated_record_type rejects NULL'
);
SELECT throws_ok(
    $sql$UPDATE public.notes SET associated_record_id = NULL
    WHERE note_id = (SELECT id FROM cv_subject)$sql$,
    '23502', NULL, 'associated_record_id rejects NULL'
);
SELECT throws_ok(
    $sql$UPDATE public.notes SET note_text = NULL
    WHERE note_id = (SELECT id FROM cv_subject)$sql$,
    '23502', NULL, 'note_text rejects NULL'
);
SELECT throws_ok(
    $sql$UPDATE public.notes SET posted_date = NULL
    WHERE note_id = (SELECT id FROM cv_subject)$sql$,
    '23502', NULL, 'posted_date rejects NULL'
);
SELECT lives_ok(
    $sql$UPDATE public.notes SET posted_by = NULL
    WHERE note_id = (SELECT id FROM cv_subject)$sql$,
    'posted_by accepts NULL'
);
SELECT lives_ok(
    $sql$UPDATE public.notes SET posted_by_name = NULL
    WHERE note_id = (SELECT id FROM cv_subject)$sql$,
    'posted_by_name accepts NULL'
);

-- ---------------------------------------------------------------------------
-- Scenario: Each supported note and associated-record label is usable by Notes.
-- Setup:    Assign all literal labels to the valid row and attempt unsupported casts.
-- Expected: All valid casts succeed; unsupported note/record labels fail with 22P02.
-- ---------------------------------------------------------------------------
SELECT lives_ok(
    $sql$UPDATE public.notes SET note_type = 'NT'::public.t_note_type_enum
    WHERE note_id = (SELECT id FROM cv_subject)$sql$,
    'NT note type is accepted'
);
SELECT lives_ok(
    $sql$UPDATE public.notes SET note_type = 'MN'::public.t_note_type_enum
    WHERE note_id = (SELECT id FROM cv_subject)$sql$,
    'MN note type is accepted'
);
SELECT lives_ok(
    $sql$UPDATE public.notes
    SET associated_record_type = 'respondent_accounts'::public.t_associated_record_type_enum
    WHERE note_id = (SELECT id FROM cv_subject)$sql$,
    'respondent_accounts associated record type is accepted'
);
SELECT lives_ok(
    $sql$UPDATE public.notes
    SET associated_record_type = 'creditor_accounts'::public.t_associated_record_type_enum
    WHERE note_id = (SELECT id FROM cv_subject)$sql$,
    'creditor_accounts associated record type is accepted'
);
SELECT lives_ok(
    $sql$UPDATE public.notes
    SET associated_record_type = 'creditor_transactions'::public.t_associated_record_type_enum
    WHERE note_id = (SELECT id FROM cv_subject)$sql$,
    'creditor_transactions associated record type is accepted'
);
SELECT lives_ok(
    $sql$UPDATE public.notes
    SET associated_record_type = 'suspense_transactions'::public.t_associated_record_type_enum
    WHERE note_id = (SELECT id FROM cv_subject)$sql$,
    'suspense_transactions associated record type is accepted'
);
SELECT throws_ok(
    $sql$UPDATE public.notes SET note_type = 'unsupported'::public.t_note_type_enum
    WHERE note_id = (SELECT id FROM cv_subject)$sql$,
    '22P02', NULL, 'unsupported note type is rejected'
);
SELECT throws_ok(
    $sql$UPDATE public.notes
    SET associated_record_type = 'unsupported'::public.t_associated_record_type_enum
    WHERE note_id = (SELECT id FROM cv_subject)$sql$,
    '22P02', NULL, 'unsupported associated record type is rejected'
);

-- ---------------------------------------------------------------------------
-- Scenario: The three bounded text fields enforce their promoted lengths.
-- Setup:    Update each field alone at its maximum and then one character beyond.
-- Expected: Declared maxima succeed and overlength values fail with 22001.
-- ---------------------------------------------------------------------------
SELECT lives_ok(
    $sql$UPDATE public.notes SET associated_record_id = repeat('x', 30)
    WHERE note_id = (SELECT id FROM cv_subject)$sql$,
    'associated_record_id accepts 30 characters'
);
SELECT throws_ok(
    $sql$UPDATE public.notes SET associated_record_id = repeat('x', 31)
    WHERE note_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'associated_record_id rejects 31 characters'
);
SELECT lives_ok(
    $sql$UPDATE public.notes SET posted_by = repeat('x', 20)
    WHERE note_id = (SELECT id FROM cv_subject)$sql$,
    'posted_by accepts 20 characters'
);
SELECT throws_ok(
    $sql$UPDATE public.notes SET posted_by = repeat('x', 21)
    WHERE note_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'posted_by rejects 21 characters'
);
SELECT lives_ok(
    $sql$UPDATE public.notes SET posted_by_name = repeat('x', 100)
    WHERE note_id = (SELECT id FROM cv_subject)$sql$,
    'posted_by_name accepts 100 characters'
);
SELECT throws_ok(
    $sql$UPDATE public.notes SET posted_by_name = repeat('x', 101)
    WHERE note_id = (SELECT id FROM cv_subject)$sql$,
    '22001', NULL, 'posted_by_name rejects 101 characters'
);

-- ---------------------------------------------------------------------------
-- Scenario: Note text remains TEXT, independent of the bounded posting fields.
-- Setup:    Persist a synthetic note longer than any bounded field on the table.
-- Expected: The long text succeeds without an invented length restriction.
-- ---------------------------------------------------------------------------
SELECT lives_ok(
    $sql$UPDATE public.notes SET note_text = repeat('Synthetic note. ', 1000)
    WHERE note_id = (SELECT id FROM cv_subject)$sql$,
    'note_text accepts long synthetic TEXT content'
);

-- ---------------------------------------------------------------------------
-- Scenario: Both note types can be created and generated IDs remain distinct.
-- Setup:    Create an MN note with a non-existent textual target; try reusing the captured NT identifier.
-- Expected: MN succeeds, successful inserts have distinct non-null IDs, and duplicate ID fails with 23505.
-- ---------------------------------------------------------------------------
SELECT lives_ok(
    $sql$WITH inserted AS (
        INSERT INTO public.notes
            (note_type, associated_record_type, associated_record_id, note_text, posted_date)
        VALUES ('MN', 'creditor_accounts', 'no-live-target', 'Synthetic maintenance note',
                TIMESTAMP '2026-01-02 12:00:00')
        RETURNING note_id
    ) INSERT INTO cv_generated SELECT note_id FROM inserted$sql$,
    'Maintenance System Note is created with a generated identifier'
);
SELECT ok((SELECT bool_and(id IS NOT NULL) FROM cv_generated),
    'captured sequence-generated note identifiers are non-null');
SELECT is((SELECT count(DISTINCT id) FROM cv_generated),
    2::bigint, 'separate successful note inserts generate distinct identifiers');
SELECT throws_ok(
    $sql$INSERT INTO public.notes
        (note_id, note_type, associated_record_type, associated_record_id, note_text, posted_date)
    VALUES ((SELECT id FROM cv_subject), 'NT', 'respondent_accounts',
            'another-target', 'Synthetic duplicate ID', TIMESTAMP '2026-01-03 12:00:00')$sql$,
    '23505', NULL, 'duplicate note identifier is rejected'
);
SELECT * FROM finish();
ROLLBACK;
