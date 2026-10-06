-- PO-10298 synthetic fixture; apply only to a stopped, disposable Results target.
-- Provisioning and cache/startup requirements: docs/TESTING.md.
BEGIN;

DO $$
BEGIN
    IF current_database() !~ '^opal_results_po10298_[a-z0-9_]+$'
        OR (SELECT shobj_description(oid, 'pg_database')
            FROM pg_database WHERE datname = current_database())
            IS DISTINCT FROM 'PO-10298 disposable Results fixtures' THEN
        RAISE EXCEPTION 'Results fixture requires a marked PO-10298 disposable database';
    END IF;
END;
$$;

LOCK TABLE public.results IN ACCESS EXCLUSIVE MODE;
DELETE FROM public.results;

INSERT INTO public.results (
    result_id, result_title, order_term, enforcement_result, case_result, case_result_type,
    active, order_accruing, requires_creditor, enforcement_hold, requires_enforcer,
    generates_hearing, generates_warrant, lists_monies, result_parameters,
    requires_employment_data, allow_additional_action, enf_next_permitted_actions,
    manual_enforcement, auto_enforcement
)
VALUES
    ('TNOORD', 'Synthetic non Order Term control', false, false, false, NULL,
     true, false, false, false, false, false, false, false, NULL,
     false, false, 'None', false, false),
    ('TINACT', 'Synthetic inactive Order Term control', true, false, false, NULL,
     false, false, false, false, false, false, false, false, NULL,
     false, false, 'None', false, false);

COMMIT;
