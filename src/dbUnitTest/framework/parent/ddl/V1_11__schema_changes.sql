/**
 * OPAL Program
 *
 * MODULE      : V1_11__schema_changes.sql
 *
 * DESCRIPTION : Fixed parent-transition regression migration; never production.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket             Nature of Change
 * ----------  -------------  -----------------  ----------------------------------------
 * 18/10/2026  Frankie Moran  parent-transition  Initial fixed batch regression.
 */
ALTER TABLE public.aliases ALTER COLUMN surname DROP NOT NULL,ALTER COLUMN forenames DROP NOT NULL,
    ALTER COLUMN organisation_name TYPE VARCHAR(80);
ALTER TABLE public.order_terms ADD COLUMN result_responses JSON;
COMMENT ON COLUMN public.order_terms.result_responses IS 'Result-response JSON array captured for the Order Term; NULL when not captured or unavailable.';
ALTER TABLE public.order_terms ADD CONSTRAINT ot_result_responses_array_ck
    CHECK (result_responses IS NULL OR JSON_TYPEOF(result_responses)='array');
