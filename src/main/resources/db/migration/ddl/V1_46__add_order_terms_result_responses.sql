/**
 * OPAL Program
 *
 * MODULE      : V1_46__add_order_terms_result_responses.sql
 *
 * DESCRIPTION : Add nullable generic Order Term responses with top-level array storage enforcement.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket        Nature of Change
 * ----------  -------------  ------------  ----------------------------------------
 * 17/10/2026  Frankie Moran  PO-10646      Add the generic response storage schema prerequisite.
 */

ALTER TABLE public.order_terms ADD COLUMN result_responses JSON;

COMMENT ON COLUMN public.order_terms.result_responses IS 'Result-response JSON array captured for the Order Term; NULL when not captured or unavailable.';

ALTER TABLE public.order_terms
    ADD CONSTRAINT ot_result_responses_array_ck
    CHECK (result_responses IS NULL OR JSON_TYPEOF(result_responses) = 'array');
