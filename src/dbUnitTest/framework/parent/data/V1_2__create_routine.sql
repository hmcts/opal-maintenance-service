/**
 * OPAL Program
 *
 * MODULE      : V1_2__create_routine.sql
 *
 * DESCRIPTION : Fixed parent-transition regression migration; never production.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket             Nature of Change
 * ----------  -------------  -----------------  ----------------------------------------
 * 18/10/2026  Frankie Moran  parent-transition  Initial fixed batch regression.
 */
CREATE FUNCTION public.framework_new(public.framework_enum) RETURNS INTEGER LANGUAGE SQL AS 'SELECT 1';
