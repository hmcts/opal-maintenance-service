-- Remove only synthetic records owned by MajorCreditorDatabaseIntegrationTest, in FK order.
DELETE FROM public.major_creditors WHERE major_creditor_id BETWEEN 5000000001 AND 5000000006;
DELETE FROM public.countries WHERE country_id = 5000000101;
DELETE FROM public.business_units WHERE business_unit_id IN (31001, 31002, 31003);
