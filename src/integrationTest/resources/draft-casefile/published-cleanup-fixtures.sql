-- Enrich both synthetic cases with every graph branch; references remain shared.
UPDATE draft_casefiles SET casefile = JSONB_SET(JSONB_SET(JSONB_SET(JSONB_SET(JSONB_SET(
    casefile::jsonb,
    '{respondent_account,remo_reference}', '"E2E-0123456789abcdef"'),
    '{respondent_account,central_authority_code}', '"C55A"'),
    '{respondent_account,notes}', '{"note_text":"Synthetic publication note"}'),
    '{respondent_account,respondent,party_details,aliases}',
    '[{"sequence_number":1,"surname":"Synthetic Alias","forenames":"Fixture"}]'),
    '{respondent_account,respondent,debtor_details}', '{"employer_name":"Synthetic Employer","employer_address":{"address_line_1":"Synthetic Employer Road","cjs_code":31055}}')::json
WHERE business_unit_id=32055;
UPDATE draft_casefiles SET casefile = JSONB_SET(JSONB_SET(casefile::jsonb,
    '{respondent_account,respondent,third_party_details}',
    '{"name":"Synthetic Contact","relationship":"Representative","address":{"address_line_1":"Synthetic Road","cjs_code":31055}}'),
    '{applicant,third_party_details}',
    '{"name":"Synthetic Applicant Contact","relationship":"Representative","address":{"address_line_1":"Synthetic Road","cjs_code":31055}}')::json
WHERE business_unit_id=32055;
UPDATE draft_casefiles SET casefile = JSONB_SET(casefile::jsonb,
    '{respondent_account,order_details,order_terms}',
    (casefile::jsonb #> '{respondent_account,order_details,order_terms}') ||
    '[{"result_id":"P55A","creditor_type":"Minor Creditor","minor_creditor_sequence":7,
       "result_responses":[{"parameter_name":"Amount","response":"1.00"}]},
      {"result_id":"P55B","creditor_type":"Major Creditor","major_creditor_code":"M55A",
       "result_responses":[{"parameter_name":"Amount","response":"2.00"}]}]')::json
WHERE business_unit_id=32055;
