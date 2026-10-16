INSERT INTO business_units
    (business_unit_id, business_unit_code, business_unit_name, business_unit_type, welsh_language)
VALUES (1, 'ZD01', 'Synthetic Draft Unit', 'Area', false);

INSERT INTO maintenance_applications
    (application_id, application_code, application_title, application_group, active, date_used_from)
VALUES (31020, 'TEST', 'Synthetic Draft Application', 'Create Casefile', true, DATE '2000-01-01');

INSERT INTO countries (country_id, cjs_code, country_name, active, date_used_from)
VALUES (5000000301, 1, 'Synthetic Draft Country', true, DATE '2000-01-01');

INSERT INTO results
    (result_id, result_title, order_term, enforcement_result, case_result, active, order_accruing,
     requires_creditor, enforcement_hold, requires_enforcer, generates_hearing, generates_warrant,
     lists_monies, requires_employment_data, allow_additional_action, enf_next_permitted_actions,
     manual_enforcement, auto_enforcement)
VALUES ('MAT', 'Synthetic Draft Result', true, false, false, true, false, true, false, false,
        false, false, false, false, false, 'All', false, false);

-- Synthetic parent required by the draft account publication-link foreign key.
INSERT INTO respondent_accounts
    (respondent_account_id, business_unit_id, account_number, application_id, account_balance,
     orders_balance, orders_amount, payment_period, total_arrears, account_status,
     last_movement_date, date_arrears_last_updated, allow_cheques, cheque_clearance_period,
     credit_trans_clearance_period, casefile_type, interest_flag, indexation, payment_arrangement,
     version_number)
VALUES (101, 1, 'R101', 31020, 0, 0, 0, 'Weekly', 0, 'L',
        TIMESTAMP '2026-10-01 12:00:00', TIMESTAMP '2026-10-01 12:00:00', true, 10, 0,
        'REMO In', false, 'None', 'Court', 1);
