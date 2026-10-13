/**
 * OPAL Program
 *
 * MODULE      : V1_1__foundation.sql
 *
 * DESCRIPTION : Fixed framework regression migration; never a production location.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket        Nature of Change
 * ----------  -------------  ------------  ----------------------------------------
 * 13/10/2026  Frankie Moran  PO-10643      Initial framework regression fixture.
 */
CREATE TABLE public.framework_reference (
    id       INTEGER PRIMARY KEY,
    label    TEXT                NOT NULL
);
COMMENT ON COLUMN public.framework_reference.id IS 'Synthetic framework reference identity';
COMMENT ON COLUMN public.framework_reference.label IS 'Synthetic framework reference value';
CREATE TABLE public.framework_gate (
    allowed    BOOLEAN NOT NULL
);
COMMENT ON COLUMN public.framework_gate.allowed IS 'Fixed framework-only candidate failure gate';
INSERT INTO public.framework_gate VALUES (true);
