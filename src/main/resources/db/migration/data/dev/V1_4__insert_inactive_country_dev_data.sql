/*
 * PO-10290
 * DEV-ONLY synthetic inactive Country used to exercise active filtering.
 */

INSERT INTO public.countries (
    cjs_code,
    international_code,
    country_name,
    date_used_from,
    date_used_to,
    active
) VALUES (
    32011,
    'XIC',
    'Inactive Test Country',
    DATE '2025-01-01',
    DATE '2025-01-02',
    FALSE
);
