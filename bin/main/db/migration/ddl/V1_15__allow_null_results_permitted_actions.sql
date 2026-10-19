/**
 * OPAL Program
 *
 * MODULE      : V1_15__allow_null_results_permitted_actions.sql
 *
 * DESCRIPTION : Allow absent permitted actions without changing existing values.
 *
 * CHANGE HISTORY:
 *
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * 01/10/2026  Chris Larkin  PO-10893      Allow NULL; retain VARCHAR(100) and data.
 */

ALTER TABLE public.results
    ALTER COLUMN enf_next_permitted_actions DROP NOT NULL;
