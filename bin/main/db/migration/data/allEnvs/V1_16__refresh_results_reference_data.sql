/**
 * OPAL Program
 *
 * MODULE      : V1_16__refresh_results_reference_data.sql
 *
 * DESCRIPTION : Refresh three fields for the 22 approved existing Results keys.
 *
 * CHANGE HISTORY:
 *
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * 01/10/2026  Chris Larkin  PO-10894      Refresh approved Results reference values
 */

UPDATE public.results
SET    order_term = true,
       result_parameters = '[{"name":"Amount","prompt":"Amount","type":"decimal-2dp","mandatory":true,"min":0,"max":9999999999.99,"language_dependent":false},{"name":"Frequency","prompt":"Payment frequency","type":"read-only","mandatory":true,"options":["Weekly","Fortnightly","Monthly","Quarterly","Yearly"],"min":1,"max":1,"language_dependent":false},{"name":"Expiry","prompt":"Expiry date","type":"date","mandatory":false,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_future":true,"date_in_past":false,"date_today":true},{"name":"Arrears","prompt":"Arrears","type":"decimal-2dp","mandatory":false,"min":0,"max":9999999999.99,"language_dependent":false},{"name":"Creditor","prompt":"Creditor name","type":"text-60","mandatory":true,"min":1,"max":60,"language_dependent":false},{"name":"Respondent","prompt":"Respondent name","type":"text-60","mandatory":true,"min":1,"max":60,"language_dependent":false},{"name":"Payment","prompt":"Payment arrangement","type":"menu-radio","mandatory":true,"options":["Payable through the Court","Payable between the parties"],"min":1,"max":1,"language_dependent":false},{"name":"Commencement","prompt":"Date order made","type":"date","mandatory":true,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_future":true,"date_in_past":true,"date_today":true}]'::json,
       enf_next_permitted_actions = NULL
WHERE  result_id = 'MAT';

UPDATE public.results
SET    order_term = true,
       result_parameters = '[{"name":"Amount","prompt":"Amount","type":"decimal-2dp","mandatory":true,"min":0,"max":9999999999.99,"language_dependent":false},{"name":"Frequency","prompt":"Payment frequency","type":"read-only","mandatory":true,"options":["Weekly","Fortnightly","Monthly","Quarterly","Yearly"],"min":1,"max":1,"language_dependent":false},{"name":"Expiry","prompt":"Expiry date","type":"date","mandatory":true,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_future":true,"date_in_past":false,"date_today":true},{"name":"Education","prompt":"Expiry terms","type":"menu-checkbox","mandatory":false,"min":0,"hint":"Add details to case comment or notes","options":["Additional terms affect order expiry"],"max":1,"language_dependent":false},{"name":"Arrears","prompt":"Arrears","type":"decimal-2dp","mandatory":false,"min":0,"max":9999999999.99,"language_dependent":false},{"name":"Beneficiary","prompt":"Child''s name","type":"text-60","mandatory":true,"min":1,"max":60,"language_dependent":false},{"name":"ChildDOB","prompt":"Child''s date of birth","type":"date","mandatory":false,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_future":false,"date_in_past":true,"date_today":true},{"name":"Respondent","prompt":"Respondent name","type":"text-60","mandatory":true,"min":1,"max":60,"language_dependent":false},{"name":"Payment","prompt":"Payment arrangement","type":"menu-radio","mandatory":true,"options":["Payable through the Court","Payable between the parties"],"min":1,"max":1,"language_dependent":false},{"name":"Commencement","prompt":"Date order made","type":"date","mandatory":true,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_future":true,"date_in_past":true,"date_today":true}]'::json,
       enf_next_permitted_actions = NULL
WHERE  result_id = 'MCHILD';

UPDATE public.results
SET    order_term = true,
       result_parameters = '[{"name":"Amount","prompt":"Amount of order","type":"decimal-2dp","mandatory":true,"min":0,"max":9999999999.99,"language_dependent":false},{"name":"Creditor","prompt":"Creditor name","type":"text-60","mandatory":true,"min":1,"max":60,"language_dependent":false},{"name":"Respondent","prompt":"Respondent name","type":"text-60","mandatory":true,"min":1,"max":60,"language_dependent":false},{"name":"Payment","prompt":"Payment arrangement","type":"menu-radio","mandatory":true,"options":["Payable through the Court","Payable between the parties"],"min":1,"max":1,"language_dependent":false},{"name":"Reason","prompt":"Reason for order","type":"text-1000","mandatory":true,"min":1,"max":1000,"language_dependent":false},{"name":"Due","prompt":"Cost due by date","type":"date","mandatory":true,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_future":true,"date_in_past":true,"date_today":true}]'::json,
       enf_next_permitted_actions = NULL
WHERE  result_id = 'MLUMP';

UPDATE public.results
SET    order_term = false,
       result_parameters = '[{"name":"Details","prompt":"Non-standard details","type":"text-1000","mandatory":true,"min":1,"max":1000,"language_dependent":false}]'::json,
       enf_next_permitted_actions = NULL
WHERE  result_id = 'MNSTD';

UPDATE public.results
SET    order_term = false,
       result_parameters = '[{"name":"Hearing","prompt":"Date of hearing","type":"date","mandatory":true,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_future":true,"date_in_past":true,"date_today":true},{"name":"Court","prompt":"Court venue","type":"menu-autocomplete","mandatory":true,"min":1,"max":1,"language_dependent":false,"apidata":"courts"},{"name":"Time","prompt":"Hearing time","type":"text-60","mandatory":true,"min":1,"max":60,"language_dependent":false}]'::json,
       enf_next_permitted_actions = NULL
WHERE  result_id = 'MSUMM';

UPDATE public.results
SET    order_term = false,
       result_parameters = '[{"name":"Hearing","prompt":"Date of hearing","type":"date","mandatory":true,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_future":true,"date_in_past":true,"date_today":true},{"name":"Court","prompt":"Court venue","type":"menu-autocomplete","mandatory":true,"min":1,"max":1,"language_dependent":false,"apidata":"courts"},{"name":"Time","prompt":"Hearing time","type":"text-60","mandatory":true,"min":1,"max":60,"language_dependent":false},{"name":"Reason","prompt":"Reason for hearing","type":"text-1000","mandatory":true,"min":1,"max":1000,"language_dependent":false}]'::json,
       enf_next_permitted_actions = NULL
WHERE  result_id = 'MNENF';

UPDATE public.results
SET    order_term = false,
       result_parameters = '[{"name":"Adjournment","prompt":"Adjournment date","type":"date","mandatory":true,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_future":true,"date_in_past":true,"date_today":true},{"name":"Court","prompt":"Court venue","type":"menu-autocomplete","mandatory":true,"min":1,"max":1,"language_dependent":false,"apidata":"courts"},{"name":"Time","prompt":"Hearing time","type":"text-60","mandatory":true,"min":1,"max":60,"language_dependent":false},{"name":"Reason","prompt":"Reason for hearing","type":"text-1000","mandatory":true,"min":1,"max":1000,"language_dependent":false}]'::json,
       enf_next_permitted_actions = NULL
WHERE  result_id = 'MADJ';

UPDATE public.results
SET    order_term = false,
       result_parameters = '[{"name":"Arrears","prompt":"Amount of arrears","type":"decimal-2dp","mandatory":true,"min":0,"max":9999999999.99,"language_dependent":false},{"name":"Details","prompt":"Non-standard details","type":"text-1000","mandatory":true,"min":1,"max":1000,"language_dependent":false}]'::json,
       enf_next_permitted_actions = NULL
WHERE  result_id = 'MPAY';

UPDATE public.results
SET    order_term = false,
       result_parameters = '[{"name":"Creditor","prompt":"Creditor name","type":"text-60","mandatory":true,"min":1,"max":60,"language_dependent":false},{"name":"Respondent","prompt":"Respondent name","type":"text-60","mandatory":true,"min":1,"max":60,"language_dependent":false},{"name":"Reason","prompt":"Reason for order","type":"text-1000","mandatory":true,"min":1,"max":1000,"language_dependent":false}]'::json,
       enf_next_permitted_actions = NULL
WHERE  result_id = 'MTEMP';

UPDATE public.results
SET    order_term = false,
       result_parameters = '[{"name":"Deduction","prompt":"Normal deduction rate","type":"decimal-2dp","mandatory":true,"min":0,"max":9999999999.99,"language_dependent":false},{"name":"Protected","prompt":"Protected earnings rate","type":"decimal-2dp","mandatory":true,"min":0,"max":9999999999.99,"language_dependent":false},{"name":"Period","prompt":"Pay period","type":"text-60","mandatory":true,"min":1,"max":60,"language_dependent":false}]'::json,
       enf_next_permitted_actions = NULL
WHERE  result_id = 'MAEO';

UPDATE public.results
SET    order_term = false,
       result_parameters = '[]'::json,
       enf_next_permitted_actions = NULL
WHERE  result_id = 'MWDN';

UPDATE public.results
SET    order_term = false,
       result_parameters = '[{"name":"Arrears","prompt":"Amount of arrears remitted","type":"decimal-2dp","mandatory":true,"min":0,"max":9999999999.99,"language_dependent":false},{"name":"Reason","prompt":"Reason for order","type":"text-1000","mandatory":false,"min":0,"max":1000,"language_dependent":false}]'::json,
       enf_next_permitted_actions = NULL
WHERE  result_id = 'MREMT';

UPDATE public.results
SET    order_term = false,
       result_parameters = '[{"name":"Adjournment","prompt":"Adjournment date","type":"date","mandatory":true,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_future":true,"date_in_past":true,"date_today":true},{"name":"Court","prompt":"Court venue","type":"menu-autocomplete","mandatory":true,"min":1,"max":1,"language_dependent":false,"apidata":"courts"},{"name":"Time","prompt":"Hearing time","type":"text-60","mandatory":true,"min":1,"max":60,"language_dependent":false},{"name":"Reason","prompt":"Reason for hearing","type":"text-1000","mandatory":true,"min":1,"max":1000,"language_dependent":false}]'::json,
       enf_next_permitted_actions = NULL
WHERE  result_id = 'MBAIL';

UPDATE public.results
SET    order_term = false,
       result_parameters = '[{"name":"Adjournment","prompt":"Adjournment date","type":"date","mandatory":true,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_future":true,"date_in_past":true,"date_today":true},{"name":"Court","prompt":"Court venue","type":"menu-autocomplete","mandatory":true,"min":1,"max":1,"language_dependent":false,"apidata":"courts"},{"name":"Time","prompt":"Hearing time","type":"text-60","mandatory":true,"min":1,"max":60,"language_dependent":false},{"name":"Reason","prompt":"Reason for hearing","type":"text-1000","mandatory":true,"min":1,"max":1000,"language_dependent":false}]'::json,
       enf_next_permitted_actions = NULL
WHERE  result_id = 'MCMTP';

UPDATE public.results
SET    order_term = false,
       result_parameters = '[{"name":"Adjournment","prompt":"Adjournment date","type":"date","mandatory":true,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_future":true,"date_in_past":true,"date_today":true},{"name":"Court","prompt":"Court venue","type":"menu-autocomplete","mandatory":true,"min":1,"max":1,"language_dependent":false,"apidata":"courts"},{"name":"Time","prompt":"Hearing time","type":"text-60","mandatory":true,"min":1,"max":60,"language_dependent":false},{"name":"Reason","prompt":"Reason for hearing","type":"text-1000","mandatory":true,"min":1,"max":1000,"language_dependent":false}]'::json,
       enf_next_permitted_actions = NULL
WHERE  result_id = 'MTPDA';

UPDATE public.results
SET    order_term = false,
       result_parameters = '[{"name":"Adjournment","prompt":"Adjournment date","type":"date","mandatory":true,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_future":true,"date_in_past":true,"date_today":true},{"name":"Court","prompt":"Court venue","type":"menu-autocomplete","mandatory":true,"min":1,"max":1,"language_dependent":false,"apidata":"courts"},{"name":"Time","prompt":"Hearing time","type":"text-60","mandatory":true,"min":1,"max":60,"language_dependent":false},{"name":"Reason","prompt":"Reason for hearing","type":"text-1000","mandatory":true,"min":1,"max":1000,"language_dependent":false}]'::json,
       enf_next_permitted_actions = NULL
WHERE  result_id = 'MTPDO';

UPDATE public.results
SET    order_term = false,
       result_parameters = '[{"name":"Adjournment","prompt":"Adjournment date","type":"date","mandatory":true,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_future":true,"date_in_past":true,"date_today":true},{"name":"Court","prompt":"Court venue","type":"menu-autocomplete","mandatory":true,"min":1,"max":1,"language_dependent":false,"apidata":"courts"},{"name":"Time","prompt":"Hearing time","type":"text-60","mandatory":true,"min":1,"max":60,"language_dependent":false},{"name":"Reason","prompt":"Reason for hearing","type":"text-1000","mandatory":true,"min":1,"max":1000,"language_dependent":false}]'::json,
       enf_next_permitted_actions = NULL
WHERE  result_id = 'MCOO';

UPDATE public.results
SET    order_term = false,
       result_parameters = '[{"name":"Adjournment","prompt":"Adjournment date","type":"date","mandatory":true,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_future":true,"date_in_past":true,"date_today":true},{"name":"Court","prompt":"Court venue","type":"menu-autocomplete","mandatory":true,"min":1,"max":1,"language_dependent":false,"apidata":"courts"},{"name":"Time","prompt":"Hearing time","type":"text-60","mandatory":true,"min":1,"max":60,"language_dependent":false},{"name":"Reason","prompt":"Reason for hearing","type":"text-1000","mandatory":true,"min":1,"max":1000,"language_dependent":false}]'::json,
       enf_next_permitted_actions = NULL
WHERE  result_id = 'MCON';

UPDATE public.results
SET    order_term = false,
       result_parameters = '[{"name":"Adjournment","prompt":"Adjournment date","type":"date","mandatory":true,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_future":true,"date_in_past":true,"date_today":true},{"name":"Court","prompt":"Court venue","type":"menu-autocomplete","mandatory":true,"min":1,"max":1,"language_dependent":false,"apidata":"courts"},{"name":"Time","prompt":"Hearing time","type":"text-60","mandatory":true,"min":1,"max":60,"language_dependent":false},{"name":"Reason","prompt":"Reason for hearing","type":"text-1000","mandatory":true,"min":1,"max":1000,"language_dependent":false}]'::json,
       enf_next_permitted_actions = NULL
WHERE  result_id = 'MWOC';

UPDATE public.results
SET    order_term = false,
       result_parameters = '[{"name":"Adjournment","prompt":"Adjournment date","type":"date","mandatory":true,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_future":true,"date_in_past":true,"date_today":true},{"name":"Court","prompt":"Court venue","type":"menu-autocomplete","mandatory":true,"min":1,"max":1,"language_dependent":false,"apidata":"courts"},{"name":"Time","prompt":"Hearing time","type":"text-60","mandatory":true,"min":1,"max":60,"language_dependent":false},{"name":"Reason","prompt":"Reason for hearing","type":"text-1000","mandatory":true,"min":1,"max":1000,"language_dependent":false}]'::json,
       enf_next_permitted_actions = NULL
WHERE  result_id = 'MWCN';

UPDATE public.results
SET    order_term = false,
       result_parameters = '[{"name":"Adjournment","prompt":"Adjournment date","type":"date","mandatory":true,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_future":true,"date_in_past":true,"date_today":true},{"name":"Court","prompt":"Court venue","type":"menu-autocomplete","mandatory":true,"min":1,"max":1,"language_dependent":false,"apidata":"courts"},{"name":"Time","prompt":"Hearing time","type":"text-60","mandatory":true,"min":1,"max":60,"language_dependent":false},{"name":"Reason","prompt":"Reason for hearing","type":"text-1000","mandatory":true,"min":1,"max":1000,"language_dependent":false}]'::json,
       enf_next_permitted_actions = NULL
WHERE  result_id = 'MWOA';

UPDATE public.results
SET    order_term = false,
       result_parameters = '[{"name":"Adjournment","prompt":"Adjournment date","type":"date","mandatory":true,"min":"1900-01-01","max":"2100-12-31","language_dependent":false,"date_in_future":true,"date_in_past":true,"date_today":true},{"name":"Court","prompt":"Court venue","type":"menu-autocomplete","mandatory":true,"min":1,"max":1,"language_dependent":false,"apidata":"courts"},{"name":"Time","prompt":"Hearing time","type":"text-60","mandatory":true,"min":1,"max":60,"language_dependent":false},{"name":"Reason","prompt":"Reason for hearing","type":"text-1000","mandatory":true,"min":1,"max":1000,"language_dependent":false}]'::json,
       enf_next_permitted_actions = NULL
WHERE  result_id = 'MWAN';
