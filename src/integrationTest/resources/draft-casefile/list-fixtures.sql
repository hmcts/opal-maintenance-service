INSERT INTO business_units
    (business_unit_id, business_unit_code, business_unit_name, business_unit_type, welsh_language)
VALUES
    (31021, 'ZD21', 'Synthetic List Unit', 'Area', false),
    (31022, 'ZD22', 'Synthetic Other List Unit', 'Area', false);

INSERT INTO draft_casefiles
    (draft_casefile_id, business_unit_id, created_date, submitted_by, submitted_by_name,
     casefile, casefile_snapshot, casefile_type, casefile_status, casefile_status_date,
     timeline_data, version_number)
SELECT seed.id, seed.bu, TIMESTAMP '2026-09-01 10:00:00', seed.submitter, 'Synthetic Submitter',
    '{"respondent_account":{"respondent":{}},"applicant":{}}'::json,
    '{"respondent_account":{"account_id":null,"account_number":null,"respondent_name":"Synthetic R"},
      "applicant_account":{"account_id":null,"account_number":null,"applicant_name":"Synthetic A"},
      "minor_creditor_accounts":[]}'::json,
    'REMO In'::public.t_casefile_type_enum, seed.status::public.t_draft_casefile_status_enum,
    seed.status_date::timestamp,
    '[{"username":"Synthetic Submitter","status":"Submitted","status_date":"2026-09-01T10:00:00Z"}]'::json, 0
FROM (VALUES
    (910201::bigint, 31021::smallint, 'BUU-1', 'SUBMITTED', '2026-10-01 00:00:00'),
    (910202::bigint, 31021::smallint, 'BUU-2', 'RESUBMITTED', '2026-10-01 23:59:59.999999'),
    (910203::bigint, 31021::smallint, 'BUU-1', 'REJECTED', '2026-09-01 13:00:00'),
    (910204::bigint, 31021::smallint, 'BUU-1', 'SUBMITTED', '2026-10-02 00:00:00'),
    (910205::bigint, 31022::smallint, 'BUU-1', 'SUBMITTED', '2026-10-01 12:00:00'),
    (910206::bigint, 31021::smallint, 'BUU-2', 'PUBLISHED', '2026-10-03 12:00:00'),
    (910207::bigint, 31021::smallint, 'BUU-3', 'DELETED', '2026-10-01 12:00:00')
) AS seed(id, bu, submitter, status, status_date);

UPDATE draft_casefiles
SET casefile = '{"respondent_account":{"respondent":{}},"applicant":{},
                 "minor_creditors":[{"bank_account_details":{"uk_bank_details":{}}},{}]}'::json,
    casefile_snapshot = '{"respondent_account":{"account_id":null,"account_number":null,"respondent_name":"Synthetic R"},
      "applicant_account":{"account_id":null,"account_number":null,"applicant_name":"Synthetic A"},
      "minor_creditor_accounts":[
        {"creditor_sequence":7,"account_id":null,"account_number":null,"name":"Synthetic M1"},
        {"creditor_sequence":2,"account_id":null,"account_number":null,"name":"Synthetic M2"}]}'::json
WHERE draft_casefile_id = 910202;
