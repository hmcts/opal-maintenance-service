/**
 * OPAL Program
 *
 * MODULE      : V1_17__create_associated_record_type_enum.sql
 *
 * DESCRIPTION : Create the shared associated record type enum.
 *
 * CHANGE HISTORY:
 *
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * 03/10/2026  Chris Larkin  PO-10635      Create approved database object.
 */

CREATE TYPE public.t_associated_record_type_enum AS ENUM (
    'respondent_accounts',
    'creditor_accounts',
    'creditor_transactions',
    'suspense_transactions'
);
