TRUNCATE TABLE public.countries RESTART IDENTITY;

INSERT INTO public.countries (
    country_id,
    cjs_code,
    international_code,
    gov_code,
    country_name,
    demonym,
    date_used_from,
    date_used_to,
    active
) VALUES
    (101, 2001, 'FRA', 'FR', 'France', 'French', DATE '2000-01-01', NULL, TRUE),
    (102, 2002, 'GBR', 'UK', 'United Kingdom', 'British', DATE '1900-01-01', NULL, TRUE),
    (103, 2003, 'DEU', 'DE', 'Germany', 'German', DATE '2000-01-01', DATE '2025-12-31', FALSE),
    (104, 2004, NULL, NULL, 'Atlantis', NULL, DATE '2001-02-03', NULL, FALSE);
