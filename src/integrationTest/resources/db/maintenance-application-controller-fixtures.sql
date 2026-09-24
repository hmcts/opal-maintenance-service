DELETE FROM public.maintenance_applications WHERE application_id BETWEEN 32001 AND 32005;
INSERT INTO public.maintenance_applications
    (application_id, application_code, application_title, application_group, active,
     date_used_from, date_used_to)
VALUES
    (32003, 'APP00003', 'Beta',  'Create Casefile', true,  DATE '2000-01-01', NULL),
    (32002, 'APP00002', 'Alpha', 'Create Casefile', false, DATE '2000-01-01', DATE '2001-01-01'),
    (32001, 'APP00001', 'Alpha', 'Create Casefile', true,  DATE '2999-01-01', NULL),
    (32004, 'APP00004', 'Alpha', 'Other',           true,  DATE '2000-01-01', NULL),
    (32005, 'APP00005', 'Beta',  'Other',           false, DATE '2000-01-01', NULL);
