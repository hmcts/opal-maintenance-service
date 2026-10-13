/**
 * OPAL Program
 *
 * MODULE      : V1_10__candidate.sql
 *
 * DESCRIPTION : Fixed framework regression migration; never a production location.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket        Nature of Change
 * ----------  -------------  ------------  ----------------------------------------
 * 13/10/2026  Frankie Moran  PO-10643      Initial framework regression fixture.
 */
DO $candidate$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.framework_gate WHERE allowed) THEN
        RAISE EXCEPTION 'fixed framework candidate gate is closed';
    END IF;
END;
$candidate$;
CREATE VIEW public.framework_candidate AS SELECT id, label FROM public.framework_reference;
