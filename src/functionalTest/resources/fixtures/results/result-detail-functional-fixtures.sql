-- PO-10301 synthetic Result-detail fixtures; not a Flyway migration.
-- Run only inside this run's owned po10301_functional database, before service startup.
-- Each scenario owns one immutable row. Q301X1 belongs to the missing-record scenario.
BEGIN;

DO $$
BEGIN
    IF current_database() <> 'po10301_functional' THEN
        RAISE EXCEPTION 'PO-10301 fixtures require the owned functional database';
    END IF;
    IF EXISTS (
        SELECT 1 FROM public.results
        WHERE result_id IN ('Q301A1', 'Q301I1', 'Q301U1', 'Q301N1', 'Q301E1', 'Q301T1', 'Q301X1')
    ) THEN
        RAISE EXCEPTION 'PO-10301 fixture identifier collision' USING ERRCODE = '23505';
    END IF;
END;
$$;

INSERT INTO public.results (
    result_id, result_title, order_term, enforcement_result, case_result,
    case_result_type, active, order_accruing, requires_creditor, enforcement_hold,
    requires_enforcer, generates_hearing, generates_warrant, lists_monies,
    result_parameters, requires_employment_data, allow_additional_action,
    enf_next_permitted_actions, manual_enforcement, auto_enforcement
)
SELECT
    fixture.result_id, fixture.result_title, TRUE, FALSE, TRUE,
    'Final'::public.t_case_result_type_enum, fixture.active, FALSE, FALSE, FALSE,
    FALSE, FALSE, FALSE, FALSE, fixture.metadata::json, FALSE, FALSE,
    'All', FALSE, FALSE
FROM (VALUES
    ('Q301A1', 'Synthetic active order', TRUE,
     '[{"name":"Amount","prompt":"Amount","type":"decimal-2dp","mandatory":true,"min":0,"max":10000}]'),
    ('Q301I1', 'Synthetic inactive order', FALSE,
     '[{"name":"Reason","prompt":"Reason","type":"text-60","mandatory":false}]'),
    ('Q301U1', 'Synthetic unfamiliar metadata', TRUE,
     '[{"name":"Custom","prompt":"Custom","type":"synthetic-unfamiliar","mandatory":false}]'),
    ('Q301N1', 'Synthetic null metadata', TRUE, NULL),
    ('Q301E1', 'Synthetic empty metadata', TRUE, '[]'),
    ('Q301T1', 'Synthetic authentication order', TRUE, '[]')
) AS fixture(result_id, result_title, active, metadata);

DO $$
BEGIN
    IF (SELECT count(*) FROM public.results WHERE result_id IN (
        'Q301A1', 'Q301I1', 'Q301U1', 'Q301N1', 'Q301E1', 'Q301T1'
    )) <> 6 THEN
        RAISE EXCEPTION 'Expected six PO-10301 fixture rows';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.results
                   WHERE result_id = 'Q301I1' AND NOT active AND order_term) THEN
        RAISE EXCEPTION 'Inactive Result precondition is not established';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.results
                   WHERE result_id = 'Q301A1' AND active AND order_term
                     AND result_parameters::text =
                     '[{"name":"Amount","prompt":"Amount","type":"decimal-2dp","mandatory":true,"min":0,"max":10000}]') THEN
        RAISE EXCEPTION 'Active Result metadata precondition is not established';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.results
                   WHERE result_id = 'Q301U1' AND result_parameters::text =
                   '[{"name":"Custom","prompt":"Custom","type":"synthetic-unfamiliar","mandatory":false}]') THEN
        RAISE EXCEPTION 'Unfamiliar metadata precondition is not established';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.results
                   WHERE result_id = 'Q301N1' AND result_parameters IS NULL) THEN
        RAISE EXCEPTION 'SQL-null metadata precondition is not established';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.results
                   WHERE result_id = 'Q301E1' AND result_parameters::text = '[]') THEN
        RAISE EXCEPTION 'Empty metadata precondition is not established';
    END IF;
    IF EXISTS (SELECT 1 FROM public.results WHERE result_id = 'Q301X1') THEN
        RAISE EXCEPTION 'Missing Result identifier must be absent';
    END IF;
END;
$$;

COMMIT;
