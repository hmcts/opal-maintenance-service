/**
 * OPAL Program
 *
 * MODULE      : V1_10__replace_routines.sql
 *
 * DESCRIPTION : Fixed parent-transition regression migration; never production.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket             Nature of Change
 * ----------  -------------  -----------------  ----------------------------------------
 * 18/10/2026  Frankie Moran  PO-10655           Initial fixed batch regression.
 */
CREATE OR REPLACE FUNCTION public.framework_new(public.framework_enum) RETURNS INTEGER LANGUAGE SQL AS 'SELECT 2';
CREATE OR REPLACE FUNCTION public.framework_existing(public.framework_enum) RETURNS INTEGER LANGUAGE SQL AS 'SELECT 2';
