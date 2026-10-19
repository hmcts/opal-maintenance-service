/*
 * PO-10282
 * Create the COUNTRIES physical table bundle defined by the promoted RM TDIA.
 */

CREATE SEQUENCE public.country_id_seq
    AS BIGINT
    START WITH 1
    INCREMENT BY 1
    NO CYCLE
    CACHE 1;

CREATE TABLE public.countries (
    country_id BIGINT DEFAULT nextval('public.country_id_seq') NOT NULL,
    cjs_code SMALLINT NOT NULL,
    international_code VARCHAR(3),
    gov_code VARCHAR(2),
    country_name VARCHAR(100) NOT NULL,
    demonym VARCHAR(100),
    date_used_from DATE NOT NULL,
    date_used_to DATE,
    active BOOLEAN NOT NULL,
    CONSTRAINT countries_pk PRIMARY KEY (country_id),
    CONSTRAINT countries_international_code_uk UNIQUE (international_code)
);

ALTER SEQUENCE public.country_id_seq
    OWNED BY public.countries.country_id;

CREATE INDEX countries_active_country_name_idx
    ON public.countries USING btree (active, country_name);
