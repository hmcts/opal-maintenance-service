/*
 * PO-10282
 * DEV-ONLY NON-AUTHORITATIVE COUNTRY DATA.
 * Country names and ISO alpha-3 codes are realistic demonstration values.
 * Synthetic CJS codes and the fixed applicability date are not production data.
 */

INSERT INTO public.countries (
    cjs_code,
    international_code,
    country_name,
    date_used_from,
    active
) VALUES
    (32001, 'GBR', 'United Kingdom', DATE '2025-01-01', TRUE),
    (32002, 'IRL', 'Ireland', DATE '2025-01-01', TRUE),
    (32003, 'FRA', 'France', DATE '2025-01-01', TRUE),
    (32004, 'DEU', 'Germany', DATE '2025-01-01', TRUE),
    (32005, 'ESP', 'Spain', DATE '2025-01-01', TRUE),
    (32006, 'ITA', 'Italy', DATE '2025-01-01', TRUE),
    (32007, 'POL', 'Poland', DATE '2025-01-01', TRUE),
    (32008, 'USA', 'United States', DATE '2025-01-01', TRUE),
    (32009, 'IND', 'India', DATE '2025-01-01', TRUE),
    (32010, 'PAK', 'Pakistan', DATE '2025-01-01', TRUE);
