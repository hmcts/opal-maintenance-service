-- Remove only synthetic records owned by MajorCreditorDatabaseIntegrationTest, in FK order.
DELETE FROM public.major_creditors WHERE major_creditor_id BETWEEN 5000000001 AND 5000000006;
DELETE FROM public.countries WHERE country_id = 5000000101;
DELETE FROM public.business_units WHERE business_unit_id IN (31001, 31002, 31003);

-- Synthetic business units prove scope isolation and an existing unit without creditors.
INSERT INTO public.business_units
    (business_unit_id, business_unit_code, business_unit_name, business_unit_type, welsh_language)
VALUES
    (31001, 'ZT01', 'Synthetic Creditor Unit One', 'Area', false),
    (31002, 'ZT02', 'Synthetic Creditor Unit Two', 'Area', false),
    (31003, 'ZT03', 'Synthetic Empty Creditor Unit', 'Area', false);

-- Joined country is inactive and out of date: the creditor lookup must still return its details.
INSERT INTO public.countries
    (country_id, cjs_code, country_name, date_used_from, date_used_to, active)
VALUES (5000000101, 31001, 'Synthetic Country', '1990-01-01', '1991-01-01', false);

-- Duplicate names deliberately arrive in reverse identifier order; all Boolean pairs are represented.
INSERT INTO public.major_creditors
    (major_creditor_id, business_unit_id, major_creditor_code, name, address_line_1,
     address_line_2, address_line_3, address_line_4, address_line_5, postcode,
     country_id, contact_name, contact_email, active, central_authority)
VALUES
    (5000000002, 31001, 'T002', 'Alpha Shared', 'Synthetic address 2',
     NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, true, true),
    (5000000001, 31001, 'T001', 'Alpha Shared', 'Synthetic address 1',
     'Synthetic line 2', 'Synthetic line 3', 'Synthetic line 4', 'Synthetic line 5', 'ZZ1 1ZZ',
     5000000101, 'Synthetic Contact', 'synthetic@example.invalid', true, true),
    (5000000003, 31001, 'T003', 'Bravo Inactive Authority', 'Synthetic address 3',
     NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, false, true),
    (5000000004, 31001, 'T004', 'Charlie Active Creditor', 'Synthetic address 4',
     NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, true, false),
    (5000000005, 31001, 'T005', repeat('Z', 100), 'Synthetic address 5',
     NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, false, false),
    (5000000006, 31002, 'T001', 'Other Unit Authority', 'Synthetic address 6',
     NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, true, true);
