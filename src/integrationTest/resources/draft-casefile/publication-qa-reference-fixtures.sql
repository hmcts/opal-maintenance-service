-- The schema-only QA contexts need the same global clearance defaults as non-live migrations.
-- Explicit negative identities keep setup and cleanup restricted to these test-owned rows.
INSERT INTO public.configuration_items
    (configuration_item_id, item_name, business_unit_id, item_value, item_values)
VALUES
    (-1062101, 'DEFAULT_CHEQUE_CLEARANCE_PERIOD', NULL, '10', NULL),
    (-1062102, 'DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD', NULL, '0', NULL);

-- The rich QA request supplies both named responses to its synthetic MAT Result.
UPDATE public.results
SET result_parameters = '[
    {"name":"Amount","type":"decimal-2dp","mandatory":true,"min":0,"max":10000,"language_dependent":false},
    {"name":"Arrears","type":"decimal-2dp","mandatory":false,"min":0,"max":10000,"language_dependent":false}
]'::JSON
WHERE result_id = 'MAT';
