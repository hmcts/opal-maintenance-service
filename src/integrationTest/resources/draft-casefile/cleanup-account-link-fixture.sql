INSERT INTO respondent_accounts
    (respondent_account_id, business_unit_id, account_number, application_id,
     account_balance, orders_balance, orders_amount, payment_period, total_arrears,
     account_status, last_movement_date, date_arrears_last_updated, allow_cheques,
     cheque_clearance_period, credit_trans_clearance_period, casefile_type,
     interest_flag, indexation, payment_arrangement, version_number)
VALUES (9000000301, 1, 'SYNTHETIC-CLEANUP-1', 31020,
        0, 0, 0, 'Monthly', 0, 'L', TIMESTAMP '2026-10-01 12:00:00', TIMESTAMP '2026-10-01 12:00:00', false,
        0, 0, 'REMO In', false, 'None', 'Court', 0);
