-- Remove only the global configuration rows created by publication-qa-reference-fixtures.sql.
DELETE FROM public.configuration_items
WHERE business_unit_id IS NULL
  AND ((configuration_item_id = -1062101 AND item_name = 'DEFAULT_CHEQUE_CLEARANCE_PERIOD')
    OR (configuration_item_id = -1062102 AND item_name = 'DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD'));
