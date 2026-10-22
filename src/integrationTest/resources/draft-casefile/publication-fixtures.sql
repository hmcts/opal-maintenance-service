-- Synthetic publication fixtures; inserted inside each test transaction and rolled back.
INSERT INTO public.business_units(business_unit_id,business_unit_code,business_unit_name,business_unit_type,welsh_language)
VALUES(32055,'P055','Synthetic publication unit','Area',FALSE);
INSERT INTO public.countries(country_id,cjs_code,country_name,date_used_from,active)
VALUES(-1065501,31055,'Synthetic publication country',DATE '2000-01-01',TRUE),
 (-1065502,31056,'Synthetic inactive publication country',DATE '2000-01-01',FALSE);
INSERT INTO public.maintenance_applications(application_id,application_code,application_title,application_group,active,date_used_from)
VALUES(-10655,'PDC55','Synthetic publication application','Synthetic',TRUE,DATE '2000-01-01');
INSERT INTO public.major_creditors(major_creditor_id,business_unit_id,major_creditor_code,name,address_line_1,active,central_authority)
VALUES(-1065501,32055,'M55A','Synthetic first Major','First Major address',TRUE,FALSE),
 (-1065502,32055,'M55B','Synthetic second Major','Second Major address',TRUE,FALSE),
 (-1065503,32055,'C55A','Synthetic Central Authority','Authority address',TRUE,TRUE);
INSERT INTO public.results(result_id,result_title,order_term,enforcement_result,case_result,active,order_accruing,
 requires_creditor,enforcement_hold,requires_enforcer,generates_hearing,generates_warrant,lists_monies,
 requires_employment_data,allow_additional_action,enf_next_permitted_actions,manual_enforcement,auto_enforcement,
 result_parameters)
SELECT id,'Synthetic publication Result',TRUE,FALSE,FALSE,TRUE,FALSE,creditor,FALSE,FALSE,FALSE,FALSE,FALSE,
 FALSE,FALSE,'',FALSE,FALSE,
 '[{"name":"Amount","type":"decimal-2dp","mandatory":true,"min":0,"max":10000,"language_dependent":false}]'::JSON
FROM(VALUES('P55A',TRUE),('P55B',TRUE),('P55N',FALSE))v(id,creditor);
CREATE TEMP TABLE pdc_payloads(label TEXT PRIMARY KEY,payload JSON NOT NULL);
INSERT INTO pdc_payloads VALUES('base',$payload$
{ "respondent_account": {
 "application_code":"PDC55",
 "respondent":{"party_details":{"organisation":false,"individual_details":{"surname":"Synthetic Respondent"},
 "address":{"address_line_1":"Respondent address","cjs_code":31055}}},
 "order_details":{"date_ordered":"2024-01-01","date_arrears_last_updated":"2024-01-01",
 "payment_period":"Monthly","interest_flag":false,"indexation":"None","payment_arrangement":"Court",
 "order_terms":[{"result_id":"P55A","creditor_type":"Applicant",
 "result_responses":[ { "parameter_name" : "Amount", "response" : "00012.30" } ]}]}},
 "applicant":{"party_details":{"organisation":false,"individual_details":{"surname":"Synthetic Applicant"},
 "address":{"address_line_1":"Applicant address","cjs_code":31055}},
 "bank_account_details":{"bank_account_type":"None or not applicable"}},
 "minor_creditors":[{"creditor_sequence":7,"party_details":{"organisation":false,
 "individual_details":{"surname":"Synthetic Minor Seven"},
 "address":{"address_line_1":"Minor Seven address","cjs_code":31055}},
 "bank_account_details":{"bank_account_type":"None or not applicable"}}] }
$payload$::JSON);
INSERT INTO public.draft_casefiles(draft_casefile_id,business_unit_id,created_date,submitted_by,submitted_by_name,
 validated_date,validated_by,validated_by_name,casefile,casefile_snapshot,casefile_type,casefile_status,
 casefile_status_date,timeline_data,version_number)
SELECT id,32055,TIMESTAMP '2024-01-01','P55_SUBMIT','Synthetic saved submitter',
 TIMESTAMP '2024-01-02','P55_APPROVE','Synthetic saved approver',payload,
 '{ "respondent_name" : "Synthetic Respondent", "applicant_name" : "Synthetic Applicant" }'::JSON,
 'REMO In','PUBLISHING_PENDING',TIMESTAMP '2024-01-02','[ { "event" : "Synthetic approval" } ]'::JSON,1
FROM pdc_payloads CROSS JOIN(VALUES(1062901::BIGINT),(1062902::BIGINT))v(id);
