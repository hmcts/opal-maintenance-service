/**
 * OPAL Program
 *
 * MODULE      : V1_60__alter_aliases_name_columns.sql
 *
 * DESCRIPTION : Relax ALIASES individual-name nullability and widen organisation name.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket                     Nature of Change
 * ----------  -------------  -------------------------  ----------------------------------------
 * 17/10/2026  Frankie Moran  PO-10648                   Initial correction delivery.
 */

ALTER TABLE public.aliases
    ALTER COLUMN surname DROP NOT NULL,
    ALTER COLUMN forenames DROP NOT NULL,
    ALTER COLUMN organisation_name TYPE VARCHAR(80);
