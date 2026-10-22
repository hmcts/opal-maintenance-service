DELETE FROM draft_casefile_test_observations
WHERE draft_casefile_id IN (SELECT draft_casefile_id FROM draft_casefiles WHERE business_unit_id IN (1));
DELETE FROM draft_casefiles WHERE business_unit_id = 1;
DELETE FROM respondent_accounts WHERE respondent_account_id = 101 AND business_unit_id = 1;
DELETE FROM business_units WHERE business_unit_id = 1;
DELETE FROM maintenance_applications WHERE application_id = 31020;
DELETE FROM countries WHERE country_id = 5000000301;
DELETE FROM results WHERE result_id = 'MAT';
