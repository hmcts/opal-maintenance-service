DELETE FROM draft_casefiles WHERE business_unit_id IN (31021, 31022);
DELETE FROM respondent_accounts WHERE respondent_account_id = 101 AND business_unit_id = 31021;
DELETE FROM business_units WHERE business_unit_id IN (31021, 31022);
DELETE FROM maintenance_applications WHERE application_id = 31020;
