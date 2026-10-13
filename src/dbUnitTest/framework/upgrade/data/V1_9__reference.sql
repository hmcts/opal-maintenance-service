/**
 * OPAL Program
 *
 * MODULE      : V1_9__reference.sql
 *
 * DESCRIPTION : Fixed framework regression migration; never a production location.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket        Nature of Change
 * ----------  -------------  ------------  ----------------------------------------
 * 13/10/2026  Frankie Moran  PO-10643      Initial framework regression fixture.
 */
INSERT INTO public.framework_reference VALUES (9, 'predecessor');
