/**
 * OPAL Program
 *
 * MODULE      : V1_8__create_results_table.sql
 *
 * DESCRIPTION : Create the RM RESULTS table bundle defined by the promoted
 *               Create Draft Casefile TDIA.
 *
 * CHANGE HISTORY:
 *
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * 21/09/2026  Chris Larkin  PO-10286      Create the RM RESULTS table bundle
 */

CREATE TYPE public.t_case_result_type_enum AS ENUM (
    'Ancillary',
    'Interim',
    'Final'
);

CREATE TABLE public.results (
    result_id                    VARCHAR(6)                     NOT NULL,
    result_title                 VARCHAR(60)                    NOT NULL,
    order_term                   BOOLEAN                        NOT NULL,
    enforcement_result           BOOLEAN                        NOT NULL,
    case_result                  BOOLEAN                        NOT NULL,
    case_result_type             public.t_case_result_type_enum,
    active                       BOOLEAN                        NOT NULL,
    order_accruing               BOOLEAN                        NOT NULL,
    requires_creditor            BOOLEAN                        NOT NULL,
    enforcement_hold             BOOLEAN                        NOT NULL,
    requires_enforcer            BOOLEAN                        NOT NULL,
    generates_hearing            BOOLEAN                        NOT NULL,
    generates_warrant            BOOLEAN                        NOT NULL,
    lists_monies                 BOOLEAN                        NOT NULL,
    result_parameters            JSON,
    requires_employment_data     BOOLEAN                        NOT NULL,
    allow_additional_action      BOOLEAN                        NOT NULL,
    enf_next_permitted_actions   VARCHAR(100)                   NOT NULL,
    manual_enforcement           BOOLEAN                        NOT NULL,
    auto_enforcement             BOOLEAN                        NOT NULL,
    CONSTRAINT results_pk PRIMARY KEY (result_id)
);

CREATE INDEX results_order_term_active_idx
    ON public.results (order_term, active);

COMMENT ON COLUMN public.results.result_id                    IS 'Primary/business key for the Result';
COMMENT ON COLUMN public.results.result_title                 IS 'Result title presented for selection';
COMMENT ON COLUMN public.results.order_term                   IS 'Whether the Result creates or affects an Order Term';
COMMENT ON COLUMN public.results.enforcement_result           IS 'Whether the record is an enforcement action';
COMMENT ON COLUMN public.results.case_result                  IS 'Classifies whether the record is a hearing result';
COMMENT ON COLUMN public.results.case_result_type             IS 'Case-lifecycle classification: Ancillary, Interim or Final';
COMMENT ON COLUMN public.results.active                       IS 'Whether the Result can be selected for new accounts';
COMMENT ON COLUMN public.results.order_accruing               IS 'Whether the Order Term accrues over time';
COMMENT ON COLUMN public.results.requires_creditor            IS 'Indicates that on applying the result, a creditor must be selected';
COMMENT ON COLUMN public.results.enforcement_hold             IS 'Indicates if this action places a hold on enforcement';
COMMENT ON COLUMN public.results.requires_enforcer            IS 'Whether the user must also specify an enforcer';
COMMENT ON COLUMN public.results.generates_hearing            IS 'Whether applying the action can schedule an enforcement hearing';
COMMENT ON COLUMN public.results.generates_warrant            IS 'Indicates if a warrant needs to be generated as part of this result';
COMMENT ON COLUMN public.results.lists_monies                 IS 'This result will cause the account to be reported on List Monies Under Warrant if a payment is received while this is the last enforcement action on the account';
COMMENT ON COLUMN public.results.result_parameters            IS 'Metadata for the dynamic fields required when applying the Result';
COMMENT ON COLUMN public.results.requires_employment_data     IS 'Flag to state that the enforcement action requires employment data to exist on the account in order to apply the action';
COMMENT ON COLUMN public.results.allow_additional_action      IS 'Flag to state which enforcement actions allow the user to add another enforcement action in the same journey as applying the action (WDN) or removing the action (NOENF)';
COMMENT ON COLUMN public.results.enf_next_permitted_actions   IS 'A comma separated list of result_ids of permitted next actions for each active manual enforcement action. If value is “All”, then allow all result_ids.';
COMMENT ON COLUMN public.results.manual_enforcement           IS 'Flag to state that the result can be used as a manual enforcement';
COMMENT ON COLUMN public.results.auto_enforcement             IS 'Flag to state that the result can be used as an auto-enforcement on an [Enforcement Path]';
