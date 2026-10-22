INSERT INTO public.business_units
    (business_unit_id, business_unit_code, business_unit_name, business_unit_type, welsh_language)
VALUES (2610, 'Z261', 'Synthetic Evidence Unit', 'Area', false);

INSERT INTO public.draft_casefiles
    (draft_casefile_id, business_unit_id, created_date, submitted_by, submitted_by_name,
     casefile, casefile_snapshot, casefile_type, casefile_status, casefile_status_date,
     timeline_data, version_number)
VALUES
    (910626001, 2610, TIMESTAMP '2026-10-22 10:00:00', 'SYNTHETIC', 'Synthetic Submitter',
     '{}', '{}', 'REMO In', 'SUBMITTED', TIMESTAMP '2026-10-22 10:00:00', '[]', 1),
    (910626002, 2610, TIMESTAMP '2026-10-22 10:00:00', 'SYNTHETIC', 'Synthetic Submitter',
     '{}', '{}', 'REMO In', 'SUBMITTED', TIMESTAMP '2026-10-22 10:00:00', '[]', 1),
    (910626003, 2610, TIMESTAMP '2026-10-22 10:00:00', 'SYNTHETIC', 'Synthetic Submitter',
     '{}', '{}', 'REMO In', 'SUBMITTED', TIMESTAMP '2026-10-22 10:00:00', '[]', 1);
